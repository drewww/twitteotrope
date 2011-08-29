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

require 'frame_generators.rb'


# frame generator classes
# require 'color_shifter'

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

      begin
        consumer_auth = YAML.load(IO.read('app_credentials.yml'))
      rescue
        puts "Missing 'oauth.yml' file with consumer key and secret."
        return
      end
      

      consumer=OAuth::Consumer.new consumer_auth["consumer_key"], 
                                   consumer_auth["consumer_secret"], 
                                   {:site=>"https://api.twitter.com"}

      begin
        auth = YAML.load(IO.read('user_credentials.yml'))
        token_hash = {:token => auth["token"],
                      :token_secret => auth["token_secret"]}
        access_token = OAuth::AccessToken.from_hash(consumer, token_hash)
        
        # I know there's probably a way to merge keys in ruby, but I'm lazy
        auth[:consumer_key] = consumer_auth["consumer_key"]
        auth[:consumer_secret] = consumer_auth["consumer_secret"]
        
      rescue
        
        # If the load fails, we need to start the oob auth process. 
        # 1. Hit this url: https://api.twitter.com/oauth/request_token?oauth_callback=oob
        # 2. Take the request_token and construct a new URL: http://api.twitter.com/oauth/authorize?oauth_token=request_token
        # 3. Show that URL to the user and ask them to C&P it into a browser
        # 4. Prompt for them to enter the PIN
        # 5. POST (?) the PIN here: https://api.twitter.com/oauth/access_token 
        
        request_token = consumer.get_request_token(:oauth_callback => "oob")
        
        puts "Load this URL in a browser: " + request_token.authorize_url
        print "Enter PIN: "
        pin = gets.chomp
        
        access_token = request_token.get_access_token(:oauth_verifier => pin)
        
        f = File.open("user_credentials.yml", 'w')
        f.write(YAML.dump(
            {:token => access_token.token,
             :token_secret => access_token.secret}))
        f.close
        
        # this is silly and gross but whatever. I'm a nub.
        auth = {}
        auth[:consumer_key] = consumer_auth["consumer_key"]
        auth[:consumer_secret] = consumer_auth["consumer_secret"]
        auth[:token] = access_token.token
        auth[:token_secret] = access_token.secret
      end
      
      
      
      # we come out of this block with access_token for sure having what we 
      # need to run future requests.

      # begin
      #   twitter_config = YAML.load(IO.read('twitter.yml'))
      # rescue
      #   puts "You must have a twitter.yml file present with twitter login info."
      # end

      # Need to figure out how to pull this from access_token but I'm a ruby
      # retard.
      # puts "loaded twitter info for #{twitter_config["username"]}"

      frame_generator = ColorShiftFrameGenerator.new()
      
      current_time = Time.new.to_i
      
      puts "Generating frame for time: #{current_time}"

      image = frame_generator.get_frame(current_time)
      
      # bounce the produced image off a file
      # we'll want a flag here eventually that bounce them off tmp so 
      # they don't accumulate, but for now we can always store them.
      
      if image!=nil
        # write the image to disk
        image_file = "img/frame_#{current_time}.png"
        image.write(image_file)
      end

      if image_file==nil
        puts "Frame generator returned a nil image"
        return
      end

      #Actually do the request and print out the response
      if not @options.pretend
        
        puts "Uploading new profile picture."
        
        url = URI.parse('https://twitter.com/account/update_profile_image.json')
        Net::HTTP.new(url.host, url.port).start do |http| 
          req = Net::HTTP::Post.new(url.request_uri)
          add_multipart_data(req,:image=>image_file)
          add_oauth(req, auth)
        
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

# This code from this gist: https://gist.github.com/97756

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

#Uses the OAuth gem to add the signed Authorization header
def add_oauth(req, auth)
  consumer = OAuth::Consumer.new(
    auth[:consumer_key],auth[:consumer_secret],{:site=>'https://twitter.com'}
  )
  access_token = OAuth::AccessToken.new(consumer,auth[:token],auth[:token_secret])
  consumer.sign!(req,access_token)
end


# Create and run the application
app = App.new(ARGV, STDIN)
app.run