class JpSynthetic < ActiveRecord::Base
  # mysql table used
  self.table_name = "jp_synthetics"
  
  ######################################################
  ##### table refenrence
  ######################################################
  belongs_to :lexeme,  :class_name=>"JpLexeme",  :foreign_key=>"sth_ref_id"
  has_many :other_properties,  :class_name=>"JpSyntheticNewPropertyItem", :foreign_key=>"ref_id", :dependent=>:destroy

	def self.load_struct_from_json(options, current_level = 0, current_max_level = 0)
		temp_sth_struct_ary = []
		properties_ary = []
		sub_json_struct = {}
		options[:json_struct].each do |item|
			case item
			when Array
				current_max_level = current_max_level + 1
				temp_sth_struct_ary << "meta_#{current_max_level}"
				sub_json_struct[current_max_level] = item
			when Hash
				if (item.keys.size == 1) && (item.keys[0] =~ /^\d+$/)
					temp_sth_struct_ary << item.keys[0]
				else
					properties_ary = item.inject([]) do |temp_ary, inner|
						unless inner[1].blank?
							property = JpNewProperty.find_by_section_and_property_string('synthetic', inner[0])
							temp_value = case property.type_field
								when 'category' then JpProperty.find_item_by_tree_string_or_array(inner[0], inner[1]).property_cat_id
								when 'text'			then inner[1]
								when 'time'			then inner[1].to_formatted_s(:db)
							end
							temp_ary << {:property_id => property.id, :type => property.type_field, :value => temp_value}
						end
						temp_ary
					end
				end
			end
		end
		new_meta_struct = create!(
			:sth_ref_id 				=> options[:lexeme].id,
			:sth_meta_id				=> current_level,
			:sth_struct					=> temp_sth_struct_ary.map{|x| "-#{x}-"}.join(','),
			:sth_surface				=> options[:lexeme].surface,
			:sth_tagging_state	=> options[:tagging_state],
			:log								=> options[:log],
			:modified_by				=> options[:modified_by]
		)
		properties_ary.each do |item|
			JpSyntheticNewPropertyItem.create!(
				:property_id				=> item[:property_id],
				:ref_id							=> new_meta_struct.id,
				item[:type].intern	=> item[:value]
			)
		end
		sub_json_struct.each do |key, value|
			current_max_level = load_struct_from_json(options.update(:json_struct => value), key, current_max_level)
		end
		return current_max_level
	end

	def self.destroy_struct(lexeme_id)
		transaction do
			find(:all, :conditions=>["sth_ref_id=?", lexeme_id]).each{|sub_structure| sub_structure.destroy}
  	end
	end
  
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
          raise "undefined method"
        end
        if item.blank?
          return JpSyntheticNewPropertyItem.create!(:property_id=>property.id, :ref_id=>self.id, type_field=>args[0]) rescue raise "undefined method"
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
        string_array << JpLexeme.find(part.to_i).surface
      elsif part =~ /^meta_(.*)$/
        string_array << JpSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).sth_surface
      end
    }
    return string_array.join(',&nbsp;&nbsp;&nbsp;')
  end
  
  def get_dump_string(property_list)
    dump_string_array = []
    if property_list.blank?
    	dump_string_array << {}
    else
      property_hash = property_list.inject({}) do |temp_hash, property|
        valid_pro = send(property[0])
        temp_hash[property[0]] = if valid_pro.blank? then ''
        else
          case property[2]
          when 'category' then JpProperty.find(:first, :conditions=>["property_string=? and property_cat_id=?", property[0], valid_pro]).tree_string.toutf8
          when 'text'			then valid_pro
          when 'time'			then valid_pro.to_formatted_s(:number)
          end
        end
        temp_hash
      end
      dump_string_array << property_hash unless property_hash.blank?
    end
    sth_struct.split(',').map{|item| item.delete('-')}.each{|part|
      if part =~ /^\d+$/
        dump_string_array << {part => JpLexeme.find(part.to_i).surface}
      elsif part =~ /^meta_(.*)$/
        dump_string_array << JpSynthetic.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", sth_ref_id, $1.to_i]).get_dump_string(property_list)
      end
    }
    return dump_string_array
  end
end