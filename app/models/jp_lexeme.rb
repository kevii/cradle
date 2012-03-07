class JpLexeme < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_lexemes"

  ######################################################
  ##### table refenrence
  ######################################################
  has_one	:struct, :class_name=>"JpSynthetic", :foreign_key=>"sth_ref_id", :conditions=>"sth_meta_id=0"

  has_many :same_base_lexemes,	:class_name=>"JpLexeme",								:foreign_key=>"base_id"
  has_many :sub_structs,				:class_name=>"JpSynthetic",							:foreign_key=>"sth_ref_id",	:dependent=>:destroy
  has_many :dynamic_properties, :class_name=>"JpLexemeNewPropertyItem",	:foreign_key=>"ref_id",			:dependent=>:destroy
  has_many :dynamic_struct_properties, :through=>:sub_structs, :source=>:other_properties

  # tanslations between different languages
  # has_many :jp_to_cns, :foreign_key=>"jp_id", :dependent=>:destroy
  # has_many :to_cn, :through=>:jp_to_cns, :source=>:cn

  has_many :senses, :class_name=>"JpLexemeSense", :foreign_key=>"jp_lexeme_ref_id", :dependent=>:destroy

  # has_many :cn_to_jps, :class_name => "CnToJp", :foreign_key => :jp_id, :dependent => :destroy


  belongs_to :base,				:class_name=>"JpLexeme",	:foreign_key=>"base_id"
  belongs_to :creator,		:class_name=>"User",			:foreign_key=>"created_by"
  belongs_to :annotator,	:class_name=>"User",			:foreign_key=>"modified_by"

  def root
    if self.root_id =~ /^R/ then return nil
    else return JpLexeme.find(self.root_id.to_i) end
  end

  def create_sense!(text)
    senses.create!(:text => text)
  end

  def destroy_sense!(jpsense)
    senses.find_by_jp_lexeme_ref_id(jpsense).destroy
  end



#  def if_trans_to_cn?(cnlexeme)
#    jp_to_cns.find_by_cn_id(cnlexeme)
#  end

#  def create_trans_to_cn!(cnlexeme)
#    jp_to_cns.create!(:cn_id => cnlexeme.id)
#  end

