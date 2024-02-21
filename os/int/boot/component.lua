--Previous: modular.lua

do
	component = {}
	
	local found_components = {}
	
	function component.access(addr)
		return found_components[addr]
	end
	
	function osctl.reloadComponents()
		found_components = {}
		local files = fs.list("/int/component.d")
		table.sort(files)
		for i,file in ipairs(files) do
			local finalpath = fs.join("/int/component.d",file)
			local success, result = xpcall(function()
				dofile(finalpath)(found_components)
			end, debug.traceback)
		end
	end
end

--Next: