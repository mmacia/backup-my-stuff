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
    mailboxes.each do |mailbox|
      @imap.examine(mailbox)
      maildir = Maildir.new("#{@options[:backup_dir]}/#{mailbox}")

      @imap.search(['ALL']).each do |message_id|
        message = @imap.fetch(message_id, ['RFC822', 'FLAGS', 'ENVELOPE'])
        message_raw = message[0].attr['RFC822']
        message_flags = message[0].attr['FLAGS']
        message_envelope = message[0].attr['ENVELOPE']

        puts "#{message_flags.inspect} #{message_envelope.from[0].name}: #{message_envelope.subject}"

        message_mdir = maildir.add(message_raw)

        message_mdir.process if message_flags.include? :Seen
      end
    end
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
end
