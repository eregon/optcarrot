require_relative "sdl2"
require_relative "misc"

module Optcarrot
  # Video output driver for SDL2
  class SDL2Video < Video
    def init
      super

      SDL2.InitSubSystem(SDL2::INIT_VIDEO)
      @ticks_log = [0] * 11
      @buf = FFI::MemoryPointer.new(:uint32, WIDTH * HEIGHT)
      @titles = (0..500).map {|n| "optcarrot on #{RUBY_ENGINE} (%d fps)" % n }

      @window =
        SDL2.CreateWindow(
          "optcarrot",
          SDL2::WINDOWPOS_UNDEFINED,
          SDL2::WINDOWPOS_UNDEFINED,
          TV_WIDTH, HEIGHT,
          SDL2::WINDOW_RESIZABLE
        )
      @renderer = SDL2.CreateRenderer(@window, -1, 0)
      SDL2.SetHint("SDL_RENDER_SCALE_QUALITY", "linear")
      SDL2.RenderSetLogicalSize(@renderer, TV_WIDTH, HEIGHT)
      @texture = SDL2.CreateTexture(
        @renderer,
        SDL2::PIXELFORMAT_8888,
        SDL2::TEXTUREACCESS_STREAMING,
        WIDTH, HEIGHT
      )

      width, height, pixels = Driver.icon_data
      @icon = SDL2.CreateRGBSurfaceFrom(pixels, width, height, 32, width * 4, 0x0000ff, 0x00ff00, 0xff0000, 0xff000000)
      SDL2.SetWindowIcon(@window, @icon)

      @palette = @palette_rgb.map do |r, g, b|
        0xff000000 | (r << 16) | (g << 8) | b
      end

      change_window_size(3) if ENV["RECORD"]
    end

    def change_window_size(scale)
      if scale
        SDL2.SetWindowFullscreen(@window, 0)
        SDL2.SetWindowSize(@window, TV_WIDTH * scale, HEIGHT * scale)
      elsif SDL2.GetWindowFlags(@window) & SDL2::WINDOW_FULLSCREEN_DESKTOP != 0
        SDL2.SetWindowFullscreen(@window, 0)
      else
        SDL2.SetWindowFullscreen(@window, SDL2::WINDOW_FULLSCREEN_DESKTOP)
      end
    end

    def dispose
      SDL2.FreeSurface(@icon)
      SDL2.DestroyTexture(@texture)
      SDL2.DestroyRenderer(@renderer)
      SDL2.DestroyWindow(@window)
      SDL2.QuitSubSystem(SDL2::INIT_VIDEO)
    end

    def tick(colors)
      fps = super(colors)
      fps = 500 if fps > 500

      SDL2.SetWindowTitle(@window, @titles[fps])

      Driver.cutoff_overscan(colors)
      Driver.show_fps(colors, fps, @palette) if @conf.show_fps

      @buf.write_array_of_uint32(colors)

      SDL2.UpdateTexture(@texture, nil, @buf, WIDTH * 4)
      SDL2.RenderClear(@renderer)
      SDL2.RenderCopy(@renderer, @texture, nil, nil)
      SDL2.RenderPresent(@renderer)

      fps
    end
  end
end
