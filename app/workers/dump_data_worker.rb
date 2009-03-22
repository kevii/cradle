class DumpDataWorker < Workling::Base
  include CradleModule
	include SearchModule

	def dump_data(options)
		case options[:domain]
		when 'jp'
			id_array = find_all_ids(:dynamic_lexeme_condition => options[:dynamic_lexeme_condition],
															:dynamic_synthetic_condition => options[:dynamic_synthetic_condition],
															:static_condition => options[:static_condition],
															:simple_search => options[:simple_search],
															:dependency => options[:dependency],
															:domain => "jp")
      lexeme_class = 'JpLexeme'
      first_line = "出力条件： "+options[:show_conditions].delete('&nbsp;')
      header, syn_list = generate_header_and_syn_list(:section_list=>options[:section_list], :domain=>'jp')
      field_list = header.map{|item| item[0]}.join("\t")
    when 'cn'
			id_array = find_all_ids(:dynamic_lexeme_condition => options[:dynamic_lexeme_condition],
															:dynamic_synthetic_condition => options[:dynamic_synthetic_condition],
															:static_condition => options[:static_condition],
															:simple_search => options[:simple_search],
															:dependency => options[:dependency],
															:domain => "cn")
      lexeme_class = 'CnLexeme'
      first_line = "输出条件： "+options[:show_conditions].delete('&nbsp;')
      header, syn_list = generate_header_and_syn_list(:section_list=>options[:section_list], :domain=>'cn')
      field_list = header.map{|item| item[0]}.join("\t")
    when 'en'
