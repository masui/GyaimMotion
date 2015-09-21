# coding: utf-8

describe "MD5" do
  before do
  end

  it "MD5計算確認" do
    MD5.digest('abcdefg').should == '7ac66c0f148de9519b8bd264312c4d64'
  end
end

