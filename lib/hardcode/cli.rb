module Hardcode
  require 'thor'
  require 'fileutils'
  require 'bunny'
  require 'json'
  require 'logger'
  require 'sneakers/runner'

  LOCK_FILE='/var/run/hardcode.lock'

  class Cli < Thor
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
    option :tmp_dir,
      desc: "temporary directory",
      aliases: '-t',
      default: '/tmp'
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
        q = ch.queue('stack_encode', durable: true)
        Dir.glob(File.join(source_dir, "*.*")) do |source_file|
          # wait until the file is fully written and not uploaded anymore
          while system %Q[lsof '#{source_file}']
           sleep 1
          end
          FileUtils.mv(source_file, options[:tmp_dir], verbose: true)
          ch.default_exchange.publish(
            {
              source: File.join(options[:tmp_dir], File.basename(source_file)),
              dest_dir: options[:destination]
            }.to_json,
            routing_key: q.name,
            persistent: true
          )
        end
      rescue => e
        puts "ERROR: #{e.message}"
      ensure
       FileUtils.rm(LOCK_FILE) if File.exists?(LOCK_FILE)
      end
    end

    desc "start_worker", "Start the sneakers based worker"
    option :ampq_url,
      desc: "AMPQ URL",
      default: 'amqp://guest:guest@localhost:5672'
    def start_worker
      Sneakers.configure(
        amqp: options[:ampq_url],
        daemonize: false,
        log: STDOUT
      )
      Sneakers.logger.level = Logger::INFO
      r = Sneakers::Runner.new([ Hardcode::Worker ])
      r.run
    end

  end # class
end # module
