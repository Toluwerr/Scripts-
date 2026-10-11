-- Prison Life troll script (place 155615604)
-- Built on client-trust bugs found in the game's own code:
--   * ShootEvent accepts fully client-forged bullet lists {origin, end, hitPart}
--   * meleeEvent has no range validation (players AND Toilet models)
--   * GiverPressed / InteractWithItem distance rule is client-side only
--   * C4 placement positions are client-supplied (ActivateC4)
--   * Gun ammo is client-side bookkeeping (Local_CurrentAmmo attribute)
--   * Hostile / Trespassing / Tased are readable character attributes
-- Zero character movement: no teleports, no speed changes, no CFrame writes -
-- nothing that trips the server's "moving too fast / flying" kicks.
-- UI: Reborn (https://github.com/Toluwer/Reborn)

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Global = (getgenv and getgenv()) or _G

if type(Global.__PrisonTrollCleanup) == "function" then
        pcall(Global.__PrisonTrollCleanup)
end

local running = true
local connections = {}

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnectAll()
        for _, connection in ipairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end
        connections = {}
end

local FS = {
        write = (type(writefile) == "function") and writefile or nil,
        read = (type(readfile) == "function") and readfile or nil,
        isFile = (type(isfile) == "function") and isfile or nil,
        isFolder = (type(isfolder) == "function") and isfolder or nil,
        makeFolder = (type(makefolder) == "function") and makefolder or nil,
}

-- ============================================================
-- Reborn UI
-- ============================================================

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[PrisonTroll] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

-- ============================================================
-- Game bindings
-- ============================================================

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunRemotes = ReplicatedStorage:WaitForChild("GunRemotes")
local ArrestPlayer = Remotes:WaitForChild("ArrestPlayer")
local RequestTeamChange = Remotes:WaitForChild("RequestTeamChange")
local InteractWithItem = Remotes:WaitForChild("InteractWithItem")
local GiverPressed = Remotes:WaitForChild("GiverPressed")
local ActivateC4 = Remotes:WaitForChild("C4"):WaitForChild("ActivateC4")
local MeleeEvent = ReplicatedStorage:WaitForChild("meleeEvent")
local ShootEvent = GunRemotes:WaitForChild("ShootEvent")
local FuncReload = GunRemotes:WaitForChild("FuncReload")

local GIVER_WEAPONS = {
        "AK-47", "M4A1", "FAL", "MP5", "Remington 870", "Revolver", "M700",
        "C4 Explosive", "Riot Shield", "Crude Knife", "Hammer", "Stop Sign",
}

local GUN_SET = {
        ["AK-47"] = true,
        ["M4A1"] = true,
        ["FAL"] = true,
        ["MP5"] = true,
        ["Remington 870"] = true,
        ["Revolver"] = true,
        ["M700"] = true,
}

-- ============================================================
-- Config
-- ============================================================

local CONFIG_FOLDER = "prisonlife"
local CONFIG_FILE = CONFIG_FOLDER .. "/troll.json"

local cfg = {
        Weapon = "AK-47",
        InfiniteAmmo = true,
        KillAura = false,
        AuraRadius = 70,
        ClickKill = false,
        TaseAura = false,
        ArrestAura = false,
        RemoteArrest = false,
        AntiArrest = false,
        C4Rain = false,
        ShotSpam = false,
        SpamCount = 18,
}

local saveQueued = false

local function queueSave()
        if not FS.write then
                return
        end
        if saveQueued then
                return
        end
        saveQueued = true
        task.delay(1, function()
                saveQueued = false
                if not running then
                        return
                end
                local ok, json = pcall(function()
                        return HttpService:JSONEncode(cfg)
                end)
                if not ok or type(json) ~= "string" then
                        return
                end
                pcall(function()
                        if FS.isFolder and FS.makeFolder then
                                if not FS.isFolder(CONFIG_FOLDER) then
                                        FS.makeFolder(CONFIG_FOLDER)
                                end
                        end
                        FS.write(CONFIG_FILE, json)
                end)
        end)
end

local function loadConfig()
        if not FS.read or not FS.isFile then
                return
        end
        local ok, body = pcall(function()
                if FS.isFile(CONFIG_FILE) then
                        return FS.read(CONFIG_FILE)
                end
                return nil
        end)
        if not ok or type(body) ~= "string" or #body < 2 then
                return
        end
        local okData, data = pcall(function()
                return HttpService:JSONDecode(body)
        end)
        if not okData or type(data) ~= "table" then
                return
        end
        for key, value in pairs(cfg) do
                local incoming = data[key]
                if incoming ~= nil then
                        if type(value) == "string" and type(incoming) == "string" then
                                cfg[key] = incoming
                        elseif type(value) == "boolean" then
                                cfg[key] = incoming and true or false
                        elseif type(value) == "number" and type(incoming) == "number" then
                                cfg[key] = incoming
                        end
                end
        end
end

loadConfig()

local function validOption(value, options, fallback)
        for _, option in ipairs(options) do
                if option == value then
                        return value
                end
        end
        return fallback
end

cfg.Weapon = validOption(cfg.Weapon, GIVER_WEAPONS, "AK-47")
cfg.AuraRadius = math.clamp(cfg.AuraRadius, 10, 250)
cfg.SpamCount = math.clamp(cfg.SpamCount, 5, 40)

-- ============================================================
-- Runtime state
-- ============================================================

local state = {
        action = "Idle",
        kills = 0,
        arrests = 0,
        tases = 0,
        c4s = 0,
        toilets = 0,
        lastVolleyAt = 0,
        lastClickKillAt = 0,
        lastTeamSwitchAt = 0,
        lastGunFetchAt = 0,
        remoteArrestFails = 0,
        taseCooldown = {},
        auraCooldown = {},
        lastNotify = {},
}

local ui = {}

local Window = Reborn:CreateWindow({
        Title = "Prison Life",
        Size = Vector2.new(500, 450),
})

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 3.2,
                })
        end)
