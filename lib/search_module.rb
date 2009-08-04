module SearchModule
  def search
    simple_search = "true"
    if params[:search_type].blank?	# for both jp and cn
      search_conditions, show_conditions, notice = verification( params )
      unless notice == ""
        flash[:notice_err] = notice
        redirect_to :action => 'index'
        return
      end
      static_condition = search_conditions[0].join(" and ")
      dynamic_lexeme_condition = search_conditions[1].join(" **and** ")
      simple_search = "false" if search_conditions[1].size > 1
      dynamic_synthetic_condition = search_conditions[2].join(" **and** ")
      simple_search = "false" if search_conditions[2].size > 1
    elsif params[:domain] == 'jp' and params[:search_type] == "base"	# only for jp
      show_conditions = "Base="+JpLexeme.find(params[:base_id].to_i).surface
      static_condition = " jp_lexemes.base_id = #{params[:base_id]} "
      dynamic_lexeme_condition = nil
      dynamic_synthetic_condition = nil
      flash[:notice] = flash[:notice]
    elsif params[:domain] == 'jp' and params[:search_type] == "root"	# only for jp
      if (params[:root_id] =~ /^R/) != nil
        show_conditions = "Same Root"
      else
        show_conditions = "Root="+JpLexeme.find(params[:root_id].to_i).surface
      end
      static_condition = " jp_lexemes.root_id = '#{params[:root_id]}' "
      dynamic_lexeme_condition = nil
      dynamic_synthetic_condition = nil
      flash[:notice] = flash[:notice]
    end
    redirect_to :action => "list", :static_condition=>static_condition,
                                   :simple_search=>simple_search,
                                   :dynamic_lexeme_condition=>dynamic_lexeme_condition,
                                   :dynamic_synthetic_condition=>dynamic_synthetic_condition,
                                   :show_conditions => show_conditions,
                                   :domain => params[:domain]
  end

  def list
    params[:page].blank? ? page = nil : page = params[:page].to_i
    if params[:per_page].blank?
      per_page = 30
      params[:per_page] = "30"
    else
      per_page = params[:per_page].to_i
    end
    
    if session[:user_id].blank? or User.find_by_id(session[:user_id]).blank?
      temp = session[(params[:domain]+"_dict_id").to_sym].inject([]){|condition_string, dict_id| condition_string << " ( #{params[:domain]}_lexemes.dictionary like '%-#{dict_id}-%' ) "}
      if temp.size == 1
        params[:static_condition] << " and " + temp[0]
      else
        params[:static_condition] << " and ( " + temp.join(" or ") + " ) "
      end
    end
		@lexemes = get_search_collection(:domain => params[:domain],
																		 :static_condition => params[:static_condition],
																		 :dynamic_lexeme_condition => params[:dynamic_lexeme_condition],
																		 :dynamic_synthetic_condition => params[:dynamic_synthetic_condition],
																		 :simple_search => params[:simple_search],
																		 :per_page => per_page,
																		 :page => page)
    if @lexemes.total_entries == 0
      flash[:notice] = params[:domain] == 'jp' ? '<ul><li>単語は見つかりませんでした！</li></ul>' : '<ul><li>所查找单词不存在！</li></ul>'
      redirect_to :action => 'index'
      return
    end
    @pass=params
    @list = session[(params[:domain]+"_section_list").to_sym]
  end

  private
  def verification ( params = {} )
    result = []
    ###################################
    #item1 is Lexeme and Synthetic properties
    #item2 is LexemeNewPropertyItem properties
    #item3 is SyntheticNewPropertyItem properties
    condition = [[], [], []] 
    ################################
    case params[:domain]
    when "jp"
    	error_msg_1 = "IDは数字だけで指定して下さい！"
    	error_msg_1_1 = "ID範囲を指定するには、,(comma)もしくは-(hyphen)を利用してください！(例；xx, xx-yy, xx-xx, xx)"
    	error_msg_2 = "検索条件入力エラーもしくは単語が見つかりません!"
    	structure_trans = "構造"
    	inner_surface_trans = "内部表記"
    	inner_reading_trans = "内部読み"
    	inner_pos_trans = "内部品詞"
    when "cn"
    	error_msg_1 = "ID必须为数字！"
    	error_msg_1_1 = "在指定ID的范围时，只能使用comma(,)或者hyphen(-)！(例；xx, xx-yy, xx-xx, xx)"
    	error_msg_2 = "查找条件输入错误，或无此单词！"
    	structure_trans = "结构"
    	inner_surface_trans = "内部成分"
    	inner_reading_trans = "内部读音"
    	inner_pos_trans = "内部词性"
    end
    
    unless params[:id][:value].blank?
    	if params[:id][:operator] != '='
    		return "", "", "<ul><li>"+error_msg_1+"</li></ul>" if (%r[^\d+$].match(params[:id][:value]) == nil)
    	else
    		return "", "", "<ul><li>"+error_msg_1_1+"</li></ul>" unless (params[:id][:value] =~ /^(\d+(-\d+)?)(,\s*(\d+(-\d+)?))*$/)
    	end
    end
    
    params.each{|key, value|
      case key
      when "commit", "authenticity_token", "controller", "action", "search_type", "domain" then next
      else
        if initial_property_name(params[:domain])[key] != nil or ["sth_modified_by", "sth_updated_at", "sth_pos", "sth_reading"].include?(key)
          case key
          when "character_number"
            unless params[key][:value].blank?
              result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + params[key][:value]
              condition[0]<<" char_length(#{params[:domain]}_lexemes.surface) #{params[key][:operator]} #{params[key][:value].to_i} "
            end
          when "sth_struct", "sth_reading", "sth_pos"
						inner_surface = params['sth_struct'][:value].dup
						inner_reading = params['sth_reading'][:value].dup
						inner_pos = params['sth_pos'].dup
						params.delete('sth_struct')
						params.delete('sth_reading')
						params.delete('sth_pos')
						temp_conditions = []
						temp_conditions << " surface = '#{inner_surface}' " unless inner_surface.blank?
						temp_conditions << " reading = '#{inner_reading}' " unless inner_reading.blank?
						inner_pos.delete("operator")
						temp_pos = verify_domain(params[:domain])['Property'].constantize.find_item_by_tree_string_or_array('pos', get_ordered_string_from_params(inner_pos))
						unless temp_pos.blank?
						  temp_pos_string = temp_pos.sub_tree_items.map(&:property_cat_id).join(",")
						  temp_conditions << " pos in (#{temp_pos_string}) "
						end
						unless temp_conditions.blank?
						  temp_ids = verify_domain(params[:domain])['Lexeme'].constantize.find(:all, :select=>'id', :conditions=>temp_conditions.join(" and ")).map(&:id)
              temp_lexeme_id = []
              temp_ids.each{|temp_id|
                temp_structs = verify_domain(params[:domain])['Synthetic'].constantize.find(:all, :select=>"sth_ref_id", :conditions=>["sth_struct like ?", '%-'+temp_id.to_s+'-%']).map(&:sth_ref_id).uniq
                temp_lexeme_id = temp_lexeme_id.concat(temp_structs).uniq unless temp_structs.blank?
              }
              unless temp_lexeme_id.blank?
						    show_result = []
						    show_result << structure_trans + inner_surface_trans + "include#{inner_surface}" unless inner_surface.blank?
						    show_result << structure_trans + inner_reading_trans + "include#{inner_reading}" unless inner_reading.blank?
						    show_result << structure_trans + inner_pos_trans + "incluce#{temp_pos.tree_string}" unless temp_pos.blank?
						    result << show_result.join(',&nbsp;&nbsp;&nbsp;')
                condition[0] << " #{params[:domain]}_lexemes.id in (#{temp_lexeme_id.join(',')}) "
              end
            end
          when "id"
            unless params[key][:value].blank?
            	if (params[key][:operator] == '=')
            		id_result_string = []
            		id_condition_string = []
            		params[key][:value].split(/,\s*/).map{|item| item.split('-')}.each{|item|
            			if item.size == 1
            				id_result_string << item[0]
            				id_condition_string << " #{params[:domain]}_lexemes.#{key} = #{item[0].to_i} "
            			else
            				id_result_string << item.join('-')
            				id_condition_string << " (#{params[:domain]}_lexemes.#{key} >= #{item[0].to_i} and #{params[:domain]}_lexemes.#{key} <= #{item[1].to_i}) "
            			end
            		}
            		result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + id_result_string.join(', ')
            		condition[0] << '(' + id_condition_string.join(' or ') + ')'
            	else
	              result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + params[key][:value]
  	            condition[0]<<" #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} #{params[key][:value].to_i} "
            	end
            end
          when "surface", "reading", "pronunciation"
            unless params[key][:value].blank?
              if params[key][:operator] == "like"
                regexp="%"
                case params[key][:value]
                when '%' then temp = '\\%'
                when '\'' then temp = "\\\'"
                when '_' then temp = '\_'
                else temp = params[key][:value]
                end
              else
                regexp=""
                case params[key][:value]
                when '\'' then temp = "\\\'"
                else temp = params[key][:value]
                end
              end
              result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + params[key][:value]
              condition[0]<<" #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} '#{regexp}#{temp}#{regexp}' "
            end
          when "base_id"	# only for jp
            unless params[key][:value].blank?
              result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
              if params[key][:operator] == "="
                specific_base = JpLexeme.find(:all, :conditions=>["surface='#{params[key][:value]}'"])
              elsif params[key][:operator] == "like"
                specific_base = JpLexeme.find(:all, :conditions=>[" surface like ? ", '%'+params[key][:value]+'%'])
              end
              if specific_base.blank?
                condition[0]<<" jp_lexemes.#{key} is NULL "
              else
                same_base_array = []
                specific_base.each{|item| same_base_array.concat(item.same_base_lexemes.map{|lexeme| lexeme.id}) }
                condition[0]<<" jp_lexemes.#{key} in (#{same_base_array.join(',')}) "
              end
            end
          when "pos", "ctype", "cform", "tagging_state", "sth_tagging_state"
            values = params[key].dup
            values.delete("operator")
            temp = verify_domain(params[:domain])['Property'].constantize.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(values))
            case params[key][:operator]
            when "in", "not in"
              unless temp.blank?
                series = temp.sub_tree_items.map{|item| item.property_cat_id}.uniq
                series.delete(0)
                case key
                when "sth_tagging_state"
                  result << structure_trans + initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + temp.tree_string
                  condition[0] << " #{params[:domain]}_synthetics.#{key} #{params[key][:operator]} (#{series.join(',')}) "
                when "pos", "ctype", "cform", "tagging_state"
                  result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + temp.tree_string
                  condition[0] << " #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} (#{series.join(',')}) "  
                end
              end
            when "=", "!="
              unless temp.blank?
                case key
                when "sth_tagging_state"
                  result << structure_trans + initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + temp.tree_string
                  condition[0] << " #{params[:domain]}_synthetics.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                when "pos", "ctype", "cform", "tagging_state"
                  result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + temp.tree_string
                  condition[0] << " #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                end
              end
            end
          when "created_by", "modified_by", "sth_modified_by"
            unless params[key][:value].blank?
              if ["created_by", "modified_by"].include?(key)
                result << initial_property_name(params[:domain])[key] + operator0[params[key][:operator]] + User.find(params[key][:value].to_i).name
                condition[0]<<" #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} '#{params[key][:value].to_i}' "
              elsif key == "sth_modified_by"
                result << structure_trans + initial_property_name(params[:domain])["modified_by"] + operator0[params[key][:operator]] + User.find(params[key][:value].to_i).name
                condition[0]<<" #{params[:domain]}_synthetics.modified_by #{params[key][:operator]} #{params[key][:value].to_i} "
              end
            end
          when "dictionary"
            unless params[key][:value] == [""]
              dic_names_array = []
              dic_num = []
              params[key][:value].each{|item|
                dic_names_array << verify_domain(params[:domain])['Property'].constantize.find(:first, :conditions=>["property_string='dictionary' and property_cat_id=?", item.to_i]).tree_string
                dic_num << item.to_i
              }
              result << initial_property_name(params[:domain])[key] + ":(" + dic_names_array.join(operator0[params[key][:operator]]) + ")"
              temp_section = []
              if params[key][:operator] == "and"
                dic_num.sort.each{|num| temp_section << "%-#{num.to_s}-%"}
                condition[0] << %Q| #{params[:domain]}_lexemes.dictionary like '#{temp_section.join(",")}' |
              elsif params[key][:operator] == "or"
                dic_num.each{|num| temp_section << " #{params[:domain]}_lexemes.dictionary like '%-#{num}-%' "}
                condition[0] << " ("+temp_section.join(' '+params[key][:operator]+' ')+") "
              end
            end
          when "updated_at", "sth_updated_at"
            temp = params[key].dup
            temp.delete("operator")
            unless temp.values.join("") == ""
              time_error, time_string = verify_time_property(:value=>temp, :domain=>params[:domain])
              if time_error.blank?
                time = time_string
	              if key == "sth_updated_at"
	                result << structure_trans + initial_property_name(params[:domain])["updated_at"] + operator0[params[key][:operator]] + time
	                condition[0] << " #{params[:domain]}_synthetics.updated_at #{params[key][:operator]} '#{time}' "
	              elsif key == "updated_at"
                  result << initial_property_name(params[:domain])["updated_at"] + operator0[params[key][:operator]] + time
                  condition[0] << " #{params[:domain]}_lexemes.#{key} #{params[key][:operator]} '#{time}' "
                end
              else
                return "", "", time_error
              end
            end
          end
        else
          property = verify_domain(params[:domain])['NewProperty'].constantize.find(:first, :conditions=>["property_string='#{key}'"])
          case property.type_field
          when "category"
            values = params[key].dup
            values.delete("operator")
            temp = verify_domain(params[:domain])['Property'].constantize.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(values))
            case params[key][:operator]
            when "in", "not in"
              unless temp.blank?
                result << property.human_name + operator0[params[key][:operator]] + temp.tree_string
                series = temp.sub_tree_items.map{|item| item.property_cat_id}.uniq
                series.delete(0)
                case property.section
                when "synthetic"
                  condition[2] << " #{params[:domain]}_synthetic_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_synthetic_new_property_items.category #{params[key][:operator]} (#{series.join(',')}) "
                when "lexeme"
                  condition[1] << " #{params[:domain]}_lexeme_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_lexeme_new_property_items.category #{params[key][:operator]} (#{series.join(',')}) "
                end
              end
            when "=", "!="
              unless temp.blank?
                result << property.human_name + operator0[params[key][:operator]] + temp.tree_string
                case property.section
                when "synthetic"
                  condition[2] << " #{params[:domain]}_synthetic_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_synthetic_new_property_items.category #{params[key][:operator]} #{temp.property_cat_id} "
                when "lexeme"
                  condition[1] << " #{params[:domain]}_lexeme_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_lexeme_new_property_items.category #{params[key][:operator]} #{temp.property_cat_id} "
                end
              end
            end
          when "text"
            unless params[key][:value].blank?
              result << property.human_name + operator0[params[key][:operator]] + params[key][:value]
              params[key][:operator] == "like" ? regexp="%" : regexp=""
              case property.section
              when "synthetic"
                condition[2] << " #{params[:domain]}_synthetic_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_synthetic_new_property_items.text #{params[key][:operator]} '#{regexp}#{params[key][:value]}#{regexp}' "
              when "lexeme"
                condition[1] << " #{params[:domain]}_lexeme_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_lexeme_new_property_items.text #{params[key][:operator]} '#{regexp}#{params[key][:value]}#{regexp}' "
              end
            end
          when "time"
            temp = params[key].dup
            temp.delete("operator")
            unless temp.values.join("") == ""
              time_error, time_string = verify_time_property(:value=>temp, :domain=>params[:domain])
              if time_error.blank?
                time = time_string
                result << name_string + operator0[params[key][:operator]] + time
                case property.section
                when "synthetic"
                  condition[2] << " #{params[:domain]}_synthetic_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_synthetic_new_property_items.time #{params[key][:operator]} '#{time}' "
                when "lexeme"
                  condition[1] << " #{params[:domain]}_lexeme_new_property_items.property_id = '#{property.id}' and #{params[:domain]}_lexeme_new_property_items.time #{params[key][:operator]} '#{time}' "
                end
              else
                return "", "", time_error
              end
            end
          end
        end
      end
    }
    if result.empty?
      return "", "", "<ul><li>"+error_msg_2+"</li></ul>"
    else
      return condition, result.join(",&nbsp;&nbsp;&nbsp;"), ""
    end
  end

  def get_search_collection(option={}, state = 'page')
    if option[:simple_search] == "true"
      temp_conditions = [option[:static_condition], option[:dynamic_lexeme_condition], option[:dynamic_synthetic_condition]].compact
      temp_conditions.delete('')
      temp_conditions = temp_conditions.join(' and ')
      if option[:dynamic_lexeme_condition].blank? and option[:dynamic_synthetic_condition].blank?
      	if state == 'page'
		      lexemes = verify_domain(option[:domain])['Lexeme'].constantize.paginate(:conditions=>temp_conditions,
		      															 																					:include=>[:sub_structs],
		      															 																					:per_page=>option[:per_page],
																																									:page=>option[:page])
				elsif state == 'all'
		      lexemes = verify_domain(option[:domain])['Lexeme'].constantize.find(:all, :conditions=>temp_conditions, :include=>[:sub_structs])
				end
			else
				if state == 'page'
					lexemes = verify_domain(option[:domain])['Lexeme'].constantize.paginate(:conditions=>temp_conditions,
		       															 																					:include=>[:dynamic_properties, {:sub_structs=>[:other_properties]}],
		       															 																					:per_page=>option[:per_page],
		 																																							:page=>option[:page])
		 		elsif state == 'all'
					lexemes = verify_domain(option[:domain])['Lexeme'].constantize.find(:all, :conditions=>temp_conditions, :include=>[:dynamic_properties, {:sub_structs=>[:other_properties]}])
		 		end
			end
    else
      dynamic_lexeme_ids = []
      dynamic_synthetic_refs = []
      dynamic_ids = []
      collection = []
      unless option[:dynamic_lexeme_condition].blank?
        dynamic_lexeme_ids = get_lexeme_ids_from_new_property_items(:conditions=>option[:dynamic_lexeme_condition], :domain=>option[:domain], :section=>'lexeme')
      end
      unless option[:dynamic_synthetic_condition].blank?
        dynamic_synthetic_refs = get_lexeme_ids_from_new_property_items(:conditions=>option[:dynamic_synthetic_condition], :domain=>option[:domain], :section=>'synthetic')
      end
      if option[:dynamic_synthetic_condition].blank?
        dynamic_ids = dynamic_lexeme_ids
      elsif option[:dynamic_lexeme_condition].blank?
        dynamic_ids = dynamic_synthetic_refs
      else
        dynamic_lexeme_ids.size >= dynamic_synthetic_refs.size ? dynamic_ids = dynamic_synthetic_refs & dynamic_lexeme_ids : dynamic_ids = dynamic_lexeme_ids & dynamic_synthetic_refs
      end
      if option[:static_condition].blank?
        collection = install_by_dividing(:ids=>dynamic_ids, :domain=>option[:domain])
        lexemes = collection.paginate(:page=>option[:page], :per_page=>option[:per_page])
      else
      	if option[:domain] = 'jp'
      		sql_st = "SELECT DISTINCT jp_lexemes.id FROM jp_lexemes LEFT OUTER JOIN jp_synthetics ON jp_synthetics.sth_ref_id = jp_lexemes.id WHERE ( #{option[:static_condition]} ) ORDER BY jp_lexemes.id ASC"
      	elsif option[:domain] = 'cn'
      		sql_st = "SELECT DISTINCT cn_lexemes.id FROM cn_lexemes LEFT OUTER JOIN cn_synthetics ON cn_synthetics.sth_ref_id = cn_lexemes.id WHERE ( #{option[:static_condition]} ) ORDER BY cn_lexemes.id ASC"
      	end
      	static_ids = verify_domain(option[:domain])['Lexeme'].constantize.find_by_sql(sql_st).map(&:id)
        static_ids.size >= dynamic_ids.size ? final_ids = dynamic_ids & static_ids : final_ids = static_ids & dynamic_ids
        if state == 'page'
	        lexemes = verify_domain(option[:domain])['Lexeme'].constantize.paginate(:conditions=>["id in (#{final_ids.join(',')})"], :page=>option[:page], :per_page=>option[:per_page])
				elsif state == 'all'
	        lexemes = verify_domain(option[:domain])['Lexeme'].constantize.find(:all, :conditions=>["id in (#{final_ids.join(',')})"])
				end
      end
    end
  end
  
  ### :conditions, :domain, :section
  def get_lexeme_ids_from_new_property_items(fields={})
    return nil if fields[:conditions].blank? or fields[:domain].blank? or fields[:section].blank?
    if fields[:section] == "lexeme"
      class_name = verify_domain(fields[:domain])['Lexeme']
      item_class = verify_domain(fields[:domain])['LexemeNewPropertyItem']
    elsif fields[:section] == "synthetic"
      class_name = verify_domain(fields[:domain])['Synthetic']
      item_class = verify_domain(fields[:domain])['SyntheticNewPropertyItem']
    end
    ids=[]
    fields[:conditions].split("**and**").each_with_index{|search, index|
      collection = item_class.constantize.find(:all, :select=>"ref_id", :conditions=>search)
      if collection.blank?
        return []
      else
        if index == 0
          ids = (collection.map{|item| item.ref_id}).uniq.sort
        else
          ids = ids & (collection.map{|item| item.ref_id}).uniq.sort
        end
      end
    }
    if fields[:section] == "lexeme"
      return ids
    elsif fields[:section] == "synthetic"
      temp_ids = []
      ids.each{|struct_id| temp_ids << class_name.constantize.find(struct_id).lexeme.id}
      return temp_ids.uniq.sort
    end
  end
  
  ### :ids, ;domain
  def install_by_dividing(fields={})
    if fields[:ids].blank?
      return []
    else
      ids = fields[:ids]
    end
    class_name = verify_domain(fields[:domain])['Lexeme']
    start = 0
    step = 499
    collection = []
    while(start<=ids.size) do
      if step+start <= ids.size-1
        id_string = ids[start..(step+start)].join(',')
      else
        id_string = ids[start..(ids.size-1)].join(',')
      end
      collection.concat(class_name.constantize.find(:all, :conditions=>["id in (#{id_string})"]))
      start = start + step + 1
    end
    return collection
  end
end