require 'spec_helper'

describe JpLexemeSense do
  before(:each) do
    @valid_attributes = {
      :jp_lexeme_ref_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    JpLexemeSense.create!(@valid_attributes)
  end
end