end

local function notifyT(key, title, description, cooldown)
        local now = os.clock()
        cooldown = cooldown or 5
        if state.lastNotify[key] and now - state.lastNotify[key] < cooldown then
                return
        end
        state.lastNotify[key] = now
        notify(title, description)
end

local function setAction(text)
        state.action = text
end

-- ============================================================
-- Character helpers
-- ============================================================

local function myCharacter()
        return LocalPlayer.Character
end

local function myHumanoid()
        local character = myCharacter()
        return character and character:FindFirstChildOfClass("Humanoid")
end

local function myRoot()
        local character = myCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
end

local function myHeadPos()
        local character = myCharacter()
        local head = character and character:FindFirstChild("Head")
        if head then
                return head.Position
        end
        local root = myRoot()
        return root and root.Position or nil
end

local function isAlive()
        local humanoid = myHumanoid()
        return humanoid ~= nil and humanoid.Health > 0
end

local function teamName()
        local team = LocalPlayer.Team
        return team and team.Name or ""
end

local function headOf(player)
        local character = player.Character
        return character and character:FindFirstChild("Head")
end

local function rootOf(player)
        local character = player.Character
        return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(player)
        local character = player.Character
        return character and character:FindFirstChildOfClass("Humanoid")
end

-- Mirror of the game's own canBeDamaged check (GunController).
-- Filtering through it keeps forged hits on server-accepted targets only,
-- so you never trip the innocent-kill warnings.
local function damageable(player)
        if player == LocalPlayer then
                return false
        end
        if player.Team == LocalPlayer.Team then
                return false
        end
        local character = player.Character
        if not character then
                return false
        end
        if LocalPlayer.Team == Teams.Guards
                and player.Team == Teams.Inmates
                and not character:GetAttribute("Hostile") then
                return false
        end
        if character:FindFirstChildOfClass("ForceField") then
                return false
        end
        local humanoid = character:FindFirstChild("Humanoid")
        return humanoid ~= nil and humanoid.Health > 0
end

-- Mirror of the game's arrest eligibility (HandcuffsClient).
local function arrestable(player)
        if player == LocalPlayer then
                return false
        end
        local character = player.Character
        if not character then
                return false
        end
        if character:FindFirstChildOfClass("ForceField") then
                return false
        end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
                return false
        end
        if player.Team == Teams.Criminals then
                return true
        end
        if player.Team == Teams.Inmates then
                local hostile = character:GetAttribute("Hostile")
                if not hostile and character:GetAttribute("Trespassing") then
                        return true
                end
                if hostile and character:GetAttribute("Tased") then
                        return true
                end
        end
        return false
