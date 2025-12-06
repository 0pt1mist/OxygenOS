-- OxygenOS Installer v0.9 (Corrected)
local component = require("component")
local computer = require("computer")
local shell = require("shell") -- Используем API текущей системы для удобства
local fs = require("filesystem")

if not component.isAvailable("internet") then
  error("Internet Card required!", 0)
end
local internet = component.proxy(component.list("internet")())

-- 1. Поиск подходящего HDD
local installDisk = nil
for addr in component.list("filesystem") do
  local proxy = component.proxy(addr)
  -- Ищем диск, который не read-only и не является текущим загрузочным (tmpfs)
  if not proxy.isReadOnly() and proxy.address ~= computer.tmpAddress() and proxy.spaceTotal() > 1000000 then
    installDisk = proxy
    break
  end
end

if not installDisk then error("No suitable HDD found (>1MB, R/W)!", 0) end
print("Installing to: " .. installDisk.address:sub(1, 8))

-- 2. Форматирование (Опционально, но надежно)
installDisk.setLabel("OXYGEN")
local dirs = {"/bin", "/etc", "/usr", "/dev", "/home", "/var"}
for _, d in ipairs(dirs) do
  if not installDisk.exists(d) then installDisk.makeDirectory(d) end
end

-- 3. Функция загрузки (Wget-style)
local function download(url, path)
  print("Downloading " .. path .. "...")
  local handle, err = internet.request(url)
  if not handle then error("Request failed: " .. tostring(err)) end
  
  local fileHandle = installDisk.open(path, "wb")
  
  while true do
    -- Читаем данные из web-хэндла
    local chunk = internet.read(handle, math.huge)
    if chunk and #chunk > 0 then
      installDisk.write(fileHandle, chunk)
    elseif chunk == nil then -- Конец потока
      break 
    elseif #chunk == 0 then -- Ожидание данных
      os.sleep(0) 
    end
  end
  
  installDisk.close(fileHandle)
  internet.close(handle) -- Закрываем соединение
end

-- 4. Загрузка компонентов системы
local BASE = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/main"
-- ВАЖНО: В реальном сценарии файлы должны быть на GitHub. 
-- Сейчас код предполагает, что они там есть. Если нет - создайте их локально.

-- Для теста я напишу код файлов прямо на диск, так как ссылок может не существовать
local function writeLocal(path, content)
  print("Writing " .. path)
  local f = installDisk.open(path, "w")
  installDisk.write(f, content)
  installDisk.close(f)
end

-- === ЗАПИСЬ ЯДРА (INIT.LUA) ===
writeLocal("/init.lua", [[
-- OxygenOS Kernel v0.1
local component = component or require("component")
local computer = computer or require("computer")
local unicode = unicode or require("unicode")

-- 1. Low-level Hardware Initialization
local gpu = component.proxy(component.list("gpu")())
local screen = component.list("screen")()
if gpu and screen then gpu.bind(screen) end

local function kprint(msg)
  if gpu then
    local w, h = gpu.getResolution()
    gpu.copy(1, 2, w, h - 1, 0, -1)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(1, h, tostring(msg))
  end
end

kprint("OxygenOS Kernel Initializing...")

-- 2. Filesystem Driver (Mocking required library)
local bootAddr = computer.getBootAddress()
local bootFS = component.proxy(bootAddr)

local fs_lib = {}
function fs_lib.list(path) return bootFS.list(path) end
function fs_lib.exists(path) return bootFS.exists(path) end
function fs_lib.isDirectory(path) return bootFS.isDirectory(path) end
function fs_lib.readFile(path)
  local h = bootFS.open(path, "r")
  if not h then return nil end
  local buffer = ""
  repeat
    local data = bootFS.read(h, math.huge)
    if data then buffer = buffer .. data end
  until not data
  bootFS.close(h)
  return buffer
end

-- Inject into package.loaded so 'require("filesystem")' works
package.loaded["filesystem"] = fs_lib

-- 3. Device Manager (/dev creation)
kprint("Mounting /dev...")
local dev = {}
for addr, type in component.list() do
  -- Simple incremental naming (gpu0, screen0)
  if not dev[type] then dev[type] = 0 end
  -- In a real OS, we would mount these to /dev/typeN
  dev[type] = dev[type] + 1
end

-- 4. Handover to User Space (Shell)
kprint("Starting /bin/shell...")
local shellCode = fs_lib.readFile("/bin/shell")
if not shellCode then error("Kernel Panic: /bin/shell missing!") end

local shellFunc, err = load(shellCode, "shell")
if not shellFunc then error("Shell Syntax Error: " .. err) end

-- Setup minimal environment for Shell
local env = setmetatable({
  print = kprint,
  io = { write = kprint, read = function() return nil end }, -- Stub
  checkArg = checkArg
}, {__index = _G})

-- Run Shell
local status, err = pcall(shellFunc)
if not status then error("Shell Crash: " .. tostring(err)) end
]])

-- === ЗАПИСЬ SHELL ===
writeLocal("/bin/shell", [[
local fs = require("filesystem")
local component = require("component")
local gpu = component.proxy(component.list("gpu")())

-- Simple Terminal Output
local function print(...)
  local args = {...}
  local str = ""
  for i,v in ipairs(args) do str = str .. tostring(v) .. " " end
  
  if gpu then
    local w, h = gpu.getResolution()
    gpu.copy(1, 2, w, h - 1, 0, -1) -- Scroll
    gpu.fill(1, h, w, 1, " ")
    gpu.set(1, h, str)
  end
end

-- Simple Input (Polling)
local function readLine()
  local str = ""
  local w, h = gpu.getResolution()
  
  while true do
    local name, addr, char, code = computer.pullSignal()
    if name == "key_down" then
      if code == 28 then -- Enter
        return str
      elseif code == 14 then -- Backspace
        if #str > 0 then
          str = str:sub(1, -2)
          gpu.set(1, h, "oxygen# " .. str .. "  ") -- Clear char
        end
      elseif char > 0 then
        str = str .. string.char(char)
      end
      gpu.set(1, h, "oxygen# " .. str .. "_ ")
    end
  end
end

print("Welcome to OxygenOS v0.1")
print("Type 'help' for commands.")

while true do
  local w, h = gpu.getResolution()
  gpu.set(1, h, "oxygen# ")
  
  local input = readLine()
  
  local words = {}
  for w in input:gmatch("%S+") do table.insert(words, w) end
  
  if #words > 0 then
    local cmd = words[1]
    
    if cmd == "exit" then
      computer.shutdown()
    elseif cmd == "reboot" then
      computer.shutdown(true)
    elseif cmd == "ls" then
      local path = words[2] or "/"
      if fs.exists(path) then
        local list = fs.list(path)
        for f in list do print(f) end
      else
        print("Path not found")
      end
    elseif cmd == "help" then
      print("Commands: ls, reboot, exit, help")
    else
      -- Try execute file in /bin
      local binPath = "/bin/" .. cmd
      if fs.exists(binPath) then
        local code = fs.readFile(binPath)
        local f = load(code)
        if f then pcall(f) else print("Exec format error") end
      else
        print("Unknown command: " .. cmd)
      end
    end
  end
end
]])

print("Installation Complete. Rebooting in 3...")
os.sleep(3)
computer.shutdown(true)