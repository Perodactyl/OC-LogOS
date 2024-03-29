  π$  int/boot/fs.lua }'  !  int/boot/thread.lua H    int/lib/stream.lua $)a  ¬  int/component.d/90_tty.lua Υm  	  int/boot/util.lua Φv  >  int/boot/os.lua ~    int/boot/modular.lua       int/boot/component.lua ₯     init.lua ₯  B  int/boot/dev.lua η  +  lib/bit32.lua (  ͺ  int/component.d/99_default.lua Ό  κ  int/lib/tty.lua ¦  Σ  bin/lua.lua !y  σ   int/boot/user_level.lua l  Ψ   mount.lua D  ’   int/boot/boot_order  ζ     int/lib/dictionary.lua u   m   bin/shell.lua β   9   bin/art.lua ‘     lib/utils.lua 6‘     usr/dir.tag &7‘      int/dictionary.d/machine.lua 7‘      int/lib/buffer.lua  --Previous: util.lua

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
---  
---  @field read fun(self, count:integer): string|nil Reads up to the specified amount of data from an open file. Returns nil when EOF is reached.
---  @field write fun(self,value:string): boolean Writes the specified data to an open file descriptor with the specified handle.
---  @field seek fun(self,whence:string,offset:number): number Seeks in an open file descriptor with the specified handle. Returns the new pointer position.
---  @field close fun(self) Closes an open file descriptor with the specified handle.
---  @field readAll fun(self): string|nil Reads the entire file and closes it. Useful inline.
---  @field readRaw fun(self, count:integer): string|nil Reads up to the specified amount (like read), but does not auto-buffer.

local file_mt = {
	__index={
		---@param self File
		---@param count number
		read= function(self, count)
			local out = ""
			local bytesRead = 0
			while bytesRead < count do
				local result = self:readRaw(count-bytesRead)
				if result == nil then
					break
				end
				bytesRead = bytesRead + #result
				out = out .. result
			end
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
		end,
		readRaw= function(self, count)
			return self._PROVIDER.read(self._HANDLE, count)
		end
	}
}

do
	local fs = {}
	osctl.fs = {
		--- Returns a StdFSProvider for any component filesystem.
		---@param addr ID
		---@return StdFSProvider
		physicalFS= function(addr)
			if type(addr) ~= "string" then
				error(string.format("PhysicalFS: Failed to mount %s: addr is not of type string (it is %s)", addr, type(addr)))
			end
			if hardware.type(addr) ~= "filesystem" then
				error(string.format("PhysicalFS: Failed to mount %s: component is of type %s, not filesystem.", addr, hardware.type(addr)))
			end
			---@type StdFSProvider
			---@diagnostic disable-next-line: assign-type-mismatch
			local output = hardware.proxy(addr)
			output._PROVIDER="PhysicalFS: " .. addr
			output._VERSION=1.0
			output._FEATURES="std"
			
			return output
		end
	}
	
	---@type FSProvider[]
	osint.fsProviders = {}
	
	--- Mounts any FSProvider at the specified path.
	---@param path string
	---@param provider FSProvider
	function osctl.fs.mount(path, provider)
		osint.fsProviders[fs.canonicalize(path)] = provider
	end
	
	--- Returns a list of segments of a path.
	---@param path string
	---@return string[]
	function fs.segments(path)
		local out = osint.utils.split_p(path, "%/+")
		return out
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
			for j,part in ipairs(fs.segments(path)) do
				table.insert(segments, part)
			end
		end
		return fs.joinSegments(table.unpack(segments))
	end
	--- Creates the canon (unique, correct) form of a path
	---@param path string
	---@return string
	function fs.canonicalize(path)
		return fs.joinSegments(table.unpack(fs.segments(path)))
	end
	
	---@param path string
	---@param throw? boolean If `true`, function is fallible but return value is certain.
	---@return FSProvider?,string
	local function locateProvider(path, throw)
		if not path then
			error("Cannot locate a nil path!")
		end
		path = fs.canonicalize(path)
		local segments = fs.segments(path) --NOTE this is currently redundant.
		
		if #segments == 0 then
			if osint.utils.contains_k(osint.fsProviders, "/") then
				return osint.fsProviders["/"], path
			else
				if throw == true then
					error(string.format("Short-circuit provider not found / nothing mounted to \"/\".\nProviders:\n%s",table.concat(osint.utils.keys(osint.fsProviders),"\n")))
				end
				return nil, "not found"
			end
		end
		
		for i = #segments, 0, -1 do
			local provider_path = fs.joinSegments(table.unpack(segments, 1, i))
			local provided_path = fs.joinSegments(table.unpack(segments, i+1))
			local found, provider = osint.utils.contains_k(osint.fsProviders, provider_path)
			if found then
				return provider,provided_path
			end
		end
		if throw == true then
			error(string.format("No FS provider for %s\nProviders:\n%s", path, table.concat(osint.utils.keys(osint.fsProviders),"\n")))
		end
		return nil,"not found"
	end
	
	--- Opens a file and returns a proxy to its further methods.
	---@param path string
	---@param mode FSHandleMode
	---@return File
	function fs.open(path, mode)
		local provider, providedPath = locateProvider(path, true)
		---@cast provider -?
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
		local provider, providedPath = locateProvider(path, true)
		---@cast provider -?
		return provider.exists(providedPath)
	end
	
	function fs.list(path)
		local provider, providedPath = locateProvider(path, true)
		---@cast provider -?
		return provider.list(providedPath)
	end
	
	function osctl.fs.loadMountFile()
		local old_providers = osint.fsProviders
		osint.fsProviders = {}
		osctl.fs.mount("/", osctl.fs.physicalFS(osint.boot_fs.address))
		local script = loadfile("mount.lua") --[[@as function]] --infallible, but vscode don't understand my override of loadfile.
		
		osint.fsProviders = {}
		local success, message = xpcall(script, debug.traceback)
		if not success then
			osint.fsProviders = old_providers
			error(message)
		end
	end
	
	_G.loadfile, _G.dofile = osint.impl_file_exec(fs)
	osctl.fs.loadMountFile()
	
	_G.fs = fs
