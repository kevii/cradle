class JpLexeme < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_lexemes"

  ######################################################
  ##### table refenrence
  ######################################################
  # self-referential Joins
  belongs_to  :base,  :class_name => "JpLexeme",  :foreign_key => "base_id"
  has_many    :same_base_lexemes, :class_name => "JpLexeme",  :foreign_key => "base_id"
  
  def root
    if self.root_id =~ /^R/
      return nil
    else
      return JpLexeme.find(self.root_id.to_i)
    end
  end
  
  def same_root_lexemes
    if self.root_id.blank?
      return nil
    else
      return JpLexeme.find(:all, :conditions=>["root_id=?", self.root_id], :order=>"id ASC")
    end
  end
  
  has_one :struct,  :class_name=>"JpSynthetic", :foreign_key=>"sth_ref_id", :conditions=>"sth_meta_id=0"
  
  def pos_item
    JpProperty.find(:first, :conditions=>["property_string='pos' and property_cat_id=?", self.pos])
  end

  def ctype_item
    JpProperty.find(:first, :conditions=>["property_string='ctype' and property_cat_id=?", self.ctype])
  end

  def cform_item
    JpProperty.find(:first, :conditions=>["property_string='cform' and property_cat_id=?", self.cform])
  end
  
  composed_of :dictionary_item,
              :class_name => "DictionaryItem",
              :mapping => %w(dictionary dictionary_item)
  
  def tagging_state_item
    JpProperty.find(:first, :conditions=>["property_string='tagging_state' and property_cat_id=?", self.tagging_state])
  end
  
  belongs_to :creator, :class_name => "User", :foreign_key => "created_by"
  belongs_to :annotator, :class_name => "User", :foreign_key => "modified_by"
  
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
        unless type_field != "category" or JpProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
          flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
          return
        end
        if item.blank?
          begin
            JpLexemeNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
            return
          else
            return
          end
        else
          begin
            temp.update_attributes!(type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
            return
          else
            return
          end
        end
      elsif equals == 0
        if item.blank?
          return nil
        else
          return item[type_field]
        end
      end
    else
      super
    end
  end
  
  has_many :sub_structs,  :class_name=>"JpSynthetic", :foreign_key=>"sth_ref_id"
  has_many :dynamic_properties,  :class_name=>"JpLexemeNewPropertyItem", :foreign_key=>"ref_id"
  has_many :dynamic_struct_properties, :through=>:sub_structs, :source=>:other_properties
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :id, :surface, :base_id, :dictionary, :tagging_state, :created_by
  validates_uniqueness_of :surface, :scope => [:reading, :pronunciation, :pos, :ctype, :cform]
  
  ######################################################
  ##### method
  ######################################################
  def self.verify_dictionary(dic="")
    if JpLexeme.exists?([%Q|dictionary like "%-#{dic}-%"|])
      return true
    else
      return false
    end
  end
  
  def self.exist_when_new(lexeme={})
    conditions = []
    lexeme["surface"].blank? ? conditions << "surface is NULL" : conditions << "surface = '"+lexeme["surface"]+"'"
    lexeme["reading"].blank? ? conditions << "reading is NULL" : conditions << "reading = '"+lexeme["reading"]+"'"
    lexeme["pronunciation"].blank? ? conditions << "pronunciation is NULL" : conditions << "pronunciation = '"+lexeme["pronunciation"]+"'"
    lexeme["pos"].blank? ? conditions << "pos is NULL" : conditions << "pos = "+lexeme["pos"].to_s
    lexeme["ctype"].blank? ? conditions << "ctype is NULL" : conditions << "ctype = "+lexeme["ctype"].to_s
    lexeme["cform"].blank? ? conditions << "cform is NULL" : conditions << "cform = "+lexeme["cform"].to_s
    maybe_exists = find(:all, :conditions=>conditions.join(' and '))
    unless maybe_exists.blank?
      maybe_exists.each{|temp_lexeme|
        same = []
        lexeme.each{|key, value|
          case key
            when "surface", "reading", "pronunciation", "pos", "ctype", "cform"
              next
            when "base_id", "dictionary", "log", "id", "root_id", "tagging_state"
              next
            else
              if value == (eval "temp_lexeme."+key) or ( JpNewProperty.find(:first, :conditions=>["property_string='#{key}'"]).type_field == "time" and (eval "not temp_lexeme."+key+".blank?")  and value==(eval "temp_lexeme."+key+".to_formatted_s(:db)") )
                same << true
              else 
                same << false
              end
          end
        }
        if same.size == 0 or (same.size > 0 and same.include?(false) == false and temp_lexeme.id != lexeme["id"])
          return [true, temp_lexeme.id]
        end
      }
    end
    return [false, 0]
  end

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
  
  def self.delete_lexeme(lexeme)
    JpLexeme.transaction do
      JpLexemeNewPropertyItem.transaction do
        property = JpNewProperty.find(:all, :conditions=>["section='lexeme'"])
        unless property.blank?
          property.each{|item|
            temp = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id='#{item.id}' and ref_id=#{lexeme.id}"])
            temp.destroy unless temp.blank?
          }
        end
      end
      JpSynthetic.transaction do
        JpSynthetic.find(:all, :conditions=>["sth_ref_id=#{lexeme.id}"]).each{|sub|
          JpSyntheticNewPropertyItem.transaction do
            JpNewProperty.find(:all, :conditions=>["section='synthetic'"]).each{|property|
              temp = JpSyntheticNewPropertyItem.find(:first, :conditions=>["property_id='#{property.id}' and ref_id=#{sub.id}"])
              temp.destroy unless temp.blank?
            }
          end
          sub.destroy
        }
      end
      lexeme.destroy
    end
  end
  
  private
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
  
end
