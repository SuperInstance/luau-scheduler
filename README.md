# luau-scheduler

A lightweight, tick-based priority task scheduler for Roblox game loops.

Designed for server-side game logic that needs deterministic, frame-accurate task scheduling without coroutines or async complexity.

## Features

- **Tick-based** — advance time manually; integrates cleanly with `RunService.Heartbeat`
- **Priority levels** — `Critical`, `High`, `Normal`, `Low`, `Idle`
- **One-shot & recurring** — schedule once after a delay, or every N ticks
- **Cancellable** — cancel any pending task by ID
- **Zero dependencies** — pure Luau, no external libs

## Install

### Wally

```toml
[dependencies]
LuauScheduler = "superinstance/luau-scheduler@0.1.0"
```

### Manual

Copy `src/Scheduler.luau` into your project (e.g., `ReplicatedStorage/Shared/Scheduler.luau`).

## Quick Start

```luau
local Scheduler = require(path.to.Scheduler).Scheduler
local TaskPriority = require(path.to.Scheduler).TaskPriority

local sched = Scheduler.new()

-- One-shot task: run after 60 ticks (~1 second at 60fps)
sched:scheduleOnce("spawn-enemy", TaskPriority.Normal, 60, function()
    -- spawn an enemy
end)

-- Recurring task: physics update every tick
sched:scheduleRecurring("physics", TaskPriority.High, 1, function()
    -- physics step
end)

-- Connect to Roblox game loop
game:GetService("RunService").Heartbeat:Connect(function()
    sched:tick()
end)
```

## API

### `Scheduler.new()`

Creates a new scheduler instance.

### `scheduler:scheduleOnce(name, priority, delay, callback) -> number`

Schedules a one-shot task. `delay` is in ticks. Returns the task ID.

| Param      | Type         | Description                          |
|------------|--------------|--------------------------------------|
| `name`     | `string`     | Descriptive label for debugging      |
| `priority` | `number`     | `TaskPriority.*` value               |
| `delay`    | `number`     | Ticks to wait before execution       |
| `callback` | `() -> ()`   | Function to run                      |

### `scheduler:scheduleRecurring(name, priority, interval, callback) -> number`

Schedules a recurring task. `interval` is in ticks between executions. Returns the task ID.

### `scheduler:cancel(taskId) -> boolean`

Cancels a pending task. Returns `true` if cancelled, `false` if not found or already completed.

### `scheduler:tick()`

Advances the scheduler by one tick and executes all due tasks (sorted by priority).

### `scheduler:pendingCount() -> number`

Returns the number of tasks still pending.

### `scheduler:totalTaskCount() -> number`

Returns total tasks across all states.

### `scheduler:clear()`

Removes all tasks. Tick count is preserved.

### `scheduler:getTickCount() -> number`

Returns the current tick count.

### `TaskPriority`

| Level      | Value |
|------------|-------|
| `Critical` | 1     |
| `High`     | 2     |
| `Normal`   | 3     |
| `Low`      | 4     |
| `Idle`     | 5     |

Lower numbers run first within a tick.

### `TaskState`

| Value        | Meaning                       |
|--------------|-------------------------------|
| `"Pending"`  | Waiting to execute             |
| `"Running"`  | Currently executing            |
| `"Completed"`| One-shot finished              |
| `"Cancelled"`| Cancelled before execution     |

## Testing

Tests use plain Luau assertions. Run in Roblox Studio or with a test runner like [TestEZ](https://github.com/Roblox/testez):

```
-- Paste tests/run-tests.luau into a Script in Studio and hit Play
```

25 tests covering one-shot, recurring, priority ordering, cancellation, edge cases, and query methods.

## License

MIT
