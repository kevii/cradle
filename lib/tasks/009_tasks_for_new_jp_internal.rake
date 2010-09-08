STDOUT.sync = true

namespace :cradle do
  desc "import structures"
  task :import_web_lsd_structures, :file_path, :needs => :environment do |t, args|
		def convert_to_ary(temp_str, max_level, current_level = 1)
		  if current_level >= max_level
		    if temp_str.include?("LEVEL#{current_level}")
		      temp_str.split("LEVEL#{current_level}")
		    else
		      temp_str
		    end
		  else
		    if temp_str.include?("LEVEL#{current_level}")
		      temp_str.split("LEVEL#{current_level}").inject([]) do |temp_ary, item|
		        temp_ary << convert_to_ary(item, max_level, (current_level + 1))
		      end
		    else
		      temp_str
		    end
		  end
		end
		
		def convert_to_hash(struct)
		  new_ary = []
		  struct.each_with_index do |item, index|
		    if index == 0
		      new_ary << item.inject({}) do |temp_hash, inner_item|
		        key, value = inner_item.split('=')
		        temp_hash[key] = value
		        temp_hash
		      end
		    else
		      case item
		      when Array
		        new_ary << convert_to_hash(item)
		      else
		        value, key = item.split(/\[|\]/)
		        new_ary << {key => value}
		      end
		    end
		  end
		  return new_ary
		end
		
		def compute_struct(temp_str)
		  temp_chars = ''
		  level = 1
		  max_level = 0
		  origin_ary = temp_str.scan(/./)
		  origin_ary.each_with_index do |char, index|
		    case char
		    when '('
		      level += 1
		      if level > max_level
		        max_level = level
		      end
		    when ')'
		      level -= 1
		    when ','
		      temp_chars << "LEVEL#{level}"
		    else
		      temp_chars << char
		    end
		  end
		  convert_to_hash(convert_to_ary(temp_chars, max_level))
		end
		
		current_line = nil
		max_new_property_items_id = JpSyntheticNewPropertyItem.maximum(:id)
		max_structure_id = JpSynthetic.maximum(:id)
		new_tagging_state = JpProperty.find_item_by_tree_string_or_array("sth_tagging_state", "CHECKED").property_cat_id
		modified_by = User.find_by_name('yamada').id
		begin
			File.open(args[:file_path]).each do |line|
				current_line = line
	    	temp = line.chomp.split("\t")
	    	lexeme = JpLexeme.find(temp[0].to_i)
	      JpSynthetic.destroy_struct(lexeme.id)
				JpSynthetic.load_struct_from_json({
					:lexeme					=> lexeme,
					:json_struct		=> compute_struct(temp[2]),
					:tagging_state	=> new_tagging_state,
					:log						=> nil,
					:modified_by		=> modified_by
				})
			end
		rescue Exception => e
			JpSyntheticNewPropertyItem.delete_all("id > #{max_new_property_items_id}")
			JpSynthetic.delete_all("id > #{max_structure_id}")
			puts e.message
			puts current_line
			print e.backtrace.join("\n")
		else
			puts 'finished'
	  end
	end
end