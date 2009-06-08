namespace :cradle do
  desc "dump_confirmed_to_cradle"
  task :dump_3char_struct => :environment
  task :dump_3char_struct, :filename do |task, args|
    config = ActiveRecord::Base.configurations["chinese"]
    ActiveRecord::Base.establish_connection(config)
    if File.exist?("#{RAILS_ROOT}/dumped_data/chinese/#{args[:filename]}")
      dump_file = "#{RAILS_ROOT}/dumped_data/chinese/#{args[:filename]}"
    elsif File.exist?(args[:filename])
      dump_file = args[:filename]
    else
      puts "No file found"
      return
    end

    pending_pos_state = CnProperty.find_item_by_tree_string_or_array("sth_tagging_state", "PENDING-POS").property_cat_id

    File.open(dump_file) do |file|
    	file.each do |line|
	      temp = line.chomp.split("\t")
	      begin
	        sth_struct = "-#{temp[3]}-,-#{temp[4]}-"
	        CnSynthetic.transaction do
		        CnSynthetic.create!(:sth_ref_id => temp[0],
		                            :sth_meta_id => 0,
		                            :sth_struct => sth_struct,
		                            :sth_surface => temp[1],
		                            :sth_tagging_state => pending_pos_state,
		                            :modified_by => 5)
		      end
	      end
			end
    end
  end
end
