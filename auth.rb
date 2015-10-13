#! /usr/bin/ruby

LOG = File.open("/tmp/authlog", "a+")
def log(str)
  LOG.puts("#{Time.now} #{str}")
  LOG.flush
end

SVN_ROOT = File.expand_path("../svn", __FILE__)
REPO_PATH = "users"
SVN_HOST = "http://localhost:8443"
SVN_HOST_PATH = "hirschfeld/pt1_2015"

module SvnAccess
  extend self

  def exists?(path)
    log("exists?: svnlook pl #{SVN_ROOT} #{REPO_PATH}/#{path}")
    system("svnlook pl #{SVN_ROOT} #{REPO_PATH}/#{path} 2>&1 >/dev/null")
  end

  def cat(path)
    log("cat: svnlook cat \"#{SVN_ROOT}\" \"#{REPO_PATH}/#{path}\"")
    content = `svnlook cat "#{SVN_ROOT}" "#{REPO_PATH}/#{path}"`
    log("cat: got #{content[0,25]}")
    content
  end

  def accessible?(user, path)
    log("accessible?: path: #{path}")
    # don't break out of sandbox
    # return false unless File.expand_path(path, "/") =~ /^\/#{user}/

    return true if user_folder?(user, path)

    path_parts = path.split("/")
    partner = path_parts[1]
    log "Partner: #{partner}"

    [[user, partner], [partner, user]].each do |this, other|
      log("partner test: #{this}, #{other}")
      if exists?("#{this}/partner")
        log "partner-file exists"
        name = cat("#{this}/partner").split(/\r|\n/).first
        log "partner-file has #{name}"
        return false unless name == other
      else
        return false
      end
    end
    log("partner is ok")
    return true
  end

  def user_folder?(user, path)
    path_parts = path.split("/").reject(&:empty?)
    log("user_folder?: in #{path_parts}")
    is_user_folder = path_parts[0] == user
    log("user_folder?: #{is_user_folder}")
    is_user_folder
  end

  def authorize
    log("authorize: USER: #{ENV["USER"].inspect}")
    user = ENV["USER"].downcase
    return false if user.empty?

    log("authorize: user is #{user}")
    return false unless exists?(user)
    log("auhtorize: URI: #{ENV["URI"]}")
    path = ENV["URI"].sub("/#{SVN_HOST_PATH}", "")
    log("authorize: is path: #{path}")
    if path.start_with?("/!svn")
      path.sub!("/!svn", "")
      if path =~ /^\/(bc|ver|wrk)/ # we're looking at a path under a particular revision, need to check it
        path = "/" + path.split("/")[3..-1].join("/")
      else
        log "meta"
        return true # just metadata
      end
    end
    log("authorize: svn-free path: #{path}")
    return true if path == "/users"
    return true if path == "/"
    return false unless path.start_with?("/users")
    path.sub!("/users", "")
    log("authorize: user-local path: #{path}")

    return accessible?(user, path)
  end
end

admins = File.readlines("/var/svn/authfile")[1].split(/[=,]/)[1..-1].map(&:strip)
#log admins
exit(0) if admins.include?(ENV["USER"])
if SvnAccess.authorize 
    log "> yes\n"
    exit(0)
else
    log "> no\n"
    exit(1)
end

