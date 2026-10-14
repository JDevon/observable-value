<!-- Links -->

[observable-value/releases]: https://github.com/JDevon/observable-value/releases/latest
[observable-value/wally]: https://wally.run/package/jdevon/observable-value

<!-- Badges -->

[badges/github]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/github.svg
[badges/wally]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/wally.svg

# ObservableValue

A typed value you can read, set, and observe. Adding a listener returns a cleanup function that's safe to call more than once.

Full API reference at [jdevon.github.io/observable-value](https://jdevon.github.io/observable-value/).

Using React? See [ReactObservableValue](https://github.com/JDevon/react-observable-value) for hooks.

## Install

[![badges/github]][observable-value/releases] [![badges/wally]][observable-value/wally]

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

Each member links to its full entry in the [API reference](https://jdevon.github.io/observable-value/api/ObservableValue).

### Types

- [`Disconnect`](https://jdevon.github.io/observable-value/api/ObservableValue#Disconnect) - the cleanup function returned by every listener method

### Properties

- [`version`](https://jdevon.github.io/observable-value/api/ObservableValue#version) - increases each time the value changes

### Functions

- [`.new`](https://jdevon.github.io/observable-value/api/ObservableValue#new) - creates an ObservableValue holding an initial value
- [`:get`](https://jdevon.github.io/observable-value/api/ObservableValue#get) - returns the current value
- [`:set`](https://jdevon.github.io/observable-value/api/ObservableValue#set) - sets the value
- [`:update`](https://jdevon.github.io/observable-value/api/ObservableValue#update) - sets the value from the current one
- [`:onChanged`](https://jdevon.github.io/observable-value/api/ObservableValue#onChanged) - calls back whenever the value changes
- [`:onSet`](https://jdevon.github.io/observable-value/api/ObservableValue#onSet) - calls back on every `set`
- [`:observe`](https://jdevon.github.io/observable-value/api/ObservableValue#observe) - calls back now with the current value, then on every change
- [`:promiseValue`](https://jdevon.github.io/observable-value/api/ObservableValue#promiseValue) - resolves once the value passes a check
- [`:Destroy`](https://jdevon.github.io/observable-value/api/ObservableValue#Destroy) - disconnects every listener (`:destroy` also works)
