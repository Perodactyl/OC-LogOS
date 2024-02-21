    bin/shell.lua   �  boot/boot_order �  �  boot/dev.lua �  g&  boot/fs.lua i&  
,  boot/modular.lua ,  �/  boot/os.lua �/  iN  boot/thread.lua kN  �Q  boot/tty.lua �Q  6R  boot/user_level.lua 8R  5[  boot/util.lua 7[  �_  init.lua �_  �_  test.mod.lua  do
	
end/boot/os.lua
/boot/util.lua
/boot/fs.lua
/boot/dev.lua
/boot/thread.lua
/boot/modular.lua
/boot/tty.lua
/boot/user_level.lua--Previous: fs.lua

---@class DevKit
---  @field _DIRS table
---  @field _ENDPOINTS table
---  @field mkdir fun(path:string)
---  @field add fun(path:string, read: fun(data), write: fun(data))

do --TODO
	local dev = {}
	
	--- Implements a new device under /dev.
	---@param root string
	---@param callback fun(devkit:DevKit)
	---@return boolean success
	function dev.impl(root, callback)
		
	end
	
	---@type StdFSProvider|ROFSProvider
	dev.fs = {
		_PROVIDER = "DevFS",
		_FEATURES = "std",
		_VERSION = 1.0,
		
		isReadOnly= function()
			return false
		end,
		spaceUsed= function()
			return 0
		end,
		spaceTotal= function()
			return 0
		end,
		setLabel= function()
			error("Cannot change label of DevFS")
		end,
		getLabel= function()
			return "DevFS"
		end,
		makeDirectory= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		rename= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		remove= function()
			error("Use dev.impl to add modules to the DevFS!")
		end,
		lastModified= function()
			return 0
		end
	}
end

--Next: thread.lua--Previous: util.lua

---@alias FSProvider ROFSProvider | StdFSProvider
---@class ROFSProvider
---  @field _FEATURES "ro"
---  @field _PROVIDER string
---  @field _VERSION number?
---  @field isReadOnly fun(): true Returns whether the file system is read-only.
---  @field exists fun(path:string): boolean Returns whether an object exists at the specified absolute path in the file system.
---  @field open fun(path:string,mode?:FSHandleMode): FSHandle Opens a new file descriptor and returns its handle.
---  @field seek fun(handle:number,whence:string,offset:number): number Seeks in an open file descriptor with the specified handle. Returns the new pointer position.
---  @field spaceTotal fun(): integer The overall capacity of the file system, in bytes.
---  @field isDirectory fun(path:string): boolean Returns whether the object at the specified absolute path in the file system is a directory.
---  @field list fun(path:string): string[] Returns a list of names of objects in the directory at the specified absolute path in the file system.
---  @field lastModified fun(path:string): number Returns the (real world) timestamp of when the object at the specified absolute path in the file system was modified.
---  @field getLabel fun(): string Get the current label of the file system.
---  @field close fun(handle:FSHandle) Closes an open file descriptor with the specified handle.
---  @field size fun(path:string): integer Returns the size of the object at the specified absolute path in the file system.
---  @field read fun(handle:FSHandle,count:integer): string|nil Reads up to the specified amount of data from an open file descriptor with the specified handle. Returns nil when EOF is reached. WARNING: Max amount of bytes read is 2048.
---@class StdFSProvider: ROFSProvider
---  @field _FEATURES "std"
---  @field _PROVIDER string
---  @field _VERSION number?
---  @field isReadOnly fun(): false Returns whether the file system is read-only.
---  @field spaceUsed fun(): integer The currently used capacity of the file system, in bytes.
---  @field setLabel fun(value:string): string Sets the label of the file system. Returns the new value, which may be truncated.
---  @field makeDirectory fun(path:string): boolean Creates a directory at the specified absolute path in the file system. Creates parent directories, if necessary.
---  @field write fun(handle:FSHandle,value:string): boolean Writes the specified data to an open file descriptor with the specified handle.
---  @field rename fun(from:string,to:string): boolean Renames/moves an object from the first specified absolute path in the file system to the second.
---  @field remove fun(path:string): boolean Removes the object at the specified absolute path in the file system.

---@class File
---  @field _PROVIDER FSProvider Provider for this file
---  @field _MODE FSHandleMode Mode file was opened in
---  @field _HANDLE FSHandle Provider-specific handle for this file
---  @field _GLOBAL_PATH string Path to opened file
---  @field _PROVIDER_PATH string Provider-specific path to opened file
---  @field read fun(self, count:integer): string|nil Reads up to the specified amount of data from an open file. Returns nil when EOF is reached.
---  @field write fun(self,value:string): boolean Writes the specified data to an open file descriptor with the specified handle.
---  @field seek fun(self,whence:string,offset:number): number Seeks in an open file descriptor with the specified handle. Returns the new pointer position.
---  @field close fun(self) Closes an open file descriptor with the specified handle.
---  @field readAll fun(self): string|nil Reads the entire file and closes it. Useful inline.

local file_mt = {
	__index={
		---@param self File
		---@param count number
		read= function(self, count)
			local out = ""
			local block = self._PROVIDER.read(self._HANDLE, count)
			if block == nil then return out end
			repeat
				out = out .. block
				block = self._PROVIDER.read(self._HANDLE, count)
			until block == nil
			return out
		end,
		---@param self File
		---@param data string
		write= function(self, data)
			self._PROVIDER.write(self._HANDLE, data)
		end,
		---@param self File
		---@param whence string
		---@param offset number
		seek= function(self, whence, offset)
			return self._PROVIDER.seek(self._HANDLE, whence, offset)
		end,
		---@param self File
		close= function(self)
			self._PROVIDER.close(self._HANDLE)
			self._HANDLE = nil
			self._PROVIDER = nil
			self._GLOBAL_PATH = nil
			self._PROVIDER_PATH = nil
			setmetatable(self,void)
		end,
		---@param self File
		readAll= function(self)
			local data = self:read(math.huge)
			self:close()
			return data
		end
	}
}

do
	local fs = {}
	osctl.fs = {
		fsProviders= {},
		--- Returns a StdFSProvider for any component filesystem.
		---@param addr ID
		---@return StdFSProvider
		physicalFS= function(addr)
			if type(addr) ~= "string" then
				error(string.format("PhysicalFS: Failed to mount %s: addr is not of type string (it is %s)", addr, type(addr)))
			end
			if component.type(addr) ~= "filesystem" then
				error(string.format("PhysicalFS: Failed to mount %s: component is of type %s, not filesystem.", addr, component.type(addr)))
			end
			---@type StdFSProvider
			---@diagnostic disable-next-line: assign-type-mismatch
			local output = component.proxy(addr)
			output._PROVIDER="PhysicalFS: " .. addr
			output._VERSION=1.0
			output._FEATURES="std"
			
			return output
		end
	}
		
	--- Mounts any FSProvider at the specified path.
	---@param path string
	---@param provider FSProvider
	function osctl.fs.mount(path, provider)
		osctl.fs.fsProviders[fs.canonicalize(path)] = provider
	end
	
	--- Returns a list of segments of a path.
	---@param path string
	---@return string[]
	function fs.segments(path)
		return osint.utils.split_p(path, "%/+")
	end
	
	--- Merges any number of path segments together from left to right.
	---@param ... string
	---@return string
	function fs.joinSegments(...)
		local segments = {...}
		return "/"..table.concat(segments, "/")
	end
	
	--- Merges any number of paths together from left to right.
	---@param ... string
	---@return string
	function fs.join(...)
		local paths = {...}
		local segments = {}
		for i,path in ipairs(paths) do
			segments = {table.unpack(segments), table.unpack(fs.segments(path))}
		end
		return fs.joinSegments(table.unpack(segments))
	end
	--- Creates the canon (unique, correct) form of a path
	---@param path string
	---@return string
	function fs.canonicalize(path)
		return "/"..table.concat(fs.segments(path), "/")
	end
	
	---@param path string
	---@return FSProvider?,string
	local function locateProvider(path)
		if not path then
			error("Cannot locate a nil path!")
		end
		path = fs.canonicalize(path)
		local segments = fs.segments(path) --NOTE this is currently redundant.
		
		local i = #segments
		repeat --Always iterate at least once (otherwise "/" doesn't work.)
			local provider_path = fs.joinSegments(table.unpack(segments, 1, i))
			local found, provider = osint.utils.contains_k(osctl.fs.fsProviders, provider_path)
			if found then
				return provider,fs.joinSegments(table.unpack(segments, i+1))
			end
			i = i - 1
		until i == 1
		return nil,"not found"
	end
	
	--- Opens a file and returns a proxy to its further methods.
	---@param path string
	---@param mode FSHandleMode
	---@return File
	function fs.open(path, mode)
		local provider, providedPath = locateProvider(path)
		if provider == nil then
			error(string.format("No FS provider for %s", path))
		end
		
		local handle = provider.open(providedPath, mode)
		return setmetatable({
			_PROVIDER= provider,
			_MODE= mode,
			_HANDLE= handle,
			_GLOBAL_PATH= path,
			_PROVIDER_PATH= providedPath,
		}, file_mt)
	end
	
	function fs.exists(path)
		local provider, providedPath = locateProvider(path)
		if provider == nil then
			return false
		end
		return provider.exists(providedPath)
	end
	
	osctl.fs.mount("/", osctl.fs.physicalFS(computer.getBootAddress()))
	
	-- coroutine.create(function()
	-- 	while true do
	-- 		local ev, addr, type = computer.pullSignal(0.25)
	-- 		if ev == "component_added" then
	-- 			if type == "filesystem" then
	-- 				osctl.fs.mount("/mnt/"..addr:sub(1,8), osctl.fs.physicalFS(addr))
	-- 			end
	-- 		end
	-- 	end
	-- end)
	
	_G.fs = fs
end

--Next: dev.lua--Previous: thread.lua

do
	local module = {}
	
	module.paths = {
		"%s",
		"/lib/%s",
		"/pkg/lib/%s",
	}
	
	function module.pathOf(modulePath)
		for i,template in ipairs(module.paths) do
			local target = string.format(template, modulePath)
			if fs.exists(target) then
				return target
			end
		end
		return nil
	end
	--- Import a module.
	---@param modulePath string
	---@return any ...
	function module.import(modulePath)
		local target = module.pathOf(modulePath)
		if not target then
			error("Import: No module found for "..tostring(modulePath))
		end
		local code = fs.open(target,"r"):readAll()
		if not code then --Assume the file exists, but is empty. An empty file would return nil.
			return nil
		end
		local exe, load_error = load(code, string.format("import(%s) -> %s",modulePath,target))
		if load_error or not exe then
			error(string.format("Import: Failed to load %s: %s", target, load_error))
		end
		local pid, thr = thread.start(function()
			local success, reason = xpcall(exe, debug.traceback)
			if not success then
				error(string.format("Import: Module %s crashed: %s", target, reason))
			end
		end)
		osint.resume(thr.thr)
		local data = {coroutine.resume(thr)}
		if data[1] == "module_export" then
			return table.unpack(data, 2)
		end
	end
	--- Export data in bulk from a module.
	---@param ... any
	function module.exports(...)
		coroutine.yield("module_export", ...)
	end
	
	_G.module = module
end

--Next:--Beginning of boot chain

do
	_G._OS = "LogOS"
	_G._OS_VERSION = 0.0
	local osctl = {}
	--- OS Control
	_G.osctl = osctl
	
	local boot_fs = component.proxy(computer.getBootAddress())
	---@cast boot_fs FilesystemProxy
	local file = boot_fs.open("log.txt", "w")
	boot_fs.write(file,"OS starting up")
	
	function osctl.log(...)
		boot_fs.write(file, string.format("(%s) %s", computer.uptime(), table.concat({...}," ")))
		local addr = component.list("ocelot", true)()
		local success = pcall(component.invoke,addr,"log",...)
		return success
	end
	
	osctl.log("Booting...")
	
	_G.void = {
		__metatable="void",
		__index=function(key)
			return nil
		end,
		__newindex=function(...) end,
		__eq=function(self, other)
			if getmetatable(other) == "void" then
				return true
			end
		end
	}
	
	local osint = {}
	--- OS Internals (used by boot scripts and such)
	_G.osint = osint
end

--Next: util.lua--Previous: dev.lua

---@alias OSThreadState "rest" | "exit" | "error" | "poll" | "+listener" | "bg" | "transmit" | "transmit_yield" | "recieve" | ""
---@alias PID integer

---@class OSThread
---  @field state OSThreadState State of the thread, used by the kernel.
---  @field cmdInfo table Information passed between thread and kernel. Bidirectional.
---  @field parent PID Thread that spawned this.
---  @field children PID[] Threads spawned by this.
---  @field thr thread Underlying lua thread.
---  @field messages any[] Messages received asynchronously from other threads.
---  @field listens (fun(...):boolean?)[] Listeners placed by thread.listen_event

do
	local thread = {}
	local kernel = function() --Manager of coroutines. Run once all further code is set up into coroutines.
		computer.beep(440,0.1)
		osctl.log("-- Kernel loop beginning. --")
		while osint.utils.count(osint.threadpool) > 0 do
			-- osctl.log("NEW PULL")
			local ev = {computer.pullSignal(0.05)}
			for pid, target in pairs(osint.threadpool) do
				local status = coroutine.status(target.thr)
				if status == "suspended" or status == "dead" then
					if target.state == "rest" then
						target.state = ""
						osint.resume(target.thr)
					elseif target.state == "exit" then
						osctl.log("exit #"..pid)
						osint.threadpool[pid] = nil
						-- coroutine.close(target.thr)
					elseif target.state == "error" then
						osctl.log(string.format("ERROR in #%s:\n%s\n\nTerminated.",pid,target.cmdInfo[1]))
						target.state = "exit"
					elseif target.state == "poll" then
						target.state = ""
						target.cmdInfo = {table.unpack(ev)}
						osint.resume(target.thr)
					elseif target.state == "+listener" then
						target.state = ""
						target.listens[target.cmdInfo[1]] = target.cmdInfo[2]
						osctl.log(string.format("+listener '%s' -> %s", target.cmdInfo[1], target.cmdInfo[2]))
						osctl.log("Now "..tostring(#target.listens).." entries")
						target.cmdInfo = {}
						osint.resume(target.thr) --Note that this gives callback fns root powers.
					elseif target.state == "transmit" then
						target.state = ""
						local exists,thread = osint.utils.contains_k(osint.threadpool,target.cmdInfo.pid)
						if not exists then
							target.state = "error"
							target.cmdInfo = {string.format("Cannot transmit to #%s: thread not found",target.cmdInfo.pid)}
						elseif thread.state == "receive" then
							osint.resume(thread.thr,target.cmdInfo.data)
						else
							table.insert(thread.messages, target.cmdInfo.data)
						end
					end
				end
				if osint.utils.contains_k(target.listens, "*") then
					target.listens["*"](ev)
				end
				if osint.utils.contains_k(target.listens, ev[1]) then
					target.listens[ev[1]](ev)
				end
			end
		end
	end
	
	osint.kernel = kernel
	--- Table matching `PID`s to `OSThread`s
	---@type { [PID]: OSThread }
	osint.threadpool = {}
	osint.next_pid = 1
	osint.yield = coroutine.yield
	osint.resume = coroutine.resume
	
	--- Returns the PID of the running thread. If root is running, returns 0, nil
	---@return integer PID, OSThread? thread
	function thread.current_PID()
		local out = 0
		local out_thr = nil
		local running_thr, is_main = coroutine.running()
		if is_main then return 0, nil end
		for pid, thread in pairs(osint.threadpool) do
			if thread.thr == running_thr then
				out = pid
				out_thr = thread
				break
			end
		end
		return out, out_thr
	end
	
	--- Blocks the thread until an event occurs.
	---  @overload fun(filter: string)
	---  @overload fun(delay: number)
	---  @overload fun(filter: string, delay: number)
	---  @overload fun()
	function thread.poll_events(a, b)
		local delay = nil
		local filter = nil
		if type(a) == "string" then
			filter = a
		end
		if type(b) == "number" then
			delay = b
		elseif type(a) == "number" then
			delay = a
		end
		
		local startTime = computer.uptime()
		local out = {nil}
		local current_pid, current_thread = thread.current_PID()
		while current_thread do --Acts as a nil check.
			current_thread.state = "poll"
			osint.yield() --Kernel snatches state and trades it for info
			local ev = current_thread.cmdInfo
			current_thread.cmdInfo = {}
			if (type(ev[1]) == "string") and (type(filter) == "string") and (string.sub(ev[1],1, #filter) == filter) then
				out = ev
				break
			end
			if delay ~= nil and (computer.uptime() - startTime > delay) then
				break
			end
		end
		
		return table.unpack(out)
	end
	
	--- Listens for events and calls `callback` when an event is received.
	---@param filter string Set to `"*"` to accept any event.
	---@param callback fun(...:any): boolean? If the callback specifically returns `false` (NOT `nil`), immediately unregister this callback.
	function thread.listen_event(filter, callback)
		local current_pid, current_thread = thread.current_PID()
		current_thread.state = "+listener"
		current_thread.cmdInfo = {filter,callback}
		osint.yield()
	end
	
	--- Delays the thread, preventing errors and allowing other threads to work.
	function thread.rest()
		local current_pid, current_thread = thread.current_PID()
		current_thread.state = "rest"
		osint.yield()
	end
	
	--- Ends this thread's foreground activities; that is, only listeners and such will fire.
	function thread.background()
		local current_pid, current_thread = thread.current_PID()
		-- Using "bg" state is better than infinitely calling rest because rest is taxing to the kernel.
		current_thread.state = "bg"
		while true do
			osint.yield()
		end
	end
	
	--- Creates a new thread, returning its PID.
	---@param code function Code to run in another thread
	---@return integer PID, OSThread thread
	function thread.start(code)
		local pid = osint.next_pid
		osint.next_pid = osint.next_pid + 1
		osint.threadpool[pid] = {
			thr = coroutine.create(function()
				local success, result = xpcall(code, debug.traceback)
				if success then
					osint.threadpool[pid].state = "exit"
					for i,child_pid in ipairs(osint.threadpool[pid].children) do --Kill orphans
						osint.threadpool[child_pid].state = "exit"
					end
				else
					osint.threadpool[pid].state = "error"
					osint.threadpool[pid].cmdInfo = {result}
					for i,child_pid in ipairs(osint.threadpool[pid].children) do --Kill orphans
						osint.threadpool[child_pid].state = "exit"
					end
				end
			end),
			listens = {},
			state = "",
			cmdInfo = {},
			messages = {},
			children = {},
			parent = 0
		}
		local current_process_pid, current_process = thread.current_PID()
		if current_process_pid ~= 0 and current_process then
			table.insert(current_process.children,pid)
			osint.threadpool[pid].parent = current_process_pid
		end
		return pid, osint.threadpool[pid]
	end
	
	---@diagnostic disable-next-line: duplicate-set-field
	coroutine.yield = function(...)
		local pid, thr = thread.current_PID()
		if not thr then error("Thread has no threadpool entry.") end
		thr.state = "transmit_yield"
		thr.cmdInfo = {pid=thr.parent, data={...}}
		osint.yield() --resymer snatches data and swaps it out for its own.
		return table.unpack(thr.cmdInfo)
	end
	
	---@param thr PID|OSThread|thread
	---@param ... any
	---@return boolean success, any ...
	---@diagnostic disable-next-line: duplicate-set-field
	coroutine.resume = function(thr, ...)
		if type(thr) == "number" then --PID
			thr = osint.threadpool[thr]
		elseif type(thr) == "thread" then --thread
			local found = false
			for pid, osthr in pairs(osint.threadpool) do
				if osthr.thr == thr then
					thr = osthr
					found = true
					break
				end
			end
			if not found then
				error("Thread has no threadpool entry.")
			end
		end
		local output = {false}
		---@cast thr OSThread
		if thr.state == "transmit_yield" then
			thr.state = ""
			output = thr.cmdInfo.data
			thr.cmdInfo = {...}
			osint.resume(thr.thr)
		end
		
		return table.unpack(output)
	end
	
	_G.thread = thread
	
	-- coroutine.resume(cmdThr)
end

--Next: modular.lua--Previous:

do
	local screen = component.proxy(component.list("screen", true)())
	---@cast screen ScreenProxy
	local gpu = component.proxy(component.list("gpu", true)())
	---@cast gpu GPUProxy
	gpu.bind(screen.address)
	local w,h = gpu.getResolution()
	gpu.fill(1, 1, w, h, " ")
	gpu.setForeground(0xFFFFFF)
	
	local pid,thr = thread.start(function ()
		
		local data = module.import("/test.mod.lua")
		osctl.log(tostring(data))
		
		-- gpu.set(1,1,"Listening...")
		-- thread.listen_event("*", function (...)
		-- 	local ev = {...}
		-- 	gpu.set(1,1,table.concat(ev[1], ", "))
		-- end)
		-- gpu.set(1,2,"Polling...")
		-- while true do
		-- 	local start = computer.uptime()
		-- 	local ev = { thread.poll_events("key_", 2.0) }
		-- 	gpu.set(1,2,table.concat(ev, ", "))
		-- end
		-- thread.background()
	end)
	osint.resume(thr.thr)
end

--Next:--Previous: shell.lua

do
	--Final script. Start a shell and begin the kernel loop.
	return osint.kernel()
end

--Final script--Previous: os.lua

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
	---@return T
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

--Next: fs.luado
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
	local boot_order = read(boot_fs,"boot/boot_order")
	
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
endmodule.exports(
	"success!"
)