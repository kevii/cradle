# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def button_to_remote(name, options = {}, html_options = {})
    cradle_button_to_function(name, remote_function(options), html_options)
  end

  def verify_domain(domain=nil)
    class_name = {}
    case domain
      when "jp"
        class_name["Lexeme"] = "JpLexeme"
        class_name["Synthetic"] = "JpSynthetic"
        class_name["Property"] = "JpProperty"
        class_name["NewProperty"] = "JpNewProperty"
        class_name["LexemeNewPropertyItem"] = "JpLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "JpSyntheticNewPropertyItem"
      when "cn"
        class_name["Lexeme"] = "CnLexeme"
        class_name["Synthetic"] = "CnSynthetic"
        class_name["Property"] = "CnProperty"
        class_name["NewProperty"] = "CnNewProperty"
        class_name["LexemeNewPropertyItem"] = "CnLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "CnSyntheticNewPropertyItem"
      when "en"
        class_name["Lexeme"] = "EnLexeme"
        class_name["Synthetic"] = "EnSynthetic"
        class_name["Property"] = "EnProperty"
        class_name["NewProperty"] = "EnNewProperty"
        class_name["LexemeNewPropertyItem"] = "EnLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "EnSyntheticNewPropertyItem"
    end
    return class_name
  end

  def initial_property_name(domain=nil)
    case domain
      when "jp"
        { "id"=>"ID",                     "surface"=>"単語",                  "reading"=>"読み",
          "pronunciation"=>"発音",         "base_id"=>"Base",                 "root_id"=>"Root",
          "pos"=>"品詞",                   "ctype"=>"活用型",                  "cform"=>"活用形",
          "dictionary"=>"辞書",            "tagging_state"=>"状態",            "log"=>"備考",
          "created_by"=>"新規者",          "modified_by"=>"更新者",             "updated_at"=>"更新時間",
          "sth_struct"=>"構造",            "sth_tagging_state"=>"状態",        "character_number"=>"文字数" }
      when "cn"
      when "en"
    end  
  end
  
  def initial_property_desc(domain=nil)
    case domain
      when "jp"
        { "id"=>"単語ID",                    "surface"=>"単語表記",               "reading"=>"単語読み",
          "pronunciation"=>"単語発音",        "base_id"=>"単語のBase",             "root_id"=>"単語のRoot",
          "pos"=>"品詞情報",                  "ctype"=>"活用型情報",                "cform"=>"活用形情報",
          "dictionary"=>"辞書情報",           "tagging_state"=>"タグ状態",          "log" => "備考内容",
          "created_by"=>"新規者情報",         "modified_by"=>"更新者情報",           "updated_at"=>"更新時間情報",
          "sth_struct"=>"内部構造",           "sth_tagging_state"=>"タグ状態" }
      when "cn"
      when "en"
    end  
  end
  
  def operator0
    return { ">"=>">", "<"=>"<", "<="=>"<=", ">="=>">=", "="=>"=", "!="=>"!=", "like"=>"=~", "in"=>"in", "not in"=>"not in", "and"=>"and", "or"=>"or"}
  end
  
  def operator
    return { ">"=>">", "<"=>"<", "<="=>"<=", ">="=>">=", "="=>"=" }
  end
  
  def operator1
    return { "="=>"=", "=~"=>"like"}
  end

  def operator2
    return { "="=>"=", "!="=>"!=", "in"=>"in", "not in"=>"not in" }
  end

  def operator3
    return { "="=>"=", "!="=>"!=" }
  end
  
  def operator4
    return { "<="=>"<=", ">="=>">=" }
  end
  
  def operator5
    return {"and"=>"and", "or"=>"or"}
  end

  def per_page_list
    return ["10", "30", "50", "100"]
  end
  
  def dictionary_color
    { 1=>"red", 2=>"pink", 3=>"orange", 4=>"brown", 5=>"gold", 6=>"yellow", 7=>"green", 8=>"turquoise",
      9=>"blue", 10=>"purple", 11=>"grey", 12=>"black", 13=>"deepskyblue", 14=>"springgreen", 15=>"olive",
      16=>"saddlebrown", 17=>"fuchsia", 18=>"indigo", 19=>"cyan", 20=>"cadetblue"}  
  end
  
  def struct_level
    { 1=>"①", 2=>"②", 3=>"③", 4=>"④", 5=>"⑤", 6=>"⑥", 7=>"⑦", 8=>"⑧", 9=>"⑨", 10=>"⑩"}  
  end
  
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
    ajax_string = remote_function(:url=>{:controller=>domain, :action=>function_string, :type=>type, :domain=>domain, :prefix=>prefix, :state=>state, :id=>id, :level=>level, :option=>option},
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
        html_string << first_html_list_for_mdification(roots.reverse, type, prefix, domain, option)
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

  def generate_tree_view(option)
    case option[:domain]
      when "jp"
        title = "ツリー構造"
        error_message = "下の単語の内部構造定義があるので、そちらを使ってツリーを定義してください："
      when "cn"
        title = "内部构造"
        error_message = "下面的单词的内部结构定义已经存在，请使用该结构重新组织构造树："
      when "en"
    end
    html_string = ""
    html_string << "<span style='color:#dfd; background: #1e2078; font-family:sans-serif; padding:0.2em 1em;'>#{title}</span>\n<p>\n"
    html_string << generate_script_part(:domain=>option[:domain], :id=>option[:id])
  end

  ### option[:domain]
  ### option[:use_link]
  ### option[:id]
  ### option[:call_javascript]
  def generate_script_part(option)
    lexeme_name = verify_domain(option[:domain])['Lexeme']
    class_name = verify_domain(option[:domain])['Synthetic']
    option[:call_javascript] = 'false' if option[:call_javascript].blank?
    option[:use_link] = 'true' if option[:use_link].blank?
    html_string = ""
    html_string << "<script>"
    html_string << "var myTree = null;"
    html_string << "function CreateTree() {"
    html_string << "myTree=new ECOTree('myTree','myTreeContainer');"
    html_string << "myTree.config.linkColor = 'black';"
    html_string << "myTree.config.nodeBorderColor = 'black';"
    html_string << "myTree.config.colorStyle = ECOTree.CS_NODE;"
    html_string << "myTree.config.nodeFill = ECOTree.NF_FLAT;"
    html_string << "myTree.config.nodeColor = '#89bfe5';"
    html_string << "myTree.config.nodeSelColor = 'LavenderBlush';"
    node = get_node_tree(:structure=>lexeme_name.constantize.find(option[:id]).struct, :first_time=>'true', :class_name=>class_name, :lexeme_name=>lexeme_name)
    html_string << generate_core_script(:node=>node, :domain=>option[:domain], :use_link=>option[:use_link])[0]
    html_string << "myTree.UpdateTree();"
    html_string << "}"
    html_string << "window.onload=CreateTree();" if option[:call_javascript] == 'true'
    html_string << "</script>\n"
    return html_string
  end

  private
  def cradle_button_to_function(name, function, html_options = {})
    html_options.symbolize_keys!
    tag(:input, html_options.merge({
    :type => "button", :value => name,
    :onclick => (html_options[:onclick] ? "#{html_options[:onclick]}; " : "") + "#{function};"
    }))
  end
  
  def first_html_list_for_mdification(roots=nil, type="", prefix="", domain="", option="", level=1)
    html_string = ""
    name = "level"+level.to_s
    html_string << "<span id='#{prefix}#{type}_#{name}_list' >\n"
    level == 1 ? id = 0 : id = roots[level-2].id
    ajax_string = remote_function(:url=>{:controller=>domain, :action=>'update_property_list',  :type=>type, :domain=>domain, :prefix=>prefix, :state=>'modify', :id=>id, :level=>level, :option=>option}, :with=>"'#{name}='+value")
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
      html_string << first_html_list_for_mdification(roots, type, prefix, domain, option, level+1)
    else
      html_string << "<span id='#{prefix}#{type}_level#{(level+1).to_s}_list' >\n"
    end
    html_string << "</span>\n"
    return html_string
  end
  
  def is_string(item)
      begin
        item.chomp
      rescue
        return false
      else
        return true
      end
  end
  
  ### node_hash: {:type, :id, :surface, :sub_tree}
  ### sub_tree:  [node_hash, node_hash, node_hash, ...]
  ### type: root, meta, node
  ### option[:structure] synthetic structure
  ### option[:class_name] synthetic class
  ### option[:lexeme_name] lexeme class
  ### option[:first_time] root or not
  def get_node_tree(option)
    option[:first_time] = 'false' if option[:first_time].blank? 
    node_hash = {}
    if option[:first_time] == 'true'
      node_hash[:type] = 'root'
      node_hash[:id] = option[:structure].sth_ref_id
      node_hash[:surface] = option[:structure].sth_surface
    elsif option[:structure].sth_meta_id != 0
      node_hash[:type] = 'meta'
      node_hash[:id] = nil
      node_hash[:surface] = option[:structure].sth_surface
    else
      node_hash[:type] = 'node'
      node_hash[:id] = option[:structure].sth_ref_id
      node_hash[:surface] = option[:structure].sth_surface
    end
    temp_node_array = []
    option[:structure].sth_struct.split(',').map{|item| item.delete('-')}.each{|id_or_meta|
      if id_or_meta =~ /^\d+$/
        lexeme = option[:lexeme_name].constantize.find(id_or_meta.to_i)
        if lexeme.struct.blank? 
          temp_node_array << {:type=>'node', :id=>lexeme.id, :surface=>lexeme.surface, :sub_tree=>nil}
        else
          temp_node_array << get_node_tree(:structure=>lexeme.struct, :class_name=>option[:class_name], :lexeme_name=>option[:lexeme_name])
        end
      elsif id_or_meta =~ /^meta_(\d+)$/
        temp_node_array << get_node_tree(:structure=>option[:class_name].constantize.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", option[:structure].sth_ref_id, $1.to_i]),
                                         :class_name=>option[:class_name], :lexeme_name=>option[:lexeme_name])
      end
    }
    node_hash[:sub_tree] = temp_node_array
    return node_hash
  end

  ### option[:use_link]   true or false on node link
  ### option[:number]     node number in tree
  ### option[:parent]     parent node number in tree
  ### option[:node]       tree structure
  ### option[:domain]     specify the ajax call's controller
  def generate_core_script(option)
    option[:number] = 0 if option[:number].blank?
    option[:parent] = -1 if option[:parent].blank?
    javascript_string = ""
    length = (option[:node][:surface].length/3)*20+15
    if option[:use_link] == 'true' and option[:node][:type] == 'node'
      ajax_string = remote_function(:url=>{:controller=>option[:domain], :action=>'show_desc', :id=>option[:node][:id]}, :with=>"'state='+Element.visible('show_desc')")
      javascript_string << "myTree.add(#{option[:number]}, #{option[:parent]}, '#{option[:node][:surface]}', #{length}, '', '', '', \"#{ajax_string}\");"
    else
      javascript_string << "myTree.add(#{option[:number]}, #{option[:parent]}, '#{option[:node][:surface]}', #{length});"
      javascript_string << "myTree.setNodeTarget(#{option[:number]}, '', false);"
    end
    if option[:node][:sub_tree].blank?
      option[:number] = option[:number] + 1
    else
      option[:parent] = option[:number]
      option[:number] = option[:number] + 1
      option[:node][:sub_tree].each{|node|
        temp = generate_core_script(:node=>node, :number=>option[:number], :parent=>option[:parent], :domain=>option[:domain], :use_link=>option[:use_link])
        javascript_string << temp[0]
        option[:number] = temp[1]
      }
    end
    return javascript_string, option[:number]
  end
end
