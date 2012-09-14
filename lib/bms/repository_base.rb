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
        repo_slug = @options[:repository]
        copies = backedup_copies repo_slug

        last_backup = copies[copies.count - 1][:last_backup]
        last_remote_updated = last_updated(repo_slug)

        if last_remote_updated > last_backup
          puts "updating backup for #{repo_slug} ..."
          new_filename = "#{@repo_type}-#{repo_slug}-#{last_remote_updated.strftime('%Y%m%d%H%M%S')}.tar.bz2"
          clone(repo_slug, @repo_type) && compress(new_filename)
        end

        if copies.count == @options[:max_backups]
          File.delete(File.join(@options[:backup_dir], copies[0].file))
        end
      end

      exit

     # remote_repository_slugs = slugs






      # update existent backups
      Dir.entries(@options[:backup_dir]).each do |item|
        next unless File.file?(File.join(@options[:backup_dir], item)) # skip directories

        item.match(/^#{@repo_type}\-([a-zA-Z\d\-\_]+)\-(\d+)\.tar\.bz2$/) { |m|
          repo_slug = m[1]
          last_backup = DateTime.parse(m[2])
          last_updated_ = last_updated(repo_slug)

          if last_updated_ > last_backup
            puts "updating backup for #{repo_slug} ..."
            old_filename = "#{@repo_type}-#{repo_slug}-#{last_backup.strftime('%Y%m%d%H%M%S')}.tar.bz2"
            new_filename = "#{@repo_type}-#{repo_slug}-#{last_updated_.strftime('%Y%m%d%H%M%S')}.tar.bz2"

            repos.shift if clone(repo_slug, @repo_type) && compress("#{@repo_type}-#{repo_slug}", new_filename, old_filename)
          else
            repos.shift
          end
        }
      end

      # backup new repos
      repos.each do |repo_slug|
        puts "backing up #{repo_slug} ..."
        if clone(repo_slug)
          new_filename = "#{@repo_type}-#{repo_slug}-#{last_updated(repo_slug).strftime('%Y%m%d%H%M%S')}.tar.bz2"
          compress("#{@repo_type}-#{repo_slug}", new_filename)
        end
      end
    end

    protected

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
      backedup_repositories.each { |item|
        item[:slug] == repository_slug
      }.sort! { |a,b|
        a[:last_backup] <=> b[:last_backup]
      }
    end
  end
end
