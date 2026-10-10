local Players = game:GetService("Players")
local Guard = {Buckets = {}, Holds = {}}
function Guard:allow(player, action, capacity, refill)
    local all = self.Buckets[player] or {}; self.Buckets[player] = all
    local now = os.clock(); local bucket = all[action] or {Tokens = capacity, At = now}; all[action] = bucket
    bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.At) * refill); bucket.At = now
    if bucket.Tokens < 1 then return false end
    bucket.Tokens = bucket.Tokens - 1; return true
end
function Guard:bindPrompt(prompt, validate, callback)
    -- Triggered alone is not proof that a hold was completed on an honest client.
    local started = {}; self.Holds[prompt] = started
    prompt.PromptButtonHoldBegan:Connect(function(player)
        if prompt.Enabled and validate(player) then started[player] = os.clock() end
    end)
    prompt.Triggered:Connect(function(player)
        local began = started[player]; started[player] = nil
        if not prompt.Enabled or not validate(player) or not self:allow(player, prompt, 1, 0.6) then return end
        if prompt.HoldDuration > 0 and (not began or os.clock() - began < prompt.HoldDuration - 0.15) then return end
        callback(player)
    end)
    -- HoldEnded can precede Triggered; the short expiry also prevents stale hold reuse.
    prompt.PromptButtonHoldEnded:Connect(function(player)
        local began = started[player]
        task.delay(0.25, function() if started[player] == began then started[player] = nil end end)
    end)
    prompt.Destroying:Connect(function() self.Holds[prompt] = nil end)
end
function Guard:remove(player)
    self.Buckets[player] = nil
    for _, started in pairs(self.Holds) do started[player] = nil end
end
Players.PlayerRemoving:Connect(function(player) Guard:remove(player) end)
return Guard
