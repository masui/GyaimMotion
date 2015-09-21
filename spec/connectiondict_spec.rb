# coding: utf-8
#
# ConnectionDict
#

describe "ConnectionDict検索" do
  before do
    @connectiondict = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
  end

  it "「tou」で検索して「東京」などが返ることを確認" do
    d = ConnectionDict.new(@connectiondict)
    words = []
    d.search("tou",0){ |word,pat,outc|
      next if word =~ /\*$/
      word.gsub!(/\*/,'')
      word.class.should == String
      pat.class.should == String
      outc.class.should == Fixnum
      words << word
    }
    words.index('東京').should != nil
  end

  it "「taberarenai」で検索して「食べられない」が返ることを確認" do
    d = ConnectionDict.new(@connectiondict)
    words = []
    d.search("taberarenai",0){ |word,pat,outc|
      next if word =~ /\*$/
      word.gsub!(/\*/,'')
      words << word
    }
    words.index('食べられない').should != nil
  end
end
