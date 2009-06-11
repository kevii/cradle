require 'date'

namespace :cradle do
  desc "backup database and clean up temporary file"
  task :maintenance => [:backup_database, :clean_temporay_file] do
  	
  end

	desc "backup database"
	task :backup_database do
		date_suffix = Date.today.to_s.delete("-")
		["cor-jp", "cor-cn"].each{|db_name|
			case db_name
			when "cor-jp"
				dump_file_path = "#{RAILS_ROOT}/dumped_data/japanese/"
			when "cor-cn"
				dump_file_path = "#{RAILS_ROOT}/dumped_data/chinese/"
			end
			all_db_file = []
			Dir.foreach(dump_file_path){|file| all_db_file << [dump_file_path + file, $1] if file=~/^#{db_name}-(\d+)\.sql$/}
      all_db_file = all_db_file.sort{|a,b| a[1].to_i <=> b[1].to_i}.reverse
      FileUtils.rm(all_db_file.last[0]) if all_db_file.size > 10
			`mysqldump --opt -ujia-l -prails #{db_name} > #{dump_file_path + db_name}-#{date_suffix}.sql`
		}
	end

	desc "clean up temporary file"
	task :clean_temporay_file do
    `rm -rf #{RAILS_ROOT}/public/user_dump_file/*`
    `rm -rf #{RAILS_ROOT}/log/dump_data_workers:dump_data:*`
	end

end