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

  #it "hiragana2roma" do
  #  "ヴァイオリン".should == "vaxiorin"
  #end

  it "random" do
    hiralist = "あいうえおぁぃぅぇぉかきくけこがぎぐげごさしすせそざじずぜぞたちつてとっだぢづでどっなにぬねのはひふへほまみむめもやゆよゃゅょらりるれろわをんー".split(//)
    katalist = "アイウエオァィゥェォカキクケコガギグゲゴサシスセソザジズゼゾタチツテトッダヂヅデドッナニヌネノハヒフヘホマミムメモヤユヨャュョラリルレロワヲンーヴ".split(//)
    1000.times { |count|
      hira = (0..9).collect { |i|
        hiralist[rand(hiralist.length)]
      }.join
      next if hira =~ /っっ/  # これが失敗する
      # next if hira =~ /っじ/
      roma = hira.hiragana2roma
      roma.roma2hiragana.should == hira
    }
  end
end
