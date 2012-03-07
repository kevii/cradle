class CnToJpTranslation < ActiveRecord::Base
  self.table_name = "cradle_cn.cn_to_jp_translations"

  attr_accessible :jp_sense_ref_id

  belongs_to :to_jp_sense, :foreign_key=>"jp_sense_ref_id", :class_name=>"JpLexemeSense"
  belongs_to :from_cn_sense, :foreign_key=>"cn_sense_ref_id", :class_name=>"CnLexemeSense"

  validates_presence_of :cn_sense_ref_id, :jp_sense_ref_id
end

