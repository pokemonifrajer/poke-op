-- Valid Luau; portable subset keeps the domain logic executable in offline tests.
local Config = {
    Title = "HARBOR CITY", Version = "0.2.0-alpha", DataVersion = 1,
    DataStoreName = "HarborCity_Alpha_v1", SessionLease = 180, AutoSave = 45,
    -- Studio is intentionally nonpersistent. Production always requires a successful load.
    StudioPersistence = false,
    StartingCash = 1500, StartingBank = 5000, MaxBalance = 100000000,
    SentenceBase = 45, SentencePerStar = 15, HeatDecaySeconds = 35,
    ArrestDistance = 11, InteractionDistance = 16,
    Heists = {
        bank = {Name = "Civic Bank", Reward = 3800, Stars = 3, HackSeconds = 10, Steps = 4, CollectSeconds = 5, Cooldown = 180, MinEscapeSeconds = 12, StartMarker = "BankTerminal", LootMarker = "BankLoot", DoorMarker = "VaultDoor"},
        jewelry = {Name = "Aurelia Jewellers", Reward = 2900, Stars = 2, HackSeconds = 8, Steps = 4, CollectSeconds = 4, Cooldown = 140, MinEscapeSeconds = 10, StartMarker = "JewelryTerminal", LootMarker = "JewelryLoot", DoorMarker = "JewelryCaseDoor"},
        convoy = {Name = "Armored Van", Reward = 2300, Stars = 2, HackSeconds = 4, Steps = 2, CollectSeconds = 3, Cooldown = 110, MinEscapeSeconds = 15, StartMarker = "ConvoyStart", LootMarker = "ConvoyLoot"},
    },
    Heist = {Duration = 240, MaxCrew = 4},
    Properties = {
        marina = {Name="Marina Residence",Price=18000,DeskMarker="HomeDesk",EnterMarker="HomeEnter",InsideMarker="HomeInside",OutsideMarker="HomeLeave",MapLocation="Apartment"},
        westwood = {Name="Westwood House",Price=32000,DeskMarker="WestwoodHomeDesk",EnterMarker="WestwoodHomeEnter",InsideMarker="WestwoodHomeInside",OutsideMarker="WestwoodHomeLeave",MapLocation="WestwoodHome"},
        northhill = {Name="North Hill Villa",Price=78000,DeskMarker="NorthHillHomeDesk",EnterMarker="NorthHillHomeEnter",InsideMarker="NorthHillHomeInside",OutsideMarker="NorthHillHomeLeave",MapLocation="NorthHillHome"},
    },
    Businesses = {
        courier = {Name="Harbor Express Franchise",Price=12000,Income=180,Interval=180,Marker="CourierBusiness"},
        autohaus = {Name="Aster Autohaus Workshop",Price=30000,Income=420,Interval=180,Marker="AutohausBusiness"},
    },
    DeliveryReward = 450, DeliverySeconds = 12, PayInterval = 180, PolicePay = 300,
    Vehicles = {
        commuter = {Name = "Aster Compact", Price = 0, Speed = 70, Acceleration = 26, Color = {68, 155, 173}},
        sport = {Name = "Vela GT", Price = 12500, Speed = 112, Acceleration = 39, Color = {232, 159, 71}},
        suv = {Name = "Ridgeback SUV", Price = 9800, Speed = 88, Acceleration = 28, Width = 7.2, Length = 12.5, Color = {110, 128, 119}},
        muscle = {Name = "Solara Muscle", Price = 17500, Speed = 118, Acceleration = 42, Width = 7, Length = 13, Color = {194, 80, 68}},
        van = {Name = "Harbor Utility Van", Price = 6500, Speed = 77, Acceleration = 24, Width = 7.2, Length = 14.5, Color = {220, 218, 199}},
        patrol = {Name = "Sentinel Patrol", Price = 0, Speed = 93, Acceleration = 32, Color = {34, 45, 63}, Police = true},
    },
    Locations = {
        Spawn = {72, 5, 68}, Police = {80, 5, -80}, Garage = {-84, 5, 75},
        Bank = {-84, 5, -85}, Prison = {0, 5, -360}, Release = {34, 5, -263},
        Docks = {286, 5, 115}, Apartment = {85, 5, 269}, Depot = {-267, 5, 80},
        Jewelry = {267, 5, 270}, School = {270, 5, 392}, Industrial = {-463, 5, 110}, Airport = {390, 5, 350},
        WestwoodHome = {-350,5,255}, NorthHillHome = {320,5,-340},
    },
    Map = {MinX = -550, MaxX = 500, MinZ = -505, MaxZ = 490},
}
return Config
