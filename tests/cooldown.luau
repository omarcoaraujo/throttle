const cooldown = require "@src/cooldown"
const fake = require "./fake"
const spec = {} :: { [string]: any }

const function fails(callback: () -> any, expected: string)
	const success, message = pcall(callback)
	assert(not success, `expected an error containing "{expected}"`)
	assert(string.find(tostring(message), expected, 1, true), `wrong error: {message}`)
end

const function setup()
	fake.install()
end

const function recorder(calls: { any })
	return function(...: any)
		table.insert(calls, table.pack(...))
	end
end

-- cooldown
function spec.should_run_the_first_call_at_once()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act()
	assert(#calls == 1)
end

function spec.should_ignore_calls_within_the_interval()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act()
	act()

	act()
	assert(#calls == 1)
end

function spec.should_run_again_after_the_interval()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act()
	fake.advance(1)

	act()
	assert(#calls == 2)
end

function spec.should_count_the_interval_from_the_last_call_that_went_through()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act()
	fake.advance(0.5)

	act()
	fake.advance(0.5)

	act()
	assert(#calls == 2)
end

function spec.should_keep_one_timer_per_first_argument()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act "p1"
	act "p2"
	act "p1"

	assert(#calls == 2)
end

function spec.should_keep_a_single_timer_when_unkeyed()
	setup()
	const calls = {}
	const act = cooldown.create(recorder(calls), 1, { unkeyed = true })

	act(10)
	act(25)

	assert(#calls == 1)
	assert(calls[1][1] == 10)
end

function spec.should_read_the_interval_from_a_function_with_the_arguments()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), function(name: string)
		return if name == "slow" then 10 else 1
	end)

	act "slow"
	assert(#calls == 1)
	fake.advance(1)

	act "slow"
	assert(#calls == 1)

	act "fast"
	assert(#calls == 2)

	fake.advance(1)
	act "fast"
	assert(#calls == 3)
end

function spec.should_pass_every_argument_to_the_callback()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act(1, 2, 3)
	assert(calls[1].n == 3)
	assert(calls[1][1] == 1)

	assert(calls[1][2] == 2)
	assert(calls[1][3] == 3)
end

function spec.should_work_with_no_arguments()
	setup()

	const calls = {}
	const act = cooldown.create(recorder(calls), 1)

	act()
	act()
	assert(#calls == 1)
end

function spec.should_reject_an_invalid_interval()
	setup()
	fails(function()
		return cooldown.create(recorder {}, -1)
	end, "throttle: interval")
end

return spec
