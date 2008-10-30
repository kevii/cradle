# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'date'
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  ### Pick a unique cookie name to distinguish our session data from others
  session :session_key => '_cradle_session_id'
  ### set charset
  before_filter :set_charset
  
  filter_parameter_logging :password

  def update_property_list
    class_name = verify_domain(params[:domain])['Property']
    value = params["level"+params[:level].to_s]
    if value.blank?
      id = 0
    else
      if params[:id].to_i > 0
        children = class_name.constantize.find(params[:id].to_i).children
      else
        children = class_name.constantize.find(:all, :conditions=>['property_string = ? and parent_id is null', params[:type]], :order=>'property_cat_id ASC')
      end
      children.each{|child| id = child.id if child.value == value}
    end
    render :update do |page|
      page.replace "#{params[:prefix]}"+"#{params[:type]}_level#{params[:level].to_i+1}_list",
                   :inline=>"<%= display_property_list(:type=>'#{params[:type]}', :domain=>'#{params[:domain]}', :prefix=>'#{params[:prefix]}', :state=>'#{params[:state]}', :option=>'#{params[:option]}', :id=>#{id}, :level=>#{params[:level].to_i+1}) %>"
    end
  end

  
#  
#<%= button_to_remote 'test', :url=>{:action=>:test_count} %>
#<div id='wrapper'>ok</div>
#<p>
#<span class="progressBar" id="progressBar">0%</span>

  
  
  def test_count
    count = 0
    @uid = DumpDataWorker.asynch_counting(:count=>count)
    session[:update_percentage] = 1
    render(:update){|page| page[:wrapper].replace_html :inline=>"<%= periodically_call_remote(:url=>{:action=>'update_count', :uid=>@uid}, :frequency=>'10') %>"}
  end

  def update_count
    @display_number = 0
    temp = 0
    @uid = params[:uid]
    while(temp != nil)
      @display_number = temp
      temp = Workling::Return::Store.get(params[:uid])
    end
    if @display_number == 0
      render(:update){|page| page.insert_html :bottom, 'wrapper', :inline=>""}
    else
      render(:update){|page|
        if @display_number != 100
          page.insert_html :bottom, 'wrapper', :inline=>""
        else
          page.remove 'wrapper'
        end
        page << "function update_percentage(){myJsProgressBarHandler.setPercentage('progressBar', '#{@display_number}');return false;}"
        page << "window.onload=update_percentage();"
      }
    end
  end
  
  
  
  
  
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

  def get_time_string_from_hash(option)
    if option.has_key?("section(1i)")
      return DateTime.civil(option["section(1i)"].to_i, option["section(2i)"].to_i, option["section(3i)"].to_i, option["section(4i)"].to_i, option["section(5i)"].to_i).to_formatted_s(:db)
    elsif option.has_key?("year")
      return DateTime.civil(option["year"].to_i, option["month"].to_i, option["day"].to_i, option["hour"].to_i, option["minute"].to_i).to_formatted_s(:db)
    end
  end
  
  def verify_time_property(option)
    message = ""
    time_string = ""
    case option[:domain]
      when "jp"
        alert_string_1 = "<ul><li>時間を最低日まで指定して下さい！</li></ul>"
        alert_string_2 = "<ul><li>時間を正しく指定して下さい！</li></ul>"
      when "cn"
        alert_string_1 = "<ul><li>时间最少需要指定到日！</li></ul>"
        alert_string_2 = "<ul><li>请正确指定时间！</li></ul>"
      when "en"
        alert_string_1 = "<ul><li>At least specify the time to day please!</li></ul>"
        alert_string_2 = "<ul><li>Please specify the time correctly!</li></ul>"
    end
    if option[:value].values.join("").blank?
      return "", nil
    else
      if (option[:value].has_key?("section(1i)") and (option[:value]["section(1i)"]=="" or option[:value]["section(2i)"]=="" or option[:value]["section(3i)"]=="")) or
         (option[:value].has_key?("year") and (option[:value]["year"]=="" or option[:value]["month"]=="" or option[:value]["day"]==""))
        message = alert_string_1
      else
        begin
          time_string = get_time_string_from_hash(option[:value])
        rescue
          message = alert_string_2
        end
      end
      return message, time_string
    end
  end
end
