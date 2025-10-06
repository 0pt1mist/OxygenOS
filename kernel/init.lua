-- kernel/init.lua для EEPROM
-- OxygenOS v0.1 - BIOS-совместимая версия

-- === Базовые проверки в EEPROM ===
if not component or not computer then
  return
end

-- === Минимальный вывод для EEPROM ===
local function debugPrint(message)
  -- Получаем GPU напрямую
  local gpu = component.gpu
  if not gpu then
    -- Пробуем найти GPU через список компонентов
    for addr in component.list("gpu") do
      gpu = component.proxy(addr)
      break
    end
  end
  
  if gpu then
    -- Пробуем привязаться к экрану
    for screenAddr in component.list("screen") do
      if gpu.getScreen() ~= screenAddr then
        gpu.bind(screenAddr)
      end
      break
    end
    
    -- Выводим текст
    gpu.set(1, 1, tostring(message))
    return true
  end
  
  -- Если экрана нет, используем звук
  computer.beep(500, 0.1)
  return false
end

debugPrint("OxygenOS Booting...")

-- === Поиск и загрузка shell ===
local function findAndLoadShell()
  for fsAddr in component.list("filesystem") do
    local fs = component.proxy(fsAddr)
    
    local shellPaths = {
      "/bin/shell",
      "bin/shell", 
      "/shell",
      "shell"
    }
    
    for _, path in ipairs(shellPaths) do
      if fs.exists(path) and not fs.isDirectory(path) then
        debugPrint("Found: " .. path)
        
        local handle = fs.open(path, "r")
        if not handle then
          return nil
        end
        
        local content = ""
        while true do
          local chunk = fs.read(handle, 1024)
          if not chunk then break end
          content = content .. chunk
        end
        fs.close(handle)
        
        if content and content ~= "" then
          return load(content, "=shell")
        end
      end
    end
  end
  return nil
end

-- === Основная процедура загрузки ===
local function main()
  computer.pullSignal(0.5)
  
  local shell, err = findAndLoadShell()
  if not shell then
    debugPrint("Shell not found")
    
    -- Аварийный режим с базовыми командами
    while true do
      debugPrint("Emergency mode - reboot")
      computer.pullSignal(1)
    end
  end
  
  local success, shellErr = pcall(shell)
  if not success then
    debugPrint("Shell crash: " .. tostring(shellErr))
  end
  
  computer.shutdown(true)
end

-- Запускаем систему
local ok, err = pcall(main)
if not ok then
  debugPrint("Boot failed")
  computer.shutdown(true)
end