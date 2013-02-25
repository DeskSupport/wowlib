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

    if method == :patch
      method = :post
      options = {"X-HTTP-Method-Override" => "PATCH"}
    end

    response = site[:access_token].request(method, URI.escape(site[:site_url]+uri), params, options)
    parser = Yajl::Parser.new
    json = parser.parse(response.body)

    if response.code == "200" || response.code == "201"
      return json
    else

      if (json['errors'])
        # Customer already exists or is invalid
        if (json['message'] == "Validation Failed" && json['errors']['emails'][0]['value'][0] == "taken") 
          #######system("say Email.")
          puts "Params sent: #{params}"
          puts "Response: #{json}"
          return json
        elsif (json['message'] == "Validation Failed" && json['errors']['emails'][0]['value'][0] == "invalid") 
          system("say Invalid email")
          puts "Params sent: #{params}"
          puts "Response: #{json}"
          json['errors'].each {|error| puts "Error from API: #{error}" }
          new_email = ask("Change email to:")
          new_params = Yajl::Parser.parse(params.strip)
          new_params["emails"] = [{:type=>"work",:value=>new_email}]
          new_params = Yajl::Encoder.encode(new_params)
          puts new_params
          return request(@site, :post, "/api/v2/customers", new_params)
        else
          puts "Params sent: #{params}"
          puts "Response: #{json}"
          json['errors'].each {|error| puts "Error from API: #{error}" }
          if (params.include? "addresses")
            system("say Address issue. Skipping.")
            return false
          elsif json['errors'][0] == "Email is invalid."
            system("say Fix the email")
            new_email = ask("Change email to:")
            params[:customer_email] = new_email
            return request(@site, :post, "/api/v1/interactions.json", params)
          else
            system("say Response needed")
            ask("Either press enter to skip or exit, fix, rerun.")
          end
          return false
        end
      elsif (json["error"])
        system("say Error")
        puts "Params sent: #{params}"
        puts "Response: #{json}"
        #return "ratelimited"
        raise "API ERROR"
      else
        system("say Fatal")
        puts "Unsure how to handle response!"
        puts "Params sent: #{params}"
        puts "Response: #{response.body}"
        puts "Exiting"
        exit
      end

    end

  rescue => e
    puts "Params sent: #{params}"
          puts "Response: #{json}"
    system("say Retrying")
    puts "Exception: #{e}"
    print "Going to retry in 3 seconds"
    sleep(1)
    print "."
    sleep(1)
    print "."
    sleep(1)
    print ".\n"
    retry
  end
end

def log(message)
  puts message
  File.open("wowlib.log", 'a') {|f| f.write("#{message}\n") }
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