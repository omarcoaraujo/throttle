--// Modules
const scheduler = require "./scheduler"

--// Constants
const WINDOW_SECONDS = 60
const MINIMUM_LIMIT = 1
const INVALID_RATE = "throttle: rate_per_minute must be greater than zero"

--// Types
export type rate = number | () -> number
export type budget = { rate: rate, starts: { number }, last: number }

--// Functions
const function fail(message: string): never
	error(message, 0)
end

const function create(rate: rate): budget
	if type(rate) == "function" then return { rate = rate, starts = {}, last = 0 } end
	if rate <= 0 then return fail(INVALID_RATE) end

	return { rate = rate, starts = {}, last = 0 }
end

const function current_limit(budget: budget): number
	const rate = budget.rate
	const value = if type(rate) == "function" then rate() else rate
	return math.max(MINIMUM_LIMIT, math.floor(value))
end

const function forget_old(budget: budget, now: number)
	while #budget.starts > 0 and budget.starts[1] + WINDOW_SECONDS <= now do
		table.remove(budget.starts, 1)
	end
end

const function reserve(budget: budget)
	const now = scheduler.current.now()
	const limit = current_limit(budget)
	forget_old(budget, now)

	local start = math.max(now, budget.last)
	const count = #budget.starts

	if count >= limit then start = math.max(start, budget.starts[count - limit + 1] + WINDOW_SECONDS) end
	table.insert(budget.starts, start)

	budget.last = start
	return start - now
end

const function acquire(budget: budget)
	const delay = reserve(budget)
	if delay > 0 then scheduler.current.wait(delay) end
end

--// End
return table.freeze {
	create = create,
	reserve = reserve,
	acquire = acquire,
}
