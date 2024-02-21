--Previous: shell.lua

do
	--Final script. Start a shell and begin the kernel loop.
	
	osctl.reloadComponents()
	for mnt,provider in pairs(osctl.fs.fsProviders) do
		osctl.log(mnt)
	end
	thread.start(loadfile("/bin/shell.lua") --[[@as function]])
	return osint.kernel()
end

--Final script