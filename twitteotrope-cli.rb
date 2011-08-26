#!/usr/bin/env ruby 

# == Synopsis 
# twitteotrope is a system for programmatically updating your twitter icon
#
# == Examples
#   This command does blah blah blah.
#     twitteotrope foo.txt
#
#   Other examples:
#     twitteotrope -q bar.doc
#     twitteotrope --verbose foo.html
#
# == Usage 
#   twitteotrope [options] source_file
#
#   For help use: twitteotrope -h
#
# == Options
#
#
#   -p, --pretend           Do the frame generation, but don't upload it.
#   -s, --status [STATUS]   Update the status on this account, too. 
#   -g, --gif               Generate an animated GIF that simulates the frame generator. 
#   -h, --help              Displays help message
#   -v, --version           Display the version, then exit
#   -q, --quiet             Output as little as possible, overrides verbose
#   -V, --verbose           Verbose output
#   TODO - add additional options
#
# == Author
#   Drew Harry
#
# == Copyright
#   Copyright (c) 2009 Drew Harry. 
#   TODO add license

# cli structure requirements
require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
#require 'date'

# application requirements
require 'rubygems'
require 'oauth'
require 'open-uri'
require 'net/http'
require 'yaml'
require 'cgi'


class AnimationFrameGenerator
  def get_frame(time)
    puts "Invalid frame generator. You must use a class that extends this and provides a non-empty implementation."
    return nil
  end
end

# frame generator classes
require 'color_shifter'

CRLF = "\r\n"

class App
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
    @options.pretend = false
    @options.gif = false
    @options.set_status = false
    # TO DO - add additional defaults
  end

  # Parse options, check arguments, then process the command
  def run
        
    if parsed_options? && arguments_valid? 
      
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      process_arguments            
      process_command
      
      puts "\nFinished at #{DateTime.now}" if @options.verbose
      
    else
      output_usage
    end
      
  end
  
  protected
  
    def parsed_options?
      
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')    { output_version ; exit 0 }
      opts.on('-h', '--help')       { output_help }
      opts.on('-V', '--verbose')    { @options.verbose = true }  
      opts.on('-q', '--quiet')      { @options.quiet = true }
      opts.on('-p', '--pretend')    { @options.pretend = true}
      opts.on('-s', '--status [STATUS]') do |status| 
        @options.set_status = true
        @options.status = status
      end
        
      opts.on('-g', '--gif')
      # TO DO - add additional options
            
      opts.parse!(@arguments) rescue return false
      
      process_options
      true      
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "  #{name} = #{val}"
      end
    end

    # True if required arguments were provided
    def arguments_valid?
      # right now, there is no set of invalid arguments.
      # (can I really just say true here? I don't have to return something?)
      true unless (@options.set_status == true and @options.status == nil)
    end
    
    # Setup the arguments
    def process_arguments
      # TO DO - place in local vars, etc
      # not sure what I do here versus in the opts setup blocks thing
    end
    
    def output_help
      output_version
      RDoc::usage() #exits app
    end
    
    def output_usage
      RDoc::usage('usage') # gets usage from comments above
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    def process_command
      # TO DO - do whatever this app does

      begin
        twitter_config = YAML.load(IO.read('twitter.yml'))
      rescue
        puts "You must have a twitter.yml file present with twitter login info."
      end

      puts "loaded twitter info for #{twitter_config["username"]}"

      frame_generator = ColorShiftFrameGenerator.new()
      
      puts "Generating frame for time: #{Time.new.to_i}"

      image_file = File.new(frame_generator.get_frame(Time.new.to_i))

      if image_file==nil
        puts "Frame generator returned a nil image"
        return
      end

      #Actually do the request and print out the response
      if not @options.pretend
        
        puts "Uploading new profile picture."
        
        url = URI.parse('http://twitter.com/account/update_profile_image.json')
        Net::HTTP.new(url.host, url.port).start do |http| 
          req = Net::HTTP::Post.new(url.request_uri)
          add_multipart_data(req,:image=>image_file)
          req.basic_auth twitter_config["username"], twitter_config["password"]
        
          res = http.request(req)
        
          puts res.body if @options.verbose 
          # do some better success/failure sensing here. 
        end
        
        if @options.set_status
          update_status_message(@options.status)
        end
        
      end
      
      
      #process_standard_input # [Optional]
    end

    def process_standard_input
      input = @stdin.read      
      # TO DO - process input
      
      # [Optional]
      # @stdin.each do |line| 
      #  # TO DO - process each line
      #end
    end
    
    
    
    # in the app proper so it has access to the @options
    # member variable
    def update_status_message(message)
      
      
      if message == nil
        message = "ding: #{Time.new.to_i}"
      end

      puts "Tweeting: " + message;

      url = URI.parse('http://twitter.com/statuses/update.json')
      Net::HTTP.new(url.host, url.port).start do |http| 
        req = Net::HTTP::Post.new(url.request_uri)
        req.basic_auth twitter_config["username"], twitter_config["password"]
        req.set_form_data({'status'=>message})
        res = http.request(req)

        if @options.verbose
          puts "Tweeting successful! Full response:"
          puts res.body if @options.verbose 
        end
        
      end
    end
end


# TO DO - Add your Modules, Classes, etc


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


# Create and run the application
app = App.new(ARGV, STDIN)
app.run