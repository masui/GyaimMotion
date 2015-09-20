# -*- coding: utf-8 -*-
#
# Image.rb
#
# Created by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Image
  def Image.resize(size,src,dst=nil)
    if dst then
      system "sips -s format png #{src} --resampleHeight #{size} --out #{dst} > /dev/null >& /dev/null"
    else
      system "sips -s format png #{src} --resampleHeight #{size} > /dev/null >& /dev/null"
    end
  end

  def Image.pasteGyazoToTextView(gyazoID,textview)
    imagepath = "#{Config.cacheDir}/#{gyazoID}s.png"
    if !File.exists?(imagepath) then
      imagepath = "#{Config.imageDir}/#{gyazoID}s.png"
    end
    if !File.exists?(imagepath) then
      imageorigpath = "#{Config.imageDir}/#{gyazoID}.png"
      Files.get "https://i.gyazo.com/#{gyazoID}.png", imageorigpath
      Files.copy imageorigpath, imagepath
      Image.resize 20, imagepath
    end
    image = NSImage.alloc.initByReferencingFile(imagepath)
    
    url = NSURL.fileURLWithPath(imagepath,false)
    wrap = NSFileWrapper.alloc.initWithURL(url,options:0,error:nil)
    attachment = NSTextAttachment.alloc.initWithFileWrapper(wrap)
    attachChar = NSAttributedString.attributedStringWithAttachment(attachment)
    attrString = textview.textStorage
    attrString.beginEditing
    attrString.insertAttributedString(attachChar,atIndex:attrString.string.length)
    attrString.endEditing
  end

  def Image.pasteGyazoToPasteboard(gyazoID)
    # 画像をペーストボードに貼る
    imagepath = "#{Config.cacheDir}/#{gyazoID}.png"
    if !File.exists?(imagepath) then
      imagepath = "#{Config.imageDir}/#{gyazoID}.png"
    end
    image = NSImage.alloc.initByReferencingFile(imagepath)
    imagedata = image.TIFFRepresentation
    pasteboard = NSPasteboard.generalPasteboard
    pasteboard.clearContents
    pasteboard.declareTypes([NSPasteboardTypeTIFF, NSPasteboardTypeString],owner:nil)
    pasteboard.setData(imagedata,forType:NSTIFFPboardType)
    pasteboard.setString("[[http://Gyazo.com/#{gyazoID}.png]]",forType:NSStringPboardType)
  end

  def Image.downloadImage(url)
    downloaded = {}
    marshalfile = "#{Config.cacheDir}/downloaded"
    if File.exist?(marshalfile) then
      downloaded = Marshal.load(File.read(marshalfile))
    end
    if !downloaded[url] then
      begin
        Files.get url, "#{Config.cacheDir}/tmpimage"
        Image.resize 100, "#{Config.cacheDir}/tmpimage"
        imagedata = File.read("#{Config.cacheDir}/tmpimage")
        id = Digest::MD5.hexdigest(imagedata)
        Files.move "#{Config.cacheDir}/tmpimage", "#{Config.cacheDir}/#{id}.png"
        Files.copy "#{Config.cacheDir}/#{id}.png", "#{Config.cacheDir}/#{id}s.png"
        Image.resize 20, "#{Config.cacheDir}/#{id}s.png"
        downloaded[url] = id
      rescue
        res = false
      end
    end
    File.open(marshalfile,"w"){ |f|
      f.print Marshal.dump(downloaded)
    }
    downloaded[url]
  end
end

