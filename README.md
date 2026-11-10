# throttle

<a href="https://github.com/omarcoaraujo/throttle/actions/workflows/check.yml"><img src="https://github.com/omarcoaraujo/throttle/actions/workflows/check.yml/badge.svg" alt="Check"/></a> <a href="https://github.com/omarcoaraujo/throttle/actions/workflows/release.yml"><img src="https://github.com/omarcoaraujo/throttle/actions/workflows/release.yml/badge.svg" alt="Release"/></a>

Rate limiting for [Luau](https://luau.org): a request queue that respects a shared budget, with retry and backoff, plus `cooldown` and `settle` for repeatable player actions. Plain functions, no objects. It only paces calls: no cache, no persistence, no batching.

## Features

- A `budget` that several queues can share, so Http or MessagingService limits are respected across the whole server
- A queue with retry, exponential backoff with jitter, merging by key and an optional size limit
- Fire and forget with `send`, or wait for the result with `await = true`
- The queue drains itself when the server shuts down
- `cooldown` and `settle` plug straight into `OnServerEvent:Connect`, one timer per player
- Rates and intervals can be numbers or functions, read on every use

## Installation

Add throttle to your `pesde.toml`:

```toml
[dependencies]
throttle = { name = "omarcoaraujo/throttle", version = "^0.1.0" }
```

Then require it:

```luau
const throttle = require("@pkg/throttle")
```

## Usage

```luau
const http_budget = throttle.budget(450)

const track = throttle.queue {
	handler = function(event)
		return HttpService:PostAsync(ANALYTICS_URL, HttpService:JSONEncode(event))
	end,

	budget = http_budget,
	max_attempts = 2,
	max_size = 500,
}

const fetch = throttle.queue {
	handler = function(url)
		return HttpService:GetAsync(url)
	end,

	budget = http_budget,
	max_attempts = 4,
}

track { payload = { name = "robux_purchase", user = player.UserId } }
const ok, board = fetch { payload = RANKING_URL, key = "ranking", await = true }
```

Both queues draw from the same 450 requests per minute. When two queues compete for the budget, the one that asked first goes first.

## API

| Function | What it does |
|---|---|
| `throttle.budget(rate_per_minute)` | A limit that several queues can share |
| `throttle.queue(options)` | A queue that sends one entry at a time within a budget; returns `send` |
| `throttle.cooldown(callback, seconds, options?)` | Runs at once, then ignores the calls that follow within the interval |
| `throttle.settle(callback, seconds, options?)` | Waits until the calls stop, then runs once with the last arguments |

### throttle.budget(rate_per_minute)

The rate is a number or a function. A function is read on every use, so it can follow the number of players:

```luau
const messaging_budget = throttle.budget(function()
	return 600 + #Players:GetPlayers() * 40
end)
```

### throttle.queue(options)

Options:

- `handler`: required. Called with `(payload, key)`. Its return value is the result and a raised error is a failure
- `budget`: a shared limit from `throttle.budget`. Give this or `rate_per_minute`, not both
- `rate_per_minute`: a number or a function, for a queue that shares its limit with nothing
- `max_attempts`: tries per entry, including the first. `3` by default
- `max_size`: entries kept in the queue. When it is full the oldest is dropped. Without it nothing is ever dropped

Entries leave in the order they arrived. A failed entry waits `1`, `2`, `4`... seconds before the next try, up to `30`, with a random jitter so that servers do not retry together.

### send

`send` takes one table:

- `payload`: passed to the handler
- `key`: merges entries that are still in the queue. The newer replaces the older, and everyone waiting on them gets the result of the one that was sent. An entry already being sent is not merged
- `await`: when `true`, yields until the entry finishes

Without `await`, `send` returns nothing. With `await = true` it returns `ok, result`, the shape of `pcall`:

```luau
const ok, result = send { payload = body, await = true }
```

- On success `ok` is `true` and `result` is what the handler returned
- When every attempt failed `ok` is `false` and `result` is the error of the last one
- When `max_size` pushed the entry out, `ok` is `false` and `result` is `"dropped"`
- When the server was already shutting down, `ok` is `false` and `result` is `"closed"`

### Shutdown

When the server closes, every queue stops accepting entries and keeps sending what is pending for up to 25 seconds, still respecting its budget and its retries. Whatever is left is lost. The shutdown hook is registered only where `game` exists, so the queue also runs outside Roblox.

## cooldown

```luau
attack_remote.OnServerEvent:Connect(throttle.cooldown(apply_damage, 0.25))
```

Runs the first call at once and ignores the calls that follow within the interval. The interval counts from the last call that went through. In Roblox this is what most people call a debounce.

The interval can be a function that receives the arguments of the call, so it can depend on the player:

```luau
attack_remote.OnServerEvent:Connect(throttle.cooldown(apply_damage, function(player)
	return equipped(player).cooldown
end))
```

## settle

```luau
settings_remote.OnServerEvent:Connect(throttle.settle(save_settings, 1))
```

Waits until the calls stop for the given seconds, then runs once with the arguments of the last call. This is the classic debounce: use it when only the final value matters, such as a slider. A value still waiting when the server shuts down is lost.

### Timers

`cooldown` and `settle` keep one timer per first argument. In `OnServerEvent` that is the player, so each player has their own timer. When the first argument does not say who is being limited, `unkeyed` keeps a single timer for every call:

```luau
const heal = throttle.cooldown(apply_heal, 1, { unkeyed = true })

heal(10)
heal(25)
```

The second call is ignored, whatever its arguments. Timers are forgotten once their interval has passed.

## Limitations

- throttle only paces calls. A cache, saving to a store and batching belong to your own code
- There are no priorities. The queue is first in, first out
- Pending `settle` calls and the entries a queue could not send in 25 seconds at shutdown are lost

## Development

```sh
lute run tests
stylua --config-path stylua.toml --check src tests
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src tests
```

## License

MIT
