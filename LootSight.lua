--[[
        LootSight - item name + value ESP with chams, filters and carried-loot tracking
        repo: Toluwerr/Scripts-
        target: RUNAWAYS [beta] (placeId 118418618261207) - generic fallback for other games

        Data source: ReplicatedStorage.Data.LootData (live require when it replicates,
        baked copy of all 244 RUNAWAYS items as fallback). Loot in this game is Tool
        instances named after their LootData.Item key ("Coin", "GoldBar", "SawedOff"),
        skin variants carry a BaseTool attribute pointing at the base item.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local TAG_PREFIX = "__LootSight"
local HUD_NAME = "__LootSightHud"
local JUNK_VALUE = 25
local MAX_TRACKED = 350
local CHAM_LIMIT = 31
local SLOW_INTERVAL = 0.25

local GOLD = Color3.fromRGB(255, 200, 60)
local GRAY = Color3.fromRGB(178, 178, 178)
local WHITE = Color3.fromRGB(240, 240, 240)

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__LootSightCleanup) == "function" then
        pcall(Global.__LootSightCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[LootSight] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

-- Forward declarations so the engine can reference UI created later.
local Window
local statusLabel
local topLabel

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 3.5,
                })
        end)
end

-- =============================================================
-- Settings
-- =============================================================

local LootSettings = {
        Enabled = false,
        ShowName = true,
        ShowValue = true,
        ShowPrice = false,
        ShowCategory = false,
        ShowDistance = true,
        MinValue = 0,
        MaxDistance = 2000,
        HideJunk = false,
        Chams = true,
        ChamOpacity = 30,
        TierColors = true,
        ThroughWalls = true,
}

local AlertSettings = {
        Enabled = true,
        Threshold = 800,
        Sound = true,
}

local PlayerSettings = {
        Enabled = false,
        ShowName = true,
        ShowHealth = true,
        ShowDistance = true,
        CarriedValue = true,
        ShowCarriedItems = true,
        Highlight = true,
        TeamCheck = false,
        ThroughWalls = true,
        MaxDistance = 1500,
        Color = Color3.fromRGB(120, 170, 255),
}

local HudSettings = {
        Enabled = true,
}

-- =============================================================
-- Tier helpers
-- =============================================================

local TIERS = {
        { name = "Junk", color = Color3.fromRGB(158, 158, 158), min = 0 },
        { name = "Common", color = Color3.fromRGB(235, 235, 235), min = 25 },
        { name = "Uncommon", color = Color3.fromRGB(120, 220, 120), min = 100 },
        { name = "Rare", color = Color3.fromRGB(90, 170, 255), min = 300 },
        { name = "Epic", color = Color3.fromRGB(190, 110, 255), min = 800 },
        { name = "Legendary", color = Color3.fromRGB(255, 190, 60), min = 2000 },
        { name = "Mythic", color = Color3.fromRGB(255, 80, 120), min = 5000 },
}

local function tierFor(worth)
        local best = TIERS[1]
        for _, tier in ipairs(TIERS) do
                if worth >= tier.min then
                        best = tier
                end
        end
        return best
end

local function toHex(color)
        return string.format(
                "%02X%02X%02X",
                math.floor(color.R * 255 + 0.5),
                math.floor(color.G * 255 + 0.5),
                math.floor(color.B * 255 + 0.5)
        )
end

local function escapeRich(text)
        text = tostring(text)
        text = text:gsub("&", "&amp;")
        text = text:gsub("<", "&lt;")
        text = text:gsub(">", "&gt;")
        return text
end

local function rich(text, color)
        return string.format('<font color="#%s">%s</font>', toHex(color), text)
end

local function formatMoney(value)
        if value >= 1000000 then
                return string.format("$%.1fM", value / 1000000)
        end
        if value >= 10000 then
                return string.format("$%.1fK", value / 1000)
        end
        return string.format("$%g", value)
end

local function floor(value)
        return math.floor(value + 0.5)
end

-- =============================================================
-- Loot database (live require with baked fallback)
-- =============================================================

