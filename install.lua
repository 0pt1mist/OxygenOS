-- OxygenOS Installer

local component = require("component")
local computer = require("computer")

local function getComponent(name)
  local addr = component.list(name)()
  if not addr then error("❌ Required " .. name .. " missing!", 0) end
  return addr
end

local internetAddr = getComponent("internet")
local hddAddr = nil

for addr in component.list("filesystem") do
  local fs = component.proxy(addr)
  if fs.spaceTotal() and fs.spaceTotal() > 1024 * 1024 then
    hddAddr = addr
    break
  end
end

if not hddAddr then
  error("❌ No suitable HDD found (need >1 MB)!", 0)
end

local hdd = component.proxy(hddAddr)

if not hdd.getLabel() then
  error("❌ Disk not formatted! Format in BIOS (press F).", 0)
end

local function downloadFile(url, path)
  print("📥 " .. path)
  local handle, err = component.invoke(internetAddr, "request", url)
  if not handle then
    error("HTTP error: " .. tostring(err))
  end

  local fileHandle = hdd.open(path, "wb")
  if not fileHandle then
    error("Cannot create " .. path)
  end

  while true do
    local chunk, reason = handle.read(65536)  -- ✅ Без двоеточия!
    if chunk then
      hdd.write(fileHandle, chunk)
    else
      if reason then
        error("Download failed: " .. tostring(reason))
      end
      break
    end
  end

  hdd.close(fileHandle)
  handle.close()  -- тоже без двоеточия
  print("✅ Done")
end

hdd.setLabel("OXYGEN")

local dirs = {"/bin", "/etc", "/usr"}
for _, d in ipairs(dirs) do
  if not hdd.exists(d) then hdd.makeDirectory(d) end
end

local BASE = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/main"
downloadFile(BASE .. "/kernel/init.lua", "/init.lua")
downloadFile(BASE .. "/kernel/bin/shell", "/bin/shell")

print("🎉 OxygenOS installed!")
print("➡️ Reboot to start.")