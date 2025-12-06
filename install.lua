-- OxygenOS Installer v1.0 (GitHub Edition)
local component = require("component")
local internet = require("internet")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

-- КОНФИГУРАЦИЯ
local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/test/"

-- Список файлов для скачивания
-- { path = "куда сохранить на диске", remote = "путь в репозитории" }
local file_list = {
  { path = "/init.lua",        remote = "boot/init.lua" },
  { path = "/boot/kernel.lua", remote = "boot/kernel.lua" },
  { path = "/bin/sh.lua",      remote = "bin/sh.lua" },
  { path = "/bin/emerge",      remote = "bin/emerge" }
}

term.clear()
print("OxygenOS Web Installer")
print("Source: " .. REPO_URL)

-- 1. Выбор диска
local filesystems = {}
local i = 1
for address, type in component.list("filesystem") do
  local proxy = component.proxy(address)
  if proxy then
    -- Исключаем текущий загрузочный диск (OpenOS), ищем только RW диски
    local current_boot = fs.get(os.getenv("SHELL")).address
    if not proxy.isReadOnly() and address ~= current_boot then
      filesystems[i] = proxy
      print(i .. ": " .. address .. " (Target)")
      i = i + 1
    end
  end
end

if #filesystems == 0 then
  print("Error: No suitable target disk found.")
  print("Please insert a blank Tier 2/3 HDD.")
  return
end

io.write("Select target drive [1-" .. (#filesystems) .. "]: ")
local choice = tonumber(io.read())
local disk = filesystems[choice]

if not disk then 
  print("Invalid selection.") 
  return 
end

print("Installing to " .. disk.address .. "...")

-- 2. Создание структуры папок
print("Creating directories...")
local dirs = {
  "/boot", 
  "/bin", 
  "/dev",       -- Для монтирования устройств ядром
  "/etc", 
  "/etc/oxygen", -- Для базы данных пакетов
  "/home", 
  "/lib", 
  "/usr", 
  "/var",       -- Для кэша emerge
  "/tmp"
}

for _, d in ipairs(dirs) do
  if not disk.exists(d) then 
    disk.makeDirectory(d) 
  end
end

-- 3. Скачивание файлов
for _, file in ipairs(file_list) do
  local url = REPO_URL .. file.remote
  print("Downloading " .. file.remote .. " ...")
  
  -- Запрос к GitHub
  local handle, err = internet.request(url)
  
  if handle then
    local content = ""
    for chunk in handle do 
      content = content .. chunk 
    end
    
    -- Проверка на 404 (GitHub возвращает строку "404: Not Found" в теле, если файл не raw, 
    -- но так как мы берем raw, если файла нет, handle обычно закрывается или возвращает ошибку)
    if #content < 10 and string.find(content, "404") then
      print("ERROR: File not found on GitHub (404): " .. file.remote)
    else
      local f = disk.open(file.path, "w")
      disk.write(f, content)
      disk.close(f)
      print("OK -> " .. file.path)
    end
  else
    print("ERROR: Connection failed: " .. tostring(err))
  end
end

print("---------------------------------------------------")
print("Installation Complete.")
print("1. Remove OpenOS Boot Disk.")
print("2. Reboot the computer.")