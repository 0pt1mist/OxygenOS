-- OxygenOS Kernel v0.2.0 (Syscalls Update)

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

-- [3] KERNEL API & DRIVERS
local Oxygen = {
  gpu = nil,
  screenWidth = 80,
  screenHeight = 25
}

-- GPU Driver
local gpu_addr = hw.component.list("gpu")()
local screen_addr = hw.component.list("screen")()
if gpu_addr and screen_addr then
  Oxygen.gpu = hw.component.proxy(gpu_addr)
  Oxygen.gpu.bind(screen_addr)
  Oxygen.gpu.setResolution(Oxygen.screenWidth, Oxygen.screenHeight)
  Oxygen.gpu.setBackground(0x000000)
  Oxygen.gpu.setForeground(0xFFFFFF)
  Oxygen.gpu.fill(1, 1, Oxygen.screenWidth, Oxygen.screenHeight, " ")
end

function Oxygen.log(msg)
  if Oxygen.gpu then
    Oxygen.gpu.copy(1, 2, 80, 24, 0, -1)
    Oxygen.gpu.fill(1, 24, 80, 1, " ")
    Oxygen.gpu.set(1, 24, "[KER] " .. tostring(msg))
  end
end

-- VFS Driver (Минимальный, только чтение с Boot диска)
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

function Oxygen.listDir(path)
  local list = hw.component.invoke(boot_addr, "list", path)
  return list -- Returns table or nil
end

-- [4] SYSCALL INTERFACE (API для Userland)
local Syscalls = {}

function Syscalls.print(text)
  if Oxygen.gpu then
    -- Эмуляция терминального вывода
    Oxygen.gpu.copy(1, 2, 80, 24, 0, -1)
    Oxygen.gpu.fill(1, 24, 80, 1, " ")
    Oxygen.gpu.set(1, 24, tostring(text))
  end
end

function Syscalls.readln()
  -- Блокирующая функция ввода (очень примитивная)
  local buffer = ""
  Oxygen.gpu.set(1, 24, "> " .. buffer .. "_")
  
  while true do
    local sig = {hw.computer.pullSignal()}
    if sig[1] == "key_down" then
      local char_code = sig[3]
      local key_code = sig[4]
      
      if char_code == 13 then -- Enter
        return buffer
      elseif char_code == 8 then -- Backspace
        if #buffer > 0 then
          buffer = string.sub(buffer, 1, -1)
        end
      elseif char_code >= 32 and char_code <= 126 then
        buffer = buffer .. string.char(char_code)
      end
      -- Redraw input line
      Oxygen.gpu.fill(1, 24, 80, 1, " ")
      Oxygen.gpu.set(1, 24, "> " .. buffer .. "_")
    end
  end
end

function Syscalls.list(path)
  return Oxygen.listDir(path)
end

function Syscalls.read_file(path)
  return Oxygen.readFile(path)
end

function Syscalls.exit()
  hw.computer.shutdown()
end

-- [5] PROCESS LOADER (Песочница)
function Oxygen.exec(path)
  Oxygen.log("Executing: " .. path)
  local code, err = Oxygen.readFile(path)
  if not code then 
    Syscalls.print("Error: " .. tostring(err)) 
    return 
  end

  -- Создаем песочницу для процесса
  local sandbox = {
    print = Syscalls.print,
    readln = Syscalls.readln,
    ls = Syscalls.list,
    cat = Syscalls.read_file,
    exit = Syscalls.exit,
    pairs = pairs, ipairs = ipairs, tostring = tostring, 
    table = table, string = string, math = math
  }
  
  local proc, load_err = load(code, "="..path, "t", sandbox)
  if not proc then
    Syscalls.print("Syntax Error: " .. tostring(load_err))
  else
    -- Запускаем процесс (сейчас это блокирует ядро, позже сделаем coroutines)
    local status, runtime_err = pcall(proc)
    if not status then
      Syscalls.print("Runtime Error: " .. tostring(runtime_err))
    end
  end
end

-- [6] INIT
Oxygen.log("Kernel Loaded. Starting Init (Shell)...")
Oxygen.exec("/bin/sh.lua")

-- Если Shell упадет, ядро останется здесь
while true do
  hw.computer.pullSignal()
end