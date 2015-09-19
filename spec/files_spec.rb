# coding: utf-8

describe "ファイルユティリティ" do
  before do
  end

  it "ファイルコピー" do
    tmpfile1 = "/tmp/tmpfile#{$$}1"
    tmpfile2 = "/tmp/tmpfile#{$$}2"
    data = "test write data."
    File.open(tmpfile1,"w"){ |f|
      f.print data
    }
    Files.copy tmpfile1, tmpfile2
    File.read(tmpfile2).should == data
    File.unlink tmpfile1, tmpfile2
  end

  it "touch" do
    tmpfile = "/tmp/tmpfile#{$$}1"
    File.unlink tmpfile if File.exist?(tmpfile)
    File.exist?(tmpfile).should == false
    Files.touch tmpfile
    File.exist?(tmpfile).should == true
    File.unlink tmpfile
  end
end
