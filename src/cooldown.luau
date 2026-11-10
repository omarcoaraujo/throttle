--// Modules
const scheduler = require "./scheduler"
const timers = require "./timers"

--// Types
export type cooldown_options = timers.timer_options

--// Functions
const function forget(expiries: { [any]: number }, key: any, expiry: number)
	if expiries[key] == expiry then expiries[key] = nil end
end

const function create<args...>(
	callback: (args...) -> (),
	interval: timers.interval<args...>,
	options: cooldown_options?
): (args...) -> ()
	timers.validate(interval)
	const expiries = {} :: { [any]: number }

	const function guarded(...: args...)
		const now = scheduler.current.now()
		const key = timers.key_of(options, ...)

		const expiry = expiries[key]
		if expiry and now < expiry then return end

		const seconds = timers.seconds_of(interval, ...)
		const next_expiry = now + seconds

		expiries[key] = next_expiry
		scheduler.current.delay(seconds, forget, expiries, key, next_expiry)
		callback(...)
	end

	return guarded
end

--// End
return table.freeze {
	create = create,
}
