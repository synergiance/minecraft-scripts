-- Filename: reactor
-- Author: Synergiance
-- Version: 0.2.3
-- You MAY use this code in your own minecraft world
-- You MAY change the code to suit your needs
-- You MAY submit bug reports to me
-- You MUST keep my name in this file
-- You MAY redistribute the original script to your friends
-- You MAY NOT distribute modified versions of this script, it would be too hard to keep track of other peoples changes, please see next point
-- You MAY submit bug fixes to me so that I can include them in the next version
-- You MAY NOT claim this work as your own

-- Complete: Multiple monitors
-- Complete: Multiple reactors and turbines
-- Complete: Reactor mode and turbine mode
-- Complete: Dynamic peripheral detection
-- Complete: Monitor preservation
-- Complete: Safely turn off reactors and turbines on terminate
-- In Progress: Reactor and turbine tuning (algorithm doesn't seem to work very well at lower ranges of power output, doesn't check for the magical 2,000 mbps)
-- In Progress: User interface
-- In Progress: Multiple screen sizes
-- To Do: Large screen tiled mode
-- To Do: Small screen swap mode
-- To Do: Manual mode
-- To Do: Passive mode
-- To Do: Settings preservation
-- To Do: Reactor and turbine groups
-- To Do: Turning off reactor without terminating the program

-- INSTRUCTIONS

-- Hook up your reactors and turbines the way you normally would
-- Add computer interfaces to each
-- Set the turbines to never vent to create a closed loop system
-- DO NOT FILL LOOP COMPLETELY (algorithm uses tank capacity for calculations, will not function when filled to the brim)
-- Copy reactor script to computer, make it load on startup

local m, r, t = {}, {}, {}
local keepRunning = true
local firstRun = true
local timerCode
local monFileName = "monsettings" -- File to store monitor view state in
local prefsFileName = "reactorprefs" -- File to save preferences in
local calibrationFileName = "calibrationdata" -- Calibration data cache

-- Reactor Variables
local numReactors = 0
local rSettings = {}
local rActive = {}
local rConnected = {}
local rStoredEnergy = {}
local rMaxEnergy = {}
local rEnergyRate = {}
local rFuelTemp = {}
local rCaseTemp = {}
local rRodNum = {}
local rRodLevel = {}

-- Steam Reactor Variables
local numSteamReactors = 0
local rColdLiquid = {}
local rColdLiquidMax = {}
local rHotLiquid = {}
local rHotLiquidMax = {}

local tInput = {}
local tOutput = {}
local tCapacity = {}
local tSpeedingUp = {}

-- Turbine Variables
local numTurbines = 0
local tSettings = {}
local tActive = {}
local tConnected = {}
local tStoredEnergy = {}
local tMaxEnergy = {}
local tEnergyRate = {}
local tFlowRate = {}
local tFlowRateCap = {}
local tFlowRateMax = {}
local tHotLiquid = {}
local tColdLiquid = {}
local tInductorEngaged = {}
local tRotorSpeed = {}
local tRotorEfficiency = {}

-- Calculated Variables
local batPercent = {}
local batString = {}
local energyString = {}

local hotPercent = {}
local coldPercent = {}
local inputPercent = {}
local outputPercent = {}
local coolantString = {}
local flowString = {}

-- Monitor variables
local mSettings = {}
local mTopScrollPos = {}
local mBottomScrollPos = {}
local steamReactor = {}
local mButtonLocations = {}

-- Runtime variables
local rMode = {} -- Current reactor mode, eg. idle, active, measuring
local rMeasurePoint = {} -- Point at which a reactor measurement started
local tMode = {} -- Current turbine mode, eg. spinning up, engaged
local tMeasurePoint = {} -- Point at which a turbine measurement started

-- Calibration variables
local calibrationData = {} -- Calibration data

-- Static Values
local mWidgetMinWidth = 21
local mWidgetMinHeight = 14
local tDefaultLowSpeed = 1780.0
local tDefaultHighSpeed = 1820.0
local tDefaultNormalSpeed = 1800.0
local rDefaultManagedMode = true
local rDefaultTempTarget = 1700.0
local rSafetyTemp = 1000.0
local rSafetyMargin = 800.0
local bDefaultMax = 90
local bDefaultMin = 10

function saveMonTable()
  local file = fs.open(monFileName,"w")
  file.write(textutils.serialize(mSettings))
  file.close()
end

function loadMonTable()
  if fs.exists(monFileName) then
    local file = fs.open(monFileName,"r")
    local data = file.readAll()
    file.close()
    mSettings = textutils.unserialize(data)
  end
end

function saveCalibrationData()
  local file = fs.open(calibrationFileName, "w")
  file.write(textutils.serialize(calibrationData))
  file.close()
end

function loadCalibrationData()
  if fs.exists(calibrationFileName) then
    local file = fs.open(calibrationFileName, "r")
    local data = file.readAll()
    file.close()
    calibrationData = textutils.unserialize(data)
  end
end

function scanPeripherals()
  -- print("Searching for peripherals...")
  peripheralList = peripheral.getNames()
  -- m, r, t = nil, nil, nil
  mb, rb, tb = {}, {}, {}
  if term.isColor() then
    term.setTextColor(colors.lime)
  end
  for i = 1, #peripheralList do
    if (peripheral.getType(peripheralList[i]) == "monitor") then
      table.insert(mb, peripheralList[i])
    end
    if (peripheral.getType(peripheralList[i]) == "BigReactors-Reactor") then
      table.insert(rb, peripheralList[i])
    end
    if (peripheral.getType(peripheralList[i]) == "BiggerReactors_Reactor") then
      table.insert(rb, peripheralList[i])
    end
    if (peripheral.getType(peripheralList[i]) == "BigReactors-Turbine") then
      table.insert(tb, peripheralList[i])
    end
    if (peripheral.getType(peripheralList[i]) == "BiggerReactors_Turbine") then
      table.insert(tb, peripheralList[i])
    end
  end
  for _,vb in pairs(mb) do
    found = false
    for _,v in pairs(m) do
      if v == vb then found = true end
    end
    if (not found) then
      print("Monitor connected: "..vb)
      table.insert(m,vb)
    end
  end
  for _,vb in pairs(rb) do
    found = false
    for _,v in pairs(r) do
      if v == vb then found = true end
    end
    if (not found) then
      print("Reactor connected: "..vb)
      table.insert(r,vb)
    end
  end
  for _,vb in pairs(tb) do
    found = false
    for _,v in pairs(t) do
      if v == vb then found = true end
    end
    if (not found) then
      print("Turbine connected: "..vb)
      table.insert(t,vb)
    end
  end
  if term.isColor() then
    term.setTextColor(colors.red)
  end
  contains = false
  repeat
  redo = false
    for k,v in pairs(m) do
      found = false
      contains = true
      for _,vb in pairs(mb) do
        if vb == v then found = true end
      end
      if (not found) then
        print("Monitor disconnected: "..v)
        table.remove(m,k)
        redo = true
        break
      end
    end
  until (not redo)
  if (not contains) and (firstRun) then print("No monitor found") end
  contains = false
  repeat
  redo = false
    for k,v in pairs(r) do
      found = false
      contains = true
      for _,vb in pairs(rb) do
        if vb == v then found = true end
      end
      if (not found) then
        print("Reactor disconnected: "..v)
        table.remove(r,k)
        redo = true
        break
      end
    end
  until (not redo)
  if (not contains) and (firstRun) then print("No reactor found") end
  contains = false
  repeat
  redo = false
    for k,v in pairs(t) do
      found = false
      contains = true
      for _,vb in pairs(tb) do
        if vb == v then found = true end
      end
      if (not found) then
        print("Turbine disconnected: "..v)
        table.remove(t,k)
        redo = true
        break
      end
    end
  until (not redo)
  if (not contains) and (firstRun) then print("No turbine found") end
  if term.isColor() then
    term.setTextColor(colors.white)
  end
  firstRun = false
