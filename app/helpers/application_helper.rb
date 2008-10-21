# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def button_to_remote(name, options = {}, html_options = {})
    cradle_button_to_function(name, remote_function(options), html_options)
  end

  def cradle_button_to(name, url, html_options = {})
    cradle_button_to_function(name, "window.location='" + url_for(url) + "';", html_options)
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
      if ['search','new'].include?(state) or (state=='modify' and id.blank?)
        collection = eval(class_name+".find(:all, :conditions=>['property_string = ? and parent_id is null', type], :order=>'property_cat_id ASC')"+".map{|item| item.value}")
        html_string << "<span id='#{span_id}' >\n"
        html_string << "<select id='#{select_id}' name='#{select_name}' onchange=\"#{ajax_string}\" #{option}>\n"
        html_string << "  <option selected value=''></option>\n" unless collection.include?("")
        html_string << options_for_select(collection)
        html_string << "</select>\n"
        html_string << "<span id='#{next_span_id}'></span>\n"
        html_string << "</span>\n"
      elsif state == 'modify'
        roots = []
        parent = eval(class_name+".find(:first, :conditions=>['property_string =? and property_cat_id =?', type, id])")
        while not parent.blank?
          roots << parent
          parent = parent.parent
        end
        html_string << first_html_list_for_mdification(roots.reverse, type, prefix, domain, option)
      end
    else  ##chain display
      if id > 0
        parent = eval(class_name+".find(id)")
        collection = eval("parent.children.map{|item| item.value}")
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
    field[:prefix].blank? ? prefix = "" : prefix = field[:prefix]+"_"
     
    html_string = ""
    section == "lexeme" ? class_name = verify_domain(domain)["Lexeme"] : class_name = verify_domain(domain)["Synthetic"]
    property_class_name = verify_domain(domain)["Property"]
    section == "lexeme" ? item_class_name = verify_domain(domain)["LexemeNewPropertyItem"] : item_class_name = verify_domain(domain)["SyntheticNewPropertyItem"]
    properties = eval(verify_domain(domain)["NewProperty"]+'.find(:all, :conditions=>["section=?", section])')
    
    properties.each_with_index{|item, index|
      next if item.type_field=="category" and not (eval (property_class_name+".exists?(:property_string=>item.property_string)"))
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
          prefix = prefix[0..-2] unless prefix.blank?
          case state
            when "search", "new"
              html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>prefix, :state=>state)
            when "modify"
              html_string << display_property_list(:type=>item.property_string, :domain=>domain, :prefix=>prefix, :state=>state, :id=>(eval class_name+".find(id)."+item.property_string))
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
              html_string << text_field_tag("#{prefix+item.property_string}", nil, :style=>"width:100%;", :class=>'text-field')
            when "modify"
              html_string << text_field_tag("#{prefix+item.property_string}", (eval class_name+'.find(id).'+item.property_string), :style=>"width:100%;", :class=>'text-field')
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
            when "search","new"
              html_string << datetime_select(prefix+item.property_string, "section", :use_month_numbers => true, :include_blank => true)
            when "modify"
              html_string << select_datetime((eval class_name+'.find(id).'+item.property_string), :use_month_numbers => true, :include_blank => true,:prefix=>prefix+item.property_string)
          end
          html_string << "</td>\n"
      end
      html_string << "<td></td>\n" if index % 2 == 0
      html_string << "</tr>\n" if (index % 2 == 1) or (index == properties.size - 1) 
    }
    return html_string
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

  ### :original_lexeme_id, :meta, :level, :domain
  def get_formatted_ids_and_chars(fields={})
    original_lexeme_id = fields[:original_lexeme_id]
    fields[:meta].blank? ? meta=0 : meta=fields[:meta]
    fields[:level].blank? ? level=1 : level = fields[:level]
    lexeme_class = verify_domain(fields[:domain])["Lexeme"]
    synthetic_class = verify_domain(fields[:domain])["Synthetic"]
    ids = []
    chars = []
    temp_struct = eval(synthetic_class+'.find(:first, :conditions=>["sth_ref_id=#{original_lexeme_id} and sth_meta_id=#{meta}"]).sth_struct')
    temp_struct = temp_struct.split(',').map{|item| item.delete('-')}.join(',')
    if temp_struct.include?('meta')
      temp_struct.split(',').each{|item|
        if (item =~ /^meta_(\d*)$/) != nil
          meta = $1
          temp = get_formatted_ids_and_chars(:original_lexeme_id=>original_lexeme_id, :domain=>fields[:domain], :meta=>meta, :level=>level+1)
          ids << temp[0]
          chars << temp[1]
        else
          ids << item
          temp_lexeme = eval(lexeme_class+'.find(item.to_i)')
          if temp_lexeme.struct.blank?
            chars << temp_lexeme.surface.split("").join("-")
          else
            chars << temp_lexeme.surface
          end
        end
      }
    else
      temp_struct.split(',').each{|item|
        ids << item
        temp_lexeme = eval(lexeme_class+'.find(item.to_i)')
        if temp_lexeme.struct.blank?
          chars << temp_lexeme.surface.split("").join("-")
        else
          chars << temp_lexeme.surface
        end
      }
    end
    return ids.join('*'+'+'*level+'*'), chars.join('*'+'+'*level+'*')
  end
    
  def generate_tree_view(fields={})
    root = fields[:root]
    ids = fields[:ids]
    case fields[:domain]
      when "jp"
        title = "ツリー構造"
        error_message = "下の単語の内部構造定義があるので、そちらを使ってツリーを定義してください："
      when "cn"
        title = "内部构造"
        error_message = "下面的单词的内部结构定义已经存在，请使用该结构重新组织构造树："
      when "en"
    end
    id_tree, surface_tree = get_node_id_and_surface(get_id_array(ids), root, fields[:domain])
    node_tree = get_whole_tree(id_tree, surface_tree)
    temp = get_tree_script(node_tree, 0, -1, fields[:domain])
    html_string = "<span style='color:#dfd; background: #1e2078; font-family:sans-serif; padding:0.2em 1em;'>#{title}</span>\n<p>\n"
    unless temp[2].blank?
      html_string << error_message
      html_string << "<ul>#{temp[2]}</ul>"
    end
    html_string << "<script>\n  var myTree = null;\n  function CreateTree() {\n"
    html_string << "    myTree=new ECOTree('myTree','myTreeContainer');\n"
    html_string << "    myTree.config.linkColor = 'black';\n"
    html_string << "    myTree.config.nodeBorderColor = 'black';\n"
    html_string << "    myTree.config.colorStyle = ECOTree.CS_NODE;\n"
    html_string << "    myTree.config.nodeFill = ECOTree.NF_FLAT;\n"
    html_string << "    myTree.config.nodeColor = '#89bfe5';\n"
    html_string << "    myTree.config.nodeSelColor = 'LavenderBlush';\n"
    html_string << temp[0]
    html_string << "    myTree.UpdateTree();\n"
    html_string << "  }\n</script>\n"
    return html_string
  end

  def show_internal_structure(field={}, first_time=false, level=0, domain=nil)
    part = field["part"]
    html_string = ""
    if part.include?("*") == false  # do not include *
      inner_array = part.split("")
      if inner_array.include?("-")
        for index in 0..inner_array.size-1
          if inner_array[index] == "-"
            html_string << "<td style='text-align:center;'>\n"
            left = inner_array[0..index-1]
            left.delete("-")
            right = inner_array[index+1..-1]
            right.delete("-")
            if first_time == true
              html_string << link_to_remote(image_tag("internal.jpg", :border=>0), :update=>"candidates", :url=>{ :action=>"split_word",
                                                                                                                  :level => level,
                                                                                                                  :left=>left.to_s,
                                                                                                                  :right=>right.to_s,
                                                                                                                  :ids=>field["ids"],
                                                                                                                  :chars=>field["chars"],
                                                                                                                  :type=>"new",
                                                                                                                  :divide_type=>"",
                                                                                                                  :original_id=>field["original_id"],
                                                                                                                  :from=>field["from"],
                                                                                                                  :chars_index=>field["start_index"].to_s+","+(field["start_index"]+inner_array.to_s.size-1).to_s,
                                                                                                                  :ids_section=>field["ids_section"],
                                                                                                                  :domain=>domain })
            elsif first_time == false
              html_string << link_to_remote(image_tag("internal-horizontal.jpg", :border=>0), :update=>"candidates", :url=>{  :action=>"split_word",
                                                                                                                              :level => level-1,
                                                                                                                              :left=>left.to_s,
                                                                                                                              :right=>right.to_s,
                                                                                                                              :ids=>field["ids"],
                                                                                                                              :chars=>field["chars"],
                                                                                                                              :type=>"new",
                                                                                                                              :divide_type=>"horizontal",
                                                                                                                              :original_id=>field["original_id"],
                                                                                                                              :from=>field["from"],
                                                                                                                              :chars_index=>field["start_index"].to_s+","+(field["start_index"]+inner_array.to_s.size-1).to_s,
                                                                                                                              :ids_section=>field["ids_section"],
                                                                                                                              :domain=>domain })
              html_string << '<br/>'
              html_string << link_to_remote(image_tag("internal-vertical.jpg", :border=>0), :update=>"candidates", :url=>{  :action=>"split_word",
                                                                                                                            :level => level,
                                                                                                                            :left=>left.to_s,
                                                                                                                            :right=>right.to_s,
                                                                                                                            :ids=>field["ids"],
                                                                                                                            :chars=>field["chars"],
                                                                                                                            :type=>"new",
                                                                                                                            :divide_type=>"vertical",
                                                                                                                            :original_id=>field["original_id"],
                                                                                                                            :from=>field["from"],
                                                                                                                            :chars_index=>field["start_index"].to_s+","+(field["start_index"]+inner_array.to_s.size-1).to_s,
                                                                                                                            :ids_section=>field["ids_section"],
                                                                                                                            :domain=>domain })
            end
            html_string << "</td>\n"
          else
            html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
            html_string << inner_array[index]+"\n"
            html_string << "</td>\n"
          end
        end
      else
        html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
        html_string << part+"\n"
        html_string << "</td>\n"
      end
    else  #include *
      sections = part.split("*#{'+'*level}*")
      transition_index = field["start_index"]
      for index in 0..sections.size-1
        unless index == 0
          html_string << "<td style='text-align:center;vertical-align: middle;'>\n"
          left = sections[index-1].dup.to_s
          left.delete!("-")
          left.delete!("+")
          left.delete!("*")
          right = sections[index].dup.to_s
          right.delete!("-")
          right.delete!("+")
          right.delete!("*")
          html_string << link_to_remote(image_tag("internal-plus.jpg", :border=>0, :style=>"vertical-align: middle;"), :update=>"candidates", :url=>{ :action=>"split_word",
                                                                                                                   :level => level,
                                                                                                                   :left=>left,
                                                                                                                   :right=>right,
                                                                                                                   :ids=>field["ids"],
                                                                                                                   :chars=>field["chars"],
                                                                                                                   :type => "modify",
                                                                                                                   :original_id => field["original_id"],
                                                                                                                   :from=>field["from"],
                                                                                                                   :chars_index=>(transition_index-(2+1*level)-sections[index-1].size).to_s+","+(transition_index+sections[index].size).to_s,
                                                                                                                   :ids_section=>field["ids_section"].blank? ? index.to_s : field["ids_section"]+','+index.to_s,
                                                                                                                   :domain=>domain})
          html_string << struct_level[level]+"\n"
          html_string << link_to_remote(image_tag("internal-minus.jpg", :border=>0, :style=>"vertical-align: middle;"), :url=>{ :action=>"define_internal_structure",
                                                                                             :level => level,
                                                                                             :ids=>field["ids"],
                                                                                             :chars=>field["chars"],
                                                                                             :type => "delete",
                                                                                             :original_id => field["original_id"],
                                                                                             :from=>field["from"],
                                                                                             :chars_index=>(transition_index-(2+1*level)-sections[index-1].size).to_s+","+(transition_index+sections[index].size).to_s,
                                                                                             :ids_section=>field["ids_section"].blank? ? index.to_s : field["ids_section"]+','+index.to_s,
                                                                                             :domain=>domain })
          html_string << "</td>\n"
        end
        html_string << show_internal_structure( {"part"=>sections[index],       "ids"=>field["ids"],
                                                 "chars"=>field["chars"],       "original_id"=>field["original_id"],
                                                 "from"=>field["from"],         "start_index"=>transition_index,
                                                 "ids_section"=>field["ids_section"].blank? ? index.to_s : field["ids_section"]+','+index.to_s},
                                                 false,
                                                 level+1,
                                                 domain)
        transition_index = transition_index+(2+1*level)+sections[index].size
      end
    end
    return html_string
  end

  def get_showing_string(ids="", chars="", step=1)
    string = ""
    if ids == ""
      string = chars.delete("*").delete("+").delete("-")+'()'
    elsif ids.include?("*")
      temp = ids.split('*'+'+'*step+'*')
      for index in 0..temp.size-1
        string << '  [  '+get_showing_string(temp[index], chars.split('*'+'+'*step+'*')[index], step+1)+'  ]  '
      end
    else
      ids=="-" ? id='()' : id='('+ids+')'
      string = chars.delete("-")+id
    end
    return string
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
      collection = eval(class_name+".find(:all, :conditions=>['property_string = ? and parent_id is null', type], :order=>'property_cat_id ASC')"+".map{|item| item.value}")
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
  
  def get_id_array(ids="", level=1)
    id_array = []
    ids.split('*'+'+'*level+'*').each{|item|
      if item.include?('*')
        id_array << get_id_array(item, level+1)
      else
        id_array << item.to_i
      end
    }
    return id_array
  end
  
  def get_node_id_and_surface (id_array=[], root = 0, domain="" )
    class_name = verify_domain(domain)["Lexeme"]
    id_tree = Array.new
    surface_tree = Array.new
    if root != 0
      id_tree << root
      surface_tree << (eval class_name+'.find(root).surface')
    else
      id_tree << '-'
      surface_tree << ""
    end
    for index in 0..id_array.size-1
      begin
        id_array[index].last
      rescue
        lexeme = eval class_name+'.find(id_array[index])'
        if lexeme.struct.blank?
          id_tree << id_array[index]
          surface_tree << (eval class_name+'.find(id_array[index]).surface')
        else
