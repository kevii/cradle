require 'spec_helper'

describe JpToCn do
  before(:each) do
    @valid_attributes = {
      :jp_id => 1,
      :cn_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    JpToCn.create!(@valid_attributes)
  end
end
