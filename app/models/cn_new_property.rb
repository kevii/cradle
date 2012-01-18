class CnNewProperty < Chinese
  # mysql table used
  self.table_name = "cn_new_properties"
  
  ######################################################
  ##### table refenrence
  ######################################################
  has_many :lexeme_items, :class_name => "CnLexemeNewPropertyItem", :foreign_key =>"property_id"
  has_many :synthetic_items, :class_name => "CnSyntheticNewPropertyItem", :foreign_key =>"property_id"
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :property_string, :human_name,  :message=> "请填上“ID”与“名称”！"
  validates_format_of :property_string,   :with=>/^[0-9A-z_]+$/,
                      :message=> "“ID”必须使用字母，数字或者下划线！"
  validates_uniqueness_of :property_string,
                          :message=> "此“ID”已经被使用，请重新输入！"
  validates_exclusion_of :property_string,
                         :in => CnLexeme.column_names.dup.concat(CnSynthetic.column_names).uniq,
                         :message => "不能使用该“ID”！"
  validates_presence_of :section, :type_field
  
  ######################################################
  ##### callback
  ######################################################
  def before_update
    original = CnNewProperty.find(self.id)
    if self.type_field == "category" and original.property_string != self.property_string
      CnProperty.update_all("property_string = '#{self.property_string}'", "property_string = '#{original.property_string}'")
    end
  end
  
  def before_destroy
    case self.type_field
      when "category"
        if CnProperty.exists?(:property_string => self.property_string)
          errors.add_to_base("<ul><li>内部子分类仍然存在，不能删除“#{self.human_name}”！</li></ul>")
          return false
        end
      when "text", "time"
        if CnLexemeNewPropertyItem.exists?(["property_id = #{self.id}"]) or CnSyntheticNewPropertyItem.exists?(["property_id = #{self.id}"])
          errors.add_to_base("<ul><li>仍有使用该属性的单词存在，不能删除“#{self.human_name}”！</li></ul>")
          return false
        end
    end 
  end
  
  ######################################################
  ##### method
  ######################################################
  def self.find_by_section_and_type(section="", type="")
    self.find(:all, :conditions =>["section = ? and type_field = ?", section, type], :order=>"id ASC")
  end
end
