--Previous: dev.lua

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

--Next: modular.lua