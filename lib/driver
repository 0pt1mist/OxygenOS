-- Driver API for OxygenOS
-- Использование: local driver = sys.include("driver")
local driver = {}

-- Поиск первого компонента по типу (как component.list + proxy)
function driver.find(type_name)
  local list = sys.ls("/dev")
  for _, dev in pairs(list) do
    -- dev выглядит как "me_interface-a1b..."
    -- Проверяем, начинается ли строка с type_name
    if string.sub(dev, 1, #type_name) == type_name then
       -- Извлекаем UUID из названия (или просто берем dev, т.к. sys.device понимает начало UUID)
       -- Наш ls возвращает "type-uuid_start", нам нужно передать uuid_start в sys.device
       local dash_pos = string.find(dev, "-")
       if dash_pos then
          local uuid_part = string.sub(dev, dash_pos + 1)
          return sys.device(uuid_part)
       end
    end
  end
  return nil
end

-- Получить все компоненты данного типа
function driver.findAll(type_name)
  local results = {}
  local list = sys.ls("/dev")
  for _, dev in pairs(list) do
    if string.sub(dev, 1, #type_name) == type_name then
       local dash_pos = string.find(dev, "-")
       if dash_pos then
          local uuid_part = string.sub(dev, dash_pos + 1)
          table.insert(results, sys.device(uuid_part))
       end
    end
  end
  return results
end

return driver