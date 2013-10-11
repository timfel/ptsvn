require "rack/proxy"
require "rack/protection"

VERSION = "0.0.1"
SVN_ROOT = File.expand_path(__FILE__, "..")

module SvnAccess
  extend self

  def accessible?(user, path)
    return true if user_folder?(user, path)

    path_parts = path.split("/")
    partner = path_parts[0]

    [[user, partner], [partner, user]].each do |this, other|
      partner_file = File.join(SVN_ROOT, this, "partner")
      if File.exist?(partner_file)
        name, * = File.readlines(partner_file, 1)
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
    @http_host = env["HTTP_HOST"]
    %w[HTTP_HOST REQUEST_URI].each do ||
    end
    env["HTTP_HOST"] = "http://localhost"
  end

  def rewrite_response(triplet)
    status, headers, body = triplet
    %w[Location Content-Location URI].each do |header|
      if headers[header]
        headers[header].gsub!("localhost", "#{@http_host}")
      end
    end
    headers["X-PTSVN"] = VERSION
    triplet
  end
end

use Rack::Protection, :except => :session_hijacking
use SvnAccess
run LocalSvnProxy.new
