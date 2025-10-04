-- install.lua
local component = require("component")
local fs = require("filesystem")
local shell = require("shell")

if not component.isAvailable("internet") then
  print("❌ Internet Card required!")
  return
end

print("🌬️  OxygenOS Installer")
print("Looking for HDD...")

local hdd = nil
for addr, name in component.list("filesystem") do
  if name == "filesystem" then hdd = addr; break end
end

if not hdd then
  print("❌ No HDD found!")
  return
end

local label = fs.getLabel(hdd)
if label then shell.execute("umount /" .. label) end
component.invoke(hdd, "erase")
component.invoke(hdd, "setLabel", "OXYGEN")
os.sleep(1)
shell.execute("mount " .. hdd .. " /OXYGEN")

local url = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/main/kernel/init.lua"
if not shell.execute("wget " .. url .. " /OXYGEN/init.lua") then
  print("⚠️ Failed to download init.lua")
  return
end

fs.makeDirectory("/OXYGEN/bin")

local shellUrl = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/main/kernel/bin/shell"
shell.execute("wget " .. shellUrl .. " /OXYGEN/bin/shell")

print("✅ Installation complete!")
print("🔄 Reboot to start OxygenOS.")