# ObservableValue

[![License](https://img.shields.io/github/license/JDevon/observable-value)](https://github.com/JDevon/observable-value/blob/main/LICENSE)

A typed value you can read, set, and observe. Adding a listener returns a cleanup function that's safe to call more than once.

## Install

[![GitHub release](https://img.shields.io/github/v/release/JDevon/observable-value)](https://github.com/JDevon/observable-value/releases/latest)
[![Wally](https://img.shields.io/badge/wally-jdevon%2Fobservable--value-ad4646)](https://wally.run/package/jdevon/observable-value)

Install with [Wally](https://wally.run) by adding it to your `wally.toml`:

```toml
[dependencies]
ObservableValue = "jdevon/observable-value@0.1.0"
```

## Usage

```lua
local ObservableValue = require(ReplicatedStorage.Packages.ObservableValue)

local health = ObservableValue.new(100)

local cleanup = health:onChanged(function(newHealth, oldHealth)
	print(`health went from {oldHealth} to {newHealth}`)
end)

health:set(80) --> health went from 100 to 80
health:update(function(current)
	return current - 10
end) --> health went from 80 to 70

cleanup()

-- yields until health drops to 0 or below, then continues with the final value
local finalHealth = health:promiseValue(function(current)
	return current <= 0, current
end):expect()
print(`defeated at {finalHealth} health`)
```

## API

### `ObservableValue.new(initialValue: T): ObservableValue<T>`

Creates an ObservableValue holding `initialValue`.

### `observable:get(): T`

Returns the current value.

### `observable:set(newValue: T)`

Sets the value. `onChanged` fires if the value changed, and `onSet` fires on every call.

**Setting a table always fires `onChanged`**, even if it's the same table, so a table you edited in place still notifies listeners when you `set` it.

### `observable:update(update: (T) -> T): T`

Sets the value to `update(currentValue)` and returns the new value.

### `observable.version: number`

Increases each time the value changes. It identifies a value even when a table was changed in place, which makes
it a useful dependency for caches, or for React's `useMemo` / `useEffect`.

### `observable:onChanged(callback: (newValue: T, oldValue: T) -> ()): Disconnect`

Calls `callback` whenever the value changes.

### `observable:onSet(callback: (newValue: T) -> ()): Disconnect`

Calls `callback` on every `set`, including ones that don't change the value.

### `observable:observe(callback: (newValue: T, oldValue: T?) -> ()): Disconnect`

Calls `callback` straight away with the current value (`oldValue` is `nil`), then on every change.

### `observable:promiseValue(predicate: (T) -> (boolean, R)): TypedPromise<R>`

Returns a promise that resolves with `R` the first time `predicate(value)` returns `true`, checking the current
value first. If `predicate` errors, the promise rejects with that error. Cancelling the promise stops listening.

```lua
local loaded = ObservableValue.new(false)
loaded:promiseValue(function(isLoaded)
	return isLoaded, nil
end):expect() -- yields until loaded is true
```

### `observable:Destroy()` / `observable:destroy()`

Disconnects every listener. It works as a cleanup task in Maid, Janitor and Trove.

### `Disconnect`

Every listener method returns a `Disconnect` (`() -> ()`), the cleanup function. Call it to stop listening. It's safe to call more than once, and can be handed to a cleanup library or returned from a React effect.
