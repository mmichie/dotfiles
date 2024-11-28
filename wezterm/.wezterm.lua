local wezterm = require 'wezterm'
local c = wezterm.config_builder()

c.font = wezterm.font("Inconsolata for Powerline", {weight="Medium", stretch="Normal", style="Normal"})
c.font_size = 18
c.tab_bar_at_bottom = false
c.use_fancy_tab_bar = false
c.show_new_tab_button_in_tab_bar = false
c.show_tabs_in_tab_bar = true
c.window_frame = {
  font = wezterm.font({ family = "Inconsolata for Powerline", weight = "Bold" }),
  font_size = 18.0,
  active_titlebar_bg = '#000033',
  inactive_titlebar_bg = '#000066',
}

wezterm.on('update-right-status', function(window, pane)
  local cells = {}
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local cwd = ''
    local hostname = ''

    if type(cwd_uri) == 'userdata' then
      cwd = cwd_uri.file_path
      hostname = cwd_uri.host or wezterm.hostname()
    else
      cwd_uri = cwd_uri:sub(8)
      local slash = cwd_uri:find '/'
      if slash then
        hostname = cwd_uri:sub(1, slash - 1)
        cwd = cwd_uri:sub(slash):gsub('%%(%x%x)', function(hex)
          return string.char(tonumber(hex, 16))
        end)
      end
    end

    local dot = hostname:find '[.]'
    if dot then
      hostname = hostname:sub(1, dot - 1)
    end
    if hostname == '' then
      hostname = wezterm.hostname()
    end

    table.insert(cells, cwd)
    table.insert(cells, hostname)
  end

  local date = wezterm.strftime '%a %b %-d %H:%M'
  table.insert(cells, date)

  for _, b in ipairs(wezterm.battery_info()) do
    table.insert(cells, string.format('%.0f%%', b.state_of_charge * 100))
  end

  local LEFT_ARROW = utf8.char(0xe0b3)
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  local colors = {
    '#000033',
    '#000066',
    '#000099',
    '#0000cc',
    '#0000ff',
  }

  local text_fg = '#ffffff'
  local elements = {}
  local num_cells = 0

  function push(text, is_last)
    local cell_no = num_cells + 1
    table.insert(elements, { Foreground = { Color = text_fg } })
    table.insert(elements, { Background = { Color = colors[cell_no] } })
    table.insert(elements, { Text = ' ' .. text .. ' ' })
    if not is_last then
      table.insert(elements, { Foreground = { Color = colors[cell_no + 1] } })
      table.insert(elements, { Text = SOLID_LEFT_ARROW })
    end
    num_cells = num_cells + 1
  end

  while #cells > 0 do
    local cell = table.remove(cells, 1)
    push(cell, #cells == 0)
  end

  window:set_right_status(wezterm.format(elements))
end)

-- Color scheme with full-width tabs
c.colors = {
  tab_bar = {
    background = '#000033',
    active_tab = {
      bg_color = '#0000cc',
      fg_color = '#ffffff',
      intensity = 'Bold',
      underline = 'None',
      italic = false,
    },
    inactive_tab = {
      bg_color = '#000066',
      fg_color = '#ffffff',
    },
    inactive_tab_hover = {
      bg_color = '#000099',
      fg_color = '#ffffff',
      italic = true,
    },
    new_tab = {
      bg_color = '#000033',
      fg_color = '#ffffff',
    },
    new_tab_hover = {
      bg_color = '#000066',
      fg_color = '#ffffff',
      italic = true,
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

c.freetype_load_target = "Light"
c.freetype_render_target = "HorizontalLcd"
c.font_rasterizer = "FreeType"
c.adjust_window_size_when_changing_font_size = false

return c
