require 'spec_helper'

describe CnToJp do
  before(:each) do
    @valid_attributes = {
      :cn_id => 1,
      :jp_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    CnToJp.create!(@valid_attributes)
  end
end
