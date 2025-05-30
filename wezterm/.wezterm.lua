local wezterm = require 'wezterm'
local c = wezterm.config_builder()

-- Keep existing font and window configuration
c.font = wezterm.font("Hack")
c.font_size = 15
c.tab_bar_at_bottom = false
c.use_fancy_tab_bar = false
c.show_new_tab_button_in_tab_bar = false
c.show_tabs_in_tab_bar = true
c.tab_max_width = 60
c.tab_and_split_indices_are_zero_based = false

-- Tab bar styling
c.hide_tab_bar_if_only_one_tab = false
c.tab_bar_style = {
  new_tab = wezterm.format({
    { Background = { Color = '#000000' } },
    { Foreground = { Color = '#808080' } },
    { Text = ' + ' },
  }),
  new_tab_hover = wezterm.format({
    { Background = { Color = '#252525' } },
    { Foreground = { Color = '#FFFFFF' } },
    { Text = ' + ' },
  }),
}

-- Custom tab format with icons and styling
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local edge_background = '#000000'
  local background = '#0A0A0A'
  local foreground = '#808080'

  if tab.is_active then
    background = '#1a1b26'
    foreground = '#7aa2f7'
  elseif hover then
    background = '#16161e'
    foreground = '#c0caf5'
  end

  -- Get the process name and icon
  local process = tab.active_pane.foreground_process_name
  local icon = '󰆍 '  -- default terminal icon
  
  if process then
    if process:find('vim') or process:find('nvim') then
      icon = ' '
    elseif process:find('claude') then
      icon = '󰚩 '  -- Claude Code icon
    elseif process:find('node') or process:find('npm') then
      icon = ' '
    elseif process:find('python') then
      icon = ' '
    elseif process:find('git') then
      icon = ' '
    elseif process:find('docker') then
      icon = ' '
    elseif process:find('cargo') or process:find('rust') then
      icon = ' '
    elseif process:find('ssh') then
      icon = '󰣀 '
    end
  end

  -- Get the title
  local title = tab.tab_title
  if #title == 0 then
    title = tab.active_pane.title
  end

  -- Clean up the title
  title = title:gsub('^Copy mode: ', '')
  
  -- Calculate padding to use full tab width
  local content = icon .. title
  local padding = string.rep(' ', math.max(0, 56 - wezterm.column_width(content)))
  
  -- Cool tab separators - different styles
  local left_sep = ''  -- slant style
  local right_sep = ''  -- slant style
  -- Alternative separators you can try:
  -- local left_sep = ''  -- round style
  -- local right_sep = ''  -- round style
  -- local left_sep = ''  -- triangle style
  -- local right_sep = ''  -- triangle style
  
  -- Add tab index
  local tab_index = tab.tab_index
  
  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = background } },
    { Text = left_sep },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
    { Text = ' ' .. tab_index .. ' ' .. icon .. title .. padding .. ' ' },
    { Background = { Color = edge_background } },
    { Foreground = { Color = background } },
    { Text = right_sep },
  }
end)

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
  
  -- Tab bar colors (updated to match new style)
  tab_bar = {
    background = '#000000',
    active_tab = {
      bg_color = '#1a1b26',
      fg_color = '#7aa2f7',
      intensity = 'Bold',
      underline = 'None',
      italic = false,
    },
    inactive_tab = {
      bg_color = '#0A0A0A',
      fg_color = '#808080',
    },
    inactive_tab_hover = {
      bg_color = '#16161e',
      fg_color = '#c0caf5',
    },
    new_tab = {
      bg_color = '#000000',
      fg_color = '#808080',
    },
    new_tab_hover = {
      bg_color = '#16161e',
      fg_color = '#c0caf5',
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