#          sub_array = eval '['+lexeme.struct.sth_struct+']'
          sub_array = eval '['+lexeme.struct.sth_struct.delete('-')+']'
          temp = get_node_id_and_surface(sub_array, id_array[index], domain)
          id_tree << temp[0]
          surface_tree << temp[1]
        end
      else
        temp = get_node_id_and_surface(id_array[index], 0, domain)
        id_tree << temp[0]
        surface_tree << temp[1]
      end
    end
    if surface_tree[0].blank?
      dummy_node_surface = ""
      surface_tree[1..surface_tree.size-1].each{|item|
        begin
          item.chomp
        rescue
          dummy_node_surface << item[0]
        else
          dummy_node_surface << item
        end
      }
      surface_tree[0] = dummy_node_surface
    end
    return id_tree, surface_tree
  end

  def get_whole_tree(id_tree=[], surface_tree=[])
    whole_tree = []
    for index in 0..id_tree.size-1
      begin
        surface_tree[index].chomp
      rescue
        whole_tree << get_whole_tree(id_tree[index], surface_tree[index])
      else
        whole_tree << ["leaf",id_tree[index], surface_tree[index]]
      end
    end
    return whole_tree
  end
  
  def get_tree_script( node_tree = [], number = 0, parent = -1, domain="" )
    lexeme_class = verify_domain(domain)["Lexeme"]
    synthetic_class = verify_domain(domain)["Synthetic"]
    script = String.new
    message = String.new
    for index in 0..node_tree.size-1
      if node_tree[index][0] == "leaf"
        surface = node_tree[index][2]
        length = (surface.length/3)*20+15
        if node_tree[index][1] == '-'
          existing_lexemes = eval(lexeme_class+'.find(:all, :conditions=>["surface=?", surface])')
          unless existing_lexemes.blank?
            existing_lexemes.each{|lexeme| message << '<li>【'+surface+'】</li>' if eval(synthetic_class+'.exists?(:sth_ref_id=>lexeme.id)')}
          end
          script << "    myTree.add(#{number}, #{parent}, '#{surface}', #{length});\n"
          script << "    myTree.setNodeTarget(#{number}, '', false);\n" 
        else
          ajax_string = remote_function(:url=>{:controller=>'jp', :action=>'show_desc', :id=>node_tree[index][1]}, :with=>"'state='+Element.visible('show_desc')")
          script << "    myTree.add(#{number}, #{parent}, '#{surface}', #{length}, '', '', '', \"#{ajax_string}\");\n"
        end
        parent = number if index == 0
        number = number + 1
      else
        temp = get_tree_script(node_tree[index], number, parent, domain)
        sub_script = temp[0]
        number = temp[1]
        message << temp[2]
        script << sub_script
      end
    end
    return script, number, message
  end
end
