local Snipe = {}
local H = {}

Snipe.setup = function(config)
  Snipe.config = H.setup_config(config)

  local SnipeMenu = require("snipe.menu")
  Snipe.global_menu = SnipeMenu:new { dictionary = Snipe.config.hints.dictionary, position = Snipe.config.ui.position, open_win_override = Snipe.config.ui.open_win_override, max_height = Snipe.config.ui.max_height }
  Snipe.global_items = {}
end

H.default_config = {
  ui = {
    max_height = -1, -- -1 means dynamic height
    -- Where to place the ui window
    -- Can be any of "topleft", "bottomleft", "topright", "bottomright", "center", "cursor" (sets under the current cursor pos)
    position = "topleft",
    -- Override options passed to `nvim_open_win`
    -- Be careful with this as snipe will not validate
    -- anything you override here. See `:h nvim_open_win`
    -- for config options
    open_win_override = {
      -- title = "My Window Title",
      border = "single", -- use "rounded" for rounded border
    },

    -- Preselect the currently open buffer
    preselect_current = true,
  },
  hints = {
    -- Charaters to use for hints (NOTE: make sure they don't collide with the navigation keymaps)
    dictionary = "sadflewcmpghio",
  },
  navigate = {
    -- When the list is too long it is split into pages
    -- `[next|prev]_page` options allow you to navigate
    -- this list
    next_page = "J",
    prev_page = "K",

    -- You can also just use normal navigation to go to the item you want
    -- this option just sets the keybind for selecting the item under the
    -- cursor
    under_cursor = "<cr>",

    -- In case you changed your mind, provide a keybind that lets you
    -- cancel the snipe and close the window.
    cancel_snipe = "<esc>",

    -- Close the buffer under the cursor
    -- Remove "j" and "k" from your dictionary to navigate easier to delete
    -- NOTE: Make sure you don't use the character below on your dictionary
    close_buffer = "D",

    -- Open buffer in vertical split
    open_vsplit = "V",

    -- Open buffer in split, based on `vim.opt.splitbelow`
    open_split = "H",
  },
  -- The default sort used for the buffers
  -- Can be any of "last", (sort buffers by last accessed) "default" (sort buffers by its number)
  sort = "default"
}

H.setup_config = function(config)
  config = config or {}
  vim.validate({ config = { config, "table", true } })
  config = vim.tbl_deep_extend("force", vim.deepcopy(H.default_config), config)

  vim.validate({
    ["ui.max_width"] = { config.ui.max_width, "number", true },
    ["ui.position"] = { config.ui.position, "string", true },
    ["ui.open_win_override"] = { config.ui.open_win_override, "table", true },
    ["ui.preselect_current"] = { config.ui.preselect_current, "boolean", true },
    ["hints.dictionary"] = { config.hints.dictionary, "string", true },
    ["navigate.next_page"] = { config.navigate.next_page, "string", true },
    ["navigate.prev_page"] = { config.navigate.prev_page, "string", true },
    ["navigate.under_cursor"] = { config.navigate.under_cursor, "string", true },
    ["navigate.cancel_snipe"] = { config.navigate.cancel_snipe, "string", true },
    ["navigate.close_buffer"] = { config.navigate.close_buffer, "string", true },
    ["navigate.open_vsplit"] = { config.navigate.open_vsplit, "string", true },
    ["navigate.open_split"] = { config.navigate.open_split, "string", true },
    ["sort"] = { config.sort, "string", true },
  })

  -- Validate hint characters and setup tables
  if #config.hints.dictionary < 2 then
    vim.notify("(snipe) Dictionary must have at least 2 items", vim.log.levels.ERROR)
    return config
  end

  return config
end

function Snipe.default_keymaps(m)
  local nav_next = function()
    Snipe.global_menu:goto_next_page()
    Snipe.global_menu:reopen()
  end

  local nav_prev = function()
    Snipe.global_menu:goto_prev_page()
    Snipe.global_menu:reopen()
  end

  vim.keymap.set("n", Snipe.config.navigate.next_page, nav_next, { nowait = true, buffer = m.buf })
  vim.keymap.set("n", Snipe.config.navigate.prev_page, nav_prev, { nowait = true, buffer = m.buf })
  vim.keymap.set("n", Snipe.config.navigate.close_buffer, function()
    local hovered = m:hovered()
    local bufnr = m.items[hovered].id
    -- I have to hack switch back to main window, otherwise currently background focused
    -- window cannot be deleted when focused on a floating window
    local current_tabpage = vim.api.nvim_get_current_tabpage()
    local root_win = vim.api.nvim_tabpage_list_wins(current_tabpage)[1]
    vim.api.nvim_set_current_win(root_win)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.api.nvim_set_current_win(m.win)
    table.remove(m.items, hovered)
    m:reopen()
  end, { nowait = true, buffer = m.buf })

  vim.keymap.set("n", Snipe.config.navigate.open_vsplit, function()
    local bufnr = m.items[m:hovered()].id
    m:close() -- make sure to call first !
    vim.api.nvim_open_win(bufnr, true, { vertical = true, win = 0 })
  end, { nowait = true, buffer = m.buf })

  vim.keymap.set("n", Snipe.config.navigate.open_split, function()
    local split_direction = vim.opt.splitbelow:get() and "below" or "above"
    local bufnr = m.items[m:hovered()].id
    m:close() -- make sure to call first !
    vim.api.nvim_open_win(bufnr, true, { split = split_direction, win = 0 })
  end, { nowait = true, buffer = m.buf })

  vim.keymap.set("n", Snipe.config.navigate.cancel_snipe, function() m:close() end, { nowait = true, buffer = m.buf })
  vim.keymap.set("n", Snipe.config.navigate.under_cursor, function()
    local hovered = m:hovered()
    m:close()
    vim.api.nvim_set_current_buf(m.items[hovered].id)
  end, { nowait = true, buffer = m.buf })
end

function Snipe.default_fmt(item)
  return item.name
end

function Snipe.default_select(m, i)
  Snipe.global_menu:close()
  vim.api.nvim_set_current_buf(m.items[i].id)
end

function Snipe.open_buffer_menu()
  local cmd = Snipe.config.sort == "last" and "ls t" or "ls"
  Snipe.global_items = require("snipe.buffer").get_buffers(cmd)
  Snipe.global_menu:add_new_buffer_callback(Snipe.default_keymaps)

  if Snipe.config.ui.preselect_current then
    local opened = false
    for i, b in ipairs(Snipe.global_items) do
      if b.classifiers:sub(2,2) == "%" then
        Snipe.global_menu:open(Snipe.global_items, Snipe.default_select, Snipe.default_fmt, i)
        opened = true
      end
    end
    if not opened then
      Snipe.global_menu:open(Snipe.global_items, Snipe.default_select, Snipe.default_fmt)
    end
  else
    Snipe.global_menu:open(Snipe.global_items, Snipe.default_select, Snipe.default_fmt)
  end
end

return Snipe
