-- Oxygen Shell v2.2 (Fix: Removed OS dependency)
local args = {...}
local current_dir = "/"

-- [1] HELPERS

local function resolvePath(path)
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

local function exists(path)
  local list = ls(path)
  if list then return "dir" end
  local content = cat(path)
  if content then return "file" end
  return nil
end

-- [2] MAIN LOOP
print("OxygenOS Shell v2.2")
print("Welcome root") -- ИСПРАВЛЕНО: Убрано os.getenv

while true do
  -- Отрисовка промпта
  if sys and sys.gpu then
    sys.gpu.color(0x00FF00, 0x000000)
    sys.gpu.set(1, sys.gpu.res(), current_dir .. " # ")
    sys.gpu.color(0xFFFFFF, 0x000000)
  else
    print(current_dir .. " # ")
  end
  
  local input = readln()
  
  local parts = {}
  for w in string.gmatch(input, "%S+") do table.insert(parts, w) end
  
  if #parts > 0 then
    local cmd = parts[1]
    local arg1 = parts[2]
    
    if cmd == "exit" then
      exit()
      
    elseif cmd == "cd" then
      if not arg1 then
        current_dir = "/"
      else
        local new_path = resolvePath(arg1)
        if exists(new_path) == "dir" then
          current_dir = new_path
        else
          print("cd: path not found: " .. new_path)
        end
      end
      
    elseif cmd == "pwd" then
      print(current_dir)
      
    elseif cmd == "ls" then
      local target = current_dir
      if arg1 then target = resolvePath(arg1) end
      
      local l = ls(target)
      if l then
        local output = ""
        local count = 0
        -- ИСПРАВЛЕНО: pairs() обязательно для итерации по таблице от ядра
        for _, file in pairs(l) do
           output = output .. file .. "  "
           count = count + 1
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
      local run_path = nil
      local abs_test = resolvePath(cmd)
      local bin_test = resolvePath("/bin/" .. cmd)
      
      if exists(bin_test) == "file" then
        run_path = bin_test
      elseif exists(abs_test) == "file" then
        run_path = abs_test
      end
      
      if run_path then
        local args_to_pass = ""
        if #parts > 1 then
           if cmd == "nano" or cmd == "edit" then
             args_to_pass = resolvePath(arg1)
           else
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