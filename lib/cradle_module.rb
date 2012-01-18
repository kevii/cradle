module CradleModule
  def verify_domain(domain=nil)
    class_name = {}
    case domain
      when "jp"
        class_name["Lexeme"] = "JpLexeme"
        class_name["Synthetic"] = "JpSynthetic"
        class_name["Property"] = "JpProperty"
        class_name["NewProperty"] = "JpNewProperty"
        class_name["LexemeNewPropertyItem"] = "JpLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "JpSyntheticNewPropertyItem"
      when "cn"
        class_name["Lexeme"] = "CnLexeme"
        class_name["Synthetic"] = "CnSynthetic"
        class_name["Property"] = "CnProperty"
        class_name["NewProperty"] = "CnNewProperty"
        class_name["LexemeNewPropertyItem"] = "CnLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "CnSyntheticNewPropertyItem"
      when "en"
        class_name["Lexeme"] = "EnLexeme"
        class_name["Synthetic"] = "EnSynthetic"
        class_name["Property"] = "EnProperty"
        class_name["NewProperty"] = "EnNewProperty"
        class_name["LexemeNewPropertyItem"] = "EnLexemeNewPropertyItem"
        class_name["SyntheticNewPropertyItem"] = "EnSyntheticNewPropertyItem"
    end
    return class_name
  end
  
  def initial_property_name(domain=nil)
    case domain
      when "jp"
        return {"id"=>"ID",                     "surface"=>"単語",                  "reading"=>"読み",
                "pronunciation"=>"発音",         "base_id"=>"Base",                 "root_id"=>"Root",
                "pos"=>"品詞",                   "ctype"=>"活用型",                  "cform"=>"活用形",
                "dictionary"=>"辞書",            "tagging_state"=>"状態",            "log"=>"備考",
                "created_by"=>"新規者",          "modified_by"=>"更新者",             "updated_at"=>"更新時間",
                "sth_struct"=>"構造",            "sth_tagging_state"=>"状態",        "character_number"=>"文字数"}
      when "cn"
        return {"id"=>"ID",                     "surface"=>"单词",                  "reading"=>"拼音",
                "pos"=>"词性",                   "dictionary"=>"辞典",            	  "tagging_state"=>"状态",
                "log"=>"备注",										"created_by"=>"创建者",          		"modified_by"=>"更新者",
                "updated_at"=>"更新时间",					"sth_struct"=>"结构",            		"sth_tagging_state"=>"状态",
                "character_number"=>"字数"}
      when "en"
    end  
  end
  
  def initial_property_desc(domain=nil)
    case domain
      when "jp"
        return {"id"=>"単語ID",                    "surface"=>"単語表記",               "reading"=>"単語読み",
                "pronunciation"=>"単語発音",        "base_id"=>"単語のBase",             "root_id"=>"単語のRoot",
                "pos"=>"品詞情報",                  "ctype"=>"活用型情報",                "cform"=>"活用形情報",
                "dictionary"=>"辞書情報(最後の“*”の意味は匿名検索禁止)",           "tagging_state"=>"タグ状態",          "log" => "備考内容",
                "created_by"=>"新規者情報",         "modified_by"=>"更新者情報",           "updated_at"=>"更新時間情報",
                "sth_struct"=>"内部構造",           "sth_tagging_state"=>"タグ状態"}
      when "cn"
        return {"id"=>"单词ID",                    "surface"=>"单词写法",               "reading"=>"单词拼音",
                "pos"=>"词性信息",                  "dictionary"=>"辞典信息(最后的“*”表示禁止匿名检索)",
                "tagging_state"=>"标注状态",        "log" => "备注",										"created_by"=>"创建者信息",
                "modified_by"=>"更新者信息",        "updated_at"=>"更新时间信息",					"sth_struct"=>"内部结构",
                "sth_tagging_state"=>"标注状态"}
      when "en"
    end  
  end
  
  def operator0
    return { ">"=>">", "<"=>"<", "<="=>"<=", ">="=>">=", "="=>"=", "!="=>"!=", "like"=>"=~", "in"=>"in", "not in"=>"not in", "and"=>"and", "or"=>"or"}
  end
  
  def operator
    return { ">"=>">", "<"=>"<", "<="=>"<=", ">="=>">=", "="=>"=" }
  end
  
  def operator1
    return { "="=>"=", "=~"=>"like"}
  end

  def operator2
    return { "="=>"=", "!="=>"!=", "in"=>"in", "not in"=>"not in" }
  end

  def operator3
    return { "="=>"=", "!="=>"!=" }
  end
  
  def operator4
    return { "<="=>"<=", ">="=>">=" }
  end
  
  def operator5
    return {"and"=>"and", "or"=>"or"}
  end

  def per_page_list
    return ["10", "30", "50", "100"]
  end
  
  def dictionary_color
    { 1=>"red", 2=>"pink", 3=>"orange", 4=>"brown", 5=>"gold", 6=>"yellow", 7=>"green", 8=>"turquoise",
      9=>"blue", 10=>"purple", 11=>"grey", 12=>"black", 13=>"deepskyblue", 14=>"springgreen", 15=>"olive",
      16=>"saddlebrown", 17=>"fuchsia", 18=>"indigo", 19=>"cyan", 20=>"cadetblue"}  
  end
  
  def struct_level
    { 1=>"①", 2=>"②", 3=>"③", 4=>"④", 5=>"⑤", 6=>"⑥", 7=>"⑦", 8=>"⑧", 9=>"⑨", 10=>"⑩"}  
  end
  
  private
  def is_string(item)
    begin
      item.chomp
    rescue
      return false
    else
      return true
    end
  end
end