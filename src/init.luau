--!strict
local Signal = require(script.Parent.Signal)
local Promise = require(script.Parent.Promise)

--[=[
	@type Disconnect () -> ()
	@within ObservableValue

	Every listener method returns a `Disconnect`, the cleanup function. Call it to stop listening. It's safe to call
	more than once, and can be handed to a cleanup library or returned from a React effect.
]=]
export type Disconnect = () -> ()

local function safeConnectionCleanup(connection: Signal.Connection): Disconnect
	local connected = true
	return function()
		if connected then
			connected = false
			connection:Disconnect()
		end
	end
end

--[=[
	@class ObservableValue

	A typed value you can read, set, and observe. Adding a listener returns a cleanup function that's safe to call
	more than once.

	```lua
	local health = ObservableValue.new(100)

	local cleanup = health:onChanged(function(newHealth, oldHealth)
		print(`health went from {oldHealth} to {newHealth}`)
	end)

	health:set(80) --> health went from 100 to 80
	health:update(function(current)
		return current - 10
	end) --> health went from 80 to 70

	cleanup()
	```
]=]
local ObservableValue = {}
ObservableValue.__index = ObservableValue

--[=[
	@prop version number
	@within ObservableValue
	@readonly

	Increases each time the value changes. It identifies a value even when a table was changed in place, which makes
	it a useful dependency for caches, or for React's `useMemo` / `useEffect`.
]=]
export type ObservableValue<T> = typeof(setmetatable(
	{} :: {
		value: T,
		version: number,
		changedSignal: Signal.Signal<T, T>,
		setSignal: Signal.Signal<T>,
	},
	{} :: {
		__index: {
			get: (self: ObservableValue<T>) -> T,
			set: (self: ObservableValue<T>, newValue: T) -> (),
			update: (self: ObservableValue<T>, update: (T) -> T) -> T,
			onChanged: (self: ObservableValue<T>, callback: (newValue: T, oldValue: T) -> ()) -> Disconnect,
			onSet: (self: ObservableValue<T>, callback: (newValue: T) -> ()) -> Disconnect,
			promiseValue: <R>(self: ObservableValue<T>, predicate: (T) -> (boolean, R)) -> Promise.TypedPromise<R>,
			observe: (self: ObservableValue<T>, callback: (newValue: T, oldValue: T?) -> ()) -> Disconnect,
			destroy: (self: ObservableValue<T>) -> (),
			Destroy: (self: ObservableValue<T>) -> (),
		},
	}
))

--[=[
	Creates an ObservableValue holding `initialValue`.

	@param initialValue T
	@return ObservableValue<T>
]=]
function ObservableValue.new<T>(initialValue: T): ObservableValue<T>
	local self = (setmetatable({}, ObservableValue) :: any) :: ObservableValue<T>
	self.value = initialValue :: T
	self.version = 0
	self.changedSignal = Signal.new()
	self.setSignal = Signal.new()

	return self
end

--[=[
	@method get
	@within ObservableValue

	Returns the current value.

	@return T
]=]
function ObservableValue.get<T>(self: ObservableValue<T>): T
	return self.value
end

--[=[
	@method set
	@within ObservableValue

	Sets the value. [ObservableValue:onChanged] fires if the value changed, and [ObservableValue:onSet] fires on
	every call.

	:::info
	Setting a table always fires `onChanged`, even if it's the same table, so a table you edited in place still
	notifies listeners when you `set` it.
	:::

	@param newValue T
]=]
function ObservableValue.set<T>(self: ObservableValue<T>, newValue: T)
	if newValue ~= self.value or type(self.value) == "table" then
		local prevValue = self.value
		self.value = newValue
		self.version += 1
		self.changedSignal:Fire(newValue, prevValue)
	end
	self.setSignal:Fire(newValue)
end

--[=[
	@method update
	@within ObservableValue

	Sets the value to `update(currentValue)` and returns the new value.

	```lua
	health:update(function(current)
		return current - 10
	end)
	```

	@param update (T) -> T
	@return T
]=]
function ObservableValue.update<T>(self: ObservableValue<T>, update: (value: T) -> T): T
	local newValue = update(self.value)
	self:set(newValue)
	return newValue
end

--[=[
	@method onChanged
	@within ObservableValue

	Calls `callback` whenever the value changes.

	@param callback (newValue: T, oldValue: T) -> ()
	@return Disconnect
]=]
function ObservableValue.onChanged<T>(self: ObservableValue<T>, callback: (newValue: T, oldValue: T) -> ()): Disconnect
	return safeConnectionCleanup(self.changedSignal:Connect(callback))
end

--[=[
	@method onSet
	@within ObservableValue

	Calls `callback` on every [ObservableValue:set], including ones that don't change the value.

	@param callback (newValue: T) -> ()
	@return Disconnect
]=]
function ObservableValue.onSet<T>(self: ObservableValue<T>, callback: (newValue: T) -> ()): Disconnect
	return safeConnectionCleanup(self.setSignal:Connect(callback))
end

--[=[
	@method promiseValue
	@within ObservableValue

	Returns a promise that resolves with `R` the first time `predicate(value)` returns `true`, checking the current
	value first. If `predicate` errors, the promise rejects with that error. Cancelling the promise stops listening.

	```lua
	local loaded = ObservableValue.new(false)
	loaded:promiseValue(function(isLoaded)
		return isLoaded, nil
	end):expect() -- yields until loaded is true
	```

	@param predicate (T) -> (boolean, R)
	@return TypedPromise<R>
]=]
function ObservableValue.promiseValue<T, R>(self: ObservableValue<T>, predicate: (T) -> (boolean, R)): Promise.TypedPromise<R>
	return Promise.new(function(resolve, reject, onCancel)
		local connection: Signal.Connection? = nil
		local function disconnect()
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end

		local function settle(value: T): boolean
			local didRun, ok, result = pcall(predicate, value)
			if not didRun then
				reject(ok)
				return true
			elseif ok then
				resolve(result)
				return true
			end
			return false
		end

		if settle(self.value) then
			return
		end

		connection = self.changedSignal:Connect(function(newValue)
			if settle(newValue) then
				disconnect()
			end
		end)
		onCancel(disconnect)
	end)
end

--[=[
	@method observe
	@within ObservableValue

	Calls `callback` straight away with the current value (`oldValue` is `nil`), then on every change.

	@param callback (newValue: T, oldValue: T?) -> ()
	@return Disconnect
]=]
function ObservableValue.observe<T>(self: ObservableValue<T>, callback: (newValue: T, oldValue: T?) -> ()): Disconnect
	local disconnect = safeConnectionCleanup(self.changedSignal:Connect(callback))
	callback(self.value, nil)
	return disconnect
end

--[=[
	@method Destroy
	@within ObservableValue

	Disconnects every listener. It works as a cleanup task in Maid, Janitor and Trove.
]=]
function ObservableValue.Destroy<T>(self: ObservableValue<T>)
	self.changedSignal:Destroy()
	self.setSignal:Destroy()
end

--[=[
	@method destroy
	@within ObservableValue

	Alias of [ObservableValue:Destroy].
]=]
ObservableValue.destroy = ObservableValue.Destroy

return table.freeze({
	new = ObservableValue.new,
})
