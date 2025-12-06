-- OxygenOS Kernel v0.6.0 (GUI/Input API Update)

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
  Oxygen.gpu.setBackground(0x000000)
  Oxygen.gpu.setForeground(0xFFFFFF)
  Oxygen.gpu.fill(1, 1, Oxygen.w, Oxygen.h, " ")
end

local inet_addr = hw.component.list("internet")()
if inet_addr then Oxygen.inet = hw.component.proxy(inet_addr) end

-- [4] TTY ENGINE
function Oxygen.ttyPrint(text)
  if not Oxygen.gpu then return end
  text = tostring(text)
  -- Простой скроллинг, если текст внизу экрана
  local _, cy = Oxygen.gpu.get(1, 1) -- хак, нам не узнать позицию курсора без сохранения состояния
  -- Для простоты TTY просто пишет вниз. В v0.6 мы даем контроль программам.
  -- Но для совместимости оставим print как "лог"
  Oxygen.gpu.copy(1, 2, Oxygen.w, Oxygen.h - 1, 0, -1)
  Oxygen.gpu.fill(1, Oxygen.h, Oxygen.w, 1, " ")
  Oxygen.gpu.set(1, Oxygen.h, text)
end

-- [5] SYSTEM CALLS FOR NANO
local Syscalls = {}

-- File System
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

-- Network
Syscalls.fetch = function(url)
  if not Oxygen.inet then return nil, "No Net" end
  local h, e = Oxygen.inet.request(url)
  if not h then return nil, e end
  local b = ""
  while true do
    local d = h.read()
    if not d then break end
    b = b .. d
    hw.computer.pullSignal(0.0)
  end
  h.close()
  return b
end

-- Graphics (Новые возможности для Nano)
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

-- Input (Прямой доступ к событиям)
Syscalls.pull = function(timeout)
  return hw.computer.pullSignal(timeout)
end

-- Compatibility Readln
Syscalls.readln = function()
  -- (Упрощенная версия, так как теперь есть прямой доступ)
  local buf = ""
  while true do
    local s = {hw.computer.pullSignal()}
    if s[1] == "key_down" then
      if s[3] == 13 then return buf
      elseif s[3] == 8 then buf = hw.unicode.sub(buf, 1, -2)
      elseif s[3] >= 32 then buf = buf .. hw.unicode.char(s[3]) end
      -- Эхо вывода опускаем для краткости ядра, Nano использует свой ввод
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
    -- Lua Basics
    pairs=pairs, ipairs=ipairs, tostring=tostring, tonumber=tonumber,
    table=table, string=string, math=math, type=type, load=load, next=next,
    error=error, pcall=pcall, select=select,
    -- Unicode (Важно для Nano!)
    unicode = hw.unicode,
    -- Syscalls
    print = Oxygen.ttyPrint,
    readln = Syscalls.readln,
    spawn = Oxygen.exec,
    exit = Syscalls.exit,
    
    -- API Namespace
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
    -- Aliases for compatibility with old shell
    cat = Syscalls.readFile,
    ls = Syscalls.list,
    fetch = Syscalls.fetch
  }
  
  local proc, e = load(code, "="..path, "t", sandbox)
  if not proc then Oxygen.ttyPrint("Syn: "..tostring(e)) return end
  pcall(proc, table.unpack(args))
end

-- [7] INIT
Oxygen.ttyPrint("OxygenOS Kernel v0.6")
Oxygen.exec("/bin/sh.lua")
while true do hw.computer.pullSignal() end