do
	local ocelot = component.proxy(component.list("ocelot")())
	---@param fs FilesystemProxy
	---@param path string
	local function read(fs, path)
		local handle = fs.open(path, "r")
		local out = ""
		local blocks_read = 0
		while true do
			local block = fs.read(handle, math.huge)
			if block == nil then
				break
			end
			blocks_read = blocks_read + 1
			out = out .. block
		end
		-- ocelot.log("read "..blocks_read)
		fs.close(handle)
		return out
	end
	
	local boot_fs = component.proxy(computer.getBootAddress() --[[@as string]]) --[[@as FilesystemProxy]]
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
		local exe, load_error = load(prog, "="..boot_script)
		if exe == nil or load_error then
			error("Bootstrapping error (ld): "..tostring(load_error))
		end
		local success, result = xpcall(exe, debug.traceback)
		if not success then
			if _G.osctl.log then
				osctl.log("Root error:\n"..tostring(result))
			end
			error("OS root level error:\n"..tostring(result))
		end
	end
	
	error("OS execution has ended.")
end