# coding: utf-8

describe "ローカル辞書セットアップ" do
  before do
  end

  # it "localdict.txt が ~/.gyamdict の下にあること" do
  it "辞書が存在すること" do
    File.exist?(Config.gyaimDir).should == true
    File.exist?(Config.localDictFile).should == true
  end
end

