module Optcarrot
class PPU
### main-loop structure
#
# # wait for boot
# clk_685
#
# loop do
#   # pre-render scanline
#   clk_341, clk_342, ..., clk_659
#   while true
#     # visible scanline (not shown)
#     clk_320, clk_321, ..., clk_337
#
#     # increment scanline
#     clk_338
#     break if @scanline == 240
#
#     # visible scanline (shown)
#     clk_0, clk_1, ..., clk_319
#   end
#
#   # post-render sacnline (vblank)
#   do_681,682,684
# end
#
# This method definition also serves as a template for OptimizedCodeBuilder.
# Comments like "when NNN" are markers for the purpose.
def main_loop
  # when 685

  # wait for boot
  boot
  wait_frame

  while true
    if @hclk == 341 and @hclk_target == FOREVER_CLOCK
      # @any_show is on in all frames - 6
      optimized_loop_body
      wait_frame
    else
      # Only 3 / 1000
      main_loop_body
    end
  end
end

$counter = 0
at_exit { p [:counter, $counter] }

def optimized_loop_body
  # pre-render scanline

  @sp_overflow = @sp_zero_hit = @vblanking = @vblank = false
  @scanline = SCANLINE_HDUMMY

  32.times do # 341.step(589, 8) do
    # when 341, 349, ..., 589
    open_name
    @hclk += 2

    # when 343, 351, ..., 591
    open_attr
    @hclk += 2

    # when 345, 353, ..., 593
    open_pattern(@bg_pattern_base)
    @hclk += 2

    # when 347, 355, ..., 595
    open_pattern(@io_addr | 8)
    @hclk += 2
  end

  8.times do # 597.step(653, 8) do
    # when 597, 605, ..., 653
    if @any_show
      if @hclk == 645
        @scroll_addr_0_4  = @scroll_latch & 0x001f
        @scroll_addr_5_14 = @scroll_latch & 0x7fe0
        @name_io_addr = (@scroll_addr_0_4 | @scroll_addr_5_14) & 0x0fff | 0x2000 # make cache consistent
      end
    end
    open_name
    @hclk += 2

    # when 599, 607, ..., 655
    # Nestopia uses open_name here?
    open_attr
    @hclk += 2

    # when 601, 609, ..., 657
    open_pattern(@pattern_end)
    @hclk += 2

    # when 603, 611, ..., 659
    open_pattern(@io_addr | 8)
    @hclk += 2
  end

  raise unless @hclk == 661
  @hclk = 320
  @vclk += HCLOCK_DUMMY
  @hclk_target -= HCLOCK_DUMMY

  while true
    # visible scanline (not shown)

    # when 320
    load_extended_sprites
    open_name
    @sp_latch = @sp_ram[0] if @any_show
    @sp_buffered = 0
    @sp_zero_in_line = false
    @sp_index = 0
    @sp_phase = 0
    @hclk += 1

    # when 321
    fetch_name
    @hclk += 1

    # when 322
    open_attr
    @hclk += 1

    # when 323
    fetch_attr
    scroll_clock_x
    @hclk += 1

    # when 324
    open_pattern(@io_pattern)
    @hclk += 1

    # when 325
    fetch_bg_pattern_0
    @hclk += 1

    # when 326
    open_pattern(@io_pattern | 8)
    @hclk += 1

    # when 327
    fetch_bg_pattern_1
    @hclk += 1

    # when 328
    preload_tiles
    open_name
    @hclk += 1

    # when 329
    fetch_name
    @hclk += 1

    # when 330
    open_attr
    @hclk += 1

    # when 331
    fetch_attr
    scroll_clock_x
    @hclk += 1

    # when 332
    open_pattern(@io_pattern)
    @hclk += 1

    # when 333
    fetch_bg_pattern_0
    @hclk += 1

    # when 334
    open_pattern(@io_pattern | 8)
    @hclk += 1

    # when 335
    fetch_bg_pattern_1
    @hclk += 1

    # when 336
    open_name
    @hclk += 1

    # when 337
    if @any_show
      update_enabled_flags_edge
      @cpu.next_frame_clock = RP2C02_HVSYNC_1 if @scanline == SCANLINE_HDUMMY && @odd_frame
    end
    @hclk += 1

    # when 338
    open_name
    @scanline += 1
    if @scanline != SCANLINE_VBLANK
      if @any_show
        line = @scanline != 0 || !@odd_frame ? 341 : 340
      else
        update_enabled_flags_edge
        line = 341
      end
      @hclk = 0
      @vclk += line
      @hclk_target = @hclk_target <= line ? 0 : @hclk_target - line
    else
      @hclk = HCLOCK_VBLANK_0
      break
    end

    # visible scanline (shown)
    32.times do # 0.step(248, 8) do
      # when 0, 8, ..., 248
      if @any_show
        if @hclk == 64
          @sp_addr = @regs_oam & 0xf8 # SP_OFFSET_TO_0_1
          @sp_phase = nil
          @sp_latch = 0xff
        end
        load_tiles
        batch_render_eight_pixels
        evaluate_sprites_even if @hclk >= 64
        open_name
      end
      render_pixel
      @hclk += 1

      # when 1, 9, ..., 249
      if @any_show
        fetch_name
        evaluate_sprites_odd if @hclk >= 64
      end
      render_pixel
      @hclk += 1

      # when 2, 10, ..., 250
      if @any_show
        evaluate_sprites_even if @hclk >= 64
        open_attr
      end
      render_pixel
      @hclk += 1

      # when 3, 11, ..., 251
      if @any_show
        fetch_attr
        evaluate_sprites_odd if @hclk >= 64
        scroll_clock_y if @hclk == 251
        scroll_clock_x
      end
      render_pixel
      @hclk += 1

      # when 4, 12, ..., 252
      if @any_show
        evaluate_sprites_even if @hclk >= 64
        open_pattern(@io_pattern)
      end
      render_pixel
      @hclk += 1

      # when 5, 13, ..., 253
      if @any_show
        fetch_bg_pattern_0
        evaluate_sprites_odd if @hclk >= 64
      end
      render_pixel
      @hclk += 1

      # when 6, 14, ..., 254
      if @any_show
        evaluate_sprites_even if @hclk >= 64
        open_pattern(@io_pattern | 8)
      end
      render_pixel
      @hclk += 1

      # when 7, 15, ..., 255
      if @any_show
        fetch_bg_pattern_1
        evaluate_sprites_odd if @hclk >= 64
      end
      render_pixel

      if @any_show
        update_enabled_flags if @hclk != 255
      end

      @hclk += 1
    end

    raise unless @hclk == 256
    # when 256
    open_name
    @sp_latch = 0xff if @any_show
    @hclk += 1

    # when 257
    scroll_reset_x
    @sp_visible = false
    @sp_active = false
    @hclk += 1

    8.times do # 256.step(312, 8) do
      unless @hclk == 258
        # when 264, 272, ..., 312
        open_name
        @hclk += 2
      end

      # when 258, 266, ..., 314
      # Nestopia uses open_name here?
      open_attr
      @hclk += 2

      # when 260, 268, ..., 316
      if @any_show
        buffer_idx = (@hclk - 260) / 2
        open_pattern(buffer_idx >= @sp_buffered ? @pattern_end : open_sprite(buffer_idx))
        # rubocop:disable Style/NestedModifier
        @regs_oam = 0 if @scanline == 238 if @hclk == 316
        # rubocop:enable Style/NestedModifier
      end
      @hclk += 1

      # when 261, 269, ..., 317
      if @any_show
        @io_pattern = @chr_mem[@io_addr & 0x1fff] if (@hclk - 261) / 2 < @sp_buffered
      end
      @hclk += 1

      # when 262, 270, ..., 318
      open_pattern(@io_addr | 8)
      @hclk += 1

      # when 263, 271, ..., 319
      if @any_show
        buffer_idx = (@hclk - 263) / 2
        if buffer_idx < @sp_buffered
          pat0 = @io_pattern
          pat1 = @chr_mem[@io_addr & 0x1fff]
          load_sprite(pat0, pat1, buffer_idx) if pat0 != 0 || pat1 != 0
        end
      end
      @hclk += 1
    end

  end

  # post-render scanline (vblank)

  # when 681
  vblank_0

  # when 682
  vblank_1

  # when 684
  vblank_2
end

end
end
