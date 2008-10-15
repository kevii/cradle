# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  ### Pick a unique cookie name to distinguish our session data from others
  session :session_key => '_cradle_session_id'
  ### set charset
  before_filter :set_charset

  def update_property_list
    case params[:domain]
      when "jp"
        class_name = "JpProperty"
      when "cn"
        class_name = "CnProperty"
      when "en"
        class_name = "EnProperty"
    end
    value = params["level"+params[:level].to_s]
    if value.blank?
      id = 0
    else
      if params[:id].to_i > 0
        children = eval(class_name+".find(params[:id].to_i)"+".children")
      else
        children = eval(class_name+".find(:all, :conditions=>['property_string = ? and parent_id is null', params[:type]], :order=>'property_cat_id ASC')")
      end
      children.each{|child| id = child.id if child.value == value}
    end
    render :update do |page|
      page.replace "#{params[:prefix]}"+"#{params[:type]}_level#{params[:level].to_i+1}_list",
                   :inline=>"<%= display_property_list(:type=>'#{params[:type]}', :domain=>'#{params[:domain]}', :prefix=>'#{params[:prefix]}', :state=>'#{params[:state]}', :option=>'#{params[:option]}', :id=>#{id}, :level=>#{params[:level].to_i+1}) %>"
    end
  end
  
  
#  ### override paginator_and_collection_for() to return the whole result number of search
#  def paginate_collection(model, options={})
#    klass = model
#    page = options[:page] unless options[:page].blank?
#    count = count_collection_for_pagination(klass, options)
#    paginator = Paginator.new(self, count, options[:per_page], page)
#    collection = find_collection_for_pagination(klass, options, paginator)
#    
#    return paginator, count, collection 
#  end
  
  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '09ec5a97109da25e12ad40979cec9f7f'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password

  private
  def authorize
    unless User.find_by_id(session[:user_id])
      flash[:notice_err] = "<ul><li>Please log in!</li></ul>"
      redirect_to(:controller => "users" , :action => "login" )
    end
  end
  
  def authorize_admin
    unless User.find_by_id(session[:user_id]).group_name == "admin"
      flash[:notice_err] = "<ul><li>You are not administrator!</li></ul>"
      redirect_to(:controller => "users" , :action => "chg_pwd" )
    end
  end
  
  ### set charset
  def set_charset
    headers["Content-Type"] = "text/html; charset = UTF-8"
  end

  def get_ordered_string_from_params(field={}, prefix="level")
    string = []
    for index in 1..field.size
      string << field[prefix+index.to_s]
    end
    state = false
    (string.size-1).downto(0){|idx|
      if state == false and string[idx].blank?
        next
      elsif state == true and string[idx].blank?
        state = false
        break
      elsif not string[idx].blank?
        state = true
      end
    }
    if state == true
      string.delete("")
      return string
    else
      return []
    end
  end
  
  
  ## :conditions, :domain, :section
  def get_lexeme_ids_from_new_property_items(fields={})
    return nil if fields[:conditions].blank? or fields[:domain].blank? or fields[:section].blank?
    case fields[:domain]
      when "jp"
        if fields[:section] = "lexeme"
          item_class = "JpLexemeNewPropertyItem"
          class_name = "JpLexeme"
        elsif fields[:section] = "synthetic"
          item_class = "JpSyntheticNewPropertyItem"
          class_name = "JpSynthetic"
        end
      when "cn"
        
      when "en"
    end
    ids=[]
    fields[:conditions].split("and").each_with_index{|search, index|
      if index == 0
        collection = eval(item_class+'.find(:all, :select=>"ref_id", :conditions=>[" #{search} "])')
      else
        collection = eval(item_class+'.find(:all, :select=>"ref_id", :conditions=>[" #{search} and ref_id in (#{ids.join(",")}) "])')
      end
      if collection.blank?
        return []
      else
        ids = (collection.map{|item| item.ref_id}).uniq.sort
      end
    }
    if fields[:section] == "lexeme"
      return ids
    elsif fields[:section] == "synthetic"
      temp_ids = []
      ids.each{|struct_id| temp_ids << eval(class_name+'.find(struct_id).lexeme.id')}
      return temp_ids.uniq.sort
    end
  end
  
  #ids, domain
  def install_by_dividing(fields={})
    ids = fields[:ids]
    case fields[:domain]
      when "jp"
        class_name = "JpLexeme"
      when "cn"
      when "en"
    end
    start = 0
    step = 499
    collection = []
    while(start<=ids.size) do
      if step+start <= ids.size-1
        id_string = ids[start..(step+start)].join(',')
      else
        id_string = ids[start..(ids.size-1)].join(',')
      end
      collection.concat(eval(class_name+'.find(:all, :conditions=>["id in (#{id_string})"])'))
      start = start + step + 1
    end
    return collection
  end

  def get_formatted_ids_and_chars(fields={})
    original_lexeme_id = fields["original_lexeme_id"]
    fields["meta"].blank? ? meta=0 : meta=fields["meta"]
    fields["level"].blank? ? level=1 : level = fields["level"]
    case fields[:domain]
      when "jp"
        lexeme_class = "JpLexeme"
        synthetic_class = "JpSynthetic"
      when "cn"
      when "en"
    end
    ids = []
    chars = []
    temp_struct = eval(synthetic_class+'.find(:first, :conditions=>["sth_ref_id=#{original_lexeme_id} and sth_meta_id=#{meta}"]).sth_struct')
    if temp_struct.include?('meta')
      temp_struct.split(',').each{|item|
        if (item =~ /^meta_(\d*)$/) != nil
          meta = $1
          temp = get_formatted_ids_and_chars(:original_lexeme_id=>original_lexeme_id, :domain=>fields[:domain], :meta=>meta, :level=>level+1)
          ids << temp[0]
          chars << temp[1]
        else
          ids << item
          chars << eval(lexeme_class+'.find(item.to_i).surface.split("").join("-")')
        end
      }
    else
      temp_struct.split(',').each{|item|
        ids << item
        chars << eval(lexeme_class+'.find(item.to_i).surface.split("").join("-")')
      }
    end
    return ids.join('*'+'+'*level+'*'), chars.join('*'+'+'*level+'*')
  end
  
  def get_meta_structures(fields={})
    ids = fields["ids"]
    chars = fields["chars"]
    fields["count"].blank? ? count=0 : count=fields["count"]
    fields["level"].blank? ? level=1 : level = fields["level"]
    meta_ids = {}
    meta_chars = {}
    temp_ids = ids.split('*'+'+'*level+'*')
    temp_chars = chars.split('*'+'+'*level+'*')
    if not temp_ids.join(',').include?('*')
      meta_ids['meta_'+count.to_s] = temp_ids.join(',')
      meta_chars['meta_'+count.to_s] = temp_chars.join(',').split('-').join("")
    else
      original = count
      for index in 0..temp_ids.size-1
        if temp_ids[index].include?('*')
          temp_ids_string = temp_ids[index]
          temp_chars_string = temp_chars[index]
          temp_ids[index] = 'meta_'+(count+1).to_s
          temp_chars[index] = 'meta_'+(count+1).to_s
          sub_ids_struct, sub_chars_struct, count = get_meta_structures(:ids=>temp_ids_string, :chars=>temp_chars_string, :level=>level+1, :count=>count+1)
          meta_ids.update(sub_ids_struct)
          meta_chars.update(sub_chars_struct)
        end
      end
      meta_ids['meta_'+original.to_s] = temp_ids.join(',')
      meta_chars['meta_'+original.to_s] = temp_chars.join(',').split('-').join("")
    end
    return meta_ids, meta_chars, count
  end
  
end
