require 'spec_helper'

describe JpToCnTranslation do
  before(:each) do
    @valid_attributes = {
      :jp_sense_ref_id => ,
      :cn_lexeme_ref_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    JpToCnTranslation.create!(@valid_attributes)
  end
end
