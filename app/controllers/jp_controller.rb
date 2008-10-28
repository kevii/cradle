class JpController < ApplicationController
  layout 'cradle'
  include JpHelper
  before_filter :set_title
  before_filter :authorize, :only => [ :new, :create, :destroy, :edit, :update,
                                       :define_internal_structure, :split_word, :modify_structure, :save_internal_struct, :destroy_struct,
                                       :define_root, :save_roots]
  
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
      simple_search = "true"
      dynamic_lexeme_condition = search_conditions[1].join(" **and** ")
      simple_search = "false" if search_conditions[1].size > 1
      dynamic_synthetic_condition = search_conditions[2].join(" **and** ")
      simple_search = "false" if search_conditions[2].size > 1
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
                                   :simple_search=>simple_search,
                                   :dynamic_lexeme_condition=>dynamic_lexeme_condition,
                                   :dynamic_synthetic_condition=>dynamic_synthetic_condition,
                                   :show_conditions => show_conditions
  end
  
  def list
    params[:page].blank? ? page = nil : page = params[:page].to_i
    if params[:per_page].blank?
      per_page = 30
      params[:per_page] = "30"
    else
      per_page = params[:per_page].to_i
    end
    if params[:dynamic_lexeme_condition].blank? and params[:dynamic_synthetic_condition].blank?
      @jplexemes = JpLexeme.paginate( :select=>" jp_lexemes.* ",   :conditions => params[:static_condition],
                                      :include => [:sub_structs],  :order => " jp_lexemes.id ASC ",
                                      :per_page => per_page,       :page => page )
    elsif params[:simple_search] == "true"
      mysql_condition_string = [params[:static_condition].gsub('jp_synthetics', 'dynamic_struct_properties_jp_lexemes_join'),params[:dynamic_lexeme_condition],params[:dynamic_synthetic_condition]]
      mysql_condition_string.delete("")
      mysql_string = %Q| SELECT DISTINCT jp_lexemes.* | +
                     %Q| FROM jp_lexemes LEFT OUTER JOIN jp_lexeme_new_property_items ON jp_lexeme_new_property_items.ref_id = jp_lexemes.id | +
                     %Q| LEFT OUTER JOIN jp_synthetics dynamic_struct_properties_jp_lexemes_join ON (jp_lexemes.id = dynamic_struct_properties_jp_lexemes_join.sth_ref_id) | +
                     %Q| LEFT OUTER JOIN jp_synthetic_new_property_items ON (jp_synthetic_new_property_items.ref_id = dynamic_struct_properties_jp_lexemes_join.id) | +
                     %Q| WHERE | + mysql_condition_string.join(' and ') +
                     %Q| ORDER BY  jp_lexemes.id ASC |
      @jplexemes = JpLexeme.paginate_by_sql(mysql_string, :per_page => per_page, :page => page )  
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
        dynamic_lexeme_ids.size >= dynamic_synthetic_refs.size ? dynamic_ids = dynamic_synthetic_refs & dynamic_lexeme_ids : dynamic_ids = dynamic_lexeme_ids & dynamic_synthetic_refs
      end
      if params[:static_condition].blank?
        collection = install_by_dividing(:ids=>dynamic_ids, :domain=>'jp')
        @jplexemes = collection.paginate(:page=>page, :per_page=>per_page)
      else
        static_ids = JpLexeme.find(:all, :select=>" jp_lexemes.id ", :conditions => params[:static_condition], :include => [:sub_structs], :order => " jp_lexemes.id ASC ").map{|item| item.id}
        static_ids.size >= dynamic_ids.size ? final_ids = dynamic_ids & static_ids : final_ids = static_ids & dynamic_ids
        @jplexemes = JpLexeme.paginate(:all, :conditions=>["id in (#{final_ids.join(',')})"], :page=>page, :per_page=>per_page)
      end
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
  end

  def show_desc
    render :update do |page|
      page["show_desc"].replace :partial=>"show_desc", :object=>JpLexeme.find(params[:id].to_i)
      if params[:state] == "false"
        page["show_desc"].visual_effect :slide_down
      else
        page["show_desc"].visual_effect :highlight
      end
    end
  end

  def input_base
    unless params[:base_type].blank?
      render :partial => 'input_base', :locals => { :message => "", :base_type => params[:base_type], :original_base=>"" }
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
            temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
            temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
          when "dictionary"
            lexeme[key]=value.join(',')
          when  "base_type", "base", "base_ok", "base_id"
          else
            case JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"]).type_field
              when "category"
                temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
                temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
              when "text"
                value.blank? ? lexeme[key]=nil : lexeme[key]=value
              when "time"
                if value.values.join("").blank?
                  lexeme[key]=nil
                else
                  time_error, time_string = verify_time_property(:value=>value, :domain=>'jp')
                  if time_error.blank?
                    lexeme[key] = time_string
                  else
                    flash.now[:notice_err] = time_error
                    render :partial=>"preview_news"
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
            when "surface", "reading", "pronunciation", "log"
              original_property[key] = params["lexeme"+indexes.to_s][key]
            when "dictionary"
              original_property[key] = params["lexeme"+indexes.to_s][key].split(',').map{|item| item.to_i}.sort.map{|item| '-'+item.to_s+'-'}.join(',')
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
                  debugger
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
      if JpSynthetic.exists?(["sth_struct like ?", "'%-#{params[:id]}-%'"])
        flash[:notice_err] = "<ul><li>ほかの単語の内部構造になっているので、削除できません！</li></ul>"
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

  def edit
    if params[:preview_edit].blank?
      @lexeme = JpLexeme.find(params[:id])
    elsif params[:preview_edit] == 'true'
      if params[:surface].blank? or params[:reading].blank? or params[:pronunciation].blank?
        flash.now[:notice_err] = "<ul><li>単語、読み、発音は必須属性なので、全部入力してください！</li><ul>"
        render :partial=>"preview_edit"
        return
      end
      #############################################################################
      #tidy up the input properties
      params.delete("commit")
      params.delete("authenticity_token")
      params.delete("action")
      params.delete("controller")
      lexeme = {"id"=>params[:id].to_i}
      params.each{|key,value|
        case key
          when "surface", "reading", "pronunciation", "log"
            value.blank? ? lexeme[key]=nil : lexeme[key]=value
          when "pos", "ctype", "cform", "tagging_state"
            temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
            temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
            if key=="tagging_state" and lexeme["tagging_state"].blank?
              flash.now[:notice_err] = "<ul><li>単語の状態は必須なので、空に設定しないでください！</li><ul>"
              render :partial=>"preview_edit"
              return
            end
          when "dictionary"
            lexeme[key]=value.join(',')
          when  "base_type", "base", "base_ok", "base_id", "id", "preview_edit"
            next
          else
            case JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"]).type_field
              when "category"
                temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
                temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
              when "text"
                value.blank? ? lexeme[key]=nil : lexeme[key]=value
              when "time"
                if value.values.join("").blank?
                  lexeme[key]=nil
                else
                  time_error, time_string = verify_time_property(:value=>value, :domain=>'jp')
                  if time_error.blank?
                    lexeme[key]=time_string
                  else
                    flash.now[:notice_err] = time_error
                    render :partial=>"preview_edit"
                    return
                  end
                end
            end
        end
      }
      if params["base_ok"] == "true"
        lexeme["base_id"] = params["base_id"]
        lexeme["root_id"] = JpLexeme.find(params["base_id"].to_i).root_id
      else
        lexeme["base_id"] = params["id"]
        lexeme["root_id"] = nil
      end
      original = JpLexeme.find(params["id"].to_i)
      if original.id == original.base_id and original.same_base_lexemes.size != 1 and original.base_id != lexeme["base_id"].to_i
        series_change = "true"
      else
        series_change = "false"
      end
      #############################################################################
      
      #############################################################################
      #see if this word has already been registered
      if JpLexeme.exist_when_new(lexeme)[0] == true
        flash.now[:notice_err] = "<ul><li>単語　#{lexeme['surface']}　はすでに辞書に保存している</li></ul>"
        render :partial=>"preview_edit"
        return
      end
      #############################################################################
      render :partial=>"preview_edit", :object=>lexeme, :locals=> { :series_change => series_change }
    end
  end

  def update
    series_change = ""
    original_id = 0
    lexeme = {}
    customize_property = [{}, {}, {}]
    params.each{|key, value|
      case key
        when "series_change"
          series_change = value
        when "id"
          original_id = value.to_i
        when "commit", "authenticity_token", "action", "controller"
          next
        when "surface", "reading", "pronunciation", "log", "root_id"
          params[key].blank? ? lexeme[key] = nil : lexeme[key] = value
        when "dictionary"
          params[key].blank? ? lexeme[key] = nil : lexeme[key] = value.split(',').map{|item| item.to_i}.sort.map{|item| '-'+item.to_s+'-'}.join(',')
        when "pos", "ctype", "cform", "base_id", "tagging_state"
          params[key].blank? ? lexeme[key] = nil : lexeme[key] = value.to_i
        else
          property = JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"])
          case property.type_field
            when "category"
              customize_property[0][property.id] = value.to_i
            when "text"
              customize_property[1][property.id] = value
            when "time"
              customize_property[2][property.id] = value
          end
      end
    }
    begin
      JpLexeme.transaction do
        original_lexeme = JpLexeme.find(original_id)
        lexeme.each{|key, value| original_lexeme[key]=value }
        original_lexeme.modified_by = session[:user_id]
        if original_lexeme.save!
          save_series_aux_properties_core(customize_property, original_id)
        end
        if series_change == "true"
          JpLexeme.find(:all, :conditions=>["base_id=#{original_id}"]).each{|item|
            next if item.id == original_id
            item.base_id = original_lexeme.base_id
            item.root_id = original_lexeme.root_id
            item.save!
          }
        end
      end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を更新できません</li></ul>"
      flash[:notice_err] = "<ul><li>#{e}</li></ul>"
      redirect_to :action => 'edit', :id=>JpLexeme.find(original_id)
    else
      flash[:notice] = "<ul><li>単語を更新しました！</li></ul>"
      if series_change == "true"
        redirect_to :action => "search", :search_type => "base", :base_id => lexeme["base_id"]
      else
        redirect_to :action => "show", :id => original_id
      end
    end
  end

  def define_root
    if request.post?
      case params[:type]
        when "define"
          input_id_list = params[:id_list].split(/\t|\s/).join("").split(',')
          is_number = true
          input_id_list.each{|id| is_number = false if (id =~ /^\d*$/) == nil }
          if input_id_list.blank? or is_number == false
            flash.now[:notice_err] = "<ul><li>同じRoot系列に指定したい単語リストを正しく入力してください</li></ul>"
            render :partial=>"preview_same_root"
          elsif not params[:option_real_root].blank? and (params[:option_real_root] =~ /^\d*$/) == nil
            flash.now[:notice_err] = "<ul><li>Root単語のIDを正しく入力してください</li></ul>"
            render :partial=>"preview_same_root"
          else
            root_list = []
            base_list = []
            input_id_list.each{|id|
              lexeme = JpLexeme.find(id.to_i)
              base_list << lexeme.base_id unless lexeme.base_id.blank?
              root_list << lexeme.root_id unless lexeme.root_id.blank?
            }
            root_list = root_list.uniq.sort
            root_list.blank? ? new_root = "NEW" : new_root = root_list.map{|item| item if item=~/^R/}.compact.sort{|a,b| a.gsub(/^R/, "")<=>b.gsub(/^R/, "")}[0]
            root_list.each{|root| JpLexeme.find(:all, :conditions=>["root_id=?",root]).each{|lexeme| base_list << lexeme.base_id unless base_list.include?(lexeme.base_id)}}
            base_list = base_list.uniq.sort
            if params[:option_real_root].blank?
              render :partial=>"preview_same_root", :object=>[base_list, []], :locals=>{:type=>params[:type], :new_root=>new_root}
            else
              temp = JpLexeme.find(params[:option_real_root].to_i)
              if base_list.include?(temp.base_id) and temp.id == temp.base_id
                render :partial=>"preview_same_root", :object=>[base_list, root_list], :locals=>{:type=>params[:type], :new_root=>params[:option_real_root]}
              else
                if temp.id != temp.base_id
                  flash.now[:notice_err] = "<ul><li>【Root単語】になれるのは【Base単語】のみなので、【Base単語】のIDを入力してください！</li></ul>"
                elsif not base_list.include?(temp.base_id)
                  flash.now[:notice_err] = "<ul><li>指定した【Root単語】は入力した【同じRoot系列にしたい単語リスト】に含めていないので、もう一度入力してください！</li></ul>"
                end
                render :partial=>"preview_same_root"
              end
            end
          end
        when "destroy"
          temp = JpLexeme.find(params[:destroy_root])
          if temp.root_id.blank?
            flash.now[:notice_err] = "<ul><li>入力した単語がRootを持っていないまた、操作はできない</li></ul>"
            render :partial=>"preview_same_root"
          else
            base_list = []
            temp.same_root_lexemes.each{|item| base_list << item.base_id unless base_list.include?(item.base_id)}
            old_base_list = base_list.uniq.sort
            base_list.delete(temp.base_id)
            base_list = base_list.uniq.sort
            if not base_list.blank? and temp.base_id == temp.root_id.to_i
              flash.now[:notice_err] = "<ul><li>外したいBase系列の【Base単語】はRoot系列の【Root単語】になっているので、操作を続くには、まずRoot系列の【Root単語】を変更してください</li></ul>"
              render :partial=>"preview_same_root"
            else
              render :partial=>"preview_same_root", :object=>[base_list, old_base_list],
                     :locals=>{:type=>params[:type], :new_root=>temp.root_id, :deleted=>temp.same_base_lexemes.size}
            end
          end
      end
    end
  end

  def save_roots
    case params[:type]
      when "define"
        new_root_id = nil
        begin
          JpLexeme.transaction do
            if params[:new_root]=="NEW"
              max = JpLexeme.maximum('id')
              new_root_id = "R"+max.to_s
              while(JpLexeme.exists?(:root_id=>temp_string))
                new_root_id = "R"+(rand(max)+1).to_s
              end
            else
              new_root_id = params[:new_root]
            end
            params[:base_list].split(',').each{|base| JpLexeme.find(base.to_i).same_base_lexemes.each{|lexeme| lexeme.update_attributes!(:root_id=>new_root_id)}}
          end
        rescue Exception => e
          flash[:notice_err] = "<ul><li>問題が発生しました、Root系列指定できません</li></ul>"
          flash[:notice_err] << "<ul><li>#{e}</li></ul>"
          redirect_to :action => "define_root"
          return
        else
          flash[:notice] = "<ul><li>Root系列を指定しました！</li></ul>"
          redirect_to :action => "search", :search_type=>"root", :root_id=>new_root_id
          return
        end
      when "destroy"
        begin
          if params[:base_list].blank?
            JpLexeme.transaction do
              JpLexeme.find(:all, :conditions=>["root_id=?",params[:new_root]]).each{|lexeme| lexeme.update_attributes!(:root_id => nil)}
            end
          else
            old_base_list = params[:old_base_list].split(',')
            base_list = params[:base_list].split(',')
            deleted_base_list = old_base_list - base_list
            JpLexeme.transaction do
              deleted_base_list.each{|base| JpLexeme.find(base.to_i).same_base_lexemes.each{|lexeme| lexeme.update_attributes!(:root_id => nil)}}
            end
          end
        rescue Exception => e
          flash[:notice_err] = "<ul><li>問題が発生しました、Root系列から外されません。</li></ul>"
          flash[:notice_err] << "<ul><li>#{e}</li></ul>"
          redirect_to :action => "define_root"
          return
        else
          flash[:notice] = "<ul><li>Root系列から外しました！</li></ul>"
          if params[:base_list].blank?
            redirect_to :action => "index"  
          else
            redirect_to :action => "search", :search_type=>"root", :root_id=>params[:new_root]
          end
          return
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
          if initial_property_name('jp')[key] != nil or ["sth_modified_by", "sth_updated_at"].include?(key)
            case key
              when "character_number"
                unless params[key][:value].blank?
                  result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  condition[0]<<" char_length(jp_lexemes.surface) #{params[key][:operator]} #{params[key][:value].to_i} "
                end
              when "sth_struct"
                unless params[key][:value].blank?
                  temp = JpLexeme.find(:all, :select=>"id", :conditions=>["surface=?", params[key][:value]])
                  unless temp.blank?
                    temp = temp.map{|item| item.id}
                    temp_lexeme_id = []
                    temp.each{|temp_id|
                      temp_structs = JpSynthetic.find(:all, :select=>"sth_ref_id", :conditions=>["sth_struct like ?", '%-'+temp_id.to_s+'-%'])
                      temp_lexeme_id.concat(temp_structs.map{|item| item.sth_ref_id}.uniq) unless temp_structs.blank?
                    }
                    unless temp_lexeme_id.blank?
                      result << "#{initial_property_name('jp')[key]}include#{params[key][:value]}"
                      condition[0] << " jp_lexemes.id in (#{temp_lexeme_id.uniq.join(',')}) "
                    end
                  end
                end
              when "id"
                unless params[key][:value].blank?
                  result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
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
                  result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
                  condition[0]<<" jp_lexemes.#{key} #{params[key][:operator]} '#{regexp}#{temp}#{regexp}' "
                end
              when "base_id"
                unless params[key][:value].blank?
                  result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{params[key][:value]}"
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
                temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(values))
                case params[key][:operator]
                  when "in", "not in"
                    unless temp.blank?
                      series = temp.sub_tree_items.map{|item| item.property_cat_id}.uniq
                      series.delete(0)
                      case key
                        when "sth_tagging_state"
                          result << "構造#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_synthetics.#{key} #{params[key][:operator]} (#{series.join(',')}) "
                        when "pos", "ctype", "cform", "tagging_state"
                          result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} (#{series.join(',')}) "  
                      end
                    end
                  when "=", "!="
                    unless temp.blank?
                      case key
                        when "sth_tagging_state"
                          result << "構造#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_synthetics.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                        when "pos", "ctype", "cform", "tagging_state"
                          result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{temp.tree_string}"
                          condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} #{temp.property_cat_id} "
                      end
                    end
                end
              when "created_by", "modified_by", "sth_modified_by"
                unless params[key][:value].blank?
                  if ["created_by", "modified_by"].include?(key)
                    result << "#{initial_property_name('jp')[key]}#{operator0[params[key][:operator]]}#{User.find(params[key][:value].to_i).name}"
                    condition[0]<<" jp_lexemes.#{key} #{params[key][:operator]} '#{params[key][:value].to_i}' "
                  elsif key == "sth_modified_by"
                    result << "構造#{initial_property_name('jp')["modified_by"]}#{operator0[params[key][:operator]]}#{User.find(params[key][:value].to_i).name}"
                    condition[0]<<" jp_synthetics.modified_by #{params[key][:operator]} #{params[key][:value].to_i} "
                  end
                end
              when "dictionary"
                unless params[key][:value] == [""]
                  dic_names_array = []
                  dic_num = []
                  params[key][:value].each{|item|
                    dic_names_array << JpProperty.find(:first, :conditions=>["property_string='dictionary' and property_cat_id=?", item.to_i]).tree_string
                    dic_num << item.to_i
                  }
                  result << "#{initial_property_name('jp')[key]}:(#{dic_names_array.join(operator0[params[key][:operator]])})"
                  temp_section = []
                  if params[key][:operator] == "and"
                    dic_num.sort.each{|num| temp_section << "%-#{num.to_s}-%"}
                    condition[0] << %Q| jp_lexemes.dictionary like '#{temp_section.join(",")}' |
                  elsif params[key][:operator] == "or"
                    dic_num.each{|num| temp_section << " jp_lexemes.dictionary like '%-#{num}-%' "}
                    condition[0] << " ("+temp_section.join(' '+params[key][:operator]+' ')+") "
                  end
                end
              when "updated_at", "sth_updated_at"
                temp = params[key].dup
                temp.delete("operator")
                unless temp.values.join("") == ""
                  time_error, time_string = verify_time_property(:value=>temp, :domain=>'jp')
                  if time_error.blank?
                    time = time_string
                    if key == "sth_updated_at"
                      result << "構造#{initial_property_name('jp')["updated_at"]}#{operator0[params[key][:operator]]}#{time}"
                      condition[0] << " jp_synthetics.updated_at #{params[key][:operator]} '#{time}' "
                    elsif key == "updated_at"
                      result << "#{initial_property_name('jp')["updated_at"]}#{operator0[params[key][:operator]]}#{time}"
                      condition[0] << " jp_lexemes.#{key} #{params[key][:operator]} '#{time}' "
                    end
                  else
                    return "", "", time_error
                  end
                end
            end
          else
            property = JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"])
            case property.type_field
              when "category"
                values = params[key].dup
                values.delete("operator")
                temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(values))
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
                  params[key][:operator] == "like" ? regexp="%" : regexp=""
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
                  time_error, time_string = verify_time_property(:value=>temp, :domain=>'jp')
                  if time_error.blank?
                    time = time_string
                    result << "#{name_string}#{operator0[params[key][:operator]]}#{time}"
                    case property.section
                      when "synthetic"
                        condition[2] << " jp_synthetic_new_property_items.property_id = '#{property.id}' and jp_synthetic_new_property_items.time #{params[key][:operator]} '#{time}' "
                      when "lexeme"
                        condition[1] << " jp_lexeme_new_property_items.property_id = '#{property.id}' and jp_lexeme_new_property_items.time #{params[key][:operator]} '#{time}' "
                    end
                  else
                    return "", "", time_error
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
      save_series_aux_properties_core(property_ary, existed_lexeme.id)
    end
  end
  
  def save_series_aux_properties_core(property_ary=[], id=nil)
    JpLexemeNewPropertyItem.transaction do
      new_field = []
      property_ary[0].each{|key,value|
        temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, id])
        temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :category=>value) : temp.update_attributes!(:category=>value)
        new_field << key
      }
      property_ary[1].each{|key,value|
        temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, id])
        temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :text=>value) : temp.update_attributes!(:text=>value)
        new_field << key
      }
      property_ary[2].each{|key,value|
        temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", key, id])
        temp.blank? ? JpLexemeNewPropertyItem.create!(:property_id=>key, :ref_id=>id, :time=>value) : temp.update_attributes!(:time=>value)
        new_field << key
      }
      JpNewProperty.find(:all, :conditions=>["section='lexeme'"]).each{|item|
        unless new_field.include?(item.id)
          temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", item.id, id])
          temp.destroy unless temp.blank?
        end
      }
    end
  end
  
end
