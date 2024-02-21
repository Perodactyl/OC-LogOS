-- Implementation of bit32, for consistency.
---@diagnostic disable: undefined-field
do
	local b32 = nil
	if _G.bit32 ~= nil then
		b32 = _G.bit32
	else
		local exe = load([[
			local bit32 = {}
			function bit32.arshift(x, disp) end
			function bit32.band(...)
				local out = math.huge
				for i,value in ipairs({...}) do
					out = out & value
				end
				return out
			end
			function bit32.bnot(x)
				return ~x
			end
			function bit32.bor(...)
				local out = 0
				for i,value in ipairs({...}) do
					out = out | value
				end
				return out
			end
			function bit32.btest(...) end
			function bit32.bxor(...)
				local out = 0
				for i,value in ipairs({...}) do
					out = out ~ value
				end
				return out
			end
			function bit32.extract(n, field, width) end
			function bit32.replace(n, v, field, width) end
			function bit32.lrotate(x, disp) end
			function bit32.lshift(x, disp) end
			function bit32.rrotate(x, disp) end
			function bit32.rshift(x, disp) end
			
			return bit32
		]])
		if exe then
			b32 = exe()
		end
	end
	module.exports(b32)
end