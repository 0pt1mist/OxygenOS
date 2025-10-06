-- kernel/init.lua для EEPROM
-- OxygenOS v0.1 - BIOS-совместимая версия

-- === Базовые проверки в EEPROM ===
if not component or not computer then
  -- В EEPROM нет стандартного print, используем прямой вывод
  computer.beep(1000, 0.5)  -- Сигнал ошибки
  return
end

-- === Минимальный вывод для EEPROM ===
local function debugPrint(message)
  -- Пытаемся найти экран и вывести текст
  for addr in component.list("screen") do
    local screen = component.proxy(addr)
    local gpu = screen.getGPU()
    if gpu then
      gpu.set(1, 1, tostring(message))
      return
    end
  end
  
  -- Если экрана нет, используем компьютерный спикер для сигнала
  computer.beep(500, 0.1)
end

debugPrint("OxygenOS Booting...")

-- === Поиск и загрузка shell ===
local function findAndLoadShell()
  -- Ищем файловую систему с shell
  for fsAddr in component.list("filesystem") do
    local fs = component.proxy(fsAddr)
    
    -- Проверяем разные возможные пути
    local shellPaths = {
      "/bin/shell",
      "bin/shell", 
      "/shell",
      "shell"
    }
    
    for _, path in ipairs(shellPaths) do
      if fs.exists(path) and not fs.isDirectory(path) then
        debugPrint("Found: " .. path)
        
        -- Читаем файл shell
        local handle = fs.open(path, "r")
        if not handle then
          debugPrint("Cannot open: " .. path)
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
  -- Ждем инициализации компонентов
  computer.pullSignal(0.5)
  
  -- Ищем и загружаем shell
  local shell, err = findAndLoadShell()
  if not shell then
    debugPrint("Shell not found: " .. tostring(err))
    
    -- Аварийный режим
    while true do
      computer.pullSignal()
      -- Можно добавить базовое взаимодействие через клавиатуру
    end
  end
  
  -- Запускаем shell
  local success, shellErr = pcall(shell)
  if not success then
    debugPrint("Shell crashed: " .. tostring(shellErr))
  end
  
  -- Если shell завершился, перезагружаемся
  computer.shutdown(true)
end

-- Запускаем систему
local ok, err = pcall(main)
if not ok then
  debugPrint("Boot failed: " .. tostring(err))
  computer.shutdown(true)
end