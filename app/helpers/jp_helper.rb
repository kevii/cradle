module JpHelper
  include ApplicationHelper
  def initial_property_name
    { "id"=>"ID",                     "surface"=>"単語",                  "reading"=>"読み",
      "pronunciation"=>"発音",         "base_id"=>"Base",                 "root_id"=>"Root",
      "pos"=>"品詞",                   "ctype"=>"活用型",                  "cform"=>"活用形",
      "dictionary"=>"辞書",            "tagging_state"=>"状態",            "log"=>"備考",
      "created_by"=>"新規者",          "modified_by"=>"更新者",             "updated_at"=>"更新時間",
      "sth_struct"=>"構造",            "sth_tagging_state"=>"状態",        "character_number"=>"文字数" }
  end
  
  def initial_property_desc
    { "id"=>"単語ID",                    "surface"=>"単語表記",               "reading"=>"単語読み",
      "pronunciation"=>"単語発音",        "base_id"=>"単語のBase",             "root_id"=>"単語のRoot",
      "pos"=>"品詞情報",                  "ctype"=>"活用型情報",                "cform"=>"活用形情報",
      "dictionary"=>"辞書情報",           "tagging_state"=>"タグ状態",          "log" => "備考内容",
      "created_by"=>"新規者情報",         "modified_by"=>"更新者情報",           "updated_at"=>"更新時間情報",
      "sth_struct"=>"内部構造",           "sth_tagging_state"=>"タグ状態" }
  end
  
end
