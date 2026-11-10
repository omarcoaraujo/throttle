const queue = require "@src/queue"
const budget = require "@src/budget"
const scheduler = require "@src/scheduler"
const fake = require "./fake"
const spec = {} :: { [string]: any }

const function fails(callback: () -> any, expected: string)
	const success, message = pcall(callback)
	assert(not success, `expected an error containing "{expected}"`)
	assert(string.find(tostring(message), expected, 1, true), `wrong error: {message}`)
end

const function setup()
	fake.install()
	queue.reset()
end

const function recorder(calls: { any })
	const function handle(payload: any)
		table.insert(calls, payload)
		return `done:{payload}`
	end

	return handle
end

-- send
function spec.should_return_nothing_without_await()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }

	assert(send { payload = "a" } == nil)
	assert(#calls == 0)
	
	fake.advance(0)
	assert(#calls == 1)
	assert(calls[1] == "a")
end

function spec.should_return_ok_and_result_with_await()
	setup()
	
	const send = queue.create { handler = recorder {}, rate_per_minute = 60 }
	local ok: boolean? = nil
	local result: any = nil

	fake.spawn(function()
		ok, result = send { payload = 2, await = true }
	end)

	fake.advance(0)
	assert(ok == true)
	assert(result == "done:2")
end

function spec.should_pass_the_key_to_the_handler()
	setup()
	
	local seen: string? = nil
	const send = queue.create {
		handler = function(payload: any, key: string?)
			seen = key
		end,
		rate_per_minute = 60,
	}

	send { payload = 1, key = "k" }
	fake.advance(0)
	assert(seen == "k")
end

-- order and budget
function spec.should_send_in_arrival_order()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }

	send { payload = "a" }
	send { payload = "b" }
	send { payload = "c" }
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "a,b,c")
end

function spec.should_respect_the_rate_of_the_queue()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 2 }

	send { payload = 1 }
	send { payload = 2 }
	send { payload = 3 }
	
	fake.advance(0)
	assert(#calls == 2)
	
	fake.advance(59)
	assert(#calls == 2)
	
	fake.advance(1)
	assert(#calls == 3)
end

function spec.should_share_a_budget_between_queues()
	setup()
	
	const pool = budget.create(1)
	const calls = {}

	const first = queue.create {
		handler = function()
			table.insert(calls, "one")
		end,
		budget = pool,
	}

	const second = queue.create {
		handler = function()
			table.insert(calls, "two")
		end,
		budget = pool,
	}

	first { payload = 1 }
	second { payload = 2 }
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "one")
	
	fake.advance(60)
	assert(table.concat(calls, ",") == "one,two")
end

-- retry
function spec.should_retry_with_exponential_backoff()
	setup()
	fake.set_random(0)
	
	local attempts = 0
	const send = queue.create {
		handler = function()
			attempts += 1
			if attempts < 3 then error("boom", 0) end
			return "ok"
		end,
		max_attempts = 3,
		rate_per_minute = 60,
	}

	local ok: boolean? = nil
	local result: any = nil
	
	fake.spawn(function()
		ok, result = send { payload = 1, await = true }
	end)

	fake.advance(0)
	assert(attempts == 1)
	
	fake.advance(0.5)
	assert(attempts == 1)
	
	fake.advance(0.5)
	assert(attempts == 2)
	
	fake.advance(1.5)
	assert(attempts == 2)
	
	fake.advance(0.5)
	assert(attempts == 3)
	
	assert(ok == true)
	assert(result == "ok")
end

function spec.should_cap_the_backoff_at_thirty_seconds()
	setup()
	fake.set_random(0)
	
	local attempts = 0
	const send = queue.create {
		handler = function()
			attempts += 1
			error("boom", 0)
		end,
		max_attempts = 10,
		rate_per_minute = 60,
	}

	send { payload = 1 }
	fake.advance(0)
	fake.advance(31)
	
	assert(attempts == 6)
	fake.advance(29)
	
	assert(attempts == 6)
	fake.advance(1)
	assert(attempts == 7)
end

function spec.should_add_jitter_to_the_backoff()
	setup()
	fake.set_random(1)
	
	local attempts = 0
	const send = queue.create {
		handler = function()
			attempts += 1
			error("boom", 0)
		end,
		rate_per_minute = 60,
	}

	send { payload = 1 }
	fake.advance(0)
	fake.advance(1)
	
	assert(attempts == 1)
	fake.advance(0.25)
	assert(attempts == 2)
end

function spec.should_return_the_last_error_when_every_attempt_failed()
	setup()
	
	fake.set_random(0)
	const send = queue.create {
		handler = function()
			error("boom", 0)
		end,
		max_attempts = 2,
		rate_per_minute = 60,
	}

	local ok: boolean? = nil
	local result: any = nil
	fake.spawn(function()
		ok, result = send { payload = 1, await = true }
	end)

	fake.advance(0)
	fake.advance(1)
	
	assert(ok == false)
	assert(result == "boom")
end

function spec.should_try_three_times_by_default()
	setup()
	fake.set_random(0)
	
	local attempts = 0
	const send = queue.create {
		handler = function()
			attempts += 1
			error("boom", 0)
		end,
		rate_per_minute = 60,
	}

	send { payload = 1 }
	fake.advance(0)

	fake.advance(100)
	assert(attempts == 3)
end

function spec.should_hold_later_entries_while_one_is_retrying()
	setup()
	fake.set_random(0)
	
	const calls = {}
	local failed_once = false
	
	const send = queue.create {
		handler = function(payload: any)
			table.insert(calls, payload)
			if payload == "a" and not failed_once then
				failed_once = true
				error("boom", 0)
			end
		end,
		rate_per_minute = 60,
	}

	send { payload = "a" }
	send { payload = "b" }
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "a")
	
	fake.advance(1)
	assert(table.concat(calls, ",") == "a,a,b")
end

-- merge
function spec.should_merge_entries_with_the_same_key()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }

	send { payload = 1, key = "k" }
	send { payload = 2, key = "k" }
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "2")
end

