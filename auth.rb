#! /usr/bin/ruby

LOG = File.open("/tmp/authlog", "a+")
def log(str)
  LOG.puts("#{Time.now} #{str}")
  LOG.flush
end

SVN_ROOT = File.expand_path("../svn", __FILE__)
REPO_PATH = "users"
SVN_HOST = "http://localhost:8443"
SVN_HOST_PATH = "svn/pt1_2013"

module SvnAccess
  extend self

  def exists?(path)
    system("svnlook pl #{SVN_ROOT} #{REPO_PATH}/#{path}")
  end

  def cat(path)
    `svnlook cat #{SVN_ROOT} #{REPO_PATH}/#{path}`
  end

  def accessible?(user, path)
    log path
    # don't break out of sandbox
    return false unless File.expand_path(path, "/") =~ /^\/#{user}/

    return true if user_folder?(user, path)

    path_parts = path.split("/")
    partner = path_parts[0]

    [[user, partner], [partner, user]].each do |this, other|
      if exists?("#{this}/partner")
        name = cat("#{this}/partner").split(/\r|\n/).first
        return false unless name == other
      else
        return false
      end
    end
  end

  def user_folder?(user, path)
    path_parts = path.split("/").reject(&:empty?)
    log path_parts
    log path_parts[0] == user
    path_parts[0] == user
  end

  def ensure_svn(user)
    mkdir(user) unless exists?(user)
  end

  def authorize
    log ENV["USER"].inspect
    log ENV.inspect
    user = ENV["USER"].downcase
    return false if user.empty?
    ensure_svn(user)

    log user
    log ENV["URI"]
    path = ENV["URI"].sub("/#{SVN_HOST_PATH}", "")
    log path
    if path.start_with?("/!svn")
      path = "/" + path.split("/")[4..-1].join("/")
    end
    log path
    return true if path == "/"
    return false unless path.start_with?("/users")
    path.sub!("/users", "")
    log path

    return accessible?(user, path)
  end
end

SvnAccess.authorize ? exit(0) : exit(1)
