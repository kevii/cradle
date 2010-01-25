STDOUT.sync = true

namespace :cradle do
  desc "add jp techterm Dic into database"
  task :load_jp_techterm => :environment
  task :load_jp_techterm, :filename do |task, args|
    ActiveRecord::Base.logger.silence do

			dictionary = "#{RAILS_ROOT}/dumped_data/japanese/techterm.freq.tab"

			def create_new_lexeme(option={})
        new_id = JpLexeme.maximum('id') + 1
        new_lexeme = JpLexeme.new(:surface => option[:surface],
        													:base_id => new_id,
        													:dictionary => option[:dictionary],
        													:tagging_state => option[:tagging_state],
        													:created_by => 1)
        new_lexeme.id = new_id
        new_lexeme.save!
        return new_lexeme.id
			end
			
			def update_lexeme(lexeme, dictionary)
				new_dic_string = [lexeme.dictionary.split(","), dictionary].flatten.uniq.sort.join(",")
				lexeme.update_attributes!(:dictionary=>new_dic_string)
				return lexeme.id
			end

			###################################
			### import dic to database   ######
			###################################
			id_for_rescue_new_lexemes = JpLexeme.maximum('id')
			array_for_rescue_updated_lexemes = []
			id_for_rescue_new_property_items = JpLexemeNewPropertyItem.maximum('id')
			
			current_item = nil
			
			begin
				tagging_state_for_new = JpProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
				dictionary_id = "-" + JpProperty.find_item_by_tree_string_or_array("dictionary", "techterm*").property_cat_id.to_s + "-"

				fre_feature_id = JpNewProperty.find_by_human_name("頻度（文数）").id
				certainty_feature_id = JpNewProperty.find_by_human_name("確信度").id

				File.open(dictionary){|file|
	      	file.each{|line|
						temp = line.chomp.split("\t")
						
						current_item = temp[2]
						
	          candidates = JpLexeme.find(:all, :conditions=>["surface=?", temp[2]], :order => 'id asc')
	          new_lexeme_id = nil
	          if candidates.blank?
	          	new_lexeme_id = create_new_lexeme(:surface => temp[2], 	          																		
	          																		:dictionary => dictionary_id,
	          																		:tagging_state => tagging_state_for_new)
	          	current_item << "  create"
	          else
	          	found_same = false
	          	break_word = false
	          	candidates.each do |candi_lexeme|
	          		if found_same == false and candi_lexeme.surface == temp[2]
	          			if candi_lexeme.dictionary =~ /#{dictionary_id}/
	          				break_word = true
	          			else
		          			array_for_rescue_updated_lexemes << [candi_lexeme.id, candi_lexeme.dictionary]
			          		new_lexeme_id = update_lexeme(candi_lexeme, dictionary_id)
			          		found_same = true
			          	end
									break
		          	else next end
		          end
		          if break_word == true
		          	puts line
		          	next
		          end
		          if found_same == false
		          	new_lexeme_id = create_new_lexeme(:surface => temp[2], 	          																		
		          																		:dictionary => dictionary_id,
		          																		:tagging_state => tagging_state_for_new)
		          end
		          current_item << "  update"
	          end
						current_item << "  create freq #{new_lexeme_id} #{fre_feature_id} #{certainty_feature_id} #{temp[0]} #{temp[1]}"
            JpLexemeNewPropertyItem.create!(:ref_id => new_lexeme_id, :property_id => fre_feature_id, :text => temp[0])

            current_item << "  create centainty #{new_lexeme_id} #{fre_feature_id} #{certainty_feature_id} #{temp[0]} #{temp[1]}"
            JpLexemeNewPropertyItem.create!(:ref_id => new_lexeme_id, :property_id => certainty_feature_id, :text => temp[1])
          }
        }
      rescue Exception => e
        if JpLexemeNewPropertyItem.maximum('id') > id_for_rescue_new_property_items
          ActiveRecord::Base.connection.execute("delete from jp_lexeme_new_property_items where id > #{id_for_rescue_new_property_items}")
        end
        if JpLexeme.maximum('id') > id_for_rescue_new_lexemes
          ActiveRecord::Base.connection.execute("delete from jp_lexemes where id > #{id_for_rescue_new_lexemes}")
        end
        unless array_for_rescue_updated_lexemes.blank?
          array_for_rescue_updated_lexemes.each{|item| JpLexeme.find(item[0]).update_attributes!(:dictionary => item[1])}
        end
        puts e
        puts current_item
      else
         puts "Finished"
      end
    end
  end
end