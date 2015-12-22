module Hardcode
  require 'sneakers'
  require 'sneakers/metrics/logging_metrics'
  require 'json'
  require 'fileutils'

  STACK_ENCODE_LOG='/var/log/hardcode.log'

  class Worker
    include Sneakers::Worker
    from_queue 'stack_encode'

    def work(msg)
      begin
        job = JSON.parse(msg)
        source_file = job['source']
        ffmpeg_options = if job['ffmpeg_options']
          "--ffmpeg-options \"#{job['ffmpeg_options']}\""
        else
          ""
        end
        # move mp4 and mp3 file directly without encoding
        if File.extname(source_file).match("^\.(mp4|mp3)$") != nil
          FileUtils.mv(source_file, job['dest_dir'], verbose: true)
        else
        puts output = %x[stack-encode encode --no-progress --log-file #{STACK_ENCODE_LOG} #{ffmpeg_options} '#{source_file}']
          if $?.success?
            filename = output[/.*>\s(.*)$/, 1]
            logger.info "Transcoding successful, deleting source file."
            FileUtils.mv(File.join(File.dirname(source_file), filename), job['dest_dir'], verbose: true)
            FileUtils.rm(source_file, verbose: true)
          else
            logger.error "Error: Transcoding failed."
          end
        end
      rescue => e
        message = "Error: #{e.message} - #{e.backtrace}"
        logger.fatal message
        raise message
      end
      logger.info "Finished: #{job.to_s}"
      ack!
    end

  end # class
end # module
