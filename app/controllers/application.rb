# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'date'
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  ### Pick a unique cookie name to distinguish our session data from others
  session :session_key => '_cradle_session_id'
  ### set charset
  before_filter :set_charset
  
  def update_property_list
    class_name = verify_domain(params[:domain])['Property']
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
  
  def define_internal_structure
    class_name = verify_domain(params[:domain])['Lexeme']
    case params[:type]
      when "define"  ###need params:  type, ids, lexeme_id, (chars), from
        if params[:ids].blank?
          ids = ""
          chars = eval(class_name+'.find(params[:original_id].to_i).surface.scan(/./).join("-")')
        else
          ids = params[:ids]
          chars = params[:chars]
        end
      when "modify", "new", "delete"
        ids, chars = get_ids_and_chars(params.update({:domain=>params[:domain]}))
    end
    render :update do |page|
      page["synthetic_struct"].replace :partial=>"synthetic/show_internal_structure",
                                       :object=>{"ids"=>ids, "chars"=>chars, "part"=>chars, "original_id"=>params[:original_id],
                                                 "from"=>params[:from], "start_index"=>0, "ids_section"=>"", "domain"=>params[:domain]}
    end
  end

  def split_word
    class_name = verify_domain(params[:domain])['Lexeme']
    lexemes_left = eval(class_name+%Q|.find(:all, :include=>[:struct], :conditions=>["surface='#{params[:left]}'"], :order=>"id ASC")|)
    lexemes_right = eval(class_name+%Q|.find(:all, :include=>[:struct], :conditions => ["surface='#{params[:right]}'"], :order=>"id ASC")|)
    if params[:type] == "modify"
      ids_array = swap_idsarray_and_ids(params[:ids],[])
      indexes = params[:ids_section].split(',')
      prev_id = ""
      next_id = ""
      if indexes.size == 1
        prev_id = '['+(indexes[0].to_i-1).to_s+']'
        next_id = '['+indexes[0]+']'
      else
        for index_item in 0..indexes.size-1
          if index_item == indexes.size-1
            prev_id << '['+(indexes[index_item].to_i-1).to_s+']'
            next_id << '['+indexes[index_item]+']'
          else
            prev_id << '['+indexes[index_item]+']'
            next_id << '['+indexes[index_item]+']'
          end
        end
      end
      left_id = eval 'ids_array'+prev_id
      right_id = eval 'ids_array'+next_id
      begin
        left_id.chomp
      rescue
        left_id = nil
      end
      begin
        right_id.chomp
      rescue
        right_id = nil
      end
    else params[:type] == "new"
      left_id = nil
      right_id = nil
    end
    render :update do |page|
      page.replace "candidate", :partial=>"synthetic/left_or_right", :object => [lexemes_left, lexemes_right],  
                                :locals => { :left=>params[:left],        :left_id=>left_id,
                                            :right=>params[:right],      :right_id=>right_id,
                                            :ids=>params[:ids],          :chars=>params[:chars],
                                            :level=>params[:level],      :type=>params[:type],
                                            :from=>params[:from],        :original_id => params[:original_id],
                                            :chars_index=>params[:chars_index],     :ids_section=>params[:ids_section],
                                            :divide_type=>params[:divide_type],     :domain=>params[:domain]}
    end
  end

  def modify_structure  ##params:  ids, from, chars, original_id, domain
    if params[:ids].blank? or params[:ids].include?("-")
      case params[:domain]
        when "jp"
          flash[:notice_err] = "<ul><li>内部構造の各部分を確実に存在している単語に指定してください！</li></ul>"
        when "cn"
          flash[:notice_err] = "<ul><li>内部构造的各个部分必须为实际存在的单词！</li></ul>"
        when "en"
          flash[:notice_err] = "<ul><li>Every part of internal structure should be lexeme actually registered in dictioanry!</li></ul>"
      end
      redirect_to :action=>"define_internal_structure", :type=>"define", :from=>params[:from],
                  :original_id=>params[:original_id], :ids=>params[:ids], :chars=>params[:chars], :domain=>params[:domain]
      return
    end
    meta_ids, meta_chars = get_meta_structures(:ids=>params[:ids], :chars=>params[:chars])
    meta_show_chars = meta_chars.dup
    indexes = meta_show_chars.size - 1
    while(indexes >= 0) do
      if meta_show_chars['meta_'+indexes.to_s].include?('meta')
        temp = []
        meta_show_chars['meta_'+indexes.to_s].split(',').each{|item| item.include?('meta') ? temp << meta_show_chars[item].split(',').join("") : temp << item}
        meta_show_chars['meta_'+indexes.to_s] = temp.join(',')
      end
      indexes = indexes - 1
    end
    if params[:from] == "new"
      object = ""
    elsif params[:from] == "modify"
      class_name = verify_domain(params[:domain])['Synthetic']
      structs = eval(class_name+%Q|.find(:all, :conditions=>["sth_ref_id=?", params[:original_id].to_i])|)
      object = {}
      structs.each{|substruct| object['meta_'+substruct.sth_meta_id.to_s]=substruct }
    end
    render :update do |page|
      page["synthetic_struct"].replace :partial=>"synthetic/modify_internal_struct", :object=>object,
                                       :locals=>{ :ids=>params[:ids],   :chars=>params[:chars], :original_id=>params[:original_id],
                                                  :from=>params[:from], :meta_ids=>meta_ids,  :meta_chars=>meta_chars,
                                                  :meta_show_chars=>meta_show_chars, :domain=>params[:domain] }
    end
  end
  
  def save_internal_struct
    lexeme_class_name = verify_domain(params[:domain])['Lexeme']
    class_name = verify_domain(params[:domain])['Synthetic']
    property_class_name = verify_domain(params[:domain])['Property']
    new_property_class_name = verify_domain(params[:domain])['NewProperty']
    item_class_name = verify_domain(params[:domain])['SyntheticNewPropertyItem']
    case params[:domain]
      when "jp"
        alert_string_1 = "<ul><li>時間を最低日まで指定して下さい！</li></ul>"
        alert_string_2 = "<ul><li>時間を正しく指定して下さい！</li></ul>"
        alert_string_3 = "<ul><li>問題が発生しました、構造を新規できません</li></ul>"
        success_string = "<ul><li>構造を新規しました！</li></ul>"
      when "cn"
        alert_string_1 = "<ul><li>时间最少需要指定到日！</li></ul>"
        alert_string_2 = "<ul><li>请正确指定时间！</li></ul>"
        alert_string_3 = "<ul><li>问题发生，不能创建内部结构</li></ul>"
        success_string = "<ul><li>内部结构已创建！</li></ul>"
      when "en"
        alert_string_1 = "<ul><li>At least specify the time to day please!</li></ul>"
        alert_string_2 = "<ul><li>Please specify the time correctly!</li></ul>"
        alert_string_3 = "<ul><li>Problem occurred, cannot create internal structure</li></ul>"
        success_string = "<ul><li>Internal structure created!</li></ul>"
    end
    
    internal_structure = {}
    customize_category = {}
    customize_text = {}
    customize_time = {}
    for indexes in 0..(params[:meta_size].to_i-1)
      key = 'meta_'+indexes.to_s
      internal_structure[key] = params[key]
      customize_category[key] = {}
      customize_text[key] = {}
      customize_time[key] = {}
      eval(new_property_class_name+%Q|.find(:all, :conditions=>["section='synthetic'"])|).each{|property|
        case property.type_field
          when 'category'
            unless params[key+'_'+property.property_string].blank? or params[key+'_'+property.property_string][:level1].blank?
              temp = eval(property_class_name+%Q|.find_item_by_tree_string_or_array(property.property_string, get_ordered_string_from_params(params[key+'_'+property.property_string].dup))|)
              customize_category[key][property.id] = temp.property_cat_id unless temp.blank?
            end
          when 'text'
            unless params[key+'_'+property.property_string].blank?
              customize_text[key][property.id] = params[key+'_'+property.property_string]
            end
          when 'time'
            unless params[key+'_'+property.property_string].blank? or params[key+'_'+property.property_string].values.join("").blank?
              value = params[key+'_'+property.property_string]
              if (value.has_key?("section(1i)") and (value["section(1i)"]=="" or value["section(2i)"]=="" or value["section(3i)"]=="")) or (value.has_key?("year") and (value["year"]=="" or value["month"]=="" or value["day"]==""))
                flash[:notice_err] = alert_string_1
                temp = get_formatted_ids_and_chars(:original_lexeme_id=>params[:sth_ref_id], :domain=>params[:domain])
                redirect_to :action => "modify_structure", :from=>params[:from], :original_id=>params[:sth_ref_id], :ids=>temp[0], :chars=>temp[1], :domain=>params[:domain]
                return
              else
                begin
                  if value.has_key?("section(1i)")
                    customize_time[key][property.id] = DateTime.civil( value["section(1i)"].to_i, value["section(2i)"].to_i, value["section(3i)"].to_i, value["section(4i)"].to_i, value["section(5i)"].to_i).to_formatted_s(:db)
                  elsif value.has_key?("year")
                    customize_time[key][property.id] = DateTime.civil( value["year"].to_i, value["month"].to_i, value["day"].to_i, value["hour"].to_i, value["minite"].to_i).to_formatted_s(:db)
                  end
                rescue
                  flash[:notice_err] = alert_string_2
                  temp = get_formatted_ids_and_chars(:original_lexeme_id=>params[:sth_ref_id], :domain=>params[:domain])
                  redirect_to :action => "modify_structure", :from=>params[:from], :original_id => params[:sth_ref_id], :ids => temp[0], :chars=>temp[1], :domain=>params[:domain]
                  return
                end
              end
            end
        end
      }
    end
    sth_ref_id = params[:sth_ref_id].to_i
    log = params[:log]
    
    if params[:from] == "new"
      sth_tagging_state = eval(property_class_name+%Q|.find_item_by_tree_string_or_array("sth_tagging_state", "NEW").property_cat_id|)
      begin
        case params[:domain]
          when 'jp'
            JpSynthetic.transaction do
              for indexes in 0..(params[:meta_size].to_i-1)
                sub_structure = save_synthetic_structure(internal_structure, indexes, class_name, sth_ref_id, sth_tagging_state, log)
                if sub_structure.save!
                  JpSyntheticNewPropertyItem.transaction do
                    save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, indexes, sub_structure.id)
                  end
                  JpLexeme.transaction do
                    update_nodes_dictionary(internal_structure, lexeme_class_name, indexes, sth_ref_id)
                  end
                end
              end
            end
          when 'cn'
            CnSynthetic.transaction do
              for indexes in 0..(params[:meta_size].to_i-1)
                sub_structure = save_synthetic_structure(internal_structure, indexes, class_name, sth_ref_id, sth_tagging_state, log)
                if sub_structure.save!
                  CnSyntheticNewPropertyItem.transaction do
                    save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, indexes, sub_structure.id)
                  end
                  CnLexeme.transaction do
                    update_nodes_dictionary(internal_structure, lexeme_class_name, indexes, sth_ref_id)
                  end
                end
              end
            end
          when 'en'
            EnSynthetic.transaction do
              for indexes in 0..(params[:meta_size].to_i-1)
                sub_structure = save_synthetic_structure(internal_structure, indexes, class_name, sth_ref_id, sth_tagging_state, log)
                if sub_structure.save!
                  EnSyntheticNewPropertyItem.transaction do
                    save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, indexes, sub_structure.id)
                  end
                  EnLexeme.transaction do
                    update_nodes_dictionary(internal_structure, lexeme_class_name, indexes, sth_ref_id)
                  end
                end
              end
            end
        end
      rescue Exception => e
        flash[:notice_err] = alert_string_3+"<ul><li>#{e}</li></ul>"
        render(:update) { |page| page.call 'location.reload' }
        return
      else
        flash[:notice] = success_string
        render(:update) { |page| page.call 'location.reload' }
        return
      end
    elsif params[:from] == "modify"
      sth_tagging_state = eval(property_class_name+%Q|.find_item_by_tree_string_or_array("sth_tagging_state", get_ordered_string_from_params(params[:sth_tagging_state].dup)).property_cat_id|)
      begin
        if params[:changed].blank?
          case params[:domain]
            when 'jp'
              JpSynthetic.transaction do
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = eval(class_name+%Q|.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, index])|)
                  index == 0 ? temp_log = log : temp_log = nil
                  if sub_structure.update_attributes!(:sth_tagging_state=>sth_tagging_state, :modified_by=>session[:user_id], :log=>temp_log)
                    JpSyntheticNewPropertyItem.transaction do
                      eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub_structure.id])|).each{|item| item.destroy}
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                  end
                end
              end
            when 'cn'
              CnSynthetic.transaction do
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = eval(class_name+%Q|.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, index])|)
                  index == 0 ? temp_log = log : temp_log = nil
                  if sub_structure.update_attributes!(:sth_tagging_state=>sth_tagging_state, :modified_by=>session[:user_id], :log=>temp_log)
                    CnSyntheticNewPropertyItem.transaction do
                      eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub_structure.id])|).each{|item| item.destroy}
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                  end
                end
              end
            when 'en'
              EnSynthetic.transaction do
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = eval(class_name+%Q|.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, index])|)
                  index == 0 ? temp_log = log : temp_log = nil
                  if sub_structure.update_attributes!(:sth_tagging_state=>sth_tagging_state, :modified_by=>session[:user_id], :log=>temp_log)
                    EnSyntheticNewPropertyItem.transaction do
                      eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub_structure.id])|).each{|item| item.destroy}
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                  end
                end
              end
          end
        elsif params[:changed] == 'true'
          case params[:domain]
            when 'jp'
              JpSynthetic.transaction do
                eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", sth_ref_id])').each{|sub|
                  JpSyntheticNewPropertyItem.transaction do
                    eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
                  end
                  sub.destroy
                }
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = save_synthetic_structure(internal_structure, index, class_name, sth_ref_id, sth_tagging_state, log)
                  if sub_structure.save!
                    JpSyntheticNewPropertyItem.transaction do
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                    JpLexeme.transaction do
                      update_nodes_dictionary(internal_structure, lexeme_class_name, index, sth_ref_id)
                    end
                  end
                end
              end
            when 'cn'
              CnSynthetic.transaction do
                eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", sth_ref_id])').each{|sub|
                  CnSyntheticNewPropertyItem.transaction do
                    eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
                  end
                  sub.destroy
                }
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = save_synthetic_structure(internal_structure, index, class_name, sth_ref_id, sth_tagging_state, log)
                  if sub_structure.save!
                    CnSyntheticNewPropertyItem.transaction do
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                    CnLexeme.transaction do
                      update_nodes_dictionary(internal_structure, lexeme_class_name, index, sth_ref_id)
                    end
                  end
                end
              end
            when 'en'
              EnSynthetic.transaction do
                eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", sth_ref_id])').each{|sub|
                  EnSyntheticNewPropertyItem.transaction do
                    eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
                  end
                  sub.destroy
                }
                for index in 0..(params[:meta_size].to_i-1)
                  sub_structure = save_synthetic_structure(internal_structure, index, class_name, sth_ref_id, sth_tagging_state, log)
                  if sub_structure.save!
                    EnSyntheticNewPropertyItem.transaction do
                      save_synthetic_structure_property(customize_category, customize_text, customize_time, item_class_name, index, sub_structure.id)
                    end
                    EnLexeme.transaction do
                      update_nodes_dictionary(internal_structure, lexeme_class_name, index, sth_ref_id)
                    end
                  end
                end
              end
          end
        end
      rescue Exception => e
        flash[:notice_err] = alert_string_3+"<ul><li>#{e}</li></ul>"
        render(:update) { |page| page.call 'location.reload' }
        return
      else
        flash[:notice] = success_string
        render(:update) { |page| page.call 'location.reload' }
        return
      end

    end
  end
  
  def destroy_struct
    class_name = verify_domain(params[:domain])['Synthetic']
    item_class_name = verify_domain(params[:domain])['SyntheticNewPropertyItem']
    case params[:domain]
      when "jp"
        alert_string = "<ul><li>問題が発生しました、構造を削除できません！</li></ul>"
        success_string = "<ul><li>構造を削除しました！</li></ul>"
      when "cn"
        alert_string = "<ul><li>问题发生，不能删除内部结构！</li></ul>"
        success_string = "<ul><li>内部结构已删除！</li></ul>"
      when "en"
        alert_string = "<ul><li>Problem occurred, cannot delete internal structure!</li></ul>"
        success_string = "<ul><li>Internal structure deleted!</li></ul>"
    end
    begin
      case params[:domain]
        when 'jp'
          JpSynthetic.transaction do
            eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", params[:id].to_i])').each{|sub|
              JpSyntheticNewPropertyItem.transaction do
                eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
              end
              sub.destroy
            }
          end
        when 'cn'
          CnSynthetic.transaction do
            eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", params[:id].to_i])').each{|sub|
              CnSyntheticNewPropertyItem.transaction do
                eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
              end
              sub.destroy
            }
          end
        when 'en'
          EnSynthetic.transaction do
            eval(class_name+'.find(:all, :conditions=>["sth_ref_id=?", params[:id].to_i])').each{|sub|
              EnSyntheticNewPropertyItem.transaction do
                eval(item_class_name+%Q|.find(:all, :conditions=>["ref_id=?",sub.id])|).each{|item| item.destroy}
              end
              sub.destroy
            }
          end
      end
    rescue Exception => e
      flash[:notice_err] = alert_string+"<ul><li>#{e}</li></ul>"
    else
      flash[:notice] = success_string
    end
    redirect_to :action => 'show', :id => params[:id]
  end
  
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
      return
    end
  end
  
  def authorize_admin
    unless User.find_by_id(session[:user_id]).group_name == "admin"
      flash[:notice_err] = "<ul><li>You are not administrator!</li></ul>"
      redirect_to(:controller => "users" , :action => "chg_pwd" )
      return
    end
  end
  
  ### set charset
  def set_charset
    headers["Content-Type"] = "text/html; charset = UTF-8"
  end

  ### hash contail levels fieds
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
      collection = eval(item_class+%Q|.find(:all, :select=>"ref_id", :conditions=>search)|)
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
      ids.each{|struct_id| temp_ids << eval(class_name+'.find(struct_id).lexeme.id')}
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
      collection.concat(eval(class_name+'.find(:all, :conditions=>["id in (#{id_string})"])'))
      start = start + step + 1
    end
    return collection
  end

  ### :ids, :chars, :count, :level
  def get_meta_structures(fields={})
    ids = fields[:ids]
    chars = fields[:chars]
    fields[:count].blank? ? count=0 : count=fields[:count]
    fields[:level].blank? ? level=1 : level = fields[:level]
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

  ### :chars_index, :chars, 
  ### :domain  jp, cn, en
  ### :type    new, modify, delete
  ### :ids     aaa*++*bbb*+*ccc*++*ddd
  ### :left_id, :right_id  the left lexeme_id and right lexeme_id after new divide
  ### :left, :right        the left and right part characters after new divide
  ### :level               the new dividing level
  ### :ids_section         the indexes of the character on the left of dividing point.  Format:  level_1_index,level_2_index,level_3_index,....
  
  def get_ids_and_chars(field={})
    synthetic_class = verify_domain(field[:domain])['Synthetic']
    case field[:type]
      when "new"
        if field[:ids] == ""
          ids = field[:left_id]+'*+*'+field[:right_id]
          eval(synthetic_class+'.exists?(:sth_ref_id=>field[:left_id].to_i)') ? left = field[:left] : left = field[:left].scan(/./).join("-")
          eval(synthetic_class+'.exists?(:sth_ref_id=>field[:right_id].to_i)') ? right = field[:right] : right = field[:right].scan(/./).join("-")
          chars = left+'*+*'+right
        else
          ids_array = swap_idsarray_and_ids(field[:ids],[])
          indexes = field[:ids_section].split(',')
          if field[:level].to_i == indexes.size
            temp = ""
            temp1 = ""
            insert_point = ""
            for index in 0..indexes.size-1
              temp << '['+indexes[index]+']'
              index == indexes.size-1 ? insert_point = (indexes[index].to_i+1).to_s : temp1 << '['+indexes[index]+']'
            end
            eval ('ids_array'+temp+"='#{field[:left_id]}'")
            eval ('ids_array'+temp1+"\.insert\(#{insert_point}, '#{field[:right_id]}'\)")
          elsif field[:level].to_i == indexes.size+1
            temp = ""
            indexes.each{|index_item| temp << '['+index_item+']' }
            eval ('ids_array'+temp+"=\['#{field[:left_id]}', '#{field[:right_id]}'\]")
          end
          ids = swap_idsarray_and_ids("", ids_array)
          from_to = field[:chars_index].split(',')
          field[:chars].slice!(from_to[0].to_i..from_to[1].to_i)
          eval(synthetic_class+'.exists?(:sth_ref_id=>field[:left_id].to_i)') ? left = field[:left] : left = field[:left].scan(/./).join("-")
          eval(synthetic_class+'.exists?(:sth_ref_id=>field[:right_id].to_i)') ? right = field[:right] : right = field[:right].scan(/./).join("-")
          chars = field[:chars].insert(from_to[0].to_i, left+'*'+'+'*field[:level].to_i+'*'+right)
        end
      when "modify"
        ids_array = swap_idsarray_and_ids(field[:ids],[])
        indexes = field[:ids_section].split(',')
        temp = ""
        temp1 = ""
        for index in 0..indexes.size-1
          temp << '['+indexes[index]+']'
          index == indexes.size-1 ? temp1 << '['+(indexes[index].to_i-1).to_s+']' : temp1 << '['+indexes[index]+']'
        end
        eval ('ids_array'+temp1+"='#{field[:left_id]}'")
        eval ('ids_array'+temp+"='#{field[:right_id]}'")
        ids = swap_idsarray_and_ids("", ids_array)
        from_to = field[:chars_index].split(',')
        field[:chars].slice!(from_to[0].to_i, from_to[1].to_i)
        eval(synthetic_class+'.exists?(:sth_ref_id=>field[:left_id].to_i)') ? left = field[:left] : left = field[:left].scan(/./).join("-")
        eval(synthetic_class+'.exists?(:sth_ref_id=>field[:right_id].to_i)') ? right = field[:right] : right = field[:right].scan(/./).join("-")
        chars = field[:chars].insert(from_to[0].to_i, left+'*'+'+'*field[:level].to_i+'*'+right)
      when "delete"
        ids_array = swap_idsarray_and_ids(field[:ids],[])
        indexes = field[:ids_section].split(',')
        temp = ""
        temp1 = ""
        delete_point = ""
        for index in 0..indexes.size-1
          temp << '['+indexes[index]+']'
          index == indexes.size-1 ? delete_point = (indexes[index].to_i-1).to_s : temp1 << '['+indexes[index]+']'
        end
        eval ('ids_array'+temp+"='-'")
        eval ('ids_array'+temp1+"\.delete_at\(#{delete_point}\)")
        ids = swap_idsarray_and_ids("", ids_array)
        ids = "" if ids == "-"
        from_to = field[:chars_index].split(',')
        temp = field[:chars].slice(from_to[0].to_i, from_to[1].to_i)
        temp = temp.split(/\*\++\*/).to_s
        temp = temp.split("-").to_s.split("").join("-")
        field[:chars].slice!(from_to[0].to_i, from_to[1].to_i)
        chars = field[:chars].insert(from_to[0].to_i, temp)
    end
    return ids, chars
  end

  def swap_idsarray_and_ids(string="", array=[], step=1)
    unless string.blank?
      string.split('*'+'+'*step+'*').each{|item|
        if item.include?('*')
          array << swap_idsarray_and_ids(item, [], step+1)
        else
          array << item
        end
      }
      return array
    end
    unless array.blank?
      for index in 0..array.size-1
        array[index] = swap_idsarray_and_ids("", array[index], step+1) unless array[index] =~ /\d*/ or array[index] == "-"
      end
      return array.join('*'+'+'*step+'*')
    end
  end

  def save_synthetic_structure(internal_structure={}, indexes=nil, class_name=nil, sth_ref_id=nil, sth_tagging_state=nil, log=nil)
    temp_struct_string = internal_structure['meta_'+indexes.to_s].split(',').map{|item| '-'+item+'-'}.join(',')
    sub_structure = eval(class_name+%Q|.new(:sth_ref_id=>sth_ref_id, :sth_meta_id=>indexes, :sth_struct=>temp_struct_string, :sth_tagging_state=>sth_tagging_state, :modified_by=>session[:user_id])|)
    sub_structure.log = log if indexes == 0
    return sub_structure
  end
              
  def save_synthetic_structure_property(customize_category={}, customize_text={}, customize_time={}, item_class_name=nil, indexes=nil, sub_structure_id=nil)
    customize_category['meta_'+indexes.to_s].each{|id,value| eval(item_class_name+'.create!(:property_id=>id, :ref_id=>sub_structure_id, :category=>value)') }
    customize_text['meta_'+indexes.to_s].each{|id,value| eval(item_class_name+'.create!(:property_id=>id, :ref_id=>sub_structure_id, :text=>value)') }
    customize_time['meta_'+indexes.to_s].each{|id,value| eval(item_class_name+'.create!(:property_id=>id, :ref_id=>sub_structure_id, :time=>value)') }
  end
  
  def update_nodes_dictionary(internal_structure={}, lexeme_class_name=nil, indexes=nil, sth_ref_id=nil)
    original_dic = eval(lexeme_class_name+'.find(sth_ref_id.to_s).dictionary_item.list')
    internal_structure['meta_'+indexes.to_s].split(',').each{|item|
      if item =~ /^\d+$/
        temp_lexeme = eval(lexeme_class_name+'.find(item.to_s)')
        temp_dic = temp_lexeme.dictionary_item.list
        diff = original_dic - temp_dic
        unless diff.blank?
          temp_dic = temp_dic.concat(diff).sort
          temp_lexeme.update_attributes!(:dictionary=>temp_dic.map{|item| '-'+item.to_s+'-'}.join(','))
        end
      end
    }
  end
end
