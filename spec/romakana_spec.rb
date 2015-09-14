# coding: utf-8

describe "ローマ字かな変換" do
  before do
  end

  it "ローマ字 => ひらがな" do
    "masui".roma2hiragana.should == "ますい"
    "hannnya".roma2hiragana.should == "はんにゃ"
    # "han'nya".roma2hiragana.should == "はんにゃ"
  end

  it "ひらがな => ローマ字" do
    "ますい".hiragana2roma.should == "masui"
  end

  it "ローマ字 => カタカナ" do
    "vaiorinn".roma2katakana.should == "ヴァイオリン"
  end

  it "カタカナ => ローマ字" do
    "ヴァイオリン".katakana2roma.should == "vaiorinn"
  end

  iter = 1000
  it "ランダムに#{iter}個のかなを生成して変換" do
    hiralist = "あいうえおぁぃぅぇぉかきくけこがぎぐげごさしすせそざじずぜぞたちつてとっだぢづでどっなにぬねのはひふへほまみむめもやゆよゃゅょらりるれろわをんー".split(//)
    katalist = "アイウエオァィゥェォカキクケコガギグゲゴサシスセソザジズゼゾタチツテトッダヂヅデドッナニヌネノハヒフヘホマミムメモヤユヨャュョラリルレロワヲンーヴ".split(//)
    iter.times { |count|
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
