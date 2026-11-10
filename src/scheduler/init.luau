--// Modules
const real = require "@self/real"

--// Types
export type scheduler = real.scheduler

--// Variables
const current = table.clone(real) :: scheduler

--// Functions
const function use(replacement: scheduler)
	current.now = replacement.now
	current.wait = replacement.wait
	current.delay = replacement.delay
	current.defer = replacement.defer
	current.resume = replacement.resume
	current.random = replacement.random
	current.on_close = replacement.on_close
end

--// End
return table.freeze {
	current = current,
	use = use,
}
