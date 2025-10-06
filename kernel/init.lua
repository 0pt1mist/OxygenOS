-- kernel/init.lua
if not component or not computer then
  return
end

local function debugPrint(message)
  for addr in component.list("screen") do
    local screen = component.proxy(addr)
    local gpuAddr = screen.getGPU()
    if gpuAddr then
      local gpu = component.proxy(gpuAddr)
      gpu.set(1, 1, tostring(message))
      return
    end
  end
  computer.beep(500, 0.1)
end

debugPrint("OxygenOS Booting...")

local function findAndLoadShell()
  for fsAddr in component.list("filesystem") do
    local fs = component.proxy(fsAddr)
    
    local shellPaths = {
      "/bin/shell",
      "bin/shell", 
      "/shell",
      "shell"
    }
    
    for _, path in ipairs(shellPaths) do
      if fs.exists(path) and not fs.isDirectory(path) then
        local handle = fs.open(path, "r")
        if not handle then return nil end
        
        local content = ""
        while true do
          local chunk = fs.read(handle, 1024)
          if not chunk then break end
          content = content .. chunk
        end
        fs.close(handle)
        
        if content ~= "" then
          return load(content, "=shell")
        end
      end
    end
  end
  return nil
end

local shell = findAndLoadShell()
if shell then
  pcall(shell)
else
  debugPrint("Shell not found")
end

computer.shutdown(true)