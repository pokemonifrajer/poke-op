-- Valid Luau; portable subset keeps the domain logic executable in offline tests.
local Config = {
    Title = "HARBOR CITY", Version = "0.1.0-alpha", DataVersion = 1,
    DataStoreName = "HarborCity_Alpha_v1", SessionLease = 180, AutoSave = 45,
    -- Studio is intentionally nonpersistent. Production always requires a successful load.
    StudioPersistence = false,
    StartingCash = 1500, StartingBank = 5000, MaxBalance = 100000000,
    SentenceBase = 45, SentencePerStar = 15, HeatDecaySeconds = 35,
    ArrestDistance = 11, InteractionDistance = 16,
    Heist = {Reward = 3800, Cooldown = 180, Duration = 240, HackSeconds = 10, CollectSeconds = 5, MaxCrew = 4},
    DeliveryReward = 450, DeliverySeconds = 12, PayInterval = 180, PolicePay = 300,
    Vehicles = {
        commuter = {Name = "Aster Compact", Price = 0, Speed = 70, Acceleration = 26, Color = {68, 155, 173}},
        sport = {Name = "Vela GT", Price = 12500, Speed = 112, Acceleration = 39, Color = {232, 159, 71}},
        patrol = {Name = "Sentinel Patrol", Price = 0, Speed = 93, Acceleration = 32, Color = {34, 45, 63}, Police = true},
    },
    Locations = {
        Spawn = {72, 5, 68}, Police = {80, 5, -80}, Garage = {-84, 5, 75},
        Bank = {-84, 5, -85}, Prison = {0, 5, -360}, Release = {34, 5, -263},
        Docks = {286, 5, 115}, Apartment = {85, 5, 269}, Depot = {-267, 5, 80},
    },
    Map = {MinX = -430, MaxX = 430, MinZ = -465, MaxZ = 400},
}
return Config
