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
#
# == Author
#   Drew Harry
#
# == Copyright
#   Copyright (c) 2011 Drew Harry. 
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

require 'RMagick'
include Magick

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
    @options.gif_duration = 60*60*24*30
    @options.gif_steps = 60
    @options.set_status = false
    @options.status = false
    # TO DO - add additional defaults
  end

  # Parse options, check arguments, then process the command
  def run
        
    if parsed_options? && arguments_valid? 
      
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      if process_arguments == false
        return
      end
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

      opts.on('g', '--gif')         { @options.gif = true}
      
      # These are fancier gif options, but had trouble getting the
      # OptionParser to handle them properly. Not critical.
      # opts.on('-g', '--gif [steps,duration_in_days]') do |gif_options|
      #   @options.gif = true
      #   
      #   puts "gif_options: " + gif_options
      #   
      #   if gif_options == nil
      #     @options.gif_duration = 60*60*24*30
      #     @options.gif_steps = 60
      #   end
      #   
      #   gif_options_list = gif_options.split(",")
      #   @options.gif_steps=gif_options_list[0]
      #   if gif_options_list.length > 1
      #     @options.gif_duration = gif_options_list[1].to_i*60*60*24
      #   else
      #     @options.gif_duration = 60*60*24*30
      #   end
      # end
            
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
      # at this point, @arguments just has the stuff after all the options
      # have been parsed. The main option here is which frame generator
      # are we going to use.
      
      generator_name = @arguments[0]
      
      
      generators = {"gradient"=>GradientShiftFrameGenerator,
        "color"=>ColorShiftFrameGenerator}
      
      
      if(generators.keys.include? generator_name)
        @generator = generators[generator_name].new
      else
        puts "'#{generator_name}' is not a valid style. Valid options are:"
        generators.keys.each do |key|
          puts "\t#{key} - " + generators[key].info
        end
        return false
      end
      return true
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

      if @options.gif
        # If we're doing gif generation, it's going to be a totally different
        # flow from usual. Just loop through the images and accumulate an
        # ImageList.
        image_list = ImageList.new()

        start_time = Time.new.to_i
        cur_time = Time.new.to_i
        
        for i in 0..@options.gif_steps
          image_list << @generator.get_frame(cur_time)
          
          cur_time = cur_time + @options.gif_duration/@options.gif_steps
        end
        
        image_list.write("img/animated_#{start_time}.gif")
        return
      end


      begin
        consumer_auth = YAML.load(IO.read('app_credentials.yml'))
      rescue
        puts "Missing 'app_credentials.yml' file with consumer key and secret." unless @options.quiet
        return
      end
      

      @consumer=OAuth::Consumer.new consumer_auth[:consumer_key], 
                                         consumer_auth[:consumer_secret], 
                                         {:site=>"http://api.twitter.com"}
            
      begin
        puts "Loading user token and secret from file." if @options.verbose
        
        @auth = YAML.load(IO.read('user_credentials.yml'))
        token_hash = {:token => @auth[:token],
                      :token_secret => @auth[:token_secret]}

        access_token = OAuth::AccessToken.from_hash(@consumer, token_hash)
      
        # I know there's probably a way to merge keys in ruby, but I'm lazy
        @auth[:consumer_key] = consumer_auth[:consumer_key]
        @auth[:consumer_secret] = consumer_auth[:consumer_secret]
        
      rescue
        puts "Failed to load user token and secret, requesting authorization." if @options.verbose
        # If the load fails, we need to start the oob auth process. 
        # 1. Hit this url: https://api.twitter.com/oauth/request_token?oauth_callback=oob
        # 2. Take the request_token and construct a new URL: http://api.twitter.com/oauth/authorize?oauth_token=request_token
        # 3. Show that URL to the user and ask them to C&P it into a browser
        # 4. Prompt for them to enter the PIN
        # 5. POST (?) the PIN here: https://api.twitter.com/oauth/access_token 
      
        request_token = @consumer.get_request_token(:oauth_callback => "oob")
      
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
        @auth = consumer_auth.clone
        @auth[:token] = access_token.token
        @auth[:token_secret] = access_token.secret
      end
      
      
      # Need to figure out how to pull this from access_token but I'm a ruby
      # retard.
      # puts "loaded twitter info for #{twitter_config["username"]}"
      

      
      current_time = Time.new.to_i
      
      puts "Generating frame for time: #{current_time}" unless @options.quiet

      # The generator is set in process_arguments.
      image = @generator.get_frame(current_time)
      
      # bounce the produced image off a file
      # we'll want a flag here eventually that bounce them off tmp so 
      # they don't accumulate, but for now we can always store them.
      
      if image!=nil
        # write the image to disk
        image_file = "img/frame_#{current_time}.png"
        image.write(image_file)
      end

      if image_file==nil
        puts "Frame generator returned a nil image" unless @options.quiet
        return
      end

      #Actually do the request and print out the response
      if not @options.pretend
        
        update_profile_image(File.new(image_file))
        
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
    # def update_status_message(message)
    #       
    #       
    #       if message == nil
    #         message = "ding: #{Time.new.to_i}"
    #       end
    # 
    #       puts "Tweeting: " + message;
    # 
    #       url = URI.parse('http://twitter.com/statuses/update.json')
    #       Net::HTTP.new(url.host, url.port).start do |http| 
    #         req = Net::HTTP::Post.new(url.request_uri)
    #         req.basic_auth twitter_config["username"], twitter_config["password"]
    #         req.set_form_data({'status'=>message})
    #         res = http.request(req)
    # 
    #         if @options.verbose
    #           puts "Tweeting successful! Full response:"
    #           puts res.body
    #         end
    #         
    #       end
    #     end
    
    
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
    def add_oauth(req)
      access_token = OAuth::AccessToken.new(@consumer,@auth[:token],@auth[:token_secret])
      @consumer.sign!(req,access_token)
    end

    def update_profile_image(image_file)
      url = URI.parse('http://api.twitter.com/1/account/update_profile_image.json')
      Net::HTTP.new(url.host, url.port).start do |http| 
        req = Net::HTTP::Post.new(url.request_uri)
        add_multipart_data(req,:image=>image_file)
        add_oauth(req)
        res = http.request(req)
        puts res.body if @options.verbose
      end
    end
    
    
end



# Create and run the application
app = App.new(ARGV, STDIN)
app.run