--SkinnyFS Prototype v0.1

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
	
	local function contains_k(needle, haystack)
		for k,v in pairs(haystack) do
			if k == needle then
				return true
			end
		end
		return false
	end
	
	return function(data)
		local fs = {_TYPE="SkinnyFS", _SOURCE=data}
		local handles = {}
		local handle_id = 1
		local data_tree = {}
		
		local ptr = 1
		while data:byte(ptr) ~= 0 do
			ptr = ptr + 1 --skip length byte
			local start_addr_bytes = string.sub(data,ptr, ptr+4)
			ptr = ptr + 4
			local end_addr_bytes = string.sub(data,ptr, ptr+4)
			ptr = ptr + 4
			local filename = ""
			repeat
				filename = filename .. string.sub(data,ptr,ptr)
				ptr = ptr + 1
			until data:byte(ptr) == 0
			ptr = ptr + 1
			
			local start_addr = 0
			local end_addr = 0
			
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(1), 0))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(2), 1))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(3), 2))
			start_addr = bit32.bor(start_addr, bit32.lshift(start_addr_bytes:byte(4), 3))
			
			end_addr = bit32.bor(end_addr, bit32.lshift(end_addr_bytes:byte(1), 0))
			end_addr = bit32.bor(end_addr, bit32.lshift(end_addr_bytes:byte(2), 1))
			end_addr = bit32.bor(end_addr, bit32.lshift(end_addr_bytes:byte(3), 2))
			end_addr = bit32.bor(end_addr, bit32.lshift(end_addr_bytes:byte(4), 3))
			
			local file_block = string.sub(data,start_addr, end_addr+1)
			data_tree[filename] = file_block
		end
		
		function fs.open(path, mode)
			if mode == nil or mode == "rb" then
				mode = "r"
			end
			if mode ~= "r" then
				error("SkinnyFS: SkinnyFS is RO (attempt open ".. tostring(mode) ..")")
			end
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
		
		function fs.exists(path) --TODO folders
			return contains_k(path, data_tree)
		end
		
		function fs.spaceUsed() return #data end
		function fs.spaceTotal() return #data end
		function fs.isReadOnly() return true end
		function fs.isDirectory(path) return false end --TODO
		function fs.getLabel() return "SkinnyFS" end
		function fs.rename(path) error("SkinnyFS is RO (attempt rename)") end
		function fs.remove(path) error("SkinnyFS is RO (attempt remove)") end
		function fs.makeDirectory(path) error("SkinnyFS is RO (attempt mkdir)") end
		function fs.write(handle,value) error("SkinnyFS is RO (attempt write)") end
		
		return fs
	end
end