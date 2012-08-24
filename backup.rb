class Backup

  def initialize(options)
    @backup_dir = options.include?(:backup_dir) ? options[:backup_dir] : '/tmp/repos'

    if options.include?(:bitbucket_user) && options.include?(:bitbucket_password)
      @bb = Bitbucket.new(options[:bitbucket_user], options[:bitbucket_password])
    end

#    @gh = Github.new(options[:github_user], options[:github_password])

    Dir.mkdir(@backup_dir) if !File.directory?(@backup_dir)
  end

  def backup_repositories
    backup_bitbucket if @bb
  end


  protected
  def clone(repo_slug, type)
    dest_dir = File.join(@backup_dir, "#{type}-#{repo_slug}")
    url = @bb.url(repo_slug) if type == 'bitbucket'

   if File.directory?(dest_dir)
     `cd #{dest_dir}; git fetch --all --prune --tags`
   else
     `cd #{@backup_dir}; git clone --mirror --bare #{url} #{dest_dir}`
   end

   $?.success?
  end

  def compress(repo_dir, new_filename, old_filename = nil)
    puts "compressing #{repo_dir} ..."
    dir = File.join(@backup_dir, repo_dir)
    ret = false

    return ret unless File.directory?(dir)

    `cd #{@backup_dir}; tar cvjf #{new_filename}.tmp #{repo_dir}`
    ret = $?.success?

    if ret
      `mv #{@backup_dir}/#{new_filename}.tmp #{@backup_dir}/#{new_filename}` # rename file on success
      `rm -f #{@backup_dir}/#{old_filename}` unless old_filename.nil?
    else
      `rm -f #{@backup_dir}/#{new_filename}.tmp`
    end

    ret
  end

  def backup_bitbucket
    slugs = @bb.slugs

    # update existent backups
    Dir.entries(@backup_dir).each do |item|
      next unless File.file?(File.join(@backup_dir, item)) # skip directories

      m = item.match(/^bitbucket\-([a-zA-Z\d\-\_]+)\-(\d+)\.tar\.bz2$/)
      next unless m # skip files with unknown format

      repo_slug = m[1]
      last_backup = DateTime.parse(m[2])
      last_updated = @bb.last_updated(repo_slug)

      if last_updated > last_backup
        puts "updating backup for #{repo_slug} ..."
        old_filename = "bitbucket-#{repo_slug}-#{last_backup.strftime('%Y%m%d%H%M%S')}.tar.bz2"
        new_filename = "bitbucket-#{repo_slug}-#{last_updated.strftime('%Y%m%d%H%M%S')}.tar.bz2"

        slugs.shift if clone(repo_slug, 'bitbucket') && compress("bitbucket-#{repo_slug}", new_filename, old_filename)
      else
        slugs.shift
      end
    end

    # backup new repos
    slugs.each do |repo_slug|
      puts "backing up #{repo_slug} ..."
      if clone(repo_slug, 'bitbucket')
        new_filename = "bitbucket-#{repo_slug}-#{@bb.last_updated(repo_slug).strftime('%Y%m%d%H%M%S')}.tar.bz2"
        compress("bitbucket-#{repo_slug}", new_filename)
      end
    end
  end
end
