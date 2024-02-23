do
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
end