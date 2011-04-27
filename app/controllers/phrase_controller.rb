require 'ruby-debug'
require 'json'

class PhraseController < ApplicationController

  before_filter :get_connections, :only => [:index, :create, :update]
  Vowels = ['aa', 'ae', 'ah', 'ao', 'aw', 'ay', 'eh', 'er', 'ey', 'ih', 'iy', 'ow', 'oy', 'uh', 'uw']
  def index
    #test(params[:q_phrase])

    phrase = params[:q_phrase]
    word_sym = @rhyme_coll.find("word" => phrase.split(" ")[-1]).first["symbols"]
    m = generate_map(word_sym)
    result = @lyrics_coll.map_reduce(generate_map(word_sym), generate_reduce)
    render :json => {:error => "what was a wierd tweet..."}, :status => 404 and return if result.find().count() == 0

    rand_result_phrase = result.find().skip(rand(result.count())).first
    lyric_phrase = @lyrics_coll.find("_id" => rand_result_phrase["_id"]).first 
    track = find_track(lyric_phrase["track"])
    render :json => {:phrase => rand_result_phrase["value"]["phrase"][0], :artist => track["artist_name"], :song => track["track_name"], :time => lyric_phrase["time"]} and return
  end

  def show

  end

private
  def get_connections
    @db = Mongo::Connection.new(ENV["MONGOHQ_URL"])["music_hack"]
    @rhyme_coll = @db["rhymes"]
    @lyrics_coll = @db["lyric_phrases"]
  end

  def find_track(track_id)
    url = "http://api.musixmatch.com/ws/1.1/track.get?apikey=0a8cf4250af67069563ff651c427aba8&track_id=#{track_id}&format=json"
    res = JSON.parse(Net::HTTP.get(URI.parse(url)))
    res["message"]["body"]["track"]
  end

  def generate_map(match_symbols)
    "function() {" + 
      "vowels = ['" + Vowels.join("','") + "']; "+ 
      "match_sym = ['" + match_symbols.join("','") + "']; " +
      "arr1 = match_sym;" +
      "arr2 = this.symbols;" +
      "while (arr1.length > 0 && arr2.length > 0) {" +
        "s1 = arr1.pop();" + 
        "s2 = arr2.pop();" +
        "if (s1 != s2) {" +
          "break;" +
        "}" +
        "else if (s1 == s2 && vowels.indexOf(s1) >= 0) {" +
          "emit(this._id, this.phrase);" +
          "break;" +
        "}" +
      "}" +
    "}"
  end

  def generate_reduce()
    "function(key, value) { return {phrase: value}}"
  end

  def test(term)
    docs = @db["lyric_phrases"].find().entries
    word = @db["rhymes"].find("word"=>term).first
    f_reverse = word["symbols"]
    phrases = docs.collect do |d|
      arr1 = d["symbols"]
      arr2 = Array.new(f_reverse)
      rhyme_phrase = nil
      while (arr1.length > 0 && arr2.length > 0)
        s1 = arr1.pop
        s2 = arr2.pop
        if (s1 != s2) 
          break
        elsif (s1 == s2 && Vowels.index(s1))
          rhyme_phrase = d
          break
        end
      end

      rhyme_phrase
    end.compact
    phrases.count
  end

  def recurse_find(ele, key)
    if ele.class == Array
      ele.each do |e|
        return recurse_find(e, key)
      end
    elsif ele.class == Hash
      ele.each do |k, v|
        if k == key
          return v
        elsif v.class == Array || v.class = Hash
          return recurse_find(v, key)
        end
      end 
    end
  end

end

