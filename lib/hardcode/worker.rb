module Hardcode
  require 'sneakers'
  require 'json'
  require 'fileutils'

  TMP_DIR='/tmp/'
  LOG='/var/log/hardcode.log'

  class Worker
    include Sneakers::Worker
    from_queue :logs

    def work(msg)
      job = JSON.parse(msg)
      source_file = job[:source]

      if File.extname(source_file).match("^\.(mp4|mp3)$") != nil
        FileUtils.mv(source_file, job[:dest_dir], verbose: true)
      else
        puts output = %x[stack-encode encode --no-progress -l #{LOG} -d #{TMP_DIR} '#{source_file}']
        if $?.success?
          puts filename = output[/.*>\s(.*)$/, 1]
          puts "Transcoding successful, deleting source file."
          FileUtils.mv(File.join(TMP_DIR, filename), job[:dest_dir], verbose: true)
          FileUtils.rm(source_file, verbose: true)
        else
          puts "Error: Transcoding failed."
        end
      end

      ack!
    end

  end # class
end # module
