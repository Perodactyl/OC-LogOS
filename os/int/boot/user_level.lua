--Previous: shell.lua

do
	--Final script. Start a shell and begin the kernel loop.
	
	osctl.reloadComponents()
	thread.start(loadfile("/bin/shell.lua") --[[@as function]], "User Level Shell"):begin()
	return osint.kernel()
end

--Final script