-- kernel/init.lua
-- OxygenOS v0.1 — Minimal Boot

--if not pcall(require, "component") then
--  error("OxygenOS requires OpenComputers!")
--end

local component = require("component")
local fs = require("filesystem")
local shell = require("shell")

print("Mounting filesystems...")
for address in component.list("filesystem") do
  local label = fs.getDriveLabel(address) or "disk"
  local mountPoint = "/" .. label
  if not fs.exists(mountPoint) then
    fs.makeDirectory(mountPoint)
  end
  pcall(shell.execute, "umount " .. mountPoint)
  shell.execute("mount " .. address .. " " .. mountPoint)
end

local requiredDirs = {
  "/bin", "/sbin", "/etc", "/dev", "/tmp", "/home", "/var", "/usr"
}
for _, dir in ipairs(requiredDirs) do
  if not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
end

print("\27[36m🌬️  OxygenOS v0.1\27[0m")
print("Unix-like OS for OpenComputers 1.12.2")
print("")

dofile("/bin/shell")