end

--Next: dev.lua--Previous: dev.lua

---@alias OSThreadState "rest" | "exit" | "error" | "poll" | "+listener" | "bg" | "transmit" | "transmit_yield" | "recieve" | "unstarted" | ""
---@alias PID integer

---@class OSThread
---  @field state OSThreadState State of the thread, used by the kernel.
---  @field cmdInfo table Information passed between thread and kernel. Bidirectional.
---  @field parent PID Thread that spawned this.
---  @field children PID[] Threads spawned by this.
---  @field thr thread Underlying lua thread.
---  @field messages any[] Messages received asynchronously from other threads.
---  @field listens (fun(...):boolean?)[] Listeners placed by thread.listen_event
---  @field info string
---  
---  @field begin fun(self: OSThread) Begins a thread if it hasn't started yet.

local thread_mt = {
	__index={
		---@param self OSThread
		begin=function(self)
			if self.state == "unstarted" then
				self.state = ""
				osint.resume(self.thr)
			end
			return self
		end
	}
}

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
						osctl.log(string.format("#%s (%s) exiting...", pid, target.info))
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
					target.listens["*"](table.unpack(ev))
				end
				if osint.utils.contains_k(target.listens, ev[1]) then
					target.listens[ev[1]](table.unpack(ev))
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
	
	--- Ends this thread's foreground activities. Listeners will fire and children will keep running.
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
	---@param info? string Info about a thread, usually a name
	---@return OSThread thread
	function thread.start(code, info)
		if info == nil then
			info = "unknown"
		end
		local pid = osint.next_pid
		osint.next_pid = osint.next_pid + 1
		osint.threadpool[pid] = setmetatable({
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
			state = "unstarted",
			cmdInfo = {},
			messages = {},
			children = {},
			parent = 0,
			pid = pid,
			info = info,
		}, thread_mt)
		local current_process_pid, current_process = thread.current_PID()
		if current_process_pid ~= 0 and current_process then
			table.insert(current_process.children,pid)
			osint.threadpool[pid].parent = current_process_pid
		end
		return osint.threadpool[pid]
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

--Next: modular.lua---@alias Stream ReadStream | WriteStream | DuplexStream

---@alias StreamType "r" | "w" | "rw" | "-r" | "-rw"

---Base class for all streams.
---@class StreamBase
---  @field type StreamType

---Read-only stream
---@class ReadStream: StreamBase
---  @field type "r"
---  Receive data from this stream. If #data < len, call read again.
---  @field read fun(len: integer): string

---Read-only stream that uses a callback
---@class AsyncReadStream: StreamBase
---  @field type "-r"
---  Register a callback to be called when data is available. <br />
---  `onData` and `onceData` callbacks may be called in an arbitrary order.
---  @field onData fun(callback: fun(data: string))
---  Removes a previously added callback.
---  @field offData fun(callback: fun(data: string))
---  Register a one-time callback to be called when data is available. <br />
---  `onData` and `onceData` callbacks may be called in an arbitrary order.
---  @field onceData fun(callback: fun(data: string))

