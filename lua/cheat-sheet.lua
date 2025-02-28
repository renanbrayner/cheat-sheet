local M = {}
local api = vim.api

require("split")

local opts = {
  auto_fill = {
    filetype = true,
    current_word = true,
  },

  main_win = {
    style = "minimal",
    border = "double",
  },

  input_win = {
    style = "minimal",
    border = "double",
  },
}

function M.setup(user_conf)
  opts = vim.tbl_deep_extend("force", opts, user_conf or {})
end

function M.run()
  local ui = api.nvim_list_uis()[1]
  M.main_win = nil
  M.main_buf = nil
  M.main_win_width = math.floor(ui.width / 1.2)
  M.main_win_height = math.floor(ui.height / 1.2)
  M.main_win_style = opts.main_win.style
  M.main_win_relavent = "win"
  M.main_win_border = opts.main_win.border
  M.main_col = ui.width / 2 - M.main_win_width / 2
  M.main_row = ui.height / 2 - M.main_win_height / 2

  M.input_win = nil
  M.input_buf = nil
  M.input_win_width = 60
  M.input_win_height = 1
  M.input_win_style = opts.input_win.style
  M.input_win_relavent = "win"
  M.input_win_border = opts.input_win.border
  M.input_col = ui.width / 2 - M.input_win_width / 2
  M.input_row = ui.height / 2 - M.input_win_height / 2

  M.openInput()
end

function M.openInput()
  local bufContent = ""

  if opts.auto_fill.filetype then
    local fileType = vim.api.nvim_buf_get_option(0, "filetype")
    if fileType ~= "" then
      bufContent = bufContent .. fileType .. "/"
      if not opts.auto_fill.current_word then
        bufContent = bufContent .. " "
      end
    end
  end

  if opts.auto_fill.current_word then
    local cword = vim.fn.expand("<cword>")
    if cword then
      bufContent = bufContent .. cword .. " "
    end
  end

  M.input_buf = api.nvim_create_buf(false, true)
  M.input_win = api.nvim_open_win(M.input_buf, false, {
    relative = M.input_win_relavent,
    col = M.input_col,
    row = M.input_row,
    width = M.input_win_width,
    height = M.input_win_height,
    style = M.input_win_style,
    border = M.input_win_border,
  })
  api.nvim_win_set_option(M.input_win, "cursorline", true)
  api.nvim_set_current_win(M.input_win)
  M.setKey(M.input_buf)
  -- add filetype to first line
  api.nvim_buf_set_option(M.input_buf, "modifiable", true)
  api.nvim_buf_set_lines(M.input_buf, 0, 1, false, { bufContent })

  -- set cursor on the second line
  -- and put it in insert mode
  local cursor_input = bufContent:len() + 1
  api.nvim_win_set_cursor(M.input_win, { 1, cursor_input })
  api.nvim_command("startinsert")
end

function Resolve_filetype(sh_filetype)
  local fileTypes = {
    {
      fileType = "c",
      alies = { "c", "h" },
    },
    {
      fileType = "cpp",
      alies = { "cpp", "hpp" },
    },
    {
      fileType = "javascript",
      alies = { "js", "nodejs", "node", "javascript", "ts", "typescript" },
    },
    {
      fileType = "python",
      alies = { "py", "python" },
    },
    {
      fileType = "ruby",
      alies = { "rb", "ruby" },
    },
    {
      fileType = "rust",
      alies = { "rs", "rust" },
    },
    {
      fileType = "kotlin",
      alies = { "kt", "kotlin" },
    },
  }
  for _, fileType in ipairs(fileTypes) do
    if sh_filetype == fileType.fileType then
      sh_filetype = fileType.fileType
      break
    else
      for _, alies in ipairs(fileType.alies) do
        if sh_filetype == alies then
          sh_filetype = fileType.fileType
          break
        end
      end
    end
  end
  return sh_filetype
end

function M.openPreview()
  -- get the text from the input buffer
  local input_lines = api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
  input_lines = input_lines[1]
  if input_lines == "" then
    return
  end

  local search_fileType = input_lines:split("/")
  if #search_fileType > 1 then
    -- list all file types in array
    search_fileType = Resolve_filetype(search_fileType[1])
  else
    search_fileType = "text"
  end

  api.nvim_win_close(M.input_win, true)
  M.input_win = nil
  M.input_buf = nil

  local path = input_lines:gsub(" ", "%%20")

  local url = "https://cheat.sh/" .. path
  local cmdcommand = "curl -s " .. url
  local output = vim.api.nvim_call_function("system", { cmdcommand })
  output = output:split("\n")
  local win_height = M.main_win_height
  if #output < M.main_win_height then
    win_height = #output
  end
  M.main_buf = api.nvim_create_buf(false, true)
  M.main_win = api.nvim_open_win(M.main_buf, false, {
    relative = M.main_win_relavent,
    width = M.main_win_width,
    height = win_height,
    style = M.main_win_style,
    row = M.main_row,
    col = M.main_col,
    anchor = "NW",
    border = M.main_win_border,
  })
  api.nvim_set_current_win(M.main_win)
  api.nvim_win_set_option(M.main_win, "cursorline", true)
  -- set background color for the window
  api.nvim_win_set_option(M.main_win, "winhighlight", "Normal:CursorLine")
  api.nvim_buf_set_option(M.main_buf, "filetype", search_fileType)

  for _, line in ipairs(output) do
    line = line:gsub("[^m]*m", "")
    api.nvim_buf_set_lines(M.main_buf, -1, -1, true, { line })
  end

  api.nvim_buf_set_option(M.main_buf, "modifiable", false)

  M.setKey(M.main_buf)
end

function M.setKey(buf)
  if M.input_buf == nil then
    api.nvim_buf_set_keymap(
      buf,
      "n",
      "q",
      '<Esc>:lua require"cheat-sheet".close_win()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
  elseif M.main_buf == nil then
    api.nvim_buf_set_keymap(
      buf,
      "n",
      "q",
      '<Esc>:lua require"cheat-sheet".close_win()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
      buf,
      "i",
      "<C-c>",
      '<Esc>:lua require"cheat-sheet".close_win()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
      buf,
      "i",
      "<CR>",
      '<Esc>:lua require"cheat-sheet".openPreview()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
      buf,
      "n",
      "<CR>",
      '<Esc>:lua require"cheat-sheet".openPreview()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
      buf,
      "i",
      "<C-d>",
      '<Esc>:lua require"cheat-sheet".removeInput()<CR>',
      { nowait = true, noremap = true, silent = true }
    )
  end
end

function M.removeInput()
  -- remove first line text from input buffer
  api.nvim_buf_set_option(M.input_buf, "modifiable", true)
  api.nvim_buf_set_lines(M.input_buf, 0, 1, false, {})
  api.nvim_command("startinsert")
end

function M.close_win()
  if M.main_win then
    api.nvim_win_close(M.main_win, true)
    M.main_win = nil
    M.main_buf = nil
  elseif M.input_win then
    api.nvim_win_close(M.input_win, true)
    M.input_win = nil
    M.input_buf = nil
  end
end

return M
