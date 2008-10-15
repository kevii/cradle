class JpLexemeNewPropertyItem < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_lexeme_new_property_items"
  
  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :property, :class_name => "JpNewProperty", :foreign_key =>"property_id"
end
