--Beginning of boot chain

do
	_G._OS = "LogOS"
	_G._OS_VERSION = 0.0
	local osctl = {}
	--- OS Control
	_G.osctl = osctl
	
	local osint = {}
	osint.component = component
	_G.hardware = component
	--- OS Internals (used by boot scripts and such)
	_G.osint = osint
	
	local boot_fs = component.proxy(computer.getBootAddress())
	local file = nil
	---@cast boot_fs FilesystemProxy
	if not boot_fs.isReadOnly() then
		file = boot_fs.open("logos.log", "w")
		boot_fs.write(file,"OS log file beginning")
	end
	
	osint.boot_fs = boot_fs
	
	function osctl.log(...)
		if file ~= nil and not boot_fs.isReadOnly() then
			boot_fs.write(file, string.format("(%s) %s", computer.uptime(), table.concat({...}," ")))
		end
		local addr = hardware.list("ocelot", true)()
		local success = pcall(hardware.invoke,addr,"log",...)
		return success
	end
	
	osctl.log("Booting...")
	
	_G.void = {
		__metatable="void",
		__name= "void",
		
		__index=function(key)
			return nil
		end,
		__newindex=function(...) end,
		__eq=function(self, other)
			if other == false then return true end
			if getmetatable(other) == "void" then
				return true
			end
		end
	}
	
	function osint.impl_file_exec(fs)
		--- Mode does nothing. Doesn't load from stdin. This implementation is fallible, but reliable if unhandled.
		---@param filename string
		---@param mode any
		---@param env table?
		---@return function
		local function loadfile(filename, mode, env)
			local code = fs.open(filename, "r"):readAll()
			if code == nil then
				error("Failed to read "..filename)
			end
			local exe, err = load(code, "="..filename, mode, env)
			if not exe or err then
				error(err)
			end
			return exe
		end
		
		local function dofile(filename)
			return loadfile(filename)()
		end
		
		return loadfile, dofile
	end
	_G.loadfile, _G.dofile = osint.impl_file_exec(boot_fs)
end

--Next: util.lua