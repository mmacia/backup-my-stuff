class Bitbucket
  include HTTParty
  base_uri 'https://api.bitbucket.org/1.0'

  def initialize(u, p)
    super
    @repo_type = 'bitbucket'
  end

  def repositories
    return @repositories unless @repositories.empty?

    options = { :basic_auth => @auth }
    response = self.class.get('/user/repositories/', options)

    if response.code == 200
      @repositories = response.to_a
    end

    @repositories
  end

  def url(repository_slug)
    url = nil

    repositories.each do |repo|
      if repo['slug'] == repository_slug
        url = "git@bitbucket.org:#{repo['owner']}/#{repository_slug}.git"
        break
      end
    end

    url
  end

  def slugs
    slugs = []

    repositories.each do |repo|
      slugs << repo['slug']
    end

    slugs
  end

  def last_updated(repository_slug)
    owner = nil

    repositories.each do |repo|
      if repo['slug'] == repository_slug
        owner = repo['owner']
        break
      end
    end

    options = { :basic_auth => @auth }
    response = self.class.get("/repositories/#{owner}/#{repository_slug}/", options)

    DateTime.parse(response['last_updated']) if response.code == 200
  end
end
