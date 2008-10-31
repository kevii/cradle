class DumpDataWorker < Workling::Base
  def dump_data(options)
    number = options[:count]
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
      unless params[:dynamic_lexeme_condition].blank?
        dynamic_lexeme_ids = get_lexeme_ids_from_new_property_items(:conditions=>params[:dynamic_lexeme_condition], :domain=>'jp', :section=>'lexeme')
      end
      unless params[:dynamic_synthetic_condition].blank?
        dynamic_synthetic_refs = get_lexeme_ids_from_new_property_items(:conditions=>params[:dynamic_synthetic_condition], :domain=>'jp', :section=>'synthetic')
      end
      if params[:dynamic_synthetic_condition].blank?
        dynamic_ids = dynamic_lexeme_ids
      elsif params[:dynamic_lexeme_condition].blank?
        dynamic_ids = dynamic_synthetic_refs
      else
        dynamic_lexeme_ids.size >= dynamic_synthetic_refs.size ? dynamic_ids = dynamic_synthetic_refs & dynamic_lexeme_ids : dynamic_ids = dynamic_lexeme_ids & dynamic_synthetic_refs
      end
      if params[:static_condition].blank?
        collection = install_by_dividing(:ids=>dynamic_ids, :domain=>'jp')
        @jplexemes = collection.paginate(:page=>page, :per_page=>per_page)
      else
        static_ids = JpLexeme.find(:all, :select=>" jp_lexemes.id ", :conditions => params[:static_condition], :include => [:sub_structs], :order => " jp_lexemes.id ASC ").map{|item| item.id}
        static_ids.size >= dynamic_ids.size ? final_ids = dynamic_ids & static_ids : final_ids = static_ids & dynamic_ids
        @jplexemes = JpLexeme.paginate(:all, :conditions=>["id in (#{final_ids.join(',')})"], :page=>page, :per_page=>per_page)
      end
    end













































  end



end
