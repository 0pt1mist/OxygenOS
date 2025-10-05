-- kernel/init.lua
-- OxygenOS v0.1 — BIOS-compatible, no OpenOS dependency

-- === Безопасный print ===
local function safePrint(...)
  if type(print) == "function" then
    print(...)
  else
    local args = {...}
    for i = 1, #args do
      io.write(tostring(args[i]) .. "\t")
    end
    io.write("\n")
  end
end

if not print then
  print = safePrint
end

-- === Проверка: запущено в OpenComputers? ===
if not component or not component.list then
  safePrint("OxygenOS requires OpenComputers!")
  return
end

safePrint("🌬️  OxygenOS v0.1")
safePrint("Unix-like OS for OpenComputers 1.12.2")
safePrint("")

-- === Проверка: существует ли /bin/shell? ===
local shellPath = "/bin/shell"
local file = io.open(shellPath, "r")
if not file then
  safePrint("ERROR: Shell not found! Corrupted installation.")
  safePrint("Expected: /bin/shell on boot disk.")
  return
end
file:close()

-- === Загрузка и запуск shell ===
local content = ""
local f = io.open(shellPath, "r")
if f then
  content = f:read("*a")
  f:close()
end

if content == "" then
  safePrint("ERROR: Shell is empty!")
  return
end

local fn, err = load(content, "@shell", "t", {})
if not fn then
  safePrint("SHELL LOAD ERROR: " .. tostring(err))
  return
end

-- Запуск
local success, err = pcall(fn)
if not success then
  safePrint("SHELL CRASHED: " .. tostring(err))
  safePrint("EMERGENCY MODE")

  while true do
    io.write("# ")
    local cmd = io.read()
    if cmd == "reboot" then
      os.exit()
    elseif cmd == "ls" then
      local fsys = component.list("filesystem")()
      if fsys then
        local proxy = component.proxy(fsys)
        for item in proxy.list("/") do
          safePrint(item)
        end
      end
    else
      safePrint("Unknown command")
    end
  end
end