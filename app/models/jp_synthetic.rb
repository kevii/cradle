class JpSynthetic < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_synthetics"
  
  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :lexeme,  :class_name=>"JpLexeme",  :foreign_key=>"sth_ref_id"
  has_many :other_properties,  :class_name=>"JpSyntheticNewPropertyItem", :foreign_key=>"ref_id"
  
  def sth_tagging_state_item
    JpProperty.find(:first, :conditions=>["property_string='sth_tagging_state' and property_cat_id=?", self.sth_tagging_state])
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
    if JpNewProperty.exists?(:property_string=>method, :section=>"synthetic")
      property = JpNewProperty.find(:first, :conditions=>["property_string=? and section='synthetic'", method])
      type_field = property.type_field
      item = JpSyntheticNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        unless type_field != "category" or JpProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
          flash[:notice_err] = "<ul><li>複合語 method_missing problem！</li></ul>"
          return
        end
        if item.blank?
          begin
            JpSyntheticNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li>複合語 method_missing problem！</li></ul>"
            return
          else
            return
          end
        else
          begin
            temp.update_attributes!(type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li複合語 method_missing problem！</li></ul>"
            return
          else
            return
          end
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
  ##### method
  ######################################################
  def get_display_string
    string_array = []
    sth_struct.split(',').map{|item| item.delete('-')}.each{|part|
      if part =~ /^\d+$/
        string_array << JpLexeme.find(part.to_i).surface
      elsif part =~ /^meta_(.*)$/
        string_array << JpSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).sth_surface
      end
    }
    return string_array.join(',&nbsp;&nbsp;&nbsp;')
  end
  
  def get_dump_string
    dump_string_array = []
    sth_struct.split(',').map{|item| item.delete('-')}.each{|part|
      if part =~ /^\d+$/
        dump_string_array << JpLexeme.find(part.to_i).surface + '(' + part + ')'
      elsif part =~ /^meta_(.*)$/
        dump_string_array << '(' + JpSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).get_dump_string + ')'
      end
    }
    return dump_string_array.join(',')
  end
  
end
