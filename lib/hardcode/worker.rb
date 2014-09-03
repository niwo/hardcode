module Hardcode
  require 'sneakers'
  require 'sneakers/metrics/logging_metrics'
  require 'json'
  require 'fileutils'

  LOG='/var/log/hardcode.log'

  class Worker
    include Sneakers::Worker
    from_queue :stack_encode

    Sneakers.configure metrics: Sneakers::Metrics::LoggingMetrics.new

    def work(msg)
      begin
        job = JSON.parse(msg)
        source_file = job[:source]
        if File.extname(source_file).match("^\.(mp4|mp3)$") != nil
          FileUtils.mv(source_file, job[:dest_dir], verbose: true)
        else
          puts output = %x[stack-encode encode --no-progress -l #{LOG} '#{source_file}']
          if $?.success?
            puts filename = output[/.*>\s(.*)$/, 1]
            puts "Transcoding successful, deleting source file."
            FileUtils.mv(File.join(File.dirname(source_file), filename), job[:dest_dir], verbose: true)
            FileUtils.rm(source_file, verbose: true)
          else
            puts "Error: Transcoding failed."
          end
        end
      rescue => e
        worker_trace "Error: #{e.backtrace}"
      end
      worker_trace "Finished: #{job.to_s}"
      ack!
    end

  end # class
end # module
