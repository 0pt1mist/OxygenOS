-- kernel/init.lua для EEPROM
local function debugPrint(message)
  if component and computer then
    local gpu = component.gpu
    if gpu then
      for screenAddr in component.list("screen") do
        if gpu.getScreen() ~= screenAddr then
          gpu.bind(screenAddr)
        end
        break
      end
      gpu.set(1, 1, tostring(message))
      return
    end
    computer.beep(500, 0.1)
  end
end

local function findAndLoadShell()
  for fsAddr in component.list("filesystem") do
    local fs = component.proxy(fsAddr)
    
    if fs.exists("/bin/shell") then
      local handle = fs.open("/bin/shell", "r")
      if not handle then return nil end
      
      local content = ""
      while true do
        local chunk = fs.read(handle, 1024)
        if not chunk then break end
        content = content .. chunk
      end
      fs.close(handle)
      
      if content ~= "" then
        -- Передаем компоненты как окружение для shell
        return load(content, "=shell", "t", {
          component = component,
          computer = computer,
          print = debugPrint
        })
      end
    end
  end
  return nil
end

debugPrint("OxygenOS Booting...")
computer.pullSignal(0.5)

local shell = findAndLoadShell()
if shell then
  local success, err = pcall(shell)
  if not success then
    debugPrint("Shell crash: " .. tostring(err))
  end
else
  debugPrint("Shell not found")
end

computer.shutdown(true)