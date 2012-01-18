class CnLexeme < Chinese
  # mysql table used
  self.table_name = "cn_lexemes"

  ######################################################
  ##### table refenrence
  ######################################################
  has_one :struct,  :class_name=>"CnSynthetic", :foreign_key=>"sth_ref_id", :conditions=>"sth_meta_id=0"

  has_many :sub_structs,				:class_name=>"CnSynthetic",							:foreign_key=>"sth_ref_id",	:dependent=>:destroy
  has_many :dynamic_properties,	:class_name=>"CnLexemeNewPropertyItem",	:foreign_key=>"ref_id",			:dependent=>:destroy
  has_many :dynamic_struct_properties, :through=>:sub_structs, :source=>:other_properties

  belongs_to :creator,		:class_name=>"User",	:foreign_key=>"created_by"
  belongs_to :annotator,	:class_name=>"User",	:foreign_key=>"modified_by"
  
  def pos_item
    CnProperty.find(:first, :conditions=>["property_string='pos' and property_cat_id=?", self.pos])
  end

  def tagging_state_item
    CnProperty.find(:first, :conditions=>["property_string='tagging_state' and property_cat_id=?", self.tagging_state])
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
    if CnNewProperty.exists?(:property_string=>method, :section=>"lexeme")
      property = CnNewProperty.find(:first, :conditions=>["property_string=? and section='lexeme'", method])
      type_field = property.type_field
      item = CnLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        raise "undefined method" unless type_field != "category" or CnProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
        if item.blank? then return CnLexemeNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0]) rescue raise "undefined method"
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
  validates_presence_of :surface, :message => '单词不能为空！'
	validates_uniqueness_of :surface, :scope => [:reading, :pos], :message => '该单词已存在于辞典中！'
end