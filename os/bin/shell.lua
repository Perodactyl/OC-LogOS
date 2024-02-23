do
	thread.start(loadfile("/bin/lua.lua") --[[@as function]], "cmd 'lua'"):begin()
	
	thread.background()
end