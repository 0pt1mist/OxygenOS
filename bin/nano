-- Nano for OxygenOS
-- Requires Kernel v0.6+

local args = {...}
local filename = args[1]

if not filename then
  print("Usage: nano <filename>")
  return
end

-- Screen Size
local w, h = sys.gpu.res()
local scrollY = 0
local cursorX, cursorY = 1, 1

-- Load File
local lines = {}
local content = sys.read(filename)
if content then
  for line in string.gmatch(content.."\n", "([^\n]*)\n") do
    table.insert(lines, line)
  end
else
  lines = {""} -- New file
end
-- Hack for last empty line
if #lines == 0 then lines = {""} end

-- UI Colors
local C_BG = 0x000000
local C_FG = 0xFFFFFF
local C_BAR = 0xFFFFFF
local C_BAR_TXT = 0x000000

local function draw()
  -- Draw Header
  sys.gpu.color(C_BAR_TXT, C_BAR)
  sys.gpu.fill(1, 1, w, 1, " ")
  sys.gpu.set(1, 1, " Nano: " .. filename)
  
  -- Draw Content
  sys.gpu.color(C_FG, C_BG)
  sys.gpu.fill(1, 2, w, h-2, " ")
  
  for i = 1, h-2 do
    local lineIdx = scrollY + i
    if lines[lineIdx] then
      -- Ограничение длины строки для отрисовки
      local lineStr = unicode.sub(lines[lineIdx], 1, w)
      sys.gpu.set(1, i+1, lineStr)
    end
  end
  
  -- Draw Footer
  sys.gpu.color(C_BAR_TXT, C_BAR)
  sys.gpu.fill(1, h, w, 1, " ")
  sys.gpu.set(1, h, "^S Save  ^X Exit  Lines: " .. #lines)
  
  -- Cursor
  sys.gpu.color(C_FG, C_BG) -- Reset
  -- Эмуляция курсора инверсией цвета или миганием сложна без прямого доступа, 
  -- но системный курсор не управляется нами напрямую в ядре v0.6 так детально.
  -- Поэтому мы просто ставим символ "_" или используем системный блинк, если бы он был.
  -- В данном случае мы просто обновляем строку, где курсор.
  local line = lines[scrollY + cursorY] or ""
  local charUnder = unicode.sub(line, cursorX, cursorX)
  if charUnder == "" then charUnder = " " end
  
  sys.gpu.color(0x000000, 0xFFFFFF) -- Invert cursor
  sys.gpu.set(cursorX, cursorY + 1, charUnder)
  sys.gpu.color(C_FG, C_BG)
end

local function save()
  local data = table.concat(lines, "\n")
  if sys.write(filename, data) then
    sys.gpu.color(0x00FF00, 0x000000)
    sys.gpu.set(1, h, "Saved!")
    sys.pull(1)
  else
    sys.gpu.set(1, h, "Error Saving!")
    sys.pull(1)
  end
end

-- Main Loop
while true do
  draw()
  
  local sig = {sys.pull(math.huge)}
  local name = sig[1]
  
  if name == "key_down" then
    local char = sig[3]
    local code = sig[4]
    
    -- Ctrl+S (19)
    if char == 19 then 
      save()
    
    -- Ctrl+X (24)
    elseif char == 24 then
      sys.gpu.fill(1, 1, w, h, " ")
      sys.gpu.set(1, 1, "Exited.")
      return
      
    -- Enter
    elseif char == 13 then
      local line = lines[scrollY + cursorY]
      local part1 = unicode.sub(line, 1, cursorX - 1)
      local part2 = unicode.sub(line, cursorX)
      lines[scrollY + cursorY] = part1
      table.insert(lines, scrollY + cursorY + 1, part2)
      cursorY = cursorY + 1
      cursorX = 1
      
    -- Backspace
    elseif char == 8 then
      if cursorX > 1 then
        local line = lines[scrollY + cursorY]
        lines[scrollY + cursorY] = unicode.sub(line, 1, cursorX - 2) .. unicode.sub(line, cursorX)
        cursorX = cursorX - 1
      elseif cursorY > 1 then
        -- Append current line to previous
        local current = lines[scrollY + cursorY]
        local prev = lines[scrollY + cursorY - 1]
        cursorX = unicode.len(prev) + 1
        lines[scrollY + cursorY - 1] = prev .. current
        table.remove(lines, scrollY + cursorY)
        cursorY = cursorY - 1
      end
      
    -- Arrows
    elseif code == 200 then -- Up
      if cursorY > 1 then cursorY = cursorY - 1
      elseif scrollY > 0 then scrollY = scrollY - 1 end
    elseif code == 208 then -- Down
      if cursorY < h - 2 and (scrollY + cursorY) < #lines then cursorY = cursorY + 1
      elseif (scrollY + cursorY) < #lines then scrollY = scrollY + 1 end
    elseif code == 203 then -- Left
      if cursorX > 1 then cursorX = cursorX - 1 end
    elseif code == 205 then -- Right
      local len = unicode.len(lines[scrollY + cursorY] or "")
      if cursorX <= len then cursorX = cursorX + 1 end
      
    elseif char >= 32 then
      local uchar = unicode.char(char)
      local line = lines[scrollY + cursorY] or ""
      lines[scrollY + cursorY] = unicode.sub(line, 1, cursorX - 1) .. uchar .. unicode.sub(line, cursorX)
      cursorX = cursorX + 1
    end
  end
end