# coding: utf-8

describe "Local dictionary setup" do
  before do
  end

  it "localdict.txt should exist" do
    File.exist?(File.expand_path("~/.gyaimdict")).should == true
    File.exist?(File.expand_path("~/.gyaimdict/localdict.txt")).should == true
  end
end

