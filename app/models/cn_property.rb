class CnProperty < Chinese
  # mysql table used
  self.table_name = "cradle_cn.cn_properties"

  ######################################################
  ##### table refenrence
  ######################################################
  acts_as_tree :order=>"property_cat_id"

  def definition
    if ["pos", "tagging_state", "dictionary", "sth_tagging_state"].include?(self.property_string)
      return nil
    else
      return CnNewProperty.find(:first, :conditions=>["property_string = ?", self.property_string])
    end
  end

  ######################################################
  ##### validation
  ######################################################
  validates_presence_of :property_string, :property_cat_id, :value

  ######################################################
  ##### method
  ######################################################
  def self.save_property_tree(type="", sections=[], seperator=nil)
    parent_item = nil
    parent_item_id = nil
    0.upto(sections.size-1){|index|
      if index == 0
        item = find(:first, :conditions=>["property_string=? and value=? and parent_id is null", type, sections[index]])
      else
        item = find(:first, :conditions=>["property_string=? and value=? and parent_id=?", type, sections[index], parent_item_id])
      end
      if item.blank?
        if index == sections.size-1
          type_max_id = maximum("property_cat_id", :conditions=>["property_string=?",type])
          type_max_id.blank? ? type_id = 1 : type_id = type_max_id+1
        else
          type_id = 0
        end
        seperator = nil if seperator.blank?
        parent_item = create!(:property_string=>type,	:property_cat_id=>type_id,	:parent_id=>parent_item_id,
        											:seperator=>seperator,	:value=>sections[index])
      else
        if index == sections.size-1 and item.property_cat_id == 0
          type_max_id = maximum("property_cat_id", :conditions=>["property_string=?",type])
          type_max_id.blank? ? type_id = 1 : type_id = type_max_id+1
          item.update_attributes!(:property_cat_id=>type_id)
        end
        parent_item = item
      end
      parent_item_id = parent_item.id
    }
    return parent_item
  end

  def self.find_item_by_tree_string_or_array(type="", value_string=nil, state=nil)
    sections = []
    begin
      value_string.chomp
    rescue
      sections = value_string
    else
      seperator = find(:first, :conditions=>["property_string=?", type]).seperator
      if seperator.blank?
        sections = [value_string]
      else
        sections = value_string.split(seperator)
      end
    end
    parent = nil
    0.upto(sections.size-1){|index|
      if index == 0
        if state.blank? ## ordinary usage
          parent = find(:first, :conditions=>["property_string=? and value=? and parent_id is null", type, sections[index]])
        else  ## for validation of whether null parent_id and 0 property_cat_id item exist or not?
          parent = find(:first, :conditions=>["property_string=? and value=? and parent_id is null and property_cat_id > 0", type, sections[index]])
        end
        break if parent.blank?
      else
        if parent.children.map{|child| child.value}.include?(sections[index])
          parent.children.each{|child| parent = child if child.value == sections[index]}
        else
          parent = nil
          break
        end
      end
    }
    return parent
  end

  def tree_string
    tree_string_array = [self.value]
    parent = self.parent
    until (parent.blank?)
      tree_string_array << parent.value
      parent = parent.parent
    end
    return tree_string_array.reverse.join(self.seperator)
  end

  def sub_tree_items
    tree_node_array = []
    tree_node_array << self if self.property_cat_id > 0
    unless self.children.blank?
      self.children.each{|child| tree_node_array.concat(child.sub_tree_items)}
    end
    return tree_node_array
  end

  def self.find_inside(type, conditions)
  	find(:all, :conditions=>["property_string=? and "+conditions, type])
  end
end

