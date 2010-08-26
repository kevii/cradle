task :cradle do
	set :application, "cradle"
  set :branch, "master"
	set :deploy_to, "/home/jia-l/rails/#{application}"
end

task :seinan do
	set :application, "seinan"
  set :branch, "seinan"
	set :deploy_to, "/home/jia-l/rails/#{application}"
end

server "dahlia.naist.jp", :app, :web, :db, :primary => true	# set the server's role, equal to following

set :repository,  "/home/jia-l/git-repo/cradle.git"	# set repo URL
set :local_repository, "ssh://jia-l@dahlia.naist.jp/home/jia-l/git-repo/cradle.git"
set :scm, :git											# set source control management method
set :deploy_via, :remote_cache			# speed up the deploy process
set :base_path, "/home/jia-l/rails" # set base deploy path on the server

set :user, "jia-l"		# set ssh user
set :use_sudo, false  # do not use sudo
set :keep_releases, 5	#	set the number of old copies on server


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
	run "ln -s #{shared_path}/dumped_data #{release_path}/dumped_data"
 	run "ln -s #{shared_path}/user_dump_file #{release_path}/public/user_dump_file"
 	run "cp -f #{release_path}/public/javascripts/jsProgressBarHandler.js.example #{release_path}/public/javascripts/jsProgressBarHandler.js"
end

after "deploy", "restart_workling"
after "deploy", "update_crontab"
after "deploy", "deploy:cleanup"

desc "restart workling"
task :restart_workling do
	if application == 'cradle'
		3.times do |i|
		  run "RAILS_ENV=production #{release_path}/script/workling_client --number #{i+1} stop"
  		run "RAILS_ENV=production #{release_path}/script/workling_client --number #{i+1} start"
  	end
  end
end

desc "Update the crontab file"
task :update_crontab, :roles => :db do
  run "cd #{release_path} && whenever --update-crontab #{application}"
end