#  def destroy_trans_to_cn!(cnlexeme)
#    jp_to_cns.find_by_cn_id(cnlexeme).destroy
#  end

  def same_root_lexemes
    if self.root_id.blank? then return nil
    else return JpLexeme.find(:all, :conditions=>["root_id=?", self.root_id], :order=>"id ASC") end
  end

  def pos_item
    JpProperty.find(:first, :conditions=>["property_string='pos' and property_cat_id=?", self.pos])
  end

  def ctype_item
    JpProperty.find(:first, :conditions=>["property_string='ctype' and property_cat_id=?", self.ctype])
  end

  def cform_item
    JpProperty.find(:first, :conditions=>["property_string='cform' and property_cat_id=?", self.cform])
  end

  def tagging_state_item
    JpProperty.find(:first, :conditions=>["property_string='tagging_state' and property_cat_id=?", self.tagging_state])
  end

  composed_of :dictionary_item, :class_name => "DictionaryItem", :mapping => %w(dictionary dictionary_item)

  def method_missing(selector, *args)
    string = selector.to_s
    if (string =~ /=$/) != nil
      method = string.chop
      equals = 1
    else
      method = string
      equals = 0
    end
    if JpNewProperty.exists?(:property_string=>method, :section=>"lexeme")
      property = JpNewProperty.find(:first, :conditions=>["property_string=? and section='lexeme'", method])
      type_field = property.type_field
      item = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        raise "undefined method" unless type_field != "category" or JpProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
        if item.blank? then return JpLexemeNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0]) rescue raise "undefined method"
        else return item.update_attributes!(type_field=>args[0]) rescue raise "undefined method" end
      elsif equals == 0
        if item.blank? then return nil
        else return item[type_field] end
      end
    else super end
  end

  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :surface, :message=>'単語を入力してください！'
	validates_uniqueness_of :surface, :scope=>[:reading, :pos, :ctype, :cform, :dictionary], :message=>'新規する単語は既に辞書に保存されている！'

  ######################################################
  ##### method
  ######################################################

  def self.verify_words_in_base(params, lexeme)
    same_base_lexemes = []
		point_base = nil
		base_type = nil
		err_msg = nil

    # specify the boot_id field according to cform seeds
    if not params[:base_ok].blank? and params[:base_ok]=="true"
      lexeme["base_id"]= params[:base_id]
      same_base_lexemes << lexeme
      point_base = "true"
      base_type="2"
    else
      point_base = "false"
      same_base_lexemes, type = findWordsInSeries(lexeme)
      # type -3 means that it can not find a match in the list against input's pronunciation
      # type -2 means that it can not find a match in the list against input's reading
      # type -1 means that can not find a match in the list against input's surface
      # type 1 means that there is only one lexeme in the returned array and it's base is itself
      # type 2 means that there are several lexemes in the returned array and their base is the word whose cform_id is 1
      case type
      when -1 then err_msg = "<ul><li>単語の入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"
      when -2 then err_msg = "<ul><li>読みの入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"
      when -3 then err_msg = "<ul><li>発音の入力は間違っている<br/>もしくは活用型、活用形の選択が間違っている</li></ul>"
      when 1
        same_base_lexemes[0]["base_id"] = 0
        base_type="1"
      when 2
        base = 0
        same_base_lexemes.each{ |x|
          if x["cform"] == 1
            base_word = find(:all, :conditions=>["surface =? and reading = ? and pronunciation = ? and ctype = ? and cform = ?", x["surface"], x["reading"], x["pronunciation"], x["ctype"], x["cform"]])
            if base_word.blank?
              base = same_base_lexemes.index(x)
              base_type="1"
            else
              base = base_word[0].id
              base_type="2"
            end
            break
          end
        }
        same_base_lexemes.each{ |x| x["base_id"] = base }
      end
    end
		return same_base_lexemes, point_base, base_type, err_msg
	end

	def self.create_new_word_or_series(params, lexemes, other_properties, user_id)
    new_word = nil
    new_series = nil
    if params[:base_type] == "1" ## base_id is order
      ## 1. one word, base_id is itself
      ## 2. series, base is not registered, and base could be any number in series
      ##    2.1. there may be registered word in series
      JpLexeme.transaction do
        base_index = lexemes[0]["base_id"]
        baselexeme = lexemes[base_index]
        baselexeme.id = JpLexeme.maximum('id')+1
        baselexeme.base_id = baselexeme.id
        baselexeme.created_by = user_id
        baselexeme.save!
        save_aux_properties(baselexeme, other_properties[base_index], 'new')
        new_word = baselexeme.id
        lexemes.delete_at(base_index)
        other_properties.delete_at(base_index)
				unless lexemes.blank?
					lexemes.each_with_index{|temp_record, index|
						temp_record.base_id = baselexeme.id
						if temp_record.id.blank?
							temp_record.id = JpLexeme.maximum('id')+1
							temp_record.created_by = user_id
							temp_record.save!
							save_aux_properties(temp_record, other_properties[index], 'new')
						else
							temp_record.modified_by = user_id
							temp_record.save!
							save_aux_properties(temp_record, other_properties[index], 'update')
						end
					}
					new_series = baselexeme.id
				end
      end
    elsif params[:base_type] == "2"  ## base_id is real lexeme id
      ## 1. one word
      ## 2. series, base is registered
      ##      2.1. there may be registered word in series
      JpLexeme.transaction do
      	firstlexeme = lexemes[0]
        firstlexeme.id = JpLexeme.maximum('id')+1
        firstlexeme.created_by = user_id
        firstlexeme.root_id = JpLexeme.find(firstlexeme.base_id).root_id
        firstlexeme.save!
        save_aux_properties(firstlexeme, other_properties[0], 'new')
        new_word = firstlexeme.id
        lexemes.delete_at(0)
        other_properties.delete_at(0)
				unless lexemes.blank?
					lexemes.each_with_index{|temp_record, index|
						temp_record.root_id = firstlexeme.root_id
						if temp_record.id.blank?
							temp_record.id = JpLexeme.maximum('id')+1
							temp_record.created_by = user_id
							temp_record.save!
							save_aux_properties(temp_record, other_properties[index], 'new')
						else
							temp_record.modified_by = user_id
							temp_record.save!
							save_aux_properties(temp_record, other_properties[index], 'update')
						end
					}
          new_series = firstlexeme.base_id
        end
      end
    end
    return new_word, new_series
	end

	def self.delete_lexeme(params)
		notice_msg = nil
		err_msg = nil
 	  lexeme = JpLexeme.find(params[:id])
    base = lexeme.base
    if JpSynthetic.exists?(["sth_struct like ?", "%-#{lexeme.id}-%"])
      err_msg = "<ul><li>ほかの単語の内部構造になっているので、削除できません！</li></ul>"
    else
      if lexeme.id != base.id  #word is in base series, but is not base
        lexeme.destroy
        notice_msg = "<ul><li>単語を削除しました！</li></ul>"
      else
        if lexeme.same_base_lexemes.size == 1 ##  only the word itself remains in base series, and the word is base
          if lexeme.root_id.blank?  # no root
            lexeme.destroy
            notice_msg = "<ul><li>単語を削除しました！</li></ul>"
          elsif not lexeme.root.blank? and lexeme.root.id != lexeme.id ## word's root is not itself
            lexeme.destroy
            notice_msg = "<ul><li>単語を削除しました！</li></ul>"
          elsif JpLexeme.find(:all, :conditions=>["root_id=?", lexeme.root_id]).size == 1 ## only the word itself remains in root series
            lexeme.destroy
            notice_msg = "<ul><li>単語を削除しました！</li></ul>"
          else # still other words in root series
            err_msg = "<ul><li>単語【#{lexeme.surface}】は他の単語のRootになるので、削除できません！</li></ul>"
          end
        else #word is base, still other words in base series
          err_msg = "<ul><li>単語【#{lexeme.surface}】は他の単語のBaseになるので、削除できません！</li></ul>"
        end
      end
    end
		return notice_msg, err_msg
	end

  private
  def self.findWordsInSeries( lexeme = {} )
    newLexemes = Array.new
    newLexemes << lexeme

    # save single word which does not have cform or ctype
    if lexeme["cform"] == nil or lexeme["ctype"] == nil
    # return type 1 means base is itself
      return newLexemes, 1
    end

    # save word which has cform and ctype
    seeds = JpCtypeCformSeed.find(:all, :conditions => [" ctype=? and cform=? ", lexeme["ctype"], lexeme["cform"]] )
    if seeds.size == 0
      # save single word that can not find a match in the list of  cform_seed table
      # return type 1 means base is itself
      return newLexemes, 1
    elsif seeds.size >= 1
      # save word series that list in the cform_seed table
      seed_found = find_seed(seeds, lexeme["surface"])

      # return type -1 means that can not find a match in the list against input's surface
      if seed_found == nil
        return newLexemes, -1
      elsif seed_found.surface_end == "*"
        surface_head = lexeme["surface"]
        reading_head = lexeme["reading"]
        pronunciation_head = lexeme["pronunciation"]
      else
        lexeme["surface"] =~ /#{seed_found.surface_end}$/
        surface_head = $`
        # return type -2 means that can not find a match in the list against input's reading
        if (lexeme["reading"] =~ /#{seed_found.reading_end}$/) == nil
          return newLexemes, -2
        end
        reading_head = $`
        # return type -3 means that can not find a match in the list against input's pronunciation
        if (lexeme["pronunciation"] =~ /#{seed_found.pronunciation_end}$/) == nil
          return newLexemes, -3
        end
        pronunciation_head = $`
      end

      series = JpCtypeCformSeed.find(:all, :conditions => " ctype = '#{seed_found.ctype}' and id != '#{seed_found.id}' ")
      if series.size == 0     # return if only have itself in the list
        return newLexemes, 1
      end

      series.sort{ |x,y| x[:cform]<=>y[:cform] }.each {|kind|
        temp_lexeme = {}
        lexeme.each{|key, value|
          case key
            when "cform"
              temp_lexeme[key] = kind.cform
            when "surface", "reading", "pronunciation"
              if kind.surface_end == "*"
                temp_lexeme[key] = eval key+"_head"
              else
                temp_lexeme[key] = (eval key+"_head") + (eval "kind."+key+"_end")
              end
            else
              temp_lexeme[key] = value
          end
        }
        newLexemes << temp_lexeme
      }
      # return type 2 means base is the word which in newLexemes
      return newLexemes, 2
    end
  end

  def self.find_seed(array = [], string ="")
    return array[0] if array.size == 1 and (string =~ /#{array[0].surface_end}$/) != nil
    result = nil
    asterid_seed = nil
    array.each { |seed|
      if seed.surface_end =="*"
        asterid_seed = seed
        next
      end
      if (string =~ /#{seed.surface_end}$/) != nil
        result = seed
        break
      end
    }
    # nil means that can not find a match in the list against input's surface
    # asterid_seed means that can find a match in the list which does not have a suffix in surface
    # result means means that can find a normal match in the list which have a suffix in surface
    if result.blank?
      if asterid_seed.blank?
        return nil
      else
        return asterid_seed
      end
    else
      return result
    end
  end

	def self.save_aux_properties(lexeme, aux_properties, state)
		if state == 'new'
			unless aux_properties.blank?
				aux_properties.each{|key,value|
					property = JpNewProperty.find_by_property_string(key)
					lexeme.dynamic_properties.create!(:property_id=>property.id, property.type_field.to_sym=>value)
				}
			end
		elsif state == 'update'
	  	lexeme_dynamic_property_ids = lexeme.dynamic_properties.map(&:property_id)
	  	JpNewProperty.find_all_by_section('lexeme').each{|property|
	  		if aux_properties.key?(property.property_string)
	  			if lexeme_dynamic_property_ids.include?(property.id)
	  				lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].update_attributes!(property.type_field.to_sym=>aux_properties[property.property_string])
	  			else
	  				lexeme.dynamic_properties.create!(:property_id=>property.id, property.type_field.to_sym=>aux_properties[property.property_string])
	  			end
	  		else
	  			if lexeme_dynamic_property_ids.include?(property.id)
	  				lexeme.dynamic_properties.select{|t| t.property_id == property.id}[0].destroy
	  			end
	  		end
	  	}
		end
	end
end

