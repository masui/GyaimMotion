# coding: utf-8

describe "Romakana" do
  before do
  end

  it "roma2hiragana" do
    "masui".roma2hiragana.should == "ますい"
    "hannnya".roma2hiragana.should == "はんにゃ"
    # "han'nya".roma2hiragana.should == "はんにゃ"
  end

  it "hiragana2roma" do
    "ますい".hiragana2roma.should == "masui"
  end
end
