class CnLexeme < Chinese
  # mysql table used
  self.table_name = "cn_lexemes"

  ######################################################
  ##### table refenrence
  ######################################################
  has_one :struct,  :class_name=>"CnSynthetic", :foreign_key=>"sth_ref_id", :conditions=>"sth_meta_id=0"
  has_many :sub_structs,  :class_name=>"CnSynthetic", :foreign_key=>"sth_ref_id", :dependent => :destroy
  has_many :dynamic_properties,  :class_name=>"CnLexemeNewPropertyItem", :foreign_key=>"ref_id", :dependent => :destroy
  has_many :dynamic_struct_properties, :through=>:sub_structs, :source=>:other_properties

  def pos_item
    CnProperty.find(:first, :conditions=>["property_string='pos' and property_cat_id=?", self.pos])
  end

  composed_of :dictionary_item,
              :class_name => "DictionaryItem",
              :mapping => %w(dictionary dictionary_item)
  
  def tagging_state_item
    CnProperty.find(:first, :conditions=>["property_string='tagging_state' and property_cat_id=?", self.tagging_state])
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
    if CnNewProperty.exists?(:property_string=>method, :section=>"lexeme")
      property = CnNewProperty.find(:first, :conditions=>["property_string=? and section='lexeme'", method])
      type_field = property.type_field
      item = CnLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        unless type_field != "category" or CnProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
          raise "undefined method"
        end
        if item.blank?
          return CnLexemeNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0]) rescue raise "undefined method"
        else
          return item.update_attributes!(type_field=>args[0]) rescue raise "undefined method"
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
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :surface, :message => '单词不能为空！'
  validates_presence_of :dictionary, :message => '所属辞典不能为空！'
  validates_presence_of :tagging_state, :message => '状态不能为空！'
	validates_format_of :reading, :with => /^[a-z]([a-z]|\s)*[a-z]$/, :message => '拼音不能为空，并且必须为小写英文字母！'
	validates_uniqueness_of :surface, :scope => [:reading, :pos], :message => '该单词已存在于辞典中！'
	
	
  ######################################################
  ##### method
  ######################################################
  def self.verify_dictionary(dic="")
    if CnLexeme.exists?([%Q|dictionary like "%-#{dic}-%"|])
      return true
    else
      return false
    end
  end
  
  def self.delete_lexeme(lexeme)
    CnLexeme.transaction do
      CnLexemeNewPropertyItem.transaction do
        property = CnNewProperty.find(:all, :conditions=>["section='lexeme'"])
        unless property.blank?
          property.each{|item|
            temp = CnLexemeNewPropertyItem.find(:first, :conditions=>["property_id='#{item.id}' and ref_id=#{lexeme.id}"])
            temp.destroy unless temp.blank?
          }
        end
      end
      CnSynthetic.transaction do
        CnSynthetic.find(:all, :conditions=>["sth_ref_id=#{lexeme.id}"]).each{|sub|
          CnSyntheticNewPropertyItem.transaction do
            CnNewProperty.find(:all, :conditions=>["section='synthetic'"]).each{|property|
              temp = CnSyntheticNewPropertyItem.find(:first, :conditions=>["property_id='#{property.id}' and ref_id=#{sub.id}"])
              temp.destroy unless temp.blank?
            }
          end
          sub.destroy
        }
      end
      lexeme.destroy
    end
  end
end