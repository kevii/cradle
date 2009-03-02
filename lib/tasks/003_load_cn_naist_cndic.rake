namespace :cradle do
  desc "analyze and load naist-cndic"
  task :load_cn_naist_cndic => :environment
  task :load_cn_naist_cndic, :filename do |task, args|
    config = {}
    ActiveRecord::Base.configurations.each{|key,value|
      if key == "chinese"
        config = value
        break
      end
    }
    ActiveRecord::Base.establish_connection(config)
    
    ActiveRecord::Base.logger.silence do
      ## extract the lexeme properties from input file ##
      ### format of old dumped file ###
      ### surface may be the same with different POS
      ### 0   			1
      ### surface  	POS
      old_dump_file = String.new
      if File.exist?("#{RAILS_ROOT}/dumped_data/chinese/#{args[:filename]}")
        old_dump_file = "#{RAILS_ROOT}/dumped_data/chinese/#{args[:filename]}"
      elsif File.exist?(args[:filename])
        old_dump_file = args[:filename]
      end
      
      if old_dump_file != ""
        puts "STEP 1: extracting the lexeme properties from input file #{old_dump_file}"
        parts_of_speech = Array.new
        File.open(old_dump_file).each{|line|
          temp = line.chomp.split("\t")
          parts_of_speech << temp[1] if temp[1] != "0" and temp[1] != "" and parts_of_speech.include?(temp[1]) == false
        }
        
        parts_of_speech = parts_of_speech.compact.sort
        
        ## verify if there are new properties ##
        puts "STEP 2: comparing the properties against initial lexeme properties"  
        error_msg = false

        ### parts_of_speech ###
        original_parts_of_speech = Hash.new
        CnProperty.find(:all, :conditions=>["property_string='pos' and property_cat_id>0"], :order=>"property_cat_id").each{|item|
          original_parts_of_speech[item.tree_string] = item.property_cat_id
        }
        parts_of_speech.each{|item|
          if original_parts_of_speech.key?(item) == false 
            puts "    ERROR: The POS #{item} does not exist in original POS list!"
            error_msg = true
          end
        }        
        
        if error_msg == true
          puts "There are new lexeme properties in input file #{old_dump_file}"
        else
          ## loading input dump file and initial lexeme properties into database
          puts "STEP 3: loading data into database"
          puts "    creating dictionary information"
          # insert dictionary property
          CnProperty.find(:all, :conditions=>["property_string='dictionary'"]).each{|item| item.destroy}
          dic = CnProperty.create!(:property_string=>"dictionary", :property_cat_id=>0, :parent_id=>nil,
                                      :seperator=>"-",      :value=>"NAIST-cndic")
          version = CnProperty.create!(:property_string=>"dictionary", :property_cat_id=>1, :parent_id=>dic.id,
                                       :seperator=>"-",      :value=>"2008")
            
          puts "    loading lexemes into table cn_lexemes"
            ActiveRecord::Base.connection.execute <<-"ENB"
              TRUNCATE TABLE cn_lexemes
            ENB
            new_tag = CnProperty.find_item_by_tree_string_or_array('tagging_state', 'NEW').property_cat_id
            File.open(old_dump_file).each{|line|
              temp = line.chomp.split("\t")
              case temp[0]
              when "\\" then temp[0] = "\\\\"
              when "\"\'\"" then temp[0] = "\\\'"
              when "\"\(\"" then temp[0] = "\\\("
              when "\"\)\"" then temp[0] = "\\\)"
							end

              ## pos
              original_parts_of_speech.key?(temp[1]) ? temp[1] = original_parts_of_speech[temp[1]] : temp[1] = "NULL"
              
              ActiveRecord::Base.connection.execute <<-"ENB"
                insert into cn_lexemes  ( id,
                                          surface,
                                          pos,
                                          dictionary,
                                          tagging_state,
                                          created_by )
                                  values( #{CnLexeme.maximum('id').to_i+1},
                                          convert("#{temp[0]}" using utf8),
                                          #{temp[1].to_i},
                                          '-1-',
                                          #{new_tag},
                                          1 )
              ENB
            }
        end
        puts "Finished"
      else
        puts "No such file or directory: #{args[:filename]}"
      end
    end
  end
end