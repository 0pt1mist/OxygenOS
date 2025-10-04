-- OxygenOS Installer v0.3
-- Works with OpenComputers BIOS (no OpenOS required)

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")

if not component.isAvailable("internet") then
  error("❌ Internet Card is required to install OxygenOS!", 0)
end

if not component.isAvailable("filesystem") then
  error("❌ No disk drive or HDD found!", 0)
end

print("🌬️  OxygenOS Installer")
print("Scanning for install target...")

local hddAddress = nil
for address in component.list("filesystem") do
  local proxy = component.proxy(address)
  local totalSpace = proxy.spaceTotal()
  if totalSpace and totalSpace > 100 * 1024 then
    hddAddress = address
    break
  end
end

if not hddAddress then
  error("❌ No suitable HDD found (need >100 KB)!", 0)
end

local hdd = component.proxy(hddAddress)
local currentLabel = hdd.getLabel() or "disk"
print("Target disk: " .. currentLabel .. " (" .. hddAddress .. ")")

local mountPoint = "/" .. currentLabel
if filesystem.exists(mountPoint) then
  print("Unmounting existing filesystem...")
  pcall(filesystem.umount, mountPoint)
  computer.sleep(0.5)
end

print("Formatting disk...")
local hdd = component.proxy(hddAddress)
hdd.erase()
hdd.setLabel("OXYGEN")
computer.sleep(1)

print("Mounting as /OXYGEN...")
filesystem.mount(hddAddress, "/OXYGEN")

local function downloadFile(url, path)
  print("📥 Downloading: " .. path)
  local internet = component.internet

  local response, err = internet.request(url)
  if not response then
    error("Failed to connect to " .. url .. ": " .. tostring(err), 0)
  end

  local content = ""
  local chunk = response:read(math.huge)
  while chunk do
    content = content .. chunk
    chunk = response:read(math.huge)
  end

  local file = io.open(path, "wb")
  if not file then
    error("Cannot write to " .. path, 0)
  end
  file:write(content)
  file:close()

  print("✅ Saved to " .. path)
  return true
end

local GITHUB_USER = "0pt1mist"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/OxygenOS/main"

downloadFile(BASE_URL .. "/kernel/init.lua", "/OXYGEN/init.lua")

local dirs = {
  "/OXYGEN/bin",
  "/OXYGEN/sbin",
  "/OXYGEN/etc",
  "/OXYGEN/dev",
  "/OXYGEN/tmp",
  "/OXYGEN/home",
  "/OXYGEN/var",
  "/OXYGEN/usr"
}
for _, dir in ipairs(dirs) do
  if not filesystem.exists(dir) then
    filesystem.makeDirectory(dir)
  end
end

downloadFile(BASE_URL .. "/kernel/bin/shell", "/OXYGEN/bin/shell")

print("")
print("🎉 OxygenOS installation complete!")
print("💡 Next steps:")
print("  1. Remove the floppy disk (if any)")
print("  2. Reboot the computer")
print("  3. Enjoy your new OS!")