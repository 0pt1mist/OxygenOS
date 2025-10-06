-- OxygenOS Installer v0.9.1
local component = require("component")
local computer = require("computer")

print("OxygenOS Installer")

-- Найти HDD для установки
local function findHDD()
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if not fs.isReadOnly() and fs.spaceTotal() > 100000 then
      return fs, addr
    end
  end
  return nil
end

local hdd, hddAddr = findHDD()
if not hdd then
  print("No suitable HDD found! Need writable disk with >100KB space")
  return
end

print("Installing to: " .. hddAddr)

-- Создать структуру каталогов
local dirs = {"/bin", "/etc", "/home", "/tmp", "/var"}
for _, dir in ipairs(dirs) do
  if not hdd.exists(dir) then
    hdd.makeDirectory(dir)
  end
end

-- Копировать файлы с текущего носителя
local function copyFile(sourceFs, sourcePath, destFs, destPath)
  if not sourceFs.exists(sourcePath) then
    error("Source file not found: " .. sourcePath)
  end
  
  local sourceHandle = sourceFs.open(sourcePath, "r")
  local destHandle = destFs.open(destPath, "w")
  
  if not sourceHandle or not destHandle then
    error("Cannot open files for copying: " .. sourcePath .. " -> " .. destPath)
  end
  
  while true do
    local chunk = sourceFs.read(sourceHandle, 1024)
    if not chunk then break end
    destFs.write(destHandle, chunk)
  end
  
  sourceFs.close(sourceHandle)
  destFs.close(destHandle)
end

-- Найти файловую систему установщика (текущую)
local installerFs
for addr in component.list("filesystem") do
  local fs = component.proxy(addr)
  if fs.exists("install.lua") then
    installerFs = fs
    break
  end
end

if not installerFs then
  print("Cannot find installer filesystem!")
  return
end

-- Установить файлы
print("Installing kernel...")
copyFile(installerFs, "kernel/init.lua", hdd, "/init.lua")
copyFile(installerFs, "kernel/bin/shell", hdd, "/bin/shell")

hdd.setLabel("OXYGEN")
print("Installation complete!")
print("Set this disk as boot device and reboot")