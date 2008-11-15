class JpCtypeCformSeed < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_ctype_cform_seeds"
  
  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :ctype, :cform, :surface_end, :reading_end, :pronunciation_end,
                        :message=>"すべての語尾フィールドを入力してください！"
                        
  ######################################################
  ##### callback
  ######################################################
  def before_save
    return false if self.class.exists?(:cform=>cform, :ctype=>ctype)
  end
end
