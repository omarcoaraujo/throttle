--// Modules
const scheduler = require "@src/scheduler"

--// Types
type timer = { at: number, order: number, run: () -> () }

--// Variables
local clock = 0
local counter = 0
local roll = 0
const timers = {} :: { timer }

--// Functions
const function run_thread(callback: (...any) -> (), ...: any)
	const thread = coroutine.create(callback)
	const ok, message = coroutine.resume(thread, ...)
	if not ok then error(message, 0) end
end

const function resume(thread: thread, ...: any)
	const ok, message = coroutine.resume(thread, ...)
	if not ok then error(message, 0) end
end

const function schedule(seconds: number, run: () -> ())
	counter += 1
	table.insert(timers, { at = clock + seconds, order = counter, run = run })
end

const function now()
	return clock
end

const function delay(seconds: number, callback: (...any) -> (), ...: any)
	const packed = table.pack(...)

	const function run()
		run_thread(callback, table.unpack(packed, 1, packed.n))
	end

	schedule(seconds, run)
end

const function defer(callback: (...any) -> (), ...: any)
	delay(0, callback, ...)
end

const function wait(seconds: number)
	const thread = coroutine.running()

	const function wake()
		resume(thread)
	end

	schedule(seconds, wake)
	coroutine.yield()
end

const function random()
	return roll
end

const function on_close(callback: () -> ()) end

const function set_random(value: number)
	roll = value
end

const function earliest(limit: number)
	local best = nil :: timer?

	for _, timer in timers do
		if timer.at > limit then continue end
		if best == nil or timer.at < best.at or (timer.at == best.at and timer.order < best.order) then best = timer end
	end

	return best
end

const function advance(seconds: number)
	const limit = clock + seconds

	while true do
		const timer = earliest(limit)
		if not timer then break end

		table.remove(timers, table.find(timers, timer) :: number)
		clock = math.max(clock, timer.at)
		timer.run()
	end

	clock = limit
end

const function install()
	clock = 0
	counter = 0

	roll = 0
	table.clear(timers)

	scheduler.use {
		now = now,
		wait = wait,

		delay = delay,
		defer = defer,

		resume = resume,
		random = random,
		on_close = on_close,
	}
end

--// End
return table.freeze {
	install = install,
	advance = advance,

	spawn = run_thread,
	now = now,
	set_random = set_random,
}
