local utils = module.import("utils.lua")

return function(found_components)
	for addr in hardware.list() do
		if not utils.contains_k(found_components, addr) then
			local entry = {
				address = addr,
				type = hardware.type(addr)
			}
			for i, method in hardware.methods(addr) do
				entry[method] = function(self,...)
					hardware.invoke(self.addr, method, ...)
				end
			end
			found_components[addr] = entry
		end
	end
end