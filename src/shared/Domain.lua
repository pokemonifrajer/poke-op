-- Pure state transitions: never accept client supplied prices, rewards or balances.
local Domain = {}
function Domain.integer(value, low, high)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end
function Domain.default(config)
    return {Version = config.DataVersion, Cash = config.StartingCash, Bank = config.StartingBank,
        Cars = {commuter = true}, Colors = {}, Home = false, Transactions = {},
        Wanted = 0, JailUntil = 0, LastCrime = 0, LastDecay = 0, RewardIds = {}}
end
function Domain.validate(data, config)
    if type(data) ~= "table" then return false end
    if data.Version ~= config.DataVersion then return false end
    if not Domain.integer(data.Cash, 0, config.MaxBalance) or not Domain.integer(data.Bank, 0, config.MaxBalance) then return false end
    if not Domain.integer(data.Wanted, 0, 5) or not Domain.integer(data.JailUntil, 0, 100000000000) then return false end
    if type(data.Cars) ~= "table" or type(data.Transactions) ~= "table" or type(data.Colors) ~= "table" or type(data.RewardIds) ~= "table" then return false end
    if type(data.Home) ~= "boolean" or not Domain.integer(data.LastCrime, 0, 100000000000) or not Domain.integer(data.LastDecay, 0, 100000000000) then return false end
    for key, value in pairs(data.Cars) do if not config.Vehicles[key] or type(value) ~= "boolean" then return false end end
    for key, value in pairs(data.Colors) do if not config.Vehicles[key] or not Domain.integer(value, 1, 6) then return false end end
    return true
end
function Domain.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, item in pairs(value) do out[key] = Domain.copy(item) end; return out
end
function Domain.log(data, label, amount, now)
    table.insert(data.Transactions, 1, {Label = label, Amount = amount, At = now})
    while #data.Transactions > 25 do table.remove(data.Transactions) end
end
function Domain.transfer(data, direction, amount, config, now)
    if not Domain.integer(amount, 1, 1000000) then return false, "Zadej celé kladné číslo." end
    local from, to
    if direction == "deposit" then from, to = "Cash", "Bank"
    elseif direction == "withdraw" then from, to = "Bank", "Cash"
    else return false, "Neplatná operace." end
    if data[from] < amount then return false, "Nedostatek peněz." end
    if data[to] + amount > config.MaxBalance then return false, "Limit účtu." end
    data[from], data[to] = data[from] - amount, data[to] + amount
    Domain.log(data, direction == "deposit" and "Vklad" or "Výběr", amount, now)
    return true
end
function Domain.spend(data, amount, label, now)
    if not Domain.integer(amount, 0, 100000000) or data.Bank < amount then return false, "Na účtu nemáš dost peněz." end
    data.Bank = data.Bank - amount; Domain.log(data, label, -amount, now); return true
end
function Domain.reward(data, amount, id, label, config, now)
    if not Domain.integer(amount, 1, config.MaxBalance) or type(id) ~= "string" then return false end
    for _, saved in ipairs(data.RewardIds) do if saved == id then return false end end
    if data.Cash + amount > config.MaxBalance then return false end
    data.Cash = data.Cash + amount
    table.insert(data.RewardIds, id)
    while #data.RewardIds > 80 do table.remove(data.RewardIds, 1) end
    Domain.log(data, label, amount, now); return true
end
function Domain.buyCar(data, id, config, now)
    local car = config.Vehicles[id]
    if not car or car.Police or data.Cars[id] then return false, "Vůz už vlastníš, nebo není na prodej." end
    local ok, reason = Domain.spend(data, car.Price, "Nákup: " .. car.Name, now)
    if ok then data.Cars[id] = true end
    return ok, reason
end
function Domain.crime(data, stars, now)
    data.Wanted = math.min(5, math.max(data.Wanted, stars))
    data.LastCrime, data.LastDecay = now, now
end
function Domain.decay(data, now, seen, interval)
    if seen then data.LastDecay = now; return end
    if data.Wanted > 0 and now - math.max(data.LastCrime, data.LastDecay) >= interval then
        data.Wanted = data.Wanted - 1; data.LastDecay = now
    end
end
function Domain.jail(data, now, config)
    data.JailUntil = now + config.SentenceBase + data.Wanted * config.SentencePerStar
    data.Wanted = 0
    return data.JailUntil
end
return Domain
