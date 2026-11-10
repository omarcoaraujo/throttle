--// Types
export type scheduler = {
	now: () -> number,
	wait: (seconds: number) -> (),

	delay: (seconds: number, callback: (...any) -> (), ...any) -> (),
	defer: (callback: (...any) -> (), ...any) -> (),

	resume: (thread: thread, ...any) -> (),
	random: () -> number,
	on_close: (callback: () -> ()) -> (),
}

--// Functions
const function is_roblox()
	return typeof(game) == "Instance"
end

const function now()
	if is_roblox() then return time() end
	return os.clock()
end

const function wait(seconds: number)
	task.wait(seconds)
end

const function delay(seconds: number, callback: (...any) -> (), ...: any)
	task.delay(seconds, callback, ...)
end

const function defer(callback: (...any) -> (), ...: any)
	task.defer(callback, ...)
end

const function resume(thread: thread, ...: any)
	task.spawn(thread, ...)
end

const function on_close(callback: () -> ())
	if is_roblox() then game:BindToClose(callback) end
end

--// End
return table.freeze {
	now = now,
	wait = wait,

	delay = delay,
	defer = defer,

	resume = resume,
	random = math.random,
	on_close = on_close,
}
