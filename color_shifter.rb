# A trivial FrameGenerator that generates single-colored frames based on the time
require 'RMagick'

include Magick


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

    filename = "frame_#{time}.png"
    image.write(filename)
    
    return filename
  end
end
