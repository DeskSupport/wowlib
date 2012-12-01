# encoding: utf-8

# Wow Dev Standard Library
# Last updated: 11/8/2012

require 'nokogiri'
require 'rubygems'
require 'open-uri'
require 'json'
require 'oauth'
require 'yajl'
require 'yaml'
require "highline/import"
require 'aws-sdk'
require "open-uri"
require "time"

@libmsg = "# "
@prompt = "    > "

system("clear")
puts " _ _ _           _ _ _   \n| | | |___ _ _ _| |_| |_ \n| | | | . | | | | | | . |\n|_____|___|_____|_|_|___|"
puts "\"I gotta have more wowbell!\"\n\n"

# Exchange api keys for an access token instance to perform api requests
def selectSite(site_name)
  site = {}
  path = "#{File.dirname(__FILE__)}/api_keys/#{site_name}.txt"
  begin
    file = File.open(path, "r") #read-only
  rescue => e
    txt = ""
    puts "#{@libmsg}No API key on file for Desk site \"#{site_name}\". Shall we create one?\n\n"
    puts "#{@prompt}Site URL: https://#{site_name}.desk.com"
    site[:site_url] = "https://#{site_name}.desk.com"
    site[:consumer_key] = ask("#{@prompt}Consumer key (\"API App Key\"): ")
    site[:consumer_secret] = ask("#{@prompt}Consumer token (\"API App Secret\"): ")
    site[:token] = ask("#{@prompt}Your Token: ")
    site[:token_secret] = ask("#{@prompt}Your Token Secret: ")
    site.each do |key, value|
      txt += "#{value}\n"
    end
    aFile = File.new("#{File.dirname(__FILE__)}/api_keys/#{site_name}.txt", "w")
    aFile.write(txt)
    aFile.close
    puts "\n#{@libmsg}Cool. I'll remember that.\n\n"
    retry
  end
  site[:site_name] = site_name
  file.each_with_index do |line, i|
    if (i == 0) then site[:site_url] = line.chomp end
    if (i == 1) then site[:consumer_key] = line.chomp end
    if (i == 2) then site[:consumer_secret] = line.chomp end
    if (i == 3) then site[:token] = line.chomp end
    if (i == 4) then site[:token_secret] = line.chomp end
  end
  site[:access_token] = getToken(site)
  return site
end

def getToken(site)
  site_consumer = OAuth::Consumer.new(site[:consumer_key], site[:consumer_secret], { :site => site[:site_url], :scheme => :header })
  site_token = OAuth::AccessToken.from_hash(site_consumer,
      :oauth_token => site[:token], :oauth_token_secret => site[:token_secret])
  return site_token
end

def parse(response)
  Yajl::Parser.parse(response.body)
end

def encode(obj)
  Yajl::Encoder.encode(obj)
end

def request(site, method, uri, params = {})
  begin
    response = site[:access_token].request(method, URI.escape(site[:site_url]+uri), params)
    parser = Yajl::Parser.new
    json = parser.parse(response.body)

    if response.code == "200"
      return json
    elsif json["error"] == "rate_limit_exceeded"
       puts response
       puts "Waiting for rate limit"
       sleep 1
       return "ratelimited"
    else
      puts "ERROR: #{response.body}"
      json['errors'].each {|error| puts "ERROR MESSAGE: #{error}" }
      return json
    end
  rescue => e
    puts "Encountered an error while communicating with Desk API: #{e}"
    puts "Taking a 1 second nap before retrying..."
    sleep(1)
    retry
  end
end

def dump(output, path)
  aFile = File.new(path, "w")
  res = aFile.write(output)
  aFile.close
  if res
    puts "Data saved to \"#{path}\".\n\n"
    return true
  else
    puts "Error saving to \"#{path}\".\n\n"
    return false
  end
end