module BMS
  class Github < BMS::RepositoryBase
    include HTTParty
    base_uri 'https://api.github.com'

    def initialize(options = {})
      super
      @repo_type = 'github'
    end

    def repositories
      return @repositories unless @repositories.empty?

      options = { :basic_auth => @auth }
      response = self.class.get('/user/repos', options)

      if response.code == 200
        @repositories = response.to_a
      end

      @repositories
    end

    def url(repository_slug)
      url = nil

      repositories.each do |repo|
        next unless repo['name'] == repository_slug && repo['owner']['login'] == @auth[:username]

        url = repo['git_url']
      end

      url
    end

    def slugs
      slugs = []

      repositories.each do |repo|
        next unless repo['owner']['login'] == @auth[:username]
        slugs << repo['name']
      end

      slugs
    end

    def last_updated(repository_slug)
      last_updated = nil

      repositories.each do |repo|
        next unless repo['name'] == repository_slug && repo['owner']['login'] == @auth[:username]
        last_updated = repo['updated_at']
      end

      DateTime.parse(last_updated) unless last_updated.nil?
    end
  end
end
