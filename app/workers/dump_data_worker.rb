class DumpDataWorker < Workling::Base
  include SearchModule
  
  def dump_data(options)
    case options[:domain]
      when 'jp'
        id_array = find_all_jp_ids(:dynamic_lexeme_condition=>options[:dynamic_lexeme_condition], :dynamic_synthetic_condition=>options[:dynamic_synthetic_condition],
                                    :static_condition=>options[:static_condition], :simple_search=>options[:simple_search])
        lexeme_class = 'JpLexeme'
        first_line = "出力条件： "+options[:show_conditions].delete('&nbsp;')
        header = generate_header(:section_list=>options[:section_list], :domain=>'jp')
        field_list = header.map{|item| item[0]}.join("\t")
      when 'cn'
#       id_array = find_all_cn_ids()
        lexeme_class = 'CnLexeme'
      when 'en'
#       id_array = find_all_en_ids()
        lexeme_class = 'EnLexeme'
    end

    whole_number = id_array.size
    step = (whole_number.to_f/100.0).round
    start_index = 0
    each_part = 100
    count = 0
    file_path = '/user_dump_file/' + Time.now.to_s(:db).gsub(/[^\d]/, '-')
    output_file = File.open(RAILS_ROOT+'/public'+file_path, "w")
    output_file.puts first_line
    output_file.puts field_list
    while(count < 100) do
      if each_part > whole_number
        dump_to_file(:result_array=>lexeme_class.constantize.find(id_array), :file_handler=>output_file, :header=>header, :domain=>options[:domain])
        count = 100
      else
        end_index = start_index+each_part
        end_index = whole_number-1 if end_index > whole_number-1
        dump_to_file(:result_array=>lexeme_class.constantize.find(id_array[start_index..end_index]),
                     :file_handler=>output_file, :header=>header, :domain=>options[:domain])
        start_index = end_index+1
        count = start_index / step
        count = 100 if start_index == whole_number
        count = 1 if count < 1
      end
      Workling::Return::Store.set(options[:uid], count.to_s)
    end
    output_file.close
    if ENV["RAILS_ENV"] == "production"
      Workling::Return::Store.set(options[:uid], '/cradle'+file_path)
    else
      Workling::Return::Store.set(options[:uid], file_path)
    end
  end

  private
  def find_all_jp_ids(options)
    final_id_arrays = []
    if options[:dynamic_lexeme_condition].blank? and options[:dynamic_synthetic_condition].blank?
      mysql_string = %Q| SELECT DISTINCT jp_lexemes.id | +
                     %Q| FROM `jp_lexemes` LEFT OUTER JOIN `jp_synthetics` ON jp_synthetics.sth_ref_id = jp_lexemes.id | +
                     %Q| WHERE | + options[:static_condition] +
                     %Q| ORDER BY  jp_lexemes.id ASC |
      final_id_arrays = JpLexeme.find_by_sql(mysql_string).map{|item| item.id}
    elsif options[:simple_search] == "true"
      mysql_condition_string = [options[:static_condition].gsub('jp_synthetics', 'dynamic_struct_properties_jp_lexemes_join'), options[:dynamic_lexeme_condition], options[:dynamic_synthetic_condition]]
      mysql_condition_string.delete("")
      mysql_string = %Q| SELECT DISTINCT jp_lexemes.id | +
                     %Q| FROM jp_lexemes LEFT OUTER JOIN jp_lexeme_new_property_items ON jp_lexeme_new_property_items.ref_id = jp_lexemes.id | +
                     %Q| LEFT OUTER JOIN jp_synthetics dynamic_struct_properties_jp_lexemes_join ON (jp_lexemes.id = dynamic_struct_properties_jp_lexemes_join.sth_ref_id) | +
                     %Q| LEFT OUTER JOIN jp_synthetic_new_property_items ON (jp_synthetic_new_property_items.ref_id = dynamic_struct_properties_jp_lexemes_join.id) | +
                     %Q| WHERE | + mysql_condition_string.join(' and ') +
                     %Q| ORDER BY  jp_lexemes.id ASC |
      final_id_arrays = JpLexeme.find_by_sql(mysql_string).map{|item| item.id}
    else
      dynamic_lexeme_ids = []
      dynamic_synthetic_refs = []
      dynamic_ids = []
      collection = []
      unless options[:dynamic_lexeme_condition].blank?
        dynamic_lexeme_ids = get_lexeme_ids_from_new_property_items(:conditions=>options[:dynamic_lexeme_condition], :domain=>'jp', :section=>'lexeme')
      end
      unless options[:dynamic_synthetic_condition].blank?
        dynamic_synthetic_refs = get_lexeme_ids_from_new_property_items(:conditions=>options[:dynamic_synthetic_condition], :domain=>'jp', :section=>'synthetic')
      end
      if options[:dynamic_synthetic_condition].blank?
        dynamic_ids = dynamic_lexeme_ids
      elsif options[:dynamic_lexeme_condition].blank?
        dynamic_ids = dynamic_synthetic_refs
      else
        dynamic_lexeme_ids.size >= dynamic_synthetic_refs.size ? dynamic_ids = dynamic_synthetic_refs & dynamic_lexeme_ids : dynamic_ids = dynamic_lexeme_ids & dynamic_synthetic_refs
      end
      if options[:static_condition].blank?
        collection = install_by_dividing(:ids=>dynamic_ids, :domain=>'jp')
        final_id_arrays = collection.map{|item| item.id}
      else
        static_ids = JpLexeme.find(:all, :select=>" jp_lexemes.id ", :conditions=>options[:static_condition], :include=>[:sub_structs], :order=>" jp_lexemes.id ASC ").map{|item| item.id}
        static_ids.size >= dynamic_ids.size ? final_id_arrays = dynamic_ids & static_ids : final_id_arrays = static_ids & dynamic_ids
      end
    end
    return final_id_arrays.uniq.sort
  end
  
  def generate_header(options)
    case options[:domain]
      when "jp"
        header = [['ID','id', 'lexeme', nil]]
        options[:section_list].each{|item|
          item =~ /^(\d+)_(.*)/
          index = $1.to_i
          property_string = $2
          type = nil
          section = nil
          if JpNewProperty.exists?(:property_string=>property_string)
            temp = JpNewProperty.find_by_property_string(property_string)
            human_name = temp.human_name
            section = temp.section
            type = temp.type_field
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
                human_name = initial_property_name('jp')["sth_tagging_state"]
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
        header = header.compact
      when "cn"
      when "en"
    end
  end
  
  def dump_to_file(options)
    if options[:domain] == 'jp'
      options[:result_array].each{|lexeme|
        temp_line = []
        options[:header].each{|item|
          if item[2] == 'synthetic' and lexeme.struct.blank?
            temp_line << ""
          else
            case item[3]
              when "category"
                item[2] == 'lexeme' ? temp_id = eval('lexeme.'+item[1]) : temp_id = eval('lexeme.struct.'+item[1])
                temp_id.blank? ? temp_line << "" : temp_line << JpProperty.find(:first, :conditions=>["property_string=? and property_cat_id=?", item[1], temp_id]).tree_string
              when "text"
                item[2] == 'lexeme' ? temp_line << eval('lexeme.'+item[1]) : temp_line << eval('lexeme.struct.'+item[1])
              when "time"
                item[2] == 'lexeme' ? temp_line << eval('lexeme.'+item[1]).to_s(:db) : temp_line << eval('lexeme.struct.'+item[1]).to_s(:db)
              when "user"
                item[2] == 'lexeme' ? temp_line << User.find(eval('lexeme.'+item[1])).name : temp_line << User.find(eval('lexeme.struct.'+item[1])).name
              else  ##nil      base_id, base.surface, root_id, root.surface, id, dictionary, sth_struct
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
                  when 'sth_struct'
                    temp_line << lexeme.struct.get_dump_string
                end
            end
          end
        }
        options[:file_handler].puts temp_line.join("\t")
      }
    elsif options[:domain] == 'cn'
      
    elsif options[:domain] == 'en'
      
    end
  end
  
end