local BAKED_LOOT = {
                { Item = "Coin", DisplayName = "Coin", Category = "Cash", Value = 10, Price = 10 },
                { Item = "CoinStack", DisplayName = "Coin Stack", Category = "Cash", Value = 25, Price = 25 },
                { Item = "Bill", DisplayName = "Bill", Category = "Cash", Value = 50, Price = 50 },
                { Item = "BillStack", DisplayName = "Bill Stack", Category = "Cash", Value = 100, Price = 100 },
                { Item = "Roll", DisplayName = "Roll", Category = "Cash", Value = 250, Price = 250 },
                { Item = "Band", DisplayName = "Band", Category = "Cash", Value = 500, Price = 500 },
                { Item = "Bag", DisplayName = "Bag", Category = "Cash", Value = 1000, Price = 1000 },
                { Item = "Credz", DisplayName = "Credz", Category = "Cash", Value = 0, Price = 10000 },
                { Item = "Bandage", DisplayName = "Bandage", Category = "Medical", Value = 20, Price = 400 },
                { Item = "MedicBag", DisplayName = "Medic Bag", Category = "Medical", Value = 37.5, Price = 750 },
                { Item = "MedicPack", DisplayName = "Medic Pack", Category = "Medical", Value = 75, Price = 1500 },
                { Item = "Drip", DisplayName = "Drip", Category = "Food", Value = 15, Price = 30 },
                { Item = "BlueCow", DisplayName = "Blue Cow", Category = "Food", Value = 25, Price = 50 },
                { Item = "8Hop", DisplayName = "8Hop", Category = "Food", Value = 10, Price = 20 },
                { Item = "Corny", DisplayName = "Corny", Category = "Food", Value = 10, Price = 20 },
                { Item = "Chonks", DisplayName = "Chonks", Category = "Food", Value = 12, Price = 30 },
                { Item = "Banana", DisplayName = "Banana", Category = "Food", Value = 30, Price = 100 },
                { Item = "Apple", DisplayName = "Apple", Category = "Food", Value = 28, Price = 100 },
                { Item = "Hotdog", DisplayName = "Hotdog", Category = "Food", Value = 15, Price = 50 },
                { Item = "Sandwich", DisplayName = "Sandwich", Category = "Food", Value = 20, Price = 50 },
                { Item = "Burger", DisplayName = "Burger", Category = "Food", Value = 20, Price = 50 },
                { Item = "ChickenBucket", DisplayName = "Chicken Bucket", Category = "Food", Value = 40, Price = 50 },
                { Item = "Coffee", DisplayName = "Coffee", Category = "Food", Value = 20, Price = 50 },
                { Item = "Steak", DisplayName = "Steak", Category = "Food", Value = 30, Price = 50 },
                { Item = "Ribs", DisplayName = "Ribs", Category = "Food", Value = 35, Price = 50 },
                { Item = "Ramen", DisplayName = "Ramen", Category = "Food", Value = 30, Price = 50 },
                { Item = "Sushi", DisplayName = "Sushi", Category = "Food", Value = 35, Price = 50 },
                { Item = "CanFood", DisplayName = "CanFood", Category = "Food", Value = 5, Price = 50 },
                { Item = "Mints", DisplayName = "Mints", Category = "Food", Value = 25, Price = 60 },
                { Item = "Laptop", DisplayName = "Laptop", Category = "Electronic", Value = 350, Price = 550 },
                { Item = "Phone", DisplayName = "Phone", Category = "Electronic", Value = 400, Price = 250 },
                { Item = "Tablet", DisplayName = "Tablet", Category = "Electronic", Value = 250, Price = 250 },
                { Item = "PocketConsole", DisplayName = "Pocket Console", Category = "Electronic", Value = 310, Price = 250 },
                { Item = "Headset", DisplayName = "Headset", Category = "Electronic", Value = 400, Price = 250 },
                { Item = "HardDrive", DisplayName = "Hard Drive", Category = "Electronic", Value = 300, Price = 250 },
                { Item = "VHS", DisplayName = "VHS", Category = "Electronic", Value = 50, Price = 250 },
                { Item = "LightBulb", DisplayName = "Light Bulb", Category = "Electronic", Value = 500, Price = 250 },
                { Item = "FlipPhone", DisplayName = "Flip Phone", Category = "Electronic", Value = 350, Price = 250 },
                { Item = "Computer", DisplayName = "Computer", Category = "BigElectronic", Value = 550, Price = 800 },
                { Item = "Console", DisplayName = "Console", Category = "BigElectronic", Value = 400, Price = 600 },
                { Item = "Gramophone", DisplayName = "Gramophone", Category = "BigElectronic", Value = 3000, Price = 5000 },
                { Item = "ElectricGuitar", DisplayName = "Electric Guitar", Category = "BigElectronic", Value = 1300, Price = 2000 },
                { Item = "SoundSystem", DisplayName = "Sound System", Category = "BigElectronic", Value = 900, Price = 1000 },
                { Item = "TV", DisplayName = "TV", Category = "BigElectronic", Value = 300, Price = 500 },
                { Item = "Keyboard", DisplayName = "Keyboard", Category = "BigElectronic", Value = 1600, Price = 2000 },
                { Item = "Flute", DisplayName = "Flute", Category = "Household", Value = 250, Price = 2000 },
                { Item = "Trombone", DisplayName = "Trombone", Category = "BigElectronic", Value = 1400, Price = 2000 },
                { Item = "Trumpet", DisplayName = "Trumpet", Category = "BigElectronic", Value = 1000, Price = 2000 },
                { Item = "Plank", DisplayName = "Plank", Category = "Craftable", Value = 30, Price = 150 },
                { Item = "MetalSheet", DisplayName = "Metal Sheet", Category = "Craftable", Value = 60, Price = 500 },
                { Item = "PropaneTank", DisplayName = "Propane Tank", Category = "Craftable", Value = 100, Price = 400 },
                { Item = "ConstructionLight", DisplayName = "Construction Light", Category = "Craftable", Value = 80, Price = 300 },
                { Item = "Turret", DisplayName = "Turret", Category = "Craftable", Value = 1250, Price = 15000 },
                { Item = "Jammer", DisplayName = "Jammer", Category = "Craftable", Value = 1000, Price = 10000 },
                { Item = "Reactor", DisplayName = "Reactor", Category = "Craftable", Value = 1500, Price = 15000 },
                { Item = "WoodenChest", DisplayName = "Wooden Chest", Category = "Craftable", Value = 300, Price = 500 },
                { Item = "Trashbag", DisplayName = "Trashbag", Category = "Junk", Value = 10, Price = 30 },
                { Item = "ConcreteBlock", DisplayName = "Concrete Block", Category = "Junk", Value = 5, Price = 10 },
                { Item = "Plunger", DisplayName = "Plunger", Category = "Junk", Value = 8, Price = 20 },
                { Item = "Bucket", DisplayName = "Bucket", Category = "Junk", Value = 15, Price = 25 },
                { Item = "LifeBuoy", DisplayName = "Life Buoy", Category = "Junk", Value = 100, Price = 100 },
                { Item = "GlassBottle", DisplayName = "Glass Bottle", Category = "Junk", Value = 5, Price = 10 },
                { Item = "ScrapMetal", DisplayName = "Scrap Metal", Category = "Junk", Value = 10, Price = 35 },
                { Item = "Ink", DisplayName = "Ink", Category = "Junk", Value = 20, Price = 100 },
                { Item = "PaintCan", DisplayName = "Paint Can", Category = "Tool", Value = 60, Price = 400 },
                { Item = "Drill", DisplayName = "Drill", Category = "Tool", Value = 80, Price = 800 },
                { Item = "ToolBox", DisplayName = "Toolbox", Category = "Tool", Value = 120, Price = 1600 },
                { Item = "WantedPoster", DisplayName = "Wanted Poster", Category = "Tool", Value = 0, Price = 0 },
                { Item = "LumberyardKey", DisplayName = "Lumberyard Key", Category = "Tool", Value = 200, Price = 0 },
                { Item = "PirateSkull", DisplayName = "Pirate Skull", Category = "Tool", Value = 1500, Price = 0 },
                { Item = "GovFile", DisplayName = "Gov File", Category = "Tool", Value = 2000, Price = 0 },
                { Item = "Lockpick", DisplayName = "Lockpick", Category = "Tool", Value = 50, Price = 500 },
                { Item = "Jerrycan", DisplayName = "Jerrycan", Category = "VehiclePart", Value = 30, Price = 500 },
                { Item = "Wheel", DisplayName = "Wheel", Category = "VehiclePart", Value = 225, Price = 450 },
                { Item = "Tire", DisplayName = "Tire", Category = "VehiclePart", Value = 125, Price = 400 },
                { Item = "Barrel", DisplayName = "Barrel", Category = "VehiclePart", Value = 100, Price = 2000 },
                { Item = "BoostBottle", DisplayName = "Boost Bottle", Category = "VehiclePart", Value = 50, Price = 800 },
                { Item = "SnowPlowArmor", DisplayName = "Snowplow Armor", Category = "VehiclePart", Value = 500, Price = 4500 },
                { Item = "RammingPlate", DisplayName = "Ramming Plate", Category = "VehiclePart", Value = 300, Price = 3500 },
                { Item = "SpikePlate", DisplayName = "Spike Plate", Category = "VehiclePart", Value = 200, Price = 3000 },
                { Item = "Crowbar", DisplayName = "Crowbar", Category = "Weapon", Value = 40, Price = 800 },
                { Item = "Bat", DisplayName = "Bat", Category = "Weapon", Value = 25, Price = 500 },
                { Item = "Machete", DisplayName = "Machete", Category = "Weapon", Value = 85, Price = 1700 },
                { Item = "Mace", DisplayName = "Mace", Category = "Weapon", Value = 125, Price = 2500 },
                { Item = "Knuckle", DisplayName = "Knuckle", Category = "Weapon", Value = 140, Price = 2800 },
                { Item = "Pan", DisplayName = "Pan", Category = "Weapon", Value = 50, Price = 1000 },
                { Item = "Axe", DisplayName = "Axe", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "Baton", DisplayName = "Baton", Category = "Weapon", Value = 50, Price = 50000 },
                { Item = "RiotShield", DisplayName = "Riot Shield", Category = "Weapon", Value = 200, Price = 100000 },
                { Item = "Sword", DisplayName = "Sword", Category = "Weapon", Value = 8000, Price = 50000 },
                { Item = "Pistol", DisplayName = "Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "Shotgun", DisplayName = "Shotgun", Category = "Weapon", Value = 110, Price = 2200 },
                { Item = "SawedOff", DisplayName = "Sawed-Off", Category = "Weapon", Value = 95, Price = 1900 },
                { Item = "MAC", DisplayName = "MAC", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "AK", DisplayName = "AK", Category = "Weapon", Value = 225, Price = 4500 },
                { Item = "M4", DisplayName = "M4", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "Sniper", DisplayName = "Sniper", Category = "Weapon", Value = 600, Price = 12000 },
                { Item = "Revolver", DisplayName = "Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "RPG7", DisplayName = "RPG7", Category = "Weapon", Value = 450, Price = 9000 },
                { Item = "Flamethrower", DisplayName = "Flamethrower", Category = "Weapon", Value = 350, Price = 7000 },
                { Item = "Minigun", DisplayName = "Minigun", Category = "Weapon", Value = 1000, Price = 20000 },
                { Item = "GrenadeLauncher", DisplayName = "Grenade Launcher", Category = "Weapon", Value = 500, Price = 10000 },
                { Item = "Molotov", DisplayName = "Molotov", Category = "Weapon", Value = 12.5, Price = 250 },
                { Item = "Grenade", DisplayName = "Grenade", Category = "Weapon", Value = 17.5, Price = 350 },
                { Item = "C4", DisplayName = "C4", Category = "Weapon", Value = 30, Price = 600 },
                { Item = "Cleaver", DisplayName = "Cleaver", Category = "Weapon", Value = 600, Price = 600 },
                { Item = "Chainsaw", DisplayName = "Chainsaw", Category = "Weapon", Value = 1200, Price = 600 },
                { Item = "SoundCannon", DisplayName = "Sound Cannon", Category = "Weapon", Value = 3000, Price = 600 },
                { Item = "NailGun", DisplayName = "Nail Gun", Category = "Weapon", Value = 700, Price = 600 },
                { Item = "SugarBomb", DisplayName = "Sugar Bomb", Category = "Weapon", Value = 20, Price = 350 },
                { Item = "MinigunPlatted", DisplayName = "Platted Minigun", Category = "Weapon", Value = 1000, Price = 20000 },
                { Item = "MacePlatted", DisplayName = "Platted Mace", Category = "Weapon", Value = 125, Price = 2500 },
                { Item = "PistolPlatted", DisplayName = "Platted Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "RevolverFalcon", DisplayName = "Falcon Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "PistolBounty", DisplayName = "Bounty Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "MacheteBounty", DisplayName = "Bounty Machete", Category = "Weapon", Value = 85, Price = 1700 },
                { Item = "PistolTactical", DisplayName = "Tactical Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "ShotgunTactical", DisplayName = "Tactical Shotgun", Category = "Weapon", Value = 110, Price = 2200 },
                { Item = "M4Tactical", DisplayName = "Tactical M4", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "AKToy", DisplayName = "Toy AK", Category = "Weapon", Value = 225, Price = 4500 },
                { Item = "RPG7Toy", DisplayName = "Toy RPG", Category = "Weapon", Value = 450, Price = 9000 },
                { Item = "MacheteOld", DisplayName = "Old Machete", Category = "Weapon", Value = 85, Price = 1700 },
                { Item = "PanOld", DisplayName = "Old Pan", Category = "Weapon", Value = 50, Price = 1000 },
                { Item = "AxeOld", DisplayName = "Old Axe", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "MaceOld", DisplayName = "Old Mace", Category = "Weapon", Value = 125, Price = 2500 },
                { Item = "AKMafia", DisplayName = "Mafia AK", Category = "Weapon", Value = 225, Price = 4500 },
                { Item = "RevolverMafia", DisplayName = "Mafia Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "ShotgunClassic", DisplayName = "Classic Shotgun", Category = "Weapon", Value = 110, Price = 2200 },
                { Item = "MACVintage", DisplayName = "Vintage MAC", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "SawedOffModern", DisplayName = "Modern SawedOff", Category = "Weapon", Value = 95, Price = 1900 },
                { Item = "SniperOld", DisplayName = "Old Sniper", Category = "Weapon", Value = 600, Price = 12000 },
                { Item = "GrenadeLauncherOld", DisplayName = "Old Grenade Launcher", Category = "Weapon", Value = 500, Price = 10000 },
                { Item = "RevolverSherrif", DisplayName = "Sheriff Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "BatToy", DisplayName = "Toy Bat", Category = "Weapon", Value = 25, Price = 500 },
                { Item = "KnuckleMetal", DisplayName = "Metal Knuckle", Category = "Weapon", Value = 140, Price = 2800 },
                { Item = "RPG7Dragon", DisplayName = "Dragon RPG", Category = "Weapon", Value = 450, Price = 9000 },
                { Item = "KnuckleDragon", DisplayName = "Dragon Knuckle", Category = "Weapon", Value = 140, Price = 2800 },
                { Item = "RPG7Plunger", DisplayName = "Plunger RPG", Category = "Weapon", Value = 450, Price = 9000 },
                { Item = "SniperAngel", DisplayName = "Angel Sniper", Category = "Weapon", Value = 600, Price = 12000 },
                { Item = "SniperTactical", DisplayName = "Tactical Sniper", Category = "Weapon", Value = 600, Price = 12000 },
                { Item = "PistolBanana", DisplayName = "Banana Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "RevolverMini", DisplayName = "Mini Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "RevolverStrong", DisplayName = "Strong Revolver", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "MACTactical", DisplayName = "Tactical MAC", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "ShotgunBulldog", DisplayName = "Bulldog Shotgun", Category = "Weapon", Value = 110, Price = 2200 },
                { Item = "FlamethrowerModern", DisplayName = "Modern Flamethrower", Category = "Weapon", Value = 350, Price = 7000 },
                { Item = "MinigunVintage", DisplayName = "Vintage Minigun", Category = "Weapon", Value = 1000, Price = 20000 },
                { Item = "PistolShredder", DisplayName = "Shredder Pistol", Category = "Weapon", Value = 75, Price = 1500 },
                { Item = "M4Chained", DisplayName = "Chained M4", Category = "Weapon", Value = 250, Price = 5000 },
                { Item = "BatSandwich", DisplayName = "Sandwich Bat", Category = "Weapon", Value = 25, Price = 500 },
                { Item = "BatAztec", DisplayName = "Aztec Bat", Category = "Weapon", Value = 25, Price = 500 },
                { Item = "CrowbarTaped", DisplayName = "Taped Crowbar", Category = "Weapon", Value = 40, Price = 800 },
                { Item = "CrowbarPipe", DisplayName = "Pipe Crowbar", Category = "Weapon", Value = 40, Price = 800 },
                { Item = "CrowbarWrench", DisplayName = "Wrench Crowbar", Category = "Weapon", Value = 40, Price = 800 },
                { Item = "MacheteSerrated", DisplayName = "Serrated Machete", Category = "Weapon", Value = 85, Price = 1700 },
                { Item = "PanTennis", DisplayName = "Tennis Pan", Category = "Weapon", Value = 50, Price = 1000 },
                { Item = "PanEgg", DisplayName = "Egg Pan", Category = "Weapon", Value = 50, Price = 1000 },
                { Item = "AxeViking", DisplayName = "Viking Axe", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "AxeStop", DisplayName = "Stop Axe", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "MacePickaxe", DisplayName = "Pickaxe Mace", Category = "Weapon", Value = 125, Price = 2500 },
                { Item = "MaceShroom", DisplayName = "Shroom Mace", Category = "Weapon", Value = 125, Price = 2500 },
                { Item = "KnucklePunk", DisplayName = "Punk Knuckle", Category = "Weapon", Value = 140, Price = 2800 },
                { Item = "AxeDeepSea", DisplayName = "Deep-Sea Axe", Category = "Weapon", Value = 100, Price = 2000 },
                { Item = "SawedOffDeepSea", DisplayName = "Deep-Sea Sawed-Off", Category = "Weapon", Value = 95, Price = 1900 },
                { Item = "SilverNecklace", DisplayName = "Silver Necklace", Category = "Valuable", Value = 160, Price = 850 },
                { Item = "GoldNecklace", DisplayName = "Gold Necklace", Category = "Valuable", Value = 210, Price = 850 },
                { Item = "SilverSapphireNecklace", DisplayName = "Silver Sapphire Necklace", Category = "Valuable", Value = 285, Price = 850 },
                { Item = "GoldRubyNecklace", DisplayName = "Gold Ruby Necklace", Category = "Valuable", Value = 350, Price = 850 },
                { Item = "GoldDiamondNecklace", DisplayName = "Gold Diamond Necklace", Category = "Valuable", Value = 650, Price = 850 },
                { Item = "SilverTiara", DisplayName = "Silver Tiara", Category = "Valuable", Value = 235, Price = 850 },
                { Item = "GoldTiara", DisplayName = "Gold Tiara", Category = "Valuable", Value = 705, Price = 850 },
                { Item = "KingCrown", DisplayName = "King Crown", Category = "Valuable", Value = 1500, Price = 850 },
                { Item = "SilverBracelet", DisplayName = "Silver Bracelet", Category = "Valuable", Value = 100, Price = 400 },
                { Item = "GoldBracelet", DisplayName = "Gold Bracelet", Category = "Valuable", Value = 140, Price = 600 },
                { Item = "SilverWatch", DisplayName = "Silver Watch", Category = "Valuable", Value = 142, Price = 450 },
                { Item = "GoldWatch", DisplayName = "Gold Watch", Category = "Valuable", Value = 220, Price = 900 },
                { Item = "DiamondWatch", DisplayName = "Diamond Watch", Category = "Valuable", Value = 355, Price = 450 },
                { Item = "SilverRing", DisplayName = "Silver Ring", Category = "Valuable", Value = 100, Price = 300 },
                { Item = "GoldRing", DisplayName = "Gold Ring", Category = "Valuable", Value = 130, Price = 300 },
                { Item = "EmeraldRing", DisplayName = "Emerald Ring", Category = "Valuable", Value = 160, Price = 500 },
                { Item = "SapphireRing", DisplayName = "Sapphire Ring", Category = "Valuable", Value = 210, Price = 500 },
                { Item = "RubyRing", DisplayName = "Ruby Ring", Category = "Valuable", Value = 320, Price = 500 },
                { Item = "DiamondRing", DisplayName = "Diamond Ring", Category = "Valuable", Value = 730, Price = 500 },
                { Item = "Wallet", DisplayName = "Wallet", Category = "Valuable", Value = 100, Price = 100 },
                { Item = "Emerald", DisplayName = "Emerald", Category = "Valuable", Value = 225, Price = 2000 },
                { Item = "Sapphire", DisplayName = "Sapphire", Category = "Valuable", Value = 270, Price = 2000 },
                { Item = "Ruby", DisplayName = "Ruby", Category = "Valuable", Value = 360, Price = 2250 },
                { Item = "Diamond", DisplayName = "Diamond", Category = "Valuable", Value = 720, Price = 3000 },
                { Item = "BronzeBar", DisplayName = "Bronze Bar", Category = "Valuable", Value = 170, Price = 2600 },
                { Item = "SilverBar", DisplayName = "Silver Bar", Category = "Valuable", Value = 265, Price = 2600 },
                { Item = "GoldBar", DisplayName = "Gold Bar", Category = "Valuable", Value = 500, Price = 2600 },
                { Item = "CatStatue", DisplayName = "Cat Statue", Category = "Valuable", Value = 1800, Price = 3500 },
                { Item = "StatueThinker", DisplayName = "Statue Thinker", Category = "Valuable", Value = 1000, Price = 2500 },
                { Item = "Trophy", DisplayName = "Trophy", Category = "Valuable", Value = 200, Price = 1400 },
                { Item = "Pearl", DisplayName = "Pearl", Category = "Painting", Value = 300, Price = 3500 },
                { Item = "WeirdDame", DisplayName = "Weird Dame", Category = "Painting", Value = 250, Price = 3000 },
                { Item = "NightSky", DisplayName = "Night Sky", Category = "Painting", Value = 310, Price = 4000 },
                { Item = "Neoplast", DisplayName = "Neoplast", Category = "Painting", Value = 300, Price = 3300 },
                { Item = "HappyWife", DisplayName = "Happy Wife", Category = "Painting", Value = 350, Price = 4500 },
                { Item = "WildCat", DisplayName = "Wild Cat", Category = "Painting", Value = 275, Price = 4500 },
                { Item = "CherryPeak", DisplayName = "Cherry Peak", Category = "Painting", Value = 230, Price = 4500 },
                { Item = "Dumbbell", DisplayName = "Dumbbell", Category = "Household", Value = 35, Price = 400 },
                { Item = "Box", DisplayName = "Box", Category = "Household", Value = 10, Price = 30 },
                { Item = "Mug", DisplayName = "Mug", Category = "Household", Value = 5, Price = 30 },
                { Item = "Toaster", DisplayName = "Toaster", Category = "Household", Value = 25, Price = 75 },
                { Item = "Basketball", DisplayName = "Basketball", Category = "Household", Value = 15, Price = 100 },
                { Item = "WateringCan", DisplayName = "Watering Can", Category = "Household", Value = 12, Price = 100 },
                { Item = "PinguinPlushy", DisplayName = "Pinguin Plushy", Category = "Household", Value = 567, Price = 1500 },
                { Item = "MovingBox", DisplayName = "Moving Box", Category = "Household", Value = 300, Price = 1500 },
                { Item = "Book", DisplayName = "Book", Category = "Household", Value = 20, Price = 1500 },
                { Item = "ArtBook", DisplayName = "Art Book", Category = "Household", Value = 350, Price = 1500 },
                { Item = "Briefcase", DisplayName = "Briefcase", Category = "Household", Value = 1000, Price = 2000 },
                { Item = "Toothbrush", DisplayName = "Toothbrush", Category = "Household", Value = 20, Price = 40 },
                { Item = "RubberDucky", DisplayName = "Rubber Ducky", Category = "Household", Value = 30, Price = 60 },
                { Item = "Pants", DisplayName = "Pants", Category = "Household", Value = 15, Price = 60 },
                { Item = "Shirt", DisplayName = "Shirt", Category = "Household", Value = 20, Price = 60 },
                { Item = "Socks", DisplayName = "Socks", Category = "Household", Value = 10, Price = 60 },
                { Item = "BulletPackHeavy", DisplayName = "Bullet Pack Heavy", Category = "Ammo", Value = 25, Price = 500 },
                { Item = "BulletPackLight", DisplayName = "Bullet Pack Light", Category = "Ammo", Value = 10, Price = 200 },
                { Item = "BulletPackExplosive", DisplayName = "Bullet Pack Explosive", Category = "Ammo", Value = 32.5, Price = 650 },
                { Item = "BulletPackShotgun", DisplayName = "Bullet Pack Shotgun", Category = "Ammo", Value = 15, Price = 300 },
                { Item = "BulletBoxLight", DisplayName = "Bullet Box Light", Category = "Ammo", Value = 100, Price = 2000 },
                { Item = "BulletBoxHeavy", DisplayName = "Bullet Box Heavy", Category = "Ammo", Value = 100, Price = 2000 },
                { Item = "BulletBoxExplosive", DisplayName = "Bullet Box Explosive", Category = "Ammo", Value = 100, Price = 2000 },
                { Item = "BulletBoxShotgun", DisplayName = "Bullet Box Shotgun", Category = "Ammo", Value = 100, Price = 2000 },
                { Item = "BackpackSmall", DisplayName = "Backpack Small", Category = "Backpack", Value = 50, Price = 1000 },
                { Item = "BackpackMedium", DisplayName = "Backpack Medium", Category = "Backpack", Value = 250, Price = 5000 },
                { Item = "BackpackLarge", DisplayName = "Backpack Large", Category = "Backpack", Value = 600, Price = 12000 },
                { Item = "ArmorLight", DisplayName = "Armor Light", Category = "Armor", Value = 100, Price = 2000 },
                { Item = "ArmorHeavy", DisplayName = "Armor Heavy", Category = "Armor", Value = 500, Price = 10000 },
                { Item = "GrenadeLauncherAsPlushyLauncher", DisplayName = "Hug Launcher", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "PinguinPlushyAsMolotov", DisplayName = "Warm Pinguin", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "MinigunAsLaser", DisplayName = "Space Minigun", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "HotdogLarge", DisplayName = "Thick Hotdog", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "Demon", DisplayName = "Demon", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "BananaAsGrenade", DisplayName = "Oddly Heavy Banana", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "BananaAsPistol", DisplayName = "Concealed Banana", Category = "Secret", Value = 0, Price = 100000 },
                { Item = "CatStatueLarge", DisplayName = "Inflated Cat Statue", Category = "Secret", Value = 5000, Price = 100000 },
                { Item = "LaptopOGRoblox", DisplayName = "OG Roblox Gamer Laptop", Category = "Secret", Value = 1500, Price = 100000 },
                { Item = "RubyLarge", DisplayName = "Large Ruby", Category = "Secret", Value = 450, Price = 100000 },
                { Item = "SapphireLarge", DisplayName = "Large Sapphire", Category = "Secret", Value = 340, Price = 100000 },
                { Item = "EmeraldLarge", DisplayName = "Large Emerald", Category = "Secret", Value = 290, Price = 100000 },
                { Item = "SawedOffTrust", DisplayName = "Yeet Cannon", Category = "Secret", Value = 5000, Price = 100000 },
                { Item = "DiamondLarge", DisplayName = "Large Diamond", Category = "Secret", Value = 900, Price = 100000 },
}

local byItem = {}
local dbSource = "none"
local dbCount = 0

local function effectiveValue(info)
        if info.v > 0 then
                return info.v
        end
        return info.p
end

local function buildLookup(list)
        local lookup = {}
        for _, entry in ipairs(list) do
                if type(entry) == "table" and type(entry.Item) == "string" then
                        lookup[entry.Item] = {
                                d = entry.DisplayName or entry.Item,
                                c = entry.Category or "?",
                                v = tonumber(entry.Value) or 0,
                                p = tonumber(entry.Price) or 0,
                        }
                end
        end
        return lookup
end

local function loadLootDatabase()
        local ok, live = pcall(function()
                local dataFolder = ReplicatedStorage:FindFirstChild("Data")
                if not dataFolder then
                        dataFolder = ReplicatedStorage:WaitForChild("Data", 6)
                end
                if not dataFolder then
                        return nil
                end
                local module = dataFolder:FindFirstChild("LootData")
                        or dataFolder:WaitForChild("LootData", 3)
                if not module then
                        return nil
                end
                return require(module)
        end)

        if ok and type(live) == "table" then
                byItem = buildLookup(live)
                dbSource = "live"
        else
                byItem = buildLookup(BAKED_LOOT)
                dbSource = "baked"
        end

        dbCount = 0
        for _ in pairs(byItem) do
                dbCount = dbCount + 1
        end
end

local function topLootLines(count)
        local list = {}
        for _, info in pairs(byItem) do
                table.insert(list, info)
        end
        table.sort(list, function(a, b)
                return effectiveValue(a) > effectiveValue(b)
        end)
        local lines = {}
        for i = 1, math.min(count, #list) do
                local info = list[i]
                table.insert(lines, string.format(
                        "%d. %s - %s",
                        i,
                        info.d,
                        formatMoney(effectiveValue(info))
                ))
        end
        return table.concat(lines, "\n")
end

-- =============================================================
-- Detection helpers
-- =============================================================

-- No container exclusions by design: any instance that resolves to an item
-- with a value is tracked - world loot, shop/case displays, reward stations
-- and weapons carried or holstered on players alike. Visibility is controlled
-- only by the user-facing filters (Min Value / Max Distance / Hide Junk).

local function resolveItem(inst)
        local info = byItem[inst.Name]
        if info then
                return info, inst.Name
        end

        local base = inst:GetAttribute("BaseTool")
        if type(base) == "string" then
                info = byItem[base]
                if info then
                        return info, base
                end
        end

        -- Generic fallback for other games: instances tagged with a value.
        local value = inst:GetAttribute("Value")
        if type(value) ~= "number" then
                value = inst:GetAttribute("Price")
        end
        if type(value) == "number" then
                return { d = inst.Name, c = "Other", v = value, p = value }, inst.Name
        end

        return nil
end

local function getAdornee(inst)
        if inst:IsA("Tool") then
                local handle = inst:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                        return handle
                end
                return inst:FindFirstChildWhichIsA("BasePart", true)
        end
        if inst:IsA("Model") then
                return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        end
        if inst:IsA("BasePart") then
                return inst
        end
        return nil
end

-- =============================================================
-- Loot ESP engine
-- =============================================================

local running = true
local connections = {}
local trackedLoot = {}
local trackedCount = 0
local trackedPlayers = {}
local lastAlertAt = {}
local scanning = false
local hudGui, hudStatsLabel, hudBestLabel, hudYouLabel
local alertSound

local function untrackLoot(inst)
        local rec = trackedLoot[inst]
        if not rec then
                return
        end
        trackedLoot[inst] = nil
        trackedCount = trackedCount - 1
        if rec.billboard then
                pcall(function()
                        rec.billboard:Destroy()
                end)
        end
        if rec.highlight then
                pcall(function()
                        rec.highlight:Destroy()
                end)
        end
end

local function untrackPlayer(player)
        local rec = trackedPlayers[player]
        if not rec then
                return
        end
        trackedPlayers[player] = nil
        if rec.billboard then
                pcall(function()
                        rec.billboard:Destroy()
                end)
        end
        if rec.highlight then
                pcall(function()
                        rec.highlight:Destroy()
                end)
        end
end

local function buildLootText(rec)
        local info = rec.info
        local tier = tierFor(effectiveValue(info))
        local lines = {}

        if LootSettings.ShowName then
                table.insert(lines, rich("<b>" .. escapeRich(info.d) .. "</b>", tier.color))
        end

        if LootSettings.ShowValue then
                if info.v > 0 then
                        table.insert(lines, rich("<b>" .. formatMoney(info.v) .. "</b>", tier.color))
                elseif info.p > 0 then
                        table.insert(lines, rich(
                                "<b>" .. formatMoney(info.p) .. "</b> (shop)",
                                tier.color
                        ))
                end
        end

        if LootSettings.ShowPrice and info.p > 0 then
                table.insert(lines, rich("shop " .. formatMoney(info.p), GRAY))
        end

        if LootSettings.ShowCategory then
                table.insert(lines, rich(escapeRich(info.c), GRAY))
        end

        if LootSettings.ShowDistance then
                table.insert(lines, rich(rec.distance .. " studs", GRAY))
        end

        return table.concat(lines, "\n")
end

local function ensureLootAdornments(rec)
        local inst = rec.instance

        local billboard = Instance.new("BillboardGui")
        billboard.Name = TAG_PREFIX .. "Tag"
        billboard.Size = UDim2.fromOffset(220, 76)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
        billboard.LightInfluence = 0
        billboard.MaxDistance = LootSettings.MaxDistance
        billboard.AlwaysOnTop = LootSettings.ThroughWalls
        billboard.Enabled = false

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextWrapped = true
        label.RichText = true
        label.Text = ""
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0.25
        label.Parent = billboard

        local highlight = Instance.new("Highlight")
        highlight.Name = TAG_PREFIX .. "Cham"
        highlight.FillTransparency = 1 - (LootSettings.ChamOpacity / 100)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = LootSettings.ThroughWalls
                        and Enum.HighlightDepthMode.AlwaysOnTop
                        or Enum.HighlightDepthMode.Occluded
        highlight.Enabled = false

        billboard.Adornee = rec.adornee
        billboard.Parent = inst
        highlight.Parent = inst

        rec.billboard = billboard
        rec.label = label
        rec.highlight = highlight
        rec.worth = effectiveValue(rec.info)
end

local function playAlertSound()
        pcall(function()
                if not alertSound then
                        alertSound = Instance.new("Sound")
                        alertSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
                        alertSound.Volume = 0.6
                        alertSound.Parent = SoundService
                end
                SoundService:PlayLocalSound(alertSound)
        end)
end

local function maybeAlert(rec)
        if not AlertSettings.Enabled or scanning then
                return
        end
        local worth = rec.worth
        if worth < AlertSettings.Threshold then
                return
        end
        local now = os.clock()
        if lastAlertAt[rec.key] and now - lastAlertAt[rec.key] < 5 then
                return
        end
        lastAlertAt[rec.key] = now
        notify("Rare loot spotted", string.format(
                "%s worth %s (%s)",
                rec.info.d,
                formatMoney(worth),
                tierFor(worth).name
        ))
        if AlertSettings.Sound then
                playAlertSound()
        end
end

local function onInstanceAdded(inst)
        if not running or not LootSettings.Enabled then
                return
        end
        if trackedLoot[inst] then
                return
        end
        local className = inst.ClassName
        if className ~= "Tool" and className ~= "Model" and className ~= "MeshPart" then
                return
        end
        if inst.Name:sub(1, #TAG_PREFIX) == TAG_PREFIX then
                return
        end

        local info, key = resolveItem(inst)
        if not info then
                return
        end

        local adornee = getAdornee(inst)
        if not adornee then
                return
        end

        local worth = effectiveValue(info)
        if trackedCount >= MAX_TRACKED and worth < 300 then
                return
        end

        local rec = {
                instance = inst,
                info = info,
                key = key,
                adornee = adornee,
                distance = 0,
        }
        local ok = pcall(ensureLootAdornments, rec)
        if not ok then
                return
        end

        trackedLoot[inst] = rec
        trackedCount = trackedCount + 1
        maybeAlert(rec)
end

local function scanWorkspace()
        scanning = true
        local ok, descendants = pcall(function()
                return Workspace:GetDescendants()
        end)
        if ok and type(descendants) == "table" then
                for _, inst in ipairs(descendants) do
                        pcall(onInstanceAdded, inst)
                end
        end
        scanning = false
end

local function clearTrackedLoot()
        for inst in pairs(trackedLoot) do
                untrackLoot(inst)
        end
end

local function updateLootRecord(inst, localRoot)
        local rec = trackedLoot[inst]
        if not rec then
                return
        end

        if not inst.Parent or not rec.adornee or not rec.adornee.Parent then
                untrackLoot(inst)
                return
        end

        local position = rec.adornee.Position
        local distance = (position - localRoot.Position).Magnitude
        rec.distance = distance
        rec.worth = effectiveValue(rec.info)

        local visible = distance <= LootSettings.MaxDistance
                and rec.worth >= LootSettings.MinValue
                and not (LootSettings.HideJunk and rec.worth < JUNK_VALUE)

        if not visible then
                if rec.billboard then
                        rec.billboard.Enabled = false
                end
                if rec.highlight then
                        rec.highlight.Enabled = false
                end
                return
        end

        if rec.billboard then
                rec.billboard.Enabled = true
                rec.billboard.MaxDistance = LootSettings.MaxDistance
                rec.billboard.AlwaysOnTop = LootSettings.ThroughWalls
                rec.label.Text = buildLootText(rec)
        end
end

-- =============================================================
-- Player ESP engine (name / health / distance / carried loot value)
-- =============================================================

local function isTeammate(player)
        return PlayerSettings.TeamCheck
                and LocalPlayer.Team ~= nil
                and player.Team == LocalPlayer.Team
end

local function computeCarried(player)
        local total, count, names = 0, 0, {}
        local containers = {}

        local backpack = player:FindFirstChild("Backpack")
        if backpack then
                table.insert(containers, backpack)
        end
        if player.Character then
                table.insert(containers, player.Character)
        end

        for _, container in ipairs(containers) do
                local ok, tools = pcall(function()
                        local found = {}
                        for _, desc in ipairs(container:GetDescendants()) do
                                if desc:IsA("Tool") then
                                        table.insert(found, desc)
                                end
                        end
                        return found
                end)
                if ok and type(tools) == "table" then
                        for _, tool in ipairs(tools) do
                                local info = resolveItem(tool)
                                if info then
                                        local worth = effectiveValue(info)
                                        total = total + worth
                                        count = count + 1
                                        table.insert(names, { name = info.d, value = worth })
                                end
                        end
                end
        end

        table.sort(names, function(a, b)
                return a.value > b.value
        end)

        return total, count, names
end

local function ensurePlayerAdornments(player, character, root)
        local rec = trackedPlayers[player]

        if rec and rec.character ~= character then
                untrackPlayer(player)
                rec = nil
        end

        if not rec then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = TAG_PREFIX .. "PlayerTag"
                billboard.Size = UDim2.fromOffset(260, 104)
                billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
                billboard.LightInfluence = 0
                billboard.MaxDistance = PlayerSettings.MaxDistance
                billboard.AlwaysOnTop = PlayerSettings.ThroughWalls

                local label = Instance.new("TextLabel")
                label.Name = "Text"
                label.BackgroundTransparency = 1
                label.Size = UDim2.fromScale(1, 1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.TextWrapped = true
                label.RichText = true
                label.Text = ""
                label.TextXAlignment = Enum.TextXAlignment.Center
                label.TextYAlignment = Enum.TextYAlignment.Center
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.TextStrokeTransparency = 0.25
                label.Parent = billboard

                local highlight = Instance.new("Highlight")
                highlight.Name = TAG_PREFIX .. "PlayerCham"

                billboard.Adornee = root
                billboard.Parent = character
                highlight.Parent = character

                rec = {
                        character = character,
                        billboard = billboard,
                        label = label,
                        highlight = highlight,
                        distance = 0,
                        carriedTotal = 0,
                        carriedCount = 0,
                        carriedNames = {},
                        carriedAt = -999,
                }
                trackedPlayers[player] = rec
        end

        return rec
end

local function buildPlayerText(rec, player, humanoid)
        local lines = {}

        if PlayerSettings.ShowName then
                local displayName = player.DisplayName ~= "" and player.DisplayName or player.Name
                table.insert(lines, rich("<b>" .. escapeRich(displayName) .. "</b>", PlayerSettings.Color))
        end

        if PlayerSettings.CarriedValue then
                if rec.carriedCount > 0 then
                        local moneyPart = rich(
                                "<b>" .. formatMoney(rec.carriedTotal) .. "</b>",
                                GOLD
                        )
                        local countPart = rich(" " .. rec.carriedCount .. " items", GRAY)
                        table.insert(lines, moneyPart .. countPart)
                else
                        table.insert(lines, rich("empty-handed", GRAY))
                end
        end

        if PlayerSettings.ShowCarriedItems and #rec.carriedNames > 0 then
                local shown = {}
                for i = 1, math.min(3, #rec.carriedNames) do
                        table.insert(shown, escapeRich(rec.carriedNames[i].name))
                end
                local text = table.concat(shown, ", ")
                if #rec.carriedNames > 3 then
                        text = text .. " +" .. (#rec.carriedNames - 3)
                end
                table.insert(lines, rich(text, GRAY))
        end

        if PlayerSettings.ShowHealth then
                table.insert(lines, rich(string.format(
                        "%d/%d HP",
                        floor(humanoid.Health),
                        floor(humanoid.MaxHealth)
                ), WHITE))
        end

        if PlayerSettings.ShowDistance then
                table.insert(lines, rich(floor(rec.distance) .. " studs", GRAY))
        end

        return table.concat(lines, "\n")
end

local function updatePlayerEsp(player, localRoot, tickCount)
        if not PlayerSettings.Enabled or player == LocalPlayer then
                if trackedPlayers[player] then
                        untrackPlayer(player)
                end
                return
        end

        local character = player.Character
        if not character then
                if trackedPlayers[player] then
                        untrackPlayer(player)
                end
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        if not humanoid or humanoid.Health <= 0 or not root or not localRoot then
                if trackedPlayers[player] then
                        untrackPlayer(player)
                end
                return
        end

        if PlayerSettings.TeamCheck and isTeammate(player) then
                if trackedPlayers[player] then
                        untrackPlayer(player)
                end
                return
        end

        local distance = (root.Position - localRoot.Position).Magnitude
        if distance > PlayerSettings.MaxDistance then
                if trackedPlayers[player] then
                        untrackPlayer(player)
                end
                return
        end

        local rec = ensurePlayerAdornments(player, character, root)
        rec.distance = distance

        if not rec.carriedAt or tickCount - rec.carriedAt >= 4 then
                local total, count, names = computeCarried(player)
                rec.carriedTotal = total
                rec.carriedCount = count
                rec.carriedNames = names
                rec.carriedAt = tickCount
        end

        if rec.highlight then
                rec.highlight.Enabled = PlayerSettings.Highlight
                rec.highlight.FillColor = PlayerSettings.Color
                rec.highlight.OutlineColor = PlayerSettings.Color
                rec.highlight.FillTransparency = 0.72
                rec.highlight.OutlineTransparency = 0
                rec.highlight.DepthMode = PlayerSettings.ThroughWalls
                        and Enum.HighlightDepthMode.AlwaysOnTop
                        or Enum.HighlightDepthMode.Occluded
        end

        if rec.billboard then
                rec.billboard.Enabled = true
                rec.billboard.MaxDistance = PlayerSettings.MaxDistance
                rec.billboard.AlwaysOnTop = PlayerSettings.ThroughWalls
                rec.label.Text = buildPlayerText(rec, player, humanoid)
        end
end

-- =============================================================
-- Stats HUD
-- =============================================================

local function ensureHud()
        if hudGui then
                return hudGui
        end

        hudGui = Instance.new("ScreenGui")
        hudGui.Name = HUD_NAME
        hudGui.ResetOnSpawn = false
        hudGui.DisplayOrder = 9999
        hudGui.Enabled = false

        local frame = Instance.new("Frame")
        frame.Name = "Root"
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.new(0.5, 0, 0, 10)
        frame.Size = UDim2.fromOffset(380, 96)
        frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        frame.BackgroundTransparency = 0.18
        frame.BorderSizePixel = 0
        frame.Parent = hudGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 90)
        stroke.Transparency = 0.4
        stroke.Parent = frame

        local function makeLabel(name, position, size, textSize, color)
                local label = Instance.new("TextLabel")
                label.Name = name
                label.BackgroundTransparency = 1
                label.Position = position
                label.Size = size
                label.Font = Enum.Font.GothamBold
                label.TextSize = textSize
                label.TextColor3 = color
                label.TextXAlignment = Enum.TextXAlignment.Center
                label.TextYAlignment = Enum.TextYAlignment.Center
                label.Text = ""
                label.Parent = frame
                return label
        end

        local titleLabel = makeLabel(
                "Title",
                UDim2.new(0, 0, 0, 3),
                UDim2.new(1, 0, 0, 16),
                12,
                GRAY
        )
        titleLabel.Text = "LootSight"
        hudStatsLabel = makeLabel(
                "Stats",
                UDim2.new(0, 0, 0, 20),
                UDim2.new(1, 0, 0, 20),
                15,
                WHITE
        )
        hudBestLabel = makeLabel(
                "Best",
                UDim2.new(0, 0, 0, 42),
                UDim2.new(1, 0, 0, 18),
                13,
                GOLD
        )
        hudYouLabel = makeLabel(
                "You",
                UDim2.new(0, 0, 0, 62),
                UDim2.new(1, 0, 0, 18),
                13,
                GOLD
        )

        local parent = nil
        pcall(function()
                if gethui then
                        parent = gethui()
                end
        end)
        if not parent then
                parent = LocalPlayer:WaitForChild("PlayerGui", 5)
        end
        if parent then
                hudGui.Parent = parent
        end

        return hudGui
end

local youCarried = { total = 0, count = 0, at = -999 }

local function updateHud(tickCount)
        local shouldShow = HudSettings.Enabled and LootSettings.Enabled and running
        if not shouldShow then
                if hudGui then
                        hudGui.Enabled = false
                end
                return
        end

        local gui = ensureHud()
        if not gui then
                return
        end
        gui.Enabled = true

        local total, count = 0, 0
        local bestName, bestValue, bestDistance = nil, -1, 0

        for _, rec in pairs(trackedLoot) do
                local worth = rec.worth or 0
                if rec.distance <= LootSettings.MaxDistance and worth >= LootSettings.MinValue then
                        total = total + worth
                        count = count + 1
                        if worth > bestValue then
                                bestValue = worth
                                bestName = rec.info.d
                                bestDistance = rec.distance
                        end
                end
        end

        if hudStatsLabel then
                hudStatsLabel.Text = string.format(
                        "%s in range  -  %d items",
                        formatMoney(total),
                        count
                )
        end

        if hudBestLabel then
                if bestName then
                        hudBestLabel.Text = string.format(
                                "Best: %s  %s  (%d studs)",
                                bestName,
                                formatMoney(bestValue),
                                floor(bestDistance)
                        )
                        hudBestLabel.TextColor3 = tierFor(bestValue).color
                else
                        hudBestLabel.Text = "No loot in range"
                        hudBestLabel.TextColor3 = GRAY
                end
        end

        if tickCount - youCarried.at >= 4 then
                local t, c = computeCarried(LocalPlayer)
                youCarried.total = t
                youCarried.count = c
                youCarried.at = tickCount
        end

        if hudYouLabel then
                hudYouLabel.Text = string.format(
                        "You carry: %s (%d items)",
                        formatMoney(youCarried.total),
                        youCarried.count
                )
        end
end

-- =============================================================
-- World update (throttled)
-- =============================================================

local function updateChamBudget()
        -- Roblox only renders ~31 Highlight instances at once, so chams are
        -- granted to the most valuable visible loot after player highlights
        -- take their share.
        local budget = CHAM_LIMIT

        if PlayerSettings.Enabled and PlayerSettings.Highlight then
                local playerCount = 0
                for _ in pairs(trackedPlayers) do
                        playerCount = playerCount + 1
                end
                budget = math.max(0, CHAM_LIMIT - playerCount)
        end

        if not LootSettings.Chams then
                budget = 0
        end

        local visible = {}
        for _, rec in pairs(trackedLoot) do
                if rec.billboard and rec.billboard.Enabled then
                        table.insert(visible, rec)
                elseif rec.highlight then
                        rec.highlight.Enabled = false
                end
        end

        table.sort(visible, function(a, b)
                return (a.worth or 0) > (b.worth or 0)
        end)

        for index, rec in ipairs(visible) do
                if rec.highlight then
                        local tier = tierFor(rec.worth or 0)
                        local color = LootSettings.TierColors and tier.color or WHITE
                        rec.highlight.Enabled = index <= budget
                        rec.highlight.FillColor = color
                        rec.highlight.OutlineColor = color
                        rec.highlight.FillTransparency = 1 - (LootSettings.ChamOpacity / 100)
                        rec.highlight.DepthMode = LootSettings.ThroughWalls
                                and Enum.HighlightDepthMode.AlwaysOnTop
                                or Enum.HighlightDepthMode.Occluded
                end
        end
end

local function updateWorld(tickCount)
        local character = LocalPlayer.Character
        local localRoot = character and character:FindFirstChild("HumanoidRootPart")

        if localRoot then
                local snapshot = {}
                for inst in pairs(trackedLoot) do
                        table.insert(snapshot, inst)
                end
                for _, inst in ipairs(snapshot) do
                        local ok = pcall(updateLootRecord, inst, localRoot)
                        if not ok then
                                untrackLoot(inst)
                        end
                end
        end

        for _, player in ipairs(Players:GetPlayers()) do
                pcall(updatePlayerEsp, player, localRoot, tickCount)
        end

        pcall(updateChamBudget)
        pcall(updateHud, tickCount)

        if statusLabel and tickCount % 4 == 0 then
                pcall(function()
                        statusLabel:Set(string.format(
                                "Tracking %d items  |  DB: %s (%d entries)",
                                trackedCount,
                                dbSource,
                                dbCount
                        ))
                end)
        end
end

-- =============================================================
-- UI
-- =============================================================

Window = Reborn:CreateWindow({
        Title = "LootSight",
        Size = Vector2.new(680, 480),
})

local function setLootEspEnabled(value)
        LootSettings.Enabled = value and true or false

        if value then
                loadLootDatabase()
                if topLabel then
                        pcall(function()
                                topLabel:Set(topLootLines(12))
                        end)
                end
                scanWorkspace()
                notify("LootSight", string.format(
                        "%d items tagged (DB: %s, %d entries)",
                        trackedCount,
                        dbSource,
                        dbCount
                ))
        else
                clearTrackedLoot()
                if hudGui then
                        hudGui.Enabled = false
                end
        end
end

do
        local LootTab = Window:Tab("Loot ESP", "gem")
        LootTab:SetColumns(2)

        local ItemSection = LootTab:Section("Item ESP")

        ItemSection:Toggle({
                Text = "Enable Item ESP",
                Value = false,
                Callback = setLootEspEnabled,
        })

        local LabelSection = LootTab:Section("Label Elements")

        LabelSection:Toggle({
                Text = "Show Name",
                Value = LootSettings.ShowName,
                Callback = function(value)
                        LootSettings.ShowName = value and true or false
                end,
        })

        LabelSection:Toggle({
                Text = "Show Value",
                Value = LootSettings.ShowValue,
                Callback = function(value)
                        LootSettings.ShowValue = value and true or false
                end,
        })

        LabelSection:Toggle({
                Text = "Show Shop Price",
                Value = LootSettings.ShowPrice,
                Callback = function(value)
                        LootSettings.ShowPrice = value and true or false
                end,
        })

        LabelSection:Toggle({
                Text = "Show Category",
                Value = LootSettings.ShowCategory,
                Callback = function(value)
                        LootSettings.ShowCategory = value and true or false
                end,
        })

        LabelSection:Toggle({
                Text = "Show Distance",
                Value = LootSettings.ShowDistance,
                Callback = function(value)
                        LootSettings.ShowDistance = value and true or false
                end,
        })

        local FilterSection = LootTab:Section("Filters")

        FilterSection:Slider({
                Text = "Min Value",
                Min = 0,
                Max = 10000,
                Value = LootSettings.MinValue,
                Callback = function(value)
                        LootSettings.MinValue = tonumber(value) or 0
                end,
        })

        FilterSection:Slider({
                Text = "Max Distance (studs)",
                Min = 100,
                Max = 10000,
                Value = LootSettings.MaxDistance,
                Callback = function(value)
                        LootSettings.MaxDistance = tonumber(value) or 2000
                end,
        })

        FilterSection:Toggle({
                Text = "Hide Junk (< $25)",
                Value = LootSettings.HideJunk,
                Callback = function(value)
                        LootSettings.HideJunk = value and true or false
                end,
        })

        local ChamSection = LootTab:Section("Chams")

        ChamSection:Toggle({
                Text = "Loot Chams",
                Value = LootSettings.Chams,
                Callback = function(value)
                        LootSettings.Chams = value and true or false
                end,
        })

        ChamSection:Slider({
                Text = "Cham Fill Opacity",
                Min = 0,
                Max = 100,
                Value = LootSettings.ChamOpacity,
                Callback = function(value)
                        LootSettings.ChamOpacity = tonumber(value) or 30
                end,
        })

        ChamSection:Toggle({
                Text = "Tier Colors",
                Value = LootSettings.TierColors,
                Callback = function(value)
                        LootSettings.TierColors = value and true or false
                end,
        })

        ChamSection:Toggle({
                Text = "Through Walls",
                Value = LootSettings.ThroughWalls,
                Callback = function(value)
                        LootSettings.ThroughWalls = value and true or false
                end,
        })
end

do
        local PlayerTab = Window:Tab("Players", "user")
        PlayerTab:SetColumns(2)

        local PlayerSection = PlayerTab:Section("Player ESP")

        PlayerSection:Toggle({
                Text = "Enable Player ESP",
                Value = false,
                Callback = function(value)
                        PlayerSettings.Enabled = value and true or false
                        if not value then
                                for player in pairs(trackedPlayers) do
                                        untrackPlayer(player)
                                end
                        end
                end,
        })

        PlayerSection:Toggle({
                Text = "Show Name",
                Value = PlayerSettings.ShowName,
                Callback = function(value)
                        PlayerSettings.ShowName = value and true or false
                end,
        })

        PlayerSection:Toggle({
                Text = "Show Health",
                Value = PlayerSettings.ShowHealth,
                Callback = function(value)
                        PlayerSettings.ShowHealth = value and true or false
                end,
        })

        PlayerSection:Toggle({
                Text = "Show Distance",
                Value = PlayerSettings.ShowDistance,
                Callback = function(value)
                        PlayerSettings.ShowDistance = value and true or false
                end,
        })

        local CarriedSection = PlayerTab:Section("Carried Loot")

        CarriedSection:Toggle({
                Text = "Show Carried Value",
                Value = PlayerSettings.CarriedValue,
                Callback = function(value)
                        PlayerSettings.CarriedValue = value and true or false
                end,
        })

        CarriedSection:Toggle({
                Text = "Show Item Names",
                Value = PlayerSettings.ShowCarriedItems,
                Callback = function(value)
                        PlayerSettings.ShowCarriedItems = value and true or false
                end,
        })

        local StyleSection = PlayerTab:Section("Style")

        StyleSection:Toggle({
                Text = "Highlight",
                Value = PlayerSettings.Highlight,
                Callback = function(value)
                        PlayerSettings.Highlight = value and true or false
                end,
        })

        StyleSection:ColorPicker({
                Text = "ESP Color",
                Value = PlayerSettings.Color,
                Callback = function(hex, color)
                        PlayerSettings.Color = color
                end,
        })

        StyleSection:Toggle({
                Text = "Team Check",
                Value = PlayerSettings.TeamCheck,
                Callback = function(value)
                        PlayerSettings.TeamCheck = value and true or false
                end,
        })

        StyleSection:Toggle({
                Text = "Through Walls",
                Value = PlayerSettings.ThroughWalls,
                Callback = function(value)
                        PlayerSettings.ThroughWalls = value and true or false
                end,
        })

        StyleSection:Slider({
                Text = "Max Distance (studs)",
                Min = 100,
                Max = 10000,
                Value = PlayerSettings.MaxDistance,
                Callback = function(value)
                        PlayerSettings.MaxDistance = tonumber(value) or 1500
                end,
        })
end

do
        local AlertTab = Window:Tab("Alerts", "bell")

        local AlertSection = AlertTab:Section("Rare Loot Alerts")

        AlertSection:Toggle({
                Text = "Alert On Rare Spawns",
                Value = AlertSettings.Enabled,
                Callback = function(value)
                        AlertSettings.Enabled = value and true or false
                end,
        })

        AlertSection:Slider({
                Text = "Alert Threshold",
                Min = 100,
                Max = 10000,
                Value = AlertSettings.Threshold,
                Callback = function(value)
                        AlertSettings.Threshold = tonumber(value) or 800
                end,
        })

        AlertSection:Toggle({
                Text = "Alert Sound",
                Value = AlertSettings.Sound,
                Callback = function(value)
                        AlertSettings.Sound = value and true or false
                end,
        })
end

do
        local StatsTab = Window:Tab("Stats", "activity")

        local HudSection = StatsTab:Section("HUD")

        HudSection:Toggle({
                Text = "Stats HUD",
                Value = HudSettings.Enabled,
                Callback = function(value)
                        HudSettings.Enabled = value and true or false
                        if not value and hudGui then
                                hudGui.Enabled = false
                        end
                end,
        })

        local DataSection = StatsTab:Section("Loot Database")

        statusLabel = DataSection:Paragraph({
                Text = "Idle - enable Item ESP to scan",
        })

        topLabel = DataSection:Paragraph({
                Text = "Enable Item ESP to load values",
        })

        DataSection:Button({
                Text = "Rescan Workspace",
                Callback = function()
                        if not LootSettings.Enabled then
                                notify("LootSight", "Enable Item ESP first.")
                                return
                        end
                        clearTrackedLoot()
                        scanWorkspace()
                        notify("LootSight", "Rescan complete: " .. trackedCount .. " items tagged.")
                end,
        })

        DataSection:Button({
                Text = "Reload Loot Database",
                Callback = function()
                        loadLootDatabase()
                        if topLabel then
                                pcall(function()
                                        topLabel:Set(topLootLines(12))
                                end)
                        end
                        if statusLabel then
                                pcall(function()
                                        statusLabel:Set(string.format(
                                                "DB reloaded: %s (%d entries)",
                                                dbSource,
                                                dbCount
                                        ))
                                end)
                        end
                        notify("LootSight", "Database reloaded (" .. dbSource .. ", " .. dbCount .. " entries).")
                end,
        })

        DataSection:Button({
                Text = "Unload LootSight",
                Callback = function()
                        if type(Global.__LootSightCleanup) == "function" then
                                pcall(Global.__LootSightCleanup)
                        end
                end,
        })
end

-- =============================================================
-- Live connections + cleanup
-- =============================================================

connections.DescendantAdded = Workspace.DescendantAdded:Connect(function(inst)
        local ok = pcall(onInstanceAdded, inst)
        if not ok then
                return
        end
end)

connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        untrackPlayer(player)
end)

local slowState = { accumulator = 1 }

connections.Heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
        if not running then
                return
        end
        slowState.accumulator = slowState.accumulator + deltaTime
        if slowState.accumulator < SLOW_INTERVAL then
                return
        end
        slowState.tick = (slowState.tick or 0) + 1
        slowState.accumulator = 0
        pcall(updateWorld, slowState.tick)
end)

local function cleanup()
        if not running then
                return
        end

        running = false
        LootSettings.Enabled = false
        PlayerSettings.Enabled = false

        for _, connection in pairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end

        clearTrackedLoot()

        for player in pairs(trackedPlayers) do
                untrackPlayer(player)
        end

        if hudGui then
                pcall(function()
                        hudGui:Destroy()
                end)
                hudGui = nil
        end

        if alertSound then
                pcall(function()
                        alertSound:Destroy()
                end)
                alertSound = nil
        end

        pcall(function()
                Window:Destroy()
        end)

        Global.__LootSightCleanup = nil
end

Global.__LootSightCleanup = cleanup
