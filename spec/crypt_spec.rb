# coding: utf-8

describe "暗号化/復号化" do
  before do
  end

  it "encode / decode" do
    str = "あいうえお"
    key = "abcdefg"
    encoded = Crypt.encrypt(str,key)
    encoded.should.match /^[0-9a-f]+$/i
    decoded = Crypt.decrypt(encoded,key)
    decoded.should == str
    
    str = "とても長い文字列"
    key = "とても長いキー"
    encoded = Crypt.encrypt(str,key)
    encoded.should.match /^[0-9a-f]+$/i
    decoded = Crypt.decrypt(encoded,key)
    decoded.should == str
  end
end

