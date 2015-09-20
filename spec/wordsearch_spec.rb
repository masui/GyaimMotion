# coding: utf-8
#
# 検索テスト
#

describe "WordSearch" do
  before do
    @localdict = "/tmp/localdict.txt"
    @studydict = "/tmp/studydict.txt"
    File.unlink @localdict if File.exist? @localdict
    File.unlink @studydict if File.exist? @studydict
    File.open(@localdict,"w"){ |f| f.print "" }
    File.open(@studydict,"w"){ |f| f.print "" }
    @connectiondict = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
    @ws = WordSearch.new @connectiondict, @localdict, @studydict
  end

  it "単純単語検索" do
    cands = @ws.search "masui", 0
    cands.length.should > 0
    cands.flatten.index("増井").should >= 0
  end
  
  it "語尾変化" do
    cands = @ws.search "taberaremasen", 0
    cands.length.should > 0
    cands.flatten.index("食べられません").should >= 0
  end
  
  it "複雑な接続" do
    cands = @ws.search "sanbyakuyonjuuni", 0
    cands.length.should > 0
    cands.flatten.index("三百四十二").should >= 0
  end

  it "ユーザ辞書登録" do
    @ws.register 'あいうえお', 'aiueo'
    a = File.read(@localdict)
    a.index('あいうえお').should >= 0
    a.index('aiueo').should >= 0
  end
  
end