end

function setTurbine(status)
  for _,v in pairs(t) do
    local turbine = peripheral.wrap(v)
    if not (turbine == nil) then
      if (status == true) or (status == false) then
        turbine.setActive(status)
      end
    end
  end
end

function setReactor(status)
  for _,v in pairs(r) do
    local reactor = peripheral.wrap(v)
    if not (reactor == nil) then
      if (status == true) or (status == false) then
        reactor.setActive(status)
      end
    end
  end
end

-- General Use Functions

---lerp
---performs a linear interpolation between a and b according to t
---@param a number
---@param b number
---@param t number
---@return number
function lerp(a,b,t)
  return (1.0-t)*a+1.0*t*b
end

---inverseLerp
---derives a number in a range between a and b
---@param a number
---@param b number
---@param t number
---@return number
function inverseLerp(a,b,t)
  return (t - a) / (b - a * 1.0)
end

function centerText(text, width)
  if string.len(text) == 0 then return nil end
  if string.len(text) > width then return nil end
  
  var = width - string.len(text)
  str = ""
  
  for _ = 0, var / 2 - 1 do
    str = str.." "
  end
  str = str..text
  for _ = var / 2, var do
    str = str.." "
  end
  return str
end

-- Because LuaJ is broken >.>
function trimDecimal(num, places)
  local unformatted = tostring(num)
  local formatted = ""
  if places > 0 then
    fmtString = "^(%d+%."
    while places > 0 do
      fmtString = fmtString.."%d"
      places = places - 1
      if string.match(unformatted, fmtString..")") then
        formatted = string.match(unformatted, fmtString..")")
      else
        places = 0
      end
    end
  else
    formatted  = string.match(unformatted, "^(%d+)")
  end
  return formatted
end

function percentFormat(num)
  local formatted = tostring(num)
  if string.match(formatted, "%.") then
    formatted = string.match(formatted, "^(%d+%.%d)")
  end
  return formatted.."%"
end

function powerFormat(num)
  local formatted = tostring(num)
  if num == nil then
    formatted = formatted.." RF/t"
  elseif num < 100 then
    if string.match(formatted, "%.%d%d") then
      formatted = string.match(formatted, "^(%d+%.%d%d)")
    end
    formatted = formatted.." RF/t"
  elseif num < 1000 then
    if string.match(formatted, "%.%d") then
      formatted = string.match(formatted, "^(%d+%.%d)")
    end
    formatted = formatted.." RF/t"
  else
    num = num / 1000
    formatted = tostring(num)
    if string.match(formatted, "%.%d%d") then
      formatted = string.match(formatted, "^(%d+%.%d%d)")
    end
    formatted = formatted.." kRF/t"
  end
  return formatted
end

function formatFlowRate(num)
  local formatted
  if num == nil then
    formatted = "nil mB/t"
  elseif num < 10000 then
    formatted = tostring(num).." mB/t"
  else
    num = num / 1000
    formatted = tostring(num)
    if string.match(formatted, "%.%d%d") then
      formatted = string.match(formatted, "^(%d+%.%d%d)")
    end
    formatted = formatted.." B/t"
  end
  return formatted
end

function stringWrap(text, width)
  if string.len(text) == 0 then return nil end
  done = false
  tmp = {}
  text = string.reverse(text)
  while not done do
    if string.len(text) <= width then
      table.insert(tmp, string.reverse(text))
      done = true
    else
      chop = string.find(text, " ", (0 - width))
      if chop == nil then chop = width end
      table.insert(tmp, string.reverse(string.sub(text, (chop + 1))))
      text = string.sub(text, 1, (chop - 1))
    end
  end
  return tmp
end

function trimFrom(text, letter)
  if string.len(letter) == 1 then
    local buf = string.reverse(text)
    chop = string.find(buf, letter)
    if chop == nil then
      return nil
    else
      return string.reverse(string.sub(text, (0 - chop + 1)))
    end
  else
    return nil
  end
end

