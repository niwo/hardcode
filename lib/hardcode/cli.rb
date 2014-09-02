module Hardcode
  require 'thor'
  require 'fileutils'
  require 'bunny'
  require 'json'
  require 'logger'
  require 'sneakers/runner'

  LOCK_FILE='/var/run/hardcode.lock'

  class Cli
    include Thor::Actions

    def self.exit_on_failure?
      true
    end

    # catch control-c and exit
    trap("SIGINT") {
      puts " bye"
      exit!
    }

    package_name "hardcode"
    map %w(-v --version) => :version

    desc "version", "Outputs the version number"
    def version
      say "hardcode v#{Hardcode::VERSION}"
    end

    desc "enqueue SOURCE_DIRECTORY", "Scans a source directory and enqueues transcoding jobs to rabbitmq"
    option :destination,
      desc: "destination directory",
      aliases: '-d',
      default: '/var/www/'
    def enqueue(source_dir)
      if File.exists? LOCK_FILE
        puts "Lockfile present: #{LOCK_FILE}"
        puts "Schedule the job to run in 2 minutes."
        %x[echo #{File.expand_path(__FILE__)} | at now + 2 minutes]
        exit $?.exitstatus
      end

      begin
        FileUtils.touch LOCK_FILE
        conn = Bunny.new
        conn.start
        ch = conn.create_channel
        q = ch.queue('stack-encode')
        Dir.glob(File.join(source_dir, "*.*")) do |source_file|
          # wait until the file is fully written and not uploaded anymore
          while system %Q[lsof #{source_file}]
           sleep 1
          end
          ch.default_exchange.publish(
            {
              source: source_file,
              dest_dir: options[:destination]
            }.to_json,
            routing_key: q.name,
            durable: true
          )
        end
      rescue => e
        puts "ERROR: #{e.message}"
      ensure
       FileUtils.rm(LOCK_FILE) if File.exists?(LOCK_FILE)
      end
    end

    def start_worker
      Sneakers.configure(
        amqp: ENV['AMQP_URL'] || 'localhost',
        daemonize: false,
        log: STDOUT
      )
      Sneakers.logger.level = Logger::INFO

      r = Sneakers::Runner.new([ Hardcode::Worker ])
      r.run
    end

  end # class
end # module
