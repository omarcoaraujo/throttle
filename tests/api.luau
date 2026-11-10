const fake = require "./fake"
const queue = require "@src/queue"
const throttle = require "@src"
const spec = {} :: { [string]: any }

-- api
function spec.should_export_the_readme_api()
	assert(type(throttle.budget) == "function")
	assert(type(throttle.queue) == "function")

	assert(type(throttle.cooldown) == "function")
	assert(type(throttle.settle) == "function")

	assert(table.isfrozen(throttle))
	assert((throttle :: any).shutdown == nil)
	assert((throttle :: any).reset == nil)
end

function spec.should_run_the_readme_usage_example()
	fake.install()
	queue.reset()

	const http_budget = throttle.budget(450)
	const tracked = {}

	const track = throttle.queue {
		budget = http_budget,
		handler = function(payload: any)
			table.insert(tracked, payload)
		end,
	}

	const fetch = throttle.queue {
		budget = http_budget,
		handler = function(url: string)
			return "board"
		end,
	}

	track { payload = { name = "robux_purchase" } }

	local ok: boolean? = nil
	local board: any = nil

	fake.spawn(function()
		ok, board = fetch { payload = "url", key = "ranking", await = true }
	end)

	fake.advance(0)
	assert(ok == true)
	assert(board == "board")
end

function spec.should_accept_a_function_rate()
	throttle.budget(function()
		return 600
	end)
end

return spec
