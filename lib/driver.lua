-- /lib/driver.lua
local driver = {}

function driver.find(type_name)
  print("[DEBUG] Searching for: " .. type_name)
  local list = sys.ls("/dev")
  
  for _, dev in pairs(list) do
    -- Проверяем совпадение начала строки
    if string.sub(dev, 1, #type_name) == type_name then
       print("[DEBUG] Match found: " .. dev)
       
       -- Ищем тире
       local dash_pos = string.find(dev, "-")
       if dash_pos then
          local uuid_part = string.sub(dev, dash_pos + 1)
          print("[DEBUG] Extracted ID: " .. uuid_part)
          
          -- Пытаемся получить прокси
          local proxy, err = sys.device(uuid_part)
          if proxy then
             print("[DEBUG] Proxy obtained successfully!")
             return proxy
          else
             print("[DEBUG] Failed to get proxy: " .. tostring(err))
          end
       end
    end
  end
  print("[DEBUG] " .. type_name .. " not found.")
  return nil
end

return driver