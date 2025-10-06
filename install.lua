-- OxygenOS Network Installer v2.0
local component = require("component")
local computer = require("computer")
local term = require("term")

-- Конфигурация
local REPO_BASE = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/test"
local FILES = {
  "/kernel/init.lua",
  "/kernel/bin/shell"
}

print("=== OxygenOS Network Installer ===")
print("Downloading from GitHub...")

-- Проверка интернет-карты
if not component.isAvailable("internet") then
  print("ERROR: Internet card required!")
  return
end

local internet = component.internet

-- Функция для скачивания файла
local function downloadFile(url, path, fs)
  print("Downloading: " .. path)
  
  local handle, reason = internet.request(url)
  if not handle then
    error("HTTP error: " .. tostring(reason))
  end

  -- Создаем директорию если нужно
  local dir = path:match("(.*)/")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end

  local fileHandle = fs.open(path, "w")
  if not fileHandle then
    error("Cannot create: " .. path)
  end

  local content = ""
  while true do
    local chunk, reason = handle.read(1024)
    if chunk then
      content = content .. chunk
    else
      if reason then
        error("Download failed: " .. tostring(reason))
      end
      break
    end
  end

  fs.write(fileHandle, content)
  fs.close(fileHandle)
  handle.close()
  print("✓ " .. path)
end

-- Проверка доступности GitHub
local function testGitHubConnection()
  print("Testing connection to GitHub...")
  local handle, reason = internet.request(REPO_BASE .. FILES[1])
  if not handle then
    error("Cannot connect to GitHub: " .. tostring(reason))
  end
  
  local testData = handle.read(1024)
  handle.close()
  
  if not testData then
    error("GitHub returned empty response")
  end
  
  print("✓ Connection successful")
end

-- Получить список всех подходящих дисков
local function getAvailableDisks()
  local disks = {}
  
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if not fs.isReadOnly() and fs.spaceTotal() > 100000 then
      local total = fs.spaceTotal()
      local used = fs.spaceUsed()
      local free = total - used
      
      table.insert(disks, {
        address = addr,
        fs = fs,
        label = fs.getLabel() or "No Label",
        size = math.floor(total / 1024) .. " KB",
        free = math.floor(free / 1024) .. " KB"
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
  print("Source: GitHub Repository")
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
local function createDirectoryStructure(fs)
  local dirs = {"/bin", "/etc", "/home", "/tmp", "/var", "/usr"}
  
  print("Creating directory structure...")
  for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
      fs.makeDirectory(dir)
    end
  end
end

-- Основная функция установки
local function install()
  -- Проверка соединения с GitHub
  local ok, err = pcall(testGitHubConnection)
  if not ok then
    print("Network error: " .. tostring(err))
    print("Please check:")
    print("  - Internet card is installed")
    print("  - GitHub is not blocked")
    print("  - Network connection is available")
    return
  end
  
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
  
  -- Начать установку
  print("\nStarting installation...")
  
  -- Создать структуру каталогов
  createDirectoryStructure(selectedDisk.fs)
  
  -- Скачать все файлы
  print("\nDownloading OxygenOS files...")
  for _, file in ipairs(FILES) do
    local ok, err = pcall(downloadFile, REPO_BASE .. file, file, selectedDisk.fs)
    if not ok then
      print("✗ Failed to download: " .. file)
      print("Error: " .. tostring(err))
      return
    end
  end
  
  -- Установить метку
  selectedDisk.fs.setLabel("OXYGEN")
  
  -- Завершение
  print("\n" .. string.rep("=", 40))
  print("=== Installation complete! ===")
  print(string.rep("=", 40))
  print("Disk: " .. selectedDisk.address)
  print("Label: " .. selectedDisk.fs.getLabel())
  print("\nTo boot OxygenOS:")
  print("1. Reboot computer (type 'reboot')")
  print("2. In BIOS: Set this disk as boot device")
  print("3. Save and exit BIOS")
  print("\nReboot now? (y/N): ")
  
  local input = io.read():lower()
  if input == "y" or input == "yes" then
    computer.shutdown(true)
  end
end

-- Запустить установку
print("OxygenOS Network Installer ready")
print("Repository: " .. REPO_BASE)
local success, err = pcall(install)
if not success then
  print("\nINSTALLATION FAILED: " .. tostring(err))
  print("Please check your setup and try again.")
end