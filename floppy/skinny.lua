--SkinnyFS Prototype v0.2
local ocelot = component.proxy(component.list("ocelot")())
do
	local bit32 = {}
	---@diagnostic disable-next-line: undefined-field
	if not _G.bit32 then
		local fns, load_error = load([[
			local bit32 = {}
			function bit32.bor(a, b)
				return a | b
			end
			function bit32.lshift(n, dist)
				return n << dist
			end
			return bit32
		]], "(Lua 5.3+ redefine for bit32 functions)")
		if fns == nil then
			error("SkinnyFS: Failed to load bit32 defs: " .. tostring(load_error))
		end
		local success, result = pcall(fns)
		if not success then
			error("SkinnyFS: Failed to redefine bit32: " .. tostring(result))
		else
			bit32 = result
		end
	else
		---@diagnostic disable-next-line: undefined-field
		bit32 = _G.bit32
	end
	
	local function dump(o)
		if type(o) == 'table' then
			local s = '{ '
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. dump(v) .. ','
			end
			return s .. '} '
		else
			return tostring(o)
		end
	end
	
	local function contains_k(needle, haystack)
		for k,v in pairs(haystack) do
			if k == needle then
				return true
			end
		end
		return false
	end
	local function contains_v(needle, haystack)
		for k,v in pairs(haystack) do
			if v == needle then
				return true
			end
		end
		return false
	end
	
	local function split_p(src, pat, allow_empty)
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
	
	---@param path string
	---@return string[]
	local function segments(path)
		local out = split_p(path, "%/+")
		return out
	end
	
	--- Merges any number of path segments together from left to right.
	---@param ... string
	---@return string
	local function joinSegments(...)
		local segs = {...}
		return "/"..table.concat(segs, "/")
	end
	
	--- Merges any number of paths together from left to right.
	---@param ... string
	---@return string
	local function join(...)
		local paths = {...}
		local segs = {}
		for i,p in ipairs(paths) do
			segs = {table.unpack(segs), table.unpack(segments(p))}
		end
		return joinSegments(table.unpack(segs))
	end
	--- Creates the canon (unique, correct) form of a path
	---@param path string
	---@return string
	local function canonicalize(path)
		return joinSegments(table.unpack(segments(path)))
	end
	
	return function(data)
		local fs = {_TYPE="SkinnyFS", _SOURCE=data}
		local handles = {}
		local handle_id = 1
		---@type {[string]: string}
		local data_tree = {}
		
		local ptr = 1
		while data:byte(ptr) ~= 0 do
			ptr = ptr + 1 --skip length byte
			local start_addr_bytes = string.sub(data,ptr, ptr+4)
			ptr = ptr + 4
			local end_addr_bytes = string.sub(data,ptr, ptr+4)
			ptr = ptr + 4
			local filename_start = ptr
			repeat
				ptr = ptr + 1
			until data:byte(ptr) == 0
			local filename = data:sub(filename_start, ptr-1)
			ptr = ptr + 1
			
			local start_addr = 0
			local len = 0
			
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(1), 0))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(2), 8))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(3), 16))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(4), 24))
			
			len = bit32.bor(len, bit32.lshift(end_addr_bytes:byte(1), 0))
			len = bit32.bor(len, bit32.lshift(end_addr_bytes:byte(2), 8))
			len = bit32.bor(len, bit32.lshift(end_addr_bytes:byte(3), 16))
			len = bit32.bor(len, bit32.lshift(end_addr_bytes:byte(4), 24))
			
			-- ocelot.log(string.format("%x => %x, %s", start_addr, len, filename))
			
			local file_block = string.sub(data,start_addr+1, start_addr+len)
			data_tree[canonicalize(filename)] = file_block
		end
		
		local dir_tree = {
			dirs= {},
			files= {},
		}
		for path in pairs(data_tree) do
			local parts = segments(path)
			local section = dir_tree
			for i,part in ipairs(parts) do
				if i ~= #parts then
					if not contains_k(part, section.dirs) then
						section.dirs[part] = {
							dirs= {},
							files= {}
						}
					end
					section = section.dirs[part]
				else
					section.files[part] = joinSegments(table.unpack(parts, 1, i))
				end
			end
		end
		
		function fs.open(path, mode)
			if mode == nil or mode == "rb" then
				mode = "r"
			end
			if mode ~= "r" then
				error("SkinnyFS: SkinnyFS is RO (attempt open ".. tostring(mode) ..")")
			end
			path = canonicalize(path)
			if not contains_k(path, data_tree) then
				error("SkinnyFS: Tree miss: " .. path)
			end
			
			local handle = handle_id
			handles[handle] = {1, path}
			handle_id = handle_id + 1
			return handle
		end
		
		function fs.close(handle)
			if not contains_k(handle, handles) then
				error("SkinnyFS: Handle miss: #" .. tostring(handle))
			end
			handles[handle] = nil
		end
		
		function fs.read(handle, length)
			if not contains_k(handle, handles) then
				error("SkinnyFS: Handle miss: #" .. tostring(handle))
			end
			local handle_info = handles[handle]
			local filepath = handle_info[2]
			if not contains_k(filepath, data_tree) then
				error("SkinnyFS: Filedata miss: " .. filepath)
			end
			local data = data_tree[filepath]
			if handle_info[1] >= #data then
				return nil
			end
			local blocklen = math.min(handle_info[1]+length, #data, 2048)
			local out = string.sub(data,handle_info[1], blocklen)
			handle_info[1] = handle_info[1] + blocklen
			return out
		end
		
		function fs.seek(handle, whence, offset) --?? whence ??
			if not contains_k(handle, handles) then
				error("SkinnyFS: Handle miss: #" .. tostring(handle))
			end
			
			handles[handle][1] = handles[handle][1] + offset
		end
		
		function fs.exists(path)
			path = canonicalize(path)
			local parts = segments(path)
			local section = dir_tree
			for i, seg in ipairs(parts) do
				if i < #parts then
					for name,dir in ipairs(section.dirs) do
						if name == seg then
							section = dir
							break
						end
						return false
					end
				else
					for name in ipairs(section.files) do
						if name == seg then return true end
					end
					for name in ipairs(section.dirs) do
						if name == seg then return true end
					end
				end
			end
			return false
		end
		
		function fs.spaceUsed() return #data end
		function fs.spaceTotal() return #data end
		function fs.isReadOnly() return true end
		
		local function traverse(path)
			path = canonicalize(path)
			ocelot.log("Traverse "..path)
			local parts = segments(path)
			ocelot.log(tostring(#parts))
			local section = dir_tree
			-- ocelot.log(dump(section))
			for i, seg in ipairs(parts) do
				ocelot.log("seg: "..seg)
				local success = false
				for name,dir in pairs(section.dirs) do
					ocelot.log("name: "..name)
					if name == seg then
						ocelot.log("enter: "..name)
						section = dir
						success = true
						ocelot.log(dump(section))
						break
					end
				end
				if not success then --[[error("Traverse: Dead-End!")]] return nil end
			end
			-- ocelot.log(dump(section))
			return section
		end
		
		function fs.isDirectory(path)
			path = canonicalize(path)
			ocelot.log("isdir "..path)
			
			return traverse(path) ~= nil
			
			-- local segments = segments(path)
			-- local head, tail
			-- if #segments == 1 then
			-- 	ocelot.log("tailless")
			-- 	tail = "/"
			-- 	head = path
			-- elseif #segments == 0 then
			-- 	ocelot.log("short-circuit")
			-- 	return true --Must be root, which is a directory.
			-- else
			-- 	ocelot.log("regular")
			-- 	head = segments[#segments-1]
			-- 	tail = joinSegments(table.unpack(segments, 1, #segments-1))
			-- end
			-- local node = traverse(tail)
			-- for name, subdir in pairs(node.dirs) do
			-- 	ocelot.log(string.format("Check %s == %s", name, head))
			-- 	if canonicalize(name) == canonicalize(head) then
			-- 		ocelot.log(path.." is a directory")
			-- 		return true
			-- 	end
			-- end
			-- ocelot.log(path.." isn't a directory")
			-- return false
		end
		function fs.list(path)
			ocelot.log(path)
			local node = traverse(path)
			local out = {}
			for name in pairs(node.files) do
				if name ~= "dir.tag" then
					table.insert(out, name)
				end
			end
			for name in pairs(node.dirs) do
				table.insert(out, name)
			end
			return out
		end
		function fs.getLabel() return "SkinnyFS" end
		function fs.rename(path) error("SkinnyFS is RO (attempt rename)") end
		function fs.remove(path) error("SkinnyFS is RO (attempt remove)") end
		function fs.makeDirectory(path) error("SkinnyFS is RO (attempt mkdir)") end
		function fs.write(handle,value) error("SkinnyFS is RO (attempt write)") end
		function fs.setLabel() error("SkinnyFS is RO (attempt setLabel)") end
		
		return fs
	end
end