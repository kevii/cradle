module SyntheticHelper
  include ApplicationHelper

  def show_internal_structure(option)
    option[:level] = 1 if option[:level].blank?
    option[:original_strcut] = option[:structure] if option[:original_strcut].blank?
    option[:section_indexes] = [] if option[:section_indexes].blank?
    html_string = ""
    option[:structure].each_with_index{|section,index|
      next if index == 0
      begin
        section.last
      rescue
        if verify_domain(option[:domain])['Synthetic'].constantize.exists?(:sth_ref_id=>section)
          html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
          html_string << verify_domain(option[:domain])['Lexeme'].constantize.find(section).surface+"\n"
          html_string << "</td>\n"
        else
          temp = verify_domain(option[:domain])['Lexeme'].constantize.find(section).surface.scan(/./)
          for inner_index in 0..temp.size-1
            html_string << "<td style='background:#F0F8FF;padding:5px 10px 5px 10px;color:#047;font-weight:bold;text-align:center;font-size:120%;'>\n"
            html_string << temp[inner_index]+"\n"
            html_string << "</td>\n"
            unless inner_index == temp.size-1
              html_string << "<td style='text-align:center;'>\n"
              left = temp[0..inner_index]
              right = temp[inner_index+1..-1]
              if option[:first_time]==true
                html_string << link_to_remote(image_tag("internal.jpg", :border=>0), :update=>"candidates", :url=>{:action=>"split_word",
                                                                                                                   :left=>left,
                                                                                                                   :right=>right,
                                                                                                                   :type=>"new",
                                                                                                                   :divide_type=>"vertical",
                                                                                                                   :structure=>option[:original_strcut],
                                                                                                                   :section_indexes=>(option[:section_indexes]<<index),
                                                                                                                   :original_id=>option[:original_id],
                                                                                                                   :from=>option[:from],
                                                                                                                   :domain=>option[:domain]})
              elsif option[:first_time]==false
                html_string << link_to_remote(image_tag("internal-horizontal.jpg", :border=>0), :update=>"candidates", :url=>{:action=>"split_word",
                                                                                                                              :left=>left,
                                                                                                                              :right=>right,
                                                                                                                              :type=>"new",
                                                                                                                              :divide_type=>"horizontal",
                                                                                                                              :structure=>option[:original_strcut],
                                                                                                                              :section_indexes=>(option[:section_indexes]<<index),
                                                                                                                              :original_id=>option[:original_id],
                                                                                                                              :from=>option[:from],
                                                                                                                              :domain=>option[:domain]})
                html_string << '<br/>'
                html_string << link_to_remote(image_tag("internal-vertical.jpg", :border=>0), :update=>"candidates", :url=>{:action=>"split_word",
                                                                                                                            :left=>left,
                                                                                                                            :right=>right,
                                                                                                                            :type=>"new",
                                                                                                                            :divide_type=>"vertical",
                                                                                                                            :structure=>option[:original_strcut],
                                                                                                                            :section_indexes=>(option[:section_indexes]<<index),
                                                                                                                            :original_id=>option[:original_id],
                                                                                                                            :from=>option[:from],
                                                                                                                            :domain=>option[:domain]})
              end
              html_string << "</td>\n"
            end
          end
        end
      else
        html_string << show_internal_structure(:structure=>section, :first_time=>false, :domain=>option[:domain], :level=>option[:level]+1, :from=>option[:from],
                                               :original_id=>option[:original_id], :original_strcut=>option[:original_strcut], :section_indexes=>option[:section_indexes])
      end
      unless index == option[:structure].size-1
        html_string << "<td style='text-align:center;vertical-align: middle;'>\n"
        left = get_chars_from_structure(section, option[:domain])
        right = get_chars_from_structure(option[:structure][index+1], option[:domain])
        html_string << link_to_remote(image_tag("internal-plus.jpg", :border=>0, :style=>"vertical-align: middle;"), :update=>"candidates", :url=>{:action=>"split_word", 
                                                                                                                                                   :left=>left,
                                                                                                                                                   :right=>right,
                                                                                                                                                   :type => "modify",
                                                                                                                                                   :structure=>option[:original_strcut],
                                                                                                                                                   :section_indexes=>(option[:section_indexes]<<index),
                                                                                                                                                   :original_id=>option[:original_id],
                                                                                                                                                   :from=>option[:from],
                                                                                                                                                   :domain=>option[:domain]})
        html_string << struct_level[level]+"\n"
        html_string << link_to_remote(image_tag("internal-minus.jpg", :border=>0, :style=>"vertical-align: middle;"), :url=>{:action=>"define_internal_structure",
                                                                                                                             :type => "delete",
                                                                                                                             :structure=>option[:original_strcut],
                                                                                                                             :section_indexes=>(option[:section_indexes]<<index),
                                                                                                                             :original_id=>option[:original_id],
                                                                                                                             :from=>option[:from],
                                                                                                                             :domain=>option[:domain]})
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
      begin
        item.last
      rescue
        char_string << lexeme_class.constantize.find(item).surface
      else
        char_string << get_showing_string(:structure=>item, :domain=>option[:domain])
      end
    }
    return '[  '+char_string.join(',')+'  ]'
  end
  
  private
  def get_chars_from_structure(section, domain)
    char_string = ""
    begin
      section.last
    rescue
      char_string << verify_domain(domain)['Lexeme'].constantize.find(section).surface
    else
      if section[0] =~ /^\d+$/
        char_string << verify_domain(domain)['Lexeme'].constantize.find(section[0]).surface
      else
        section[1..-1].each{|item| char_string << get_chars_from_structure(item, domain)}
      end
    end
    return char_string
  end
  
end
