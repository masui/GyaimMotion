# coding: utf-8

describe "暗号化/復号化" do
  before do
  end

  it "encode / decode" do
    str = "あいうえお"
    key = "abcdefg"
    Crypt.decrypt(Crypt.encrypt(str,key),key).should == str
    str = "とても長い文字列"
    key = "とても長いキー"
    Crypt.decrypt(Crypt.encrypt(str,key),key).should == str
  end
end

