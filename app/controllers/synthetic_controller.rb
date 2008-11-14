class SyntheticController < ApplicationController
  before_filter :authorize
  
  def define_internal_structure
    lexeme_class = verify_domain(params[:info][:domain])['Lexeme']
    case params[:split_action][:type]
      when "define"
        if params[:structure].blank?
          structure = make_initial_structure(:info=>params[:info])
        else
          structure = swap_structure_array_and_string(params[:structure].dup, [])
        end
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
            flash.now[:notice_err] = get_error_message(params[:info][:domain], "define_internal_structure")
          else
            eval('params[:structure]'+params[:split_action][:right_hand_index]+'=transfer_left_or_right_part_to_structure(params[:right], lexeme_class)')
            eval('params[:structure]'+params[:split_action][:left_hand_index]+'=transfer_left_or_right_part_to_structure(params[:left], lexeme_class)')
          end
        end
        structure = params[:structure]
      else
        params[:structure] = swap_structure_array_and_string(params[:structure].dup, [])
        if params[:left].blank? or params[:right].blank?
          flash.now[:notice_err] = get_error_message(params[:info][:domain], "define_internal_structure")
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
    temp = get_create_and_update_structures(:structure=>structure, :domain=>params[:info][:domain])
    string_structure = swap_structure_array_and_string('', structure.dup)
    root_structure = get_structure_display_string(:structure=>structure, :domain=>params[:info][:domain])
    render :update do |page|
      page["synthetic_struct"].replace :partial=>"show_internal_structure", :object=> structure,
                                       :locals=>{:info=>params[:info], :string_structure=>string_structure, :root_structure=>root_structure,
                                                 :to_create=>temp[0], :to_update=>temp[1]}
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
    string_structure = swap_structure_array_and_string('', params[:structure].dup)
    render :update do |page|
      page.replace "candidate", :partial=>"left_or_right", :object=>[lexemes_left, lexemes_right],  
                                :locals => {:left=>params[:left],         :right=>params[:right],
                                            :left_id=>left_id,            :right_id=>right_id,
                                            :info=>params[:info],         :split_action=>params[:split_action],
                                            :string_structure=>string_structure}
    end
  end

  def review_structure
    render :partial=>"review_structure", :locals=>{:id=>params[:id].to_i, :domain=>params[:domain]}
  end
    
  def modify_structure
    if params[:first_modification].blank?
      params[:structure] = swap_structure_array_and_string(params[:structure].dup, [])
      top_structure = get_structure_display_string(:structure=>params[:structure], :domain=>params[:info][:domain])
      to_create_structure, to_update_structure = get_create_and_update_structures(:structure=>params[:structure], :domain=>params[:info][:domain])
      not_defined = false
      not_defined = true if top_structure.include?('()') or top_structure.include?('[]')
      [to_create_structure, to_update_structure].each{|array| array.each{|string| not_defined = true if string.include?('()') or string.include?('[]')}}
      if not_defined == true
        flash.now[:notice_err] = get_error_message(params[:info][:domain], "modify_structure_1")
        temp = get_create_and_update_structures(:structure=>params[:structure], :domain=>params[:info][:domain])
        string_structure = swap_structure_array_and_string('', params[:structure].dup)
        root_structure = get_structure_display_string(:structure=>params[:structure], :domain=>params[:info][:domain])
        render :update do |page|
          page["synthetic_struct"].replace :partial=>"show_internal_structure", :object=>params[:structure],
                                           :locals=>{:info=>params[:info], :string_structure=>string_structure, :root_structure=>root_structure,
                                                     :to_create=>temp[0], :to_update=>temp[1]}
        end
        return
      end
      top_meta = get_meta_structure(:structure=>params[:structure], :domain=>params[:info][:domain])[0]
      create_indexes, update_indexes = find_structure_indexes(:structure=>params[:structure])
      create_meta_array = []
      update_meta_array = []
      create_indexes.each{|index_string| create_meta_array << get_meta_structure(:structure=>eval('params[:structure]'+index_string), :domain=>params[:info][:domain])[0]}
      update_indexes.each{|index_string| update_meta_array << get_meta_structure(:structure=>eval('params[:structure]'+index_string), :domain=>params[:info][:domain])[0]}
      flash.now[:notice_err] = params[:err_msg] unless params[:err_msg].blank?
      string_structure = swap_structure_array_and_string('', params[:structure].dup)
      render :update do |page|
        page["synthetic_struct"].replace :partial=>"modify_internal_struct",
                                         :object=>[top_meta, create_meta_array, update_meta_array],
                                         :locals=>{:top_structure=>top_structure,             :to_create_structure=>to_create_structure,
                                                   :to_update_structure=>to_update_structure, :info=>params[:info], :first_modification=>'',
                                                   :string_structure=>string_structure}
      end
      return
    else
      structure = make_initial_structure(:info=>params[:info])
      top_structure = get_structure_display_string(:structure=>structure, :domain=>params[:info][:domain])
      top_meta = verify_domain(params[:info][:domain])['Synthetic'].constantize.find(:all, :order=>'sth_meta_id ASC', :conditions=>["sth_ref_id=?", params[:info][:original_id]])
      flash.now[:notice_err] = params[:err_msg] unless params[:err_msg].blank?
      string_structure = swap_structure_array_and_string('', structure.dup)
      render :update do |page|
        page["synthetic_struct"].replace :partial=>"modify_internal_struct", :object=>top_meta,
                                         :locals=>{:top_structure=>top_structure, :info=>params[:info], :first_modification=>"true",
                                                   :string_structure=>string_structure}
      end
      return
    end
  end

  def save_internal_struct
    lexeme_class_name = verify_domain(params[:info][:domain])['Lexeme']
    class_name = verify_domain(params[:info][:domain])['Synthetic']
    property_class_name = verify_domain(params[:info][:domain])['Property']
    new_property_class_name = verify_domain(params[:info][:domain])['NewProperty']
    item_class_name = verify_domain(params[:info][:domain])['SyntheticNewPropertyItem']
    case params[:info][:domain]
      when "jp"
        alert_string = "<ul><li>問題が発生しました、構造を新規できません</li></ul>"
        success_string = "<ul><li>構造を新規しました！</li></ul>"
      when "cn"
        alert_string = "<ul><li>问题发生，不能创建内部结构</li></ul>"
        success_string = "<ul><li>内部结构已创建！</li></ul>"
      when "en"
        alert_string = "<ul><li>Problem occurred, cannot create internal structure</li></ul>"
        success_string = "<ul><li>Internal structure created!</li></ul>"
    end
    category_names = {}
    new_property_class_name.constantize.find(:all, :conditions=>["section='synthetic' and type_field='category'"]).each{|item| category_names[item.property_string]=item.id}
    text_names = {}
    new_property_class_name.constantize.find(:all, :conditions=>["section='synthetic' and type_field='text'"]).each{|item| text_names[item.property_string]=item.id}
    time_names = {}
    new_property_class_name.constantize.find(:all, :conditions=>["section='synthetic' and type_field='time'"]).each{|item| time_names[item.property_string]=item.id}

    top_word = {}
    new_words = []
    update_words = []
    dummy_words = {}
    all_lexemes = []
    params.each{|item, value|
      case item
        when "commit", "authenticity_token", "action", "controller", "info", "first_modification", "structure"
          next
        when /^top_(.*)(\d+)_(.*)$/
          meta_id = $2
          field_name = $3
          top_word[meta_id.to_i] = {} if top_word[meta_id.to_i].blank?
          err_msg, temp_hash = format_meta_hashes(:category_names=>category_names, :text_names=>text_names, :time_names=>time_names, :property_class_name=>property_class_name,
                                                  :domain=>params[:info][:domain], :field_name=>field_name, :value=>value)
          if err_msg.blank?
            top_word[meta_id.to_i].update(temp_hash)
          else
            redirect_to :action => "modify_structure", :first_modification=>params[:first_modification], :info=>params[:info],
                                                       :structure=>params[:structure], :err_msg=>err_msg
            return
          end
        when /^new(\d+)_meta(\d+)_(.*)$/
          word_id = $1
          meta_id = $2
          field_name = $3
          new_words[word_id.to_i] = {} if new_words[word_id.to_i].blank?
          new_words[word_id.to_i][meta_id.to_i] = {} if new_words[word_id.to_i][meta_id.to_i].blank?
          err_msg, temp_hash = format_meta_hashes(:category_names=>category_names, :text_names=>text_names, :time_names=>time_names, :property_class_name=>property_class_name,
                                                  :domain=>params[:info][:domain], :field_name=>field_name, :value=>value)
          if err_msg.blank?
            new_words[word_id.to_i][meta_id.to_i].update(temp_hash)
          else
            redirect_to :action => "modify_structure", :first_modification=>params[:first_modification], :info=>params[:info],
                                                       :structure=>params[:structure], :err_msg=>err_msg
            return
          end
        when /^update(\d+)_meta(\d+)_(.*)$/
          word_id = $1
          meta_id = $2
          field_name = $3
          update_words[word_id.to_i] = {} if update_words[word_id.to_i].blank?
          update_words[word_id.to_i][meta_id.to_i] = {} if update_words[word_id.to_i][meta_id.to_i].blank?
          err_msg, temp_hash = format_meta_hashes(:category_names=>category_names, :text_names=>text_names, :time_names=>time_names, :property_class_name=>property_class_name,
                                                  :domain=>params[:info][:domain], :field_name=>field_name, :value=>value)
          if err_msg.blank?
            update_words[word_id.to_i][meta_id.to_i].update(temp_hash)
          else
            redirect_to :action => "modify_structure", :first_modification=>params[:first_modification], :info=>params[:info],
                                                       :structure=>params[:structure], :err_msg=>err_msg
            return
          end
      end
    }
      
    if params[:first_modification].blank?
      top_word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
        if part=~/^\d+$/
          all_lexemes << part.to_i
        elsif (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and not dummy_words.has_key?(part)
          dummy_words.store(part, nil)
        end
      }}
      new_words.each{|word| word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
        if part=~/^\d+$/
          all_lexemes << part.to_i
        elsif (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and not dummy_words.has_key?(part)
          dummy_words.store(part, nil)
        end
      }}}
      update_words.each{|word| word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
        if part=~/^\d+$/
          all_lexemes << part.to_i
        elsif (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and not dummy_words.has_key?(part)
          dummy_words.store(part, nil)
        end
      }}}
      dummy_tag = property_class_name.constantize.find_item_by_tree_string_or_array("tagging_state", 'DUMMY').property_cat_id
      root_dictionary = lexeme_class_name.constantize.find(params[:info][:original_id]).dictionary_item
      begin
        class_name.constantize.transaction do
          #####################################
          ####   save dummy words
          lexeme_class_name.constantize.transaction do
            dummy_words.each{|surface, value|
              max_id = lexeme_class_name.constantize.maximum('id')
              temp = lexeme_class_name.constantize.new(:surface=>surface, :base_id=>max_id+1, :dictionary=>root_dictionary.to_s, :tagging_state=>dummy_tag, :created_by=>session[:user_id])
              temp.id = max_id+1
              if temp.save!
                dummy_words[surface] = temp.id.to_s
              end
            }
          end
          
          #####################################
          #####   update dummy words' id in meta structure and all lexemes
          top_word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
            if (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and dummy_words.has_key?(part)
              top_word[id][:sth_struct] = top_word[id][:sth_struct].gsub(part, dummy_words[part])
            end
          }}
          new_words.each_with_index{|word, index| word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
            if (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and dummy_words.has_key?(part)
              new_words[index][id][:sth_struct] = new_words[index][id][:sth_struct].gsub(part, dummy_words[part])
            end
          }}}
          update_words.each_with_index{|word, index| word.each{|id, meta| meta[:sth_struct].split(',').map{|item| item.delete('-')}.each{|part|
            if (part=~/^\d+$/)==nil and (part=~/^meta_(\d+)$/)==nil and dummy_words.has_key?(part)
              update_words[index][id][:sth_struct] = new_words[index][id][:sth_struct].gsub(part, dummy_words[part])
            end
          }}}
          dummy_words.each{|key, value| all_lexemes << value.to_i}
          all_lexemes = all_lexemes.uniq
          
          ######################################
          ####      save the update words
          old_struct_ids = []
          update_words.each{|word| old_struct_ids.concat(class_name.constantize.find(:all, :conditions=>["sth_ref_id=?", word[0][:sth_ref_id].to_i]).map{|item| item.id})}
          old_struct_ids.uniq.each{|structure_id|
            item_class_name.constantize.transaction do
              item_class_name.constantize.find(:all, :conditions=>["ref_id=?", structure_id]).each{|temp| temp.destroy}
            end
            class_name.constantize.find(structure_id).destroy
          }
          update_words.each{|word| save_word_structure(:word=>word, :class_name=>class_name, :user_id=>session[:user_id], :item_class_name=>item_class_name, :category_names=>category_names, :text_names=>text_names, :time_names=>time_names)}
          
          ######################################
          ####      save the new words
          new_words.each{|word| save_word_structure(:word=>word, :class_name=>class_name, :user_id=>session[:user_id], :item_class_name=>item_class_name, :category_names=>category_names, :text_names=>text_names, :time_names=>time_names)}
          
          
          #####################################
          ####   delete old structure if from modification
          if params[:info][:from] == 'modification'
            class_name.constantize.find(:all, :conditions=>["sth_ref_id=?", params[:info][:original_id].to_i]).each{|old_structure|
              item_class_name.constantize.transaction do
                item_class_name.constantize.find(:all, :conditions=>["ref_id=?", old_structure.id]).each{|temp| temp.destroy}
              end
              old_structure.destroy
            }
          end
          
          ######################################
          ####      save root word
          save_word_structure(:word=>top_word, :class_name=>class_name, :user_id=>session[:user_id], :item_class_name=>item_class_name, :category_names=>category_names, :text_names=>text_names, :time_names=>time_names)
          
          
          ######################################
          ####     update existing meta part whose sth_surface matches with the root word
          all_intermedia = class_name.constantize.find(:all, :conditions=>["sth_surface=? and sth_meta_id != 0", top_word[0][:sth_surface]])
          if not all_intermedia.blank? and params[:info][:from] == 'creation'
            super_root_dictionay_list = replace_intermedia_part_with_new(:id=>params[:info][:original_id].to_i, :domain=>params[:info][:domain], :all_intermedia=>all_intermedia,
                                                                         :lexeme_class_name=>lexeme_class_name,  :class_name=>class_name,         :item_class_name=>item_class_name)
            if (super_root_dictionay_list - root_dictionary.list).blank?
              final_update_dictioary_list = root_dictionary.list
            else
              final_update_dictioary_list = root_dictionary.list.concat(super_root_dictionay_list - root_dictionary.list).uniq.sort
            end
          else
            final_update_dictioary_list = root_dictionary.list
          end
          
          ######################################
          ####      update all words' dictionary
          lexeme_class_name.constantize.transaction do
            all_lexemes.each{|id|
              lexeme = lexeme_class_name.constantize.find(id)
              temp = final_update_dictioary_list - lexeme.dictionary_item.list
              unless temp.blank?
                new_dictionary_string = lexeme.dictionary_item.list.concat(temp).uniq.sort.map{|item| '-'+item+'-'}.join(",")
                lexeme.update_attributes!(:dictionary=>new_dictionary_string)
              end
            }
          end
        end
      rescue
        redirect_to :action => "modify_structure", :first_modification=>params[:first_modification], :info=>params[:info],
                                                   :structure=>params[:structure], :err_msg=>alert_string
        return
      else
        flash[:notice_special] = success_string
        render(:update) { |page| page.call 'location.reload' }
      end
    else
      begin
        class_name.constantize.transaction do
          item_class_name.constantize.transaction do
            top_word.each{|meta_id, content| item_class_name.constantize.find(:all, :conditions=>["ref_id=?", content[:id]]).each{|temp| temp.destroy}}
          end
          sth_tagging_state_tag = property_class_name.constantize.find_item_by_tree_string_or_array('sth_tagging_state', get_ordered_string_from_params(top_word[0][:sth_tagging_state])).property_cat_id
          top_word.each{|meta_id, content|
            structure = class_name.constantize.find(content[:id])
            structure.update_attributes!(:sth_tagging_state=>sth_tagging_state_tag, :log=>content[:log], :modified_by=>session[:user_id])
            save_word_structure_property(:item_class_name=>item_class_name, :content=>content, :category_names=>category_names,
                                         :text_names=>text_names, :time_names=>time_names, :structure_id=>structure.id)
          }
        end
      rescue
        redirect_to :action => "modify_structure", :first_modification=>params[:first_modification], :info=>params[:info]
        return
      else
        flash[:notice_special] = success_string
        render(:update) { |page| page.call 'location.reload' }
      end
    end
  end

  def destroy_struct
    case params[:domain]
      when "jp"
        alert_string = "<ul><li>問題が発生しました、内部構造を削除できません</li></ul>"
        success_string = "<ul><li>内部構造を削除しました！</li></ul>"
      when "cn"
        alert_string = "<ul><li>问题发生，不能删除内部结构</li></ul>"
        success_string = "<ul><li>内部结构已删除！</li></ul>"
      when "en"
        alert_string = "<ul><li>Problem occurred, cannot delete internal structure</li></ul>"
        success_string = "<ul><li>Internal structure deleted!</li></ul>"
    end
    class_name = verify_domain(params[:domain])['Synthetic']
    item_class_name = verify_domain(params[:domain])['SyntheticNewPropertyItem']
    begin
      class_name.constantize.transaction do
        class_name.constantize.find(:all, :conditions=>["sth_ref_id=?", params[:id].to_i]).each{|sub_structure|
          item_class_name.constantize.transaction do
            item_class_name.constantize.find(:all, :conditions=>["ref_id=?", sub_structure.id]).each{|temp| temp.destroy}
          end
          sub_structure.destroy
        }
      end
    rescue
      flash[:notice_err]=alert_string
    else
      flash[:notice]=success_string
    end
    render(:update) { |page| page.call 'location.reload' }
  end
  
  private
  def make_initial_structure(option)
    if option[:info][:from] == 'creation'
      return [option[:info][:original_id], 'initial_'+verify_domain(option[:info][:domain])['Lexeme'].constantize.find(option[:info][:original_id].to_i).surface]
    elsif option[:info][:from] == 'modification'
      option[:meta_id] = 0 if option[:meta_id].blank?
      temp_synthetic = verify_domain(option[:info][:domain])['Synthetic'].constantize.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", option[:info][:original_id].to_i, option[:meta_id]])
      option[:meta_id] ==0 ? structure = [option[:info][:original_id]] : structure = ['meta_'+temp_synthetic.sth_surface]
      temp_array = temp_synthetic.sth_struct.split(',').map{|item| item.delete('-')}
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

  def get_error_message(domain, action)
    case domain
      when 'jp'
        case action
          when "define_internal_structure"
            return '<ul><li>左右の部分を両方選択してください！</li></ul>'
          when "modify_structure_1"
            return '<ul><li>未定義の部分があるので、確認してください！</li></ul>'
        end
      when 'cn'
        case action
          when "define_internal_structure"
            return '<ul><li>左右两个部分必须都要选择！</li></ul>'
          when "modify_structure_1"
            return '<ul><li>存在没有定义的部分，请重新确认！</li></ul>'
        end
      when 'en'
        case action
          when "define_internal_structure"
            return '<ul><li>Plese select both left and right part in division!</li></ul>'
          when "modify_structure_1"
            return '<ul><li>Not defined part exists, please check again!</li></ul>'
        end
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

  def get_meta_structure(option)
    option[:original_count] = 0 if option[:original_count].blank?
    lexeme_class = verify_domain(option[:domain])['Lexeme']
    meta_hash={}
    meta_hash[option[:original_count]]={}
    string_part = []
    new_count = option[:original_count]
    option[:structure].each_with_index{|section, index|
      if index == 0
        if section =~ /^meta_(.*)$/
          meta_hash[new_count][:surface] = $1
          meta_hash[new_count][:sth_ref_id] = option[:sth_ref_id]
        elsif section =~ /^\d+$/
          meta_hash[new_count][:surface] = lexeme_class.constantize.find(section.to_i).surface
          meta_hash[new_count][:sth_ref_id] = section
        elsif section =~ /^update_(.*)$/
          meta_hash[new_count][:sth_ref_id] = $1
          meta_hash[new_count][:surface] = lexeme_class.constantize.find(meta_hash[new_count][:sth_ref_id].to_i).surface
        end
      else
        if is_string(section) == true
          if section =~ /^\d+$/
            string_part << section
          elsif section =~ /^dummy_(.*)$/
            string_part << $1
          end
        else
          if section[0] =~ /^\d+$/
            string_part << section[0]
          elsif section[0] =~ /^update_(.*)$/
            string_part << $1
          elsif section[0] =~ /^meta_(.*)$/
            string_part << 'meta_'+(new_count+1).to_s
            temp_hash, temp_count = get_meta_structure(:structure=>section, :domain=>option[:domain], :original_count=>new_count+1, :sth_ref_id=>meta_hash[new_count][:sth_ref_id])
            meta_hash.update(temp_hash)
            new_count = temp_count
          end
        end
      end
    }
    meta_hash[option[:original_count]][:sth_struct] = string_part
    return meta_hash, new_count
  end
  
  def format_meta_hashes(option)
    new_hash = {}
    error_msg = ""
    if option[:category_names].include?(option[:field_name])
      temp_string = get_ordered_string_from_params(option[:value])
      if temp_string.blank?
        new_hash[eval(':'+option[:field_name])] = nil
      else
        new_hash[eval(':'+option[:field_name])] = option[:property_class_name].constantize.find_item_by_tree_string_or_array(option[:field_name], temp_string).property_cat_id
      end
    elsif option[:text_names].include?(option[:field_name])
      new_hash[eval(':'+option[:field_name])] = option[:value]
    elsif option[:time_names].include?(option[:field_name])
      time_error, time_string = verify_time_property(:value=>option[:value], :domain=>option[:domain])
      if time_error.blank?
        new_hash[eval(':'+option[:field_name])] = time_string
      else
        error_msg = time_error
        return error_msg, new_hash
      end
    else
      if option[:field_name] == "sth_struct"
        new_hash[eval(':'+option[:field_name])] = option[:value].split(',').map{|item| '-'+item+'-'}.join(',')
      elsif option[:field_name] == "sth_tagging_state"
        temp_string = get_ordered_string_from_params(option[:value])
        if temp_string.blank?
          new_hash[eval(':'+option[:field_name])] = nil
        else
          new_hash[eval(':'+option[:field_name])] = option[:property_class_name].constantize.find_item_by_tree_string_or_array(option[:field_name], temp_string).property_cat_id
        end
      else
        new_hash[eval(':'+option[:field_name])] = option[:value]
      end
    end
    return error_msg, new_hash
  end
  
  def save_word_structure_property(option)
    option[:item_class_name].constantize.transaction do
      option[:content].each{|property, value|
        unless value.blank?
          property = property.to_s
          if option[:category_names].include?(property)
            option[:item_class_name].constantize.create!(:property_id=>option[:category_names][property], :ref_id=>option[:structure_id], :category=>value)
          elsif option[:text_names].include?(property)
            option[:item_class_name].constantize.create!(:property_id=>option[:text_names][property], :ref_id=>option[:structure_id], :text=>value)
          elsif option[:time_names].include?(property)
            option[:item_class_name].constantize.create!(:property_id=>option[:time_names][property], :ref_id=>option[:structure_id], :time=>value)
          end
        end
      }
    end
  end
  
  def save_word_structure(option)
    sth_tagging_state_tag = option[:word][0][:sth_tagging_state]
    option[:word].each{|meta_id, content|
      if meta_id == 0
        structure_id = option[:class_name].constantize.create!(:sth_ref_id=>content[:sth_ref_id], :sth_meta_id=>meta_id, :sth_struct=>content[:sth_struct],
                                                               :sth_surface=>content[:sth_surface], :sth_tagging_state=>sth_tagging_state_tag,
                                                               :log=>content[:log], :modified_by=>option[:user_id]).id
      else
        structure_id = option[:class_name].constantize.create!(:sth_ref_id=>content[:sth_ref_id], :sth_meta_id=>meta_id, :sth_struct=>content[:sth_struct],
                                                               :sth_surface=>content[:sth_surface], :modified_by=>option[:user_id],
                                                               :sth_tagging_state=>sth_tagging_state_tag).id
      end
      save_word_structure_property(:item_class_name=>option[:item_class_name], :content=>content, :category_names=>option[:category_names],
                                   :text_names=>option[:text_names], :time_names=>option[:time_names], :structure_id=>structure_id)
    }
  end
  
  def replace_intermedia_part_with_new(option)
    all_super_root = option[:all_intermedia].map{|item| item.sth_ref_id}.uniq.sort
    option[:class_name].constantize.transaction do
      option[:all_intermedia].each{|inter_part|
        debugger
        option[:class_name].constantize.find(:all, :conditions=>["sth_ref_id=? and sth_struct like ?", inter_part.sth_ref_id, '%-meta\_'+inter_part.sth_meta_id.to_s+'-%']).each{|to_update|
          to_update.update_attributes!(:sth_struct=>to_update.sth_struct.gsub("-meta_#{inter_part.sth_meta_id.to_s}-", "-#{option[:id].to_s}-"))
        }
        debugger
        find_below_meta_structure(:class_name=>option[:class_name], :inter_part=>inter_part).each{|below_meta_structure|
          option[:item_class_name].constantize.transaction do
            option[:item_class_name].constantize.find(:all, :conditions=>["ref_id=?", below_meta_structure.id]).each{|temp| temp.destroy}
          end
          below_meta_structure.destroy
        }
      }
    end
    dictionary_array = []
    all_super_root.each{|id| dictionary_array.concat(option[:lexeme_class_name].constantize.find(id).dictionary_item.list)}
    return dictionary_array.uniq.sort
  end
  
  def find_below_meta_structure(option)
    array = [option[:inter_part]]
    option[:inter_part].sth_struct.split(',').map{|item| item.delete('-')}.each{|temp|
      if temp =~ /^meta_(\d+)$/
        new_meta = option[:class_name].constantize.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", option[:inter_part].sth_ref_id, $1.to_i])
        array.concat(find_below_meta_structure(:class_name=>option[:class_name], :inter_part=>new_meta))
      end
    }
    return array
  end

  def find_structure_indexes(option)
    create_index_array=[]
    update_index_array=[]
    option[:transite_index]="" if option[:transite_index].blank?
    option[:structure].each_with_index{|item, index|
      next if index == 0
      if is_string(item) == true
        if item =~ /^update_(.*)$/
          update_index_array << option[:transite_index]+'['+index.to_s+']'
        else
          next
        end
      end
      if item[0] =~ /^\d+$/
        create_index_array << option[:transite_index]+'['+index.to_s+']'
      elsif item[0] =~ /^update_(.*)$/
        update_index_array << option[:transite_index]+'['+index.to_s+']'
      end
      temp = find_structure_indexes(:structure=>item, :transite_index=>option[:transite_index]+'['+index.to_s+']')
      create_index_array.concat(temp[0])
      update_index_array.concat(temp[1])
    }
    return create_index_array, update_index_array
  end
  
  def get_structure_display_string(option)
    lexeme_class = verify_domain(option[:domain])['Lexeme']
    option[:top_level]="true" if option[:top_level].blank?
    char_string = []
    if is_string(option[:structure]) == true and option[:structure] =~ /^update_(.*)$/
      temp = $1
      return lexeme_class.constantize.find(temp.to_i).surface+'('+temp+')'+'  ==>  []'
    else
      option[:structure].each_with_index{|item, index|
        next if index == 0
        if is_string(item) == true
          if (item =~ /^meta_(.*)$/) or (item =~ /^initial_(.*)$/)
            char_string << $1+'()'
    elsif item =~ /^update_(.*)$/
      char_string << lexeme_class.constantize.find($1.to_i).surface+'('+$1+')'
          elsif item =~ /^dummy_(.*)$/
            char_string << $1+'(dummy)'
          else
            char_string << lexeme_class.constantize.find(item.to_i).surface+'('+item+')'
          end
        else
    if item[0] =~ /^meta_(.*)$/
      char_string << get_structure_display_string(:structure=>item, :domain=>option[:domain], :top_level=>"false")
    elsif item[0] =~ /^update_(.*)$/
      char_string << lexeme_class.constantize.find($1.to_i).surface+'('+$1+')'
    elsif item[0] =~ /^\d+$/
      char_string << lexeme_class.constantize.find(item[0].to_i).surface+'('+item[0]+')'
    end
        end
      }
      if option[:top_level]=="false"
        return '[ '+char_string.join(',   ')+' ]'
      else
        if option[:structure][0] =~ /^\d+$/
          root = lexeme_class.constantize.find(option[:structure][0].to_i).surface+'('+option[:structure][0]+')'
        elsif option[:structure][0] =~ /^update_(.*)$/
          id = $1
          root = lexeme_class.constantize.find(id.to_i).surface+'('+id+')'
        end
        return root+'  ===>  '+'[ '+char_string.join(',   ')+' ]'
      end
    end
  end

  def get_create_and_update_structures(option)
    create_indexes, update_indexes = find_structure_indexes(:structure=>option[:structure])
    create_array = []
    update_array = []
    create_indexes.each{|index_string| create_array << get_structure_display_string(:structure=>eval('option[:structure]'+index_string), :domain=>option[:domain])}
    update_indexes.each{|index_string| update_array << get_structure_display_string(:structure=>eval('option[:structure]'+index_string), :domain=>option[:domain])}
    return create_array, update_array
  end
  
  def swap_structure_array_and_string(string="", array=[], step=1)
    unless string.blank?
      string.split('*'+'+'*step+'*').each{|item|
        if item.include?('*')
          array << swap_structure_array_and_string(item, [], step+1)
        else
          array << item
        end
      }
      return array
    end
    unless array.blank?
      string = []
      for index in 0..array.size-1
        if is_string(array[index]) == true
          string << array[index]
        else
          string << swap_structure_array_and_string("", array[index], step+1)
        end
      end
      return string.join('*'+'+'*step+'*')
    end
  end
end
