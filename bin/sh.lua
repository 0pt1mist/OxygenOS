print("Oxygen Shell v1.0")
print("Type 'help' for commands.")

while true do
  local input = readln() -- Системный вызов
  
  if input == "exit" then
    exit()
  elseif input == "help" then
    print("Commands: ls, cat <file>, help, exit")
  elseif input == "ls" then
    local files = ls("/") -- Системный вызов ls
    local out = ""
    if files then
      for _, file in ipairs(files) do
        out = out .. file .. "  "
      end
      print(out)
    else
      print("Error listing directory")
    end
  elseif string.sub(input, 1, 3) == "cat" then
    local filename = string.sub(input, 5)
    local content = cat(filename) -- Системный вызов cat
    if content then
      print(content)
    else
      print("File not found")
    end
  else
    print("Unknown command: " .. input)
  end
end