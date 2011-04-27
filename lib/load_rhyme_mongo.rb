require 'uri'
require 'mongo'
require 'active_support/core_ext/object/blank'
require 'cgi'
require 'net/https'
require 'json'
require 'open-uri'

@db = Mongo::Connection.new("localhost", 27017)["music_hack"]
@coll = @db["rhymes"]

dict_url = "https://cmusphinx.svn.sourceforge.net/svnroot/cmusphinx/trunk/cmudict/cmudict.0.7a"
f = open dict_url
lines = []
while (line = f.gets)
  lines << line.split(" ") if line =~ /^\w/
end

lines.each do |l|
    symbols = l[1..-1].join(" ")
    @coll.insert({:word => l[0].downcase, :symbols => symbols.gsub(/\d/, "").downcase.split(" ")})
end
