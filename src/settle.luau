--// Modules
const scheduler = require "./scheduler"
const timers = require "./timers"

--// Types
export type settle_options = timers.timer_options
type call = { version: number, arguments: { n: number, [number]: any } }

--// Functions
const function fire(callback: (...any) -> (), waiting: { [any]: call }, key: any, version: number)
	const call = waiting[key]
	if not call or call.version ~= version then return end

	waiting[key] = nil
	callback(table.unpack(call.arguments, 1, call.arguments.n))
end

const function create<args...>(
	callback: (args...) -> (),
	interval: timers.interval<args...>,
	options: settle_options?
): (args...) -> ()
	timers.validate(interval)

	const waiting = {} :: { [any]: call }
	local counter = 0

	const function guarded(...: args...)
		counter += 1
		const key = timers.key_of(options, ...)

		waiting[key] = { version = counter, arguments = table.pack(...) }
		scheduler.current.delay(timers.seconds_of(interval, ...), fire, callback, waiting, key, counter)
	end

	return guarded
end

--// End
return table.freeze {
	create = create,
}
