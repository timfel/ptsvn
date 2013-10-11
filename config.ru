require "rack/proxy"
require "rack/protection"

SVN_ROOT = File.expand_path("../svn", __FILE__)
REPO_PATH = "users"

SVN_HOST = "https://localhost:8443"
SVN_HOST_PATH = "/svn/pt1_2013/#{REPO_PATH}"


module SvnAccess
  extend self

  def exists?(path)
    system("svnlook pl #{SVN_ROOT} #{REPO_PATH}/#{path}")
  end

  def mkdir(path)
    system("svn mkdir #{SVN_HOST}/#{SVN_HOST_PATH} #{REPO_PATH}/#{path}")
  end

  def cat(path)
    `svnlook cat #{SVN_ROOT} #{REPO_PATH}/#{path}`
  end

  def accessible?(user, path)
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
    path_parts = path.split("/")
    unless path_parts[0] == user
    end
  end

  def ensure_svn(user)
    path = File.join(SVN_ROOT, user)
    Dir.mkdir(path) unless Dir.exist?(path)
  end

  def call(env)
    user = env["REMOTE_USER"].downcase
    ensure_svn(user)

    unless accessible?(user, env["PATH"])
      [403, {}, ""]
    else
      @app.call(env)
    end
  end

  def new(app)
    @app = app
  end
end

class LocalSvnProxy < Rack::Proxy
  def rewrite_env(env)
    # @http_host = env["HTTP_HOST"]
    # %w[HTTP_HOST REQUEST_URI].each do ||
    # end
    env["HTTP_HOST"] = SVN_HOST
  end

  def rewrite_response(triplet)
    status, headers, body = triplet
    # %w[Location Content-Location URI].each do |header|
    #   if headers[header]
    #     headers[header].gsub!("localhost", "#{@http_host}")
    #   end
    # end
    triplet
  end
end

use Rack::Protection, :except => :session_hijacking
use SvnAccess
run LocalSvnProxy.new
