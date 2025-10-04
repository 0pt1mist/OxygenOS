-- OxygenOS Installer v1.1
-- Fully compatible with OpenComputers 1.12.2 (Lua 5.3)
-- Works with BIOS only — no OpenOS required

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")

if not component.isAvailable("internet") then
  error("❌ Internet Card is required!", 0)
end

local hddAddress = nil
for addr in component.list("filesystem") do
  local fs = component.proxy(addr)
  local total = fs.spaceTotal()
  if total and total > 100 * 1024 then -- >100 KB
    hddAddress = addr
    break
  end
end

if not hddAddress then
  error("❌ No suitable HDD found (need >100 KB)!", 0)
end

print("🌬️  OxygenOS Installer")
print("Target HDD: " .. hddAddress)

local hdd = component.proxy(hddAddress)
local currentLabel = hdd.getLabel() or "disk"

print("Unmounting all filesystems...")
for path in filesystem.mounts() do
  print("  - " .. path)
  pcall(filesystem.umount, path)
end
computer.sleep(0.5)

print("Formatting disk...")
hdd.erase()
hdd.setLabel("OXYGEN")
computer.sleep(1)

print("Mounting as /OXYGEN...")
filesystem.mount(hddAddress, "/OXYGEN")

local function download(url, path)
  print("📥 Downloading: " .. path)
  local internet = component.internet
  local response, err = internet.request(url)
  if not response then
    error("Failed to fetch " .. url .. ": " .. tostring(err), 0)
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
  print("✅ Saved")
end

local GITHUB_USER = "0pt1mist"
local BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/OxygenOS/main"

download(BASE .. "/kernel/init.lua", "/OXYGEN/init.lua")

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

download(BASE .. "/kernel/bin/shell", "/OXYGEN/bin/shell")

print("")
print("🎉 OxygenOS installed successfully!")
print("➡️  Reboot to start your new OS.")