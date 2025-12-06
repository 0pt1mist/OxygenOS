-- /init.lua
-- OxygenOS Kernel v0.1 (Stable Boot)

local component = component or require("component")
local computer = computer or require("computer")
local unicode = unicode or require("unicode")

-- === 1. Инициализация Дисплея (Kernel Log) ===
local gpu = component.proxy(component.list("gpu")())
local screen = component.list("screen")()
if gpu and screen then gpu.bind(screen) end
local w, h = gpu.getResolution()

-- Примитивная функция скроллинга для логов ядра
local function kprint(msg)
  if not gpu then return end
  gpu.copy(1, 2, w, h - 1, 0, -1) -- Сдвиг экрана вверх
  gpu.fill(1, h, w, 1, " ")       -- Очистка нижней строки
  gpu.set(1, h, tostring(msg))    -- Вывод сообщения
end

gpu.fill(1, 1, w, h, " ") -- Очистка экрана при загрузке
kprint("OxygenOS Kernel v0.1 loading...")

-- === 2. Драйвер Файловой Системы ===
local bootAddr = computer.getBootAddress()
local bootFS = component.proxy(bootAddr)

-- Создаем API, совместимый с библиотекой "filesystem" OpenOS
local fs_driver = {}

function fs_driver.list(path)
  return bootFS.list(path)
end

function fs_driver.exists(path)
  return bootFS.exists(path)
end

function fs_driver.isDirectory(path)
  return bootFS.isDirectory(path)
end

function fs_driver.readFile(path)
  local handle = bootFS.open(path, "r")
  if not handle then return nil, "File not found" end
  local buffer = ""
  repeat
    local data = bootFS.read(handle, math.huge)
    if data then buffer = buffer .. data end
  until not data
  bootFS.close(handle)
  return buffer
end

-- === 3. Подготовка окружения (User Space) ===
-- Регистрируем fs, чтобы в Shell работал require("filesystem")
package.loaded["filesystem"] = fs_driver

-- Добавляем глобальный print, который использует наш GPU вывод
_G.print = kprint

-- === 4. Запуск Shell ===
kprint("Mounting /bin/shell...")

if not bootFS.exists("/bin/shell") then
  kprint("PANIC: /bin/shell not found!")
  while true do computer.pullSignal() end -- Halt
end

local shellCode = fs_driver.readFile("/bin/shell")
local shellFunc, err = load(shellCode, "shell", "t", _G)

if not shellFunc then
  kprint("Kernel Panic (Syntax Error): " .. tostring(err))
  while true do computer.pullSignal() end
end

-- Передача управления Шелу
local status, err = pcall(shellFunc)

if not status then
  kprint("System Crash: " .. tostring(err))
  kprint("Press Power to reboot.")
end