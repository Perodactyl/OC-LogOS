--Previous: fs.lua

---@class DevKit
---  @field _DIRS table
---  @field _ENDPOINTS table
---  @field mkdir fun(path:string)
---  @field add fun(path:string, read: fun(data), write: fun(data))

do --TODO
	local dev = {}
	
	--- Implements a new device under /dev.
	---@param root string
	---@param callback fun(devkit:DevKit)
	---@return boolean success
	function dev.impl(root, callback)
		
	end
	
	---@type StdFSProvider|ROFSProvider
	dev.fs = {
		_PROVIDER = "DevFS",
		_FEATURES = "std",
		_VERSION = 1.0,
		
		isReadOnly= function()
			return false
		end,
		spaceUsed= function()
			return 0
		end,
		spaceTotal= function()
			return 0
		end,
		setLabel= function()
			error("Cannot change label of DevFS")
		end,
		getLabel= function()
			return "DevFS"
		end,
		makeDirectory= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		rename= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		remove= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		lastModified= function()
			return 0
		end
	}
end

--Next: thread.lua