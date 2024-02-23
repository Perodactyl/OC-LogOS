---@diagnostic disable: assign-type-mismatch
do
	local boot_addr = computer.getBootAddress() --Hope this exists *wink*
	---@cast boot_addr string
	---@type FilesystemProxy
	local fs = component.proxy(boot_addr)
	
	--- Read a file from the boot fs.
	---@param path string
	---@param alt_fs? FilesystemProxy
	local function read_file(path, alt_fs)
		if alt_fs == nil then alt_fs = fs end
		local out = ""
		if not alt_fs.exists(path) then
			error("Missing or Empty File! Failed to read "..path)
		end
		local handle = alt_fs.open(path, "r")
		local block = alt_fs.read(handle, math.huge)
		if block == nil then
			error("Missing or Empty File! Failed to read "..path)
		end
		repeat
			out = out .. block
			block = alt_fs.read(handle, math.huge)
		until block == nil
		alt_fs.close(handle)
		return out
	end
	
	local function dump(o)
		if type(o) == 'table' then
			local s = '{ '
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. dump(v) .. ','
			end
			return s .. '} '
		else
			return tostring(o)
		end
	end
	
	fs.setLabel("LogOS Utilities")
	
	local function initialize_skinny_fs()
		local skinny_fs = read_file("skinny.fs")
		local skinny_script = read_file("skinny.lua")
		
		local read_skinny_fs = load(skinny_script, "SkinnyFS Driver")()
		return read_skinny_fs(skinny_fs)
	end
	
	local names = {}
	local longestOption = 0
	local selection = 1
	local function recalculate_longest_option(options)
		names = {}
		for k,v in pairs(options) do table.insert(names, k) end
		table.sort(names)
		longestOption = 0
		for i,name in ipairs(names) do longestOption = math.max(longestOption, #name) end
		selection = 1
	end
	
	local options = {}
	
	local gpu = component.list("gpu",true)()
	local screen = component.list("screen",true)()
	
	if (not screen) or (not gpu) then
		computer.beep("-.-")
		error("Unknown behaviour: No screen or gpu to select action.")
	end
	gpu    = component.proxy(gpu)
	screen = component.proxy(screen)
	---@cast gpu GPUProxy
	---@cast screen ScreenProxy
	
	gpu.bind(screen.address)
	
	local w,h = gpu.maxResolution()
	--Limit to a T2 screen's size
	if w > 80 then w = 80 end
	if h > 25 then h = 25 end
	gpu.setResolution(w,h)
	
	local target_palette = {
		0xff0000, --R
		0xff6666, --O
		0xffff33, --Y
		0x33ff33, --G
		0x6666ff, --B
		0x9966ff, --I
		0x9999ff, --V
		
		0x000000, --B
		0xffffff, --W
	}
	
	gpu.setDepth(gpu.maxDepth())
	-- local grey = (2^gpu.maxDepth()) < #target_palette
	
	local grey = true
	
	local logoBuffer = 0
	local optionsBuffer = 0
	
	local optionsOffset = 0
	
	if not grey then
		logoBuffer = gpu.allocateBuffer(5,1)
		optionsBuffer = gpu.allocateBuffer(longestOption, #options)
		
		if logoBuffer == nil or optionsBuffer == nil then --Not enough VRAM
			-- grey = true
			if logoBuffer ~= nil then
				gpu.freeBuffer(logoBuffer)
			end
			if optionsBuffer ~= nil then
				gpu.freeBuffer(optionsBuffer)
			end
			logoBuffer = 0
			optionsBuffer = 0
			optionsOffset = 3
		end
	end
	
	---@cast logoBuffer -?
	---@cast optionsBuffer -?
	
	-- gpu.setActiveBuffer(logoBuffer)
	-- gpu.setActiveBuffer(optionsBuffer)
	gpu.setActiveBuffer(0)
	
	if grey then
		gpu.setPaletteColor(0,0x000000)
		gpu.setPaletteColor(1, 0xFFFFFF)
	else
		for i,color in ipairs(target_palette) do
			gpu.setPaletteColor(i,color)
		end
		gpu.set(7,1,      "Utilities")
		gpu.set(1,2,"---------------")
	end
	
	gpu.setForeground(0xFFFFFF)
	gpu.setBackground(0x000000)
	
	local function pause()
		gpu.set(1, h, "Press any key")
		local down = false
		while true do
			local ev = {computer.pullSignal()}
			if #ev > 0 then
				if ev[1] == "key_down" then
					down = true
				end
				if down and ev[1] == "key_up" then
					break
				end
				if ev[1] == "touch" then
					break
				end
			end
		end
	end
	
	local medium_options = {}
	local confirm_options = {}
	local boot_options = {}
	
	local function log(text)
		text = dump(text)
		local ocelot = component.list("ocelot")()
		if ocelot then
			component.invoke(ocelot, "log", text)
		end
		gpu.set(1,h-1,text)
		gpu.copy(1,1,w,h,1,0)
		-- gpu.fill(1,h,w,1," ")
	end
	
	local function cp_skinny_fs(target, verbose)
		local function vblog(...)
			if verbose then log(...) end
		end
		if verbose then
			gpu.setForeground(0xFFFFFF)
			gpu.setBackground(0x000000)
			gpu.fill(1,1,w,h," ")
		end
		vblog("Reading SkinnyFS...")
		local skinny_fs = initialize_skinny_fs()
		---@cast skinny_fs FilesystemProxy
		vblog("SkinnyFS ready")
		
		local function recurse(dir)
			vblog("Entering "..dir)
			local files = skinny_fs.list(dir)
			vblog(#files)
			for i, file in ipairs(files) do
				local filepath = dir .. "/" .. file
				if skinny_fs.isDirectory(filepath) then
					vblog("mkdir "..filepath)
					target.makeDirectory(filepath)
					recurse(filepath)
				else
					vblog("cp "..filepath)
					local r_handle = skinny_fs.open(filepath, "r")
					local w_handle = target.open(filepath, "w")
					local block = nil
					while true do
						block = skinny_fs.read(r_handle, math.huge)
						if block == nil then break end
						target.write(w_handle, block)
					end
					skinny_fs.close(r_handle)
					target.close(w_handle)
				end
			end
		end
		
		vblog("Copying files...")
		recurse("")
	end
	
	boot_options = {
		["1. Try LogOS"]= function()
			_G._LOGOS_TEST = true
			_G._GET_EEPROM_ADDR = computer.getBootAddress
			_G._SET_EEPROM_ADDR = computer.setBootAddress
			
			---@diagnostic disable-next-line: duplicate-set-field, inject-field
			function computer.getBootAddress()
				return computer.tmpAddress()
			end
			---@diagnostic disable-next-line: duplicate-set-field, inject-field
			function computer.setBootAddress() end
			
			local tmp_fs = component.proxy(computer.tmpAddress() --[[@as string]])
			---@cast tmp_fs FilesystemProxy
			cp_skinny_fs(tmp_fs)
			
			local code = read_file("init.lua", tmp_fs)
			local exe, load_error = load(code, "=init.lua")
			if not exe or type(load_error) == "string" then
				---@cast load_error -?
				gpu.fill(1,1,w,h," ")
				gpu.set(1,1,load_error)
				pause()
				return
			end
			local result, why = pcall(exe)
			if not result then
				gpu.fill(1,1,w,h," ")
				gpu.set(1,1,why)
				pause()
				return
			end
			computer.shutdown()
		end,
		["2. Install LogOS"]= function()
			medium_options = {
				["01. Back"]= function()
					options = boot_options
					recalculate_longest_option(options)
				end,
			}
			
			local num = 2
			for addr,comp_type in component.list() do
				if comp_type == "filesystem" and not component.invoke(addr,"isReadOnly") then
					local proxy = component.proxy(addr)
					---@cast proxy FilesystemProxy
					local label = proxy.getLabel()
					if not label then label = "<none>" end
					local mode = "rw"
					medium_options[string.format("%02d. %s %s", num, addr, label)] = function()
						confirm_options = {
							["1. Cancel"]= function()
								options = medium_options
								recalculate_longest_option(options)
							end,
							["2. Install LogOS"]= function()
								cp_skinny_fs(proxy, true)
								log("Done!")
								log("Press any key 3 times.")
								pause()
								pause()
								pause()
								computer.setBootAddress(addr)
							end,
						}
						options = confirm_options
						recalculate_longest_option(options)
					end
					num = num + 1
				end
			end
			
			options = medium_options
			recalculate_longest_option(options)
		end,
		["3. Flash Pixel EEPROM"]= function()
			local eeprom = component.list("eeprom")()
			if eeprom then
				eeprom = component.proxy(eeprom)
				---@cast eeprom EEPROMProxy
			else
				computer.beep(440)
				gpu.set(1,h-1, "No EEPROM!")
				pause()
				return
			end
			eeprom.set(read_file("pixel.lua"))
			eeprom.setData("")
			eeprom.setLabel("Pixel EEPROM")
		end,
		["4. Flash Default EEPROM"]= function()
			local eeprom = component.list("eeprom")()
			if eeprom then
				eeprom = component.proxy(eeprom)
				---@cast eeprom EEPROMProxy
			else
				computer.beep(440)
				gpu.set(1,h-1, "No EEPROM!")
				pause()
				return
			end
			eeprom.set(read_file("basic.lua"))
			eeprom.setData("")
			eeprom.setLabel("Lua BIOS")
		end,
		["5. Flash Advanced Loader EEPROM"]= function()
			local eeprom = component.list("eeprom")()
			if eeprom then
				eeprom = component.proxy(eeprom)
				---@cast eeprom EEPROMProxy
			else
				computer.beep(440)
				gpu.set(1,h-1, "No EEPROM!")
				pause()
				return
			end
			eeprom.set(read_file("advanced.lua"))
			eeprom.setData("")
			eeprom.setLabel("AdvancedLoader")
		end,
		["6. Find another bootable medium"]= function()
			medium_options = {
				["01. Back"]= function()
					options = boot_options
					recalculate_longest_option(options)
				end
			}
			
			local num = 2
			for addr,comp_type in component.list() do
				if comp_type == "filesystem" then
					local proxy = component.proxy(addr)
					---@cast proxy FilesystemProxy
					local label = proxy.getLabel()
					if not label then label = "<none>" end
					local mode = "rw"
					if proxy.isReadOnly() then mode = "ro" end
					medium_options[string.format("%02d. %s %s %s", num, addr, mode, label)] = function()
						computer.setBootAddress(addr)
						computer.shutdown(true)
					end
					num = num + 1
				end
			end
			
			options = medium_options
			recalculate_longest_option(options)
		end,
		["7. Shutdown"]= function()
			computer.shutdown()
		end,
		["8. Reboot"]= function()
			computer.shutdown(true)
		end
	}
	options = boot_options
	recalculate_longest_option(options)
	
	local offset = 0
	
	local instaUpdate = false
	while true do
		if grey then
			gpu.setForeground(0xFFFFFF)
			gpu.setBackground(0x000000)
			gpu.fill(1,1,w,h," ")
			gpu.set(1,1,"LogOS Utilities")
			gpu.set(1,2,"---------------")
			for i,text in ipairs(names) do
				if i == selection then
					gpu.setForeground(0x000000)
					gpu.setBackground(0xFFFFFF)
					gpu.set(1,3+i,text)
				else
					gpu.setForeground(0xFFFFFF)
					gpu.setBackground(0x000000)
					gpu.set(1,3+i,text)
				end
			end
		else
			offset = offset - 1
			if logoBuffer then gpu.setActiveBuffer(logoBuffer) end
			gpu.setForeground(1+(((1+offset)-1) % (#target_palette-2)), true)
			gpu.set(1,1,"L")
			gpu.setForeground(1+(((3+offset)-1) % (#target_palette-2)), true)
			gpu.set(2,1,"o")
			gpu.setForeground(1+(((4+offset)-1) % (#target_palette-2)), true)
			gpu.set(3,1,"g")
			gpu.setForeground(1+(((5+offset)-1) % (#target_palette-2)), true)
			gpu.set(4,1,"O")
			gpu.setForeground(1+(((7+offset)-1) % (#target_palette-2)), true)
			gpu.set(5,1,"S")
			
			if optionsBuffer then gpu.setActiveBuffer(optionsBuffer) end
			gpu.fill(1,1+optionsOffset, #options, longestOption, " ")
			for i,text in ipairs(names) do
				if i == selection then
					for j = 1,#text do
						gpu.setForeground(j % (#target_palette-2), true)
						gpu.set(1+j,i+optionsOffset,string.sub(text,j,j))
					end
				else
					gpu.setForeground(0xFFFFFF)
					gpu.setBackground(0x000000)
					gpu.set(1,i+optionsOffset,text)
				end
			end
			-- gpu.setActiveBuffer(0)
			-- if logoBuffer then gpu.bitblt(0, 1,1, nil,nil, logoBuffer) end
			-- if optionsBuffer then gpu.bitblt(0, 1,4, nil,nil, optionsBuffer) end
		end
		
		local ev = {}
		if not instaUpdate then
			ev = {computer.pullSignal(0.25)}
		else
			instaUpdate = false
		end
		if #ev > 0 then
			if ev[1] == "key_down" then
				local code = ev[4]
				if code == 200 then --Up
					selection = selection - 1
					if selection < 1 then
						selection = #names + selection
					end
				elseif code == 208 then --Down
					selection = selection + 1
					if selection > #names then
						selection = selection - #names
					end
				elseif code == 28 then --Enter
					options[names[selection]]()
					instaUpdate = true
				end
			elseif ev[1] == "touch" then
				local old_sel = selection
				
				selection = ev[4] - 3
				-- selection = math.max(1, math.min(#names, selection))
				if selection < 1 or selection > #names then
					selection = old_sel
				elseif selection == old_sel then
					options[names[selection]]()
					instaUpdate = true
				end
			end
		end
	end
end