module BMS
  class Gmail
    include BMS::Backup

    def initialize(opts = {})
      @options = opts

      @imap = Net::IMAP.new(@options[:host], @options)
      @imap.login(@options[:username], @options[:password])

      Dir.mkdir("#{@options[:cache_dir]}/gmail") unless Dir.exist? "#{@options[:cache_dir]}/gmail"

      @index_path = "#{@options[:cache_dir]}/gmail/index.yml"

      # initialize index
      if !File.exist? @index_path
        @index= {
          :emails => {},
          :last_check => nil
        }

        File.open(@index_path, 'w') { |file| file.puts YAML.dump @index }
      end

      @index = YAML.load_file(@index_path)
    end

    def synchronize
      start = Time.now.strftime('%Y-%m-%d %H:%M:%S')

      mailboxes.each { |mailbox|
        puts "Fetching #{mailbox} ..."

        synchronize_mailbox(mailbox)
      }

      @index[:last_check] = start
      write_index
    end

    def perform
      synchronize

      filename = File.join(@options[:backup_dir], "gmail-#{@index[:last_check].strftime('%Y%m%d%H%M%S')}.tar.bz2")
      compress("#{@options[:cache_dir]}/gmail", filename)

    end

    private

    def write_index
      tmp = "#{@index_path}~"
      File.open(tmp, 'w') { |file| file.puts YAML.dump @index }
      FileUtils.mv(tmp, @index_path)
    end

    def synchronize_mailbox(mailbox)
      @imap.examine(mailbox)
      remote_uids = @imap.uid_search(['ALL'])

      idx = @index[:emails].include?(mailbox.to_sym) ? @index[:emails][mailbox.to_sym] : []

      maildir = Maildir.new("#{@options[:cache_dir]}/gmail/#{mailbox}")
      local_uids = idx.map { |msg| msg[:uid] }

      # fetch new messages
      new_uids = (remote_uids - local_uids)
      (idx << fetch(new_uids, maildir)).flatten! unless new_uids.empty?

      # remove local messages
      remove_uids = (local_uids - remote_uids)
      idx.delete_if { |item|
        remove_uids.include? item[:uid]
      }

      puts "  #{new_uids.size} fetched" unless new_uids.size == 0
      puts "  #{remove_uids.size} removed" unless remove_uids.size == 0

      # synchronize flags
      if @index.include?(:last_check) && !@index[:last_check].nil?
        ts = DateTime.parse(@index[:last_check])
        remote_uids = @imap.uid_search(['SINCE', ts.strftime('%e-%b-%Y')])

        synchronize_flags(remote_uids, mailbox, maildir)
        puts "  Flags synched" unless remote_uids.size == 0
      end

      # update index
      @index[:emails][mailbox.to_sym] = idx
      write_index

    rescue Interrupt # catch Ctrl-C
      # save current processed index
      unless idx.nil? || idx.empty?
        @index[:emails][mailbox.to_sym] = idx
        write_index
      end

      exit
    end

    def fetch(uids, maildir)
      processed = []

      uids.each { |uid|
        f = @imap.uid_fetch(uid, ['FLAGS', 'RFC822'])
        next if f.nil?

        flags = f[0].attr['FLAGS']
        raw = f[0].attr['RFC822']

        mdir = maildir.add(raw)

        if flags.include? :Seen
          mdir.process
          mdir.add_flag('S')
        end

        mdir.add_flag('F') if flags.include? :Flagged
        processed << { uid: uid, key: mdir.key }
      }

      return processed

    rescue Net::IMAP::ByResponseError
      return processed
    end

    def synchronize_flags(uids, mailbox, maildir)
      idx = @index[:emails].include?(mailbox.to_sym) ? @index[:emails][mailbox.to_sym] : []

      return if idx.empty?

      local_uids = {}
      idx.each { |item| local_uids[item[:uid]] = item[:key] }

      uids.each { |uid|
        f = @imap.uid_fetch(uid, ['FLAGS'])
        flags = f[0].attr['FLAGS']

        mdir = maildir.get(local_uids[uid])

        mdir.add_flag('S') if !mdir.flags.include?('S') && flags.include?(:Seen)
        mdir.add_flag('F') if !mdir.flags.include?('F') && flags.include?(:Flagged)
        mdir.remove_flag('S') if mdir.flags.include?('S') && !flags.include?(:Seen)
        mdir.remove_flag('F') if mdir.flags.include?('F') && !flags.include?(:Flagged)
      }
    end

    def mailboxes(prefix = '')
      mailboxes = []

      @imap.list('', "#{prefix}%").each do |mailbox|
        if mailbox.attr.include?(:Haschildren) && !mailbox.attr.include?(:Hasnochildren)
          mailboxes << mailboxes("#{mailbox.name}#{mailbox.delim}")
        else
          mailboxes << mailbox.name
        end
      end

      return mailboxes.flatten
    end
  end
end
