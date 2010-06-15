set :application, "cradle"	# set application name

server "dahlia.naist.jp", :app, :web, :db, :primary => true	# set the server's role, equal to following

set :repository,  "/home/jia-l/git-repo/cradle.git"	# set repo URL
set :local_repository, "ssh://jia-l@dahlia.naist.jp/home/jia-l/git-repo/cradle.git"
set :scm, :git											# set source control management method
set :deploy_via, :remote_cache			# speed up the deploy process

set :user, "jia-l"		# set ssh user
set :use_sudo, false  # do not use sudo
set :keep_releases, 5	#	set the number of old copies on server


task :cradle do
  set :base_path, "/home/jia-l/rails" # set base deploy path on the server
  set :deploy_to, "/home/jia-l/rails/#{application}"    # set the detailed deploy path of this app
  set :branch, "master"
end

task :seinan do
  set :base_path, "/home/jia-l/rails/" # set base deploy path on the server
  set :deploy_to, "/home/jia-l/rails/seinan"    # set the detailed deploy path of this app
  set :branch, "seinan"
end

namespace :deploy do
  # Overrides for Phusion Passenger
  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

after "deploy:update_code" do
	run "cp -f #{shared_path}/system/database.yml #{release_path}/config/database.yml"
	run "ln -s #{shared_path}/initial_lexeme_property #{release_path}/initial_lexeme_property"
	run "ln -s #{shared_path}/dumped_data #{release_path}/dumped_data"
 	run "ln -s #{shared_path}/user_dump_file #{release_path}/public/user_dump_file"
 	run "cp -f #{release_path}/public/javascripts/jsProgressBarHandler.js.example #{release_path}/public/javascripts/jsProgressBarHandler.js"
end

after "deploy", "restart_workling"
after "deploy", "update_crontab"
after "deploy", "deploy:cleanup"

desc "restart workling"
task :restart_workling do
  sudo "RAILS_ENV=production #{release_path}/script/workling_client stop"
  sudo "RAILS_ENV=production #{release_path}/script/workling_client start"
end

desc "Update the crontab file"
task :update_crontab, :roles => :db do
  run "cd #{release_path} && whenever --update-crontab #{application}"
end