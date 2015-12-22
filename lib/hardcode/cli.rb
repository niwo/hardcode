module Hardcode
  require 'thor'
  require 'fileutils'
  require 'bunny'
  require 'json'
  require 'logger'
  require 'sneakers/runner'
  require 'listen'

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

    class_option :amqp_url,
      desc: "AMQP URL",
      aliases: '-u',
      default: ENV['AMQP_URL'] ||'amqp://guest:guest@localhost:5672'

    desc "version", "Outputs the version number"
    def version
      say "hardcode v#{Hardcode::VERSION}"
    end

    desc "enqueue DIR", "Scans a source directory, moves the files to tmp and enqueues transcoding jobs to rabbitmq"
    method_option :destination,
      desc: "destination directory",
      aliases: '-d',
      default: '/var/www/'
    method_option :tmp_dir,
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
        conn = Bunny.new(options[:amqp_url])
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

    desc "work", "Start the sneakers based workers"
    method_option :debug,
      desc: "Enable debug output",
      type: :boolean
    def work
      vhost = vhost_from_amqp_url(options[:amqp_url])
      Sneakers.configure(
        amqp: options[:amqp_url],
        vhost: vhost,
        daemonize: false,
        log: STDOUT,
        metrics: Sneakers::Metrics::LoggingMetrics.new
      )
      Sneakers.logger.level = options[:debug] ? Logger::DEBUG : Logger::INFO
      Sneakers::Worker.configure_logger(Logger.new STDOUT)
      Sneakers::Runner.new([ Hardcode::Worker ]).run
    end

    desc "watch DIR", "Watch a source directory for new files, moves the files to tmp and enqueues transcoding jobs to rabbitmq"
    method_option :destination,
      desc: "destination directory",
      aliases: '-d',
      default: '/var/www/'
    method_option :tmp_dir,
      desc: "temporary directory",
      aliases: '-t',
      default: '/tmp'
    method_option :ffmpeg_options,
      desc: "custom ffmpeg options",
      aliases: '-o'
    def watch(source_dir)
      FileUtils.touch LOCK_FILE
      conn = Bunny.new(options[:amqp_url])
      conn.start
      ch = conn.create_channel
      q = ch.queue('stack_encode', durable: true)
      listener = Listen.to(source_dir) do |modified, added, removed|
        added.each do |source_file|
          # wait until the file is fully written and not uploaded anymore
          while system %Q[lsof '#{source_file}']
           sleep 1
          end
          worker_options = {
            source: File.join(options[:tmp_dir], File.basename(source_file)),
            dest_dir: options[:destination]
          }
          worker_options[:ffmpeg_options] = options[:ffmpeg_options] if options[:ffmpeg_options]
          FileUtils.mv(source_file, options[:tmp_dir], verbose: true)
          ch.default_exchange.publish(
            worker_options.to_json,
            routing_key: q.name,
            persistent: true
          )
        end
      end
      listener.start
      sleep
    end

    no_commands do
      def vhost_from_amqp_url(url)
        match = url.match(/^amqp:\/\/.+\/(\/|%2f)(.+)$/) rescue []
        vhost = match && match.size >= 3 ? match[2] : ''
        vhost = "/#{vhost}"
      end
    end

  end # class
end # module
