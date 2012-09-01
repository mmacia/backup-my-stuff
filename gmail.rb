class Gmail
  DEFAULTS = {
    host:       'imap.gmail.com',
    port:       993,
    ssl:        true,
    backup_dir: '/tmp/gmail',
    username:   'user',
    password:   'secret',
  }

  def initialize(opts = [])
    @options = DEFAULTS.merge(opts)

    @imap = Net::IMAP.new(@options[:host], @options)
    @imap.login(@options[:username], @options[:password])
  end

  def fetch
    mailboxes.each { |mailbox|
      @imap.examine(mailbox)
      maildir = Maildir.new("#{@options[:backup_dir]}/#{mailbox}")
      @fetched = 0
      @removed = 0

      puts "Fetching #{mailbox}"
      @fetched_ids = parse_message_ids(maildir)

      @imap.search(['ALL']).each { |message_id|
        message = @imap.fetch(message_id, ['FLAGS', 'ENVELOPE'])
        message_flags = message[0].attr['FLAGS']
        message_envelope = message[0].attr['ENVELOPE']

        store(maildir, message_flags, message_envelope, message_id)
      }

      # remove unmatched message ids
      #if @fetched_ids.size > 0
      #  p @fetched_ids.size
      #end

      puts "  #{@fetched} fetched"
      #puts "  #{@removed} removed"
    }
  end

  private

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

  def parse_message_ids(maildir)
    message_ids = {}

    maildir.list(:cur).each { |message|
      text = message.data.encode('UTF-8', 'UTF-8', invalid: :replace)
      message_ids[extract_message_id(text).to_sym] = message.key
    }

    return message_ids
  end

  def extract_message_id(raw)
    msg_id = nil

    raw.match(/Message-I[dD]:\s+(<(.+)>|(.+))/) { |m|
      if m[2].nil? || m[2].empty?
        msg_id = m[1].strip!
      else
        msg_id = m[2]
      end
    }

    # multiline
    raw.match(/Message-I[dD]:\s+<(.+?)>/m) { |m|
      msg_id = m[1]
    } if msg_id.nil?

    raise raw if msg_id.nil?
    return msg_id
  end

  def store(maildir, flags, envelope, uid)
    msg_id = envelope.message_id.match(/<(.*?)>/)[1]
    subject = envelope.subject
    from = envelope.from[0].name

    if !@fetched_ids.has_key?(msg_id.to_sym)
      message = @imap.fetch(uid, ['RFC822'])[0].attr['RFC822']

      decoded_subject = subject.nil? ? '' : NKF.nkf('-mw', subject)
      decoded_from = from.nil? ? '' : NKF.nkf('-mw', from)
      puts "#{decoded_from}: #{decoded_subject}"

      mdir = maildir.add(message)

      if flags.include? :Seen
        mdir.process
        mdir.add_flag('S')
      end

      mdir.add_flag('F') if flags.include? :Flagged
      @fetched = @fetched + 1
    else
      # synchronize flags
      mdir = maildir.get(@fetched_ids[msg_id.to_sym])

      mdir.add_flag('S') if !mdir.flags.include?('S') && flags.include?(:Seen)
      mdir.add_flag('F') if !mdir.flags.include?('F') && flags.include?(:Flagged)
      mdir.remove_flag('S') if mdir.flags.include?('S') && !flags.include?(:Seen)
      mdir.remove_flag('F') if mdir.flags.include?('F') && !flags.include?(:Flagged)

      @fetched_ids.delete(msg_id.to_sym)
    end
  end
end
