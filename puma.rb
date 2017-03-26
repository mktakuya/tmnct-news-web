root = "#{Dir.getwd}"

bind "unix://#{root}/tmp/pids/puma.sock"
pidfile "#{root}/tmp/pids/puma.pid"
state_path "#{root}/tmp/pids/puma.state"
rackup "#{root}/config.ru"

