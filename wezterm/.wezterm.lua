-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local c = wezterm.config_builder()

c.font = wezterm.font("Inconsolata for Powerline", {weight="Medium", stretch="Normal", style="Normal"})
c.font_size = 18

-- Right status with time/date in tmux style
wezterm.on("update-status", function(window, pane)
  -- Match tmux status right format: time and date with proper color
  local date = wezterm.strftime(" %R  %d %b ")
  local hostname = " " .. wezterm.hostname() .. " "
  local status = {
    { Background = { Color = "#234" }},
    { Foreground = { Color = "#8c8c8c" }}, -- color245 equivalent
    { Text = date },
    { Background = { Color = "#234" }},
    { Foreground = { Color = "#8c8c8c" }},
    { Text = hostname },
  }
  window:set_right_status(wezterm.format(status))
end)

c.hide_tab_bar_if_only_one_tab = false
c.use_fancy_tab_bar = false
c.tab_max_width = 32

-- Window padding to match tmux style
c.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- Color scheme matching tmux colors
c.colors = {
  tab_bar = {
    background = '#234', -- Matches tmux bg=colour234
    active_tab = {
      bg_color = '#27f', -- Matches tmux colour39 (bright blue)
      fg_color = '#000', -- Black text for contrast
      intensity = 'Bold',
      underline = 'None',
      italic = false,
    },
    inactive_tab = {
      bg_color = '#234', -- Matches tmux bg
      fg_color = '#fff', -- White text for inactive tabs
    },
    inactive_tab_hover = {
      bg_color = '#345',
      fg_color = '#fff',
      italic = true,
    },
    new_tab = {
      bg_color = '#234',
      fg_color = '#fff',
    },
    new_tab_hover = {
      bg_color = '#345',
      fg_color = '#fff',
      italic = true,
    },
  },
}

-- Key bindings
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

-- Font rendering settings
c.freetype_load_target = "Light"
c.freetype_render_target = "HorizontalLcd"
c.font_rasterizer = "FreeType"
c.adjust_window_size_when_changing_font_size = false

return c
