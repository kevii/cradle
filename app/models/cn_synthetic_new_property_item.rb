class CnSyntheticNewPropertyItem < Chinese
  # mysql table used
  self.table_name = "cradle_cn.cn_synthetic_new_property_items"

  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :property, :class_name => "CnNewProperty", :foreign_key =>"property_id"
  validates_uniqueness_of :property_id, :scope => [:ref_id]
end

