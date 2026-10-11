-- Pure state transitions: never accept client supplied prices, rewards or balances.
local Domain = {}
function Domain.integer(value, low, high)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end
function Domain.default(config)
    return {Version = config.DataVersion, Cash = config.StartingCash, Bank = config.StartingBank,
        Cars = {commuter = true}, Colors = {}, Home = false, Homes = {}, Businesses = {}, Transactions = {},
        Wanted = 0, JailUntil = 0, LastCrime = 0, LastDecay = 0, RewardIds = {}, Company = false, Arrests = 0}
end
function Domain.validate(data, config)
    if type(data) ~= "table" then return false end
    if data.Version ~= config.DataVersion then return false end
    if not Domain.integer(data.Cash, 0, config.MaxBalance) or not Domain.integer(data.Bank, 0, config.MaxBalance) then return false end
    if not Domain.integer(data.Wanted, 0, 5) or not Domain.integer(data.JailUntil, 0, 100000000000) then return false end
    if type(data.Cars) ~= "table" or type(data.Transactions) ~= "table" or type(data.Colors) ~= "table" or type(data.RewardIds) ~= "table" then return false end
    if type(data.Home) ~= "boolean" or not Domain.integer(data.LastCrime, 0, 100000000000) or not Domain.integer(data.LastDecay, 0, 100000000000) then return false end
    if data.Homes ~= nil and type(data.Homes) ~= "table" then return false end
    if data.Businesses ~= nil and type(data.Businesses) ~= "table" then return false end
    if data.Arrests ~= nil and not Domain.integer(data.Arrests,0,100000000) then return false end
    if data.Company ~= nil and data.Company ~= false then
        local c=data.Company
        if type(c)~="table" or not config.Company.Industries[c.Industry] or not Domain.integer(c.Brand,1,#config.Company.Brands)
            or not Domain.integer(c.Level,1,config.Company.MaxLevel) or not Domain.integer(c.Treasury,0,config.Company.MaxTreasury)
            or not Domain.integer(c.Completed,0,100000000) then return false end
    end
    for id, owned in pairs(data.Homes or {}) do if not config.Properties[id] or type(owned) ~= "boolean" then return false end end
    for id, owned in pairs(data.Businesses or {}) do if not config.Businesses[id] or type(owned) ~= "boolean" then return false end end
    for key, value in pairs(data.Cars) do if not config.Vehicles[key] or type(value) ~= "boolean" then return false end end
    for key, value in pairs(data.Colors) do if not config.Vehicles[key] or not Domain.integer(value, 1, 6) then return false end end
    return true
end
function Domain.normalize(data, config)
    data.Homes = data.Homes or {}
    data.Businesses = data.Businesses or {}
    data.Company = data.Company or false
    data.Arrests = data.Arrests or 0
    if data.Home then data.Homes.marina = true end
    return data
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
function Domain.ownsHome(data, id)
    return (data.Homes and data.Homes[id] == true) or (id == "marina" and data.Home == true)
end
function Domain.buyHome(data, id, config, now)
    local spec = config.Properties[id]
    if not spec then return false, "Tato nemovitost není k prodeji." end
    Domain.normalize(data, config)
    if Domain.ownsHome(data, id) then return false, "Tuto nemovitost už vlastníš." end
    local ok, reason = Domain.spend(data, spec.Price, "Nemovitost: " .. spec.Name, now)
    if ok then data.Homes[id] = true; if id == "marina" then data.Home = true end end
    return ok, reason
end
function Domain.buyBusiness(data, id, config, now)
    local spec = config.Businesses[id]
    if not spec then return false, "Tato firma není k dispozici." end
    data.Businesses = data.Businesses or {}
    if data.Businesses[id] then return false, "Tuto firmu už vlastníš." end
    local ok, reason = Domain.spend(data, spec.Price, "Podnikání: " .. spec.Name, now)
    if ok then data.Businesses[id] = true end
    return ok, reason
end
function Domain.businessPayout(data, id, config, now)
    local spec = config.Businesses[id]
    if not spec or not data.Businesses or not data.Businesses[id] then return false end
    local amount = math.min(spec.Income, config.MaxBalance - data.Bank)
    if amount <= 0 then return false end
    data.Bank = data.Bank + amount
    Domain.log(data, "Výnos: " .. spec.Name, amount, now)
    return true
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
function Domain.foundCompany(data,industry,brand,config,now)
    local spec=type(industry)=="string" and config.Company.Industries[industry]
    if data.Company then return false,"Už vlastníš firmu." end
    if not spec or not Domain.integer(brand,1,#config.Company.Brands) then return false,"Vyber název a obor firmy." end
    local ok,reason=Domain.spend(data,spec.Price,"Založení firmy",now)
    if ok then data.Company={Industry=industry,Brand=brand,Level=1,Treasury=0,Completed=0} end
    return ok,reason
end
function Domain.companyName(company,config)
    if not company then return "" end
    return config.Company.Brands[company.Brand].." "..config.Company.Industries[company.Industry].Name
end
function Domain.upgradeCompany(data,config,now)
    local c=data.Company
    if not c or c.Level>=config.Company.MaxLevel then return false,"Firma už má maximální úroveň, nebo ji ještě nevlastníš." end
    local ok,reason=Domain.spend(data,config.Company.UpgradePrices[c.Level],"Rozšíření firmy",now)
    if ok then c.Level=c.Level+1 end
    return ok,reason
end
function Domain.companyReward(data,id,config,now)
    local c=data.Company
    if not c or type(id)~="string" then return false end
    for _,saved in ipairs(data.RewardIds) do if saved==id then return false end end
    local amount=config.Company.Industries[c.Industry].Reward+250*(c.Level-1)
    if c.Treasury+amount>config.Company.MaxTreasury then return false end
    c.Treasury=c.Treasury+amount; c.Completed=c.Completed+1
    table.insert(data.RewardIds,id); while #data.RewardIds>80 do table.remove(data.RewardIds,1) end
    Domain.log(data,"Firemní zakázka",amount,now)
    return true,amount
end
function Domain.withdrawCompany(data,config,now)
    local c=data.Company
    if not c or c.Treasury<=0 then return false,"Firma nemá žádný zisk k výběru." end
    if data.Bank+c.Treasury>config.MaxBalance then return false,"Na bankovním účtu není místo." end
    local amount=c.Treasury; c.Treasury=0; data.Bank=data.Bank+amount
    Domain.log(data,"Výběr zisku firmy",amount,now); return true
end
return Domain
