module BMS
  class RepositoryBase
    include BMS::Backup

    def initialize(options = {})
      @options = options
      @auth = { :username => @options[:username], :password => @options[:password] }
      @repositories = []

      Dir.mkdir(@options[:cache_dir]) if !File.directory?(@options[:cache_dir])
      Dir.mkdir(@options[:backup_dir]) if !File.directory?(@options[:backup_dir])
    end

    def clone(repo_slug)
      dest_dir = File.join(@options[:cache_dir], "#{@repo_type}-#{repo_slug}")

      if File.directory?(dest_dir)
        `cd #{dest_dir}; git fetch --all --prune --tags`
      else
        `cd #{@options[:cache_dir]}; git clone --mirror --bare #{url(repo_slug)} #{dest_dir}`
      end

      $?.success?
    end

    def perform
      # backup a single repository
      if @options.include? :repository
        perform_single(@options[:repository])
      else
        # backup all repositories
        remote_repository_slugs = slugs

        # update existent backups
        Dir.entries(@options[:backup_dir]).each do |item|
          next unless File.file?(File.join(@options[:backup_dir], item)) # skip directories

          item.match(/^#{@repo_type}\-([a-zA-Z\d\-\_]+)\-(\d+)\.tar\.bz2$/) { |m|
            remote_repository_slugs.shift if perform_single(m[1])
          }
        end

        # backup new repos
        remote_repository_slugs.each { |repo_slug| perform_single(repo_slug) }
      end
    end

    protected

    def perform_single(repo_slug)
      copies = backedup_copies(repo_slug)
      last_remote_updated = last_updated(repo_slug)

      # first time backup
      return clone_and_compress(repo_slug, last_remote_updated) if copies.empty?

      last_backup = copies[copies.count - 1][:last_backup]

      if last_remote_updated.nil?
        puts "Seems that repository \"#{repo_slug}\" doesn't exists!"
        return false
      end

      if last_remote_updated > last_backup
        clone_and_compress(repo_slug, last_remote_updated)
      else
        puts "Cheers! Repository \"#{repo_slug}\" is already backed up."
      end

      # remove older backups
      if copies.count > @options[:max_backups]
        File.delete(File.join(@options[:backup_dir], copies[0].file))
      end

      return true
    end

    def clone_and_compress(repo_slug, updated_at)
      puts "updating backup for #{repo_slug} ..."

      target = File.join(@options[:cache_dir], "#{@repo_type}-#{repo_slug}")
      output = File.join(@options[:backup_dir], "#{@repo_type}-#{repo_slug}-#{updated_at.strftime('%Y%m%d%H%M%S')}.tar.bz2")

      clone(repo_slug) && compress(target, output)
    end

    #
    # Get backed up repositories and its metadata
    #
    def backedup_repositories
      cache = Dir.entries(@options[:backup_dir]).map { |item|
        item.match(/^#{@repo_type}\-([a-zA-Z\d\-\_]+)\-(\d+)\.tar(\.bz2)?$/) do |m|
          {
            slug: m[1],
            file: item,
            last_backup: DateTime.parse(m[2]),
            compressed: !m[3].nil?
          }
        end
      }.reject! { |item| item.nil? }

      # memoization
      self.class.send(:define_method, :backedup_repository, lambda{cache}).call
    end

    #
    # Get all backups of given repository, ordered by date
    #
    def backedup_copies(repository_slug)
      puts "backing up #{repository_slug}"
      copies = []

      backedup_repositories.each { |item| copies << item if item[:slug] == repository_slug }
      copies.sort! { |a, b| a[:last_backup] <=> b[:last_backup] }
    end
  end
end
