--// Modules
const budget = require "@self/budget"
const cooldown = require "@self/cooldown"
const queue = require "@self/queue"
const settle = require "@self/settle"
const timers = require "@self/timers"

--// Types
export type budget = budget.budget
export type rate = budget.rate

export type queue_options<payload> = queue.queue_options<payload>
export type send_options<payload> = queue.send_options<payload>

export type send<payload> = queue.send<payload>
export type interval<args...> = timers.interval<args...>

export type cooldown_options = cooldown.cooldown_options
export type settle_options = settle.settle_options

--// End
return table.freeze {
	budget = budget.create,
	queue = queue.create,

	cooldown = cooldown.create,
	settle = settle.create,
}
