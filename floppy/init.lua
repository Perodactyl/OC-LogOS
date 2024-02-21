---@diagnostic disable: assign-type-mismatch
do
	-- -@type EEPROMProxy
	local eeprom = component.list("eeprom")()
	local boot_addr = computer.getBootAddress() --Hope this exists *wink*
	---@type FilesystemProxy
	local fs = component.proxy(boot_addr)
	
	local skinny_fs = ""
	
	do
		local fs_file_handle = fs.open("skinny.fs", "r")
		local block = fs.read(fs_file_handle, math.huge)
		if block == nil then
			error("No skinnyFS File Found!")
		end
		repeat
			skinny_fs = skinny_fs .. block
			block = fs.read(fs_file_handle, math.huge)
		until block == nil
	end
	
	local skinny_script = ""
	do
		local fs_file_handle = fs.open("skinny.lua", "r")
		local block = fs.read(fs_file_handle, math.huge)
		if block == nil then
			error("No skinnyFS Driver Found!")
		end
		repeat
			skinny_script = skinny_script .. block
			block = fs.read(fs_file_handle, math.huge)
		until block == nil
	end
	
	local read_skinny_fs = load(skinny_script, "SkinnyFS Driver")()
	local targ_fs = read_skinny_fs(skinny_fs)
	
	local orig_component_proxy = component.proxy
	
	---@diagnostic disable-next-line: duplicate-set-field
	component.proxy = function(addr)
		if addr == boot_addr then
			return targ_fs
		else
			return orig_component_proxy(addr)
		end
	end
	
	local init_code = ""
	
	do
		local init_file_handle = targ_fs.open("init.lua", "r")
		local block = targ_fs.read(init_file_handle, math.huge)
		if block == nil then
			error("No init.lua!")
		end
		repeat
			init_code = init_code .. block
			block = targ_fs.read(init_file_handle, math.huge)
		until block == nil
	end
	
	local init_exe, error_message = load(init_code, "skinnified init.lua")
	
	if init_exe == nil then
		error("init.lua failed to load! " .. tostring(error_message))
	end
	
	return init_exe() --Returning causes chain calls; This function is deallocated and the next is immediately called.
end