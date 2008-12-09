module TreeviewHelper
  include CradleModule
  
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