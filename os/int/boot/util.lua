--Previous: os.lua

do
	local utils = {}
	
	--- Returns true if `haystack` contains a key `needle`
	---@param haystack table
	---@param needle any
	---@return boolean found, any? value
	function utils.contains_k(haystack, needle)
		for k,v in pairs(haystack) do
			if k == needle then
				return true, v
			end
		end
		return false
	end
	--- Returns true if `haystack` contains a value `needle`
	---@param haystack table
	---@param needle any
	---@return boolean found, any? key
	function utils.contains_v(haystack, needle)
		for k,v in pairs(haystack) do
			if v == needle then
				return true, k
			end
		end
		return false
	end
	
	--- Returns all keys in a kv table.
	---@generic T
	---@param tbl { [T]: any }
	---@return T[]
	function utils.keys(tbl)
		local out = {}
		for k,v in pairs(tbl) do
			table.insert(out, k)
		end
		return out
	end
	
	--- Splits a string `src` into a list by `delim`. If `allow_empty` (default false) is true, empty segments may exist.
	---@deprecated --TODO
	function utils.split_c(src, delim, allow_empty)
		local accum = ""
		local out = {}
		for i = 1,#src do
			local char = src:sub(i,i)
			
		end
	end
	
	--- Splits a string `src` into a list by pattern `delim`. If `allow_empty` (default false) is true, empty segments may exist.
	---@param src string Input value to split
	---@param pat string? Pattern to split by. Defaults to `"%s"`.
	---@param allow_empty boolean? If `allow_empty` (default `false`) is `true`, empty segments may be output.
	function utils.split_p(src, pat, allow_empty)
		if pat == nil then
			pat = "%s"
		end
		if allow_empty == nil then
			allow_empty = false
		end
		local out = {}
		
		for str in string.gmatch(src, string.format("([^%s]+)", pat)) do
			table.insert(out, str)
		end
		
		return out
	end
	
	-- setmetatable(string, {
	-- 	__index = string,
	-- 	split = utils.split_p
	-- })
	---shameless theft
	function utils.dump(o)
		if type(o) == 'table' then
			local s = '{ '
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. utils.dump(v) .. ','
			end
			return s .. '} '
		else
			return tostring(o)
		end
	end
	
	function utils.count(tbl)
		local count = 0
		for _ in pairs(tbl) do
			count = count + 1
		end
		return count
	end
	
	osint.utils = utils
end

--Next: fs.lua