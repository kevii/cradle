class JpToCn < ActiveRecord::Base
  attr_accessible :cn_id

  belongs_to :cn, :foreign_key=>"cn_id", :class_name=>"CnLexeme"
  belongs_to :jp, :foreign_key=>"jp_id", :class_name=>"JpLexeme"

  validates_presence_of :cn_id, :jp_id

end

