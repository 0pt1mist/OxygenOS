-- Oxygen Shell v2.3 (User Aware)
local args = {...}
local current_dir = "/"
local user = "unknown"
if sys and sys.getuser then user = sys.getuser() end

-- [Helpers]
local function resolvePath(path)
  if string.sub(path, 1, 1) ~= "/" then
    if current_dir == "/" then path = "/" .. path else path = current_dir .. "/" .. path end
  end
  local parts = {}
  for part in string.gmatch(path, "[^/]+") do
    if part == ".." then
      if #parts > 0 then table.remove(parts) end
    elseif part ~= "." and part ~= "" then table.insert(parts, part) end
  end
  return "/" .. table.concat(parts, "/")
end

local function exists(path)
  local list = ls(path)
  if list then return "dir" end
  local content = cat(path)
  if content then return "file" end
  return nil
end

-- [Main]
print("OxygenOS Shell v2.3")
print("Logged in as: " .. user)

while true do
  local prompt = user .. "@" .. current_dir .. " # "
  if sys and sys.gpu then
    sys.gpu.color(0x00FF00, 0x000000)
    sys.gpu.set(1, sys.gpu.res(), prompt)
    sys.gpu.color(0xFFFFFF, 0x000000)
  else
    print(prompt)
  end
  
  local input = readln()
  local parts = {}
  for w in string.gmatch(input, "%S+") do table.insert(parts, w) end
  
  if #parts > 0 then
    local cmd = parts[1]
    local arg1 = parts[2]
    
    if cmd == "exit" then
      exit() -- Выход в Login
    elseif cmd == "cd" then
      if not arg1 then current_dir = "/" else
        local new = resolvePath(arg1)
        if exists(new) == "dir" then current_dir = new else print("cd: invalid dir") end
      end
    elseif cmd == "pwd" then
      print(current_dir)
    elseif cmd == "ls" then
      local t = current_dir
      if arg1 then t = resolvePath(arg1) end
      local l = ls(t)
      if l then
        local o, c = "", 0
        for _, f in pairs(l) do
           o = o .. f .. "  "; c = c + 1
           if c % 4 == 0 then o = o .. "\n" end
        end
        print(o)
      else print("ls: error") end
    elseif cmd == "cat" then
      if not arg1 then print("Usage: cat <file>") else
        local d = cat(resolvePath(arg1))
        if d then print(d) else print("File not found") end
      end
    elseif cmd == "help" then
      print("Builtins: cd, ls, pwd, cat, exit")
      print("Programs: emerge, nano, login")
    else
      local run, abs, bin = nil, resolvePath(cmd), resolvePath("/bin/"..cmd)
      if exists(bin) == "file" then run = bin elseif exists(abs) == "file" then run = abs end
      if run then
        local p = ""
        if #parts > 1 then 
           if cmd=="nano" then p=resolvePath(arg1) else p=table.concat(parts," ",2) end 
        end
        spawn(run, p)
      else print("Unknown: "..cmd) end
    end
  end
end