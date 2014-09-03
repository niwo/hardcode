module Hardcode
  require 'sneakers'
  require 'json'
  require 'fileutils'

  LOG='/var/log/hardcode.log'

  class Worker
    include Sneakers::Worker
    from_queue :stack_encode

    def work(msg)
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

      ack!
    end

  end # class
end # module
