class JpLexemeSense < ActiveRecord::Base

  attr_accessible :text

  belongs_to :jp_lexeme, :foreign_key=>"jp_lexeme_ref_id", :class_name=>"JpLexeme"

  has_many :translation_to_cn, :class_name=>"JpToCnTranslation", :foreign_key=>"jp_sense_ref_id", :dependent=>:destroy
  has_many :get_translation_to_cn, :through=>:translation_to_cn, :source=>:to_cn_sense

  validates_presence_of :jp_lexeme_ref_id, :text

  default_scope :order => 'created_at'

  def if_trans_to_cn?(cnsense)
    translation_to_cn.find_by_cn_sense_ref_id(cnsense)
  end

  def create_trans_to_cn!(cnsense)
    translation_to_cn.create!(:cn_sense_ref_id => cnsense.id)
  end

  def create_trans_to_cn_by_id!(cnsense_id)
    translation_to_cn.create!(:cn_sense_ref_id => cnsense_id)
  end

  def destroy_trans_to_cn!(cnsense)
    translation_to_cn.find_by_cn_sense_ref_id(cnsense).destroy
  end

end

