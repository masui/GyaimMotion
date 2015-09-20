# -*- coding: utf-8 -*-
#
# Created by Toshiyuki Masui on 2015/9/8.
#
# Copyright 2011-2015 Pitecan Systems. All rights reserved.
#
class Google
  #
  # Google日本語変換
  #
  def Google.searchCands(q)
    candidates = []
    AFMotion::JSON.get("http://google.com/transliterate", {langpair: "ja-Hira|ja", text: q.roma2hiragana}) do |result|
      candidates = result.object[0][1].uniq
      #  #if !candfound[candword] then
      #  #  candfound[candword] = 1
      #  #  @candidates << candword
      #  #end
      #  candidates << candword
      #}
      GyaimController.showCands(candidates) # AFMotionが非同期なのでここで更新!
    end
    candidates # ダミー (たぶん空配列が返る)
  end
  
  #
  # Google画像検索
  #
  def Google.searchImages(q)
    ids = []
    server = 'ajax.googleapis.com'
    command = "/ajax/services/search/images?q=#{q}&v=1.0&rsz=large&start=1"
    Net::HTTP.start(server, 80) {|http|
      response = http.get(command)
      json = BubbleWrap::JSON.parse(response.body)
      images = json['responseData']['results']
      images.each { |image|
        url = image['url']
        if id = Image.downloadImage(url) then
          ids << id
        end
      }
    }
    puts ids
    ids
  end

end

# Google Suggest API ... 何度も使ってると拒否られるようになった
#Net::HTTP.start('google.co.jp', 80) {|http|
#  response = http.get("/complete/search?output=toolbar&hl=ja&q=#{q}",header)
#  s = response.body.to_s
#  s = NKF.nkf('-w',s)
#  while s.sub!(/data="([^"]*)"\/>/,'') do
#    word = $1.split[0]
#    if !candfound[word] then
#      candfound[word] = 1
#      @candidates << word
#    end
#  end
#}

