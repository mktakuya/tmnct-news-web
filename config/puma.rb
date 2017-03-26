root = "#{Dir.getwd}"

bind "unix:///tmp/tmnct-news.sock"
pidfile "#{root}/tmp/pids/puma.pid"
state_path "#{root}/tmp/pids/puma.state"
rackup "#{root}/config.ru"
