module SearchModule
  include CradleModule
  
  private
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