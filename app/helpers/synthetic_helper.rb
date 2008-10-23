module SyntheticHelper
  include ApplicationHelper

  def show_internal_structure(option)
    option[:original_strcut] = swap_structure_array_and_string("", option[:structure].dup) if option[:original_strcut].blank?
    option[:section_indexes] = "" if option[:section_indexes].blank?
    html_string = ""
    option[:structure].each_with_index{|section,index|
      next if index == 0
      if is_string(section) == true
        if section =~ /^\d+$/ and
           (verify_domain(option[:info][:domain])['Synthetic'].constantize.exists?(:sth_ref_id=>section.to_i) or
           verify_domain(option[:info][:domain])['Lexeme'].constantize.find(section.to_i).tagging_state_item.tree_string == 'DUMMY')
          html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
          html_string << verify_domain(option[:info][:domain])['Lexeme'].constantize.find(section).surface+"\n"
          html_string << "</td>\n"
        elsif section =~ /^dummy_(.*)$/
          html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
          html_string << $1+"\n"
          html_string << "</td>\n"
        else
          ((section =~ /^meta_(.*)$/) or (section =~ /^initial_(.*)$/)) ? temp = $1.scan(/./) : temp = verify_domain(option[:info][:domain])['Lexeme'].constantize.find(section.to_i).surface.scan(/./)
          split_action = {:type=>"new", :point=>option[:section_indexes]+'['+index.to_s+']'}
          for inner_index in 0..temp.size-1
            html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
            html_string << temp[inner_index]+"\n"
            html_string << "</td>\n"
            unless inner_index == temp.size-1
              html_string << "<td style='text-align:center;'>\n"
              left = temp[0..inner_index].join('')
              right = temp[inner_index+1..-1].join('')
              if option[:first_time]==true
                html_string << link_to_remote(image_tag("internal.jpg", :border=>0), :url=>{:action=>"split_word", :left=>left,
                                                                                            :right=>right,         :split_action=>split_action.update(:divide_type=>"horizontal"),
                                                                                            :info=>option[:info],  :structure=>option[:original_strcut]})
              elsif option[:first_time]==false
                html_string << link_to_remote(image_tag("internal-horizontal.jpg", :border=>0), :url=>{:action=>"split_word", :left=>left,
                                                                                                       :right=>right,         :split_action=>split_action.update(:divide_type=>"horizontal"),
                                                                                                       :info=>option[:info],  :structure=>option[:original_strcut]})
                html_string << '<br/>'
                html_string << link_to_remote(image_tag("internal-vertical.jpg", :border=>0), :url=>{:action=>"split_word", :left=>left,
                                                                                                     :right=>right,         :split_action=>split_action.update(:divide_type=>"vertical"),
                                                                                                     :info=>option[:info],  :structure=>option[:original_strcut]})
              end
              html_string << "</td>\n"
            end
          end
        end
      else
        html_string << show_internal_structure(:structure=>section, :first_time=>false, :info=>option[:info], :original_strcut=>option[:original_strcut],
                                               :section_indexes=>option[:section_indexes]+'['+index.to_s+']')
      end
      unless index == option[:structure].size-1
        html_string << "<td style='text-align:center;vertical-align: middle;'>\n"
        left = get_chars_from_structure(section, option[:info][:domain])
        right = get_chars_from_structure(option[:structure][index+1], option[:info][:domain])
        option[:structure].size > 3 ? divide_type = "horizontal" : divide_type = "vertical"
        html_string << link_to_remote(image_tag("internal-plus.jpg", :border=>0, :style=>"vertical-align: middle;"),
                                      :url=>{:action=>"split_word", :structure=>option[:original_strcut],
                                      :left=>left,                  :right=>right,
                                      :info=>option[:info],         :split_action=>{:type=>"modify", :divide_type=>divide_type,
                                                                                    :left_hand_index=>(option[:section_indexes]+'['+index.to_s+']'),
                                                                                    :right_hand_index=>(option[:section_indexes]+'['+(index+1).to_s+']')}})
        html_string << struct_level[option[:section_indexes].blank? ? 1 : option[:section_indexes].count('[')+1]+"\n"
        if divide_type == "horizontal"
          if index == option[:structure].size-2
            right = left+right
            left = get_chars_from_structure(option[:structure][index-1], option[:info][:domain])
            left_hand_index = option[:section_indexes]+'['+(index-1).to_s+']'
            right_hand_index = option[:section_indexes]+'['+index.to_s+'..-1]'
          else
            left = left+right
            right = get_chars_from_structure(option[:structure][index+2], option[:info][:domain])
            left_hand_index = option[:section_indexes]+'['+index.to_s+'..'+(index+1).to_s+']'
            right_hand_index = option[:section_indexes]+'['+(index+2).to_s+']'
          end
          split_action = {:type=>"delete", :divide_type=>divide_type, :left_hand_index=>left_hand_index, :right_hand_index=>right_hand_index}
          html_string << link_to_remote(image_tag("internal-minus.jpg", :border=>0, :style=>"vertical-align: middle;"), :url=>{:action=>"split_word", :structure=>option[:original_strcut],
                                                                                                                               :info=>option[:info],  :split_action=>split_action,
                                                                                                                               :left=>left,           :right=>right})          
        elsif divide_type == "vertical"
          html_string << link_to_remote(image_tag("internal-minus.jpg", :border=>0, :style=>"vertical-align: middle;"),
                                        :url=>{:action=>"define_internal_structure", :structure=>option[:original_strcut],
                                               :info=>option[:info],                 :split_action=>{:type=>"delete", :divide_type=>divide_type, :point=>option[:section_indexes]}})
        end
        html_string << "</td>\n"
      end
    }
    return html_string
  end
  
  def get_showing_string(option)
    lexeme_class = verify_domain(option[:domain])['Lexeme']
    char_string = []
    option[:structure].each_with_index{|item, index|
      next if index == 0
      if is_string(item) == true
        if (item =~ /^meta_(.*)$/) or (item =~ /^initial_(.*)$/)
          char_string << $1+'()'
        elsif item =~ /^dummy_(.*)$/
          char_string << $1+'(dummy)'
        else
          char_string << lexeme_class.constantize.find(item.to_i).surface+'('+item+')'
        end
      else
        char_string << get_showing_string(:structure=>item, :domain=>option[:domain])
      end
    }
    return '[  '+char_string.join(',')+'  ]'
  end
  
  private
  def get_chars_from_structure(section, domain)
    char_string = ""
    if is_string(section) == true
      if section =~ /^\d+$/
        char_string << verify_domain(domain)['Lexeme'].constantize.find(section).surface
      elsif section =~ /^dummy_(.*)$/
        char_string << $1
      end
    else
      if section[0] =~ /^\d+$/
        char_string << verify_domain(domain)['Lexeme'].constantize.find(section[0]).surface
      else
        section[1..-1].each{|item| char_string << get_chars_from_structure(item, domain)}
      end
    end
    return char_string
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
      for index in 0..array.size-1
        array[index] = swap_structure_array_and_string("", array[index], step+1) if is_string(array[index]) == false
      end
      return array.join('*'+'+'*step+'*')
    end
  end
end
