class CnToJp < ActiveRecord::Base
  self.table_name = "cradle_cn.cn_to_jps"

  attr_accessible :jp_id

  belongs_to :jp, :foreign_key => :jp_id, :class_name => "JpLexeme"
  belongs_to :cn, :foreign_key => :cn_id, :class_name => "CnLexeme"

  validates_presence_of :jp_id, :cn_id
end

