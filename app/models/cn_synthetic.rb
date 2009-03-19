class CnSynthetic < Chinese
  # mysql table used
  self.table_name = "cn_synthetics"
  
  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :lexeme,  :class_name=>"CnLexeme",  :foreign_key=>"sth_ref_id"
  has_many :other_properties,  :class_name=>"CnSyntheticNewPropertyItem", :foreign_key=>"ref_id", :dependent => :destroy
  
  def sth_tagging_state_item
    CnProperty.find(:first, :conditions=>["property_string='sth_tagging_state' and property_cat_id=?", self.sth_tagging_state])
  end
  
  belongs_to :annotator, :class_name => "User", :foreign_key => "modified_by"
  
  def method_missing(selector, *args)
    string = selector.to_s
    if (string =~ /=$/) != nil
      method = string.chop
      equals = 1
    else
      method = string
      equals = 0
    end
    if CnNewProperty.exists?(:property_string=>method, :section=>"synthetic")
      property = CnNewProperty.find(:first, :conditions=>["property_string=? and section='synthetic'", method])
      type_field = property.type_field
      item = CnSyntheticNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        unless type_field != "category" or CnProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
          raise "undefined method"
        end
        if item.blank?
          return CnSyntheticNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0]) rescue raise "undefined method"
        else
          return item.update_attributes!(type_field=>args[0]) rescue raise "undefined method"
        end
      elsif equals == 0
        if item.blank?
          return nil
        else
          return item[type_field]
        end
      end
    else
      super
    end
  end
  
  ######################################################
  ##### validation
  ######################################################
  validates_uniqueness_of :sth_ref_id, :scope => [:sth_meta_id]
  
  ######################################################
  ##### method
  ######################################################
  def get_display_string
    string_array = []
    sth_struct.split(',').map{|item| item.delete('-')}.each{|part|
      if part =~ /^\d+$/
        string_array << CnLexeme.find(part.to_i).surface
      elsif part =~ /^meta_(.*)$/
        string_array << CnSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).sth_surface
      end
    }
    return string_array.join(',&nbsp;&nbsp;&nbsp;')
  end
  
  def get_dump_string(property_list)
    dump_string_array = []
    unless property_list.blank?
      property_string = []
      property_list.each{|property|
        valid_pro = eval('self.'+property[0])
        if valid_pro.blank?
          property_string << property[0]+'='
        else
          case property[2]
            when 'category'
              property_string << property[0]+'='+CnProperty.find(:first, :conditions=>["property_string=? and property_cat_id=?", property[0], valid_pro]).tree_string 
            when 'text'
              property_string << property[0]+'='+valid_pro
            when 'time'
              property_string << property[0]+'='+valid_pro.to_formatted_s(:number)
          end
        end
      }
      dump_string_array << '('+property_string.join(",")+')'
    end
    sth_struct.split(',').map{|item| item.delete('-')}.each{|part|
      if part =~ /^\d+$/
        dump_string_array << CnLexeme.find(part.to_i).surface + '[' + part + ']'
      elsif part =~ /^meta_(.*)$/
        dump_string_array << '(' + CnSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).get_dump_string(property_list) + ')'
      end
    }
    return dump_string_array.join(',')
  end
end
