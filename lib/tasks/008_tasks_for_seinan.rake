STDOUT.sync = true

namespace :seinan do
# 0 表層形     hyousoukei
# 1 左連接状態番号  hidarirenzoku
# 2 右連接状態番号  migirenzoku
# 3 コスト      comecost
# 4 品詞　１    pos
# 5 品詞　２
# 6 品詞　３
# 7 品詞　４
# 8 品詞　５    null
# 9 品詞　６    null
# 10 用語      surface
# 11 フリガナ   reading
# 12 ヨミガナ   pronunciation
# 13 N-jdic予備　1   null
# 14 N-jdic予備　2   null
# 15 N-jdic予備　3   null
# 16 場面　１   scene1
# 17 場面　２   scene2
# 18 場面　３   scene3
# 19 場面　４   scene4
# 20 場面　５   scene5
# 21 表層語数   hyousougosu
# 22 フリガナ語数  furiganagosu
# 23 連番     renban
# 	


# E型肝炎,-1,-1,996,名詞,一般,*,*,*,*,E型肝炎,イーガタカンエン,イーガタカンエン,,,,*,edu,*,etc,ns,2,5,401
# II型アレルギー,-1,-1,992,名詞,一般,*,*,*,*,II型アレルギー,ニガタアレルギー,ニガタアレルギー,,,,clinic,*,*,etc,ns,11,11,586
# α‐リノレン酸,-1,-1,993,名詞,一般,*,*,*,*,α‐リノレン酸,アルファーリノレンサン,アルファーリノレンサン,,,,*,edu,*,etc,ns,17,21,1179
# アトピー性皮膚炎,-1,-1,992,名詞,一般,*,*,*,*,アトピー性皮膚炎,アトピーセイヒフエン,アトピーセイヒフエン,,,,*,edu,*,etc,ns,4,6,1448
# アレルギー,-1,-1,995,名詞,一般,*,*,*,*,アレルギー,アレルギー,アレルギー,,,,clinic,edu,*,*,ns,8,8,1741
# アレルゲン,-1,-1,995,名詞,一般,*,*,*,*,アレルゲン,アレルゲン,アレルゲン,,,,clinic,*,*,etc,ns,10,10,1777
# リザーバーバッグ,-1,-1,992,名詞,一般,*,*,*,*,リザーバーバッグ,リザーバーバッグ,リザーバーバッグ,,,,*,edu,*,etc,ns,6,8,8174
# 癌性疼痛,-1,-1,996,名詞,一般,*,*,*,*,癌性疼痛,ガンセイトウツウ,ガンセイトーツー,,,,*,edu,*,etc,ns,11,16,12178  
# 減塩,-1,-1,998,名詞,サ変接続,*,*,*,*,減塩,ゲンエン,ゲンエン,,,,*,edu,*,etc,ns,8,16,15311
# 口蓋裂,-1,-1,997,名詞,一般,*,*,*,*,口蓋裂,コウガイレツ,コーガイレツ,,,,*,*,*,etc,ns,7,12,15823
# 高血圧症,-1,-1,996,名詞,一般,*,*,*,*,高血圧症,コウケツアツショウ,コーケツアツショー,,,,*,edu,*,etc,ns,6,9,16485




  desc "import seinan data"
  task :import_seinan_data, :file_path, :needs => :environment do |t, args|
		def create_new_lexeme(option={})
      new_id = JpLexeme.maximum('id') + 1
      new_lexeme = JpLexeme.new(option.update(:base_id => new_id, :created_by => 1))
      new_lexeme.id = new_id
      new_lexeme.save!
      return new_lexeme.id
		end

		def update_lexeme(lexeme, dictionary)
			new_dic_string = [lexeme.dictionary.split(","), dictionary].flatten.uniq.sort.join(",")
			lexeme.update_attributes!(:dictionary=>new_dic_string)
			return lexeme.id
		end
  
  	ActiveRecord::Base.logger.silence do
			id_for_rescue_new_lexemes = JpLexeme.maximum('id') || 0
			array_for_rescue_updated_lexemes = []
			id_for_rescue_new_property_items = JpLexemeNewPropertyItem.maximum('id') || 0
			current_word = ''
			pos_cache = {}
  	
  		begin
  			tagging_state_for_new = JpProperty.find_item_by_tree_string_or_array("tagging_state", "NEW").property_cat_id
				dictionary_id = "-" + JpProperty.find_item_by_tree_string_or_array("dictionary", "ComeJisyoV20123s*").property_cat_id.to_s + "-"
				new_property_id_hash = {
					0 => JpNewProperty.find_by_property_string('hyousoukei').id,
					1 => JpNewProperty.find_by_property_string('hidarirenzoku').id,
					2 => JpNewProperty.find_by_property_string('migirenzoku').id,
					3 => JpNewProperty.find_by_property_string('comecost').id,
					16 => JpNewProperty.find_by_property_string('scene1').id,
					17 => JpNewProperty.find_by_property_string('scene2').id,
					18 => JpNewProperty.find_by_property_string('scene3').id,
					19 => JpNewProperty.find_by_property_string('scene4').id,
					20 => JpNewProperty.find_by_property_string('scene5').id,
					21 => JpNewProperty.find_by_property_string('hyousougosu').id,
					22 => JpNewProperty.find_by_property_string('furiganagosu').id,
					23 => JpNewProperty.find_by_property_string('renban').id
				}

				
	  		File.open(args[:file_path]).each do |line|
	      	temp = line.chomp.split(",")
	      	current_word = temp[10]
	      	pos_array = temp[4..9].select{|x| x != '*'}
	      	pos_id = if pos_array.blank? then nil
	      	elsif not pos_cache[pos_array.join('-')].blank? then pos_cache[pos_array.join('-')]
	      	else
	      		JpProperty.find_item_by_tree_string_or_array("pos", pos_array).property_cat_id
	      	end
	      	pos_cache[pos_array.join('-')] = pos_id
					candidates = JpLexeme.find(:all, :conditions=>{:surface => temp[10], :pos => pos_id}, :order => 'id asc')
          if candidates.blank?
          	new_lexeme_id = create_new_lexeme(:surface => temp[10],
          																		:reading => temp[11],
          																		:pronunciation => temp[12],
          																		:pos => pos_id,
          																		:dictionary => dictionary_id,
          																		:tagging_state => tagging_state_for_new)
          else
          	found_same = false
          	break_word = false
          	candidates.each do |candi_lexeme|
          		if found_same == false and candi_lexeme.surface == temp[1]
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
	          	new_lexeme_id = create_new_lexeme(:surface => temp[10],
	          																		:reading => temp[11],
	          																		:pronunciation => temp[12],
	          																		:pos => pos_id,
	          																		:dictionary => dictionary_id,
	          																		:tagging_state => tagging_state_for_new)
	          end
          end
        	new_property_id_hash.each do |key, value|
        		JpLexemeNewPropertyItem.create!(:ref_id => new_lexeme_id, :property_id => value, :text => temp[key])
        	end
      	end
      rescue Exception => e
        if (temp = JpLexemeNewPropertyItem.maximum('id')) and (temp > id_for_rescue_new_property_items)
          ActiveRecord::Base.connection.execute("delete from jp_lexeme_new_property_items where id > #{id_for_rescue_new_property_items}")
        end
        if JpLexeme.maximum('id') > id_for_rescue_new_lexemes
          ActiveRecord::Base.connection.execute("delete from jp_lexemes where id > #{id_for_rescue_new_lexemes}")
        end
        unless array_for_rescue_updated_lexemes.blank?
          array_for_rescue_updated_lexemes.each{|item| JpLexeme.find(item[0]).update_attributes!(:dictionary => item[1])}
        end
        puts e
        puts current_word
      else
        puts "Finished"
  		end
  	end
	end
end