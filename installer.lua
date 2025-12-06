-- OxygenOS Web Installer
local component = require("component")
local internet = require("internet")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/main/"

local MOCK_MODE = false

local file_list = {
  {path = "/init.lua", remote = "boot/init.lua"},
  {path = "/boot/kernel.lua", remote = "boot/kernel.lua"},
  {path = "/bin/sh.lua", remote = "bin/sh.lua"},
}

term.clear()
print("OxygenOS Web Installer")
print("Source: " .. REPO_URL)

-- 1. Выбор диска (как раньше)
local filesystems = {}
local i = 1
for address, type in component.list("filesystem") do
  local proxy = component.proxy(address)
  if proxy and not proxy.isReadOnly() and address ~= fs.get(os.getenv("SHELL")).address then
    filesystems[i] = proxy
    print(i .. ": " .. address)
    i = i + 1
  end
end
if #filesystems == 0 then print("No disk found") return end
io.write("Target drive: ")
local disk = filesystems[tonumber(io.read())]
if not disk then return end

-- 2. Создание папок
print("Creating directories...")
local dirs = {"/boot", "/bin", "/etc", "/lib", "/usr", "/home"}
for _, d in ipairs(dirs) do
  if not disk.exists(d) then disk.makeDirectory(d) end
end

-- 3. Скачивание файлов
for _, file in ipairs(file_list) do
  print("Downloading " .. file.remote .. " -> " .. file.path)
  
  local content = nil
  
  if MOCK_MODE then
    -- В РЕАЛЬНОСТИ ЭТО БЛОК НУЖНО УДАЛИТЬ, КОГДА БУДЕТ ГИТХАБ
    -- Здесь я просто "инжекчу" код, который написал выше, чтобы ты мог проверить прямо сейчас
    if file.path == "/bin/sh.lua" then
      content = [[
print("Oxygen Shell v1.0")
while true do
  local input = readln()
  if input == "ls" then
    local l = ls("/")
    local s = ""
    for k,v in pairs(l) do s=s..v.." " end
    print(s)
  elseif input == "help" then
    print("Commands: ls, reboot")
  elseif input == "reboot" then
    exit()
  else
    print("Unknown: "..input)
  end
end
]]
    -- Для Kernel и Init используется тот же код, что я давал выше (сократил для примера)
    elseif file.path == "/boot/kernel.lua" then
       print("!! PLEASE UPDATE KERNEL CODE MANUALLY IN MOCK MODE OR USE GITHUB !!")
       -- Тут должен быть огромный кусок кода ядра.
       -- Для теста используй тот код ядра v0.2, что я дал выше, вставив его руками в файл на диске
       -- или загрузи на Github и поставь MOCK_MODE = false
    end
  else
    -- НАСТОЯЩАЯ ЗАГРУЗКА
    local url = REPO_URL .. file.remote
    local handle = internet.request(url)
    local result = ""
    for chunk in handle do result = result .. chunk end
    content = result
  end

  if content then
    local f = disk.open(file.path, "w")
    disk.write(f, content)
    disk.close(f)
  else
    print("Error downloading " .. file.remote)
  end
end

print("Installation Done.")