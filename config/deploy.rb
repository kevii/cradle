set :application, "Cradle"	# set application name

set :repository,  "/home/jia-l/git-repo/Cradle.git"	# set repo URL
set :local_repository, "ssh://jia-l@dahlia.naist.jp/home/jia-l/git-repo/Cradle.git"
set :server_name, "dahlia.naist.jp"	# set server name

set :scm, "git"											# set source control management method
set :deploy_via, :remote_cache			# speed up the deploy process
#set :branch, "master"								# set checking out branch
set :base_path, "/home/jia-l/rails"	# set base deploy path on the server
set :deploy_to, "/home/jia-l/rails/#{application}"		# set the detailed deploy path of this app

set :user, "jia-l"		# set ssh user
set :runner, "jia-l"	#
#set :use_sudo, false	# do not use sudo
default_run_options[:pty] = true
set :keep_releases, 5	#	set the number of old copies on server

server "dahlia.naist.jp", :app, :web, :db, :primary => true	# set the server's role, equal to following

namespace :deploy do

# Overrides for Phusion Passenger
  desc "Restarting mod_rails with restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_path}/tmp/restart.txt"
  end

  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
  
## executed after deploy:update
	desc "Create config files and symbol links to current app."
	task :after_update_code, :roles => :app do
  	run "cp -f #{release_path}/config/database.yml.example #{release_path}/config/database.yml"
  	run "ln -s #{shared_path}/initial_lexeme_property #{release_path}/initial_lexeme_property"
  	run "ln -s #{shared_path}/dumped_data #{release_path}/dumped_data"
  	run "ln -s #{shared_path}/user_dump_file #{release_path}/public/user_dump_file"
  	run "cp -f #{release_path}/public/javascripts/jsProgressBarHandler.js.example #{release_path}/public/javascripts/jsProgressBarHandler.js"
	end

  desc "Run this after every successful deployment" 
  task :after_default do cleanup end
end

after "deploy", "restart_workling"
after "deploy", "update_crontab"

desc "restart workling"
task :restart_workling do
  sudo "RAILS_ENV=production #{release_path}/script/workling_client stop"
  sudo "RAILS_ENV=production #{release_path}/script/workling_client start"
end

desc "Update the crontab file"
task :update_crontab, :roles => :db do
  run "cd #{release_path} && whenever --update-crontab #{application}"
end