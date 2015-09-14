# coding: utf-8

describe "ローカル辞書セットアップ" do
  before do
  end

  it "localdict.txt が ~/.gyamdict の下にあること" do
    File.exist?(File.expand_path("~/.gyaimdict")).should == true
    File.exist?(File.expand_path("~/.gyaimdict/localdict.txt")).should == true
  end
end

