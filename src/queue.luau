--// Modules
const budget = require "./budget"
const scheduler = require "./scheduler"

--// Constants
const DEFAULT_ATTEMPTS = 3
const BASE_BACKOFF = 1

const MAX_BACKOFF = 30
const JITTER = 0.25

const SHUTDOWN_SECONDS = 25
const SHUTDOWN_POLL = 0.1

const DROPPED = "dropped"
const CLOSED = "closed"

const SOURCE_REQUIRED = "throttle: give budget or rate_per_minute"
const SOURCE_EXCLUSIVE = "throttle: give budget or rate_per_minute, not both"

const ATTEMPTS_INVALID = "throttle: max_attempts must be a whole number of at least 1"
const SIZE_INVALID = "throttle: max_size must be a whole number of at least 1"

--// Types
export type queue_options<payload> = {
	handler: (payload: payload, key: string?) -> ...any,
	budget: budget.budget?,

	rate_per_minute: budget.rate?,
	max_attempts: number?,
	max_size: number?,
}

export type send_options<payload> = {
	payload: payload,
	key: string?,
	await: boolean?,
}

export type send<payload> = (request: send_options<payload>) -> (boolean?, any)
type entry = { payload: any, key: string?, waiters: { thread } }

type state = {
	handler: (any, string?) -> ...any,
	pool: budget.budget,

	max_attempts: number,
	max_size: number?,

	entries: { entry },
	by_key: { [string]: entry },

	busy: boolean,
	closed: boolean,
}

--// Variables
const open_queues = {} :: { [state]: boolean }

--// Functions
const function fail(message: string): never
	error(message, 0)
end

const function is_whole(value: any, minimum: number)
	return type(value) == "number" and value >= minimum and value % 1 == 0
end

const function check_options(options: queue_options<any>)
	if options.max_attempts ~= nil and not is_whole(options.max_attempts, 1) then fail(ATTEMPTS_INVALID) end
	if options.max_size ~= nil and not is_whole(options.max_size, 1) then fail(SIZE_INVALID) end
end

const function pick_pool(options: queue_options<any>): budget.budget
	const shared = options.budget
	const own_rate = options.rate_per_minute

	if shared and own_rate ~= nil then return fail(SOURCE_EXCLUSIVE) end
	if shared then return shared end

	if own_rate == nil then return fail(SOURCE_REQUIRED) end
	return budget.create(own_rate)
end

const function release_key(state: state, entry: entry)
	const key = entry.key
	if key and state.by_key[key] == entry then state.by_key[key] = nil end
end

const function finish(entry: entry, ok: boolean, value: any)
	for _, thread in entry.waiters do
		scheduler.current.resume(thread, ok, value)
	end
end

const function trim(state: state)
	const max_size = state.max_size
	if not max_size then return end

	while #state.entries > max_size do
		const oldest = table.remove(state.entries, 1) :: entry
		release_key(state, oldest)
		finish(oldest, false, DROPPED)
	end
end

const function enqueue(state: state, request: send_options<any>): entry
	const key = request.key
	const existing = if key then state.by_key[key] else nil

	if existing then
		existing.payload = request.payload
		return existing
	end

	const entry = { payload = request.payload, key = key, waiters = {} } :: entry
	table.insert(state.entries, entry)
	if key then state.by_key[key] = entry end

	trim(state)
	return entry
end

const function backoff_seconds(failures: number)
	const base = math.min(MAX_BACKOFF, BASE_BACKOFF * 2 ^ (failures - 1))
	return math.min(MAX_BACKOFF, base * (1 + JITTER * scheduler.current.random()))
end

const function deliver(state: state, entry: entry)
	local failure = nil :: any

	for attempt = 1, state.max_attempts do
		budget.acquire(state.pool)
		const ok, result = pcall(state.handler, entry.payload, entry.key)

		if ok then
			finish(entry, true, result)
			return nil
		end

		failure = result
		if attempt < state.max_attempts then scheduler.current.wait(backoff_seconds(attempt)) end
	end

	finish(entry, false, failure)
	return nil
end

const function drain(state: state)
	while #state.entries > 0 do
		const entry = table.remove(state.entries, 1) :: entry
		release_key(state, entry)

		const ok, failure = pcall(deliver, state, entry)
		if not ok then finish(entry, false, failure) end
	end

	state.busy = false
end

const function wake(state: state)
	if state.busy then return end
	state.busy = true
	scheduler.current.defer(drain, state)
end

const function create<payload>(options: queue_options<payload>): send<payload>
	check_options(options)
	const state = {
		handler = options.handler,
		pool = pick_pool(options),

		max_attempts = options.max_attempts or DEFAULT_ATTEMPTS,
		max_size = options.max_size,

		entries = {},
		by_key = {},

		busy = false,
		closed = false,
	} :: state

	open_queues[state] = true
	return function(request: send_options<payload>)
		if state.closed then
			if request.await then return false, CLOSED end
			return nil, nil
		end

		const entry = enqueue(state, request)
		if request.await then table.insert(entry.waiters, coroutine.running()) end

		wake(state)
		if request.await then return coroutine.yield() end
		return nil, nil
	end
end

const function is_pending()
	for state in open_queues do
		if state.busy or #state.entries > 0 then return true end
	end

	return false
end

const function shutdown(seconds: number)
	const deadline = scheduler.current.now() + seconds

	for state in open_queues do
		state.closed = true
	end

	while is_pending() and scheduler.current.now() < deadline do
		scheduler.current.wait(SHUTDOWN_POLL)
	end
end

const function close()
	shutdown(SHUTDOWN_SECONDS)
end

const function reset()
	table.clear(open_queues)
end

--// Listeners
scheduler.current.on_close(close)

--// End
return table.freeze {
	create = create,
	shutdown = shutdown,
	reset = reset,
}
