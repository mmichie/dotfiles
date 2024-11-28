-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local c = wezterm.config_builder()

c.font = wezterm.font("Inconsolata for Powerline", {weight="Medium", stretch="Normal", style="Normal"})
c.font_size = 18

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

return c
