require 'spec_helper'

describe CnLexemeSense do
  before(:each) do
    @valid_attributes = {
      :cn_lexeme_ref_id => ,
      :text => "value for text",
      :category => 1,
      :lock_version => 1
    }
  end

  it "should create a new instance given valid attributes" do
    CnLexemeSense.create!(@valid_attributes)
  end
end
