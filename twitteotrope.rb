#!/usr/bin/env ruby
# twitteotrope - a system for programmatically updating your twitter icon
#
# Drew Harry / Sept 2009

# The vast majority of this code is taken from Hayes Davis' wonderful code snippet:
# http://gist.github.com/97756

# This script performs an OAuth authorized POST with multipart encoding to 
# http://twitter.com/account/update_profile_image.json
# 
# This code is primarily taken from my Grackle library's implementation at
# http://github.com/hayesdavis/grackle
#
#
#
# twitter.yml format:
# username: USERNAME
# password: PASSWORD

require 'rubygems'
require 'oauth'
require 'open-uri'
require 'net/http'
require 'yaml'
require 'cgi'

# this is the template that all generators need to follow.
# given a time (seconds since epoch) return an image file.
# this is a toy one - just generate a solid color background
# image. 

class AnimationFrameGenerator
  def get_frame(time)
    puts "Invalid frame generator. You must use a class that extends this and provides a non-empty implementation."
    return nil
  end
end


require 'color_shifter'

CRLF = "\r\n"

puts "twitteotrope v0.1 // drew harry sept 2009"

begin
  twitter_config = YAML.load(IO.read('twitter.yml'))
rescue
  puts "You must have a twitter.yml file present with twitter login info."
end

puts "loaded twitter info for #{twitter_config["username"]}"

# frameGenerator = "twitteotrope::plugins::ColorShiftFrameGenerator"
# if ARGV.size == 1
#   frameGenerator = ARGV[0]
# end
# 
# puts "using frame generator: #{frameGenerator}"

frame_generator = ColorShiftFrameGenerator.new()

#Quick and dirty method for determining mime type of uploaded file
def mime_type(file)
  case 
    when file =~ /\.jpg/ then 'image/jpg'
    when file =~ /\.gif$/ then 'image/gif'
    when file =~ /\.png$/ then 'image/png'
    else 'application/octet-stream'
  end
end

#Encodes the request as multipart
def add_multipart_data(req,params)
  boundary = Time.now.to_i.to_s(16)
  req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
  body = ""
  params.each do |key,value|
    esc_key = CGI.escape(key.to_s)
    body << "--#{boundary}#{CRLF}"
    if value.respond_to?(:read)
      body << "Content-Disposition: form-data; name=\"#{esc_key}\"; filename=\"#{File.basename(value.path)}\"#{CRLF}"
      body << "Content-Type: #{mime_type(value.path)}#{CRLF*2}"
      body << value.read
    else
      body << "Content-Disposition: form-data; name=\"#{esc_key}\"#{CRLF*2}#{value}"
    end
    body << CRLF
  end
  body << "--#{boundary}--#{CRLF*2}"
  req.body = body
  req["Content-Length"] = req.body.size
end



puts "Generating frame for time: #{Time.new.to_i}"

image_file = File.new(frame_generator.get_frame(Time.new.to_i))

if image_file==nil
  puts "frame generator returned a nil image"
  return
end

#Actually do the request and print out the response
url = URI.parse('http://twitter.com/account/update_profile_image.json')
Net::HTTP.new(url.host, url.port).start do |http| 
  req = Net::HTTP::Post.new(url.request_uri)
  add_multipart_data(req,:image=>image_file)
  req.basic_auth twitter_config["username"], twitter_config["password"]
  res = http.request(req)
  puts res.body
  
  # do some better success/failure sensing here. 
end


url = URI.parse('http://twitter.com/statuses/update.json')
Net::HTTP.new(url.host, url.port).start do |http| 
  req = Net::HTTP::Post.new(url.request_uri)
  req.basic_auth twitter_config["username"], twitter_config["password"]
  req.set_form_data({'status'=>"ding: #{Time.new.to_i}"})
  res = http.request(req)
  puts res.body
end
