-- Filename: reactor
-- Author: Synergiance
-- Version: 1.0.0

local url = "https://raw.githubusercontent.com/synergiance/minecraft-scripts/main/reactor.lua"
local response = http.get(url)
if response then
  local r = response.readAll()
  response.close()
  local file = fs.open("reactor", "w")
  file.write(r)
  file.close()
  print("Success")
else
  print("Failure")
end