const settle = require "@src/settle"
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

-- settle
function spec.should_not_run_before_the_calls_stop()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1)

	act()
	fake.advance(0.5)
	assert(#calls == 0)
end

function spec.should_run_once_with_the_last_arguments()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1, { unkeyed = true })

	act(1)
	act(2)
	
	fake.advance(0.5)
	act(3)
	
	fake.advance(0.5)
	assert(#calls == 0)
	
	fake.advance(0.5)
	assert(#calls == 1)
	assert(calls[1][1] == 3)
end

function spec.should_restart_the_wait_on_each_call()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1)

	act()
	fake.advance(0.5)
	act()

	fake.advance(0.5)
	assert(#calls == 0)
	
	fake.advance(0.5)
	assert(#calls == 1)
end

function spec.should_keep_one_timer_per_first_argument()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1)

	act("a", 1)
	act("b", 2)

	fake.advance(1)
	assert(#calls == 2)
end

function spec.should_keep_a_single_timer_when_unkeyed()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1, { unkeyed = true })

	act(1)
	act(2)
	fake.advance(1)

	assert(#calls == 1)
	assert(calls[1][1] == 2)
end

function spec.should_run_again_after_settling()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1)

	act()
	fake.advance(1)
	act()

	fake.advance(1)
	assert(#calls == 2)
end

function spec.should_read_the_interval_from_a_function_with_the_arguments()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), function(wait: number)
		return wait
	end)

	act(2)
	fake.advance(1)
	assert(#calls == 0)

	fake.advance(1)
	assert(#calls == 1)
end

function spec.should_pass_nil_arguments()
	setup()
	
	const calls = {}
	const act = settle.create(recorder(calls), 1)

	act(nil, 5)
	fake.advance(1)
	
	assert(#calls == 1)
	assert(calls[1].n == 2)
	
	assert(calls[1][1] == nil)
	assert(calls[1][2] == 5)
end

function spec.should_reject_an_invalid_interval()
	setup()
	fails(function()
		return settle.create(recorder {}, -1)
	end, "throttle: interval")
end

return spec
