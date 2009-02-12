module CustomizefieldHelper
  include CradleModule
  
  ## type: property_string
  ## domain:  jp, cn, en
  ## prefix:  prefix string add to select tag name
  ## state:   search, new, modify
  ## id:    previous level's database record id
  ## level: current display level
  def display_property_list(field={})
    type = field[:type]
    domain = field[:domain]
    field[:prefix].blank? ? prefix = "" : prefix = field[:prefix]+"_"
    state = field[:state]
    field[:id].blank? ? id = 0 : id = field[:id]
    field[:level].blank? ? level = 1 : level = field[:level]
    field[:option].blank? ? option = "" : option = field[:option]

    html_string = ""
    function_string = "update_property_list"
    class_name = verify_domain(domain)["Property"]
    name = "level#{level.to_s}"
    select_name = "#{prefix}"+type+"["+name+"]"
    select_id = "#{prefix}"+type+"_"+name
    span_id = select_id+"_list"
    next_span_id = "#{prefix}"+type+"_level"+(level+1).to_s+"_list"
    ajax_string = remote_function(:url=>{:controller=>domain, :action=>function_string, :type=>type, :domain=>domain, :prefix=>prefix.chop, :state=>state, :id=>id, :level=>level, :option=>option},
                                  :with=>"'#{name}='+value")
    if level==1
      if ['search','new'].include?(state) or (state=='modify' and id==0)
        collection = class_name.constantize.find(:all, :conditions=>['property_string = ? and parent_id is null', type], :order=>'property_cat_id ASC').map{|item| item.value}
        html_string << "<span id='#{span_id}' >\n"
        html_string << "<select id='#{select_id}' name='#{select_name}' onchange=\"#{ajax_string}\" #{option}>\n"
        html_string << "  <option selected value=''></option>\n" unless collection.include?("")
        html_string << options_for_select(collection)
        html_string << "</select>\n"
        html_string << "<span id='#{next_span_id}'></span>\n"
        html_string << "</span>\n"
      elsif state == 'modify'
        roots = []
        parent = class_name.constantize.find(:first, :conditions=>['property_string =? and property_cat_id =?', type, id])
        while not parent.blank?
          roots << parent
          parent = parent.parent
        end
        html_string << first_html_list_for_mdification(roots.reverse, type, prefix.chop, domain, option)
      end
    else  ##chain display
      if id > 0
        parent = class_name.constantize.find(id)
        collection = parent.children.map{|item| item.value}
      else
        collection = []
      end
      html_string << "<span id='#{span_id}' >\n"
      unless collection.blank?
        html_string << "<select id='#{select_id}' name='#{select_name}' onchange=\"#{ajax_string}\" #{option}>\n"
        if (state == 'search' and not collection.include?("")) or (['new', 'modify'].include?(state) and parent.property_cat_id > 0)
            html_string << "  <option selected value=''></option>\n"
        end
        html_string << options_for_select(collection)
        html_string << "</select>\n"
        html_string << "<span id='#{next_span_id}' ></span>\n"
      end
      html_string << "</span>\n"
    end
  end

  ##  domain:  jp, cn, en
  ##  prefix:  prefix string add to select tag name
  ##  id: lexeme_id or sth_id when in modification state
  ##  section  lexeme or synthetic
  ##  state:   search, new, modify
  def customize_field_html(field={})
    state = field[:state]
    field[:id].blank? ? id=nil : id=field[:id]
    domain = field[:domain]
    section = field[:section]
    if field[:prefix].blank?
      prefix = ""
      orig_prefix = ""
    else
      prefix = field[:prefix]+"_"
      orig_prefix = field[:prefix]
    end
     
    html_string = ""
    section == "lexeme" ? class_name = verify_domain(domain)["Lexeme"] : class_name = verify_domain(domain)["Synthetic"]
    property_class_name = verify_domain(domain)["Property"]
    section == "lexeme" ? item_class_name = verify_domain(domain)["LexemeNewPropertyItem"] : item_class_name = verify_domain(domain)["SyntheticNewPropertyItem"]
    properties = verify_domain(domain)["NewProperty"].constantize.find(:all, :conditions=>["section=?", section])

    properties.each_with_index{|item, index|
      next unless verify_domain(domain)["session_dic_id_array"].include?(item.dictionary_id)
      next if item.type_field=="category" and not property_class_name.constantize.exists?(:property_string=>item.property_string)
      html_string << "<tr>\n" if index % 2 == 0
      html_string << "<td>\n"+item.human_name+"</td>\n"
      case item.type_field
        when "category"
          if state == "search"
            html_string << "<td>\n"
            html_string << "<select id='operator_#{prefix+item.property_string}' name='#{prefix+item.property_string}[operator]' style='width:100%;'>\n"
            html_string << options_for_select(operator2, "=")
            html_string << "</select>\n"
            html_string << "</td>\n"
          end
          html_string << "<td>\n"
          case state
            when "search"
              html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>orig_prefix, :state=>state)
            when "new"
              temp = verify_domain(domain)["NewProperty"].constantize.find(:first, :conditions=>["property_string=?", item.property_string]).default_value
              if temp.blank?
                html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>orig_prefix, :state=>state)
              else
                html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>orig_prefix, :state=>"modify", :id=>temp.to_i)
              end
            when "modify"
              html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>orig_prefix, :state=>state, :id=>eval('class_name.constantize.find(id).'+item.property_string))
          end
          html_string << "</td>\n"
        when "text"
          if state == "search"
            html_string << "<td>\n"
            html_string << "<select id='operator_#{prefix+item.property_string}' name='#{prefix+item.property_string}[operator]' style='width:100%;'>\n"
            html_string << options_for_select(operator1, "=")
            html_string << "</select>\n"
            html_string << "</td>\n"
          end
          html_string << "<td>\n"
          case state
            when "search"
              html_string << text_field("#{prefix+item.property_string}", "value", {:style=>"width:100%;", :class=>'text-field'})
            when "new"
              temp = verify_domain(domain)["NewProperty"].constantize.find(:first, :conditions=>["property_string=?", item.property_string]).default_value
              if temp.blank?
                html_string << text_field_tag("#{prefix+item.property_string}", nil, :style=>"width:100%;", :class=>'text-field')
              else
                html_string << text_field_tag("#{prefix+item.property_string}", temp, :style=>"width:100%;", :class=>'text-field')
              end
            when "modify"
              html_string << text_field_tag("#{prefix+item.property_string}", eval('class_name.constantize.find(id).'+item.property_string), :style=>"width:100%;", :class=>'text-field')
          end
          html_string << "</td>\n"
        when "time"
          if state == "search"
            html_string << "<td>\n"
            html_string << "<select id='operator_#{prefix+item.property_string}' name='#{prefix+item.property_string}[operator]' style='width:100%;'>\n"
            html_string << options_for_select(operator4, "<=")
            html_string << "</select>\n"
            html_string << "</td>\n"
          end
          html_string << "<td>\n"
          case state
            when "search"
              html_string << datetime_select(prefix+item.property_string, "section", :use_month_numbers => true, :include_blank => true)
            when "new"
              temp =verify_domain(domain)["NewProperty"].constantize.find(:first, :conditions=>["property_string=?", item.property_string]).default_value
              if temp.blank?
                html_string << datetime_select(prefix+item.property_string, "section", :use_month_numbers => true, :include_blank => true)
              else
                temp_array = temp.split(/-|\s|:/)
                temp_time = DateTime.civil(temp_array[0].to_i, temp_array[1].to_i, temp_array[2].to_i, temp_array[3].to_i, temp_array[4].to_i)
                html_string << select_datetime(temp_time, :use_month_numbers => true, :include_blank => true,:prefix=>prefix+item.property_string)
              end
            when "modify"
              html_string << select_datetime(eval('class_name.constantize.find(id).'+item.property_string), :use_month_numbers => true, :include_blank => true,:prefix=>prefix+item.property_string)
          end
          html_string << "</td>\n"
      end
      html_string << "<td></td>\n" if index % 2 == 0
      html_string << "</tr>\n" if (index % 2 == 1) or (index == properties.size - 1) 
    }
    return html_string
  end
  
  private
  def first_html_list_for_mdification(roots=nil, type="", prefix="", domain="", option="", level=1)
    prefix.blank? ? prefix = "" : prefix = prefix+"_"
    html_string = ""
    name = "level"+level.to_s
    html_string << "<span id='#{prefix}#{type}_#{name}_list' >\n"
    level == 1 ? id = 0 : id = roots[level-2].id
    ajax_string = remote_function(:url=>{:controller=>domain, :action=>'update_property_list',  :type=>type, :domain=>domain, :prefix=>prefix.chop, :state=>'modify', :id=>id, :level=>level, :option=>option}, :with=>"'#{name}='+value")
    html_string << "<select id='#{prefix}#{type}_#{name}' name='#{prefix}#{type}[#{name}]' onchange=\"#{ajax_string}\" #{option}>\n"
    if level==1
      class_name = verify_domain(domain)["Property"]
      collection = class_name.constantize.find(:all, :conditions=>['property_string = ? and parent_id is null', type], :order=>'property_cat_id ASC').map{|item| item.value}
      unless collection.include?("") or ["tagging_state", "sth_tagging_state"].include?(type)
        html_string << "  <option value=''></option>\n"
      end
    else
      collection = roots[level-2].children.map{|item| item.value}
      if roots[level-2].property_cat_id > 0
        html_string << "  <option value=''></option>\n"
      end
    end
    html_string << options_for_select(collection, roots[level-1].value)
    html_string << "</select>\n"
    if level < roots.size
      html_string << first_html_list_for_mdification(roots, type, prefix.chop, domain, option, level+1)
    else
      html_string << "<span id='#{prefix}#{type}_level#{(level+1).to_s}_list' >\n"
    end
    html_string << "</span>\n"
    return html_string
  end
end
