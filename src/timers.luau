--// Constants
const ANY_CALL = table.freeze {}
const NO_ARGUMENT = table.freeze {}
const INVALID_INTERVAL = "throttle: interval must not be negative"

--// Types
export type interval<args...> = number | (args...) -> number
export type timer_options = { unkeyed: boolean? }

--// Functions
const function validate<args...>(interval: interval<args...>)
	if type(interval) == "function" then return end
	if interval < 0 then error(INVALID_INTERVAL, 0) end
end

const function key_of(options: timer_options?, ...: any): any
	if options and options.unkeyed then return ANY_CALL end
	const first = ...

	if first == nil then return NO_ARGUMENT end
	return first
end

const function seconds_of<args...>(interval: interval<args...>, ...: args...): number
	if type(interval) == "function" then return interval(...) end
	return interval
end

--// End
return table.freeze {
	validate = validate,
	key_of = key_of,
	seconds_of = seconds_of,
}
