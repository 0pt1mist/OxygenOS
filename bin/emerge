-- Portage v1.0 (Package Manager)
-- Args: строка "install pkg" или "sync"

local args_raw = ... -- Получаем аргументы от spawn
local REPO_URL = "https://raw.githubusercontent.com/USERNAME/OxygenOS/test/"
local DB_PATH = "/etc/oxygen/packages.db"

-- Парсинг аргументов
local args = {}
for w in string.gmatch(args_raw or "", "%S+") do table.insert(args, w) end

local action = args[1]
local target = args[2]

-- Вспомогательные функции
local function loadDB()
  local data = cat(DB_PATH)
  if not data then return {} end
  local f = load("return " .. data)
  if f then return f() else return {} end
end

local function saveDB(db)
  local str = "{"
  for pkg, ver in pairs(db) do
    str = str .. '["' .. pkg .. '"]="' .. ver .. '",'
  end
  str = str .. "}"
  -- Убедимся, что папка существует
  mkdir("/etc")
  mkdir("/etc/oxygen")
  write(DB_PATH, str)
end

-- Логика
if action == "sync" then
  print("Portage: Syncing from " .. REPO_URL)
  local index = fetch(REPO_URL .. "packages.index")
  
  if index and #index > 0 then
    mkdir("/var")
    write("/var/packages.index", index)
    print("Sync complete.")
  else
    print("Error: Failed to fetch index.")
  end

elseif action == "list" then
  local index_raw = cat("/var/packages.index")
  if not index_raw then print("Error: No index. Run 'emerge sync'") return end
  
  local index = load("return " .. index_raw)()
  local db = loadDB()
  
  print("Package List:")
  for cat, pkgs in pairs(index) do
    for name, data in pairs(pkgs) do
      local cur = db[name] or "-"
      print(name .. " [" .. cur .. "] -> " .. data.version)
    end
  end

elseif action == "install" then
  if not target then print("Usage: emerge install <pkg>") return end
  
  local index_raw = cat("/var/packages.index")
  if not index_raw then print("Error: No index.") return end
  local index = load("return " .. index_raw)()
  
  -- Поиск пакета
  local pkg_data = nil
  for cat, pkgs in pairs(index) do
    if pkgs[target] then pkg_data = pkgs[target] break end
  end
  
  if not pkg_data then print("Package not found.") return end
  
  print("Downloading " .. target .. "...")
  local content = fetch(REPO_URL .. pkg_data.path)
  
  if content then
    print("Installing to " .. pkg_data.dest)
    -- TODO: Создать директорию назначения если её нет, парся путь
    write(pkg_data.dest, content)
    
    local db = loadDB()
    db[target] = pkg_data.version
    saveDB(db)
    print("Done.")
  else
    print("Download failed.")
  end

else
  print("Usage: emerge [sync|list|install <pkg>]")
end