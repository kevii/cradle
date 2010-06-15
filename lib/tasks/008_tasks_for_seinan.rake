STDOUT.sync = true

namespace :seinan do
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
	
  desc "import seinan data"
  task :import_seinan_data => :environment do |task, args|
  	temp = 2
		debugger
		temp = 1
	end
end