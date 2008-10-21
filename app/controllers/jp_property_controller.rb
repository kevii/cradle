class JpPropertyController < ApplicationController
  layout 'cradle'
  include JpHelper
  before_filter :authorize
  before_filter :authorize_admin
  before_filter :set_title
  
  def lexeme_property_index
    ## category property
    @lexeme_cat_property = [ ["pos", initial_property_name["pos"], initial_property_desc["pos"]], 
                             ["ctype", initial_property_name["ctype"], initial_property_desc["ctype"]],
                             ["cform", initial_property_name["cform"], initial_property_desc["cform"]],
                             ["dictionary", initial_property_name["dictionary"], initial_property_desc["dictionary"]],
                             ["tagging_state", initial_property_name["tagging_state"], initial_property_desc["tagging_state"]] ]
    JpNewProperty.find_by_section_and_type('lexeme', 'category').each{|item|
      @lexeme_cat_property << [item.property_string, item.human_name, item.description]
    }
    ## text property    
    @lexeme_text_property = [["log", initial_property_name["log"], initial_property_desc["log"]]]
    JpNewProperty.find_by_section_and_type('lexeme', 'text').each{|item|
      @lexeme_text_property << [item.property_string, item.human_name, item.description]
    }
    ## time property    
    @lexeme_time_property = [ ["updated_at", initial_property_name["updated_at"], initial_property_desc["updated_at"]] ]
    JpNewProperty.find_by_section_and_type('lexeme', 'time').each{|item|
      @lexeme_time_property << [item.property_string, item.human_name, item.description]
    }
    ## other property
    @lexeme_other_property = []
    @section = "lexeme"
  end

  def synthetic_property_index
    ## category property
    @synthetic_cat_property = [["sth_tagging_state", initial_property_name["sth_tagging_state"], initial_property_desc["sth_tagging_state"]]]
    JpNewProperty.find_by_section_and_type('synthetic', 'category').each{|item|
      @synthetic_cat_property << [item.property_string, item.human_name, item.description]
    }
    
    ## text property    
    @synthetic_text_property = [["sth_log", initial_property_name["log"], initial_property_desc["log"]]]
    JpNewProperty.find_by_section_and_type('synthetic', 'text').each{|item|
      @synthetic_text_property << [item.property_string, item.human_name, item.description]
    }
    
    ## time property    
    @synthetic_time_property = [ ["updated_at", initial_property_name["updated_at"], initial_property_desc["updated_at"]] ]
    JpNewProperty.find_by_section_and_type('synthetic', 'time').each{|item|
      @synthetic_time_property << [item.property_string, item.human_name, item.description]
    }
    @section = "synthetic"
  end

  def modify_property
    @section = params[:section]
    @type_field = params[:type_field]
    if params[:id].blank?
      render :partial => 'modify_property'
    else
      render :partial => 'modify_property', :object=>JpNewProperty.find(params[:id].to_i)
    end
  end

  def create_or_update_property
    @section = params[:section]
    @type_field = params[:type_field]
    params[:desc].blank? ? desc = nil : desc = params[:desc]
    params[:default_value].blank? ? default_value = nil : default_value = params[:default_value]
    if params[:id].blank?
      begin
        new_property = JpNewProperty.new( :property_string=>params[:string], :human_name=>params[:human_name],
                                          :description=>desc,                :default_value=>default_value,
                                          :section=>params[:section],        :type_field=>params[:type_field] )
        new_property.save!                                      
      rescue
        flash.now[:notice_err] = get_validation_error(new_property, "save")
        render(:update) { |page| page[:show_property].replace_html :partial=>"modify_property" }
      else
        flash[:special] = "<ul><li>属性を保存しました。</li></ul>"
        render(:update) { |page| page.call 'location.reload' }
      end
    else
      @property = JpNewProperty.find(params[:id].to_i)
      begin
        default_value = @property.default_value if @type_field == "category"
        @property.update_attributes!(:property_string => params[:string], :human_name=>params[:human_name],
                                     :description=>desc, :default_value=>default_value)
      rescue
        flash.now[:notice_err] = get_validation_error(@property, 'update')
        render(:update) { |page| page[:show_property].replace_html :partial=>"modify_property", :object=>JpNewProperty.find(@property.id)}
      else
        flash[:special] = "<ul><li>属性を更新しました。</li></ul>"
        render(:update) { |page| page.call 'location.reload' }
      end
    end
  end

  def delete_property
    temp = JpNewProperty.find(params[:id].to_i)
    begin
      temp.destroy
    rescue
      flash[:notice_err] = get_validation_error(temp, "save")
    else
      flash[:special] = "<ul><li>属性【#{temp.human_name}】を削除しました！</li></ul>"
    end
    render(:update) { |page| page.call 'location.reload' }
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
        flash.now[:notice_err] = get_validation_error(new_seed, "save")
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
        flash.now[:notice_err] = get_validation_error(seed, "edit")
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

  def show_category_item
    if initial_property_name[params[:string]].blank?
      property = JpNewProperty.find(:first, :conditions =>["property_string = ?", params[:string]])
      @human_name = property.human_name
      @desc = property.description
    else
      @human_name = initial_property_name[params[:string]]
      @desc = initial_property_desc[params[:string]]
    end
    @string = params[:string]
    render :partial => 'show_category_item'
  end

  def change_category_seperator
    @human_name = params[:human_name]
    @desc = params[:desc]
    @string = params[:string]
    params[:seperator].blank? ? seperator = nil : seperator = params[:seperator]
    if seperator==nil and JpProperty.exists?(["property_string = '#{params[:string]}' and parent_id is not null "])
      flash.now[:notice_err] = "<ul><li>多重Levelの項目があるので、区切り符号は空に変更できません！</li></ul>"
    else
      begin
        JpProperty.transaction do
          if seperator == nil
            JpProperty.update_all("seperator = NULL", "property_string = '#{params[:string]}'")
          else
            JpProperty.update_all("seperator = '#{seperator}'", "property_string = '#{params[:string]}'")
          end
        end
      rescue
        flash.now[:notice_err] = "<ul><li>問題が発生しました、区切り符号を変更できません！</li></ul>"
      else
        flash.now[:notice] = "<ul><li>区切り符号を変更しました。</li></ul>"
      end
    end
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
  end

  def change_category_default
    @human_name = params[:human_name]
    @desc = params[:desc]
    @string = params[:string]
    begin
      temp = JpNewProperty.find(:first, :conditions=>["property_string=?", @string])
      temp.update_attributes!(:default_value=>params[:id])
    rescue
      flash.now[:notice_err] = "<ul><li>問題が発生しました、デフォルト値を変更できません！</li></ul>"
    else
      flash.now[:notice] = "<ul><li>デフォルト値を変更しました。</li></ul>"
    end
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
  end

  def modify_category_item
    if params[:id].blank?
      @property_id = 0
    else
      @property_id = params[:id].to_i
      temp = JpProperty.find(@property_id)
      @property_item = temp.tree_string.split(temp.seperator)
    end
    temp = JpProperty.find(:first, :conditions=>["property_string=?",params[:string]])
    temp.blank? ? @seperator=nil : @seperator=temp.seperator
    @string = params[:string]
    @human_name = params[:human_name]
    @desc = params[:desc]
    render :partial => "modify_category_item"
  end
  
  def save_category_item
    item = nil
    if params[:id] == "0"
      property_item = get_ordered_string_from_params(params[params[:string]])
      if property_item.blank?
        flash.now[:notice_err] = "<ul><li>左上詰めで入力してください！</li></ul>"
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      elsif not JpProperty.find_item_by_tree_string_or_array(params[:string], property_item, 'validation').blank?
        flash.now[:notice_err] = "<ul><li>項目すでに登録されています！</li></ul>"
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      end
      begin
        item = JpProperty.save_property_tree(params[:string], property_item, params[:seperator])
      rescue
        flash.now[:notice_err] = get_validation_error(item, "save")
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = "<ul><li>新規Itemを保存しました。</li></ul>"
      end
    else
      begin
        item = JpProperty.find(params[:id].to_i)
        item.update_attributes!(:value=>params[params[:string]].values[0])
      rescue
        flash.now[:notice_err] = get_validation_error(item, "save")
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      else
        flash.now[:notice] = "<ul><li>Itemを保存しました。</li></ul>"
      end
    end
    @desc = params[:desc]
    @string = params[:string]
    @human_name = params[:human_name]
    render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item", :object=>item.id}
  end
  
  def delete_category_item
    temp = JpProperty.find(params[:id].to_i)
    exist = false
    if params[:section] == "lexeme"
      case temp.property_string
        when "pos", "ctype", "cform", "tagging_state"
          exist = true if JpLexeme.exists?( temp.property_string => temp.property_cat_id )
        when "dictionary"
          exist = true if JpLexeme.verify_dictionary(temp.property_cat_id.to_s)
        else
          exist = true if JpLexemeNewPropertyItem.exists?(["property_id = ? and category = ?", temp.definition.id, temp.property_cat_id])
      end
    elsif params[:section] == "synthetic"
      case temp.property_string
        when "sth_tagging_state"
          exist = true if JpSynthetic.exists?( temp.property_string => temp.property_cat_id )
        else
          exist = true if JpSyntheticNewPropertyItem.exists?(["property_id = ? and category = ?", temp.definition.id, temp.property_cat_id])
      end
    end
    @human_name = params[:human_name]
    @string = params[:string]
    @desc = params[:desc]
    if exist == true
      flash.now[:notice_err] = "<ul><li>#{@human_name}は【#{temp.tree_string}】の単語はまだあるので、【#{temp.tree_string}】を削除できません！</li></ul>"
      render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      return
    elsif not temp.children.blank?
      flash.now[:notice_err] = "<ul><li>【#{temp.tree_string}】に属している項目はまだあるので、【#{temp.tree_string}】を削除できません！</li></ul>"
      render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
      return
    else
      begin
        default_item = JpNewProperty.find(:first, :conditions=>["property_string=?", @string])
        default_item.update_attributes!(:default_value=>nil) if not default_item.blank? and default_item.default_value.to_i == temp.id
        temp.destroy
      rescue
        flash.now[:notice_err] = "<ul><li>問題が発生しました、【#{temp.value}】を削除できません！</li></ul>"
        render(:update){|page| page[:modify_category_item].replace_html :inline=>"<div id='notice_err' ><%= flash.now[:notice_err] %></div>"}
        return
      else
        flash.now[:notice] = "<ul><li>【#{temp.value}】を削除しました。</li></ul>"
        render(:update){|page| page[:show_property].replace_html :partial=>"show_category_item"}
      end
    end
  end
  
  private
  def set_title
    @page_title = "Cradle--茶筌辞書管理システム"
  end
  
  def get_validation_error(holder, state)
    if holder.errors.blank?
      if state == 'delete'
        return "<ul><li>問題が発生しました、削除できません！</li></ul>"
      else
        return "<ul><li>問題が発生しました、保存できません！</li></ul>"
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