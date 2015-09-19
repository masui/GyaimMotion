# coding: utf-8

describe "ローカル辞書セットアップ" do
  before do
  end

  # it "localdict.txt が ~/.gyamdict の下にあること" do
  it "辞書が存在すること" do
    File.exist?(Files.gyaimDir).should == true
    File.exist?(Files.localDictFile).should == true
  end
end

