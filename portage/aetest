local driver = sys.include("driver")

print("Searching for ME Interface...")
local me = driver.find("me_interface")

if me then
  print("Found ME Interface!")
  local items = me.getItemsInNetwork()
  
  print("Network contents:")
  for i, item in ipairs(items) do
     if i <= 5 then
       print("- " .. item.label .. " (x" .. math.floor(item.size) .. ")")
     end
  end
else
  print("ME Interface not found in /dev")
  print("Devices found:")
  local all = sys.ls("/dev")
  for _, d in pairs(all) do print(d) end
end