class JpNewProperty < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_new_properties"
  
  ######################################################
  ##### table refenrence
  ######################################################
  has_many :lexeme_items, :class_name => "JpLexemeNewPropertyItem", :foreign_key =>"property_id"
  has_many :synthetic_items, :class_name => "JpSyntheticNewPropertyItem", :foreign_key =>"property_id"
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :property_string, :human_name,  :message=>"【保存用ID】と【表示用名前】を記入してください！"
  validates_format_of :property_string,   :with=>/^[0-9A-z_]+$/,
                      :message=>"【保存用ID】は英数字と_の組み合わせで指定してください！"
  validates_uniqueness_of :property_string,
                          :message=> "入力した【保存用ID】はすでに使われているので、変更して入力してください！"
  validates_exclusion_of :property_string,
                         :in => JpLexeme.column_names.dup.concat(JpSynthetic.column_names).uniq,
                         :message => "入力した【保存用ID】は使用禁止です！"
  validates_presence_of :section, :type_field
  
  ######################################################
  ##### callback
  ######################################################
  def before_update
    original = JpNewProperty.find(self.id)
    if self.type_field == "category" and original.property_string != self.property_string
      JpProperty.update_all("property_string = '#{self.property_string}'", "property_string = '#{original.property_string}'")
    end
  end
  
  def before_destroy
    case self.type_field
      when "category"
        if JpProperty.exists?(:property_string => self.property_string)
          errors.add_to_base("<ul><li>内部の子分類はまだあるので、【#{self.human_name}】を削除できません！</li></ul>")
          return false
        end
      when "text", "time"
        if JpLexemeNewPropertyItem.exists?(["property_id = #{self.id}"]) or JpSyntheticNewPropertyItem.exists?(["property_id = #{self.id}"])
          errors.add_to_base("<ul><li>属性【#{self.human_name}】を保有する単語はまだあるので、属性を削除できません！</li></ul>")
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
