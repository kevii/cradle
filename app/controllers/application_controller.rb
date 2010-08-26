# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'date'

class ApplicationController < ActionController::Base
  layout 'cradle'
  helper :all
  include CradleModule
  
	### for maintenance
  include MaintenanceMode
  before_filter :disabled?

  
  ### Pick a unique cookie name to distinguish our session data from others
  session :session_key => '_cradle_session_id'
  ### set charset
  before_filter :set_charset
  
  filter_parameter_logging :password
  
  def index
      session[:jp_section_list] = ['1_surface', '2_reading', '3_pronunciation', '4_base_id', '5_root_id', '6_dictionary', '7_pos', '8_ctype', '9_cform', '100_sth_struct'] if session[:jp_section_list].blank?
      session[:cn_section_list] = ['1_surface', '2_reading', '3_dictionary', '4_pos', '100_sth_struct'] if session[:cn_section_list].blank?
    if session[:user_id].blank?
      session[:jp_dict_id] = JpProperty.find(:all, :conditions=>["property_string='dictionary' and property_cat_id > 0"]).select{|item| item.value !~ /\*$/}.map{|dict| dict.property_cat_id}
      session[:cn_dict_id] = CnProperty.find_inside('dictionary', 'property_cat_id > 0').select{|item| item.value !~ /\*$/}.map(&:property_cat_id)
    else
      session[:jp_dict_id] = JpProperty.find(:all, :conditions=>["property_string='dictionary' and property_cat_id > 0"]).map{|dict| dict.property_cat_id}
      session[:cn_dict_id] = CnProperty.find_inside('dictionary', 'property_cat_id > 0').map(&:property_cat_id)
    end
  end

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
    params[:prefix].blank? ? prefix = "" : prefix = params[:prefix]+'_' 
    render :update do |page|
      page.replace prefix+"#{params[:type]}_level#{params[:level].to_i+1}_list",
                   :inline=>"<%= display_property_list(:type=>'#{params[:type]}', :domain=>'#{params[:domain]}', :prefix=>'#{params[:prefix]}', :state=>'#{params[:state]}', :option=>'#{params[:option]}', :id=>#{id}, :level=>#{params[:level].to_i+1}) %>"
    end
  end

  def start_dump
    case params[:domain]
    when 'jp' then section_list = session[:jp_section_list]
    when 'cn' then section_list = session[:cn_section_list]
    when 'en' then section_list = session[:en_section_list]
    end
    @uid = DumpDataWorker.asynch_dump_data(:static_condition => params[:static_condition],
                                           :dynamic_lexeme_condition => params[:dynamic_lexeme_condition],
                                           :dynamic_synthetic_condition => params[:dynamic_synthetic_condition],
                                           :show_conditions => params[:show_conditions],
                                           :simple_search => params[:simple_search],
                                           :section_list => section_list,
                                           :domain => params[:domain],
                                           :dependency => params[:dependency].blank? ? nil : 1,
                                           :root_url => root_url,
                                           :rails_root => RAILS_ROOT,
                                           :file_name => ('user_dump_file/' + Time.now.to_s(:db).gsub(/[^\d]/, '-')))
     render(:update){|page|
       page[:period_caller].replace_html :inline=>"<%= periodically_call_remote(:url=>{:action=>'update_indicator', :uid=>@uid}, :frequency=>'2', :variable=>'progress_indicator') %>"
       page[:indicator].show
     }
  end

  def update_indicator
    @display = "0"
    temp = "1"
    while(temp != nil)
      @display = temp
      temp = Workling::Return::Store.get(params[:uid])
    end
    render(:update){|page|
      if @display =~ /^\d+$/
        page << "function update_indicator(){myJsProgressBarHandler.setPercentage('progressBar', '#{@display}');return false;}"
        page << "window.onload=update_indicator();"
      else
        page << "function update_indicator(){myJsProgressBarHandler.setPercentage('progressBar', '100');return false;}"
        page << "progress_indicator.stop();"
        page.replace_html 'wrapper', :inline=>"Finished.&nbsp;&nbsp;Click to download:&nbsp;&nbsp;<a href='#{@display}'>#{@display.split('/')[-1]}</a>"
      end
    }
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
