module BMS
  module Backup
    def perform
      p 'Backup::perform'
    end

    def compress(repo_dir, new_filename, old_filename = nil)
      puts "compressing #{repo_dir} ..."
      dir = File.join(@options[:backup_dir], repo_dir)
      ret = false

      return ret unless File.directory?(dir)

      `cd #{@options[:backup_dir]}; tar cvjf #{new_filename}.tmp #{repo_dir}`
      ret = $?.success?

      if ret
        `mv #{@options[:backup_dir]}/#{new_filename}.tmp #{@options[:backup_dir]}/#{new_filename}` # rename file on success
        `rm -f #{@options[:backup_dir]}/#{old_filename}` unless old_filename.nil?
      else
        `rm -f #{@options[:backup_dir]}/#{new_filename}.tmp`
      end

      ret
    end

    def store
      p 'Backup::store'
    end
  end
end
