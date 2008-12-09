require 'nkf'
STDOUT.sync = true

namespace :cradle do
  desc "load web lsd into database"
  task :load_jp_web_lsd => :environment
  task :load_jp_web_lsd, :filename do |task, args|
    ActiveRecord::Base.logger.silence do
      
      ### new dictionary file
      new_dictionary = String.new
      if File.exist?("#{RAILS_ROOT}/dumped_data/japanese/#{args[:filename]}")
        new_dictionary = "#{RAILS_ROOT}/dumped_data/japanese/#{args[:filename]}"
      elsif File.exist?(args[:filename])
        new_dictionary = args[:filename]
      else
        puts "Cannot find the input file!"
        return
      end
#          dictionary = {'name'=>'WebLSD', 'version'=>'200804'}
#          column = {
#                      "1"=>{'create'=>'old',  'type'=>'text', 'string'=>'surface'},
#                      "2"=>{'create'=>'new',  'type'=>'text', 'string'=>'nhg_code',   'name'=>'日本語コード'},
#                      "3"=>{'create'=>'new',  'type'=>'text', 'string'=>'jdsss_id',   'name'=>'自動参照先ID'},
#                      "4"=>{'create'=>'new',  'type'=>'text', 'string'=>'jdssshk',    'name'=>'自動参照先表記'},
#                      "5"=>{'create'=>'new',  'type'=>'text', 'string'=>'sgn_id',   'name'=>'親概念ID'},
#                      "6"=>{'create'=>'new',  'type'=>'text', 'string'=>'sgnnhghk',   'name'=>'親概念日本語表記'},
#                      "7"=>{'create'=>'new',  'type'=>'text', 'string'=>'sgneghk',    'name'=>'親概念英語表記'},
#                      "8"=>{'create'=>'new',  'type'=>'text', 'string'=>'ksnfks',   'name'=>'階層の深さ'},
#                      "9"=>{'create'=>'new',  'type'=>'text', 'string'=>'tree_bt',    'name'=>'ツリー番地'},
#                      "10"=>{'create'=>'new', 'type'=>'text', 'string'=>'tree_nhg',   'name'=>'ツリー日本語'},
#                      "11"=>{'create'=>'new', 'type'=>'text', 'string'=>'tree_eg',    'name'=>'ツリー英語'},
#                      "12"=>{'create'=>'old', 'type'=>'text', 'string'=>'reading'},
#                      "13"=>{'create'=>'new', 'type'=>'text', 'string'=>'tdsssnnhg_doce', 'name'=>'手動参照先の日本語コード'},
#                      "14"=>{'create'=>'new', 'type'=>'text', 'string'=>'tdsssnnhghk',  'name'=>'手動参照先の日本語表記'},
#                    }
      puts "STEP 1: Creating dictionary and new lexeme properties information"
      dictionary = {'name'=>'WebLSD', 'version'=>'200804'}
      text_feature_name = {1=>['nhg_code','日本語コード'],    2=>['jdsss_id','自動参照先ID'],    3=>['jdssshk','自動参照先表記'],   4=>['sgn_id','親概念ID'],
                           5=>['sgnnhghk','親概念日本語表記'], 6=>['sgneghk','親概念英語表記'],    7=>['ksnfks','階層の深さ'],       8=>['tree_bt','ツリー番地'],
                           9=>['tree_nhg','ツリー日本語'],    10=>['tree_eg','ツリー英語'],      12=>['tdsssnnhg_doce','手動参照先の日本語コード'],
                           13=>['tdsssnnhghk','手動参照先の日本語表記']}
      text_feature_id = {}
      
      ### Database actions
      original_max_lexeme = JpLexeme.maximum('id')
      original_max_lexeme = 0 if original_max_lexeme.blank?
      original_max_property = JpProperty.maximum('id')
      original_max_property = 0 if original_max_property.blank?
      original_max_new_property = JpNewProperty.maximum('id')
      original_max_new_property = 0 if original_max_new_property.blank?
      original_max_new_property_item = JpLexemeNewPropertyItem.maximum('id')
      original_max_new_property_item = 0 if original_max_new_property_item.blank?
      updated_lexeme_records = []

      count = 1
        
      begin
        ## create new dictionary item
        dict_id = '-'+JpProperty.save_property_tree("dictionary", [dictionary["name"], dictionary["version"]], JpProperty.find(:first, :conditions=>["property_string='dictionary'"]).seperator).property_cat_id.to_s+'-'

        ## create new lexeme property items
        text_feature_name.each{|key, value|
          temp = JpNewProperty.create!(:property_string=>value[0], :section=>'lexeme', :type_field=>'text', :human_name=>value[1])
          text_feature_id[key] = temp.id
        }

        #load file data into database
        puts "STEP 2: Loading all data list to database"
        tagging_state_new = JpProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
        odinary_pos = JpProperty.find_item_by_tree_string_or_array("pos", ['名詞','一般']).property_cat_id
        ordered_pos = []
        JpProperty.find_item_by_tree_string_or_array("pos", ['名詞','固有名詞']).children.each{|child| ordered_pos << child.property_cat_id}
        ordered_pos << JpProperty.find_item_by_tree_string_or_array("pos", ['名詞','形容動詞語幹']).property_cat_id
        ordered_pos << JpProperty.find_item_by_tree_string_or_array("pos", ['名詞','サ変接続']).property_cat_id
        ordered_pos << odinary_pos
        
        File.open(new_dictionary).each{|line|
          temp = line.chomp.split("\t")
          candidates = JpLexeme.find(:all, :conditions=>["surface=?", temp[0]])
          if candidates.blank?
            temp[11].blank? ? reading = "" : reading = NKF.nkf('-h2 --utf8', temp[11])
            new_id = JpLexeme.maximum('id')+1
            new_lexeme = JpLexeme.new(:surface=>temp[0], :reading=>reading, :base_id=>new_id, :pos=>odinary_pos,
                                      :dictionary=>dict_id, :tagging_state=>tagging_state_new, :created_by=>1)
            new_lexeme.id = new_id
            new_lexeme.save!
            new_lexeme_id = new_lexeme.id
          elsif candidates.size == 1
            updated_lexeme_records << candidates[0]
            new_dic_string = [candidates[0].dictionary, dict_id].sort.join(",")
            candidates[0].update_attributes!(:dictionary=>new_dic_string)
            new_lexeme_id = candidates[0].id
          elsif candidates.size > 1
            first_match = candidates.size
            position = ordered_pos.size
            for index in 0..candidates.size-1
              if ordered_pos.include?(candidates[index].pos)
                if ordered_pos.index(candidates[index].pos) < position
                  position = ordered_pos.index(candidates[index].pos) 
                  first_match = index
                end
              else
                next
              end
            end
            if first_match == candidates.size
              updated_lexeme_records << candidates[0]
              new_dic_string = [candidates[0].dictionary, dict_id].sort.join(",")
              candidates[0].update_attributes!(:dictionary=>new_dic_string)
              new_lexeme_id = candidates[0].id
            else
              updated_lexeme_records << candidates[first_match]
              new_dic_string = [candidates[first_match].dictionary, dict_id].sort.join(",")
              candidates[first_match].update_attributes!(:dictionary=>new_dic_string)
              new_lexeme_id = candidates[first_match].id
            end
          end
          
          text_feature_id.each{|col_num, property_id|
            unless temp[col_num].blank?
              JpLexemeNewPropertyItem.create!(:ref_id=>new_lexeme_id, :property_id=>property_id, :text=>temp[col_num])
            end
          }
          
          if count%1000 == 0
            print count/1000
            print "....."
          end
          count += 1
          
        }
      rescue Exception => e
        puts "###"+count.to_s+"###"
        if not JpProperty.maximum('id').blank? and JpProperty.maximum('id') > original_max_property
          ActiveRecord::Base.connection.execute("delete from jp_properties where id > #{original_max_property}")
        end
        if not JpNewProperty.maximum('id').blank? and JpNewProperty.maximum('id') > original_max_new_property
          ActiveRecord::Base.connection.execute("delete from jp_new_properties where id > #{original_max_new_property}")
        end
        if not JpLexemeNewPropertyItem.maximum('id').blank? and JpLexemeNewPropertyItem.maximum('id') > original_max_new_property_item
          ActiveRecord::Base.connection.execute("delete from jp_lexeme_new_property_items where id > #{original_max_new_property_item}")
        end
        if not JpLexeme.maximum('id').blank? and JpLexeme.maximum('id') > original_max_lexeme
          ActiveRecord::Base.connection.execute("delete from jp_lexemes where id > #{original_max_lexeme}")
        end
        unless updated_lexeme_records.blank?
          updated_lexeme_records.each{|original_lexeme| original_lexeme.save!}
        end
        puts e
      else
         puts "Finished"
      end
    end
  end
end