local a do local b=component.invoke local function c(c1, c2, ...)local c3=table.pack(pcall(b,c1,c2,...))if not c3[1]then return nil,c3[2]else return table.unpack(c3,2,c3.n)end end local d=component.list("eeprom")()computer.getBootAddress=function()return c(d,"getData")end computer.setBootAddress=function(s1)return c(d,"setData",s1)end do local e=component.list("screen")()local f=component.list("gpu")()if f and e then c(f,"bind",e)end end local function f(f1)local f2,f3=c(f1,"open","/init.lua")if not f2 then return nil,f3 end local f4=""repeat local f5,f6=c(f1,"read",f2,math.huge)if not f5 and f6 then return nil,f6 end f4=f4..(f5 or"")until not f5 c(f1, "close", f2)return load(f4,"=init")end local g if computer.getBootAddress() then a,g=f(computer.getBootAddress())end if not a then computer.setBootAddress()for h in component.list("filesystem")do a,g=f(h)if a then computer.setBootAddress(h)break end end end if not a then error("no bootable medium found"..(g and (": "..tostring(g))or""),0)end computer.beep(1000, 0.2)end return a()