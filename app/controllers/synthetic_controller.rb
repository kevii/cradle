class SyntheticController < ApplicationController
  include SyntheticHelper
  
  def define_internal_structure
    lexeme_class = verify_domain(params[:info][:domain])['Lexeme']
    case params[:split_action][:type]
      when "define"
	structure = make_initial_structure(:info=>params[:info])
      when "delete"
        params[:structure] = swap_structure_array_and_string(params[:structure].dup, [])
        if params[:split_action][:divide_type] == "vertical"
          if params[:split_action][:point].blank?
            params[:structure] = [params[:info][:original_id], 'initial_'+lexeme_class.constantize.find(params[:info][:original_id].to_i).surface]
          else
            temp = eval('params[:structure]'+params[:split_action][:point]+'[0]')
            if temp =~ /^meta_(.*)$/
              temp='meta_'+$1
            end
            eval('params[:structure]'+params[:split_action][:point]+'=temp')
          end
        elsif params[:split_action][:divide_type] == "horizontal"
          if params[:left].blank? or params[:right].blank?
	    flash.now[:notice_err] = get_error_message(params[:info][:domain])
          else
            eval('params[:structure]'+params[:split_action][:right_hand_index]+'=transfer_left_or_right_part_to_structure(params[:right], lexeme_class)')
            eval('params[:structure]'+params[:split_action][:left_hand_index]+'=transfer_left_or_right_part_to_structure(params[:left], lexeme_class)')
          end
        end
        structure = params[:structure]
      else
        params[:structure] = swap_structure_array_and_string(params[:structure].dup, [])
        if params[:left].blank? or params[:right].blank?
	  flash.now[:notice_err] = get_error_message(params[:info][:domain])
        elsif params[:split_action][:type] == 'new'
          if params[:split_action][:divide_type] == "vertical"
            if eval('params[:structure]'+params[:split_action][:point]) =~ /^meta_(.*)$/
              temp = ['meta_'+$1]
            elsif eval('params[:structure]'+params[:split_action][:point]) =~ /^update_(.*)$/
	      temp = ['update_'+$1]
            else
              temp = [eval('params[:structure]'+params[:split_action][:point])]
            end
            temp[1] = transfer_left_or_right_part_to_structure(params[:left], lexeme_class)
            temp[2] = transfer_left_or_right_part_to_structure(params[:right], lexeme_class)
            eval('params[:structure]'+params[:split_action][:point]+'=temp')
          elsif params[:split_action][:divide_type] == "horizontal"
            temp = transfer_left_or_right_part_to_structure(params[:right], lexeme_class)
            eval('params[:structure]'+params[:split_action][:point]+'=temp')
            temp = params[:split_action][:point].split('][')
            if temp.size == 1
              params[:structure].insert(temp[0][1..-2].to_i, transfer_left_or_right_part_to_structure(params[:left], lexeme_class))
            else
              pre_index = temp[0..-2].join('][')+']'
              index = temp.last[0..-2].to_i
              temp = transfer_left_or_right_part_to_structure(params[:left], lexeme_class)
              eval('params[:structure]'+pre_index+'.insert(index, temp)')
            end
          end
	elsif params[:split_action][:type] ==  "modify"
          eval('params[:structure]'+params[:split_action][:left_hand_index]+'=transfer_left_or_right_part_to_structure(params[:left], lexeme_class)')
          eval('params[:structure]'+params[:split_action][:right_hand_index]+'=transfer_left_or_right_part_to_structure(params[:right], lexeme_class)')
        end
        structure = params[:structure]
    end
	debugger
    render :update do |page|
      page["synthetic_struct"].replace :partial=>"show_internal_structure", :object=> structure, :locals=>{:info=>params[:info]}
    end
  end

  def split_word
    params[:structure] = swap_structure_array_and_string(params[:structure].dup, [])
    lexeme_class = verify_domain(params[:info][:domain])['Lexeme']
    lexemes_left = lexeme_class.constantize.find(:all, :include=>[:struct], :conditions=>["surface=?", params[:left]], :order=>"id ASC")
    lexemes_right = lexeme_class.constantize.find(:all, :include=>[:struct], :conditions=>["surface=?", params[:right]], :order=>"id ASC")
    case params[:split_action][:type]
      when "modify"
	left_id = get_type_or_id_from_structure(eval('params[:structure]'+params[:split_action][:left_hand_index]))
	right_id = get_type_or_id_from_structure(eval('params[:structure]'+params[:split_action][:right_hand_index]))
      when "delete"
        if params[:split_action][:left_hand_index].include?('..')
          left_id = nil
	  right_id = get_type_or_id_from_structure(eval('params[:structure]'+params[:split_action][:right_hand_index]))
        elsif params[:split_action][:left_hand_index].include?('..')
          right_id = nil
	  left_id = get_type_or_id_from_structure(eval('params[:structure]'+params[:split_action][:left_hand_index]))
        end
      when "new"
        left_id = nil
        right_id = nil
    end
    render :update do |page|
      page.replace "candidate", :partial=>"left_or_right", :object=>[lexemes_left, lexemes_right],  
                                :locals => {:left=>params[:left],         :right=>params[:right],
                                            :left_id=>left_id,            :right_id=>right_id,
                                            :info=>params[:info],         :structure=>params[:structure],
                                            :split_action=>params[:split_action]}
    end
  end

