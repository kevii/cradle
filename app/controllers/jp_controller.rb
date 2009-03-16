class JpController < ApplicationController
  before_filter :set_title
  before_filter :authorize, :only => [:input_base, :new, :create, :destroy, :edit, :update, :define_root, :save_roots]

  include SearchModule

  def index
      session[:jp_section_list] = ['1_surface', '2_reading', '3_pronunciation', '4_base_id', '5_root_id', '6_dictionary', '7_pos', '8_ctype', '9_cform', '100_sth_struct'] if session[:jp_section_list].blank?
    if session[:user_id].blank?
      session[:jp_dict_id] = JpProperty.find(:all, :conditions=>["property_string='dictionary' and property_cat_id > 0"]).select{|item| item.value !~ /\*$/}.map{|dict| dict.property_cat_id}
    else
      session[:jp_dict_id] = JpProperty.find(:all, :conditions=>["property_string='dictionary' and property_cat_id > 0"]).map{|dict| dict.property_cat_id}
    end
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
          when "pos", "ctype", "cform", "tagging_state"
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
            when "pos", "ctype", "cform", "base_id", "tagging_state"
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
      if params[:base_type] == "1" ## base_id is order
        ## 1. one word, base_is is order 1
        ## 2. series, base is not registered, and base could be any number in series
        ##    2.1. there may be registered word in series
        JpLexeme.transaction do
          base_index = lexemes[0]["base_id"]
          baselexeme = JpLexeme.new(lexemes[base_index])
          baselexeme.id = JpLexeme.maximum('id')+1
          baselexeme.base_id = baselexeme.id
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
      if JpSynthetic.exists?(["sth_struct like ?", "%-#{lexeme.id}-%"])
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
