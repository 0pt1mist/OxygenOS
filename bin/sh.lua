-- Oxygen Shell v2.0 (Path & CD Support)
local args = {...}

-- [1] STATE
local current_dir = "/"

-- [2] HELPERS

-- Функция очистки пути (превращает /foo/bar/../baz в /foo/baz)
local function resolvePath(path)
  -- Если путь не начинается с /, добавляем текущую директорию
  if string.sub(path, 1, 1) ~= "/" then
    if current_dir == "/" then
      path = "/" .. path
    else
      path = current_dir .. "/" .. path
    end
  end

  local parts = {}
  for part in string.gmatch(path, "[^/]+") do
    if part == ".." then
      if #parts > 0 then table.remove(parts) end
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  
  local res = "/" .. table.concat(parts, "/")
  return res
end

-- Функция проверки существования файла/папки
local function exists(path)
  -- Используем ls для проверки. Если ls возвращает таблицу - папка.
  -- Если возвращает строку (или поведение sys.ls) - файл.
  -- В нашем ядре ls возвращает итератор или список.
  -- Проще всего попробовать прочитать (cat) или листнуть.
  -- В Kernel v0.6+ sys.ls возвращает итератор.
  local list = ls(path)
  if list then return "dir" end
  
  local content = cat(path)
  if content then return "file" end
  
  return nil
end

-- [3] MAIN LOOP
print("OxygenOS Shell v2.0")

while true do
  -- Красивый промпт: /home/user #
  sys.gpu.color(0x00FF00, 0x000000) -- Зеленый текст
  sys.gpu.set(1, sys.gpu.res(), current_dir .. " # ")
  sys.gpu.color(0xFFFFFF, 0x000000) -- Белый текст
  
  -- Ввод с учетом длины промпта (простой костыль с пробелами)
  -- В идеале readln должен принимать prompt аргументом, но пока так:
  local input = readln()
  
  local parts = {}
  for w in string.gmatch(input, "%S+") do table.insert(parts, w) end
  
  if #parts > 0 then
    local cmd = parts[1]
    local arg1 = parts[2]
    
    -- === BUILT-IN COMMANDS ===
    
    if cmd == "exit" then
      exit()
      
    elseif cmd == "cd" then
      if not arg1 then
        current_dir = "/" -- cd без аргументов кидает в корень
      else
        local new_path = resolvePath(arg1)
        if exists(new_path) == "dir" then
          current_dir = new_path
        else
          print("cd: path not found or not a directory: " .. new_path)
        end
      end
      
    elseif cmd == "pwd" then
      print(current_dir)
      
    elseif cmd == "ls" then
      -- Если аргумент дан, резолвим его. Если нет - текущая папка.
      local target = current_dir
      if arg1 then target = resolvePath(arg1) end
      
      local l = ls(target)
      if l then
        local output = ""
        local count = 0
        for file in l do
           output = output .. file .. "  "
           count = count + 1
           if count % 4 == 0 then output = output .. "\n" end
        end
        print(output)
      else
        print("ls: cannot access " .. target)
      end
      
    elseif cmd == "cat" then
      if not arg1 then print("Usage: cat <file>") else
        local target = resolvePath(arg1)
        local data = cat(target)
        if data then print(data) else print("cat: file not found") end
      end

    elseif cmd == "help" then
      print("Builtins: cd, pwd, ls, cat, exit")
      print("Binaries: nano, emerge, etc.")
      
    else
      -- === EXTERNAL BINARIES ===
      -- Логика поиска программ:
      -- 1. Сначала ищем в текущей папке (если путь явный ./...)
      -- 2. Ищем в /bin
      -- 3. Ищем по абсолютному пути
      
      local run_path = nil
      local abs_test = resolvePath(cmd)
      local bin_test = resolvePath("/bin/" .. cmd)
      
      -- Пробуем /bin/имя
      if exists(bin_test) == "file" then
        run_path = bin_test
      -- Пробуем текущую директорию/абсолютный путь
      elseif exists(abs_test) == "file" then
        run_path = abs_test
      end
      
      if run_path then
        -- Собираем аргументы в строку
        local args_to_pass = ""
        if #parts > 1 then
           args_to_pass = table.concat(parts, " ", 2)
        end
        
        -- ВАЖНО: Мы передаем полный путь к файлу.
        -- Но сами программы (типа nano) могут получать относительные пути в аргументах.
        -- Нам нужно либо учить программы понимать relative path, 
        -- либо (лучше) резолвить аргументы здесь, если они похожи на пути.
        -- ДЛЯ NANO:
        if cmd == "nano" and arg1 then
             args_to_pass = resolvePath(arg1)
        end
        
        spawn(run_path, args_to_pass)
      else
        print("Unknown command: " .. cmd)
      end
    end
  end
end