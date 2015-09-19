# coding: utf-8

describe "ファイルユティリティ" do
  before do
  end

  it "ファイルコピー" do
    File.open("/tmp/junkspec","w"){ |f|
      f.puts "abcdefg"
    }
    Files.copy("/tmp/junkspec","/tmp/junkspec1")
    s = File.read("/tmp/junkspec1")
    s.should == "abcdefg\n"
  end

  it "touch" do
    tmpfile = "/tmp/touchtest"
    File.unlink tmpfile if File.exist?(tmpfile)
    File.exist?(tmpfile).should == false
    Files.touch tmpfile
    File.exist?(tmpfile).should == true
    File.unlink tmpfile
  end
end
