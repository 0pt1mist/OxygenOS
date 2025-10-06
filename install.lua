-- OxygenOS Installer v1.0 с выбором диска
local component = require("component")
local computer = require("computer")
local term = require("term")

print("=== OxygenOS Installer ===")

-- Получить список всех подходящих дисков
local function getAvailableDisks()
  local disks = {}
  
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if not fs.isReadOnly() and fs.spaceTotal() > 100000 then
      table.insert(disks, {
        address = addr,
        fs = fs,
        label = fs.getLabel() or "No Label",
        size = math.floor(fs.spaceTotal() / 1024) .. " KB",
        free = math.floor((fs.spaceTotal() - fs.spaceUsed()) / 1024) .. " KB"
      })
    end
  end
  
  return disks
end

-- Показать меню выбора диска
local function selectDisk(disks)
  if #disks == 0 then
    print("No suitable disks found!")
    print("Need writable disk with >100KB free space")
    return nil
  end
  
  print("\nAvailable disks:")
  print("№  Address         Label        Size     Free")
  print("--------------------------------------------")
  
  for i, disk in ipairs(disks) do
    print(string.format("%d. %s %-12s %-8s %-8s", 
      i, disk.address:sub(1, 8).."...", disk.label, disk.size, disk.free))
  end
  
  if #disks == 1 then
    print("\nOnly one disk found. Using it automatically.")
    return disks[1]
  end
  
  while true do
    io.write("\nSelect disk (1-" .. #disks .. "): ")
    local input = io.read()
    local choice = tonumber(input)
    
    if choice and choice >= 1 and choice <= #disks then
      return disks[choice]
    else
      print("Invalid choice! Please enter number 1-" .. #disks)
    end
  end
end

-- Подтверждение установки
local function confirmInstallation(disk)
  print("\nInstallation summary:")
  print("Disk: " .. disk.address)
  print("Label: " .. disk.label)
  print("Size: " .. disk.size)
  print("WARNING: All data on this disk will be erased!")
  
  while true do
    io.write("Proceed with installation? (y/N): ")
    local input = io.read():lower()
    
    if input == "y" or input == "yes" then
      return true
    elseif input == "n" or input == "no" or input == "" then
      return false
    else
      print("Please enter 'y' for Yes or 'n' for No")
    end
  end
end

-- Создать структуру каталогов
local function createDirectoryStructure(hdd)
  local dirs = {"/bin", "/etc", "/home", "/tmp", "/var", "/usr"}
  
  print("Creating directory structure...")
  for _, dir in ipairs(dirs) do
    if not hdd.exists(dir) then
      hdd.makeDirectory(dir)
    end
  end
end

-- Копировать файлы с текущего носителя
local function copyFile(sourceFs, sourcePath, destFs, destPath)
  if not sourceFs.exists(sourcePath) then
    error("Source file not found: " .. sourcePath)
  end
  
  print("Copying: " .. sourcePath .. " -> " .. destPath)
  
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
local function findInstallerFs()
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if fs.exists("install.lua") then
      return fs
    end
  end
  return nil
end

-- Основная функция установки
local function install()
  -- Получить список дисков
  local disks = getAvailableDisks()
  
  -- Выбрать диск
  local selectedDisk = selectDisk(disks)
  if not selectedDisk then
    return
  end
  
  -- Подтверждение
  if not confirmInstallation(selectedDisk) then
    print("Installation cancelled.")
    return
  end
  
  -- Найти установочные файлы
  local installerFs = findInstallerFs()
  if not installerFs then
    print("ERROR: Cannot find installer files!")
    return
  end
  
  -- Начать установку
  print("\nStarting installation...")
  
  -- Создать структуру каталогов
  createDirectoryStructure(selectedDisk.fs)
  
  -- Скопировать файлы
  copyFile(installerFs, "kernel/init.lua", selectedDisk.fs, "/init.lua")
  copyFile(installerFs, "kernel/bin/shell", selectedDisk.fs, "/bin/shell")
  
  -- Установить метку
  selectedDisk.fs.setLabel("OXYGEN")
  
  -- Завершение
  print("\n=== Installation complete! ===")
  print("Disk: " .. selectedDisk.address)
  print("Label: " .. selectedDisk.fs.getLabel())
  print("\nTo boot OxygenOS:")
  print("1. Reboot computer")
  print("2. In BIOS: Set this disk as boot device")
  print("3. Save and exit BIOS")
end

-- Запустить установку
local success, err = pcall(install)
if not success then
  print("INSTALLATION FAILED: " .. tostring(err))
  print("Please check your setup and try again.")
end