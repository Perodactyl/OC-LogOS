local drives = {}
local filesystems = {}
local invoke = component.invoke

local function formatMemory(mem)
 local units = {"B", "KiB", "MiB", "GiB"}
 local unit = 1
 while mem > 1024 and units[unit] do
  unit = unit + 1
  mem = mem/1024
 end
 return mem.." "..units[unit]
end

local function getBootCode(addr)
 local sector1 = invoke(addr, "readSector", 1)
 for i = 1,#sector1 do
  if sector1:sub(i,i)=="\0" then
   sector1 = sector1:sub(1,i-1)
   break
  end
 end
 return sector1
end

local eeprom = component.list("eeprom")()

computer.getBootAddress = function()
 return invoke(eeprom, "getData")
end

computer.setBootAddress = function(addr)
 return invoke(eeprom, "setData", addr)
end

local function isBootable(addr)
 if component.type(addr) == "drive" then
  local f, err = load(getBootCode(addr))
  if not f then
   return false
  end
  return true
 elseif component.type(addr) == "filesystem" then
  return invoke(addr, "exists", "init.lua") and not invoke(addr, "isDirectory", "init.lua")
 else
  return false
 end
end

for i, _ in pairs(component.list("drive")) do
 if isBootable(i) then
  drives[#drives+1] = i
 end
end

for i, _ in pairs(component.list("filesystem")) do
 if isBootable(i) then
  filesystems[#filesystems+1] = i
 end
end

local screen = component.list("screen")()
local gpu = component.list("gpu")()
invoke(gpu, "bind", screen)
invoke(gpu, "setResolution", invoke(gpu, "maxResolution"))
local w, h = invoke(gpu, "getResolution")
local function clear()
 invoke(gpu, "setForeground", 0xFFFFFF)
 invoke(gpu, "setBackground", 0x000000)
 invoke(gpu, "fill", 1, 1, w, h, " ")
end
clear()

local function center(text, y)
 local x = w/2-#text/2
 invoke(gpu, "set", x, y, text)
end

local bootable = {}
for _, v in pairs(drives) do
 bootable[#bootable+1] = v
end
for _, v in pairs(filesystems) do
 bootable[#bootable+1] = v
end

local bootAddress = computer.getBootAddress()

for i, v in pairs(bootable) do
 if v == bootAddress then
  s = i
  break
 end
end

if s == nil then s = 1 end

local function drawMenu()
 center("Advanced Bootloader", 2)
 center("Select boot medium", 3)
 center("Computer Memory: "..formatMemory(computer.totalMemory()), 4)

 for i, v in pairs(bootable) do
  if i == s then
   invoke(gpu, "setForeground", 0x000000)
   invoke(gpu, "setBackground", 0xFFFFFF)
  end

  invoke(gpu, "fill", 1, i+5, w, 1, " ") -- Clear line
  center(v .. "(" .. (invoke(v, "getLabel") or "No Label") .. ")", i+5)

  if i == s then
   invoke(gpu, "setForeground", 0xFFFFFF)
   invoke(gpu, "setBackground", 0x000000)
  end
 end
end

local function boot(addr)
 clear()
 center("Booting " .. addr .. "(" .. (invoke(addr, "getLabel") or "No Label") .. ")", math.floor(h/2))
 center("Please wait...", math.floor(h/2)+1)
 computer.setBootAddress(addr)
 if component.type(addr) == "filesystem" then
  local handle, err = invoke(addr, "open", "/init.lua")
  if not handle then
   error(err)
  end
  local bootCode = ""
  repeat
   local chunk = invoke(addr, "read", handle, math.huge)
   bootCode = bootCode..(chunk or "")
  until not chunk
  return load(bootCode, "=init")()
 elseif component.type(addr) == "drive" then
  return load(getBootCode(addr), "=init")()
 end
 clear()
end

if #bootable == 1 then
 boot(bootable[1])
elseif #bootable == 0 then
 error("No bootable device!")
end

drawMenu()

while true do
 local e, _, _, code = computer.pullSignal()
 if e == "key_down" then
  if code == 208 then
   s = s + 1
   if s > #bootable then
    s = 1
   end
  elseif code == 200 then
   s = s - 1
   if s < 1 then
    s = #bootable
   end
  elseif code == 28 then
   return boot(bootable[s])
  end
  drawMenu()
 elseif e == "touch" then
  if bootable[code-5] then
   if s == code - 5 then
    boot(bootable[s])
   else
    s = code - 5
   end
  end
  drawMenu()
 end
end
