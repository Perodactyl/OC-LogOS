--Previous: modular.lua

---@alias OSComponent _

---@class OSComponentAPI
---  @field get fun(addr: string): OSComponent
---  @field list fun(filter?: string, exact?: boolean): ... Returns a list matching component addresses. 

do
	
	local component = {}
	---@type OSComponentAPI
	_G.component = component
	
	local found_components = {}
	
	function component.get(addr)
		return found_components[addr]
	end
	
	---Returns a list of matching components.
	---@param filter? string
	---@param exact? boolean
	---@return ID ...
	function component.list(filter, exact)
		local out = {}
		for addr,comp in pairs(found_components) do
			if (not filter) or (comp.type == filter) or (not exact and string.sub(comp.type, 1, #filter) == filter) then
				table.insert(out, addr)
			end
		end
		
		return table.unpack(out)
	end
	
	function osctl.reloadComponents()
		found_components = {}
		local files = fs.list("/int/component.d")
		table.sort(files)
		for i,file in ipairs(files) do
			local finalpath = fs.join("/int/component.d",file)
			local success, result = xpcall(function()
				loadfile(finalpath)()(found_components)
			end, debug.traceback)
			if not success then
				osctl.log(string.format("Component driver %s crashed:\n%s",file,result))
			end
		end
	end
end

--Next: user_level.lua