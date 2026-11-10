const budget = require "@src/budget"
const fake = require "./fake"
const spec = {} :: { [string]: any }

const function fails(callback: () -> any, expected: string)
	const success, message = pcall(callback)
	assert(not success, `expected an error containing "{expected}"`)
	assert(string.find(tostring(message), expected, 1, true), `wrong error: {message}`)
end

-- reserve
function spec.should_not_wait_while_the_budget_is_free()
	fake.install()
	const pool = budget.create(60)
	assert(budget.reserve(pool) == 0)
end

function spec.should_allow_a_burst_up_to_the_rate()
	fake.install()
	const pool = budget.create(3)

	assert(budget.reserve(pool) == 0)
	assert(budget.reserve(pool) == 0)

	assert(budget.reserve(pool) == 0)
	assert(budget.reserve(pool) == 60)
end

function spec.should_free_a_slot_a_minute_after_it_was_used()
	fake.install()
	const pool = budget.create(2)

	assert(budget.reserve(pool) == 0)
	assert(budget.reserve(pool) == 0)

	fake.advance(30)
	assert(budget.reserve(pool) == 30)
end

function spec.should_serve_who_asked_first_first()
	fake.install()
	const pool = budget.create(1)

	assert(budget.reserve(pool) == 0)
	assert(budget.reserve(pool) == 60)
	assert(budget.reserve(pool) == 120)
end

-- acquire
function spec.should_wait_on_acquire()
	fake.install()

	const pool = budget.create(1)
	local finished = false

	fake.spawn(function()
		budget.acquire(pool)
		budget.acquire(pool)
		finished = true
	end)

	fake.advance(59)
	assert(not finished)

	fake.advance(1)
	assert(finished)
	assert(fake.now() == 60)
end

-- rate
function spec.should_read_a_function_rate_on_every_use()
	fake.install()

	local current_rate = 1
	const pool = budget.create(function()
		return current_rate
	end)

	assert(budget.reserve(pool) == 0)
	current_rate = 3
	assert(budget.reserve(pool) == 0)
end

function spec.should_never_allow_less_than_one_per_minute()
	fake.install()
	const pool = budget.create(0.5)

	assert(budget.reserve(pool) == 0)
	assert(budget.reserve(pool) == 60)
end

function spec.should_reject_a_rate_that_is_not_positive()
	fails(function()
		return budget.create(0)
	end, "rate_per_minute must be")
end

return spec