---Write-only stream
---@class WriteStream: StreamBase
---  @field type "w"
---  Send data to this stream. Returns how many bytes were written. If len < #data, call write again.
---  @field write fun(data: string): integer

---Bidirectional (duplex) stream
---@class DuplexStream: ReadStream,WriteStream
---  @field type "rw"

---Bidirectional (duplex) stream, uses a callback to read
---@class AsyncDuplexStream: AsyncReadStream,WriteStream
---  @field type "-rw"

do
	local stream = {}
	
	--- Creates a `ReadStream`. Returns the left (Readable) side and right (Writable) side. <br />
	--- Internally, this creates a buffer that is completely free to grow. It is recommended to use `stream.createAsyncReadStream()`.
	---@return ReadStream left, WriteStream right
	function stream.createReadStream()
		local buffer = {}
		
		local writer = {type="w"}
		function writer.write(data)
			table.insert(buffer, data)
			return #data
		end
		local reader = {type="r"}
		function reader.read(len)
			if #buffer > 0 then
				return table.remove(buffer, 1)
			end
			return ""
		end
		
		local function stop()
			buffer = nil
			writer.write = function(...) return 0 end
			reader.read = function(...) return nil end
		end
		
		setmetatable(reader, {
			__gc= stop,
			__close= stop,
		})
		setmetatable(writer, {
			__gc= stop,
			__close= stop,
		})
		
		return reader, writer
	end
	
	--- Creates an `AsyncReadStream`. Returns the left (Readable) side and right (Writable) side. <br />
	--- If nothing is listening when data is written, the data is lost.
	---@return AsyncReadStream left, WriteStream right
	function stream.createAsyncReadStream()
		local callbacks = {}
		local once = {}
		local writer = {type="w"}
		function writer.write(data)
			for i,cb in ipairs(once) do
				cb(data)
			end
			once = {}
			for i,cb in ipairs(callbacks) do
				cb(data)
			end
			return #data
		end
		local reader = {type="-r"}
		function reader.onData(cb)
			table.insert(callbacks, cb)
		end
		function reader.offData(cb)
			local idx = nil
			for i,fn in ipairs(callbacks) do
				if cb == fn then
					idx = i
					break
				end
			end
			if idx then
				table.remove(callbacks, idx)
			end
		end
		function reader.onceData(cb)
			table.insert(once, cb)
		end
		
		return reader, writer
	end
	
	--- Creates a `DuplexStream`. Returns both sides, which are cross-wired. Uses internal buffers.
	--- @see ReadStream
	--- @see WriteStream
	---@return DuplexStream, DuplexStream
	function stream.createDuplexStream()
		local inboxA, inboxB = {},{}
		
		local readerA, writerA = stream.createAsyncReadStream()
		local readerB, writerB = stream.createAsyncReadStream()
		readerA.onData(function(msg) table.insert(inboxB, msg) end)
		readerB.onData(function(msg) table.insert(inboxA, msg) end)
		
		local duplexA = {table.unpack(writerA)}
		function duplexA.read(len)
			if #inboxA > 0 then
				return table.remove(inboxA, 1)
			end
			return ""
		end
		duplexA.type = "rw"
		
		local duplexB = {table.unpack(writerB)}
		function duplexB.read(len)
			if #inboxB > 0 then
				return table.remove(inboxB, 1)
			end
			return ""
		end
		duplexB.type = "rw"
		
		return duplexA, duplexB
	end
	
	--- Creates an `AsyncDuplexStream`. Returns both sides, which are cross-wired.
	--- @see AsyncReadStream
	--- @see WriteStream
	---@return AsyncDuplexStream, AsyncDuplexStream
	function stream.createAsyncDuplexStream()
		local readerA, writerA = stream.createAsyncReadStream()
		local readerB, writerB = stream.createAsyncReadStream()
		readerA.onData(writerB.write)
		readerB.onData(writerA.write)
		
		local duplexA = {table.unpack(readerA), table.unpack(writerA)}
		duplexA.type = "-rw"
		
		local duplexB = {table.unpack(readerB), table.unpack(writerB)}
		duplexB.type = "-rw"
		
		return duplexA, duplexB
	end
	
	--- Inverse of `stream.createReadStream`.
	---@return WriteStream left, ReadStream right
	function stream.createWriteStream()
		local reader, writer = stream.createReadStream()
		return writer, reader
	end
	
	--- Inverse of `stream.createAsyncReadStream`. There is no such thing as an `AsyncWriteStream`.
	---@return WriteStream left, AsyncReadStream right
	function stream.createAsyncWriteStream()
		local reader, writer = stream.createAsyncReadStream()
		return writer, reader
	end
	
	--- Opens a file as a ReadStream.
	---@param path string Path to open.
	---@return ReadStream
	function stream.readFile(path)
		local handle = fs.open(path, "r")
		
		local reader = {type= "r"}
		function reader.read(len)
			if not handle then return nil end
			local out = handle:readRaw(len)
			if out == nil then
				handle:close()
			end
			return out
		end
		
		setmetatable(reader, {
			__call=function() reader.read(math.huge) end,
			__gc=function() handle:close() end,
			__close=function() handle:close() end,
		})
		
		return reader
	end
	
	--- Opens a file as a WriteStream.
	---@param path string Path to open.
	---@return WriteStream
	function stream.writeFile(path)
		local handle = fs.open(path, "w")
		
		local reader, writer = stream.createAsyncDuplexStream()
		
		reader.onData(function(data)
			handle: write(data)
		end)
		
		setmetatable(writer, {
			table.unpack(getmetatable(writer)),
			__gc=function() handle:close() end,
			__close=function() handle:close() end,
		})
		
		return writer
	end
	
	module.exports(stream)