#  def modify_structure  ##params:  ids, from, chars, original_id, domain
#    meta_ids, meta_chars = get_meta_structures(:ids=>params[:ids], :chars=>params[:chars])
#    meta_show_chars = meta_chars.dup
#    indexes = meta_show_chars.size - 1
#    while(indexes >= 0) do
#      if meta_show_chars['meta_'+indexes.to_s].include?('meta')
#        temp = []
#        meta_show_chars['meta_'+indexes.to_s].split(',').each{|item| item.include?('meta') ? temp << meta_show_chars[item].split(',').join("") : temp << item}
#        meta_show_chars['meta_'+indexes.to_s] = temp.join(',')
#      end
#      indexes = indexes - 1
#    end
#    if params[:from] == "new"
#      object = ""
#    elsif params[:from] == "modify"
#      class_name = verify_domain(params[:domain])['Synthetic']
#      structs = eval(class_name+%Q|.find(:all, :conditions=>["sth_ref_id=?", params[:original_id].to_i])|)
#      object = {}
#      structs.each{|substruct| object['meta_'+substruct.sth_meta_id.to_s]=substruct }
#    end
#    render :update do |page|
#      page["synthetic_struct"].replace :partial=>"synthetic/modify_internal_struct", :object=>object,
#                                       :locals=>{ :ids=>params[:ids],   :chars=>params[:chars], :original_id=>params[:original_id],
#                                                  :from=>params[:from], :meta_ids=>meta_ids,  :meta_chars=>meta_chars,
#                                                  :meta_show_chars=>meta_show_chars, :domain=>params[:domain] }
#    end
#  end

  private
  def make_initial_structure(option)
    if option[:info][:from] == 'creation'
      return [option[:info][:original_id], 'initial_'+verify_domain(option[:info][:domain])['Lexeme'].constantize.find(option[:info][:original_id].to_i).surface]
    elsif option[:info][:from] == 'modification'
      option[:meta_id] = 0 if option[:meta_id].blank?
      temp_synthetic = verify_domain(option[:info][:domain])['Synthetic'].constantize.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", 
option[:ref_id].to_i, option[:meta_id]])
      option[:meta_id] ==0 ? structure = [option[:info][:original_id]] : structure = ['meta_'+temp_synthetic.sth_surface]
      temp_array = temp_synthetic.sth_struct.map{|item| item.delete('-')}
      temp_array.each{|item|
        if item =~ /^\d+$/
          structure << item
        elsif item =~ /^meta_(\d+)$/
          structure << make_initial_structure(:info=>option[:info], :meta_id=>$1.to_i)
        end
      }
      return structure      
    end
  end

  def get_error_message(domain)
    case domain
      when 'jp'
        return '<ul><li>左右の部分を両方選択してください！</li></ul>'
      when 'cn'
        return '<ul><li>左右两个部分必须都要选择！</li></ul>'
      when 'en'
        return '<ul><li>Plese select both left and right part in division!</li></ul>'
    end
  end

  def transfer_left_or_right_part_to_structure(option, lexeme_class)
    type, value = option.split(',')
    case type
      when 'meta'
        return 'meta_'+value
      when 'dummy'
        return 'dummy_'+value
      when 'select'
        return value
      when 'update'
        return 'update_'+value
    end
  end

  def get_type_or_id_from_structure(item)
    if is_string(item) == false
      if item[0] =~ /^meta_(.*)$/
	return 'meta'
      else
	return item[0]
      end
    else
      if item =~ /^meta_(.*)$/
        return 'meta'
      elsif item =~ /^dummy_(.*)$/
        return 'dummy'
      else
        return item
      end	
    end
  end
end
