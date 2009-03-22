class CnController < ApplicationController
  before_filter :set_title
  before_filter :authorize, :only => [:input_base, :new, :create, :destroy, :edit, :update, :define_root, :save_roots]

  include SearchModule

  def load_section_list
    if params[:state] == "false"
      render(:update){|page|
        page[:field_list].replace_html :partial=>"field_list", :object=>session[:cn_section_list]
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
    session[:cn_section_list] = section_list.sort{|a,b| a.split('_')[0].to_i<=>b.split('_')[0].to_i}
    render(:update) { |page| page.call 'location.reload' }
  end

  def show
    @lexeme = CnLexeme.find(params[:id].to_i)
  end

  def show_desc
    render :update do |page|
      page["show_desc"].replace :partial=>"show_desc", :object=>CnLexeme.find(params[:id].to_i)
      if params[:state] == "false"
        page["show_desc"].visual_effect :slide_down
      else
        page["show_desc"].visual_effect :highlight
      end
    end
  end


  def new
    if request.post?
			lexeme, flash.now[:notice_err] = get_params_from_form(params)
			unless flash.now[:notice_err].blank?
				render :partial=>"preview"
			else
	 			@lexeme = lexeme.dup
	      temp = CnLexeme.new(lexeme.delete_if{|k,v| not CnLexeme.column_names.include?(k)})
				unless temp.valid?
	        flash.now[:notice_err] = "<ul>" + temp.errors.map{|k,v| '<li>'+v+'</li>'}.join('') + "</ul>"
	        render :partial=>"preview"
				else
		      render :partial=>"preview", :object=>@lexeme, :locals=>{:action_string=>'create'}
				end
			end
    end
  end

  def create
    lexeme = CnLexeme.new(params[:lexeme])
    begin
      CnLexeme.transaction do
    		lexeme.dictionary = lexeme.dictionary.split(',').map{|item| item.to_i}.sort.map{|item| '-'+item.to_s+'-'}.join(',')
        lexeme.id = CnLexeme.maximum('id')+1
        lexeme.created_by = session[:user_id]
				lexeme.save!
				unless params[:other_property].blank?
					params[:other_property].each{|key,value|
						property = CnNewProperty.find_by_property_string(key)
						lexeme.dynamic_properties.create!(:property_id=>property.id, property.type_field.to_sym=>value)
					}
				end
			end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>程序出现问题，不能创建新单词！</li><li>#{e.message}</li></ul>"
      redirect_to :action => "new"
    else
      flash[:notice] = "<ul><li>成功创建单词！</li></ul>"
      redirect_to :action => "show", :id => lexeme.id
    end
  end

	def destroy
    if CnSynthetic.exists?(["sth_struct like ?", "%-#{params[:id]}-%"])
      flash[:notice_err] = "<ul><li>此单词被使用在其它单词的内部结构中，不能被删除！</li></ul>"
      redirect_to :action => 'show', :id => params[:id]
    else
			begin
				CnLexeme.transaction do CnLexeme.find(params[:id]).destroy end
		  rescue Exception => e
	      flash[:notice_err] = "<ul><li>程序出现问题，不能删除单词！</li><li>#{e.message}</li></ul>"
	      redirect_to :action => 'show', :id => params[:id]
	    else
				flash[:notice] = "<ul><li>成功删除单词！</li></ul>"
	      redirect_to :action => 'index'
	    end
		end
	end

  def edit
    if request.post?
			lexeme, flash.now[:notice_err] = get_params_from_form(params)
			unless flash.now[:notice_err].blank?
				render :partial=>"preview"
			else
	 			@lexeme = lexeme.dup
	 			temp = CnLexeme.find(params[:id])
	      lexeme.delete_if{|k,v| not CnLexeme.column_names.include?(k)}.each{|key, value| temp[key] = value}
				unless temp.valid?
	        flash.now[:notice_err] = "<ul>" + temp.errors.map{|k,v| '<li>'+v+'</li>'}.join('') + "</ul>"
	        render :partial=>"preview"
				else
		      render :partial=>"preview", :object=>@lexeme, :locals=>{:action_string=>'update', :id=>params[:id]}
				end
			end
    end
	end

	def update
    params[:lexeme].update({:dictionary => params[:lexeme][:dictionary].split(',').map{|item| item.to_i}.sort.map{|item| '-'+item.to_s+'-'}.join(','), :modified_by => session[:user_id]})
   	lexeme = CnLexeme.find(params[:id])
    begin
      CnLexeme.transaction do
      	lexeme.update_attributes!(params[:lexeme])
      	lexeme_dynamic_property_ids = lexeme.dynamic_properties.map(&:property_id)
      	CnNewProperty.find_all_by_section('lexeme').each{|property|
      		if params[:other_property].key?(property.property_string)
      			if lexeme_dynamic_property_ids.include?(property.id)
      				lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].update_attributes!(property.type_field.to_sym=>params[:other_property][property.property_string.to_sym])
      			else
      				lexeme.dynamic_properties.create!(:property_id=>property.id, property.type_field.to_sym=>params[:other_property][property.property_string.to_sym])
      			end
      		else
      			if lexeme_dynamic_property_ids.include?(property.id)
      				lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].destroy
      			end
      		end
      	}
			end
    rescue Exception => e
      flash[:notice_err] = "<ul><li>程序出现问题，不能更新修改单词！</li><li>#{e.message}</li></ul>"
      redirect_to :action => "edit", :id => lexeme.id
    else
      flash[:notice] = "<ul><li>成功更新修改单词！</li></ul>"
      redirect_to :action => "show", :id => lexeme.id
    end
	end

  private
  def set_title
    @page_title = "Cradle--ChaSen辞典管理系统"
  end

	def get_params_from_form(params)
    lexeme = {}
    params.each{|key,value|
      case key
      when "surface", "reading", "log" then value.blank? ? lexeme[key]=nil : lexeme[key]=value
      when "pos", "tagging_state"
        temp = CnProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
        temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
      when "dictionary" then lexeme[key]=value.join(',')
      else
      	property = CnNewProperty.find_by_property_string(key)
      	unless property.blank?
          case property.type_field
          when "category"
            temp = CnProperty.find_item_by_tree_string_or_array(key, get_ordered_string_from_params(value.dup))
            temp.blank? ? lexeme[key] = nil : lexeme[key] = temp.property_cat_id
          when "text"
            value.blank? ? lexeme[key]=nil : lexeme[key]=value
          when "time"
            if value.values.join("").blank? then lexeme[key]=nil
            else
              time_error, time_string = verify_time_property(:value=>value, :domain=>'cn')
              if time_error.blank? then lexeme[key] = time_string
              else
              	return nil, time_error
              end
            end
          end
        end
      end
    }
    return lexeme, nil
  end
end