function displayError(message)
  exists = false
  for _,v in pairs(m) do
    local mon = peripheral.wrap(v)
    mon.setTextScale(1)
    w, h = mon.getSize()
    st = stringWrap(message, w)
    if st == nil then
      if term.isColor() then
        term.setTextColor(colors.red)
      end
      print("Error was nil")
      if term.isColor() then
        term.setTextColor(colors.white)
      end
    elseif table.getn(st) > h then
      if term.isColor() then
        term.textColor(colors.red)
      end
      print("Error message was too long")
      if term.isColor() then
        term.setColor(colors.white)
      end
    else
      mon.clear()
      if mon.isColor() then
        mon.setBackgroundColor(colors.red)
      end
      for y = 1, h do
        mon.setCursorPos(1,y)
        for _ = 1, w do
          mon.write(" ")
        end
      end
      y = ((h - #st) / 2)
      for i = 1, #st do
        x = (w - string.len(st[i])) / 2
        mon.setCursorPos(x+1,y+i)
        mon.write(st[i])
      end
      if mon.isColor() then
        mon.setBackgroundColor(colors.black)
      end
    end
  end
  if (not exists) then
    w, h = term.getSize()
    st = stringWrap(message, w)
    if term.isColor() then
      term.setTextColor(colors.red)
    end
    if st == nil then
      print("Error was nil")
    else
      for i = 1, #st do
        print(st[i])
      end
    end
    if term.isColor() then
      term.setTextColor(colors.white)
    end
  end
end

function integrityCheck()
  assembled = false
  local error = 0
  while not assembled do
    scanPeripherals()
    reactorPresent = false
    turbinePresent = false
    steamPresent = false
    numReactors = 0
    numTurbines = 0
    numSteamReactors = 0
    for _,v in pairs(r) do
      numReactors = numReactors + 1
      reactorPresent = true
      local reactor = peripheral.wrap(v)
	  steamReactor[v] = reactor.coolantTank() ~= nil
      if steamReactor[v] then
        numSteamReactors = numSteamReactors + 1
		if (not steamPresent) then
		  steamPresent = true
		end
      end
    end
    for _,_ in pairs(t) do
      numTurbines = numTurbines + 1
      steamPresent = true
      turbinePresent = true
    end
    steamReactor[0] = steamPresent
    if (not turbinePresent) and (not reactorPresent) then
      setReactor(false)
      setTurbine(false)
      assembled = false
      if not (error == 1) then
        displayError("No reactor or turbine.")
      end
      sleep(1)
      error = 1
    else
      assembled = true
      error = 0
    end
  end
end

function checkReactor()
  -- Reset Reactor Statistics
  rActive = {}
  rConnected = {}
  rStoredEnergy = {}
  rEnergyRate = {}
  rFuelTemp = {}
  rCaseTemp = {}
  rRodNum = {}
  rRodLevel = {}
  rColdLiquid = {}
  rColdLiquidMax = {}
  rHotLiquid = {}
  rHotLiquidMax = {}
  
  rStoredEnergy[0] = 0
  rEnergyRate[0] = 0
  rMaxEnergy[0] = 0
  rColdLiquid[0] = 0
  rColdLiquidMax[0] = 0
  rHotLiquid[0] = 0
  rHotLiquidMax[0] = 0
  
  local battery
  local coolantTank
  
  for _,v in pairs(r) do
    local reactor = peripheral.wrap(v)
    if reactor then
      -- Get Reactor Statistics
      rActive[v] = reactor.active()
      rConnected[v] = reactor.connected()
      rFuelTemp[v] = reactor.fuelTemperature()
      rCaseTemp[v] = reactor.casingTemperature()
      rRodNum[v] = reactor.controlRodCount()
      rRodLevel[v] = reactor.getControlRod(0).level()

      if (not steamReactor[v]) then
        -- Energy Reactor things
		    battery = reactor.battery()
        rStoredEnergy[v] = battery.stored()
        rMaxEnergy[v] = battery.capacity()
        rEnergyRate[v] = battery.producedLastTick()
      else
        -- Turbine Reactor things
		    coolantTank = reactor.coolantTank()
        rColdLiquid[v] = coolantTank.coldFluidAmount()
        rColdLiquidMax[v] = coolantTank.capacity()
        rHotLiquid[v] = coolantTank.hotFluidAmount()
        rHotLiquidMax[v] = coolantTank.capacity()
      end
      
      
      -- if rStoredEnergy[v] == nil then print("Please disconnect and connect "..v) end
      
      -- Add to Global Statistics
      if steamReactor[v] then
        rColdLiquid[0] = rColdLiquid[0] + rColdLiquid[v]
        rColdLiquidMax[0] = rColdLiquidMax[0] + rColdLiquidMax[v]
        rHotLiquid[0] = rHotLiquid[0] + rHotLiquid[v]
        rHotLiquidMax[0] = rHotLiquidMax[0] + rHotLiquidMax[v]
      else
        rMaxEnergy[0] = rMaxEnergy[0] + rMaxEnergy[v]
        rStoredEnergy[0] = rStoredEnergy[0] + rStoredEnergy[v]
        rEnergyRate[0] = rEnergyRate[0] + rEnergyRate[v]
      end
    end
  end
end

function checkTurbine()
  -- Reset Turbine Statistics
  tActive = {}
  tConnected = {}
  tStoredEnergy = {}
  tEnergyRate = {}
  tFlowRate = {}
  tFlowRateCap = {}
  tFlowRateMax = {}
  tInductorEngaged = {}
  tInput = {}
  tOutput = {}
  tCapacity = {}
  tRotorSpeed = {}
  
  if tSpeedingUp == 2 then tSpeedingUp = 1 end
  
  tStoredEnergy[0] = 0
  tEnergyRate[0] = 0
  tMaxEnergy[0] = 0
  tFlowRate[0] = 0
  tInput[0] = 0
  tOutput[0] = 0
  tCapacity[0] = 0
  
  for _,v in pairs(t) do
    local turbine = peripheral.wrap(v)
    if turbine then
      -- Calculate Turbine Statistics
      tActive[v] = turbine.active()
      tConnected[v] = turbine.connected()
      local battery = turbine.battery()
      tStoredEnergy[v] = battery.stored()
      tMaxEnergy[v] = battery.capacity()
      tEnergyRate[v] = battery.producedLastTick()
      local tank = turbine.fluidTank()
      tFlowRate[v] = tank.flowLastTick()
      tFlowRateCap[v] = tank.nominalFlowRate()
      tFlowRateMax[v] = tank.flowRateLimit()
      local input = tank.input()
      tInput[v] = input.amount()
      tCapacity[v] = input.maxAmount()
      tHotLiquid[v] = input.name()
      local output = tank.output()
      tOutput[v] = output.amount()
      tColdLiquid[v] = output.name()
      local rotor = turbine.rotor()
      tRotorSpeed[v] = rotor.RPM()
      tRotorEfficiency[v] = rotor.efficiencyLastTick()
      tInductorEngaged[v] = turbine.coilEngaged()
      
      if tStoredEnergy[v] == nil then print("Please disconnect and connect "..v) end
      
      -- Add to Global Statistics
      tStoredEnergy[0] = tStoredEnergy[0] + tStoredEnergy[v]
      tEnergyRate[0] = tEnergyRate[0] + tEnergyRate[v]
      tMaxEnergy[0] = tMaxEnergy[0] + tMaxEnergy[v]
      tFlowRate[0] = tFlowRate[0] + tFlowRate[v]
      tInput[0] = tInput[0] + tInput[v]
      tOutput[0] = tOutput[0] + tOutput[v]
      tCapacity[0] = tCapacity[0] + tCapacity[v]
    end
  end
end

function calcCoolant(percent)
  if percent == 0 then
    return "Empty"
  elseif percent < 50 then
    return "Low"
  else
    return "Good"
  end
end

function calcGlobals()
  batPercent[0] = (tStoredEnergy[0] + rStoredEnergy[0]) / (tMaxEnergy[0] + rMaxEnergy[0]) * 100
end

function calcStrings(key, energyRate)
  batString[key] = percentFormat(batPercent[key])
  energyString[key] = powerFormat(energyRate)
end

function calcReactor(key)
  if not (key == 0) then
    if (steamReactor[key]) then
      hotPercent[key] = (rHotLiquid[key] / rHotLiquidMax[key]) * 100
      coldPercent[key] = (rColdLiquid[key] / rColdLiquidMax[key]) * 100
      coolantString[key] = calcCoolant(coldPercent[key])
    else
      batPercent[key] = rStoredEnergy[key] / rMaxEnergy[key] * 100
    end
  end
end

function calcTurbine(key)
  batPercent[key] = tStoredEnergy[key] / tMaxEnergy[key] * 100
  inputPercent[key] = (tInput[key] / tCapacity[key]) * 100
  outputPercent[key] = (tOutput[key] / tCapacity[key]) * 100
  flowString[key] = formatFlowRate(tFlowRate[key])
end

function calcReactorTurbine()
  calcGlobals()
  local hasSteamReactor = (numSteamReactors > 0)
  local hasNormalReactor = (numReactors - numSteamReactors > 0)
  local hasTurbine = (numTurbines > 0)
  if (hasTurbine or hasNormalReactor) then
    batString[0] = percentFormat(batPercent[0])
  else
    batString[0] = "--"
  end
  local energyRate
  if hasTurbine then energyRate = tEnergyRate[0] end
  if hasNormalReactor then
    if (energyRate == nil) then energyRate = 0 end
    energyRate = energyRate + rEnergyRate[0]
  end
  if (energyRate == nil) then
    energyString[0] = "--"
  else
    energyString[0] = powerFormat(energyRate)
  end
  if hasTurbine then
    inputPercent[0] = (tInput[0] / tCapacity[0]) * 100
    outputPercent[0] = (tOutput[0] / tCapacity[0]) * 100
    flowString[0] = formatFlowRate(tFlowRate[0])
  else
    inputPercent[0] = 0
    outputPercent[0] = 0
    flowString[0] = "--"
  end
  if hasSteamReactor then
    hotPercent[0] = (rHotLiquid[0] / rHotLiquidMax[0]) * 100
    coldPercent[0] = (rColdLiquid[0] / rColdLiquidMax[0]) * 100
    coolantString[0] = calcCoolant(coldPercent[0])
  else
    hotPercent[0] = 0
    coldPercent[0] = 0
    if hasTurbine then
      coolantString[0] = calcCoolant(outputPercent[0])
    else
      coolantString[0] = "--"
    end
  end
end

function resetCalculations()
  batPercent = {}
  batString = {}
  energyString = {}
  hotPercent = {}
  coldPercent = {}
  inputPercent = {}
  outputPercent = {}
  flowString = {}
  coolantString = {}
end

function processReactor(key)
  if rSettings[key] == nil then rSettings[key] = rSettings[0] end
  if rMode[key] == nil then rMode[key] = "init" end
  if rMeasurePoint[key] == nil then rMeasurePoint[key] = -1 end
  if not (rSettings[key]["manual"]) then
    local reactor = peripheral.wrap(key)
    local rodLevels = rRodLevel[key]
    local safetyMultiplier = 1.0
    if (rFuelTemp[key] > rSafetyTemp) then
      if (rFuelTemp[key] > rSafetyTemp + rSafetyMargin) then
        safetyMultiplier = 0.0
      else
        safetyMultiplier = (rFuelTemp[key] - rSafetyTemp) / rSafetyMargin
      end
    end
    if reactor and steamReactor[key] then
      local maxPercent = coldPercent[key] + hotPercent[key]
      local inverseRodLevel = 100.0 * coldPercent[key] / maxPercent
      inverseRodLevel = inverseRodLevel * inverseRodLevel * 0.01
      rodLevels = 100.0 - inverseRodLevel * safetyMultiplier
      -- TODO: Add Turbine integration to help with managing turbine speed
    else
      -- TODO: Add configurable values
      local inverseRodLevel = 0.0
      if batPercent[key] > bDefaultMax then
        inverseRodLevel = 0.0
      elseif batPercent[key] < bDefaultMin then
        inverseRodLevel = 100.0
      else
        inverseRodLevel = 100.0 * inverseLerp(bDefaultMin, bDefaultMax, batPercent[key])
        inverseRodLevel = inverseRodLevel * inverseRodLevel * 0.01
      end
      rodLevels = 100.0 - inverseRodLevel * safetyMultiplier
    end

    local reactorShouldBeActive = (rodLevels <= 99)
    if reactorShouldBeActive ~= reactor.active then reactor.setActive(reactorShouldBeActive) end

    reactor.setAllControlRodLevels(rodLevels)
  end
end

function processTurbine(key)
  if tSettings[key] == nil then tSettings[key] = tSettings[0] end
  if not (tSettings[key]["manual"]) then
    local turbine = peripheral.wrap(key)
    local tank = turbine.fluidTank()
    turbine.setActive(true)
    if batPercent[key] > 80  then turbine.setCoilEngaged(false) end
    if tRotorSpeed[key] < tSettings[key]["lowspeed"] then
      turbine.setCoilEngaged(false)
      tSpeedingUp[key] = 1
      tank.setNominalFlowRate(tank.flowRateLimit())
    end
    if tRotorSpeed[key] > tSettings[key]["highspeed"] then tSpeedingUp[key] = 0 end
    if (tRotorSpeed[key] > tSettings[key]["lowspeed"]) and (batPercent[key] < 20) then turbine.setCoilEngaged(true) end
    if (tSpeedingUp[key] == 0) then
      if tRotorSpeed[key] < tSettings[key]["normalspeed"] then tank.setNominalFlowRate(tFlowRate[key] + tSettings[key]["normalspeed"] - tRotorSpeed[key]) end
      if tRotorSpeed[key] > tSettings[key]["normalspeed"] then tank.setNominalFlowRate(tFlowRate[key] + tSettings[key]["normalspeed"] - tRotorSpeed[key]) end
    end
  end
end

function process()
  resetCalculations()
  turbineExists = false
  for _,v in pairs(t) do
    turbineExists = true
    calcTurbine(v)
    processTurbine(v)
  end
  reactorExists = false
  for _,v in pairs(r) do
    reactorExists = true
    calcReactor(v)
    processReactor(v)
  end
  calcReactorTurbine()
end

function drawRect(x,y,w,h,monitor,color,outline)
  local mon = peripheral.wrap(monitor)
  local draw = true
  if not (mon.isColor()) then
    if not (color == colors.black or color == colors.white) then draw = false end
    if not (outline == colors.black or outline == colors.white) then draw = false end
  end
  if (w >= 1) and (h >= 1) and draw then
    -- Save everything to restore later
    local restoreBackgroundColor = mon.getBackgroundColor()
    local restoreTextColor = mon.getTextColor()
    local restoreX,restoreY = mon.getCursorPos()
    if (not (outline == nil)) and (w >= 3) and (h >= 3) then
      mon.setBackgroundColor(outline)
      mon.setCursorPos(x,y)
      for _=1,w do mon.write(" ") end
      for c=1,h-2 do
        mon.setCursorPos(x,y+c)
        mon.write(" ")
        mon.setCursorPos(x+w-1,y+c)
        mon.write(" ")
      end
      mon.setCursorPos(x,y+h-1)
      for _=1,w do mon.write(" ") end
      x = x + 1
      y = y + 1
      w = w - 2
      h = h - 2
    end
    mon.setBackgroundColor(color)
    for c=y,y+h-1 do
      mon.setCursorPos(x,c)
      for _=1,w do mon.write(" ") end
    end
    -- Set everything back the way we found it
    mon.setBackgroundColor(restoreBackgroundColor)
    mon.setTextColor(restoreTextColor)
    mon.setCursorPos(restoreX,restoreY)
  end
end

function drawText(x,y,str,monitor,fgColor,bgColor)
  local retX, retY = x, y
  if not (str == nil) then
    local mon = peripheral.wrap(monitor)
    local restoreBackgroundColor
    local restoreTextColor
    local restoreX,restoreY = mon.getCursorPos()
    if not (fgColor == nil) then
      restoreTextColor = mon.getTextColor()
      mon.setTextColor(fgColor)
    end
    if not (bgColor == nil) then
      restoreBackgroundColor = mon.getBackgroundColor()
      mon.setBackgroundColor(bgColor)
    end
    mon.setCursorPos(x,y)
    mon.write(str)
    retX,retY = mon.getCursorPos()
    mon.setCursorPos(restoreX,restoreY)
    if not (fgColor == nil) then
      mon.setTextColor(restoreTextColor)
    end
    if not (bgColor == nil) then
      mon.setBackgroundColor(restoreBackgroundColor)
    end
  end
  return retX, retY
end

function drawBatPercent(monitor, key, redVal, yellowVal)
  local mon = peripheral.wrap(monitor)
  if mon.isColor() then
    if batPercent[key] <= redVal then
      mon.setTextColor(colors.red)
    elseif batPercent[key] <= yellowVal then
      mon.setTextColor(colors.yellow)
    else
      mon.setTextColor(colors.green)
    end
  end
  mon.write(batString[key])
  mon.setTextColor(colors.white)
end

function drawRFgen(monitor, key)
  local mon = peripheral.wrap(monitor)
  if mon.isColor() then
    if (energyString[key] == "--") or (energyString[key] == "0 RF/t") then
      mon.setTextColor(colors.red)
    else
      mon.setTextColor(colors.green)
    end
  end
  mon.write(energyString[key])
  mon.setTextColor(colors.white)
end

function drawCoolantLevel(monitor, key)
  local mon = peripheral.wrap(monitor)
  if mon.isColor() then
    if coolantString[key] == "Good" then
      mon.setTextColor(colors.green)
    elseif coolantString[key] == "Low" then
      mon.setTextColor(colors.yellow)
    else
      mon.setTextColor(colors.red)
    end
  end
  mon.write(coolantString[key])
  mon.setTextColor(colors.white)
end

function drawFlowRate(monitor, key)
  local mon = peripheral.wrap(monitor)
  if (flowString[key] == "--") and (mon.isColor()) then
    mon.setTextColor(colors.red)
  end
  mon.write(flowString[key])
  mon.setTextColor(colors.white)
end

function drawTopBar(monitor)
  local mon = peripheral.wrap(monitor)
  -- Save everything to restore later
  local restoreBackgroundColor = mon.getBackgroundColor()
  --local restoreBackgroundColor = colors.black
  local restoreTextColor = mon.getTextColor()
  --local restoreTextColor = colors.white
  local restoreX,restoreY = mon.getCursorPos()
  w, h = mon.getSize()
  mon.setCursorPos(1,1)
  if mon.isColor() then
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.white)
  else
    mon.setBackgroundColor(colors.white)
    mon.setTextColor(colors.black)
  end
  if steamReactor[0] then
    if numReactors == 0 then
      mon.write(centerText("Steam Turbine", w))
    else
      mon.write(centerText("Steam Reactor", w))
    end
  else
    mon.write(centerText("Reactor", w))
  end
  -- Set everything back the way we found it
  mon.setBackgroundColor(restoreBackgroundColor)
  mon.setTextColor(restoreTextColor)
  mon.setCursorPos(restoreX,restoreY)
end

function drawBottomBar(monitor, termString, backString)
  local mon = peripheral.wrap(monitor)
  if mon.isColor() then
    w, h = mon.getSize()
    if termString == nil then termString = "Terminate" end
    termString = " "..termString.." "
    local wordLen = string.len(termString)
    local spaceLen = (w - wordLen) / 2
    if not (backString == nil) then
      backString = " "..backString.." "
      wordLen = wordLen + string.len(backString)
      spaceLen = (w - wordLen) / 3
    end
    mon.setCursorPos(spaceLen + 1, h)
    mon.setBackgroundColor(colors.red)
    mon.write(termString)
    table.insert(mButtonLocations[monitor], { spaceLen + 1, h, 11, 1, "exit" })
    if not (backString == nil) then
      mon.setCursorPos(string.len(termString) + (spaceLen * 2) + 1, h)
      mon.write(backString)
      table.insert(mButtonLocations[monitor], { string.len(termString) + (spaceLen * 2) + 1, h, 11, 1, "back" })
    end
    mon.setBackgroundColor(colors.black)
  end
end

function drawReactor(x,y,w,h,monitor,reactor)
  if w > 7 then w = 7 end
  if w == 6 then w = 5 end
  if h > 12 then h = 12 end
  if (w >= 5) and (h >= 5) and not (reactor == nil) then
    drawRect(x, y, w, h, monitor, colors.yellow,colors.white)
    drawRect(x + 2, y + 1, w - 4, (h - 2) * rRodLevel[reactor] / 100, monitor, colors.red, nil)
  end
end

function drawTurbine(x,y,w,h,monitor,turbine)
  if w > 7 then w = 7 end
  if w == 6 then w = 5 end
  if h > 12 then h = 12 end
  if (w >= 5) and (h >= 5) then
    local inductorColor = colors.gray
    local inductorHeight = math.floor((h / 4) + 0.25)
    if tInductorEngaged[turbine] then
      inductorColor = colors.red
    else
      inductorColor = colors.blue
    end
    drawRect(x,y,w,h,monitor,colors.lightGray,colors.gray)
    drawRect(x + (w / 2), y + 1, 1, h - 2, monitor, colors.gray, nil)
    if tRotorSpeed[turbine] >= 1700 then
      for c = 1,(h - 3 - inductorHeight),2 do
        drawRect(x + (w / 2) - 1, y + 1 + c, 3, 1, monitor, colors.gray, nil)
      end
    end
    if w == 5 then
      drawRect(x + (w / 2), y + h - 1 - inductorHeight, 1, inductorHeight, monitor, inductorColor, nil)
    else
      drawRect(x + (w / 2) - 1, y + h - 1 - inductorHeight, 1, inductorHeight, monitor, inductorColor, nil)
      drawRect(x + (w / 2) + 1, y + h - 1 - inductorHeight, 1, inductorHeight, monitor, inductorColor, nil)
    end
  end
end

function pageSizes(w,h)
  local pageWidth = "normal"
  local pageHeight = "normal"
  if w < 23 then pageWidth = "small" end
  if w < 15 then pageWidth = "tiny" end
  if w > 50 then pageWidth = "large" end
  if h < 11 then pageHeight = "small" end
  if h < 6 then pageHeight = "tiny" end
  if h > 23 then pageHeight = "large" end
  return pageWidth, pageHeight
end

-- Page Types are: normal, tiny, wide, slender, huge, tall, small
function pageTyper(w,h)
  local pageWidth, pageHeight = pageSizes(w,h)
  local pageType = "normal"
  if pageHeight == "tiny" then
    if pageWidth == "tiny" or pageWidth == "small" then
      pageType = "tiny"
    else
      pageType = "wide"
    end
  elseif pageHeight == "large" then
    if pageWidth == "tiny" then
      pageType = "slender"
    elseif pageWidth == "large" then
      pageType = "huge"
    else
      pageType = "tall"
    end
  elseif pageWidth == "small" and pageHeight == "small" then
    pageType = "small"
  end
  return pageType
end

function drawReactorPage(x,y,w,h,monitor,reactor)
  local pageType = pageTyper(w,h)
  local statList = {}
  calcStrings(reactor, rEnergyRate[reactor])
  -- TODO: Make better tall and huge layouts
  if (pageType == "normal") or (pageType == "tall") or (pageType == "huge") then
    drawReactor(x + 1, y + 1, 7, h - 2, monitor, reactor)
    drawText(x + 9, y + 1, centerText("Reactor "..trimFrom(reactor, "_"), w - 10), monitor, nil, nil)
    -- Compile list
    n = 3
    if steamReactor[reactor] then
      table.insert(statList, {"Coolant", "Water", nil, nil})
      table.insert(statList, {"Cold", rColdLiquid[reactor].."/"..rColdLiquidMax[reactor].." mB", nil, nil})
      table.insert(statList, {"Hot", rHotLiquid[reactor].."/"..rHotLiquidMax[reactor].." mB", nil, nil})
    else
      table.insert(statList, {"RF Gen", energyString[reactor], nil, nil})
      table.insert(statList, {"Energy", batString[reactor], nil, nil})
    end
    table.insert(statList, {"Fuel Temp", trimDecimal(rFuelTemp[reactor], 1).." C", nil, nil})
    table.insert(statList, {"Case Temp", trimDecimal(rCaseTemp[reactor], 1).." C", nil, nil})
    -- Draw list
    for _, data in pairs(statList) do
      nX, nY = drawText(x + 9, y + n, data[1]..": ", monitor, nil, nil)
      drawText(nX, nY, data[2], monitor, data[3], data[4])
      n = n + 1
    end
  end
end

function drawTurbinePage(x,y,w,h,monitor,turbine)
  local pageType = pageTyper(w,h)
  local statList = {}
  calcStrings(turbine, tEnergyRate[turbine])
  -- TODO: Make better tall and huge layouts
  if (pageType == "normal") or (pageType == "tall") or (pageType == "huge") then
    drawTurbine(x + 1, y + 1, 7, h - 2, monitor, turbine)
    drawText(x + 9, y + 1, centerText("Turbine "..trimFrom(turbine, "_"), w - 10), monitor, nil, nil)
    -- Compile list
    n = 3
    table.insert(statList, {"RF Gen", energyString[turbine], nil, nil})
    table.insert(statList, {"Energy", batString[turbine], nil, nil})
    table.insert(statList, {"Flow", tFlowRate[turbine].." mB/t", nil, nil})
    table.insert(statList, {"Rotor", trimDecimal(tRotorSpeed[turbine], 0).." RPM", nil, nil})
    table.insert(statList, {"Inductor", tInductorEngaged[turbine], nil, nil})
    -- Draw list
    for _, data in pairs(statList) do
      nX, nY = drawText(x + 9, y + n, data[1]..": ", monitor, nil, nil)
      drawText(nX, nY, data[2], monitor, data[3], data[4])
      n = n + 1
    end
  end
end

function drawBackPage(x,y,w,h,monitor,text)
  -- Determine middle point
  -- Draw text centred
end

function drawPage(x,y,w,h,monitor,newPage)
  local realPage = false
  for _,v in pairs(r) do
    if newPage == v then
      realPage = true
      drawReactorPage(x,y,w,h,monitor,newPage)
      break
    end
  end
  for _,v in pairs(t) do
    if newPage == v then
      realPage = true
      drawTurbinePage(x,y,w,h,monitor,newPage)
      break
    end
  end
  if (not realPage) then
    drawBackPage(x,y,w,h,monitor,"Does not exist")
  end
end

function drawBigMain(x,y,w,h,monitor)
  local bigArrows = 0
  local split = false
  if w > 30 then bigArrows = 1 end
  if h > 18 then split = true end
  local topArrowSize = 0
  local bottomArrowSize = 0
  local topRowNum = 0
  local bottomRowNum = 0
  local height = h - 2
  local labelSize = 0
  if split then height = math.floor((h - 3) / 2) end
  if height > 6 then
    labelSize = 1
    height = height - 1
  end
  if height > 12 then height = 12 end
  local top = y + 1 + labelSize
  local bottomRightArrow = colors.black
  local bottomLeftArrow = colors.black
  local topRightArrow = colors.black
  local topLeftArrow = colors.black
  if mTopScrollPos[monitor] == nil then mTopScrollPos[monitor] = 0 end
  if mBottomScrollPos[monitor] == nil then mBottomScrollPos[monitor] = 0 end
  if split then
    topRowNum = numReactors
    bottomRowNum = numTurbines
    if numReactors * 8 + 1 > w then
      topArrowSize = 2 + bigArrows
      topRowNum = math.floor((w - 1 - topArrowSize) / 8)
    end
    if numTurbines * 8 + 1 > w then
      bottomArrowSize = 2 + bigArrows
      bottomRowNum = math.floor((w - 1 - bottomArrowSize) / 8)
    end
    if mTopScrollPos[monitor] + topRowNum >= numReactors then
      mTopScrollPos[monitor] = numReactors - topRowNum
      topRightArrow = colors.gray
    end
    if mBottomScrollPos[monitor] + bottomRowNum >= numTurbines then
      mBottomScrollPos[monitor] = numTurbines - bottomRowNum
      bottomRightArrow = colors.gray
    end
  else
    topRowNum = numReactors + numTurbines
    if (numReactors + numTurbines) * 8 + 1 > w then
      topArrowSize = 2 + bigArrows
      bottomArrowSize = 0
      topRowNum = math.floor((w - 1 - topArrowSize) / 8)
    end
    if mTopScrollPos[monitor] + topRowNum >= numReactors + numTurbines then
      mTopScrollPos[monitor] = numReactors + numTurbines - topRowNum
      topRightArrow = colors.gray
    end
    mBottomScrollPos[monitor] = 0
  end
  if mTopScrollPos[monitor] <= 0 then
    topLeftArrow = colors.gray
    mTopScrollPos[monitor] = 0
  end
  if mBottomScrollPos[monitor] <= 0 then
    bottomLeftArrow = colors.gray
    mBottomScrollPos[monitor] = 0
  end
  if (topArrowSize > 0) then
    drawRect(1, math.floor(top + height / 2 - 1.5), topArrowSize, 3, monitor, colors.lightGray, nil)
    drawRect(w - topArrowSize + 1, math.floor(top + height / 2 - 1.5), topArrowSize, 3, monitor, colors.lightGray, nil)
    drawText(topArrowSize - 1, math.floor(top + height / 2 - 0.5), "<", monitor, topLeftArrow, colors.lightGray)
    drawText(w - topArrowSize + 2, math.floor(top + height / 2 - 0.5), ">", monitor, topRightArrow, colors.lightGray)
    table.insert(mButtonLocations[monitor], { 1, math.floor(top + height / 2 - 1.5), topArrowSize, 3, "topLeftArrow" })
    table.insert(mButtonLocations[monitor], { w - topArrowSize + 1, math.floor(top + height / 2 - 1.5), topArrowSize, 3, "topRightArrow" })
  end
  local l = math.floor(w / 2 + 0.5) - (topRowNum * 4)
  local drawWait = mTopScrollPos[monitor]
  for _,v in pairs(r) do
    if drawWait <= 0 then
      if l + 8 > w - topArrowSize then break end
      drawReactor(x + l, top, 7, height, monitor, v)
      table.insert(mButtonLocations[monitor], { x + l, top, 7, height, v })
      if labelSize == 1 and peripheral.call(monitor, "isColor") then drawText(x + l, top - 1, centerText("R "..trimFrom(v, "_"), 7), monitor, nil, nil) end
      l = l + 8
    elseif drawWait > 0 then
      drawWait = drawWait - 1
    end
  end
  if split then
    drawWait = mBottomScrollPos[monitor]
    top = top + height + 1 + labelSize
    l = math.floor(w / 2 + 0.5) - (bottomRowNum * 4)
  end
  if (bottomArrowSize > 0) then
    drawRect(1, math.floor(top + height / 2 - 1.5), bottomArrowSize, 3, monitor, colors.lightGray, nil)
    drawRect(w - bottomArrowSize + 1, math.floor(top + height / 2 - 1.5), bottomArrowSize, 3, monitor, colors.lightGray, nil)
    drawText(bottomArrowSize - 1, math.floor(top + height / 2 - 0.5), "<", monitor, bottomLeftArrow, colors.lightGray)
    drawText(w - bottomArrowSize + 2, math.floor(top + height / 2 - 0.5), ">", monitor, bottomRightArrow, colors.lightGray)
    table.insert(mButtonLocations[monitor], { 1, math.floor(top + height / 2 - 1.5), bottomArrowSize, 3, "bottomLeftArrow" })
    table.insert(mButtonLocations[monitor], { w - bottomArrowSize + 1, math.floor(top + height / 2 - 1.5), bottomArrowSize, 3, "bottomRightArrow" })
  end
  for _,v in pairs(t) do
    if drawWait <= 0 then
      if l + 8 > w - bottomArrowSize then break end
      drawTurbine(x + l, top, 7, height, monitor, v)
      table.insert(mButtonLocations[monitor], { x + l, top, 7, height, v })
      if labelSize == 1 and peripheral.call(monitor, "isColor") then drawText(x + l, top - 1, centerText("T "..trimFrom(v, "_"), 7), monitor, nil, nil) end
      l = l + 8
    elseif drawWait > 0 then
      drawWait = drawWait - 1
    end
  end
  return nil, nil
end

function drawColumnMain(x,y,w,h,monitor)

end

function drawGridMain(x,y,w,h,monitor)

end

function drawGiantMain(x,y,w,h,monitor)
  drawBigMain(x,y,w,h,monitor)
end

function monDrawNormal(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos(w/2+1,2)
  mon.write("RF Gen: ")
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos(1,3)
  mon.write("Coolant: ")
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(w/2+1,3)
  mon.write("Flow: ")
  drawFlowRate(monitor, 0)
  if mSettings[monitor]["page"] == "main" then
    drawBigMain(1, 4, w, h - 4, monitor)
    drawBottomBar(monitor, "Terminate", nil)
  else
    drawPage(1, 4, w, h - 4, monitor, mSettings[monitor]["page"])
    drawBottomBar(monitor, "Terminate", "Back")
  end
end

function monDrawSmall(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos(1,3)
  mon.write("RF Gen: ")
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos(1,4)
  mon.write("Coolant: ")
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(1,5)
  mon.write("Flow: ")
  drawFlowRate(monitor, 0)
  if mon.isColor() then
    if h > 5 then
      if mSettings[monitor]["page"] == "main" then
        drawBottomBar(monitor, "Terminate", nil)
      else
        drawBottomBar(monitor, "Terminate", "Back")
      end
    else
      mon.setCursorPos(w,1)
      mon.setBackgroundColor(colors.red)
      mon.write("X")
      mon.setBackgroundColor(colors.black)
      table.insert(mButtonLocations[monitor], { w, 1, 1, 1, "exit" })
    end
  end
end

function monDrawTiny(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos(1,3)
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos(1,4)
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(1,5)
  drawFlowRate(monitor, 0)
  if mon.isColor() then
    mon.setCursorPos(w,1)
    mon.setBackgroundColor(colors.red)
    mon.write("X")
    mon.setBackgroundColor(colors.black)
    table.insert(mButtonLocations[monitor], { w, 1, 1, 1, "exit" })
  end
end

function monDrawHuge(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos((w+1)/4-1,2)
  mon.write("RF Gen: ")
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos((w+1)/2-1,2)
  mon.write("Coolant: ")
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(((w+1)/4)*3-1,2)
  mon.write("Flow: ")
  drawFlowRate(monitor, 0)
  mon.setCursorPos(1,3)
  if mSettings[monitor]["page"] == "main" then
    drawBigMain(1, 3, w, h - 3, monitor)
    drawBottomBar(monitor, "Terminate", nil)
  else
    drawBottomBar(monitor, "Terminate", "Back")
  end
end

function monDrawFat(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos(w/2+1,2)
  mon.write("RF Gen: ")
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos(1,3)
  mon.write("Coolant: ")
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(w/2+1,3)
  mon.write("Flow: ")
  drawFlowRate(monitor, 0)
  mon.setCursorPos(1,4)
  if mSettings[monitor]["page"] == "main" then
    drawBottomBar(monitor, "Terminate", nil)
  else
    drawBottomBar(monitor, "Terminate", "Back")
  end
end

function monDrawVeryFat(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos((w+1)/4-1,2)
  mon.write("RF Gen: ")
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos((w+1)/2-1,2)
  mon.write("Coolant: ")
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(((w+1)/4)*3-1,2)
  mon.write("Flow: ")
  drawFlowRate(monitor, 0)
  mon.setCursorPos(1,3)
  if mSettings[monitor]["page"] == "main" then
    drawBottomBar(monitor, "Terminate", nil)
  else
    drawBottomBar(monitor, "Terminate", "Back")
  end
end

function monDrawSlender(monitor)
  local mon = peripheral.wrap(monitor)
  mon.setTextScale(1)
  mon.clear()
  w, h = mon.getSize()
  drawTopBar(monitor)
  -- Draw Battery Level
  mon.setCursorPos(1,2)
  mon.write("Energy: ")
  mon.setCursorPos(1,3)
  drawBatPercent(monitor, 0, 20, 50)
  -- Draw RF Production
  mon.setCursorPos(1,4)
  mon.write("RF Gen: ")
  mon.setCursorPos(1,5)
  drawRFgen(monitor, 0)
  -- Draw Coolant Level
  mon.setCursorPos(1,6)
  mon.write("Coolant: ")
  mon.setCursorPos(1,7)
  drawCoolantLevel(monitor, 0)
  -- Draw Flow Rate
  mon.setCursorPos(1,8)
  mon.write("Flow: ")
  mon.setCursorPos(1,9)
  drawFlowRate(monitor, 0)
  if mon.isColor() then
    if mSettings[monitor]["page"] == "main" then
      drawBottomBar(monitor, "Off", nil)
    else
      drawBottomBar(monitor, "X", "<")
    end
  end
end

function drawMonitor(monitor)
  w, h = peripheral.call(monitor, "getSize")
  peripheral.call(monitor, "clear")
  mButtonLocations[monitor] = {}
  if w >= 65 then
    if h >= 11 then
      monDrawHuge(monitor)
    else
      monDrawVeryFat(monitor)
    end
  elseif w >= 23 then
    if h >= 11 then
      monDrawNormal(monitor)
    else
      monDrawFat(monitor)
    end
  elseif w >= 15 then
    monDrawSmall(monitor)
  elseif h > 5 then
    monDrawSlender(monitor)
  else
    monDrawTiny(monitor)
  end
end

function display()
  monConnected = false
  for _,v in pairs(m) do
    if mSettings[v] == nil then
      mSettings[v] = {}
      mSettings[v]["page"] = "main"
    elseif mSettings[v]["page"] == nil then
      mSettings[v]["page"] = "main"
    end
    monConnected = true
    drawMonitor(v)
  end
  if (not monConnected) then
    if not ((t == nil) and steamReactor[0]) then
      print("Energy use: "..batPercent[0].."%")
    end
  end
end

function changePage(monitor, newPage)
  local realPage = false
  if newPage == "back" then newPage = "main" end
  if newPage == "main" then realPage = true end
  for _,v in pairs(r) do
    if newPage == v then realPage = true end
  end
  for _,v in pairs(t) do
    if newPage == v then realPage = true end
  end
  if realPage then
    mSettings[monitor]["page"] = newPage
  end
  if newPage == "topLeftArrow" then mTopScrollPos[monitor] = mTopScrollPos[monitor] - 1 end
  if newPage == "topRightArrow" then mTopScrollPos[monitor] = mTopScrollPos[monitor] + 1 end
  if newPage == "bottomLeftArrow" then mBottomScrollPos[monitor] = mBottomScrollPos[monitor] - 1 end
  if newPage == "bottomRightArrow" then mBottomScrollPos[monitor] = mBottomScrollPos[monitor] + 1 end
  drawMonitor(monitor)
  saveMonTable()
end

-- Each entry is { x, y, w, h, "string" }
function verifyTouch(monitor, x, y)
  local command
  if not (mButtonLocations[monitor] == nil) then
    for _,v in pairs(mButtonLocations[monitor]) do
      if (x >= v[1]) and (x < v[1] + v[3]) then
        if (y >= v[2]) and (y < v[2] + v[4]) then
          command = v[5]
        end
      end
    end
  end
  return command
end

-- MAIN REACTOR EXECUTION BEGINS --

loadMonTable()
loadCalibrationData()
if tSettings[0] == nil then
  tSettings[0] = {}
  tSettings[0]["lowspeed"] = tDefaultLowSpeed
  tSettings[0]["highspeed"] = tDefaultHighSpeed
  tSettings[0]["normalspeed"] = tDefaultNormalSpeed
  tSettings[0]["manual"] = false
  tSettings[0]["max_power"] = bDefaultMax
  tSettings[0]["min_power"] = bDefaultMin
end
if rSettings[0] == nil then
  rSettings[0] = {}
  rSettings[0]["manual"] = false
  rSettings[0]["target_temp"] = rDefaultTempTarget
  rSettings[0]["fuel_rod_level"] = 100.0
  rSettings[0]["max_power"] = bDefaultMax
  rSettings[0]["min_power"] = bDefaultMin
end

while keepRunning do
  mButtonLocations = {}
  integrityCheck()
  checkReactor()
  checkTurbine()
  process()
  checkReactor()
  checkTurbine()
  display()
  -- keepRunning = false
  -- os.sleep(1)
  
  timerCode = os.startTimer(1)
  sentinel = true
  while sentinel do
    event, code, x, y = os.pullEvent()
    if event == "monitor_touch" then
      local command = verifyTouch(code, x, y)
      if command == "exit" then
        keepRunning = false
        sentinel = false
      elseif (command == "next") or (command == "prev") then
        -- code
      else
        changePage(code, command)
      end
    elseif (event == "timer") and (code == timerCode) then
      sentinel = false
    end
  end
end

setTurbine(false)
setReactor(false)

for _,v in pairs(m) do
  peripheral.call(v,"clear")
end
