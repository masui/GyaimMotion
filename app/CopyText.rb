# -*- coding: utf-8 -*-

class CopyText
  def CopyText.file
    "#{Config.gyaimDir}/copytext"
  end

  def CopyText.set(text)
    curtext = ''
    curtext = File.read(file) if File.exist?(file)
    if curtext != text then
      File.open(file,"w"){ |f| f.print text }
    end
  end

  def CopyText.get
    File.read file
  end

  def CopyText.time
    File.mtime file
  end
end
