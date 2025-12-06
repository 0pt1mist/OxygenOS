-- OxygenOS Kernel v0.6.2 (Net Debug)

-- [1] HARDWARE SEIZE
local hw = {
  component = component,
  computer = computer,
  unicode = unicode
}
local boot_addr = hw.computer.getBootAddress()

-- [2] GLOBAL PURGE
_G.component = nil
_G.computer = nil
_G.io = nil
_G.os = nil

-- [3] DRIVERS
local Oxygen = {
  gpu = nil,
  inet = nil,
  w = 80, h = 25,
  input_row = 25
}

local gpu_addr = hw.component.list("gpu")()
local screen_addr = hw.component.list("screen")()
if gpu_addr and screen_addr then
  Oxygen.gpu = hw.component.proxy(gpu_addr)
  Oxygen.gpu.bind(screen_addr)
  Oxygen.w, Oxygen.h = Oxygen.gpu.getResolution()
  Oxygen.input_row = Oxygen.h
  Oxygen.gpu.setBackground(0x000000)
  Oxygen.gpu.setForeground(0xFFFFFF)
  Oxygen.gpu.fill(1, 1, Oxygen.w, Oxygen.h, " ")
end

local inet_addr = hw.component.list("internet")()
if inet_addr then Oxygen.inet = hw.component.proxy(inet_addr) end

-- [4] TTY ENGINE
function Oxygen.scroll()
  if not Oxygen.gpu then return end
  Oxygen.gpu.copy(1, 2, Oxygen.w, Oxygen.input_row - 2, 0, -1)
  Oxygen.gpu.fill(1, Oxygen.input_row - 1, Oxygen.w, 1, " ")
end

function Oxygen.printLine(line)
  if not Oxygen.gpu then return end
  Oxygen.scroll()
  Oxygen.gpu.set(1, Oxygen.input_row - 1, tostring(line))
end

function Oxygen.ttyPrint(text)
  if not text then text = "nil" end
  text = tostring(text)
  local line = ""
  for i = 1, #text do
    local char = string.sub(text, i, i)
    if char == "\n" then
      Oxygen.printLine(line)
      line = ""
    else
      line = line .. char
      if hw.unicode.len(line) >= Oxygen.w then
        Oxygen.printLine(line)
        line = ""
      end
    end
  end
  if #line > 0 then Oxygen.printLine(line) end
end

-- [5] SYSTEM CALLS
local Syscalls = {}

Syscalls.readFile = function(path)
  local handle = hw.component.invoke(boot_addr, "open", path)
  if not handle then return nil, "File not found" end
  local buffer = ""
  repeat
    local data = hw.component.invoke(boot_addr, "read", handle, math.huge)
    buffer = buffer .. (data or "")
  until not data
  hw.component.invoke(boot_addr, "close", handle)
  return buffer
end

Syscalls.writeFile = function(path, data)
  local handle = hw.component.invoke(boot_addr, "open", path, "w")
  if not handle then return false, "Write error" end
  hw.component.invoke(boot_addr, "write", handle, data)
  hw.component.invoke(boot_addr, "close", handle)
  return true
end

Syscalls.list = function(path) return hw.component.invoke(boot_addr, "list", path) end
Syscalls.mkDir = function(path) return hw.component.invoke(boot_addr, "makeDirectory", path) end