function spec.should_give_merged_waiters_the_same_result()
	setup()
	
	const send = queue.create { handler = recorder {}, rate_per_minute = 60 }
	const outcomes = {} :: { { ok: boolean?, result: any } }

	fake.spawn(function()
		const ok, result = send { payload = 1, key = "k", await = true }
		table.insert(outcomes, { ok = ok, result = result })
	end)

	fake.spawn(function()
		const ok, result = send { payload = 2, key = "k", await = true }
		table.insert(outcomes, { ok = ok, result = result })
	end)

	fake.advance(0)
	assert(#outcomes == 2)
	
	assert(outcomes[1].ok == true and outcomes[1].result == "done:2")
	assert(outcomes[2].ok == true and outcomes[2].result == "done:2")
end

function spec.should_keep_the_place_of_a_merged_entry()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }

	send { payload = "a", key = "a" }
	send { payload = "b" }
	send { payload = "a2", key = "a" }
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "a2,b")
end

function spec.should_not_merge_with_an_entry_being_sent()
	setup()
	
	const calls = {}
	const send = queue.create {
		handler = function(payload: any)
			table.insert(calls, payload)
			scheduler.current.wait(5)
		end,
		rate_per_minute = 60,
	}

	send { payload = 1, key = "k" }
	fake.advance(0)
	
	send { payload = 2, key = "k" }
	fake.advance(10)
	assert(table.concat(calls, ",") == "1,2")
end

-- size
function spec.should_drop_the_oldest_when_full()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), max_size = 2, rate_per_minute = 60 }
	local ok: boolean? = nil
	local result: any = nil

	fake.spawn(function()
		ok, result = send { payload = "a", await = true }
	end)

	send { payload = "b" }
	send { payload = "c" }
	
	assert(ok == false)
	assert(result == "dropped")
	
	fake.advance(0)
	assert(table.concat(calls, ",") == "b,c")
end

function spec.should_never_drop_without_max_size()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }

	for index = 1, 5 do
		send { payload = index }
	end

	fake.advance(0)
	assert(#calls == 5)
end

-- shutdown
function spec.should_answer_closed_after_shutdown_started()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }
	
	queue.shutdown(25)
	local ok: boolean? = nil
	local result: any = nil

	fake.spawn(function()
		ok, result = send { payload = 1, await = true }
	end)

	send { payload = 2 }
	fake.advance(0)
	
	assert(ok == false)
	assert(result == "closed")
	assert(#calls == 0)
end

function spec.should_keep_sending_while_shutting_down()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 60 }
	
	send { payload = 1 }
	send { payload = 2 }
	send { payload = 3 }
	
	local done = false
	fake.spawn(function()
		queue.shutdown(25)
		done = true
	end)

	fake.advance(2)
	assert(#calls == 3)
	assert(done)
end

function spec.should_give_up_at_the_shutdown_deadline()
	setup()
	
	const calls = {}
	const send = queue.create { handler = recorder(calls), rate_per_minute = 1 }
	
	send { payload = "a" }
	send { payload = "b" }
	
	local done = false
	fake.spawn(function()
		queue.shutdown(25)
		done = true
	end)

	fake.advance(30)
	assert(table.concat(calls, ",") == "a")
	assert(done)
end

-- options
function spec.should_reject_both_budget_and_rate()
	setup()
	fails(function()
		return queue.create {
			handler = function() end,
			budget = budget.create(1),
			rate_per_minute = 60,
		}
	end, "throttle: give budget or rate_per_minute, not both")
end

function spec.should_reject_neither_budget_nor_rate()
	setup()
	fails(function()
		return queue.create { handler = function() end }
	end, "throttle: give budget or rate_per_minute")
end

function spec.should_reject_invalid_max_attempts()
	setup()
	fails(function()
		return queue.create { handler = function() end, rate_per_minute = 60, max_attempts = 0 }
	end, "throttle: max_attempts must be a whole number of at least 1")
end

function spec.should_reject_invalid_max_size()
	setup()
	fails(function()
		return queue.create { handler = function() end, rate_per_minute = 60, max_size = 0 }
	end, "throttle: max_size must be a whole number of at least 1")
end

return spec
