module BMS
  module Backup
    def perform
      p 'Backup::perform'
    end

    def compress(target, filename)
      base = File.basename(target)
      output = File.join(@options[:backup_dir], filename)

      puts "compressing #{base} ..."
      ret = false

      `tar cvjf #{output}.tmp -C #{File.dirname(target)} #{base}`
      ret = $?.success?

      # rename file on success
      ret ? File.rename("#{output}.tmp", output) : File.delete("#{output}.tmp")

      return ret
    end

    def store
      p 'Backup::store'
    end
  end
end
