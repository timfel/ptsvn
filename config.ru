require "rack/reverse_proxy"

SVN_ROOT = File.expand_path("../svn", __FILE__)
REPO_PATH = "users"

SVN_HOST = "http://localhost:8443"
SVN_HOST_PATH = "svn/pt1_2013"


module SvnAccess
  extend self

  def exists?(path)
    system("svnlook pl #{SVN_ROOT} #{REPO_PATH}/#{path}")
  end

  def mkdir(path)
    system("svn mkdir #{SVN_HOST}/#{SVN_HOST_PATH}/#{REPO_PATH}/#{path} --non-interactive -n \"Create #{path}\"")
  end

  def cat(path)
    `svnlook cat #{SVN_ROOT} #{REPO_PATH}/#{path}`
  end

  def accessible?(user, path)
    path = path.sub("/users", "")

    # don't break out of sandbox
    return false unless File.expand_path(path, "/") =~ /^\/#{user}/

    return true if user_folder?(user, path)

    path_parts = path.split("/")
    partner = path_parts[0]

    [[user, partner], [partner, user]].each do |this, other|
      if exists?("#{this}/partner")
        name = cat("#{this}/partner").split(/\r|\n/).first
        return false unless name == other
      end
    end
  end

  def user_folder?(user, path)
    path_parts = path.split("/").reject(&:empty?)
    path_parts[0] == user
  end

  def ensure_svn(user)
    mkdir(user) unless exists?(user)
  end

  def call(env)
    env["REMOTE_USER"] ||= "test.user"
    user = env["REMOTE_USER"].downcase
    ensure_svn(user)

    if (env["PATH_INFO"].start_with?(REPO_PATH) && accessible?(user, env["PATH"])) ||
        env["PATH_INFO"].start_with?("!svn")
      r = @app.call(env)
      p r
      r
    else
      [403, {"Content-Type" => "text/plain"}, ["Invalid URL"]]
    end
  end

  def new(app)
    @app = app
  end
end

# app = Rack::ReverseProxy.new
# app.send :reverse_proxy, %r{/pt/(.*)$}, "#{SVN_HOST}/#{SVN_HOST_PATH}/$1"
# use app
# use Rack::ReverseProxy do
#   reverse_proxy %r{/pt/(.*)$}, "#{SVN_HOST}/#{SVN_HOST_PATH}/$1"
# end
run SvnAccess

