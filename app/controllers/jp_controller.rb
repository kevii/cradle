require 'date'

class JpController < ApplicationController
  layout 'cradle'
  include JpHelper
  before_filter :set_title
  
  def index
    if session[:jp_section_list].blank?
      session[:jp_section_list] = ['1_surface', '2_reading', '3_pronunciation', '4_base_id', '5_root_id', '6_dictionary', '7_pos', '8_ctype', '9_cform']
    end
  end
  
  def search
    if params[:search_type].blank?
      search_conditions, show_conditions, notice = verification( params )
      unless notice == ""
        flash[:notice_err] = notice
        redirect_to :action => 'index'
        return
      end
      static_condition = search_conditions[0].join(" and ")
      dynamic_lexeme_condition = search_conditions[1].join(" and ")
      dynamic_synthetic_condition = search_conditions[2].join(" and ")
    elsif params[:search_type] == "base"
      show_conditions = "Base="+JpLexeme.find(params[:base_id].to_i).surface
      static_condition = " jp_lexemes.base_id = #{params[:base_id]} "
      dynamic_lexeme_condition = ""
      dynamic_synthetic_condition = ""
      flash[:notice] = flash[:notice]
    elsif params[:search_type] == "root"
      if (params[:root_id] =~ /^R/) != nil
        show_conditions = "Same Root"
      else
        show_conditions = "Root="+JpLexeme.find(params[:root_id].to_i).surface
      end
      static_condition = " jp_lexemes.root_id = '#{params[:root_id]}' "
      dynamic_lexeme_condition = ""
      dynamic_synthetic_condition = ""
      flash[:notice] = flash[:notice]
    end
    redirect_to :action => "list", :static_condition=>static_condition,
                                   :dynamic_lexeme_condition=>dynamic_lexeme_condition,
                                   :dynamic_synthetic_condition=>dynamic_synthetic_condition,
                                   :show_conditions => show_conditions
  end
  
  def list
    params[:page].blank? ? page = nil : page = params[:page].to_i
    params[:per_page].blank? ? per_page = 10 : per_page = params[:per_page].to_i
    if params[:dynamic_lexeme_condition].blank? and params[:dynamic_synthetic_condition].blank?
      @jplexemes = JpLexeme.paginate( :select=>" jp_lexemes.* ",   :conditions => params[:static_condition],
                                      :include => [:struct],       :order => " jp_lexemes.id ASC ",
                                      :per_page => per_page,       :page => page )
    else
      dynamic_lexeme_ids = []
      dynamic_synthetic_refs = []
      dynamic_ids = []
      collection = []
      unless params[:dynamic_lexeme_condition].blank?
        dynamic_lexeme_ids = get_lexeme_ids_from_new_property_items(:conditions=>params[:dynamic_lexeme_condition], :domain=>'jp', :section=>'lexeme')
      end
      unless params[:dynamic_synthetic_condition].blank?
        dynamic_synthetic_refs = get_lexeme_ids_from_new_property_items(:conditions=>params[:dynamic_synthetic_condition], :domain=>'jp', :section=>'synthetic')
      end
      if params[:dynamic_synthetic_condition].blank?
        dynamic_ids = dynamic_lexeme_ids
      elsif params[:dynamic_lexeme_condition].blank?
        dynamic_ids = dynamic_synthetic_refs
      else
        dynamic_ids = dynamic_lexeme_ids & dynamic_synthetic_refs
      end
      if params[:static_condition].blank?
        collection = install_by_dividing(:ids=>dynamic_ids, :domain=>'jp')
      else
        static_ids = JpLexeme.find(:all, :select=>"jp_lexemes.id", :include=>[:struct], :conditions=>params[:static_condition], :order => " jp_lexemes.id ASC ").map{|item| item.id}
        final_ids = static_ids & dynamic_ids
        collection = JpLexeme.find(:all, :conditions=>["id in (#{final_ids.join(',')})"])
      end
      @jplexemes = collection.paginate(:page=>page, :per_page=>per_page)
    end
    if @jplexemes.total_entries == 0
      flash[:notice] = '<ul><li>単語は見つかりませんでした！</li></ul>'
      redirect_to :action => 'index'
      return
    end
    @pass=params
    @list = session[:jp_section_list]
  end

  def load_section_list
    if params[:state] == "false"
      render(:update){|page|
        page[:field_list].replace_html :partial=>"field_list", :object=>session[:jp_section_list]
        page[:field_list].visual_effect :slide_down
      }
    end
  end

  def change_section_list
    section_list = []
    params.each{|key, value|
      case key
        when "commit", "authenticity_token", "controller", "action"
          next
        else
          section_list << key if value == "true"
      end
    }
    session[:jp_section_list] = section_list.sort{|a,b| a.split('_')[0].to_i<=>b.split('_')[0].to_i}
    render(:update) { |page| page.call 'location.reload' }
  end

  def show
    @lexeme = JpLexeme.find(params[:id].to_i)
    unless @lexeme.struct.blank?
      @ids, @chars = get_formatted_ids_and_chars(:original_lexeme_id=>@lexeme.id, :domain=>'jp')
      @meta_show_chars = get_meta_structures(:ids=>@ids, :chars=>@chars)[1]
      indexes = @meta_show_chars.size - 1
      while(indexes >= 0) do
        if @meta_show_chars['meta_'+indexes.to_s].include?('meta')
          temp = []
          @meta_show_chars['meta_'+indexes.to_s].split(',').each{|item| item.include?('meta') ? temp << @meta_show_chars[item].delete(',') : temp << item}
          @meta_show_chars['meta_'+indexes.to_s] = temp.join(',')
        end
        indexes = indexes - 1
      end
    end
  end

  def input_base
    unless params[:base_type].blank?
      render :partial => 'input_base', :locals => { :message => "", :base_type => params[:base_type] }
      return
    end
    unless params[:base_as_id].blank?
      begin
        if (params[:base_as_id] =~ /^\d*$/) != nil
          message = "ok_id" if not JpLexeme.find(params[:base_as_id].to_i).blank?
        else
          message = "fail_id"
        end
      rescue ActiveRecord::RecordNotFound
        message = "fail_id"
      end
      render :partial => 'input_base', :locals => { :message => message, :base_id => params[:base_as_id] }
      return
    end
    unless params[:base_as_surface].blank?
      base_candidates = JpLexeme.find(:all, :conditions => ["surface = ?", params[:base_as_surface]])
      if base_candidates.size == 1
        message = "ok_surface"
        render :partial => 'input_base', :locals => { :message => message, :base_id => base_candidates[0].id }
        return
      elsif base_candidates.size == 0
        message = "fail_surface"
        render :partial => 'input_base', :locals => { :message => message }
        return
      else
        message = "list_surface"
        base_list = []
        base_candidates.each{|base|
          temp = []
          temp << "品詞："+base.pos_item.tree_string unless base.pos.blank?
          temp << "活用型："+base.ctype_item.tree_string unless base.ctype.blank?
          temp << "活用形："+base.cform_item.tree_string unless base.cform.blank?
          base_list << [temp.join("， "), base.id]
        }
        render :partial => 'input_base', :locals => { :message => message }, :object=>base_list
        return
      end
    end
  end

  def new
    if request.post?
      if params[:surface].blank? or params[:reading].blank? or params[:pronunciation].blank?
        flash.now[:notice_err] = "<ul><li>単語、読み、発音は新規に必要なので、全部入力してください</li><ul>"
        render :partial=>"preview_news"
        return
      end
      
      #############################################################################
      #tidy up the input properties
      params.delete("commit")
      params.delete("authenticity_token")
      params.delete("action")
      params.delete("controller")
      lexeme = {}
      params.each{|key,value|
        case key
          when "surface", "reading", "pronunciation", "log"
            value.blank? ? lexeme[key]=nil : lexeme[key]=value
          when "pos", "ctype", "cform"
            section_strings = get_ordered_string_from_params(value.dup)
            temp = JpProperty.find_item_by_tree_string_or_array(key, section_strings)
            temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
          when "dictionary"
            lexeme[key]=value.join(',')
          when  "base_type", "base", "base_ok", "base_id"
          else
            case JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"]).type_field
              when "category"
                section_strings = get_ordered_string_from_params(value.dup)
                temp = JpProperty.find_item_by_tree_string_or_array(key, section_strings)
                temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
              when "text"
                value.blank? ? lexeme[key]=nil : lexeme[key]=value
              when "time"
                if value.values.join("").blank?
                  lexeme[key]=nil
                elsif value["section(1i)"]=="" or value["section(2i)"]=="" or value["section(3i)"]==""
                  flash.now[:notice_err] = "<ul><li>時間を最低日まで指定して下さい！</li></ul>"
                  render :partial=>"preview_news"
                  return
                else
                  begin
                    lexeme[key]=DateTime.civil(value["section(1i)"].to_i, value["section(2i)"].to_i, value["section(3i)"].to_i, value["section(4i)"].to_i, value["section(5i)"].to_i).to_formatted_s(:db)
                  rescue
                    flash.now[:notice_err] = "<ul><li>時間を正しく指定して下さい！</li></ul>"
                    render :partial=>"preview_edit"
                    return
                  end
                end
            end
        end
      }
      #############################################################################
      
      #############################################################################
      #see if this word has already been registered
      if JpLexeme.exist_when_new(lexeme)[0] == true
        flash.now[:notice_err] = "<ul><li>単語　#{lexeme['surface']}　はすでに辞書に保存している</li></ul>"
        render :partial=>"preview_news"
        return
      end
      #############################################################################
      
      #############################################################################
      # specify the boot_id field according to cform seeds
      if not params[:base_ok].blank? and params[:base_ok]=="true"
        lexeme["base_id"]= params[:base_id]
        @lexemes = []
        @lexemes << lexeme
        point_base = "true"
        base_type="2"
      else
        @lexemes, @type = JpLexeme.findWordsInSeries(lexeme)
        # @type -3 means that it can not find a match in the list against input's pronunciation
        # @type -2 means that it can not find a match in the list against input's reading
        # @type -1 means that can not find a match in the list against input's surface
        # @type 1 means that there is only one lexeme in the returned array and it's base is itself 
        # @type 2 means that there are several lexemes in the returned array and their base is the word whose cform_id is 1           
        case @type
          when -1
            flash.now[:notice_err] = "<ul><li>単語の入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"
          when -2
            flash.now[:notice_err] = "<ul><li>読みの入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"
          when -3
            flash.now[:notice_err] = "<ul><li>発音の入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"  
          when 1
            @lexemes[0]["base_id"] = 0
            base_type="1"
          when 2
            base = 0
            @lexemes.each{ |x|
              if x["cform"] == 1
                base_word = JpLexeme.find(:all, :conditions=>["surface =? and reading = ? and pronunciation = ? and ctype = ? and cform = ?", x["surface"], x["reading"], x["pronunciation"], x["ctype"], x["cform"]])
                if base_word.blank?
                  base = @lexemes.index(x)
                  base_type="1"
                else
                  base = base_word[0].id
                  base_type="2"
                end
                break
              end
            }
            @lexemes.each{ |x| x["base_id"] = base }
        end
        point_base = "false"
      end
      # point_base true means the base word is specified; false means the baes word is not specified
      # when point_base is false, base_type 1 means base_lexeme_ref is the order in new word series;
      #                           base_type 2 means base_lexeme_ref is the real base_lexeme_ref field in the database
      #############################################################################
            
      ####################################
      #At last, render page
      render :partial=>"preview_news", :object=>@lexemes, :locals=> {:point_base => point_base, :base_type => base_type, :structure => nil }
      ####################################
    end
  end

  def create
    lexemes = []
    customize_property = []    
    for indexes in 1..(params.size)
      original_property = {}
      customize_category = {}
      customize_text = {}
      customize_time = {}
      unless params["lexeme"+indexes.to_s].blank?
        params["lexeme1"].each{|key, value|
          case key
            when "surface", "reading", "pronunciation", "dictionary", "log"
              original_property[key] = params["lexeme"+indexes.to_s][key]
            when "pos", "ctype", "cform", "base_id"
              original_property[key] = params["lexeme"+indexes.to_s][key].to_i
            else
              property = JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"])
              case property.type_field
                when "category"
                  customize_category[property.id] = params["lexeme"+indexes.to_s][key].to_i
                when "text"
                  customize_text[property.id] = params["lexeme"+indexes.to_s][key]
                when "time"
                  customize_time[property.id] = params["lexeme"+indexes.to_s][key]
              end
          end
        }
        original_property["id"] = params["lexeme"+indexes.to_s]["id"].to_i unless params["lexeme"+indexes.to_s]["id"].blank?
        lexemes << original_property
        customize_property << [customize_category, customize_text, customize_time]
      end
    end
    
    begin
      new_word = 0
      new_series = 0
      tagging_state_for_new = JpProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
      if params[:base_type] == "1" ## base_id is order
        ## 1. one word, base_is is order 1
        ## 2. series, base is not registered, and base could be any number in series
        ##    2.1. there may be registered word in series
        JpLexeme.transaction do
          base_index = lexemes[0]["base_id"]
          baselexeme = JpLexeme.new(lexemes[base_index])
          baselexeme.id = JpLexeme.maximum('id')+1
          baselexeme.base_id = baselexeme.id
          baselexeme.tagging_state = tagging_state_for_new
          baselexeme.created_by = session[:user_id]
          if baselexeme.save!
            save_aux_properties(customize_property[base_index], baselexeme.id)
            new_word = baselexeme.id
          end
          
          if lexemes.size > 1
            for index in 0..(lexemes.size-1)
              if index == base_index
                next
              elsif lexemes[index]["id"].blank?
                newlexeme = JpLexeme.new(lexemes[index])
                newlexeme.id = JpLexeme.maximum('id')+1
                newlexeme.base_id = baselexeme.id
                newlexeme.tagging_state = tagging_state_for_new
                newlexeme.created_by = session[:user_id]
                if newlexeme.save!
                  save_aux_properties(customize_property[index], newlexeme.id)
                end
              else
                save_series_aux_properties(lexemes[index], customize_property[index], baselexeme.id)
              end
            end
            new_series = baselexeme.id
          end
        end
      elsif params[:base_type] == "2"  ## base_id is real lexeme id
        ## 1. one word
        ## 2. series, base is registered
        ##      2.1. there may be registered word in series
        JpLexeme.transaction do
          firstlexeme = JpLexeme.new(lexemes[0])
          firstlexeme.id = JpLexeme.maximum('id')+1
          firstlexeme.tagging_state = tagging_state_for_new
          firstlexeme.created_by = session[:user_id]
          firstlexeme.root_id = JpLexeme.find(firstlexeme.base_id).root_id
          if firstlexeme.save!
            save_aux_properties(customize_property[0], firstlexeme.id)
            new_word = firstlexeme.id
          end

          if lexemes.size > 1
            for index in 1..(lexemes.size-1)
              if lexemes[index]["id"].blank?
                newlexeme = JpLexeme.new(lexemes[index])
                newlexeme.id = JpLexeme.maximum('id')+1
                newlexeme.tagging_state = tagging_state_for_new
                newlexeme.created_by = session[:user_id]
                newlexeme.root_id = nil
                if newlexeme.save!
                  save_aux_properties(customize_property[index], newlexeme.id)
                end
              else
                save_series_aux_properties(lexemes[index], customize_property[index])
              end
            end
            firstlexeme.root_id = nil
            firstlexeme.save!
            new_series = firstlexeme.base_id
          end
        end
      end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を新規できません</li></ul>"
      flash[:notice_err] = "<ul><li>#{e}</li></ul>"
      redirect_to :action => 'new'
    else
      flash[:notice] = "<ul><li>単語を新規しました！</li></ul>"
      if lexemes.size == 1
        redirect_to :action => "show", :id => new_word
      else
        redirect_to :action => "search", :search_type => "base", :base_id => new_series
      end
    end
  end

  def destroy
    lexeme = JpLexeme.find(params[:id])
    base = lexeme.base
    begin
      if JpSynthetic.exists?(["sth_struct rlike '^#{params[:id]},|,#{params[:id]}$|,#{params[:id]},'"])
        flash[:notice_err] = "<ul><li>ほかの単語の内部構造になるので、削除できません！</li></ul>"
      else
        if lexeme.id != base.id  #word is in base series, but is not base
          JpLexeme.delete_lexeme(lexeme)
          flash[:notice] = "<ul><li>単語を削除しました！</li></ul>"
        else
          if lexeme.same_base_lexemes.size == 1 ##  only the word itself remains in base series, and the word is base
            if lexeme.root_id.blank?  # no root
              JpLexeme.delete_lexeme(lexeme)
              flash[:notice] = "<ul><li>単語を削除しました！</li></ul>"
            elsif not lexeme.root.blank? and lexeme.root.id != lexeme.id ## word's root is not itself
              JpLexeme.delete_lexeme(lexeme)
              flash[:notice] = "<ul><li>単語を削除しました！</li></ul>"
            elsif JpLexeme.find(:all, :conditions=>["root_id=?", lexeme.root_id]).size == 1 ## only the word itself remains in root series
              JpLexeme.delete_lexeme(lexeme)
              flash[:notice] = "<ul><li>単語を削除しました！</li></ul>"
            else # still other words in root series
              flash[:notice_err] = "<ul><li>単語【#{lexeme.surface}】は他の単語のRootになるので、削除できません！</li></ul>"
            end
          else #word is base, still other words in base series
            flash[:notice_err] = "<ul><li>単語【#{lexeme.surface}】は他の単語のBaseになるので、削除できません！</li></ul>"
          end
        end
      end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を削除できません！</li><li>#{e.message}</li></ul>"
      redirect_to :action => 'show', :id => lexeme.id
    else
      if flash[:notice_err].blank?
        redirect_to :action => 'index'
      elsif flash[:notice].blank?
        redirect_to :action => 'show', :id => params[:id]
      end
    end
  end

  private
  def set_title
    @page_title = "Cradle--茶筌辞書管理システム"
  end
  
  def verification ( params = {} )
    result = []
    ###################################
    #item1 is JpLexeme and JpSynthetic properties
    #item2 is JpLexemeNewPropertyItem properties
    #item3 is JpSyntheticNewPropertyItem properties
    condition = [[], [], []] 
    ################################
    return "", "", "<ul><li>IDは数字だけで指定して下さい！</li></ul>" if not params[:id][:value].blank? and %r[^\d+$].match(params[:id][:value]) == nil
    params.each{|key, value|
      case key
        when "commit", "authenticity_token", "controller", "action", "search_type"
          next
        else
          if initial_property_name[key] != nil or ["sth_modified_by", "sth_updated_at"].include?(key)
            case key
              when "character_number"
                unless params[key][:value].blank?
                  result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  temp = params[key][:value].to_i*3
                  case params[key][:operator]
                    when ">="
                      regexp = "^.{#{temp},}$"
                    when ">"
                      regexp = "^.{#{temp+3},}$"
                    when "="
                      regexp = "^.{#{temp},#{temp}}$"
                    when "<="
                      regexp = "^.{0,#{temp}}$"
                    when "<"
                      regexp = "^.{0,#{temp-3}}$"
                  end
                  condition[0]<<" jp_lexemes.surface REGEXP '#{regexp}' "
                end
              when "id"
                unless params[key][:value].blank?
                  result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  condition[0]<<" jp_lexemes.#{key} #{params[key][:operator]} #{params[key][:value].to_i} "
                end
              when "surface", "reading", "pronunciation"
                unless params[key][:value].blank?
                  if params[key][:operator] == "like"
                    regexp="%"
                    case params[key][:value]
                      when '%'
                        temp = '\\%'
                      when '\''
                        temp = "\\\'"
                      when '_'
                        temp = '\_'
                      else
                        temp = params[key][:value]
                    end
                  else
                    regexp=""
                    case params[key][:value]
                      when '\''
                        temp = "\\\'"
                      else
                        temp = params[key][:value]
                    end
                  end
                  result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  condition[0]<<" jp_lexemes.#{key} #{params[key][:operator]} '#{regexp}#{temp}#{regexp}' "
                end
              when "base_id"
                unless params[key][:value].blank?
                  result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  if params[key][:operator] == "="
                    specific_base = JpLexeme.find(:all, :conditions=>["surface='#{params[key][:value]}'"])
                  elsif params[key][:operator] == "like"
                    specific_base = JpLexeme.find(:all, :conditions=>[" surface like ? ", '%'+params[key][:value]+'%'])
                  end
                  if specific_base.blank?
                    condition[0]<<" jp_lexemes.#{key} is NULL "
                  else
                    same_base_array = []
                    specific_base.each{|item| same_base_array.concat(item.same_base_lexemes.map{|lexeme| lexeme.id}) }
                    condition[0]<<" jp_lexemes.#{key} in (#{same_base_array.join(',')}) "
                  end
                end
              when "pos", "ctype", "cform", "tagging_state", "sth_tagging_state"
                values = params[key].dup
                values.delete("operator")
                section_strings = get_ordered_string_from_params(values)
                temp = JpProperty.find_item_by_tree_string_or_array(key, section_strings)
                case params[key][:operator]
                  when "in", "not in"
                    unless temp.blank?
                      series = temp.sub_tree_items.map{|item| item.property_cat_id}.uniq
                      series.delete(0)
                      case key
                        when "sth_tagging_state"
                          result << "構造#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_synthetics.#{key} #{params[key][:operator]} (#{series.join(',')}) "
                        when "pos", "ctype", "cform", "tagging_state"
                          result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} (#{series.join(',')}) "  
                      end
                    end
                  when "=", "!="
                    unless temp.blank?
                      case key
                        when "sth_tagging_state"
                          result << "構造#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_synthetics.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                        when "pos", "ctype", "cform", "tagging_state"
                          result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                      end
                    end
                end
              when "created_by", "modified_by", "sth_modified_by"
                unless params[key][:value].blank?
                  if ["created_by", "modified_by"].include?(key)
                    result << "#{initial_property_name[key]}#{operator0[params[key][:operator]]}#{User.find(params[key][:value].to_i).name}"
                    condition[0]<<" jp_lexemes.#{key} #{params[key][:operator]} '#{params[key][:value].to_i}' "
                  elsif key == "sth_modified_by"
                    result << "構造#{initial_property_name["modified_by"]}#{operator0[params[key][:operator]]}#{User.find(params[key][:value].to_i).name}"
                    condition[0]<<" jp_synthetics.modified_by #{params[key][:operator]} #{params[key][:value].to_i} "
                  end
                end
              when "dictionary"
                unless params[key][:value] == [""]
                  dic_names_array = []
                  dic_num = []
                  params[key][:value].each{|item|
                    dic_names_array << JpProperty.find(:first, :conditions=>["property_string='dictionary' and property_cat_id=?", item.to_i]).tree_string
                    dic_num << item
                  }
                  result << "#{initial_property_name[key]}:(#{dic_names_array.join(operator0[params[key][:operator]])})"
                  temp_section = []
                  dic_num.each{|num| temp_section << " jp_lexemes.dictionary rlike '^#{num}$|^#{num},|,#{num}$|,#{num},' " }
                  condition[0] << " ("+temp_section.join(' '+params[key][:operator]+' ')+") "
                end
              when "updated_at", "sth_updated_at"
                temp = params[key].dup
                temp.delete("operator")
                unless temp.values.join("") == ""
                  if temp["section(1i)"]=="" or temp["section(2i)"]=="" or temp["section(3i)"]==""
                    return "", "", "<ul><li>更新時間を最低日まで指定して下さい！</li></ul>"
                  else
                    begin
                      time = DateTime.civil(temp["section(1i)"].to_i, temp["section(2i)"].to_i, temp["section(3i)"].to_i, temp["section(4i)"].to_i, temp["section(5i)"].to_i)
                      if key == "sth_updated_at"
                        result << "構造#{initial_property_name["updated_at"]}#{operator0[params[key][:operator]]}#{time.to_formatted_s(:db)}"
                        condition[0] << " jp_synthetics.updated_at #{params[key][:operator]} '#{time.to_formatted_s(:db)}' "
                      elsif key == "updated_at"
                        result << "#{initial_property_name["updated_at"]}#{operator0[params[key][:operator]]}#{time.to_formatted_s(:db)}"
                        condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} '#{time.to_formatted_s(:db)}' "
                      end
                    rescue
                      return "", "", "<ul><li>時間を正しく指定して下さい！</li></ul>"
                    end
                  end
                end
            end
          else
            property = JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"])
            case property.type_field
              when "category"
                values = params[key].dup
                values.delete("operator")
                section_strings = get_ordered_string_from_params(values)
                temp = JpProperty.find_item_by_tree_string_or_array(key, section_strings)
                case params[key][:operator]
                  when "in", "not in"
                    unless temp.blank?
                      result << "#{property.human_name}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                      series = temp.sub_tree_items.map{|item| item.property_cat_id}.uniq
                      series.delete(0)
                      case property.section
                        when "synthetic"
                          condition[2] << " jp_synthetic_new_property_items.property_id = '#{property.id}' and jp_synthetic_new_property_items.category #{params[key][:operator]} (#{series.join(',')}) "
                        when "lexeme"
                          condition[1] << " jp_lexeme_new_property_items.property_id = '#{property.id}' and jp_lexeme_new_property_items.category #{params[key][:operator]} (#{series.join(',')}) "
                      end
                    end
                  when "=", "!="
                    unless temp.blank?
                      result << "#{property.human_name}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                      case property.section
                        when "synthetic"
                          condition[2] << " jp_synthetic_new_property_items.property_id = '#{property.id}' and jp_synthetic_new_property_items.category #{params[key][:operator]} #{temp.property_cat_id} "
                        when "lexeme"
                          condition[1] << " jp_lexeme_new_property_items.property_id = '#{property.id}' and jp_lexeme_new_property_items.category #{params[key][:operator]} #{temp.property_cat_id} "
                      end
                    end
                end
              when "text"
                unless params[key][:value].blank?
                  result << "#{property.human_name}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  params[key][:operator] == "=~" ? regexp="%" : regexp=""
                  case property.section
                    when "synthetic"
                      condition[2] << " jp_synthetic_new_property_items.property_id = '#{property.id}' and jp_synthetic_new_property_items.text #{params[key][:operator]} '#{regexp}#{params[key][:value]}#{regexp}' "
                    when "lexeme"
                      condition[1] << " jp_lexeme_new_property_items.property_id = '#{property.id}' and jp_lexeme_new_property_items.text #{params[key][:operator]} '#{regexp}#{params[key][:value]}#{regexp}' "
                  end               
                end
              when "time"
                temp = params[key].dup
                temp.delete("operator")
                unless temp.values.join("") == ""
                  if temp["section(1i)"]=="" or temp["section(2i)"]=="" or temp["section(3i)"]==""
                    return "", "", "<ul><li>#{property.human_name}を最低日まで指定して下さい！</li></ul>"
                  else
                    begin
                      time = DateTime.civil(temp["section(1i)"].to_i, temp["section(2i)"].to_i, temp["section(3i)"].to_i, temp["section(4i)"].to_i, temp["section(5i)"].to_i)
                      result << "#{name_string}#{operator0[params[key][:operator]]}#{time.to_formatted_s(:db)}"
                      case property.section
                        when "synthetic"
                          condition[2] << " jp_synthetic_new_property_items.property_id = '#{property.id}' and jp_synthetic_new_property_items.time #{params[key][:operator]} '#{time.to_formatted_s(:db)}' "
                        when "lexeme"
                          condition[1] << " jp_lexeme_new_property_items.property_id = '#{property.id}' and jp_lexeme_new_property_items.time #{params[key][:operator]} '#{time.to_formatted_s(:db)}' "
                      end
                    rescue
                      return "", "", "<ul><li>時間を正しく指定して下さい！</li></ul>"
                    end
                  end
                end
            end
          end
      end
    }
    if result.empty?
      return "", "", "<ul><li>検索条件を正しく入力して下さい!</li></ul>"
    else
      return condition, result.join(",&nbsp;&nbsp;&nbsp;"), ""
    end
  end

  def save_aux_properties(ary=[], id=0)
    JpLexemeNewPropertyItem.transaction do
      ary[0].each{|key,value| JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :category=>value)}
      ary[1].each{|key,value| JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :text=>value)}
      ary[2].each{|key,value| JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :time=>value)}
    end
  end
  
  def save_series_aux_properties(lexeme_ary=[], property_ary=[], baselexeme_id=nil)
    existed_lexeme = JpLexeme.find(lexeme_ary["id"])
    lexeme_ary.each{|key, value|
      case key
        when "id"
          next
        when "base_id"
          baselexeme_id.blank? ? eval("existed_lexeme."+key+"=#{value}") : existed_lexeme.base_id = baselexeme.id
        when "pos", "ctype", "cform"
          eval "existed_lexeme."+key+"=#{value}"
        else
          eval "existed_lexeme."+key+"='#{value}'"
      end
    }
    existed_lexeme.modified_by = session[:user_id]
    existed_lexeme.root_id = nil
    if existed_lexeme.save!
      JpLexemeNewPropertyItem.transaction do
        new_field = []
        property_ary[0].each{|key,value|
          temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, existed_lexeme.id])
          temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>existed_lexeme.id, :category=>value) : temp.update_attributes!(:category=>value)
          new_field << key
        }
        property_ary[1].each{|key,value|
          temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, existed_lexeme.id])
          temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>existed_lexeme.id, :text=>value) : temp.update_attributes!(:text=>value)
          new_field << key
        }
        property_ary[2].each{|key,value|
          temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, existed_lexeme.id])
          temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>existed_lexeme.id, :time=>value) : temp.update_attributes!(:time=>value)
          new_field << key
        }
        JpNewProperty.find(:all, :conditions=>["section='lexeme'"]).each{|item|
          unless new_field.include?(item.id)
            temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", item.id, existed_lexeme.id])
            temp.destroy unless temp.blank?
          end
        }
      end
    end
  end
end