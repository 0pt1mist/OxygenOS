-- kernel/init.lua
-- OxygenOS v0.1 — Minimal Boot (BIOS-compatible, no OpenOS dependency)

-- === Проверка: запущено в OpenComputers? ===
if not component or not component.list then
  error("OxygenOS requires OpenComputers!", 0)
end

-- === Монтирование всех дисков ===
print("Mounting filesystems...")
for address in component.list("filesystem") do
  -- Получаем метку через прокси (надёжно)
  local proxy = component.proxy(address)
  local label = proxy.getLabel() or "disk"
  local mountPoint = "/" .. label

  -- Создаём точку монтирования (если нужно)
  -- В BIOS нет filesystem.makeDirectory, поэтому пропускаем
  -- Доверяем, что / уже существует

  -- Отмонтируем и смонтируем
  pcall(component.invoke, address, "mount", mountPoint)
end

-- === Проверка: существует ли /bin/shell? ===
-- Ищем любой диск, где есть /bin/shell
local shellFound = false
for address in component.list("filesystem") do
  local proxy = component.proxy(address)
  if proxy.exists("/bin/shell") then
    -- Убедимся, что диск смонтирован как корень
    -- (обычно это тот, с которого загрузились)
    shellFound = true
    break
  end
end

if not shellFound then
  error("Shell not found! Corrupted or incomplete installation.", 0)
end

-- === Приветствие ===
print("\27[36m🌬️  OxygenOS v0.1\27[0m")
print("Unix-like OS for OpenComputers 1.12.2")
print("")

-- === Запуск shell ===
-- В BIOS нет dofile, но можно использовать loadfile + load
local shellPath = "/bin/shell"
local fileHandle = io.open(shellPath, "r")
if not fileHandle then
  error("Cannot open shell script: " .. shellPath, 0)
end

local content = fileHandle:read("*a")
fileHandle:close()

local fn, err = load(content, "@shell", "t", {})
if not fn then
  error("Shell syntax error: " .. tostring(err), 0)
end

-- Запускаем shell в песочнице
local success, err = pcall(fn)
if not success then
  print("Shell crashed: " .. tostring(err))
  print("Dropping to emergency prompt...")

  -- Простой emergency shell
  while true do
    io.write("EMERGENCY# ")
    local line = io.read()
    if line == "reboot" then
      os.exit()
    elseif line == "ls" then
      for addr in component.list("filesystem") do
        local p = component.proxy(addr)
        for item in p.list("/") do print(item) end
      end
    else
      print("Unknown command")
    end
  end
end