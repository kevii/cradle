namespace :cradle do
  desc "analyze and load naist-jdic"
  task :load_jp_naist_jdic => :environment
  task :load_jp_naist_jdic, :filename do |task, args|
    ActiveRecord::Base.logger.silence do
      ## extract the lexeme properties from input file ##
      ### format of old dumped file ###
      ### 0   1         2        3        4              5     6    7      8      9    10       11             12
      ### ID  Category  Surface  Reading  Pronunciation  Base  POS  Ctype  Cform  Rid  Base_id  Comp_internal  Com_category ###
      old_dump_file = String.new
      if File.exist?("#{RAILS_ROOT}/dumped_data/japanese/#{args[:filename]}")
        old_dump_file = "#{RAILS_ROOT}/dumped_data/japanese/#{args[:filename]}"
      elsif File.exist?(args[:filename])
        old_dump_file = args[:filename]
      end
      
      if old_dump_file != ""
        puts "STEP 1: extracting the lexeme properties from input file #{old_dump_file}"
        tagging_states = Array.new
        parts_of_speech = Array.new
        ctypes = Array.new
        cforms = Array.new
        synthetic_tagging_states = Array.new
        lexeme_ids = Array.new
        File.open(old_dump_file).each{|line|
          temp = line.chomp.split("\t")
          tagging_states << temp[1] if temp[1] != "0" and temp[1] != "" and tagging_states.include?(temp[1]) == false
          parts_of_speech << temp[6] if temp[6] != "0" and temp[6] != "" and parts_of_speech.include?(temp[6]) == false
          ctypes << temp[7] if temp[7] != "0" and temp[7] != "" and ctypes.include?(temp[7]) == false
          cforms << temp[8] if temp[8] != "0" and temp[8] != "" and cforms.include?(temp[8]) == false
          synthetic_tagging_states << temp[12] if temp[12] != "0" and temp[12] != "" and synthetic_tagging_states.include?(temp[12]) == false        
          lexeme_ids[temp[0].to_i] = 1
        }
        
        tagging_states.delete("NOTIMPORT")
        tagging_states.delete("NOTIMPORT-CONJ")
        tagging_states = tagging_states.compact.sort
        ## input file problem ##
        parts_of_speech.delete("副詞-")     # 3 in 2008-07-07
        parts_of_speech.delete("副詞-形容動詞語幹")  # 1 in 2008-07-07
        parts_of_speech.delete("名詞-副詞可能j")  # 1 in 2008-07-07
        #############################################
        parts_of_speech = parts_of_speech.compact.sort
        ## input file problem ##
        ctypes.delete("五段") # 2 in 2008-07-07
        ##############################################
        ctypes = ctypes.compact.sort
        cforms = cforms.compact.sort
        synthetic_tagging_states = synthetic_tagging_states.compact.sort
        
        
        
        ## verify if there are new properties ##
        puts "STEP 2: comparing the properties against initial lexeme properties"  
        error_msg = false
        ### category ###
        original_tagging_states = Hash.new
        JpProperty.find(:all, :conditions=>["property_string='tagging_state' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_tagging_states[item.tree_string] = item.property_cat_id
        }

        tagging_states.each{|item|
          if original_tagging_states.key?(item) == false 
            puts "    ERROR: The category #{item} does not exist in original category list!"
            error_msg = true
          end
        }
        ### parts_of_speech ###
        original_parts_of_speech = Hash.new
        JpProperty.find(:all, :conditions=>["property_string='pos' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_parts_of_speech[item.tree_string] = item.property_cat_id
        }
        parts_of_speech.each{|item|
          if original_parts_of_speech.key?(item) == false 
            puts "    ERROR: The POS #{item} does not exist in original POS list!"
            error_msg = true
          end
        }        
        ### ctypes ###
        original_ctypes = Hash.new
        JpProperty.find(:all, :conditions=>["property_string='ctype' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_ctypes[item.tree_string] = item.property_cat_id
        }
        ctypes.each{|item|
          if original_ctypes.key?(item) == false 
            puts "    ERROR: The ctype #{item} does not exist in original ctype list!"
            error_msg = true
          end
        }
        ### cforms ###
        original_cforms = Hash.new
        JpProperty.find(:all, :conditions=>["property_string='cform' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_cforms[item.tree_string] = item.property_cat_id
        }
        cforms.each{|item|
          if original_cforms.key?(item) == false 
            puts "    ERROR: The cform #{item} does not exist in original cform list!"
            error_msg = true
          end
        }
        ### synthetic_tagging_states ###
        original_synthetic_tagging_states = Hash.new
        JpProperty.find(:all, :conditions=>["property_string='sth_tagging_state' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_synthetic_tagging_states[item.tree_string] = item.property_cat_id
        }
        synthetic_tagging_states.each{|item|
          if original_synthetic_tagging_states.key?(item) == false 
            puts "    ERROR: The synthetic_tagging_states #{item} does not exist in original synthetic_tagging_states list!"
            error_msg = true
          end
        }
        ### base_id and synthetic_struct ###
        problem_id = Array.new
        problem_lexeme_ids = Array.new
        File.open(old_dump_file).each{|line|
          temp = line.chomp.split("\t")
          if temp[10] != "0" and temp[0] != temp[10]
            if lexeme_ids[temp[10].to_i] == nil
              puts "    ERROR:The base value #{temp[10]} does not equal to any lexeme id of input file!"
            end
          end
          if temp[11] != "0" and temp[11] != nil and temp[11] != ""
            ## input file problem ##
# 2008-03-18
#            problem_id =[2270,12602,13116,13941,19898,29947,30706,37549,42523,42568,42716,55809,91955,96978,120224,191110,195478,203599,222989,223685,223686,245410,247612,247865,247866,249879,251407,256897,260683,260901,249194,2141687,2193031,2193138,2193425,2194803,2195147,2196655]
# 2008-07-07
            problem_id =[2270,12602,13116,13941,19898,29947,30706,37549,42523,42568,42716,55809,91955,96978,120224,191110,195478,203599,222989,223685,223686,245410,247612,247865,247866,249879,251407,256897,260683,260901,249194,2141687,2193031,2193138,2193425,2195147]
            ###################################################
            temp[11].split(",").each{|item|
              if problem_id.include?(item.to_i)
                problem_lexeme_ids << temp[0]
                next 
              end
              if lexeme_ids[item.to_i] == nil
                puts "    ERROR:The synthetic_struct value #{item} in #{temp[11]} does not equal to any lexeme id of input file!"
                error_msg = true
              end
            }
          end
        }
        
        if error_msg == true
          puts "There are new lexeme properties in input file #{old_dump_file}"
        else
          ## loading input dump file and initial lexeme properties into database
          puts "STEP 3: loading data into database"
          puts "    creating dictionary information"
          # insert dictionary property
          JpProperty.find(:all, :conditions=>["property_string='dictionary'"]).each{|item| item.destroy}
          dic = JpProperty.create!(:property_string=>"dictionary", :property_cat_id=>0, :parent_id=>nil,
                                      :seperator=>"-",      :value=>"NAIST-jdic")
          version = JpProperty.create!(:property_string=>"dictionary", :property_cat_id=>1, :parent_id=>dic.id,
                                       :seperator=>"-",      :value=>"20080707")
            
          puts "    loading lexemes into table jp_lexemes, jp_synthetics"
            ActiveRecord::Base.connection.execute <<-"ENB"
              TRUNCATE TABLE jp_synthetics
            ENB
            ActiveRecord::Base.connection.execute <<-"ENB"
              TRUNCATE TABLE jp_lexemes
            ENB
            File.open(old_dump_file).each{|line|
              temp = line.chomp.split("\t")
              if temp[2] == "\\"
                temp[2] = "\\\\"
                temp[3] = "\\\\"
                temp[4] = "\\\\"
              end
              if temp[2] == "\"\'\""
                temp[2] = "\\\'"
                temp[3] = "\\\'"
                temp[4] = "\\\'"
              end
              if temp[2] == "\"\(\""
                temp[2] = "\\\("
                temp[3] = "\\\("
                temp[4] = "\\\("
              end
              if temp[2] == "\"\)\""
                temp[2] = "\\\)"
                temp[3] = "\\\)"
                temp[4] = "\\\)"
              end
              ##  tagging_state not null
              if original_tagging_states.key?(temp[1])
                temp[1] = original_tagging_states[temp[1]]
              elsif ["NOTIMPORT", "NOTIMPORT-CONJ", ""].include?(temp[1])
                next
              else
                puts "tagging_state error: ***#{temp[1]}***   surface: #{temp[2]}"
                return
              end
              ## pos
              if original_parts_of_speech.key?(temp[6])
                temp[6] = original_parts_of_speech[temp[6]]
              else
                temp[6] = "NULL"
              end
              ## ctpye
              if original_ctypes.key?(temp[7])
                temp[7] = original_ctypes[temp[7]]
              else
                temp[7] = "NULL"
              end
              ## cform
              if original_cforms.key?(temp[8])
                temp[8] = original_cforms[temp[8]]
              else
                temp[8] = "NULL"
              end
              ## root_id
              if temp[9] == "" or temp[9] == nil or temp[9] == "0"
                temp[9] = "NULL"
              else
                temp[9] = "R"+temp[9]
              end

              ## base_id not null
              temp[10] = 0 if temp[10] == "" or temp[10] == nil
              
              ActiveRecord::Base.connection.execute <<-"ENB"
                insert into jp_lexemes  ( id,
                                          surface,
                                          reading,
                                          pronunciation,
                                          base_id,
                                          root_id,
                                          pos,
                                          ctype,
                                          cform,
                                          dictionary,
                                          tagging_state,
                                          created_by )
                                  values( #{temp[0].to_i},
                                          convert("#{temp[2]}" using utf8),
                                          convert("#{temp[3]}" using utf8),
                                          convert("#{temp[4]}" using utf8),
                                          #{temp[10].to_i},
                                          #{temp[9]=="NULL" ? "NULL" : "convert('#{temp[9]}' using utf8)"},
                                          #{temp[6]},
                                          #{temp[7]},
                                          #{temp[8]},
                                          1,
                                          #{temp[1]},
                                          1 )
              ENB

              ## internal struct
              unless temp[11] == "" or temp[11] == nil
                unless problem_lexeme_ids.include?(temp[0]) == true
                  ## internal struct tagging state not null
                  if original_synthetic_tagging_states.key?(temp[12])
                    temp[12] = original_synthetic_tagging_states[temp[12]]
                  else
                    puts "sth_tagging_state error"
                    return
                  end
                  ActiveRecord::Base.connection.execute <<-"ENB"
                    insert into jp_synthetics  ( sth_ref_id,
                                                 sth_meta_id,
                                                 sth_struct,
                                                 sth_tagging_state,
                                                 modified_by )
                                         values( #{temp[0].to_i},
                                                 0,
                                                 convert("#{temp[11]}" using utf8),
                                                 #{temp[12]},
                                                 1 )
                  ENB
                end
              end
            }
        end
        puts "Finished"
      else
        puts "No such file or directory: #{args[:filename]}"
      end
    end
  end
end