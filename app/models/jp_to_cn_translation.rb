class JpToCnTranslation < ActiveRecord::Base

  attr_accessible :cn_sense_ref_id

  belongs_to :to_cn_sense, :foreign_key=>"cn_sense_ref_id", :class_name=>"CnLexemeSense"
  belongs_to :from_jp_sense, :foreign_key=>"jp_sense_ref_id", :class_name=>"JpLexemeSense"

  validates_presence_of :jp_sense_ref_id, :cn_sense_ref_id
end

