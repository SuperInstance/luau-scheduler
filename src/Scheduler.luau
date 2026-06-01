--[[
    luau-scheduler — Tick-based priority task scheduler for Roblox game loops.
    MIT License
]]

-- Task priority levels
local TaskPriority = {
    Critical = 1,
    High = 2,
    Normal = 3,
    Low = 4,
    Idle = 5,
}

-- Task states
local TaskState = {
    Pending = "Pending",
    Running = "Running",
    Completed = "Completed",
    Cancelled = "Cancelled",
}

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self.tasks = {}          -- id → task
    self.nextId = 1
    self.tickCount = 0
    return self
end

-- Schedule a one-shot task after `delay` ticks
function Scheduler:scheduleOnce(name: string, priority: number, delay: number, callback: () -> ()): number
    local task = {
        id = self.nextId,
        name = name,
        priority = priority,
        delay = delay,
        remainingDelay = delay,
        interval = nil,
        callback = callback,
        state = TaskState.Pending,
        recurring = false,
    }
    self.nextId += 1
    self.tasks[task.id] = task
    return task.id
end

-- Schedule a recurring task every `interval` ticks
function Scheduler:scheduleRecurring(name: string, priority: number, interval: number, callback: () -> ()): number
    local task = {
        id = self.nextId,
        name = name,
        priority = priority,
        delay = 0,
        remainingDelay = 0,
        interval = interval,
        ticksSinceLastRun = 0,
        callback = callback,
        state = TaskState.Pending,
        recurring = true,
    }
    self.nextId += 1
    self.tasks[task.id] = task
    return task.id
end

-- Cancel a task by id
function Scheduler:cancel(taskId: number): boolean
    local task = self.tasks[taskId]
    if task and task.state == TaskState.Pending then
        task.state = TaskState.Cancelled
        return true
    end
    return false
end

-- Run one tick — execute all due tasks sorted by priority
function Scheduler:tick()
    self.tickCount += 1

    -- Collect due tasks
    local due = {}
    for _id, task in pairs(self.tasks) do
        if task.state == TaskState.Pending then
            if task.recurring then
                task.ticksSinceLastRun = (task.ticksSinceLastRun or 0) + 1
                if task.ticksSinceLastRun >= (task.interval or 1) then
                    table.insert(due, task)
                end
            else
                task.remainingDelay = (task.remainingDelay or 0) - 1
                if task.remainingDelay <= 0 then
                    table.insert(due, task)
                end
            end
        end
    end

    -- Sort by priority (lower number = higher priority)
    table.sort(due, function(a: typeof(task), b: typeof(task)): boolean
        return a.priority < b.priority
    end)

    -- Execute
    for _, task in ipairs(due) do
        task.state = TaskState.Running
        task.callback()

        if task.recurring then
            task.ticksSinceLastRun = 0
            task.state = TaskState.Pending
        else
            task.state = TaskState.Completed
        end
    end
end

-- Query: count of pending tasks
function Scheduler:pendingCount(): number
    local count = 0
    for _, task in pairs(self.tasks) do
        if task.state == TaskState.Pending then
            count += 1
        end
    end
    return count
end

-- Query: total tasks (all states)
function Scheduler:totalTaskCount(): number
    local count = 0
    for _ in pairs(self.tasks) do
        count += 1
    end
    return count
end

-- Remove all tasks
function Scheduler:clear()
    self.tasks = {}
end

-- Get current tick count
function Scheduler:getTickCount(): number
    return self.tickCount
end

return {
    Scheduler = Scheduler,
    TaskPriority = TaskPriority,
    TaskState = TaskState,
}
