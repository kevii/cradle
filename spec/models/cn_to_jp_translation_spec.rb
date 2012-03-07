require 'spec_helper'

describe CnToJpTranslation do
  before(:each) do
    @valid_attributes = {
      :cn_sense_ref_id => ,
      :jp_sense_ref_id => ,
      :lock_version => 1
    }
  end

  it "should create a new instance given valid attributes" do
    CnToJpTranslation.create!(@valid_attributes)
  end
end
