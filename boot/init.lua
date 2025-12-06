local addr = computer.getBootAddress()
local invoke = component.invoke

local function raw_status(text)
  local gpu = component.list("gpu")()
  local screen = component.list("screen")()
  if gpu and screen then
    invoke(gpu, "bind", screen)
    invoke(gpu, "set", 1, 1, tostring(text) .. "                ")
  end
end

local function read_file(path)
  local handle = invoke(addr, "open", path)
  if not handle then error("Bootloader: Kernel not found at " .. path) end
  local buffer = ""
  repeat
    local data = invoke(addr, "read", handle, math.huge)
    buffer = buffer .. (data or "")
  until not data
  invoke(addr, "close", handle)
  return buffer
end

raw_status("Oxygen: Booting...")

-- Загрузка и запуск ядра
local kernel_code = read_file("/boot/kernel.lua")
local kernel, err = load(kernel_code, "=kernel", "t", _G)
if not kernel then error("Kernel Panic: " .. tostring(err)) end
kernel()