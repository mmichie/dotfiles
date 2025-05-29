local wezterm = require 'wezterm'
local c = wezterm.config_builder()

-- Keep existing font and window configuration
c.font = wezterm.font("Hack")
c.font_size = 15
c.tab_bar_at_bottom = false
c.use_fancy_tab_bar = false
c.show_new_tab_button_in_tab_bar = false
c.show_tabs_in_tab_bar = true
c.tab_max_width = 32

-- Scrollback and memory settings
c.scrollback_lines = 10000
c.enable_scroll_bar = true
c.front_end = "WebGpu"  -- GPU acceleration
c.webgpu_power_preference = "LowPower"  -- Reduce power/memory usage

c.window_frame = {
--  font = wezterm.font({ family = "Inconsolata for Powerline", weight = "Bold" }),
  font = wezterm.font({ family = "Fieracode", weight = "Bold" }),
  font_size = 16.0,
  active_titlebar_bg = '#0F0F0F',
  inactive_titlebar_bg = '#1F1F1F',
}

-- Adjusted color scheme to match Warp more precisely
c.colors = {
  -- Default colors
  foreground = '#FFFFFF',
  background = '#000000',
  
  -- Normal colors
  ansi = {
    '#000000', -- black
    '#FF5555', -- red
    '#50FA7B', -- green (brighter lime green for files)
    '#F1FA8C', -- yellow
    '#2B7DE9', -- blue (more saturated for directories)
    '#BD93F9', -- magenta
    '#8BE9FD', -- cyan (for symlinks)
    '#FFFFFF', -- white
  },
  
  -- Bright colors
  brights = {
    '#4D4D4D', -- bright black
    '#FF6E67', -- bright red
    '#5AF78E', -- bright green
    '#F4F99D', -- bright yellow
    '#3B8AEF', -- bright blue
    '#CAA9FA', -- bright magenta
    '#9AEDFE', -- bright cyan
    '#FFFFFF', -- bright white
  },
  
  -- Tab bar colors
  tab_bar = {
    background = '#000000',
    active_tab = {
      bg_color = '#1F1F1F',
      fg_color = '#FFFFFF',
      intensity = 'Bold',
      underline = 'None',
      italic = false,
    },
    inactive_tab = {
      bg_color = '#000000',
      fg_color = '#808080',
    },
    inactive_tab_hover = {
      bg_color = '#252525',
      fg_color = '#FFFFFF',
    },
    new_tab = {
      bg_color = '#000000',
      fg_color = '#FFFFFF',
    },
    new_tab_hover = {
      bg_color = '#252525',
      fg_color = '#FFFFFF',
    },
  },
}

c.keys = {
  {
    key = 'LeftArrow',
    mods = 'CMD',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'RightArrow',
    mods = 'CMD',
    action = wezterm.action.ActivateTabRelative(1),
  },
}

-- c.freetype_load_target = "Light"
-- c.freetype_render_target = "HorizontalLcd"
-- c.font_rasterizer = "FreeType"
-- c.adjust_window_size_when_changing_font_size = false

return c
