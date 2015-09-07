# coding: utf-8
#
# GyaimMotion
#
# Created by Toshiyuki Masui on 2015/9/7
# Copyright 2015 Pitecan Systems. All rights reserved.

class AppDelegate
  #def init
  #  puts "AppDelegate start"
  #end

  @candWindowController = CandWindowController.alloc.initWithWindowNibName('MainMenu')
  puts @candWindowController.class
  # @candWindowController.window.makeKeyAndOrderFront(self)
  
  #
  # IMKServerに接続
  #
  identifier = NSBundle.mainBundle.bundleIdentifier
  server = IMKServer.alloc.initWithName("Gyaim_Connection",bundleIdentifier:identifier)
    
  def applicationDidFinishLaunching(notification)
    # puts Crypt.encrypt("xxxxx")
    puts "App start"
  end

  attr_accessor :candwin
  attr_accessor :candview
  attr_accessor :textview
  attr_accessor :inputcontroller
end


