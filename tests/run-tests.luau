--[[
    run-tests.luau — 25 tests for the Scheduler module.
    Run with: rojo build / serve, or paste into a ModuleScript in Studio.
]]

local SchedulerModule = require(script.Parent:FindFirstChild("Scheduler"))
local Scheduler = SchedulerModule.Scheduler
local TaskPriority = SchedulerModule.TaskPriority
local TaskState = SchedulerModule.TaskState

local passed = 0
local failed = 0
local function assert(condition: boolean, testName: string)
    if condition then
        passed += 1
        print(string.format("  ✓ %s", testName))
    else
        failed += 1
        warn(string.format("  ✗ %s", testName))
    end
end

print("=== luau-scheduler tests ===\n")

--------------------------------------------------------------------------------
-- 1. One-shot task executes after delay
--------------------------------------------------------------------------------
do
    print("[One-shot tasks]")
    local s = Scheduler.new()
    local fired = false
    s:scheduleOnce("test1", TaskPriority.Normal, 3, function()
        fired = true
    end)
    assert(not fired, "not fired before delay elapses")
    s:tick() -- tick 1
    assert(not fired, "not fired at tick 1 (delay=3)")
    s:tick() -- tick 2
    assert(not fired, "not fired at tick 2 (delay=3)")
    s:tick() -- tick 3 — delay expires
    assert(fired, "fired at tick 3 (delay=3)")
end

--------------------------------------------------------------------------------
-- 2. Zero-delay one-shot fires immediately
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local fired = false
    s:scheduleOnce("zero-delay", TaskPriority.Normal, 0, function()
        fired = true
    end)
    s:tick()
    assert(fired, "zero-delay fires on first tick")
end

--------------------------------------------------------------------------------
-- 3. Negative delay fires immediately
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local fired = false
    s:scheduleOnce("neg-delay", TaskPriority.Normal, -5, function()
        fired = true
    end)
    s:tick()
    assert(fired, "negative delay fires on first tick")
end

--------------------------------------------------------------------------------
-- 4. One-shot fires only once
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local count = 0
    s:scheduleOnce("once-only", TaskPriority.Normal, 1, function()
        count += 1
    end)
    s:tick() -- fires
    s:tick() -- should not fire again
    s:tick()
    assert(count == 1, "one-shot fires exactly once")
end

--------------------------------------------------------------------------------
-- 5. Recurring task fires at correct interval
--------------------------------------------------------------------------------
print("\n[Recurring tasks]")
do
    local s = Scheduler.new()
    local count = 0
    s:scheduleRecurring("tick-every-3", TaskPriority.Normal, 3, function()
        count += 1
    end)
    s:tick() -- t=1
    s:tick() -- t=2
    assert(count == 0, "recurring not fired before interval (tick 2)")
    s:tick() -- t=3 → fires
    assert(count == 1, "recurring fires at tick 3")
    s:tick() -- t=4
    s:tick() -- t=5
    assert(count == 1, "recurring not fired again before next interval")
    s:tick() -- t=6 → fires again
    assert(count == 2, "recurring fires again at tick 6")
end

--------------------------------------------------------------------------------
-- 6. Recurring with interval=1 fires every tick
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local count = 0
    s:scheduleRecurring("every-tick", TaskPriority.Normal, 1, function()
        count += 1
    end)
    for _ = 1, 10 do
        s:tick()
    end
    assert(count == 10, "interval=1 fires every tick")
end

--------------------------------------------------------------------------------
-- 7. Recurring continues after many cycles
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local count = 0
    s:scheduleRecurring("long-run", TaskPriority.Normal, 2, function()
        count += 1
    end)
    for _ = 1, 100 do
        s:tick()
    end
    assert(count == 50, "recurring fires 50 times over 100 ticks with interval=2")
end

