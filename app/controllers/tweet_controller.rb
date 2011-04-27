require 'json'
require 'lib/find_rhyme'
require 'twitter'

class TweetController < ApplicationController
  before_filter :get_connections, :only => [:index, :rhyme]

  def index
    @tweet_and_rhyme = @tweet_coll.find().sort(["_id", 'descending']).entries.collect do |tweet|
      tweet["tweet"]["profile_image_url"] = Twitter.user(tweet["tweet"]["user"])
      tweet
    end
  end

  def rhyme
    text = params["tweet_field"]
    rand_result_phrase = Rhymer.find_rhyme(text)
    if !rand_result_phrase
      flash[:error] = "This tweet is too damn hard!" 
    else
      lyric_phrase = @lyrics_coll.find("_id" => rand_result_phrase).first
      track = Rhymer.find_track_info(lyric_phrase["track"])
      tweet_hash = {
        :tweet => {:text => text, :user => "ericxtang"}, 
        :rhyme => {:phrase => lyric_phrase["phrase"], :artist => track["artist_name"], :song => track["track_name"], :time => lyric_phrase["time"]}
      }
      @tweet_coll.save(tweet_hash)
    end

    redirect_to :action => :index
  end

private

  def get_connections
    @db = Mongo::Connection.new(ENV["MONGOHQ_URL"])["music_hack"]
    @rhyme_coll = @db["rhymes"]
    @lyrics_coll = @db["lyric_phrases"]
    @tweet_coll = @db["tweet_and_rhyme"]
  end

  def transform_keys_to_symbols(value)
    return value if not value.is_a?(Hash)
    hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
    return hash
  end

end
