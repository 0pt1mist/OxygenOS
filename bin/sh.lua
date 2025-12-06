print("Oxygen Shell v1.2")
print("Type 'help' for commands.")

while true do
  local input = readln()
  
  -- Разделение строки на команду и аргументы
  local parts = {}
  for w in string.gmatch(input, "%S+") do table.insert(parts, w) end
  
  if #parts > 0 then
    local cmd = parts[1]
    local args = {}
    -- Все последующие части - аргументы
    for i = 2, #parts do table.insert(args, parts[i]) end
    
    if cmd == "exit" then
      exit()
    elseif cmd == "help" then
      print("Built-ins: ls, help, exit, reboot")
      print("Programs: emerge <cmd>, or any file in /bin")
    elseif cmd == "ls" then
      local path = args[1] or "/"
      local l = ls(path)
      if l then
        local s = ""
        for k,v in pairs(l) do s = s .. v .. "  " end
        print(s)
      else
        print("Error: Path not found")
      end
    elseif cmd == "reboot" then
      exit() -- В текущей реализации exit выключает ПК, но можно сделать перезагрузку
    else
      -- Попытка запуска внешней программы
      local bin_path = "/bin/" .. cmd
      -- Мы пробуем запустить. Если файла нет, exec вернет ошибку внутри ядра
      -- Но чтобы было красивее, проверим через cat (хотя это не эффективно, но пока сойдет)
      local exists = cat(bin_path)
      if not exists then
        -- Пробуем без /bin/ (абсолютный путь)
        bin_path = cmd
        exists = cat(bin_path)
      end
      
      if exists then
        -- ВАЖНО: передаем args распакованными или таблицей?
        -- Kernel exec делает table.unpack, значит мы можем передать каждый аргумент отдельно
        -- Но проще передать строку или таблицу. 
        -- Emerge ожидает строку или части. Передадим строку целиком для совместимости
        local arg_str = table.concat(args, " ")
        spawn(bin_path, arg_str)
      else
        print("Unknown command: " .. cmd)
      end
    end
  end
end