namespace :cradle do
	namespace :dump_3char_struct do
	  desc "dump confirmed part to cradle"
	  task :confirmed_part => :environment
	  task :confirmed_part, :filename do |task, args|
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
	  
	  desc "dump undefined part to cradle"
	  task :undefined_part => :environment
	  task :undefined_part, :filename do |task, args|
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
			
			### 1. first set all existing words' state from NEW to INITIAL
			Initial_state = CnProperty.find_item_by_tree_string_or_array("tagging_state", "INITIAL").property_cat_id
			CnLexeme.update_all("tagging_state=#{Initial_state}")
			puts 'step 1 finished.'

			### 2. set words, which have internal structure right now, to category of "合成词-复合词-分支结构"
			Branching_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-分支结构").property_cat_id
			Pending_pos_state = CnProperty.find_item_by_tree_string_or_array("sth_tagging_state", "PENDING-POS").property_cat_id
			Word_category_property = CnNewProperty.find_by_property_string('word_category').id
			
			def create_word_category(ref_id, category_id)
				CnLexemeNewPropertyItem.create!(:property_id => Word_category_property, :ref_id => ref_id, :category => category_id)
			end
			
			CnSynthetic.find(:all, :conditions => ["sth_tagging_state = ?", Pending_pos_state]).map(&:sth_ref_id).each do |lexeme_id|
				begin
					create_word_category(lexeme_id, Branching_state)
				end
			end
			puts 'step 2 finished.'

			### 3. add word category
			Abb_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-缩略词").property_cat_id
			Dup_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-重叠结构").property_cat_id
			Fact_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-固定用法").property_cat_id
			Idiom_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-俗语").property_cat_id
			Single_multi_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-多音节").property_cat_id
			Term_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-术语").property_cat_id
			Single_foreign_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-外来词").property_cat_id
			Merging_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-合并结构").property_cat_id
			Aliyan_user_id = 13


			Dictionary_field = '-' + CnProperty.find_item_by_tree_string_or_array("dictionary", ['NAIST-cndic', '2008']).property_cat_id.to_s + '-'
			New_state = CnProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
			NN_pos = CnProperty.find_item_by_tree_string_or_array("pos", "NN").property_cat_id
			
			def get_or_create_id(surface)
				temp = CnLexeme.find(:all, :conditions => ['surface = ?', surface])
				if temp.blank?
					new_lexeme = CnLexeme.new
					new_lexeme.id = CnLexeme.maximum(:id) + 1
					new_lexeme.surface = surface
					new_lexeme.dictionary = Dictionary_field
					new_lexeme.tagging_state = New_state
					new_lexeme.created_by = Aliyan_user_id
					new_lexeme.pos = NN_pos
					new_lexeme.save!
					return new_lexeme.id
				else
					return temp[0].id
				end
			end
			
			def register_structure(type, surface, ref_id)
				surface =~ /(.)(.)(.)/u
				case type
				when 'left' then parts = [$1+$2, $3]
				when 'right' then parts = [$1, $2+$3]
				when 'flat' then parts = [$1, $2, $3]
				when 'merging_front' then parts = [$1+$2, $1+$3]
				when 'merging_end' then parts = [$1+$3, $2+$3]
				end
				struct = '-' + parts.inject([]){|id_array, chars| id_array << get_or_create_id(chars) }.join('-,-') + '-'
        CnSynthetic.create!(:sth_ref_id => ref_id,
        										:sth_meta_id => 0,
                            :sth_struct => struct,
                            :sth_surface => surface,
                            :sth_tagging_state => Pending_pos_state,
                            :modified_by => Aliyan_user_id)
			end
			
	    File.open(dump_file) do |file|
	    	file.each do |line|
		      temp = line.chomp.split(',')
		      begin
		      	case temp[3]
		      	when 'A' then create_word_category(temp[0].to_i, Abb_state)
		      	when 'D' then create_word_category(temp[0].to_i, Dup_state)
						when 'F' then create_word_category(temp[0].to_i, Fact_state)
						when 'G' then create_word_category(temp[0].to_i, Idiom_state)
						when 'S' then create_word_category(temp[0].to_i, Single_multi_state)
						when 'T' then create_word_category(temp[0].to_i, Term_state)
						when 'W' then next
						when 'LB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('left', temp[1], temp[0])
						when 'RB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('right', temp[1], temp[0])
						when 'FB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('flat', temp[1], temp[0])
						when 'MF'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_front', temp[1], temp[0])
						when 'ML'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_end', temp[1], temp[0])
						else
							create_word_category(temp[0].to_i, Single_foreign_state)
						end
		      end
				end
	    end
	    puts 'All finished.'
	  end

	  desc "dump unsure part to cradle"
	  task :unsure_part => :environment
	  task :unsure_part, :filename do |task, args|
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
			### 1. set all global variables
			Single_foreign_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-外来词").property_cat_id
			Dup_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-重叠结构").property_cat_id
			Branching_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-分支结构").property_cat_id
			Merging_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-合并结构").property_cat_id
			Single_multi_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-多音节").property_cat_id
			Term_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-术语").property_cat_id
			Aliyan_user_id = 13
			Dictionary_field = '-' + CnProperty.find_item_by_tree_string_or_array("dictionary", ['NAIST-cndic', '2008']).property_cat_id.to_s + '-'
			Pending_pos_state = CnProperty.find_item_by_tree_string_or_array("sth_tagging_state", "PENDING-POS").property_cat_id
			Word_category_property = CnNewProperty.find_by_property_string('word_category').id
			New_state = CnProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
			NN_pos = CnProperty.find_item_by_tree_string_or_array("pos", "NN").property_cat_id
			puts 'step 1 setting all global variables finished.'
			
			### 2. add structures
			def create_word_category(ref_id, category_id)
				CnLexemeNewPropertyItem.create!(:property_id => Word_category_property, :ref_id => ref_id, :category => category_id)
			end
			
			def get_or_create_id(surface)
				temp = CnLexeme.find(:all, :conditions => ['surface = ?', surface])
				if temp.blank?
					new_lexeme = CnLexeme.new
					new_lexeme.id = CnLexeme.maximum(:id) + 1
					new_lexeme.surface = surface
					new_lexeme.dictionary = Dictionary_field
					new_lexeme.tagging_state = New_state
					new_lexeme.created_by = Aliyan_user_id
					new_lexeme.pos = NN_pos
					new_lexeme.save!
					return new_lexeme.id
				else
					return temp[0].id
				end
			end

			def register_structure(type, surface, ref_id)
				surface =~ /(.)(.)(.)/u
				case type
				when 'left' then parts = [$1+$2, $3]
				when 'right' then parts = [$1, $2+$3]
				when 'flat' then parts = [$1, $2, $3]
				when 'merging_front' then parts = [$1+$2, $1+$3]
				when 'merging_end' then parts = [$1+$3, $2+$3]
				when 'merging_middle' then parts = [$1+$2, $2+$3]
				end
				struct = '-' + parts.inject([]){|id_array, chars| id_array << get_or_create_id(chars) }.join('-,-') + '-'
        CnSynthetic.create!(:sth_ref_id => ref_id,
        										:sth_meta_id => 0,
                            :sth_struct => struct,
                            :sth_surface => surface,
                            :sth_tagging_state => Pending_pos_state,
                            :modified_by => Aliyan_user_id)
			end

	    File.open(dump_file) do |file|
	    	file.each do |line|
		      temp = line.chomp.split(',')
		      begin
		      	case temp[3]
		      	when 'W' then next
		      	when 'D' then create_word_category(temp[0].to_i, Dup_state)
						when 'S' then create_word_category(temp[0].to_i, Single_multi_state)
						when 'T' then create_word_category(temp[0].to_i, Term_state)
						when 'LB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('left', temp[1], temp[0])
						when 'RB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('right', temp[1], temp[0])
						when 'FB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('flat', temp[1], temp[0])
						when 'MF'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_front', temp[1], temp[0])
						when 'ML'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_end', temp[1], temp[0])
						when 'MM'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_middle', temp[1], temp[0])
						else
							create_word_category(temp[0].to_i, Single_foreign_state)
						end
		      end
				end
	    end
	    puts 'All finished.'
		end

	  desc "dump nr_without_per part to cradle"
	  task :nr_without_per => :environment
	  task :nr_without_per, :filename do |task, args|
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
			### 1. set all global variables
			Single_foreign_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-外来词").property_cat_id
			Dup_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-重叠结构").property_cat_id
			Branching_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-分支结构").property_cat_id
			Merging_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-复合词-合并结构").property_cat_id
			Single_multi_state = CnProperty.find_item_by_tree_string_or_array("word_category", "单纯词-多音节").property_cat_id
			Abb_state = CnProperty.find_item_by_tree_string_or_array("word_category", "合成词-缩略词").property_cat_id
			Aliyan_user_id = 13
			Dictionary_field = '-' + CnProperty.find_item_by_tree_string_or_array("dictionary", ['NAIST-cndic', '2008']).property_cat_id.to_s + '-'
			Pending_pos_state = CnProperty.find_item_by_tree_string_or_array("sth_tagging_state", "PENDING-POS").property_cat_id
			Word_category_property = CnNewProperty.find_by_property_string('word_category').id
			New_state = CnProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
			NN_pos = CnProperty.find_item_by_tree_string_or_array("pos", "NN").property_cat_id
			puts 'step 1 setting all global variables finished.'
			
			### 2. add structures
			def create_word_category(ref_id, category_id)
				CnLexemeNewPropertyItem.create!(:property_id => Word_category_property, :ref_id => ref_id, :category => category_id)
			end
			
			def get_or_create_id(surface)
				temp = CnLexeme.find(:all, :conditions => ['surface = ?', surface])
				if temp.blank?
					new_lexeme = CnLexeme.new
					new_lexeme.id = CnLexeme.maximum(:id) + 1
					new_lexeme.surface = surface
					new_lexeme.dictionary = Dictionary_field
					new_lexeme.tagging_state = New_state
					new_lexeme.created_by = Aliyan_user_id
					new_lexeme.pos = NN_pos
					new_lexeme.save!
					return new_lexeme.id
				else
					return temp[0].id
				end
			end

			def register_structure(type, surface, ref_id)
				surface =~ /(.)(.)(.)/u
				case type
				when 'left' then parts = [$1+$2, $3]
				when 'right' then parts = [$1, $2+$3]
				when 'flat' then parts = [$1, $2, $3]
				when 'merging_end' then parts = [$1+$3, $2+$3]
				end
				struct = '-' + parts.inject([]){|id_array, chars| id_array << get_or_create_id(chars) }.join('-,-') + '-'
        CnSynthetic.create!(:sth_ref_id => ref_id,
        										:sth_meta_id => 0,
                            :sth_struct => struct,
                            :sth_surface => surface,
                            :sth_tagging_state => Pending_pos_state,
                            :modified_by => Aliyan_user_id)
			end

	    File.open(dump_file) do |file|
	    	file.each do |line|
		      temp = line.chomp.split(',')
		      begin
		      	case temp[5]
		      	when 'W' then next
		      	when 'A' then create_word_category(temp[0].to_i, Abb_state)
		      	when 'D' then create_word_category(temp[0].to_i, Dup_state)
						when 'S' then create_word_category(temp[0].to_i, Single_multi_state)
						when 'LB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('left', temp[1], temp[0])
						when 'RB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('right', temp[1], temp[0])
						when 'FB'
							create_word_category(temp[0].to_i, Branching_state)
							register_structure('flat', temp[1], temp[0])
						when 'ML'
							create_word_category(temp[0].to_i, Merging_state)
							register_structure('merging_end', temp[1], temp[0])
						else
							create_word_category(temp[0].to_i, Single_foreign_state)
						end
		      end
				end
	    end
	    puts 'All finished.'
		end
	end
end
