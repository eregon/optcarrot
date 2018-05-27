require "io/console"
require "io/wait"

module Optcarrot
  # Input driver for terminal (this is a joke feature)
  class TermInput < Input
    def init
      $stdin.raw!
      $stdin.getc if $stdin.ready?
      @escape = false
      @ticks = { start: 0, select: 0, a: 0, b: 0, right: 0, left: 0, down: 0, up: 0,
                 screen_x1: 0, screen_x2: 0, screen_x3: 0, screen_full: 0 }
    end

    def dispose
      $stdin.cooked!
      super()
    end

    def keydown(pads, code, frame)
      event(pads, :keydown, code, 0)
      @ticks[code] = frame
    end

    def tick(frame, pads)
      while $stdin.ready?
        ch = $stdin.getbyte
        if @escape
          @escape = false
          case ch
          when 0x5b then @escape = true
          when 0x41 then keydown(pads, :up, frame)
          when 0x42 then keydown(pads, :down, frame)
          when 0x43 then keydown(pads, :right, frame)
          when 0x44 then keydown(pads, :left, frame)
          end
        else
          case ch
          when 0x1b then @escape = true
          when 0x58, 0x78 then keydown(pads, :a, frame)
          when 0x5a, 0x73 then keydown(pads, :b, frame)
          when 0x0d       then keydown(pads, :select, frame)
          when 0x20       then keydown(pads, :start, frame)
          when 0x51, 0x71 then exit
          when 0x31 then keydown(pads, :screen_x1, frame) # `1'
          when 0x32 then keydown(pads, :screen_x2, frame) # `2'
          when 0x33 then keydown(pads, :screen_x3, frame) # `3'
          when 0x34 then keydown(pads, :screen_x4, frame) # `4'
          when 0x35 then keydown(pads, :screen_x5, frame) # `5'
          when 0x36 then keydown(pads, :screen_x6, frame) # `6'
          when 0x37 then keydown(pads, :screen_x7, frame) # `7'
          when 0x66 then keydown(pads, :screen_full, frame) # `f'
          end
        end
      end

      @ticks.each do |code, prev_frame|
        event(pads, :keyup, code, 0) if prev_frame + 5 == frame
      end

      super(frame, pads)
    end
  end
end
