class JpController < ApplicationController
  before_filter :set_title
  before_filter :authorize, :only => [:input_base, :new, :create, :destroy, :edit, :update, :define_root, :save_roots]

  include SearchModule

  def direct_list
  	case params[:condition]
  	when /^surface=LIKE=(.*)$/
	    redirect_to :action												=> "list",
	    						:static_condition							=> " jp_lexemes.surface like '%#{$1}%' ",
	    						:simple_search								=> 'true',
	    						:dynamic_lexeme_condition			=> '',
	    						:dynamic_synthetic_condition	=> '',
	    						:show_conditions							=> "単語=~#{$1}",
	                :domain												=> 'jp'
			return
  	when /^surface=EQUAL=(.*)$/
	    redirect_to :action												=> "list",
	    						:static_condition							=> " jp_lexemes.surface = '#{$1}' ",
	    						:simple_search								=> 'true',
	    						:dynamic_lexeme_condition			=> '',
	    						:dynamic_synthetic_condition	=> '',
	    						:show_conditions							=> "単語=#{$1}",
	                :domain												=> 'jp'
	    return
	  when /^index_surface=LIKE=(.*)$/
	  	redirect_to :action => :index, :surface_value => $1, :surface_operator => 'LIKE'
	  	return
	  when /^index_surface=EQUAL=(.*)$/
	  	redirect_to :action => :index, :surface_value => $1, :surface_operator => 'EQUAL'
	  	return
  	else
  		redirect_to '/'
  		return
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

  def show_trans
    @lexeme = JpLexeme.find(params[:id].to_i)
    @senses = @lexeme.senses
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
			lexeme, flash.now[:notice_err] = get_params_from_form(params, 'new')
			unless flash.now[:notice_err].blank?
				render :partial=>"preview_news"
			else
	 			new_lexeme = lexeme.dup
	      temp = JpLexeme.new(lexeme.delete_if{|k,v| not JpLexeme.column_names.include?(k)})
				unless temp.valid?
	        flash.now[:notice_err] = "<ul>" + temp.errors.map{|k,v| '<li>'+v+'</li>'}.join('') + "</ul>"
	        render :partial=>"preview_news"
				else
		      #############################################################################
		      # @lexemes: stores all the words with same base
		      # point_base: true means the base word is specified;
		      #							false means the base word is not specified
		      # base_type: 1 means base_lexeme_ref is the order in new word series;
		      #						 2 means base_lexeme_ref is the real base_lexeme_ref field in the database
		      # error_message will pass to
		      lexemes, point_base, base_type, flash.now[:notice_err] = JpLexeme.verify_words_in_base(params, new_lexeme)
	      	render :partial=>"preview_news", :object=>lexemes, :locals=> {:point_base => point_base, :base_type => base_type, :structure => nil }
	      end
	    end
    end
  end

  def create
		lexemes = []
		other_properties = []
    for indexes in 1..(params.size)
	    unless params["lexeme"+indexes.to_s].blank?
				temp_lexeme = {}
				temp_other = {}
 				get_params_from_form(params["lexeme"+indexes.to_s], 'create')[0].each{|k, v|
 					JpLexeme.column_names.include?(k) ? temp_lexeme[k] = v : temp_other[k] = v
 				}
 				if temp_lexeme['id'].blank?
 					lexemes << JpLexeme.new(temp_lexeme)
 				else
	 				temp_record = JpLexeme.find(temp_lexeme['id'])
	 				temp_lexeme.each{|k, v| temp_record[k] = v}
	 				lexemes << temp_record
				end
 				other_properties << temp_other
	    end
    end

    begin
    	new_word, new_series = JpLexeme.create_new_word_or_series(params, lexemes, other_properties, session[:user_id])
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を新規できません</li><li>#{e}</li></ul>"
      redirect_to :action => 'new'
    else
      flash[:notice] = "<ul><li>単語を新規しました！</li></ul>"
      if new_series.blank?
        redirect_to :action => "show", :id => new_word
      else
        redirect_to :action => "search", :search_type => "base", :domain => 'jp', :base_id => new_series
      end
    end
  end

  def destroy
    begin
    	flash[:notice], flash[:notice_err] = JpLexeme.delete_lexeme(params)
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を削除できません！</li><li>#{e.message}</li></ul>"
      redirect_to :action => 'show', :id => params[:id]
    else
      if flash[:notice_err].blank?
        redirect_to :action => 'index'
      elsif flash[:notice].blank?
        redirect_to :action => 'show', :id => params[:id]
      end
    end
  end

  def edit
    if request.post?
			lexeme, flash.now[:notice_err] = get_params_from_form(params, 'edit')
			unless flash.now[:notice_err].blank?
				render :partial=>"preview_edit"
			else
	 			temp = JpLexeme.find(params[:id])
				if lexeme['base_id'].blank?
	     		lexeme["base_id"] = temp.base_id
       		lexeme["root_id"] = temp.root_id
				end
	 			passing_lexeme = lexeme.dup
	      lexeme.delete_if{|k,v| not JpLexeme.column_names.include?(k)}.each{|key, value| temp[key] = value}
				unless temp.valid?
	        flash.now[:notice_err] = "<ul>" + temp.errors.map{|k,v| '<li>'+v+'</li>'}.join('') + "</ul>"
	        render :partial=>"preview_edit"
				else
		      original = JpLexeme.find(params["id"])
		      if original.id == original.base_id and original.same_base_lexemes.size != 1 and original.base_id != passing_lexeme["base_id"].to_i
		        series_change = "true"
		      else
		        series_change = "false"
		      end
		      render :partial=>"preview_edit", :object=>passing_lexeme, :locals=> { :series_change => series_change }
				end
	    end
    end
  end

  def update
		lexeme = {}
		other_properties = {}
		get_params_from_form(params, 'update')[0].each{|k, v|
 			JpLexeme.column_names.include?(k) ? lexeme[k] = v : other_properties[k] = v
		}
		lexeme.update({:modified_by => session[:user_id]})
		updating_lexeme = JpLexeme.find(lexeme['id'])
    begin
      JpLexeme.transaction do
      	updating_lexeme.update_attributes!(lexeme)
      	lexeme_dynamic_property_ids = updating_lexeme.dynamic_properties.map(&:property_id)
      	JpNewProperty.find_all_by_section('lexeme').each{|property|
      		if other_properties.key?(property.property_string)
      			if lexeme_dynamic_property_ids.include?(property.id)
      				updating_lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].update_attributes!(property.type_field.to_sym=>other_properties[property.property_string])
      			else
      				updating_lexeme.dynamic_properties.create!(:property_id=>property.id, property.type_field.to_sym=>other_properties[property.property_string])
      			end
      		else
      			if lexeme_dynamic_property_ids.include?(property.id)
      				updating_lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].destroy
      			end
      		end
      	}
        if params['series_change'] == "true"
          updating_lexeme.same_base_lexemes.each{|item|
            next if item.id == updating_lexeme.id
            item.update_attributes!({:base_id=>updating_lexeme.base_id, :root_id=>updating_lexeme.root_id, :modified_by => session[:user_id]})
          }
        end
      end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>問題が発生しました、単語を更新できません</li><li>#{e}</li></ul>"
      redirect_to :action => 'edit', :id=>JpLexeme.find(params['id'])
    else
      flash[:notice] = "<ul><li>単語を更新しました！</li></ul>"
      if params['series_change'] == "true"
        redirect_to :action => "search", :search_type => "base", :base_id => lexeme["base_id"], :domain => 'jp'
      else
        redirect_to :action => "show", :id => params['id']
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
              while(JpLexeme.exists?(:root_id=>new_root_id))
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
          redirect_to :action => "search", :search_type=>"root", :root_id=>new_root_id, :domain => 'jp'
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
            redirect_to :action => "search", :search_type=>"root", :root_id=>params[:new_root], :domain => 'jp'
          end
          return
        end
    end
  end

  private
  def set_title
    @page_title = "Cradle--茶筌辞書管理システム"
  end

	def get_params_from_form(params, state)
    lexeme = {}
    params.each{|key,value|
      case key
      when "surface", "reading", "pronunciation", "log", 'root_id'
      	if ['new', 'edit', 'update'].include?(state) then value.blank? ? lexeme[key]=nil : lexeme[key]=value
      	elsif state == 'create' then lexeme[key]=value end
      when "pos", "ctype", "cform", "tagging_state"
      	if ['new', 'edit'].include?(state)
	        temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
  	      temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
  	    elsif ['create', 'update'].include?(state)
  	    	lexeme[key]=value.to_i
  	    end
      when "dictionary"
      	if ['new', 'edit'].include?(state)
      		lexeme[key]=value.join(',')
      	elsif ['create', 'update'].include?(state)
      		lexeme[key]=value.split(',').map{|item| item.to_i}.sort.map{|item| '-'+item.to_s+'-'}.join(',')
      	end
      when  "base_type", "base", "base_ok", "base_id"
				if state == 'new' then next
				elsif state == 'edit'
					if key == 'base_ok' and value == "true"
        		lexeme["base_id"] = params["base_id"]
        		lexeme["root_id"] = JpLexeme.find(params["base_id"].to_i).root_id
      		elsif key == 'base_ok' and value == 'false'
        		lexeme["base_id"] = params["id"]
		        lexeme["root_id"] = nil
		      end
      	elsif state == 'create' then lexeme[key]=value.to_i
      	elsif state == 'update'
      		lexeme[key] = value.to_i if key == 'base_id'
      	end
      when 'id'
      	if state == 'new' then next
      	elsif state == 'edit' then lexeme[key]=value.to_i
      	elsif state == 'create'
      		lexeme[key]=value.to_i unless value.blank?
      	elsif state == 'update'
      		lexeme[key] = value.to_i
      	end
      else
      	property = JpNewProperty.find_by_property_string(key)
      	unless property.blank?
          case property.type_field
          when "category"
          	if ['new', 'edit'].include?(state)
	            temp = JpProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
  	          temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
  	        elsif ['create', 'update'].include?(state)
  	        	lexeme[key] = value.to_i
  	        end
          when "text"
          	if ['new', 'edit'].include?(state)
	            value.blank? ? lexeme[key]=nil : lexeme[key]=value
	          elsif ['create', 'update'].include?(state)
	          	lexeme[key] = value
	          end
          when "time"
          	if ['new', 'edit'].include?(state)
	            if value.values.join("").blank? then lexeme[key]=nil
	            else
	              time_error, time_string = verify_time_property(:value=>value, :domain=>'cn')
	              if time_error.blank? then lexeme[key] = time_string
	              else
	              	return nil, time_error
	              end
	            end
	          elsif ['create', 'update'].include?(state)
	          	lexeme[key] = value
	          end
          end
        end
      end
    }
    return lexeme, nil
  end
end

