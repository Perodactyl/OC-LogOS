local stream = module.import("stream")
local utils = module.import("utils")

return function(found_components)
	local best_gpu = nil
	local best_gpu_vram = 0
	
	local best_screen = nil
	local best_screen_depth = 0
	
	for addr,comp_type in hardware.list("gpu", true) do
		local gpu = hardware.proxy(addr)
		---@cast gpu GPUProxy
		
		if gpu.totalMemory() > best_gpu_vram then
			best_gpu = gpu
			best_gpu_vram = gpu.totalMemory()
		end
	end
	
	if not best_gpu then
		return
	end
	
	for addr,comp_type in hardware.list("screen", true) do
		local screen = hardware.proxy(addr)
		---@cast screen ScreenProxy
		best_gpu.bind(screen.address)
		
		if best_gpu.maxDepth() > best_screen_depth then
			best_screen_depth = best_gpu.maxDepth()
			best_screen = screen
		end
	end
	
	if not best_screen then
		return
	end
	
	local keyboards = { hardware.list("keyboard") }
	if not #keyboards then --TODO disable stdin instead
		return
	end
	
	best_gpu.bind(best_screen.address)
	
	local gpu = best_gpu
	
	local tty = {
		address= "tty0",
		type= "tty"
	}
	
	---@type AsyncReadStream, WriteStream
	local stdinReader, stdinWriter = stream.createAsyncReadStream()
	---@type AsyncReadStream, WriteStream
	local stdoutReader, stdoutWriter = stream.createAsyncReadStream()
	---@type AsyncReadStream, WriteStream
	local stderrReader, stderrWriter = stream.createAsyncReadStream()
	
	tty.stdin = stdinReader
	tty.stdout = stdoutWriter
	tty.stderr = stderrWriter
	
	local x = 1
	local y = 1
	
	local function scroll(delta)
		
	end
	
	local function write(...)
		local max_w, max_h = gpu.getResolution()
		local data = table.concat({...})
		
		local lines = {}
		
		for i,line in ipairs(utils.split_p(data, "\n")) do
			table.insert(lines, line)
		end
		
		local insert_val = nil
		local insert_location = nil
		
		local emergency_stop = 0
		while true do
			emergency_stop = emergency_stop + 1
			local changed = false
			if insert_val ~= nil and insert_location ~= nil then
				table.insert(lines, insert_location, insert_val)
			end
			local offset = x
			for i,line in ipairs(lines) do --Gradually smooth out the lines until they all individually fit.
				for j = 1, unicode.len(line) do
					local char = unicode.sub(line, j, j)
					offset = offset + unicode.charWidth(char)
					if offset > max_w then
						offset = 1
						changed = true
						lines[i] = unicode.sub(line, 1, j-1)
						insert_val = unicode.sub(line, j)
						insert_location = i+1
						break
					end
				end
				if changed then break end
			end
			if not changed then
				break
			end
			if emergency_stop > 64 then
				osctl.log(osint.utils.dump(lines))
				break
			end
		end
		
		for i,line in ipairs(lines) do
			gpu.set(x, y, line)
			x = 1
			y = y + 1
		end
	end
	stdoutReader.onData(function(data)
		write(data)
	end)
	stderrReader.onData(function(data)
		write(data)
	end)
	
	gpu.setResolution(20,10)
	tty.stdout.write("Hello, World™ Ya like jazz💀\n💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀")
	
	found_components["tty0"] = tty
end