require 'uri'
require 'mongo'
require 'active_support/core_ext/object/blank'
require 'cgi'
require 'net/https'
require 'json'
require 'open-uri'

@db = Mongo::Connection.new("localhost", 27017)["music_hack"]
#db = CouchRest.database!("#{ENV['CLOUDANT_URL']}/lyric_phrases")
@rhyme_coll = @db["rhymes"]
@lyric_coll = @db["lyrics"]
@phrase_coll = @db["lyric_phrases"]
@crawl_coll = @db["subtitle_crawl_list"]

def find_lyric(track_id)
  url = "http://api.musixmatch.com/ws/1.1/track.subtitle.get?track_id=#{track_id}&format=json&apikey=#{ENV['MUSIXMATCH_API_KEY']}"
  res = JSON.parse(Net::HTTP.get(URI.parse(url)))
  res["message"]["body"]["subtitle"]["subtitle_body"] if res["message"] && res["message"]["header"]["status_code"] == 200 && res["message"]["body"] && res["message"]["body"]["subtitle"] && res["message"]["body"]["subtitle"]["subtitle_body"]
end

def load_subtitle_phrases(track_id, phrases)
  last_phrase_id = nil
  phrases.each do |phrase|
    if phrase =~ /\[\d\d:\d\d./
      time = phrase.scan(/\[\d\d:\d\d.*\]/)
      phrase.gsub!(/\[\d\d:\d\d.*\]/, "")

      phrase_symbols = phrase.split(/\s|\W/).collect do |word|
        if (word =~ /^\w*$/)
          rhyme_word = @rhyme_coll.find("word" => word.downcase).first
          rhyme_word["symbols"] if rhyme_word
        end
      end.join(" ")

      if !phrase_symbols.blank?
        last_phrase_id = @phrase_coll.insert({:last_phrase => last_phrase_id, :track => track_id, :phrase => phrase, :time => time, :symbols => phrase_symbols.split(" "), :symbols_length => phrase_symbols.split(" ").count})
      end
    end
  end
  true
end


def load_crawl_list
  f = File.open("load_track_ids.txt", "r")
  #track_id = 3355996
  while (l = f.gets)
    track_id = l.to_i
    @crawl_coll.insert({:track_id => track_id})
  end
end

@crawl_coll.find().entries.each do |entry|
  lyric = find_lyric(entry["track_id"])
  if !lyric.blank?
    @lyric_coll.save(lyric)
    @crawl_coll.remove(entry)
  else
    puts "failed: #{entry}"
    @db["failed_crawl"].insert(entry)
  end

end

@lyric_coll.find().entries.each do |lyric|
  phrases = lyric[""].split("\r\n") #XXX find out the key
  #XXX
  if load_subtitle_phrases(lyric["track_id"], phrases)
    puts entry
  else
  end
end

#XXX Not using this right now.  Using load_subtitle_phrases instead
def load_lyrics_phrases(track_id, phrases)
  phrases.each do |phrase|
    if phrase =~ /^\w/
      phrase_symbols = phrase.split(/\s|\W/).collect do |word|
        if (word =~ /^\w*$/)
          rhyme_word = @rhyme_coll.find("word" => word.downcase).first
          rhyme_word["symbols"] if rhyme_word
        else
          "-1"
        end
      end.join(" ")

      if !phrase_symbols.index("-1")
        @phrase_coll.insert({:track => track_id, :phrase => phrase, :symbols => phrase_symbols.split(" "), :symbols_length => phrase_symbols.split(" ").count})
      end
    end
  end
end