endlocal stream = module.import("stream")
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
		
		while true do
			local changed = false
			if insert_val ~= nil and insert_location ~= nil then
				table.insert(lines, insert_location, insert_val)
			end
			local offset = x
			for i,line in ipairs(lines) do --Gradually smooth out the lines until they all individually fit.
				local doublebreak = false
				for j = 1,unicode.len(line) do
					local char = unicode.sub(line,j,j)
					offset = offset + unicode.charWidth(char)
					if offset > max_w then
						-- offset = offset - 1 --unicode.charWidth(char)
						offset = 1
						doublebreak = true
						changed = true
						lines[i] = unicode.sub(line,1,j)
						insert_val = unicode.sub(line,j+1)
						insert_location = i+1
						break
					end
				end
				if doublebreak then
					doublebreak = false
					break
				end
				-- if unicode.wlen(line) > max_w then
				-- 	changed = true
				-- 	lines[i] = unicode.sub(line,1,max_w)
				-- 	insert_val = unicode.sub(line,max_w+1)
				-- 	insert_location = i+1
				-- 	break
				-- end
			end
			if not changed then
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
	tty.stdout.write("Hello, Worldβ’ Ya like jazzπ\nπππππππππππππππππππππ")
	
	found_components["tty0"] = tty
end--Previous: os.lua

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

--Next: fs.lua--Beginning of boot chain

do
	_G._OS = "LogOS"
	_G._OS_VERSION = 0.0
	local osctl = {}
	--- OS Control
	_G.osctl = osctl
	
	local osint = {}
	osint.component = component
	_G.hardware = component
	--- OS Internals (used by boot scripts and such)
	_G.osint = osint
	
	local boot_fs = component.proxy(computer.getBootAddress())
	local file = nil
	---@cast boot_fs FilesystemProxy
	if not boot_fs.isReadOnly() then
		file = boot_fs.open("logos.log", "w")
		boot_fs.write(file,"OS log file beginning")
	end
	
	osint.boot_fs = boot_fs
	
	function osctl.log(...)
		if file ~= nil and not boot_fs.isReadOnly() then
			boot_fs.write(file, string.format("(%s) %s", computer.uptime(), table.concat({...}," ")))
		end
		local addr = hardware.list("ocelot", true)()
		local success = pcall(hardware.invoke,addr,"log",...)
		return success
	end
	
	osctl.log("Booting...")
	
	_G.void = {
		__metatable="void",
		__name= "void",
		
		__index=function(key)
			return nil
		end,
		__newindex=function(...) end,
		__eq=function(self, other)
			if other == false then return true end
			if getmetatable(other) == "void" then
				return true
			end
		end
	}
	
	function osint.impl_file_exec(fs)
		--- Mode does nothing. Doesn't load from stdin. This implementation is fallible, but reliable if unhandled.
		---@param filename string
		---@param mode any
		---@param env table?
		---@return function
		local function loadfile(filename, mode, env)
			local code = fs.open(filename, "r"):readAll()
			if code == nil then
				error("Failed to read "..filename)
			end
			local exe, err = load(code, "="..filename, mode, env)
			if not exe or err then
				error(err)
			end
			return exe
		end
		
		local function dofile(filename)
			return loadfile(filename)()
		end
		
		return loadfile, dofile
	end
	_G.loadfile, _G.dofile = osint.impl_file_exec(boot_fs)
end

--Next: util.lua--Previous: thread.lua

