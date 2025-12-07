-- OxygenOS Installer v1.1
local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/OxygenOS/test/"

local file_list = {
  { path = "/init.lua",        remote = "boot/init.lua" },
  { path = "/boot/kernel.lua", remote = "boot/kernel.lua" },
  { path = "/bin/sh.lua",      remote = "bin/sh.lua" },
  { path = "/bin/emerge",      remote = "bin/emerge" },
  { path = "/bin/nano",        remote = "bin/nano" }
}

term.clear()
print("OxygenOS Web Installer")
print("Source: " .. REPO_URL)

-- 1. Выбор диска
local filesystems = {}
local i = 1
for address, type in component.list("filesystem") do
  local proxy = component.proxy(address)
  if proxy then
    -- Исключаем текущий загрузочный диск (OpenOS), ищем только RW диски
    local current_boot = fs.get(os.getenv("SHELL")).address
    if not proxy.isReadOnly() and address ~= current_boot then
      filesystems[i] = proxy
      print(i .. ": " .. address .. " (Target)")
      i = i + 1
    end
  end
end

if #filesystems == 0 then
  print("Error: No suitable target disk found.")
  print("Please insert a blank Tier 2/3 HDD.")
  return
end

io.write("Select target drive [1-" .. (#filesystems) .. "]: ")
local choice = tonumber(io.read())
local disk = filesystems[choice]

if not disk then 
  print("Invalid selection.") 
  return 
end

print("Installing to " .. disk.address .. "...")

print("Creating directories...")
local dirs = {
  "/boot", 
  "/bin", 
  "/dev",
  "/etc", 
  "/etc/oxygen",
  "/home", 
  "/lib", 
  "/usr", 
  "/var",
  "/tmp"
}

for _, d in ipairs(dirs) do
  if not disk.exists(d) then 
    disk.makeDirectory(d) 
  end
end

for _, file in ipairs(file_list) do
  local url = REPO_URL .. file.remote
  print("Downloading " .. file.remote .. " ...")
  
  local handle, err = internet.request(url)
  
  if handle then
    local content = ""
    for chunk in handle do 
      content = content .. chunk 
    end
    
    if #content < 10 and string.find(content, "404") then
      print("ERROR: File not found on GitHub (404): " .. file.remote)
    else
      local f = disk.open(file.path, "w")
      disk.write(f, content)
      disk.close(f)
      print("OK -> " .. file.path)
    end
  else
    print("ERROR: Connection failed: " .. tostring(err))
  end
end

print("---------------------------------------------------")
print("Installation Complete.")
print("1. Remove OpenOS Boot Disk.")
print("2. Reboot the computer.")