-- OxygenOS Kernel v0.5.0 (Stable Release)

-- [1] HARDWARE SEIZE (Захват оборудования)
local hw = {
  component = component,
  computer = computer,
  unicode = unicode
}
local boot_addr = hw.computer.getBootAddress()

-- [2] GLOBAL PURGE (Очистка окружения)
_G.component = nil
_G.computer = nil
_G.io = nil
_G.os = nil
_G.print = nil

-- [3] KERNEL DRIVERS (Драйверы)
local Oxygen = {
  gpu = nil,
  inet = nil,
  w = 80, h = 25,
  input_row = 25
}

-- GPU Init
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

-- Network Init
local inet_addr = hw.component.list("internet")()
if inet_addr then
  Oxygen.inet = hw.component.proxy(inet_addr)
end

-- [4] TTY ENGINE (Графический вывод)
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

-- [5] FILE SYSTEM API
function Oxygen.readFile(path)
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

function Oxygen.writeFile(path, data)
  local handle = hw.component.invoke(boot_addr, "open", path, "w")
  if not handle then return false, "Write error" end
  hw.component.invoke(boot_addr, "write", handle, data)
  hw.component.invoke(boot_addr, "close", handle)
  return true
end

function Oxygen.makeDir(path)
  return hw.component.invoke(boot_addr, "makeDirectory", path)
end

-- [6] NETWORK API
function Oxygen.http_get(url)
  if not Oxygen.inet then return nil, "No Internet Card" end
  local handle, err = Oxygen.inet.request(url)
  if not handle then return nil, err end
  
  local buffer = ""
  while true do
    local data, reason = handle.read() 
    if data then
      buffer = buffer .. data
    elseif not data and reason then -- EOF or Error
       break
    elseif not data then -- Just EOF
       break
    end
    hw.computer.pullSignal(0.05) -- Anti-freeze
  end
  handle.close()
  return buffer
end

-- [7] PROCESS & SANDBOX
function Oxygen.exec(path, ...)
  local args = {...}
  local code, err = Oxygen.readFile(path)
  if not code then 
    Oxygen.ttyPrint("Exec Error: " .. tostring(err)) 
    return false
  end

  -- Определение системных вызовов для процессов
  local Syscalls = {
    print = Oxygen.ttyPrint,
    readln = Oxygen.readln,
    ls = function(p) return hw.component.invoke(boot_addr, "list", p) end,
    cat = Oxygen.readFile,
    write = Oxygen.writeFile,
    mkdir = Oxygen.makeDir,
    fetch = Oxygen.http_get,
    spawn = Oxygen.exec,  -- Рекурсивный запуск (процесс запускает процесс)
    exit = function() hw.computer.shutdown() end,
    sleep = function(t) local d = os.time() + t while os.time() < d do hw.computer.pullSignal(0.1) end end
  }

  local sandbox = {
    -- Standard Lua
    pairs=pairs, ipairs=ipairs, tostring=tostring, tonumber=tonumber,
    table=table, string=string, math=math, type=type, load=load, next=next,
    error=error, pcall=pcall, xpcall=xpcall, select=select,
    -- System
    syscall = Syscalls, -- Можно через syscall.print()
    -- Aliases for convenience
    print = Syscalls.print,
    readln = Syscalls.readln,
    spawn = Syscalls.spawn,
    ls = Syscalls.ls,
    cat = Syscalls.cat,
    write = Syscalls.write,
    mkdir = Syscalls.mkdir,
    fetch = Syscalls.fetch,
    exit = Syscalls.exit
  }
  
  local proc, load_err = load(code, "="..path, "t", sandbox)
  if not proc then
    Oxygen.ttyPrint("Syntax Error: " .. tostring(load_err))
    return false
  else
    -- Запуск процесса с передачей аргументов
    local status, runtime_err = pcall(proc, table.unpack(args))
    if not status then
      Oxygen.ttyPrint("Runtime Error: " .. tostring(runtime_err))
    end
    return true
  end
end

-- [8] INPUT HANDLING
function Oxygen.readln()
  local buffer = ""
  local function redraw()
    if not Oxygen.gpu then return end
    Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
    Oxygen.gpu.set(1, Oxygen.input_row, "> " .. buffer .. "_")
  end
  
  redraw()
  while true do
    local sig = {hw.computer.pullSignal()}
    if sig[1] == "key_down" then
      local char = sig[3]
      if char == 13 then -- Enter
        Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
        Oxygen.gpu.set(1, Oxygen.input_row, "> " .. buffer)
        Oxygen.ttyPrint("> " .. buffer)
        return buffer
      elseif char == 8 then -- Backspace
        if #buffer > 0 then buffer = hw.unicode.sub(buffer, 1, -2) end
        redraw()
      elseif char >= 32 and char <= 126 then
        buffer = buffer .. hw.unicode.char(char)
        redraw()
      end
    end
  end
end

-- [9] INIT SEQUENCE
Oxygen.ttyPrint("OxygenOS Kernel v0.5 (Net/Spawn/Stable)")
Oxygen.ttyPrint("Mounting /dev... Done.")
Oxygen.ttyPrint("Starting Init...")

-- Запускаем Shell как главный процесс
Oxygen.exec("/bin/sh.lua")

-- Если Shell упадет, ядро останется здесь
while true do hw.computer.pullSignal() end