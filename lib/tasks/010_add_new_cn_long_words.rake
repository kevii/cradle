STDOUT.sync = true

namespace :cradle do
  desc "add cn long words which have more than 4 chars"
  task :add_cn_long_words => :environment do
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
      new_tag = CnProperty.find_item_by_tree_string_or_array('tagging_state', 'NEW').property_cat_id
      noun_pos = CnProperty.find_item_by_tree_string_or_array('pos', 'NN').property_cat_id
      5.upto(8) do |num|
      	File.read("#{RAILS_ROOT}/tmp/200_normal_#{num}_chars.txt").split("\n").each do |word|
          ActiveRecord::Base.connection.execute <<-"ENB"
            insert into cn_lexemes  ( id,
                                      surface,
                                      pos,
                                      dictionary,
                                      tagging_state,
                                      created_by )
                              values( #{CnLexeme.maximum('id').to_i+1},
                                      '#{word}',
                                      #{noun_pos},
                                      '-1-',
                                      #{new_tag},
                                      1 )
          ENB
      	end
      end
    end
  end
end