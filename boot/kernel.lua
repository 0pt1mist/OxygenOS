-- OxygenOS Kernel v0.7.0 (Security & Multi-user)

-- [1] HARDWARE SEIZE
local hw = {
  component = component,
  computer = computer,
  unicode = unicode,
  os_native = os -- Сохраняем нативные функции OS перед удалением
}
local boot_addr = hw.computer.getBootAddress()

-- [2] GLOBAL PURGE
_G.component = nil
_G.computer = nil
_G.io = nil
_G.os = nil
_G.print = nil

-- [3] KERNEL STATE
local Oxygen = {
  gpu = nil,
  inet = nil,
  w = 80, h = 25,
  input_row = 25,
  
  -- Security Context
  current_uid = 0,     -- 0 = root
  current_user = "root",
  
  -- Защищенные пути (только root может писать сюда)
  protected_paths = {
    ["/boot"] = true,
    ["/bin"] = true,
    ["/etc"] = true,
    ["/lib"] = true
  }
}

-- Hardware Init
local gpu_addr = hw.component.list("gpu")()
local screen_addr = hw.component.list("screen")()
if gpu_addr and screen_addr then
  Oxygen.gpu = hw.component.proxy(gpu_addr)
  Oxygen.gpu.bind(screen_addr)
  Oxygen.w, Oxygen.h = Oxygen.gpu.getResolution()
  Oxygen.input_row = Oxygen.h
  Oxygen.gpu.setBackground(0x000000)
  Oxygen.gpu.setForeground(0xFFFFFF)
  Oxygen.gpu.fill(1, 1, Oxygen.w, Oxygen.h, " ")
end

local inet_addr = hw.component.list("internet")()
if inet_addr then Oxygen.inet = hw.component.proxy(inet_addr) end

-- [4] HELPER FUNCTIONS
function Oxygen.printLine(line)
  if not Oxygen.gpu then return end
  Oxygen.gpu.copy(1, 2, Oxygen.w, Oxygen.input_row - 2, 0, -1)
  Oxygen.gpu.fill(1, Oxygen.input_row - 1, Oxygen.w, 1, " ")
  Oxygen.gpu.set(1, Oxygen.input_row - 1, tostring(line))
end

function Oxygen.ttyPrint(text)
  text = tostring(text)
  local line = ""
  for i = 1, #text do
    local char = string.sub(text, i, i)
    if char == "\n" then
      Oxygen.printLine(line); line = ""
    else
      line = line .. char
      if hw.unicode.len(line) >= Oxygen.w then Oxygen.printLine(line); line = "" end
    end
  end
  if #line > 0 then Oxygen.printLine(line) end
end

