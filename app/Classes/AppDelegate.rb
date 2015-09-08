# coding: utf-8
#
# GyaimMotion
#
# Created by Toshiyuki Masui on 2015/9/7
# Copyright 2015 Pitecan Systems. All rights reserved.

File.open("/tmp/log","a"){ |f|
  f.puts "AppDelegate start"
}
    
class AppDelegate
  #def init
  #  puts "AppDelegate start"
  #end

  extend IB
  
  outlet :candwin, CandWindow
  outlet :candview, CandView
  outlet :textview, CandTextView
  
  def applicationDidFinishLaunching(notification)
    CandWindowController.test
    
    @candWindowController = CandWindowController.alloc.initWithWindowNibName('xMainMenuuuuuuuu')
    puts @candWindowController.class
    # @candWindowController.window.makeKeyAndOrderFront(self)
    
    # puts Crypt.encrypt("xxxxx")
    File.open("/tmp/log","a"){ |f|
      f.puts "AppDidFinishLaunching: textview = #{CandTextView.candTextView}"
    }
    puts "AppDidFinishLaunching"

    #
    # IMKServerに接続
    #
    identifier = NSBundle.mainBundle.bundleIdentifier
    File.open("/tmp/log","a"){ |f|
      f.puts "bundleidentifier = #{identifier}"
    }
    server = IMKServer.alloc.initWithName("Gyaim_Connection",bundleIdentifier:identifier)
    File.open("/tmp/log","a"){ |f|
      f.puts "IMKServer = #{server}"
    }
    #? puts server
  end

  attr_accessor :candwin
  attr_accessor :candview
  attr_accessor :textview
  attr_accessor :inputcontroller
end

File.open("/tmp/log","a"){ |f|
  f.puts "AppDelegate end"
}
    