--------------------------------------------------------------------------------
-- 8. Priority ordering: critical before idle
--------------------------------------------------------------------------------
print("\n[Priority ordering]")
do
    local s = Scheduler.new()
    local order = {}
    s:scheduleOnce("idle-task", TaskPriority.Idle, 0, function()
        table.insert(order, "idle")
    end)
    s:scheduleOnce("critical-task", TaskPriority.Critical, 0, function()
        table.insert(order, "critical")
    end)
    s:scheduleOnce("normal-task", TaskPriority.Normal, 0, function()
        table.insert(order, "normal")
    end)
    s:tick()
    assert(#order == 3, "all three tasks executed")
    assert(order[1] == "critical", "critical runs first")
    assert(order[2] == "normal", "normal runs second")
    assert(order[3] == "idle", "idle runs last")
end

--------------------------------------------------------------------------------
-- 9. Priority with five levels
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local order = {}
    s:scheduleOnce("low", TaskPriority.Low, 0, function()
        table.insert(order, "low")
    end)
    s:scheduleOnce("critical", TaskPriority.Critical, 0, function()
        table.insert(order, "critical")
    end)
    s:scheduleOnce("idle", TaskPriority.Idle, 0, function()
        table.insert(order, "idle")
    end)
    s:scheduleOnce("high", TaskPriority.High, 0, function()
        table.insert(order, "high")
    end)
    s:scheduleOnce("normal", TaskPriority.Normal, 0, function()
        table.insert(order, "normal")
    end)
    s:tick()
    assert(order[1] == "critical" and order[2] == "high" and order[3] == "normal"
        and order[4] == "low" and order[5] == "idle",
        "all five priority levels ordered correctly")
end

--------------------------------------------------------------------------------
-- 10. Same-priority tasks both execute
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local count = 0
    s:scheduleOnce("a", TaskPriority.Normal, 0, function()
        count += 1
    end)
    s:scheduleOnce("b", TaskPriority.Normal, 0, function()
        count += 1
    end)
    s:tick()
    assert(count == 2, "same-priority tasks both execute")
end

--------------------------------------------------------------------------------
-- 11. Cancel prevents execution
--------------------------------------------------------------------------------
print("\n[Cancellation]")
do
    local s = Scheduler.new()
    local fired = false
    local id = s:scheduleOnce("to-cancel", TaskPriority.Normal, 2, function()
        fired = true
    end)
    local ok = s:cancel(id)
    assert(ok == true, "cancel returns true for pending task")
    s:tick()
    s:tick()
    assert(not fired, "cancelled task never fires")
end

--------------------------------------------------------------------------------
-- 12. Cancel recurring task
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local count = 0
    local id = s:scheduleRecurring("rec-cancel", TaskPriority.Normal, 1, function()
        count += 1
    end)
    s:tick() -- fires once
    assert(count == 1, "recurring fired once before cancel")
    s:cancel(id)
    s:tick()
    assert(count == 1, "cancelled recurring task stops firing")
end

--------------------------------------------------------------------------------
-- 13. Cancel returns false for non-existent task
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local ok = s:cancel(999)
    assert(ok == false, "cancel returns false for unknown id")
end

--------------------------------------------------------------------------------
-- 14. Cancel returns false for already-completed task
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local id = s:scheduleOnce("done", TaskPriority.Normal, 0, function() end)
    s:tick() -- completes
    local ok = s:cancel(id)
    assert(ok == false, "cancel returns false for completed task")
end

--------------------------------------------------------------------------------
-- 15. pendingCount
--------------------------------------------------------------------------------
print("\n[Query methods]")
do
    local s = Scheduler.new()
    assert(s:pendingCount() == 0, "empty scheduler has 0 pending")
    s:scheduleOnce("a", TaskPriority.Normal, 5, function() end)
    s:scheduleOnce("b", TaskPriority.Normal, 5, function() end)
    assert(s:pendingCount() == 2, "two pending tasks")
    s:tick()
    assert(s:pendingCount() == 2, "still pending (delay=5, only tick 1)")
end

--------------------------------------------------------------------------------
-- 16. pendingCount after completion
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    s:scheduleOnce("quick", TaskPriority.Normal, 0, function() end)
    assert(s:pendingCount() == 1, "1 pending before tick")
    s:tick()
    assert(s:pendingCount() == 0, "0 pending after one-shot completes")
end

--------------------------------------------------------------------------------
-- 17. getTickCount
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    assert(s:getTickCount() == 0, "starts at 0")
    s:tick()
    assert(s:getTickCount() == 1, "tick 1")
    s:tick()
    assert(s:getTickCount() == 2, "tick 2")
end

--------------------------------------------------------------------------------
-- 18. totalTaskCount
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    assert(s:totalTaskCount() == 0, "empty scheduler total = 0")
    s:scheduleOnce("a", TaskPriority.Normal, 1, function() end)
    s:scheduleOnce("b", TaskPriority.Normal, 1, function() end)
    assert(s:totalTaskCount() == 2, "total = 2")
    s:tick() -- both complete
    assert(s:totalTaskCount() == 2, "completed tasks still counted")
end

--------------------------------------------------------------------------------
-- 19. clear removes all tasks
--------------------------------------------------------------------------------
print("\n[Clear]")
do
    local s = Scheduler.new()
    s:scheduleOnce("a", TaskPriority.Normal, 5, function() end)
    s:scheduleRecurring("b", TaskPriority.Normal, 2, function() end)
    assert(s:totalTaskCount() == 2, "2 tasks before clear")
    s:clear()
    assert(s:totalTaskCount() == 0, "0 tasks after clear")
    assert(s:pendingCount() == 0, "0 pending after clear")
end

--------------------------------------------------------------------------------
-- 20. clear does not reset tick count
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    s:tick()
    s:tick()
    s:tick()
    assert(s:getTickCount() == 3, "3 ticks before clear")
    s:clear()
    assert(s:getTickCount() == 3, "tick count preserved after clear")
end

--------------------------------------------------------------------------------
-- 21. Empty scheduler tick does not error
--------------------------------------------------------------------------------
print("\n[Edge cases]")
do
    local s = Scheduler.new()
    s:tick()
    assert(s:getTickCount() == 1, "empty tick increments counter without error")
end

--------------------------------------------------------------------------------
-- 22. Multiple one-shots with different delays
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local order = {}
    s:scheduleOnce("late", TaskPriority.Normal, 3, function()
        table.insert(order, "late")
    end)
    s:scheduleOnce("early", TaskPriority.Normal, 1, function()
        table.insert(order, "early")
    end)
    s:scheduleOnce("mid", TaskPriority.Normal, 2, function()
        table.insert(order, "mid")
    end)
    for _ = 1, 5 do
        s:tick()
    end
    assert(order[1] == "early" and order[2] == "mid" and order[3] == "late",
        "tasks fire in delay order across ticks")
end

--------------------------------------------------------------------------------
-- 23. Mixed recurring and one-shot tasks
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local oneShotFired = false
    local recCount = 0
    s:scheduleOnce("one", TaskPriority.Normal, 2, function()
        oneShotFired = true
    end)
    s:scheduleRecurring("rec", TaskPriority.Normal, 2, function()
        recCount += 1
    end)
    s:tick() -- t=1
    assert(not oneShotFired and recCount == 0, "nothing fires at t=1")
    s:tick() -- t=2 → both fire
    assert(oneShotFired, "one-shot fires at t=2")
    assert(recCount == 1, "recurring fires at t=2")
    s:tick() -- t=3
    s:tick() -- t=4 → recurring fires again
    assert(recCount == 2, "recurring fires again at t=4")
    -- one-shot stays completed
    assert(s:pendingCount() == 1, "only recurring task still pending")
end

--------------------------------------------------------------------------------
-- 24. Schedule after clear works
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    s:scheduleOnce("old", TaskPriority.Normal, 0, function() end)
    s:clear()
    local fired = false
    s:scheduleOnce("new", TaskPriority.Normal, 0, function()
        fired = true
    end)
    s:tick()
    assert(fired, "new task fires after clear")
end

--------------------------------------------------------------------------------
-- 25. Task IDs are unique and monotonically increasing
--------------------------------------------------------------------------------
do
    local s = Scheduler.new()
    local id1 = s:scheduleOnce("a", TaskPriority.Normal, 0, function() end)
    local id2 = s:scheduleOnce("b", TaskPriority.Normal, 0, function() end)
    local id3 = s:scheduleRecurring("c", TaskPriority.Normal, 1, function() end)
    assert(id1 == 1 and id2 == 2 and id3 == 3, "IDs are sequential: 1, 2, 3")
    assert(id1 ~= id2 and id2 ~= id3, "IDs are unique")
end

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------
print(string.format("\n=== Results: %d passed, %d failed, %d total ===", passed, failed, passed + failed))
if failed > 0 then
    warn("SOME TESTS FAILED!")
end
