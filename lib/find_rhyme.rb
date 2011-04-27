module Rhymer
  Vowels = ['aa', 'ae', 'ah', 'ao', 'aw', 'ay', 'eh', 'er', 'ey', 'ih', 'iy', 'ow', 'oy', 'uh', 'uw']

  def self.find_rhyme(phrase)
    @db = Mongo::Connection.new("localhost", 27017)["music_hack"]
    @rhyme_coll = @db["rhymes"]
    @lyrics_coll = @db["lyric_phrases"]
    @tweet_coll = @db["tweet"]

    if (word = @rhyme_coll.find("word" => phrase.split(" ")[-1]).first)
      word_sym = @rhyme_coll.find("word" => phrase.split(" ")[-1]).first["symbols"]
      result = @lyrics_coll.map_reduce(generate_map(phrase.split(" ")[-1], word_sym), generate_reduce)
      if (result.find().count > 0)
        res = result.find().entries.max_by {|r| r["_id"]}
        res = flatten_result(result.find().entries[0], BSON::ObjectId)
        return res[rand(res.count())]
      end
    end
    nil
  end

  def self.find_track_info(track_id)
    url = "http://api.musixmatch.com/ws/1.1/track.get?apikey=#{ENV["MUSIXMATCH_API_KEY"]}&track_id=#{track_id}&format=json"
    res = JSON.parse(Net::HTTP.get(URI.parse(url)))
    res["message"]["body"]["track"] if res["message"]["header"]["status_code"] == 200
  end

  def self.generate_map(word, match_symbols)
    "function() {" + 
      "vowels = ['#{Vowels.join("','")}']; "+ 
      "match_sym = ['#{match_symbols.join("','")}']; " +
      "word = '#{word}';" +
      "phrase_words = this.phrase.split(' ');" +
      "if (word == phrase_words[phrase_words.length - 1]) {" +
        "return;" +
      "}" +
      "arr1 = match_sym;" +
      "arr2 = this.symbols;" +
      "ct = 0;" +
      "rhyme = false;" +
      "while (arr1.length > 0 && arr2.length > 0) {" +
        "s1 = arr1.pop();" + 
        "s2 = arr2.pop();" +
        "if (s1 != s2) {" +
          "if (rhyme == true) {" +
            "emit(ct, this._id);" +
          "}" +
          "break;" +
        "}" +
        "else if (s1 == s2 && vowels.indexOf(s1) >= 0) {" +
          "rhyme = true;" +
        "}" +
        "ct++;" +
      "}" +
    "}"
  end

  def self.generate_reduce()
    "function(key, values) { return { value : values};}"
  end

  def self.flatten_result(elem, type)
    if (elem.is_a? Array)
      ret_arr = []
      elem.each do |e| 
        ret_arr << e if e.class == type
        ret_arr += flatten_result(e, type) if (e.is_a? Array) || (e.is_a? Hash)
      end 
      ret_arr
    elsif (elem.is_a? Hash)
      ret_arr = []
      elem.each do |key, val|
        ret_arr << val if val.class == type
        ret_arr += flatten_result(val, type) if (val.is_a? Array) || (val.is_a? Hash)
      end
      ret_arr
    end
  end

end
