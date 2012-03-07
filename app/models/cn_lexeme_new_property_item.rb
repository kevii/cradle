class CnLexemeNewPropertyItem < Chinese
  # mysql table used
  self.table_name = "cradle_cn.cn_lexeme_new_property_items"

  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :property, :class_name => "CnNewProperty", :foreign_key =>"property_id"
  belongs_to :lexeme, :class_name => "CnLexeme", :foreign_key =>"ref_id"

  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :property_id, :ref_id
  validates_uniqueness_of :property_id, :scope => [:ref_id]
end

