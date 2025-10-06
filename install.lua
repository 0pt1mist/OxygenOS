-- OxygenOS Network Installer
local component = require("component")
local computer = require("computer")

local REPO_BASE = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/test"
local FILES = {
  "/kernel/init.lua",
  "/kernel/bin/shell"
}

print("OxygenOS Installer")

if not component.isAvailable("internet") then
  print("Internet card required")
  return
end

local internet = component.internet

local function downloadFile(url, path, fs)
  print("Downloading: " .. path)
  
  local handle = internet.request(url)
  if not handle then
    error("HTTP error")
  end

  local dir = path:match("(.*)/")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end

  local fileHandle = fs.open(path, "w")
  if not fileHandle then
    error("Cannot create: " .. path)
  end

  local content = ""
  while true do
    local chunk = handle.read(1024)
    if not chunk then break end
    content = content .. chunk
  end

  fs.write(fileHandle, content)
  fs.close(fileHandle)
  handle.close()
end

local function getAvailableDisks()
  local disks = {}
  
  for addr in component.list("filesystem") do
    local fs = component.proxy(addr)
    if not fs.isReadOnly() and fs.spaceTotal() > 100000 then
      local total = fs.spaceTotal()
      local used = fs.spaceUsed()
      local free = total - used
      
      table.insert(disks, {
        address = addr,
        fs = fs,
        label = fs.getLabel() or "No Label",
        size = math.floor(total / 1024),
        free = math.floor(free / 1024)
      })
    end
  end
  
  return disks
end

local function selectDisk(disks)
  if #disks == 0 then
    print("No suitable disks")
    return nil
  end
  
  print("Available disks:")
  for i, disk in ipairs(disks) do
    print(i .. ". " .. disk.address:sub(1, 8) .. " - " .. disk.label .. " (" .. disk.free .. "KB free)")
  end
  
  if #disks == 1 then
    return disks[1]
  end
  
  while true do
    io.write("Select disk (1-" .. #disks .. "): ")
    local input = io.read()
    local choice = tonumber(input)
    
    if choice and choice >= 1 and choice <= #disks then
      return disks[choice]
    end
  end
end

local function createDirectoryStructure(fs)
  local dirs = {"/bin", "/etc", "/home", "/tmp", "/var", "/usr"}
  for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
      fs.makeDirectory(dir)
    end
  end
end

-- Main
local disks = getAvailableDisks()
local selectedDisk = selectDisk(disks)
if not selectedDisk then return end

io.write("Install to " .. selectedDisk.address .. "? (y/N): ")
local input = io.read():lower()
if input ~= "y" and input ~= "yes" then
  print("Cancelled")
  return
end

print("Installing...")
createDirectoryStructure(selectedDisk.fs)

for _, file in ipairs(FILES) do
  local ok, err = pcall(downloadFile, REPO_BASE .. file, file, selectedDisk.fs)
  if not ok then
    print("Failed: " .. file .. " - " .. tostring(err))
    return
  end
end

selectedDisk.fs.setLabel("OXYGEN")
print("Installation complete")
print("Set as boot device and reboot")