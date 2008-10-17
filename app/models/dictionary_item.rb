class DictionaryItem
  attr_reader :list
  
  def initialize(list_as_string)
    @list = list_as_string.split(",").map{|item| item.delete('-')}
  end

  def to_s
    @list.map{|item| '-'+item+'-'}.join(",")
  end
end