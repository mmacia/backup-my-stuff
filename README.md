This is a little script I made to backup all my online Git repositories (currently only supports BitBucket API).

```ruby
require 'date'
require 'httparty'
require './bitbucket'
require './github.rb'
require './backup'

b = Backup.new({
  :bitbucket_user => 'your_bb_user',
  :bitbucket_password => 'secret',
  :github_user => 'your_gh_user',
  :github_password => 'secret',
  :backups_dir => '/path/to/backup'
})

b.backup_repositories
```

TODO
* Support for MySQL dumps
* Upload backups to Amazon S3
