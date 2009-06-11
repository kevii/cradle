STDOUT.sync = true

namespace :cradle do
  desc "load medical_name master v2.80 into database"
  task :load_jp_medical_master => :environment
  task :load_jp_medical_master, :filename do |task, args|
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
      

=begin
			###################################
			### check the existence   ######
			###################################

      puts "Checking existence of input words"
      exist_once = 0
      pos_exist_once = []
      exist_more = 0
      words_exist_more = []
      temp1 = 0
      temp2 = []
      temp3 = []
      temp4 = []
      
      File.open(new_dictionary){|file|
      	file.each{|line|
					temp = line.chomp.split("\t")
          candidates = JpLexeme.find(:all, :conditions=>["surface=? and reading=?", temp[0], temp[1]])
          if candidates.blank?
          	next
          elsif candidates.size == 1
          	exist_once += 1
          	pos = candidates[0].pos_item.tree_string
          	pos_exist_once << pos unless pos_exist_once.include?(pos)
          	case pos
          	when "名詞-一般"
          		temp1 += 1
          	when "名詞-サ変接続"
          		temp2 << temp[0]
          	when "名詞-形容動詞語幹"
          		temp3 << temp[0]
          	when "動詞-自立"
          		temp4 << temp[0]
          	end
          else
          	exist_more += 1
          	words_exist_more << temp[0]
          end
				}
			}      
  		puts "exist_once:  #{exist_once}"
  		puts pos_exist_once.join("\t")
  		puts "**********meishi********"
  		puts temp1
  		puts "**********sahen********"
  		puts temp2.size.to_s + "\t" + temp2.join("\t")
  		puts "**********keiyoudousi********"
  		puts temp3.size.to_s + "\t" + temp3.join("\t")
  		puts "**********jiritu********"
  		puts temp4.size.to_s + "\t" + temp4.join("\t")
  		puts "exist_more:  #{exist_more}"
  		puts words_exist_more.join("\n")
=end 

			def create_new_lexeme(option={})
        new_id = JpLexeme.maximum('id') + 1
        new_lexeme = JpLexeme.new(:surface => option[:surface], :reading => option[:reading], :base_id => new_id,
        													:pos => option[:pos], :dictionary => option[:dictionary],
        													:tagging_state => option[:tagging_state], :created_by => 1)
        new_lexeme.id = new_id
        new_lexeme.save!
        return new_lexeme.id
			end
			
			def update_lexeme(lexeme, dictionary)
				new_dic_string = [lexeme.dictionary.split(","), dictionary].flatten.sort.join(",")
				lexeme.update_attributes!(:dictionary=>new_dic_string)
				return lexeme.id
			end

			###################################
			### import dic to database   ######
			###################################
			begin
				tagging_state_for_new = JpProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
				dictionary = "-" + JpProperty.find_item_by_tree_string_or_array("dictionary", "標準病名マスター-V2.80*").property_cat_id.to_s + "-"
				ordinary_pos_for_noun = JpProperty.find_item_by_tree_string_or_array("pos", ['名詞','一般']).property_cat_id
				new_feature_id = JpNewProperty.find_by_property_string("ICD10").id
				
				
				id_for_rescue_new_lexemes = JpLexeme.maximum('id')
				array_for_rescue_updated_lexemes = []
				id_for_rescue_new_property_items = JpLexemeNewPropertyItem.maximum('id')
				
				File.open(new_dictionary){|file|
	      	file.each{|line|
						temp = line.chomp.split("\t")
	          candidates = JpLexeme.find(:all, :conditions=>["surface=? and reading=?", temp[0], temp[1]])
	          if candidates.blank?
	          	new_lexeme_id = create_new_lexeme(:surface => temp[0], :reading => temp[1], :pos => ordinary_pos_for_noun,
	          																		:dictionary => dictionary, :tagging_state => tagging_state_for_new)
    	      elsif candidates.size == 1
    	      	if ["名詞-一般",	"名詞-サ変接続",	"名詞-形容動詞語幹"].include?(candidates[0].pos_item.tree_string)
								array_for_rescue_updated_lexemes << candidates[0]
								new_lexeme_id = update_lexeme(candidates[0], dictionary)
		          elsif candidates[0].surface == "こわばり"
		          	new_lexeme_id = create_new_lexeme(:surface => temp[0], :reading => temp[1], :pos => ordinary_pos_for_noun,
		          																		:dictionary => dictionary, :tagging_state => tagging_state_for_new)
							end
    	      else
    	      	case temp[0]
    	      	when "よう", "やせ"
		          	new_lexeme_id = create_new_lexeme(:surface => temp[0], :reading => temp[1], :pos => ordinary_pos_for_noun,
		          																		:dictionary => dictionary, :tagging_state => tagging_state_for_new)
							when "歯ぎしり"
								lexeme = JpLexeme.find(108771)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "夜なき"
								lexeme = JpLexeme.find(1006358)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "かぜ"
								lexeme = JpLexeme.find(4418)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "せつ"
								lexeme = JpLexeme.find(2282884)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "あざ"
								lexeme = JpLexeme.find(1000008)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "のぼせ"
								lexeme = JpLexeme.find(2282885)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "ほてり"
								lexeme = JpLexeme.find(2282886)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "ふるえ"
								lexeme = JpLexeme.find(279660)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "激越"
								lexeme = JpLexeme.find(80490)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "落ち込み"
								lexeme = JpLexeme.find(233854)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
							when "ひきつけ"
								lexeme = JpLexeme.find(261828)
								array_for_rescue_updated_lexemes << lexeme
								new_lexeme_id = update_lexeme(lexeme, dictionary)
    	      	end
						end
            JpLexemeNewPropertyItem.create!(:ref_id=>new_lexeme_id, :property_id=>new_feature_id, :text=>temp[2])
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
          array_for_rescue_updated_lexemes.each{|original_lexeme| original_lexeme.save!}
        end
        puts e
      else
         puts "Finished"
      end  
    end
  end
end