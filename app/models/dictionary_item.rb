class DictionaryItem
  attr_reader :list
  
  def initialize(list_as_string)
    @list = list_as_string.split(",")
  end

  def to_s
    @list.join(",")
  end
end