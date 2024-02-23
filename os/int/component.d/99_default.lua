local utils = module.import("utils")

return function(found_components)
	-- local list = {}
	-- local iter = hardware.list()
	-- local item,item_type = iter()
	-- repeat
	-- 	list[item] = item_type
	-- 	item, item_type = iter()
	-- until not item
	
	for addr,comp_type in hardware.list() do
		if not utils.contains_k(found_components, addr) then
			-- osctl.log(string.format("Creating default entry for %s", addr))
			local entry = {
				address = addr,
				type = comp_type
			}
			for i, method in ipairs(hardware.methods(addr)) do
				entry[method] = function(self,...)
					hardware.invoke(self.addr, method, ...)
				end
			end
			found_components[addr] = entry
		end
	end
end