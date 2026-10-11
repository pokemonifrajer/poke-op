local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Domain = require(Shared.Domain)
local Data = {Profiles = {}, Persistent = not RunService:IsStudio() or Config.StudioPersistence}
local store = Data.Persistent and DataStoreService:GetDataStore(Config.DataStoreName) or nil
local session = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
local function retry(operation)
    local result
    for attempt = 1, 3 do
        local ok, value = pcall(operation)
        if ok then return true, value end
        result = value
        task.wait(attempt)
    end
    return false, result
end
function Data:load(player)
    if not self.Persistent then
        self.Profiles[player] = {Data = Domain.default(Config), Ready = true, Mode = "Studio • neukládá se"}
        return true
    end
    local ok, envelope = retry(function()
        return store:UpdateAsync("player_" .. player.UserId, function(old)
            if old ~= nil and (type(old) ~= "table" or not Domain.validate(old.Data, Config)) then
                error("Unsupported or invalid profile; refusing to overwrite")
            end
            local now = os.time()
            if old and old.Lock and old.Lock.Owner ~= session and old.Lock.Until > now then return nil end
            return {Data = old and old.Data or Domain.default(Config), Lock = {Owner = session, Until = now + Config.SessionLease}}
        end)
    end)
    if not ok or not envelope or not envelope.Lock or envelope.Lock.Owner ~= session then
        player:Kick("Data se nepodařilo bezpečně načíst. Zkus připojení znovu za chvíli; tvůj uložený postup se nepřepisuje.")
        return false
    end
    self.Profiles[player] = {Data = Domain.normalize(envelope.Data, Config), Ready = true, Mode = "Ukládání aktivní", LastSave = os.time()}
    return true
end
function Data:get(player)
    local profile = self.Profiles[player]
    if profile and profile.Ready and not profile.Closing then return profile.Data end
    return nil
end
function Data:save(player, release)
    local profile = self.Profiles[player]; if not profile then return true end
    if release then profile.Closing = true end
    while profile.Saving do task.wait(0.05) end
    if not self.Profiles[player] then return true end
    if not self.Persistent then if release then self.Profiles[player] = nil end; return true end
    profile.Saving = true
    local snapshot = Domain.copy(profile.Data)
    local ok, result = retry(function()
        return store:UpdateAsync("player_" .. player.UserId, function(old)
            if not old or not old.Lock or old.Lock.Owner ~= session then return nil end
            local envelope = {Data = snapshot}
            if not release then envelope.Lock = {Owner = session, Until = os.time() + Config.SessionLease} end
            return envelope
        end)
    end)
    profile.Saving = false
    if not ok or not result then
        profile.Ready = false; profile.Mode = "Chyba ukládání"
        warn("[Harbor City] Save failed for user", player.UserId)
        if player.Parent then player:Kick("Ukládání bylo přerušeno. Připoj se prosím znovu; poslední potvrzené uložení zůstává zachováno.") end
        return false
    end
    profile.LastSave = os.time()
    if release then self.Profiles[player] = nil end
    return true
end
function Data:start()
    task.spawn(function()
        while true do
            task.wait(Config.AutoSave)
            for player, profile in pairs(self.Profiles) do
                if profile.Ready and not profile.Closing then task.spawn(function() self:save(player, false) end) end
            end
        end
    end)
    game:BindToClose(function()
        local remaining = 0
        for player in pairs(self.Profiles) do
            remaining = remaining + 1
            task.spawn(function() self:save(player, true); remaining = remaining - 1 end)
        end
        local deadline = os.clock() + 25
        while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
    end)
end
return Data