end

-- ============================================================
-- Weapon handling (no movement - remotes only)
-- ============================================================

local function holdingTool(name)
        local character = myCharacter()
        if not character then
                return nil
        end
        local tool = character:FindFirstChild(name)
        if tool and tool:IsA("Tool") then
                return tool
        end
        return nil
end

local function backpackTool(name)
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not backpack then
                return nil
        end
        local tool = backpack:FindFirstChild(name)
        if tool and tool:IsA("Tool") then
                return tool
        end
        return nil
end

local function ensureEquipped(name)
        if holdingTool(name) then
                return true
        end
        local tool = backpackTool(name)
        if tool then
                local humanoid = myHumanoid()
                if humanoid then
                        pcall(function()
                                humanoid:EquipTool(tool)
                        end)
                        task.wait(0.15)
                end
        end
        return holdingTool(name) ~= nil
end

local function findGiverModel(name)
        for _, model in ipairs(CollectionService:GetTagged("Giver")) do
                if model.Name == name then
                        return model
                end
        end
        local items = workspace:FindFirstChild("Prison_ITEMS")
        local folder = items and items:FindFirstChild("giver")
        if folder then
                return folder:FindFirstChild(name)
        end
        return nil
end

local function findMeleeModel(name)
        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == name then
                        return model
                end
        end
        return nil
end

local GIVER_ALIAS = {
        ["Crude Knife"] = "Crude Knife",
        ["Hammer"] = "Hammer",
        ["Stop Sign"] = "Stop Sign",
}

-- Fetch any weapon from its giver without moving an inch:
-- the 12-stud distance rule only ever existed in the client's mouse handler.
local function fetchWeapon(name)
        if not isAlive() then
                return false
        end
        if holdingTool(name) or backpackTool(name) then
                return true
        end
        local melee = GIVER_ALIAS[name] ~= nil
        local model
        if melee then
                model = findMeleeModel(name)
        else
                model = findGiverModel(name)
        end
        if not model then
                if not melee then
                        model = findMeleeModel(name)
                        melee = model ~= nil
                end
                if not model then
                        notifyT("nogiver" .. name, "No giver found", "There is no " .. name .. " giver on this map.", 12)
                        return false
                end
        end
        -- Giver remotes (distance rule is client-side only)
        pcall(function()
                GiverPressed:FireServer(model)
        end)
        local part = model:FindFirstChild("ITEMPICKUP", true)
        if not part or not part:IsA("BasePart") then
                part = model:FindFirstChildWhichIsA("BasePart", true)
        end
        if part then
                pcall(function()
                        InteractWithItem:InvokeServer(part)
                end)
                local root = myRoot()
                if melee and root and type(firetouchinterest) == "function" then
                        pcall(function()
                                firetouchinterest(part, root, 0)
                                firetouchinterest(part, root, 1)
                        end)
                end
        end
        for _ = 1, 6 do
                task.wait(0.25)
                if not running then
                        return false
                end
                if holdingTool(name) or backpackTool(name) then
                        notifyT("got" .. name, "Got " .. name, "Fetched remotely - you never moved.")
                        return true
                end
        end
        notifyT("fetchfail" .. name, "Could not get " .. name, "The server refused (wrong team or area).", 10)
        return false
end

-- Make sure a real gun is in hand so forged bullets carry gun damage.
-- Fetch attempts are throttled so a missing giver can never stall aura ticks.
local function ensureGunInHand()
        local name = cfg.Weapon
        if GUN_SET[name] then
                if ensureEquipped(name) then
                        return true
                end
                local now = os.clock()
                if now - state.lastGunFetchAt > 5 then
                        state.lastGunFetchAt = now
                        if fetchWeapon(name) and ensureEquipped(name) then
                                return true
                        end
                end
        end
        for _, fallback in ipairs({ "AK-47", "M4A1", "FAL", "MP5", "Revolver", "Remington 870", "M700" }) do
                if holdingTool(fallback) then
                        return true
                end
                if backpackTool(fallback) and ensureEquipped(fallback) then
                        return true
                end
        end
        return false
end

-- ============================================================
-- Forged bullet primitives
-- ============================================================

-- The server applies damage per entry of the volley the client sends.
-- Shotgun spread proves multiple bullets per shot are legal traffic.
local VOLLEY_MIN_GAP = 0.08

