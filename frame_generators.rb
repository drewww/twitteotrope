# A trivial FrameGenerator that generates single-colored frames based on the time
require 'RMagick'

include Magick

WIDTH = 200
HEIGHT = 200

class AnimationFrameGenerator

  def initialize(force=false)
    
    if force
      set_defaults()
    else
      begin
        @state = YAML.load(IO.read(self.class.name + ".yml"))
      rescue
        puts "Initializing frame generator defaults."
        set_defaults()
      end
    end
  end
    
  def set_defaults
    # override this method if you have important defaults.
    
    self.write_state
  end
  
  def write_state
    File.open(self.class.name + ".yml", 'w') do |f|
      f.write(YAML.dump(@state))
      f.close
    end
  end

  def get_frame(time)
    puts "Invalid frame generator. You must use a class that extends this and provides a non-empty implementation."
    return nil
  end
end

# Some ideas:
# 1. Pan through an image. Either bounce off edges or wrap around. 
# 2. Scroll text 
# 3. Unspool an animated gif
# 4. Move through a gradient space.


class GradientShiftFrameGenerator < AnimationFrameGenerator
  
  def initialize(force=false)
    super(force)
  end
  
  def set_defaults
    @state = {}
    @state[:start_time] = Time.new.to_i
    
    # repeat on a one day period
    @state[:period] = 60*60*24*30
    super
  end
  
  
  def get_frame(time)
    puts "start_time: #{@state[:start_time]}  cur_time: #{time} -: #{time - @state[:start_time]}"
    
    # figures out where we are within the period (normalized)
    hue_normalized = (((time - @state[:start_time]) % @state[:period]) / @state[:period].to_f)
    hue_lower = (hue_normalized-0.05)*360
    hue_upper = (hue_normalized+0.05)*360
    
    grad = GradientFill.new(0, 0, WIDTH, 0, "hsl(#{hue_upper}, 41, 69)",
      "hsl(#{hue_lower}, 41, 69)")
    
    puts "hue_normalized: #{hue_normalized}"
    
    frame = Image.new(WIDTH, HEIGHT, grad)
    
    return frame
  end
  
end



class ColorShiftFrameGenerator < AnimationFrameGenerator
  
  
  def initialize
    # the number of seconds to go through the entire hue cycle
    # for now make this 1 day for reasonable fast testing.
    @seconds_per_cycle = 60 * 60 * 25 * 1 * 1
  end
  
  def get_frame(time)
    
    # this is dumb - should pass in a real time object.
    full_time = Time.at(time)
    
    
    hue = ((time % @seconds_per_cycle) / @seconds_per_cycle.to_f) * 360
    puts "cur hue: #{hue}"
    
    image = Image.new(200,200) {self.background_color = "hsl(#{hue}, 41, 69)"}
    image.format = "png"
    
    # now write some identifying information on the frame so we can track
    # when clients update it.
    text = Magick::Draw.new
    
    text.annotate(image, 0, 0, 10, 10, full_time.strftime("%d")) {
        self.gravity = Magick::NorthGravity
        self.pointsize = 72
        self.stroke = 'transparent'
        self.fill = '#FFFFFF'
        self.font_weight = Magick::BoldWeight
        }

    text.annotate(image, 0, 0, 0, 0, full_time.strftime("%H.%M")) {
        self.gravity = Magick::SouthGravity
        self.pointsize = 72
        self.stroke = 'transparent'
        self.fill = '#FFFFFF'
        self.font_weight = Magick::BoldWeight
        }

    
    # text.font_family = 'helvetica'
    # text.pointsize = 18
    # text.fill = "white"
    # 
    # # text.gravity = Magick::CenterGravity
    # text.text(10, 10, full_time.strftime("%d"))
    # text.text(10, 30, full_time.strftime("%H.%M"))

    # filename = "frame_#{time}.png"
    # image.write(filename)
    
    return image
  end
  
end
