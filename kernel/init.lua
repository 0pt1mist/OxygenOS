-- kernel/init.lua
-- OxygenOS v0.1 — оптимизированная для малой памяти

-- Минимальный print для экономии памяти
local function print(...)
  local args = {...}
  for i = 1, #args do
    io.write(tostring(args[i]))
    if i < #args then io.write("\t") end
  end
  io.write("\n")
end

-- Базовая проверка компонентов
if not component or not component.list then
  print("OxygenOS requires OpenComputers!")
  return
end

print("OxygenOS v0.1")
print("Booting...")

-- Поиск файловой системы с shell
local function findShell()
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if fs.exists("/bin/shell") then
      return fs, "/bin/shell"
    end
  end
  return nil
end

local fs, shellPath = findShell()
if not fs then
  print("ERROR: Shell not found!")
  print("Check /bin/shell on any disk")
  return
end

-- Минимальная загрузка shell
local function loadShell()
  local handle = fs.open(shellPath, "r")
  if not handle then
    print("ERROR: Cannot open shell")
    return nil
  end
  
  local content = ""
  while true do
    local chunk = fs.read(handle, 1024)
    if not chunk then break end
    content = content .. chunk
  end
  fs.close(handle)
  
  if content == "" then
    print("ERROR: Shell is empty")
    return nil
  end
  
  return load(content, "=shell")
end

-- Освобождаем память перед загрузкой shell
collectgarbage()

local shell, err = loadShell()
if not shell then
  print("SHELL ERROR: " .. tostring(err))
  print("Emergency mode:")
  
  -- Ультра-легковесный аварийный режим
  while true do
    io.write("> ")
    local cmd = io.read()
    if not cmd then break end
    
    if cmd == "reboot" then
      computer.shutdown(true)
    elseif cmd == "exit" then
      break
    elseif cmd == "ls" then
      for addr in component.list("filesystem") do
        local fs = component.proxy(addr)
        print("FS:", addr)
        for item in fs.list("/") do
          print("  " .. item)
        end
      end
    else
      print("Commands: ls, reboot, exit")
    end
  end
  return
end

-- Запуск shell с защитой
local ok, err = pcall(shell)
if not ok then
  print("SHELL CRASH: " .. tostring(err))
  computer.shutdown(true)
end