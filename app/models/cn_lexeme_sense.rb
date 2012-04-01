class CnLexemeSense < ActiveRecord::Base
  self.table_name = "cradle_cn.cn_lexeme_senses"

  belongs_to :cn_lexeme, :foreign_key=>"cn_lexeme_ref_id", :class_name=>"CnLexeme"

  has_many :translation_to_jp, :class_name=>"CnToJpTranslation", :foreign_key=>"cn_sense_ref_id", :dependent=>:destroy
  has_many :get_translation_to_jp, :through=>:translation_to_jp, :source=>:to_jp_sense

  validates_presence_of :cn_lexeme_ref_id, :text


  def if_trans_to_jp?(jpsense)
    translation_to_jp.find_by_jp_sense_ref_id(jpsense)
  end

  def create_trans_to_jp_by_id! jpsense_id
    translation_to_jp.create!(:jp_sense_ref_id => jpsense_id)
  end

  def create_trans_to_jp!(jpsense)
    translation_to_jp.create!(:jp_sense_ref_id => jpsense.id)
  end

  def destroy_trans_to_jp!(jpsense)
    translation_to_jp.find_by_jp_sense_ref_id(jpsense).destroy
  end

end

