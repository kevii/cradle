class PropertyController < ApplicationController
  before_filter :authorize
  before_filter :authorize_admin
  before_filter :set_title

  def lexeme_property_index
    @lexeme_cat_property = [ ["pos", initial_property_name(params[:domain])["pos"], initial_property_desc(params[:domain])["pos"]], 
                             ["dictionary", initial_property_name(params[:domain])["dictionary"], initial_property_desc(params[:domain])["dictionary"]],
                             ["tagging_state", initial_property_name(params[:domain])["tagging_state"], initial_property_desc(params[:domain])["tagging_state"]] ]
    @lexeme_text_property = [["log", initial_property_name(params[:domain])["log"], initial_property_desc(params[:domain])["log"]]]
    @lexeme_time_property = [["updated_at", initial_property_name(params[:domain])["updated_at"], initial_property_desc(params[:domain])["updated_at"]]]
    case params[:domain]
      when 'jp'
        @lexeme_cat_property.concat([["ctype", initial_property_name('jp')["ctype"], initial_property_desc('jp')["ctype"]],
                                     ["cform", initial_property_name('jp')["cform"], initial_property_desc('jp')["cform"]]])
      when 'cn'  ## nothing for cn
      when 'en'
    end
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('lexeme', 'category').each{|item| @lexeme_cat_property << [item.property_string, item.human_name, item.description]}
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('lexeme', 'text').each{|item| @lexeme_text_property << [item.property_string, item.human_name, item.description]}
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('lexeme', 'time').each{|item| @lexeme_time_property << [item.property_string, item.human_name, item.description]}
    @lexeme_other_property = []
    @section = "lexeme"
  end

  def synthetic_property_index
    @synthetic_cat_property = [["sth_tagging_state", initial_property_name(params[:domain])["sth_tagging_state"], initial_property_desc(params[:domain])["sth_tagging_state"]]]
    @synthetic_text_property = [["sth_log", initial_property_name(params[:domain])["log"], initial_property_desc(params[:domain])["log"]]]
    @synthetic_time_property = [["updated_at", initial_property_name(params[:domain])["updated_at"], initial_property_desc(params[:domain])["updated_at"]]]
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('synthetic', 'category').each{|item| @synthetic_cat_property << [item.property_string, item.human_name, item.description]}
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('synthetic', 'text').each{|item| @synthetic_text_property << [item.property_string, item.human_name, item.description]}
    verify_domain(params[:domain])['NewProperty'].constantize.find_by_section_and_type('synthetic', 'time').each{|item| @synthetic_time_property << [item.property_string, item.human_name, item.description]}
    @section = "synthetic"
  end

  def modify_property
    @section = params[:section]
    @type_field = params[:type_field]
    if params[:id].blank?
      render :partial => 'modify_property'
    else
      if @type_field == "time"
        temp =  verify_domain(params[:domain])['NewProperty'].constantize.find(params[:id].to_i).default_value
        if temp.blank?
          @time = nil
        else
          temp = temp.split(/-|\s|:/)
          @time = DateTime.civil(temp[0].to_i, temp[1].to_i, temp[2].to_i, temp[3].to_i, temp[4].to_i)
        end
      end
      render :partial => 'modify_property', :object=> verify_domain(params[:domain])['NewProperty'].constantize.find(params[:id].to_i)
    end
  end

  def create_or_update_property
    case params[:domain]
      when 'jp'
        success_msg = "<ul><li>属性を保存しました。</li></ul>"
      when 'cn'
        success_msg = "<ul><li>属性已保存。</li></ul>"
      when 'en'
        success_msg = "<ul><li>Property saved.</li></ul>"
    end
    @section = params[:section]
    @type_field = params[:type_field]
    params[:desc].blank? ? desc = nil : desc = params[:desc]
    params[:default_value].blank? ? default_value = nil : default_value = params[:default_value]
    if @type_field == "time"
      message, time_string  = verify_time_property(:domain=>params[:domain], :value=>default_value)
      if message.blank?
        default_value = time_string
      else
        flash.now[:notice_err] = message
        render(:update) { |page| page[:show_property].replace_html :partial=>"modify_property" }
        return
      end
    end
    
    if params[:id].blank?
      begin
        new_property = verify_domain(params[:domain])['NewProperty'].constantize.new( :property_string=>params[:string], :human_name=>params[:human_name],
                                                                                      :description=>desc,                :default_value=>default_value,
                                                                                      :section=>params[:section],        :type_field=>params[:type_field],
                                                                                      :dictionary_id=>params[:dic_dependency])
        new_property.save!                                      
      rescue
        flash.now[:notice_err] = get_validation_error(new_property, "save", params[:domain])
        render(:update) { |page| page[:show_property].replace_html :partial=>"modify_property" }
      else
        flash[:special] = success_msg
        render(:update) { |page| page.call 'location.reload' }
      end
    else
      @property = verify_domain(params[:domain])['NewProperty'].constantize.find(params[:id].to_i)
      begin
        if @type_field == "category"
            default_value = @property.default_value
        end
        @property.update_attributes!(:property_string => params[:string], :human_name=>params[:human_name],
                                     :description=>desc, :default_value=>default_value, :dictionary_id=>params[:dic_dependency])
      rescue
        flash.now[:notice_err] = get_validation_error(@property, 'update', params[:domain])
        render(:update) { |page| page[:show_property].replace_html :partial=>"modify_property", :object=>verify_domain(params[:domain])['NewProperty'].constantize.find(@property.id)}
      else
        flash[:special] = success_msg
        render(:update) { |page| page.call 'location.reload' }
      end
    end
  end

  def delete_property
    temp = verify_domain(params[:domain])['NewProperty'].constantize.find(params[:id].to_i)
    begin
      temp.destroy
    rescue
      flash[:notice_err] = get_validation_error(temp, "save", params[:domain])
    else
      case params[:domain]
        when 'jp'
          flash[:special] = "<ul><li>属性【#{temp.human_name}】を削除しました！</li></ul>"
        when 'cn'
          flash[:special] = "<ul><li>属性【#{temp.human_name}】已删除！</li></ul>"
        when 'en'
          flash[:special] = "<ul><li>Property【#{temp.human_name}】deleted!</li></ul>"
      end
    end
    render(:update) { |page| page.call 'location.reload' }
  end

  def show_category_item
    if initial_property_name(params[:domain])[params[:string]].blank?
      property = verify_domain(params[:domain])['NewProperty'].constantize.find(:first, :conditions =>["property_string = ?", params[:string]])
      @human_name = property.human_name
      @desc = property.description
    else
      @human_name = initial_property_name(params[:domain])[params[:string]]
      @desc = initial_property_desc(params[:domain])[params[:string]]
    end
    @string = params[:string]
    render :partial => 'show_category_item'
  end

  def change_category_seperator
    case params[:domain]
      when 'jp'
        error_msg_1 = "<ul><li>多段階の項目があるので、区切り符号は空に変更できません！</li></ul>"
        error_msg_2 = "<ul><li>問題が発生しました、区切り符号を変更できません！</li></ul>"
        success_msg = "<ul><li>区切り符号を変更しました。</li></ul>"
      when 'cn'
        error_msg_1 = "<ul><li>由于存在多层次的属性，故分隔符号不能设置为空！</li></ul>"
        error_msg_2 = "<ul><li>发生了内部问题，分隔符号不能更新！</li></ul>"
        success_msg = "<ul><li>分隔符号已更新。</li></ul>"
      when 'en'
        error_msg_1 = "<ul><li>Because multiple level property exists, you can not change seperator to null!</li></ul>"
        error_msg_2 = "<ul><li>Internal problem occurred, you can not change seperator!</li></ul>"
        success_msg = "<ul><li>Seperator successfully changed!</li></ul>"
    end
    @human_name = params[:human_name]
    @desc = params[:desc]
    @string = params[:string]
    params[:seperator].blank? ? seperator = nil : seperator = params[:seperator]
    if seperator==nil and verify_domain(params[:domain])['Property'].constantize.exists?(["property_string = '#{params[:string]}' and parent_id is not null "])
      flash.now[:notice_err] = error_msg_1
    else
      begin
        verify_domain(params[:domain])['Property'].constantize.transaction do
          if seperator == nil
            verify_domain(params[:domain])['Property'].constantize.update_all("seperator = NULL", "property_string = '#{params[:string]}'")
          else
            verify_domain(params[:domain])['Property'].constantize.update_all("seperator = '#{seperator}'", "property_string = '#{params[:string]}'")
          end
        end
      rescue
        flash.now[:notice_err] = error_msg_2
      else
        flash.now[:notice] = success_msg
      end
    end
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
  end

  def change_category_default
    case params[:domain]
      when 'jp'
        error_msg = "<ul><li>問題が発生しました、デフォルト値を変更できません！</li></ul>"
        success_msg = "<ul><li>デフォルト値を変更しました。</li></ul>"
      when 'cn'
        error_msg = "<ul><li>发生了内部问题，默认值不能更新！</li></ul>"
        success_msg = "<ul><li>默认值已更新。</li></ul>"
      when 'en'
        error_msg = "<ul><li>Internal problem occurred, you can not change default value!</li></ul>"
        success_msg = "<ul><li>Default value successfully changed!</li></ul>"
    end
    @human_name = params[:human_name]
    @desc = params[:desc]
    @string = params[:string]
    begin
      temp = verify_domain(params[:domain])['NewProperty'].constantize.find(:first, :conditions=>["property_string=?", @string])
      params[:id].blank? ? default_value=nil : default_value=params[:id]
      temp.update_attributes!(:default_value=>default_value)
    rescue
      flash.now[:notice_err] = error_msg
    else
      flash.now[:notice] = success_msg
    end
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
  end

  def modify_category_item
    if params[:id].blank?
      @property_id = 0
    else
      @property_id = params[:id].to_i
      temp = verify_domain(params[:domain])['Property'].constantize.find(@property_id)
      @property_item = temp.tree_string.split(temp.seperator)
    end
    temp = verify_domain(params[:domain])['Property'].constantize.find(:first, :conditions=>["property_string=?",params[:string]])
    temp.blank? ? @seperator=nil : @seperator=temp.seperator
    @string = params[:string]
    @human_name = params[:human_name]
    @desc = params[:desc]
    render :partial => "modify_category_item"
  end
  
  def save_category_item
    case params[:domain]
      when 'jp'
        error_msg_1 = "<ul><li>左上詰めで入力してください！</li></ul>"
        error_msg_2 = "<ul><li>項目すでに登録されています！</li></ul>"
        success_save_msg = "<ul><li>新規Itemを保存しました。</li></ul>"
        success_update_msg = "<ul><li>Itemを保存しました。</li></ul>"
      when 'cn'
        error_msg_1 = "<ul><li>靠左输入各段内容，各段间不能有空段！</li></ul>"
        error_msg_2 = "<ul><li>这个属性已经登录！</li></ul>"
        success_save_msg = "<ul><li>新建属性已保存。</li></ul>"
        success_update_msg = "<ul><li>属性已更新。</li></ul>"
      when 'en'
        error_msg_1 = "<ul><li>Please fill in the field from left and do not leave blank field in between!</li></ul>"
        error_msg_2 = "<ul><li>This property exists!</li></ul>"
        success_save_msg = "<ul><li>Property successfully created.</li></ul>"
        success_update_msg = "<ul><li>Property successfully updated.</li></ul>"
    end
    item = nil
    if params[:id] == "0"
      property_item = get_ordered_string_from_params(params[params[:string]])
      change_to_valid_property = nil
      if property_item.blank?
        flash.now[:notice_err] = error_msg_1
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      else
        change_to_valid_property = verify_domain(params[:domain])['Property'].constantize.find_item_by_tree_string_or_array(params[:string], property_item, 'validation')
        if not change_to_valid_property.blank? and change_to_valid_property.property_cat_id > 0
          flash.now[:notice_err] = error_msg_2
          render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
          return
        end
      end
      begin
        if change_to_valid_property.blank?
          item = verify_domain(params[:domain])['Property'].constantize.save_property_tree(params[:string], property_item, params[:seperator])
        else
          item = change_to_valid_property.update_attributes!(:property_cat_id=>verify_domain(params[:domain])['Property'].constantize.maximum("property_cat_id", :conditions=>["property_string=?", params[:string]])+1)
        end
      rescue
        flash.now[:notice_err] = get_validation_error(item, "save", params[:domain])
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = success_save_msg
      end
    else
      begin
        item = verify_domain(params[:domain])['Property'].constantize.find(params[:id].to_i)
        item.update_attributes!(:value=>params[params[:string]].values[0])
      rescue
        flash.now[:notice_err] = get_validation_error(item, "save", params[:domain])
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = success_update_msg
      end
    end
    @desc = params[:desc]
    @string = params[:string]
    @human_name = params[:human_name]
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item", :object=>item.id}
  end
  
  def delete_category_item
    temp = verify_domain(params[:domain])['Property'].constantize.find(params[:id].to_i)
    exist = false
    if params[:section] == "lexeme"
      case params[:domain]
      when 'jp'	then special_array = ["pos", "ctype", "cform", "tagging_state"]
      when 'cn' then special_array = ["pos", "tagging_state"]
      when 'en'
      end
      if special_array.include?(temp.property_string)
        exist = true if verify_domain(params[:domain])['Lexeme'].constantize.exists?( temp.property_string => temp.property_cat_id )
      elsif temp.property_string == "dictionary"
        exist = true if verify_domain(params[:domain])['Lexeme'].constantize.exists?([%Q|dictionary like "%-#{temp.property_cat_id.to_s}-%"|])
      else
        exist = true if verify_domain(params[:domain])['LexemeNewPropertyItem'].constantize.exists?(["property_id = ? and category = ?", temp.definition.id, temp.property_cat_id])
      end
    elsif params[:section] == "synthetic"
      case temp.property_string
        when "sth_tagging_state"
          exist = true if verify_domain(params[:domain])['Synthetic'].exists?( temp.property_string => temp.property_cat_id )
        else
          exist = true if verify_domain(params[:domain])['SyntheticNewPropertyItem'].constantize.exists?(["property_id = ? and category = ?", temp.definition.id, temp.property_cat_id])
      end
    end
    @human_name = params[:human_name]
    @string = params[:string]
    @desc = params[:desc]
    
    if exist == true
      case params[:domain]
        when 'jp'
          flash.now[:notice_err] = "<ul><li>#{@human_name}は【#{temp.tree_string}】の単語はまだあるので、【#{temp.tree_string}】を削除できません！</li></ul>"
        when 'cn'
          flash.now[:notice_err] = "<ul><li>#{@human_name}是【#{temp.tree_string}】的单词仍然存在，故【#{temp.tree_string}】不能删除！</li></ul>"
        when 'en'
          flash.now[:notice_err] = "<ul><li>There still exists lexemes whose #{@human_name} is 【#{temp.tree_string}】, 【#{temp.tree_string}】can not be deleted!</li></ul>"
      end
      render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      return
    elsif not temp.children.blank?
      case params[:domain]
        when 'jp'
          flash.now[:notice_err] = "<ul><li>【#{temp.tree_string}】に属している項目はまだあるので、【#{temp.tree_string}】を削除できません！</li></ul>"
        when 'cn'
          flash.now[:notice_err] = "<ul><li>从属于【#{temp.tree_string}】的属性仍然存在，【#{temp.tree_string}】不能被删除！</li></ul>"
        when 'en'
          flash.now[:notice_err] = "<ul><li>There still exists properties that depend on【#{temp.tree_string}】, 【#{temp.tree_string}】can not be deleted!</li></ul>"
      end
      render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      return
    else
      begin
        default_item = verify_domain(params[:domain])['NewProperty'].constantize.find(:first, :conditions=>["property_string=?", @string])
        default_item.update_attributes!(:default_value=>nil) if not default_item.blank? and default_item.default_value.to_i == temp.id
        parent = temp.parent
        temp.destroy
        while( not parent.blank? ) do
          if parent.property_cat_id==0 and parent.children.size==0
            temp_parent = parent.parent
            parent.destroy
            parent = temp_parent
          else
            break
          end
        end
      rescue
        case params[:domain]
          when 'jp'
            flash.now[:notice_err] = "<ul><li>問題が発生しました、【#{temp.value}】を削除できません！</li></ul>"
          when 'cn'
            flash.now[:notice_err] = "<ul><li>发生了内部问题，【#{temp.value}】不能被删除！</li></ul>"
          when 'en'
            flash.now[:notice_err] = "<ul><li>Internal problem occurred, 【#{temp.value}】 can not be deleted!</li></ul>"
        end
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      else
        case params[:domain]
          when 'jp'
            flash.now[:notice] = "<ul><li>【#{temp.value}】を削除しました。</li></ul>"
          when 'cn'
            flash.now[:notice] = "<ul><li>【#{temp.value}】已删除。</li></ul>"
          when 'en'
            flash.now[:notice] = "<ul><li>【#{temp.value}】 successfully deleted.</li></ul>"
        end
        render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
      end
    end
  end

  def show_ctype_cform_seeds
    render :partial => 'show_ctype_cform_seeds'
  end
  
  def modify_ctype_cform_seed
    params[:id].blank? ? @seed_id = 0 : @seed_id = params[:id].to_i
    render :partial => "modify_ctype_cform_seed"
  end
  
  def save_ctype_cform_seed
    if params[:id] == "0"
      ctype = get_ordered_string_from_params(params[:ctype])
      cform = get_ordered_string_from_params(params[:cform])
      if ctype.blank? or cform.blank?
        flash.now[:notice_err] = "<ul><li>活用型と活用形は空に指定できません！</li></ul>"
        render(:update){|page| page[:modify_seed].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      end
      ctype = JpProperty.find_item_by_tree_string_or_array("ctype", ctype).property_cat_id
      cform = JpProperty.find_item_by_tree_string_or_array("cform", cform).property_cat_id
      if JpCtypeCformSeed.exists?(["ctype=? and cform=?", ctype, cform])
        flash.now[:notice_err] = "<ul><li>活用型と活用形の組み合わせはすでにあるので、Itemを新規できません！</li></ul>"
        render(:update){|page| page[:modify_seed].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      end
      begin
        new_seed = JpCtypeCformSeed.new(:ctype=>ctype, :cform=>cform, :surface_end=>params[:surface_end][:value],
                                        :reading_end=>params[:reading_end][:value], :pronunciation_end=>params[:pronunciation_end][:value])
        new_seed.save!
      rescue
        flash.now[:notice_err] = get_validation_error(new_seed, "save", 'jp')
        render(:update){|page| page[:modify_seed].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = "<ul><li>新規Itemを保存しました。</li></ul>"
        render(:update){|page| page[:show_property].replace_html :partial=>"show_ctype_cform_seeds", :object=>new_seed.id}
      end
    else
      begin
        seed = JpCtypeCformSeed.find(params[:id].to_i)
        seed.update_attributes!(:surface_end=>params[:surface_end][:value], :reading_end=>params[:reading_end][:value], :pronunciation_end=>params[:pronunciation_end][:value])
      rescue
        flash.now[:notice_err] = get_validation_error(seed, "edit", 'jp')
        render(:update){|page| page[:modify_seed].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = "<ul><li>編集したItemを保存しました。</li></ul>"
        render(:update){|page| page[:show_property].replace_html :partial=>"show_ctype_cform_seeds", :object=>seed.id}
      end
    end
  end

  def delete_ctype_cform_seed
    begin
      temp = JpCtypeCformSeed.find(params[:id].to_i)
      temp.destroy
    rescue
      flash.now[:notice_err] = "<ul><li>問題が発生しました、Itemを削除できません！</li></ul>"
      render(:update){|page| page[:modify_seed].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
    else
      flash.now[:notice] = "<ul><li>Itemを削除しました。</li></ul>"
      render(:update){|page| page[:show_property].replace_html :partial=>"show_ctype_cform_seeds"}
    end
  end

  private
  def set_title
    case params[:domain]
      when 'jp'
        @page_title = "Cradle--茶筌辞書管理システム"
      when 'cn'
        @page_title = "Cradle--ChaSen辞典管理系统"
      when 'en'
        @page_title = "Cradle--ChaSen Dictionary Management System"
    end
  end
  
  def get_validation_error(holder, state, domain)
    if holder.errors.blank?
      if state == 'delete'
        case domain
          when 'jp'
            return "<ul><li>問題が発生しました、削除できません！</li></ul>"
          when 'cn'
            return "<ul><li>发生内部问题，不能删除！</li></ul>"
          when 'en'
            return "<ul><li>Internal problem occurred，can not delete!</li></ul>"
        end
      else
        case domain
          when 'jp'
            return "<ul><li>問題が発生しました、保存できません！</li></ul>"
          when 'cn'
            return "<ul><li>发生内部问题，不能保存！</li></ul>"
          when 'en'
            return "<ul><li>Internal problem occurred，can not save!</li></ul>"
        end
        
      end
    else
      err_arr = []
      holder.errors.each{|err| 
        err_arr << err[1] unless err_arr.include?(err[1])
      }
      return "<ul><li>"+err_arr.join('</li><li>')+"</li></ul>"
    end
  end
end