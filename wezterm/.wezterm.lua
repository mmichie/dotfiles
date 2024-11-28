-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font("Inconsolata for Powerline", {weight="Medium", stretch="Normal", style="Normal"})
config.font_size = 18
-- config.color_scheme = '3024 Night'
-- config.color_scheme = 'Deep'
-- config.color_scheme = 'CGA'
config.color_scheme = 'Firefly Traditional'
-- config.color_scheme = 'Dark Ocean'
config.freetype_load_target = "HorizontalLcd"
-- config.freetype_load_target = "Light"

return config
