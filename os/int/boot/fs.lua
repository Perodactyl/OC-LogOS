--Previous: util.lua

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

--Next: dev.lua