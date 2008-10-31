class DumpDataWorker < Workling::Base
  include ApplicationHelper
  def dump_data(options)
    number = options[:count]
    case options[:domain]
      when 'jp'
	id_array = find_all_jp_ids(:dynamic_lexeme_condition=>options[:dynamic_lexeme_condition], :dynamic_synthetic_condition=>options[:dynamic_synthetic_condition],
				   :static_condition=>options[:static_condition], :simple_search=>options[:simple_search])
      when 'cn'
      when 'en'
    end


    while(number < 100) do
      sleep(1)
      number = number + 1
      logger.info("xxxxx"+number.to_s)
      Workling::Return::Store.set(options[:uid], number.to_s)
    end
    logger.info("xxxxx---filepath")
    Workling::Return::Store.set(options[:uid], "filepath") 
  end

  private
  def find_all_jp_ids(options)
    final_id_arrays = []
    if options[:dynamic_lexeme_condition].blank? and options[:dynamic_synthetic_condition].blank?
      final_id_arrays = JpLexeme.find(:select=>" jp_lexemes.id ", :conditions => params[:static_condition],
                                      :include => [:sub_structs],  :order => " jp_lexemes.id ASC ").map{|item| item.id}
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
      return final_id_arrays
    end
  end
end
