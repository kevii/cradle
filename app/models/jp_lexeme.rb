class JpLexeme < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_lexemes"

  ######################################################
  ##### table refenrence
  ######################################################
  # self-referential Joins
  belongs_to  :base,  :class_name => "JpLexeme",  :foreign_key => "base_id"
  has_many    :same_base_lexemes, :class_name => "JpLexeme",  :foreign_key => "base_id"
  
  def root
    if self.root_id =~ /^R/
      return nil
    else
      return JpLexeme.find(self.root_id.to_i)
    end
  end
  
  def same_root_lexemes
    if self.root_id.blank?
      return nil
    else
      return JpLexeme.find(:all, :conditions=>["root_id=?", self.root_id], :order=>"id ASC")
    end
  end
  
  has_one :struct,  :class_name=>"JpSynthetic", :foreign_key=>"sth_ref_id", :conditions=>"sth_meta_id=0"
  
  def pos_item
    JpProperty.find(:first, :conditions=>["property_string='pos' and property_cat_id=?", self.pos])
  end

  def ctype_item
    JpProperty.find(:first, :conditions=>["property_string='ctype' and property_cat_id=?", self.ctype])
  end

  def cform_item
    JpProperty.find(:first, :conditions=>["property_string='cform' and property_cat_id=?", self.cform])
  end
  
  composed_of :dictionary_item,
              :class_name => "DictionaryItem",
              :mapping => %w(dictionary dictionary_item)
  
  def tagging_state_item
    JpProperty.find(:first, :conditions=>["property_string='tagging_state' and property_cat_id=?", self.tagging_state])
  end
  
  belongs_to :creator, :class_name => "User", :foreign_key => "created_by"
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
    if JpNewProperty.exists?(:property_string=>method, :section=>"lexeme")
      property = JpNewProperty.find(:first, :conditions=>["property_string=? and section='lexeme'", method])
      type_field = property.type_field
      item = JpLexemeNewPropertyItem.find(:first, :conditions=>["property_id=? and ref_id=?", property.id, self.id])
      if equals == 1
        unless type_field != "category" or JpProperty.exists?(:property_string=>method, :property_cat_id=>args[0])
          flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
          return
        end
        if item.blank?
          begin
            JpLexemeNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
            return
          else
            return
          end
        else
          begin
            temp.update_attributes!(type_field=>args[0])
          rescue
            flash[:notice_err] = "<ul><li>単語 method_missing problem！</li></ul>"
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
  def self.verify_dictionary(dic="")
    if JpLexeme.exists?(["dictionary rlike '^#{dic}$|^#{dic},|,#{dic}$|,#{dic},'"])
      return true
    else
      return false
    end
  end
  
end
