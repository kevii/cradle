STDOUT.sync = true

namespace :cradle do
#   desc "remove dictionaries except naist-jdic"
#   task :remove_dics => :environment
#   task :remove_dics, :filename do |task, args|
#     ActiveRecord::Base.logger.silence do
# 
# 			dictionary = "#{RAILS_ROOT}/dumped_data/japanese/pne.kw.freq.tab"
# 
# 
# 		end
# 	end
	
  desc "import nansei data"
  task :import_nansei_data => :environment do |task, args|
		debugger
		temp = 1
	end
end