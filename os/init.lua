do
	---@param fs FilesystemProxy
	---@param path string
	local function read(fs, path)
		local handle = fs.open(path, "r")
		local block = fs.read(handle, math.huge)
		local out = ""
		if block == nil then return "" end
		repeat
			out = out .. block
			block = fs.read(handle, math.huge)
		until block == nil
		return out
	end
	
	local boot_fs = component.proxy(computer.getBootAddress()) --[[@as FilesystemProxy]]
	local boot_order = read(boot_fs,"/int/boot/boot_order")
	
	local boot_order_lines = {}
	local line = ""
	for i = 1,#boot_order do
		if string.sub(boot_order,i,i) == "\n" then
			table.insert(boot_order_lines, line)
			line = ""
		else
			line = line .. string.sub(boot_order, i,i)
		end
	end
	if #line > 0 then table.insert(boot_order_lines, line) end
	
	for i,boot_script in ipairs(boot_order_lines) do
		local prog = read(boot_fs, boot_script)
		local exe, load_error = load(prog, boot_script)
		if exe == nil or load_error then
			error("Bootstrapping error (ld): "..tostring(load_error))
		end
		local success, result = xpcall(exe, debug.traceback)
		if not success then
			error("OS root level error:\n"..tostring(result))
		end
	end
	
	error("OS execution has ended.")
end