# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
# documentation.
worker_processes 1

# listen on both a Unix domain socket and a TCP port,
# we use a shorter backlog for quicker failover when busy
listen "/home/deployer/deploy_test/shared/tmp/sockets/deploy_test.socket", backlog: 64

# Preload our app for more speed
preload_app true

# nuke workers after 30 seconds instead of 60 seconds (the default)
# new plan - nuke workers after 90 seconds to allow for large uploads
timeout 30

pid "/home/deployer/deploy_test/shared/tmp/pids/unicorn.deploy_test.pid"

# Help ensure your application will always spawn in the symlinked
# "current" directory that Capistrano sets up.
working_directory "/home/deployer/deploy_test/current"

# feel free to point this anywhere accessible on the filesystem
shared_path = "/home/deployer/deploy_test/shared"
user 'deployer' #, 'www-data'

stderr_path "#{shared_path}/log/unicorn.stderr.log"
stdout_path "#{shared_path}/log/unicorn.stdout.log"

before_fork do |server, worker|
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
  end

  # Before forking, kill the master process that belongs to the .oldbin PID.
  # This enables 0 downtime deploys.
  old_pid = "/home/deployer/deploy_test/shared/tmp/pids/unicorn.deploy_test.pid.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  # the following is *required* for Rails + "preload_app true",
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end

end