-- NETWORK DEBUGGED
Syscalls.fetch = function(url)
  if not Oxygen.inet then 
    Oxygen.ttyPrint("[NET] Error: No Internet Card")
    return nil, "No Net" 
  end
  
  Oxygen.ttyPrint("[NET] GET " .. url)
  
  local handle, err = Oxygen.inet.request(url)
  if not handle then 
    Oxygen.ttyPrint("[NET] Connect Fail: " .. tostring(err))
    return nil, err 
  end
  
  local buffer = ""
  -- Читаем статус ответа (не все версии OC поддерживают response code, но попробуем)
  local code, msg, header = handle.response()
  if code then
     Oxygen.ttyPrint("[NET] Response: " .. tostring(code))
     if code == 404 then
        handle.close()
        return nil, "404 Not Found"
     end
  end

  while true do
    local data = handle.read()
    if not data then break end
    buffer = buffer .. data
    hw.computer.pullSignal(0.0) -- Антифриз
  end
  
  handle.close()
  Oxygen.ttyPrint("[NET] Done. Size: " .. #buffer .. " bytes")
  return buffer
end

-- GPU & Input
Syscalls.gpu_set = function(x, y, txt) if Oxygen.gpu then Oxygen.gpu.set(x, y, txt) end end
Syscalls.gpu_fill = function(x,y,w,h,c) if Oxygen.gpu then Oxygen.gpu.fill(x,y,w,h,c) end end
Syscalls.gpu_copy = function(x,y,w,h,tx,ty) if Oxygen.gpu then Oxygen.gpu.copy(x,y,w,h,tx,ty) end end
Syscalls.gpu_res = function() return Oxygen.w, Oxygen.h end
Syscalls.gpu_color = function(f, b) 
  if Oxygen.gpu then 
    if f then Oxygen.gpu.setForeground(f) end
    if b then Oxygen.gpu.setBackground(b) end
  end 
end
Syscalls.pull = function(t) return hw.computer.pullSignal(t) end

Syscalls.readln = function()
  local buffer = ""
  local function redraw()
    if not Oxygen.gpu then return end
    Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
    Oxygen.gpu.set(1, Oxygen.input_row, "> " .. buffer .. "_")
  end
  redraw()
  while true do
    local s = {hw.computer.pullSignal()}
    if s[1] == "key_down" then
      local char = s[3]
      if char == 13 then
        Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
        Oxygen.printLine("> " .. buffer)
        return buffer
      elseif char == 8 then
        if #buffer > 0 then buffer = hw.unicode.sub(buffer, 1, -2) end
        redraw()
      elseif char >= 32 then
        buffer = buffer .. hw.unicode.char(char)
        redraw()
      end
    end
  end
end

Syscalls.exit = function() hw.computer.shutdown() end

-- [6] EXEC
function Oxygen.exec(path, ...)
  local args = {...}
  local code, err = Syscalls.readFile(path)
  if not code then Oxygen.ttyPrint("Err: "..tostring(err)) return end

  local sandbox = {
    pairs=pairs, ipairs=ipairs, tostring=tostring, tonumber=tonumber,
    table=table, string=string, math=math, type=type, load=load, next=next,
    error=error, pcall=pcall, select=select,
    unicode = hw.unicode,
    print = Oxygen.ttyPrint,
    readln = Syscalls.readln,
    spawn = Oxygen.exec,
    exit = Syscalls.exit,
    sys = {
      read = Syscalls.readFile,
      write = Syscalls.writeFile,
      ls = Syscalls.list,
      mkdir = Syscalls.mkDir,
      fetch = Syscalls.fetch,
      gpu = {
        set = Syscalls.gpu_set,
        fill = Syscalls.gpu_fill,
        copy = Syscalls.gpu_copy,
        res = Syscalls.gpu_res,
        color = Syscalls.gpu_color
      },
      pull = Syscalls.pull
    },
    cat = Syscalls.readFile,
    ls = Syscalls.list,
    fetch = Syscalls.fetch
  }
  
  local proc, e = load(code, "="..path, "t", sandbox)
  if not proc then Oxygen.ttyPrint("Syn: "..tostring(e)) return end
  local ok, perr = pcall(proc, table.unpack(args))
  if not ok then Oxygen.ttyPrint("Runtime: " .. tostring(perr)) end
end

-- [7] INIT
Oxygen.ttyPrint("OxygenOS Kernel v0.6.2 (NetDebug)")
Oxygen.exec("/bin/sh.lua")
while true do hw.computer.pullSignal() end