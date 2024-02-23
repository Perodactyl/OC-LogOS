---@alias Stream ReadStream | WriteStream | DuplexStream

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
end