#       id_array = find_all_en_ids()
      lexeme_class = 'EnLexeme'
    end
    whole_number = id_array.size
    step = (whole_number.to_f/100.0).round
    start_index = 0
    each_part = 100
    count = 0
    file_path = 'user_dump_file/' + Time.now.to_s(:db).gsub(/[^\d]/, '-')
    output_file = File.open(RAILS_ROOT+'/public/'+file_path, "w")
    output_file.puts first_line
    output_file.puts field_list
    while(count < 100) do
      if each_part > whole_number
        dump_to_file(:result_array=>lexeme_class.constantize.find(id_array), :file_handler=>output_file,
                     :header=>header, :syn_list=>syn_list, :domain=>options[:domain])
        count = 100
      else
        end_index = start_index+each_part
        end_index = whole_number-1 if end_index > whole_number-1
        dump_to_file(:result_array=>lexeme_class.constantize.find(id_array[start_index..end_index]),
                     :file_handler=>output_file, :header=>header, :syn_list=>syn_list, :domain=>options[:domain])
        start_index = end_index+1
        count = start_index / step
        count = 100 if start_index == whole_number
        count = 1 if count < 1
      end
      Workling::Return::Store.set(options[:uid], count.to_s)
    end
    output_file.close
    Workling::Return::Store.set(options[:uid], options[:prefix]+file_path)
  end

	private
	def find_all_ids(options)
		final_id_arrays = get_search_collection(options, 'all').map(&:id)
    if options[:dependency].blank?
    	return final_id_arrays.uniq.sort
    else
    	temp_id_arrays = final_id_arrays.dup
    	return final_id_arrays.inject(temp_id_arrays){|id_arrays, index_id|
    		id_arrays.concat(find_ids_with_dependency(index_id, id_arrays, options[:domain])).uniq.sort
    	}
    end
  end
  
  def find_ids_with_dependency(id, original_ids_array, domain)
		if verify_domain(domain)['Lexeme'].constantize.find(id).struct.blank?
			return []
		else
    	dependency_ids = verify_domain(domain)['Synthetic'].constantize.find(:all, :conditions=>["sth_ref_id=?", id]).map(&:sth_struct).inject([]){|id_array, item| item.split(',').map{|temp| temp[1..-2]}.each{|temp_string| id_array << temp_string.to_i if temp_string =~ /^\d+$/}; id_array}
  		dependency_ids.dup.each{|item|
		 		if original_ids_array.include?(item)
	  			next
	  		else
	  			dependency_ids.concat(find_ids_with_dependency(item, original_ids_array, domain))
	  		end
	  	}
			return dependency_ids.uniq.sort
		end
  end
  
  def generate_header_and_syn_list(options)
    case options[:domain]
    when "jp"
      header = [['ID','id', 'lexeme', nil]]
      syn_string = []
      syn_list = []
      options[:section_list].each{|item|
        item =~ /^(\d+)_(.*)/
        index = $1.to_i
        property_string = $2
        type = nil
        section = nil
        if JpNewProperty.exists?(:property_string=>property_string)
          temp = JpNewProperty.find_by_property_string(property_string)
          if temp.section == 'lexeme'
            human_name = temp.human_name
            section = temp.section
            type = temp.type_field
          else
            syn_string << temp.human_name+':'+property_string
            syn_list << [property_string, temp.id, temp.type_field]
            next
          end
        else
          case property_string
            when "sth_log"
              human_name = '構造'+initial_property_name('jp')['log']
              section = 'synthetic'
              type = 'text'
            when "sth_modified_by"
              human_name = '構造'+initial_property_name('jp')['modified_by']
              section = 'synthetic'
              type = 'user'
            when "sth_updated_at"
              human_name = '構造'+initial_property_name('jp')['updated_at']
              section = 'synthetic'
              type = 'time'
            when "sth_struct"
              human_name = initial_property_name('jp')["sth_struct"]
              section = 'synthetic'
              type = nil
            when "sth_tagging_state"
              human_name = '構造'+initial_property_name('jp')["sth_tagging_state"]
              section = 'synthetic'
              type = 'category'
            else
              human_name = initial_property_name('jp')[property_string]
              section = 'lexeme'
              if ['surface', 'reading', 'pronunciation', 'log'].include?(property_string)
                type = 'text'
              elsif ['pos', 'ctype', 'cform', 'tagging_state'].include?(property_string)
                type = 'category'
              elsif property_string == 'updated_at'
                type = 'time'
              elsif ['created_by', 'modified_by'].include?(property_string)
                type = 'user'
              end
          end
        end
        header[index] = [human_name, property_string, section, type]
      }
      if header.include?(['Base', 'base_id', 'lexeme', nil])
        index = header.index(['Base', 'base_id', 'lexeme', nil])
        header[index] = ['Base', 'base.surface', 'lexeme', nil]
        header.insert(index+1, ['Base_id', 'base_id', 'lexeme', nil])
      end
      if header.include?(['Root', 'root_id', 'lexeme', nil])
        index = header.index(['Root', 'root_id', 'lexeme', nil])
        header[index] = ['Root', 'root.surface', 'lexeme', nil]
        header.insert(index+1, ['Root_value', 'root_id', 'lexeme', nil])
      end
      if header.include?([initial_property_name('jp')["sth_struct"], 'sth_struct', 'synthetic', nil]) and not syn_string.blank?
        index = header.index([initial_property_name('jp')["sth_struct"], 'sth_struct', 'synthetic', nil])
        header[index] = [initial_property_name('jp')["sth_struct"]+'('+ syn_string.join(", ") +')', 'sth_struct', 'synthetic', nil]
      elsif not header.include?([initial_property_name('jp')["sth_struct"], 'sth_struct', 'synthetic', nil]) and not syn_string.blank?
        syn_list = []
      end
    when "cn"
      header = [['ID','id', 'lexeme', nil]]
      syn_string = []
      syn_list = []
      options[:section_list].each{|item|
        item =~ /^(\d+)_(.*)/
        index = $1.to_i
        property_string = $2
        type = nil
        section = nil
        if CnNewProperty.exists?(:property_string=>property_string)
          temp = CnNewProperty.find_by_property_string(property_string)
          if temp.section == 'lexeme'
            human_name = temp.human_name
            section = temp.section
            type = temp.type_field
          else
            syn_string << temp.human_name+':'+property_string
            syn_list << [property_string, temp.id, temp.type_field]
            next
          end
        else
          case property_string
            when "sth_log"
              human_name = '结构'+initial_property_name('cn')['log']
              section = 'synthetic'
              type = 'text'
            when "sth_modified_by"
              human_name = '结构'+initial_property_name('cn')['modified_by']
              section = 'synthetic'
              type = 'user'
            when "sth_updated_at"
              human_name = '结构'+initial_property_name('cn')['updated_at']
              section = 'synthetic'
              type = 'time'
            when "sth_struct"
              human_name = initial_property_name('cn')["sth_struct"]
              section = 'synthetic'
              type = nil
            when "sth_tagging_state"
              human_name = '结构'+initial_property_name('cn')["sth_tagging_state"]
              section = 'synthetic'
              type = 'category'
            else
              human_name = initial_property_name('cn')[property_string]
              section = 'lexeme'
              if ['surface', 'reading', 'log'].include?(property_string)
                type = 'text'
              elsif ['pos', 'tagging_state'].include?(property_string)
                type = 'category'
              elsif property_string == 'updated_at'
                type = 'time'
              elsif ['created_by', 'modified_by'].include?(property_string)
                type = 'user'
              end
          end
        end
        header[index] = [human_name, property_string, section, type]
      }
      if header.include?([initial_property_name('cn')["sth_struct"], 'sth_struct', 'synthetic', nil]) and not syn_string.blank?
        index = header.index([initial_property_name('cn')["sth_struct"], 'sth_struct', 'synthetic', nil])
        header[index] = [initial_property_name('cn')["sth_struct"]+'('+ syn_string.join(", ") +')', 'sth_struct', 'synthetic', nil]
      elsif not header.include?([initial_property_name('cn')["sth_struct"], 'sth_struct', 'synthetic', nil]) and not syn_string.blank?
        syn_list = []
      end
    when "en"
    end
    return header.compact, syn_list
  end
  
  def dump_to_file(options)
    if options[:domain] == 'jp'
      options[:result_array].each{|lexeme|
        temp_line = []
        options[:header].each{|item|
          if item[2] == 'synthetic'
            if lexeme.struct.blank?
              temp_line << ""
            else
              case item[1]
                when "sth_log"
                  temp_line << lexeme.struct.log
                when "sth_modified_by"
                  temp_line << lexeme.struct.annotator.name
                when "sth_updated_at"
                  temp_line << lexeme.struct.updated_at.to_formatted_s(:number)
                when "sth_tagging_state"
                  temp_line << lexeme.struct.sth_tagging_state_item.tree_string
                when "sth_struct"
                  temp_line << lexeme.struct.get_dump_string(options[:syn_list])
              end
            end
          elsif item[2] == 'lexeme'
            case item[3]
              when "category"
                temp_id = eval('lexeme.'+item[1])
                temp_id.blank? ? temp_line << "" : temp_line << JpProperty.find(:first, :conditions=>["property_string=? and property_cat_id=?", item[1], temp_id]).tree_string
              when "text"
                temp_line << eval('lexeme.'+item[1])
              when "time"
                temp_line << eval('lexeme.'+item[1]).to_formatted_s(:number)
              when "user"
                temp_line << User.find(eval('lexeme.'+item[1])).name
              else  ##nil      base_id, base.surface, root_id, root.surface, id, dictionary
                case item[1]
                  when 'base_id', 'base.surface' , 'id', 'root_id'
                    temp_line << eval('lexeme.'+item[1])
                  when 'root.surface'
                    if lexeme.root_id.blank? or lexeme.root.blank?
                      temp_line << ''
                    else
                      temp_line << lexeme.root.surface
                    end
                  when 'dictionary'
                    temp_line << lexeme.dictionary_item.list.map{|item| JpProperty.find(:first, :conditions=>["property_string='dictionary' and property_cat_id=?", item]).tree_string}.join(',')
                end
            end
          end
        }
        options[:file_handler].puts temp_line.join("\t")
      }
    elsif options[:domain] == 'cn'
      options[:result_array].each{|lexeme|
        temp_line = []
        options[:header].each{|item|
          if item[2] == 'synthetic'
            if lexeme.struct.blank?
              temp_line << ""
            else
              case item[1]
              when "sth_log"
                temp_line << lexeme.struct.log
              when "sth_modified_by"
                temp_line << lexeme.struct.annotator.name
              when "sth_updated_at"
                temp_line << lexeme.struct.updated_at.to_formatted_s(:number)
              when "sth_tagging_state"
                temp_line << lexeme.struct.sth_tagging_state_item.tree_string
              when "sth_struct"
                temp_line << lexeme.struct.get_dump_string(options[:syn_list])
              end
            end
          elsif item[2] == 'lexeme'
            case item[3]
            when "category"
              temp_id = eval('lexeme.'+item[1])
              temp_id.blank? ? temp_line << "" : temp_line << CnProperty.find(:first, :conditions=>["property_string=? and property_cat_id=?", item[1], temp_id]).tree_string
            when "text"
              temp_line << eval('lexeme.'+item[1])
            when "time"
              temp_line << eval('lexeme.'+item[1]).to_formatted_s(:number)
            when "user"
              temp_line << User.find(eval('lexeme.'+item[1])).name
            else  ##nil      id, dictionary
              case item[1]
              when 'id'
                temp_line << eval('lexeme.'+item[1])
              when 'dictionary'
                temp_line << lexeme.dictionary_item.list.map{|item| CnProperty.find(:first, :conditions=>["property_string='dictionary' and property_cat_id=?", item]).tree_string}.join(',')
              end
            end
          end
        }
        options[:file_handler].puts temp_line.join("\t")
      }
    elsif options[:domain] == 'en'
      
    end
  end
  
end