local function fireForged(entries)
        local origin = myHeadPos()
        if not origin then
                return false
        end
        local now = os.clock()
        if now - state.lastVolleyAt < VOLLEY_MIN_GAP then
                return false
        end
        state.lastVolleyAt = now
        local volley = {}
        for _, entry in ipairs(entries) do
                table.insert(volley, { origin, entry.pos, entry.part })
        end
        pcall(function()
                ShootEvent:FireServer(volley)
        end)
        return true
end

local function countKill(player)
        local humanoid = humanoidOf(player)
        if humanoid and humanoid.Health <= 0 then
                state.kills = state.kills + 1
                return
        end
        task.delay(0.6, function()
                local later = humanoidOf(player)
                if later and later.Health <= 0 then
                        state.kills = state.kills + 1
                end
        end)
end

-- One target, several bullets to the head in a single volley.
local function forgeKill(player)
        local head = headOf(player)
        if not head then
                return false
        end
        local entries = {}
        for _ = 1, 6 do
                table.insert(entries, { pos = head.Position, part = head })
        end
        if not fireForged(entries) then
                return false
        end
        countKill(player)
        return true
end

local function forgeTase(player)
        local head = headOf(player)
        if not head then
                return false
        end
        local ok = fireForged({ { pos = head.Position, part = head } })
        if ok then
                state.tases = state.tases + 1
        end
        return ok
end

local function damageablePlayers(maxDist)
        local root = myRoot()
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
                if damageable(player) then
                        local include = true
                        if maxDist then
                                local theirRoot = rootOf(player)
                                if not root or not theirRoot or (theirRoot.Position - root.Position).Magnitude > maxDist then
                                        include = false
                                end
                        end
                        if include then
                                        table.insert(list, player)
                        end
                end
        end
        return list
end

