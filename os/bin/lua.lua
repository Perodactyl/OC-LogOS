do
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
end