do
	local module = {}
	
	module.paths = {
		"%s",
		"/int/lib/%s",
		"/lib/%s",
		"/pkg/lib/%s",
	}
	
	function module.pathOf(modulePath)
		for i,template in ipairs(module.paths) do
			local target = string.format(template, modulePath)
			if fs.exists(target) then
				return target
			end
			if fs.exists(target..".lua") then
				return target..".lua"
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
		local thr = thread.start(function()
			local success, reason = xpcall(exe, debug.traceback)
			if not success then
				error(string.format("Import: Module %s crashed: %s", target, reason))
			end
		end, string.format("Module %s", target)):begin()
		
		local data = {coroutine.resume(thr)}
		if data[1] == "module_export" then
			return table.unpack(data, 2)
		end
	end
	
	---@generic T
	---@param ... T
	---@return T
	function module.exports(...)
		coroutine.yield("module_export", ...)
		return ...
	end
	
	_G.module = module
	
	---@deprecated Comes pre-deprecated! Use module.import.
	---@see module.import
	_G.require = module.import
end

--Next: component.lua--Previous: modular.lua

---@alias OSComponent _

---@class OSComponentAPI
---  @field get fun(addr: string): OSComponent
---  @field list fun(filter?: string, exact?: boolean): ... Returns a list matching component addresses. 

do
	
	local component = {}
	---@type OSComponentAPI
	_G.component = component
	
	local found_components = {}
	
	function component.get(addr)
		return found_components[addr]
	end
	
	---Returns a list of matching components.
	---@param filter? string
	---@param exact? boolean
	---@return ID ...
	function component.list(filter, exact)
		local out = {}
		for addr,comp in pairs(found_components) do
			if (not filter) or (comp.type == filter) or (not exact and string.sub(comp.type, 1, #filter) == filter) then
				table.insert(out, addr)
			end
		end
		
		return table.unpack(out)
	end
	
	function osctl.reloadComponents()
		found_components = {}
		local files = fs.list("/int/component.d")
		table.sort(files)
		for i,file in ipairs(files) do
			local finalpath = fs.join("/int/component.d",file)
			local success, result = xpcall(function()
				loadfile(finalpath)()(found_components)
			end, debug.traceback)
			if not success then
				osctl.log(string.format("Component driver %s crashed:\n%s",file,result))
			end
		end
	end
end

--Next: user_level.luado
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
end--Previous: fs.lua

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

--Next: thread.lua-- Implementation of bit32, for consistency.
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
endlocal utils = module.import("utils")

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
enddo
	local stream = module.import("stream")
	
	local tty = {}
	
	---@type AsyncReadStream, WriteStream
	local stdinReader, stdinWriter = stream.createAsyncReadStream()
	---@type AsyncReadStream, WriteStream
	local stdoutReader, stdoutWriter = stream.createAsyncReadStream()
	---@type AsyncReadStream, WriteStream
	local stderrReader, stderrWriter = stream.createAsyncReadStream()
	
	tty.stdin = stdinReader
	tty.stdout = stdoutWriter
	tty.stderr = stderrWriter
	
	
	
	module.exports(tty)
enddo
	thread.listen_event("ocelot_message", function (_,id,message)
		local code, why = load(message)
		if not code then
			local code2 = load("return "..message)
			if code2 then
				code = code2
			end
		end
		if not code then --error
			osctl.log(why)
		else
			local output = { xpcall(code, debug.traceback) }
			if output[1] == true then
				osctl.log(table.unpack(output,2))
			else --error
				osctl.log(output[2])
			end
		end
	end)
	
	
	thread.background()
end--Previous: shell.lua

do
	--Final script. Start a shell and begin the kernel loop.
	
	osctl.reloadComponents()
	thread.start(loadfile("/bin/shell.lua") --[[@as function]], "User Level Shell"):begin()
	return osint.kernel()
end

--Final scriptosctl.fs.mount("/", osctl.fs.physicalFS(computer.getBootAddress()))

for addr in osint.component.list("filesystem", true) do
	osctl.fs.mount("/mnt/"..osint.utils.split_p(addr, "%-")[1], osctl.fs.physicalFS(addr))
end/int/boot/os.lua
/int/boot/util.lua
/int/boot/fs.lua
/int/boot/dev.lua
/int/boot/thread.lua
/int/boot/modular.lua
/int/boot/component.lua
/int/boot/user_level.lua---A magical way of finding out about things!
local dictionary = {
	data= {},
}

function dictionary.reload()
	
end

module.exports(dictionary)do
	thread.start(loadfile("/bin/lua.lua") --[[@as function]], "cmd 'lua'"):begin()
	
	thread.background()
end--package manager goes here
--ART: Automatic Routine Treemodule.exports(osint.utils)@