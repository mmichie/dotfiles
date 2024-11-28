-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local c = wezterm.config_builder()

c.font = wezterm.font("Inconsolata for Powerline", {weight="Medium", stretch="Normal", style="Normal"})
c.font_size = 18

wezterm.on("update-status", function(window, pane)
  local status = wezterm.format({
    { Foreground = { Color = "#94e2d5" }},
    { Text = "  " .. wezterm.strftime("%H:%M") },
  })
  window:set_right_status(status)
end)

-- config.color_scheme = '3024 Night'
-- config.color_scheme = 'Deep'
-- config.color_scheme = 'CGA'
-- config.freetype_load_target = "Light"
-- config.color_scheme = 'Dark Ocean'
c.color_scheme = 'Firefly Traditional'
c.hide_tab_bar_if_only_one_tab = true

-- Add key bindings for switching tabs
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

-- Font rendering settings to be more like iTerm2
c.freetype_load_target = "Light"
c.freetype_render_target = "HorizontalLcd"
c.font_rasterizer = "FreeType"  -- Using FreeType for rendering
c.adjust_window_size_when_changing_font_size = false

c.use_fancy_tab_bar = false
c.tab_max_width = 32
-- Remove tab bar padding to make it span full width
c.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
-- Enable tab bar even with a single tab
c.hide_tab_bar_if_only_one_tab = false
c.colors = {
  tab_bar = {
    background = '#0b0022',
    active_tab = {
      bg_color = '#2b2042',
      fg_color = '#c0c0c0',
      intensity = 'Normal',
      underline = 'None',
      italic = false,
    },
    inactive_tab = {
      bg_color = '#1b1032',
      fg_color = '#808080',
    },
    inactive_tab_hover = {
      bg_color = '#3b3052',
      fg_color = '#909090',
      italic = true,
    },
    new_tab = {
      bg_color = '#1b1032',
      fg_color = '#808080',
    },
    new_tab_hover = {
      bg_color = '#3b3052',
      fg_color = '#909090',
      italic = true,
    },
  },
}

return c
