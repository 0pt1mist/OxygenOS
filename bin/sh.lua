-- Oxygen Shell v2.1
-- Features: Path resolution, CD, Auto-bin search, Stable LS

local args = {...}
local current_dir = "/"

-- [1] ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ

-- Превращает относительные пути (test, ../bin) в абсолютные (/home/test, /bin)
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

-- Проверка типа объекта (файл или папка)
local function exists(path)
  -- Пробуем получить список файлов (значит папка)
  local list = ls(path)
  if list then return "dir" end
  
  -- Пробуем прочитать (значит файл)
  local content = cat(path)
  if content then return "file" end
  
  return nil
end

-- [2] ГЛАВНЫЙ ЦИКЛ
print("OxygenOS Shell v2.1")
print("Welcome " .. (os.getenv("USER") or "root"))

while true do
  -- Отрисовка красивого промпта (Зеленый путь # Белый текст)
  if sys and sys.gpu then
    sys.gpu.color(0x00FF00, 0x000000) -- Зеленый
    sys.gpu.set(1, sys.gpu.res(), current_dir .. " # ")
    sys.gpu.color(0xFFFFFF, 0x000000) -- Белый
  else
    -- Фолбэк если драйвера GPU нет (на всякий случай)
    print(current_dir .. " # ")
  end
  
  -- Ожидание ввода
  local input = readln()
  
  -- Разбиваем ввод на слова
  local parts = {}
  for w in string.gmatch(input, "%S+") do table.insert(parts, w) end
  
  if #parts > 0 then
    local cmd = parts[1]
    local arg1 = parts[2]
    
    -- === ВСТРОЕННЫЕ КОМАНДЫ ===
    
    if cmd == "exit" then
      exit()
      
    elseif cmd == "cd" then
      if not arg1 then
        current_dir = "/" -- cd без аргументов -> в корень
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
      -- Если аргумент дан, смотрим ту папку, иначе текущую
      local target = current_dir
      if arg1 then target = resolvePath(arg1) end
      
      local l = ls(target)
      if l then
        local output = ""
        local count = 0
        -- ИСПРАВЛЕНИЕ: Используем pairs для обхода таблицы
        for _, file in pairs(l) do
           output = output .. file .. "  "
           count = count + 1
           -- Перенос строки каждые 4 файла
           if count % 4 == 0 then output = output .. "\n" end
        end
        print(output)
      else
        print("ls: cannot access " .. target)
      end
      
    elseif cmd == "cat" then
      if not arg1 then 
        print("Usage: cat <file>") 
      else
        local target = resolvePath(arg1)
        local data = cat(target)
        if data then print(data) else print("cat: file not found") end
      end

    elseif cmd == "help" then
      print("Builtins: cd, pwd, ls, cat, exit")
      print("System:   emerge, nano")
      
    else
      -- === ЗАПУСК ПРОГРАММ ===
      
      local run_path = nil
      local abs_test = resolvePath(cmd)
      local bin_test = resolvePath("/bin/" .. cmd)
      
      -- 1. Ищем в /bin/ (чтобы работало 'nano' вместо '/bin/nano')
      if exists(bin_test) == "file" then
        run_path = bin_test
      -- 2. Ищем по указанному пути (или в текущей папке)
      elseif exists(abs_test) == "file" then
        run_path = abs_test
      end
      
      if run_path then
        -- Собираем аргументы для программы
        local args_to_pass = ""
        if #parts > 1 then
           -- Если это nano, нам нужно превратить имя файла в полный путь,
           -- так как nano не знает про current_dir шелла
           if cmd == "nano" or cmd == "edit" then
             args_to_pass = resolvePath(arg1)
           else
             -- Для остальных программ передаем аргументы как есть
             args_to_pass = table.concat(parts, " ", 2)
           end
        end
        
        spawn(run_path, args_to_pass)
      else
        print("Unknown command: " .. cmd)
      end
    end
  end
end