local function killAllEnemies()
        if not ensureGunInHand() then
                notify("No gun", "Grab a gun first (Loadout > Get).")
                return
        end
        local targets = damageablePlayers(nil)
        if #targets == 0 then
                notify("No targets", "Nobody on the enemy team right now.")
                return
        end
        setAction("Kill All - " .. #targets .. " targets")
        for round = 1, 3 do
                if not running then
                        return
                end
                local entries = {}
                for _, player in ipairs(targets) do
                        local head = headOf(player)
                        if head and humanoidOf(player) and humanoidOf(player).Health > 0 then
                                table.insert(entries, { pos = head.Position, part = head })
                        end
                end
                if #entries == 0 then
                        break
                end
                fireForged(entries)
                for _, player in ipairs(targets) do
                        countKill(player)
                end
                task.wait(0.25)
        end
        notify("Kill All fired", "One volley per enemy - check the tracers.")
end

-- ============================================================
-- Arrest (eligibility mirrored from HandcuffsClient)
-- ============================================================

local function hasHandcuffs()
        return holdingTool("Handcuffs") ~= nil or backpackTool("Handcuffs") ~= nil
end

local function tryArrest(player)
        local ok, result = pcall(function()
                return ArrestPlayer:InvokeServer(player, 1)
        end)
        if ok and result then
                state.arrests = state.arrests + 1
                notifyT("arrest" .. player.Name, "Arrested " .. player.Name)
                return true
        end
        return false
end

local function switchTeam(name)
        local team = Teams:FindFirstChild(name)
        if not team then
                return
        end
        local now = os.clock()
        if now - state.lastTeamSwitchAt < 8 then
                notifyT("teamcd", "Slow down", "Team changes are rate-limited.", 6)
                return
        end
        state.lastTeamSwitchAt = now
        pcall(function()
                RequestTeamChange:InvokeServer(team, 1)
        end)
end

-- ============================================================
-- C4 (positions are client-supplied)
-- ============================================================

-- Remote-only planting: the game's client passes its own raycast positions,
-- so the server trusts whatever we hand it. If this server clamps the range
-- we simply report it - never plant at our own feet in automated modes.
local function plantC4(targetPos)
        local root = myRoot()
        if not root then
                return false
        end
        local ok, result = pcall(function()
                return ActivateC4:InvokeServer(root.Position, targetPos)
        end)
        if ok and result then
                state.c4s = state.c4s + 1
                return true
        end
        return false
end

local function detonateC4()
        pcall(function()
                ActivateC4:InvokeServer()
        end)
end

local function c4RainTick()
        local root = myRoot()
        if not root or not isAlive() then
                return
        end
        if not ensureEquipped("C4 Explosive") then
                if not fetchWeapon("C4 Explosive") or not ensureEquipped("C4 Explosive") then
                        return
                end
        end
        local targets = damageablePlayers(nil)
        if #targets == 0 then
                return
        end
        local pick = targets[math.random(#targets)]
        local theirRoot = rootOf(pick)
        if not theirRoot then
                return
        end
        setAction("C4 on " .. pick.Name)
        if plantC4(theirRoot.Position) then
                task.wait(0.6)
                detonateC4()
                notifyT("c4" .. pick.Name, "C4 delivered", pick.Name .. " got a package.")
        else
                cfg.C4Rain = false
                if ui.c4Rain then
                        pcall(function() ui.c4Rain:Set(false, false) end)
                end
                notify("C4 Rain disabled", "This server clamps plant range - use Plant at Mouse up close.")
        end
end

-- ============================================================
-- Loops
-- ============================================================

local function killAuraTick()
        local root = myRoot()
        if not root or not isAlive() then
                return
        end
        local now = os.clock()
        local targets = {}
        for _, player in ipairs(Players:GetPlayers()) do
                if damageable(player) then
                        local theirRoot = rootOf(player)
                        if theirRoot and (theirRoot.Position - root.Position).Magnitude <= cfg.AuraRadius then
                                if not state.auraCooldown[player] or now - state.auraCooldown[player] > 0.45 then
                                        table.insert(targets, player)
                                        state.auraCooldown[player] = now
                                end
                        end
                end
        end
        if #targets == 0 then
                return
        end
        if not ensureGunInHand() then
                return
        end
        setAction("Aura: " .. #targets .. " target(s)")
        local entries = {}
        for _, player in ipairs(targets) do
                local head = headOf(player)
                if head then
                        table.insert(entries, { pos = head.Position, part = head })
                end
        end
        if fireForged(entries) then
                for _, player in ipairs(targets) do
                        countKill(player)
                end
        end
end

local function taseAuraTick()
        local root = myRoot()
        if not root or not isAlive() then
                return
        end
        local now = os.clock()
        if not ensureEquipped("Taser") then
                notifyT("notaser", "Need the Taser", "Switch to Guards - they spawn with a Taser.", 20)
                return
        end
        for _, player in ipairs(Players:GetPlayers()) do
                if damageable(player) then
                        local theirRoot = rootOf(player)
                        if theirRoot and (theirRoot.Position - root.Position).Magnitude <= cfg.AuraRadius then
                                if not state.taseCooldown[player] or now - state.taseCooldown[player] > 3 then
                                        state.taseCooldown[player] = now
                                        setAction("Tasing " .. player.Name)
                                        forgeTase(player)
                                        return
                                end
                        end
                end
        end
end

local function arrestAuraTick()
        local root = myRoot()
        if not root or not isAlive() then
                return
        end
        if not hasHandcuffs() then
                notifyT("nocuffs", "Need Handcuffs", "Switch to Guards - they spawn with Handcuffs.", 20)
                return
        end
        for _, player in ipairs(Players:GetPlayers()) do
                if arrestable(player) then
                        local theirRoot = rootOf(player)
                        if theirRoot and (theirRoot.Position - root.Position).Magnitude <= 10 then
                                setAction("Arresting " .. player.Name)
                                tryArrest(player)
                                return
                        end
                end
        end
end

local function remoteArrestTick()
        if not isAlive() then
                return
        end
        if not hasHandcuffs() then
                notifyT("nocuffs", "Need Handcuffs", "Switch to Guards - they spawn with Handcuffs.", 20)
                return
        end
        if state.remoteArrestFails >= 5 then
                if cfg.RemoteArrest then
                        cfg.RemoteArrest = false
                        if ui.remoteArrest then
                                pcall(function() ui.remoteArrest:Set(false, false) end)
                        end
                        notify("Remote Arrest disabled", "The server checks arrest distance - use Arrest Aura instead.")
                end
                return
        end
        local done = 0
        for _, player in ipairs(Players:GetPlayers()) do
                if done >= 2 then
                        break
                end
                if arrestable(player) then
                        setAction("Remote arrest: " .. player.Name)
                        if tryArrest(player) then
                                state.remoteArrestFails = 0
                                done = done + 1
                        else
                                state.remoteArrestFails = state.remoteArrestFails + 1
                                if state.remoteArrestFails >= 5 then
                                        return
                                end
                        end
                end
        end
end

-- Counter the cuff-rushers: no fleeing, no teleports - they just die.
local function antiArrestTick()
        if teamName() == "Guards" or not isAlive() then
                return
        end
        local root = myRoot()
        if not root then
                return
        end
        for _, player in ipairs(Players:GetPlayers()) do
                if player.Team == Teams.Guards and damageable(player) then
                        local character = player.Character
                        if character and character:FindFirstChild("Handcuffs") then
                                local theirRoot = rootOf(player)
                                if theirRoot and (theirRoot.Position - root.Position).Magnitude < 14 then
                                        setAction("Anti-arrest: " .. player.Name)
                                        if not ensureGunInHand() then
                                                return
                                        end
                                        if forgeKill(player) then
                                                notifyT("aa" .. player.Name, "Anti-Arrest", player.Name .. " pulled cuffs - dropped them.")
                                        end
                                        return
                                end
                        end
                end
        end
end

local function shotSpamTick()
        local origin = myHeadPos()
        if not origin or not isAlive() then
                return
        end
        local entries = {}
        for _ = 1, cfg.SpamCount do
                local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
                if dir.Magnitude < 0.05 then
                        dir = Vector3.new(1, 0, 0)
                end
                dir = dir.Unit * (30 + math.random() * 60)
                table.insert(entries, { pos = origin + dir, part = nil })
        end
        fireForged(entries)
end

-- Infinite ammo: the ammo counter is an attribute the client maintains.
local function infiniteAmmoTick()
        if not cfg.InfiniteAmmo then
                return
        end
        local character = myCharacter()
        if not character then
                return
        end
        for _, child in ipairs(character:GetChildren()) do
                if child:IsA("Tool") then
                        local current = child:GetAttribute("Local_CurrentAmmo")
                        if type(current) == "number" then
                                local max = child:GetAttribute("MaxAmmo")
                                if type(max) ~= "number" then
                                        max = 30
                                end
                                if current < max then
                                        pcall(function()
                                                child:SetAttribute("Local_CurrentAmmo", max)
                                        end)
                                end
                        end
                end
        end
end

local function toiletWipe()
        setAction("Flushing the prison")
        local toilets = {}
        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Toilet" then
                        local health = model:FindFirstChild("Health")
                        if not health or health.Value > 0 then
                                table.insert(toilets, model)
                        end
                end
        end
        if #toilets == 0 then
                notify("No toilets", "Found none in the workspace root - may need to be near the prison blocks.")
                return
        end
        if holdingTool("Hammer") or backpackTool("Hammer") then
                ensureEquipped("Hammer")
        end
        local broken = 0
        for _, toilet in ipairs(toilets) do
                if not running then
                        break
                end
                pcall(function()
                        MeleeEvent:FireServer(toilet, 1, 1)
                end)
                broken = broken + 1
                if broken % 12 == 0 then
                        task.wait(0.1)
                end
        end
        state.toilets = state.toilets + broken
        notify("Toilets wiped", broken .. " flushes sent (server may want you closer).")
end

local function updateStatus()
        local lines = {
                "Team: " .. (teamName() ~= "" and teamName() or "None") .. "   |   Kills: " .. state.kills
                        .. "   |   Arrests: " .. state.arrests,
                "Tases: " .. state.tases .. "   |   C4: " .. state.c4s .. "   |   Toilets: " .. state.toilets,
                state.action,
        }
        if ui.status then
                pcall(function()
                        ui.status:Set(table.concat(lines, "\n"))
                end)
        end
end

-- ============================================================
-- UI
-- ============================================================

local TrollTab = Window:Tab("Troll", "skull")
local ChaosTab = Window:Tab("Chaos", "bomb")

local LoadoutSection = TrollTab:Section("Loadout")

ui.weapon = LoadoutSection:Dropdown({
        Text = "Weapon",
        Options = GIVER_WEAPONS,
        Value = cfg.Weapon,
        Callback = function(value)
                cfg.Weapon = value
                queueSave()
        end,
})

local loadoutRow = LoadoutSection:Row()

loadoutRow:Button({
        Text = "Get",
        Callback = function()
                task.spawn(function()
                        setAction("Fetching " .. cfg.Weapon)
                        fetchWeapon(cfg.Weapon)
                end)
        end,
})

loadoutRow:Button({
        Text = "Guards",
        Callback = function()
                switchTeam("Guards")
        end,
})

loadoutRow:Button({
        Text = "Inmates",
        Callback = function()
                switchTeam("Inmates")
        end,
})

ui.infiniteAmmo = LoadoutSection:Toggle({
        Text = "Infinite Ammo",
        Value = cfg.InfiniteAmmo,
        Callback = function(value)
                cfg.InfiniteAmmo = value
                queueSave()
        end,
})

local KillSection = TrollTab:Section("Kills")

ui.killAura = KillSection:Toggle({
        Text = "Kill Aura",
        Value = cfg.KillAura,
        Callback = function(value)
                cfg.KillAura = value
                queueSave()
        end,
})

ui.auraRadius = KillSection:Slider({
        Text = "Aura Radius",
        Min = 10,
        Max = 250,
        Step = 5,
        Value = cfg.AuraRadius,
        Callback = function(value)
                cfg.AuraRadius = value
                queueSave()
        end,
})

ui.clickKill = KillSection:Toggle({
        Text = "Click Kill",
        Value = cfg.ClickKill,
        Callback = function(value)
                cfg.ClickKill = value
                if value then
                        notify("Click Kill on", "Left-click any enemy player to delete them.")
                end
                queueSave()
        end,
})

local killRow = KillSection:Row()

killRow:Button({
        Text = "Kill All",
        Callback = function()
                task.spawn(function()
                        killAllEnemies()
                end)
        end,
})

local TaseSection = TrollTab:Section("Taser")

local taseRow = TaseSection:Row()

taseRow:Button({
        Text = "Tase All",
        Callback = function()
                task.spawn(function()
                        if not ensureEquipped("Taser") then
                                notify("Need the Taser", "Switch to Guards - they spawn with a Taser.")
                                return
                        end
                        local targets = damageablePlayers(nil)
                        if #targets == 0 then
                                notify("No targets", "Nobody taseable right now.")
                                return
                        end
                        setAction("Tase All - " .. #targets .. " targets")
                        local entries = {}
                        for _, player in ipairs(targets) do
                                local head = headOf(player)
                                if head then
                                        table.insert(entries, { pos = head.Position, part = head })
                                end
                        end
                        if fireForged(entries) then
                                state.tases = state.tases + #entries
                                notify("Tased " .. #entries .. " players", "Everybody drops.")
                        end
                end)
        end,
})

ui.taseAura = TaseSection:Toggle({
        Text = "Tase Aura",
        Value = cfg.TaseAura,
        Callback = function(value)
                cfg.TaseAura = value
                queueSave()
        end,
})

local ArrestSection = TrollTab:Section("Arrest")

ui.arrestAura = ArrestSection:Toggle({
        Text = "Arrest Aura",
        Value = cfg.ArrestAura,
        Callback = function(value)
                cfg.ArrestAura = value
                queueSave()
        end,
})

ui.remoteArrest = ArrestSection:Toggle({
        Text = "Remote Arrest",
        Value = cfg.RemoteArrest,
        Callback = function(value)
                cfg.RemoteArrest = value
                state.remoteArrestFails = 0
                if value then
                        notify("Remote Arrest on", "Arrests anyone on the map - auto-disables if the server refuses.")
                end
                queueSave()
        end,
})

ui.antiArrest = ArrestSection:Toggle({
        Text = "Anti-Arrest",
        Value = cfg.AntiArrest,
        Callback = function(value)
                cfg.AntiArrest = value
                queueSave()
        end,
})

local StatusSection = TrollTab:Section("Status")

ui.status = StatusSection:Paragraph({
        Text = "Loading...",
})

local C4Section = ChaosTab:Section("C4")

ui.c4Rain = C4Section:Toggle({
        Text = "C4 Rain",
        Value = cfg.C4Rain,
        Callback = function(value)
                cfg.C4Rain = value
                if value then
                        notify("C4 Rain on", "Random enemies get a surprise package every few seconds.")
                end
                queueSave()
        end,
})

local c4Row = C4Section:Row()

c4Row:Button({
        Text = "Plant at Mouse",
        Callback = function()
                task.spawn(function()
                        if not ensureEquipped("C4 Explosive") then
                                if not fetchWeapon("C4 Explosive") or not ensureEquipped("C4 Explosive") then
                                        notify("No C4", "Could not get the C4 Explosive.")
                                        return
                                end
                        end
                        local hit = Mouse.Hit
                        if plantC4(hit.Position) then
                                notify("C4 planted", "Run before you detonate - it does not check whose feet are there.")
                        end
                end)
        end,
})

c4Row:Button({
        Text = "Detonate",
        Callback = function()
                detonateC4()
        end,
})

local MayhemSection = ChaosTab:Section("Mayhem")

ui.shotSpam = MayhemSection:Toggle({
        Text = "Shot Spam",
        Value = cfg.ShotSpam,
        Callback = function(value)
                cfg.ShotSpam = value
                if value then
                        notify("Shot Spam on", "Tracers and gunfire sounds for the whole server.")
                end
                queueSave()
        end,
})

ui.spamCount = MayhemSection:Slider({
        Text = "Spam Density",
        Min = 5,
        Max = 40,
        Step = 1,
        Value = cfg.SpamCount,
        Callback = function(value)
                cfg.SpamCount = value
                queueSave()
        end,
})

local mayhemRow = MayhemSection:Row()

mayhemRow:Button({
        Text = "Toilet Wipe",
        Callback = function()
                task.spawn(function()
                        toiletWipe()
                end)
        end,
})

local NotesSection = ChaosTab:Section("Notes")

NotesSection:Paragraph({
        Text = "Everything works through the game's own remotes - this script never "
                .. "teleports you, never changes your speed, and never writes to your "
                .. "character, so the fast-movement kicks cannot trigger.",
})

-- ============================================================
-- Events + loops
-- ============================================================

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not cfg.ClickKill or not running then
                return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
        end
        local now = os.clock()
        if now - state.lastClickKillAt < 0.3 then
                return
        end
        local target = Mouse.Target
        if not target then
                return
        end
        local character = target:FindFirstAncestorOfClass("Model")
        if not character then
                return
        end
        local player = Players:GetPlayerFromCharacter(character)
        if not player or not damageable(player) then
                return
        end
        state.lastClickKillAt = now
        task.spawn(function()
                if not ensureGunInHand() then
                        notify("No gun", "Grab a gun first (Loadout > Get).")
                        return
                end
                setAction("Click kill: " .. player.Name)
                forgeKill(player)
        end)
end))

task.spawn(function()
        while running do
                task.wait(0.4)
                if running then
                        pcall(updateStatus)
                        pcall(infiniteAmmoTick)
                end
        end
end)

task.spawn(function()
        while running do
                task.wait(0.25)
                if running then
                        if cfg.KillAura then
                                pcall(killAuraTick)
                        end
                        if cfg.TaseAura then
                                pcall(taseAuraTick)
                        end
                end
        end
end)

task.spawn(function()
        while running do
                task.wait(0.35)
                if running then
                        if cfg.ArrestAura then
                                pcall(arrestAuraTick)
                        end
                        if cfg.RemoteArrest then
                                pcall(remoteArrestTick)
                        end
                        if cfg.AntiArrest then
                                pcall(antiArrestTick)
                        end
                end
        end
end)

task.spawn(function()
        while running do
                task.wait(0.3)
                if running and cfg.ShotSpam and isAlive() then
                        pcall(shotSpamTick)
                end
        end
end)

task.spawn(function()
        while running do
                local wait = 2 + math.random() * 3
                task.wait(wait)
                if running and cfg.C4Rain and isAlive() then
                        pcall(c4RainTick)
                end
        end
end)

-- ============================================================
-- Cleanup
-- ============================================================

local function cleanup()
        running = false
        disconnectAll()
        pcall(function()
                Window:Destroy()
        end)
        Global.__PrisonTrollCleanup = nil
end

Global.__PrisonTrollCleanup = cleanup

notify("Prison Troll loaded", "Every feature is remote-only - nothing moves you.")
