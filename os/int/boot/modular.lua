--Previous: thread.lua

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
			if fs.exists(target) or fs.exists(target..".lua") then
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
	
	---@deprecated Comes pre-deprecated! Use module.import
	_G.require = module.import
end

--Next: component.lua