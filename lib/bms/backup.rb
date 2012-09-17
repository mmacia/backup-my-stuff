module BMS
  module Backup
    def perform
      p 'Backup::perform'
    end

    def compress(target, filename)
      base = File.basename(target)

      puts "compressing #{base} ..."
      ret = false

      `tar cvjf #{filename}.tmp -C #{File.dirname(target)} #{base}`
      ret = $?.success?

      # rename file on success
      ret ? File.rename("#{filename}.tmp", filename) : File.delete("#{filename}.tmp")

      return ret
    end
  end
end
