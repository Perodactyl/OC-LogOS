do
	local eeprom_addr = component.list("eeprom", true)()
	local eeprom = component.proxy(eeprom_addr)
	
	eeprom.setLabel("Vector BIOS")
	
	local boot_priority = {}
	
	function computer.getBootAddress()
		
	end
	function computer.setBootAddress(addr)
		
	end
	
	---@type GPUProxy[]
	local available_gpus = {}
	---@type GPUProxy?
	local gpu = nil
	---@type ScreenProxy[]
	local available_screens = {}
	---@type FilesystemProxy[]
	local available_fs = {} --[[@as FilesystemProxy[] ]]
	
	---@type {fs: FilesystemProxy, type: "nonboot" | "-floppy" | "floppy" | "-hdd" | "hdd"}[]
	local fs_classes = {}
	
	local function allocateDevices()
		available_gpus, available_screens, available_fs = {},{},{}
		for addr,type in component.list() do
			if type == "gpu" then table.insert(available_gpus,component.proxy(addr)) end
			if type == "screen" then table.insert(available_screens,component.proxy(addr)) end
			if type == "filesystem" then table.insert(available_fs,component.proxy(addr)) end
		end
		
		--TODO: Smart allocation of seperate tiered GPUs
		gpu = available_gpus[1]
		if gpu then
			local screen = available_screens[1]
			if screen then
				gpu.bind(screen.address)
			end
		end
	end
	
	allocateDevices()
end