-- [5] SECURITY CHECKS
function Oxygen.canWrite(path)
  if Oxygen.current_uid == 0 then return true end -- Root разрешено всё
  
  -- Проверка защищенных путей
  for prot, _ in pairs(Oxygen.protected_paths) do
    if string.sub(path, 1, #prot) == prot then
      return false
    end
  end
  return true
end

function Oxygen.canNet()
  -- Пока разрешаем всем, в будущем можно ограничить
  return true 
end

-- [6] SYSTEM CALLS
local Syscalls = {}

Syscalls.readFile = function(path)
  local handle = hw.component.invoke(boot_addr, "open", path)
  if not handle then return nil, "File not found" end
  local buffer = ""
  repeat
    local data = hw.component.invoke(boot_addr, "read", handle, math.huge)
    buffer = buffer .. (data or "")
  until not data
  hw.component.invoke(boot_addr, "close", handle)
  return buffer
end

Syscalls.writeFile = function(path, data)
  if not Oxygen.canWrite(path) then return false, "Permission Denied" end

  local handle = hw.component.invoke(boot_addr, "open", path, "w")
  if not handle then return false, "Write error" end
  hw.component.invoke(boot_addr, "write", handle, data)
  hw.component.invoke(boot_addr, "close", handle)
  return true
end

Syscalls.mkDir = function(path) 
  if not Oxygen.canWrite(path) then return false, "Permission Denied" end
  return hw.component.invoke(boot_addr, "makeDirectory", path) 
end

Syscalls.list = function(path) return hw.component.invoke(boot_addr, "list", path) end

Syscalls.fetch = function(url)
  if not Oxygen.canNet() then return nil, "Permission Denied" end
  if not Oxygen.inet then return nil, "No Net" end
  Oxygen.ttyPrint("[NET] GET " .. url)
  local h, e = Oxygen.inet.request(url)
  if not h then return nil, e end
  local b = ""
  while true do
    local d = h.read()
    if not d then break end
    b = b .. d
    hw.computer.pullSignal(0.0)
  end
  h.close()
  return b
end

-- User Management Syscalls
Syscalls.getuid = function() return Oxygen.current_uid end
Syscalls.getuser = function() return Oxygen.current_user end
Syscalls.setuid = function(uid, user)
  if Oxygen.current_uid ~= 0 then return false, "EPERM: Root required" end
  Oxygen.current_uid = uid
  Oxygen.current_user = user
  return true
end

-- Input/Output
Syscalls.gpu_set = function(x, y, txt) if Oxygen.gpu then Oxygen.gpu.set(x, y, txt) end end
Syscalls.gpu_fill = function(x,y,w,h,c) if Oxygen.gpu then Oxygen.gpu.fill(x,y,w,h,c) end end
Syscalls.gpu_copy = function(x,y,w,h,tx,ty) if Oxygen.gpu then Oxygen.gpu.copy(x,y,w,h,tx,ty) end end
Syscalls.gpu_res = function() return Oxygen.w, Oxygen.h end
Syscalls.gpu_color = function(f, b) if Oxygen.gpu then if f then Oxygen.gpu.setForeground(f) end if b then Oxygen.gpu.setBackground(b) end end end
Syscalls.pull = function(t) return hw.computer.pullSignal(t) end

Syscalls.readln = function(mask_char)
  local buffer = ""
  local function redraw()
    if not Oxygen.gpu then return end
    Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
    local show = buffer
    if mask_char then show = string.rep(mask_char, #buffer) end
    Oxygen.gpu.set(1, Oxygen.input_row, "> " .. show .. "_")
  end
  redraw()
  while true do
    local s = {hw.computer.pullSignal()}
    if s[1] == "key_down" then
      local char = s[3]
      if char == 13 then
        Oxygen.gpu.fill(1, Oxygen.input_row, Oxygen.w, 1, " ")
        if not mask_char then Oxygen.printLine("> " .. buffer) end
        return buffer
      elseif char == 8 then
        if #buffer > 0 then buffer = hw.unicode.sub(buffer, 1, -2) end
        redraw()
      elseif char >= 32 then
        buffer = buffer .. hw.unicode.char(char)
        redraw()
      end
    end
  end
end

Syscalls.exit = function() hw.computer.shutdown() end

-- [7] EXEC
function Oxygen.exec(path, ...)
  local args = {...}
  local code, err = Syscalls.readFile(path)
  if not code then Oxygen.ttyPrint("Exec Error: "..tostring(err)) return end

  local sandbox = {
    pairs=pairs, ipairs=ipairs, tostring=tostring, tonumber=tonumber,
    table=table, string=string, math=math, type=type, load=load, next=next,
    error=error, pcall=pcall, select=select,
    unicode = hw.unicode,
    -- Restored OS (Safe Subset)
    os = { time = hw.os_native.time, date = hw.os_native.date, clock = hw.os_native.clock, difftime = hw.os_native.difftime },
    
    print = Oxygen.ttyPrint,
    readln = Syscalls.readln,
    spawn = Oxygen.exec,
    exit = Syscalls.exit,
    
    sys = {
      read = Syscalls.readFile, write = Syscalls.writeFile,
      ls = Syscalls.list, mkdir = Syscalls.mkDir,
      fetch = Syscalls.fetch,
      getuid = Syscalls.getuid, getuser = Syscalls.getuser, setuid = Syscalls.setuid,
      gpu = { set = Syscalls.gpu_set, fill = Syscalls.gpu_fill, copy = Syscalls.gpu_copy, res = Syscalls.gpu_res, color = Syscalls.gpu_color },
      pull = Syscalls.pull
    },
    -- Aliases
    cat = Syscalls.readFile, ls = Syscalls.list, fetch = Syscalls.fetch
  }
  
  local proc, e = load(code, "="..path, "t", sandbox)
  if not proc then Oxygen.ttyPrint("Syn: "..tostring(e)) return end
  pcall(proc, table.unpack(args))
end

-- [8] BOOT
Oxygen.ttyPrint("OxygenOS Kernel v0.7.0 (Secure)")
Oxygen.ttyPrint("Launching Login Manager...")

while true do
  Oxygen.current_uid = 0
  Oxygen.current_user = "root"
  
  Oxygen.exec("/bin/login")
  
  Oxygen.ttyPrint("Logout. Restarting...")
  hw.computer.pullSignal(1)
end