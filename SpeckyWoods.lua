local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PLACE_ID = 2539588846
local GOD_HEALTH = 1000000000
local HEAL_GAP = 0.15
local WATCH_GAP = 2
local NAN = 0 / 0

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Global = (getgenv and getgenv()) or _G

if type(Global.__SpeckyWoodsCleanup) == "function" then
        pcall(Global.__SpeckyWoodsCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[SpeckyWoods] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Specky Woods",
        Size = Vector2.new(500, 430),
})

local function registerEarlyExit()
        Global.__SpeckyWoodsCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__SpeckyWoodsCleanup = nil
        end
end

if game.PlaceId ~= PLACE_ID then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Specky Woods")
        section:Paragraph({Text = "Wrong game."})
        registerEarlyExit()
        return
end

local TargetPointFix = ReplicatedStorage:WaitForChild("TargetPointFix", 5)
local LastSpot = ReplicatedStorage:WaitForChild("LastSpot", 5)

if not (TargetPointFix and TargetPointFix:IsA("RemoteEvent"))
        or not (LastSpot and LastSpot:IsA("RemoteEvent")) then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Specky Woods")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local alive = true
local conns = {}

local settings = {walkSpeed = 16, jumpPower = 50, hipHeight = 0}
local godMode = false
local infJump = false
local blockKickback = true
local antiCheatDead = false
local lastSpotOwned = false
local resetOk = false
local fakeSpotOn = false
local savedSpot = nil
local targetPlayer = nil
local aimActive = false
local healToken = 0

local statusParagraph = nil
local targetDropdown = nil
local walkSlider, jumpSlider, hipSlider
local jumpToggle, godToggle

local function statusText()
        return table.concat({
                "Anti-Cheat: " .. (antiCheatDead and "Dead" or "Waiting"),
                "LastSpot: " .. (lastSpotOwned and "Owned" or "Waiting"),
                "Reset: " .. (resetOk and "Enabled" or "Pending"),
                "Kickback Lock: " .. (blockKickback and "On" or "Off"),
        }, "\n")
end

local function pushStatus()
        if statusParagraph then
                statusParagraph:Set(statusText())
        end
end

local function getChar()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then
                return character, humanoid, root
        end
        return nil
end

local function applyGod(humanoid)
        if not humanoid or not antiCheatDead then
                return
        end
        if godMode then
                humanoid.MaxHealth = GOD_HEALTH
                humanoid.Health = GOD_HEALTH
        else
                humanoid.MaxHealth = 100
                humanoid.Health = math.min(humanoid.Health, 100)
        end
end

local function applyMovement(humanoid)
        if not humanoid or not antiCheatDead then
                return
        end
        humanoid.WalkSpeed = settings.walkSpeed
        humanoid.JumpPower = settings.jumpPower
        humanoid.HipHeight = settings.hipHeight
        applyGod(humanoid)
end

local function startHeal()
        healToken = healToken + 1
        local token = healToken
        task.spawn(function()
                while alive and token == healToken and godMode do
                        local _, humanoid = getChar()
                        if humanoid and humanoid.Health > 0 then
                                humanoid.Health = humanoid.MaxHealth
                        end
                        task.wait(HEAL_GAP)
                end
        end)
end

local function enableReset(tries)
        task.spawn(function()
                for i = 1, tries do
                        if not alive then
                                return
                        end
                        local ok = pcall(function()
                                StarterGui:SetCore("ResetButtonCallback", true)
                        end)
                        if ok then
                                resetOk = true
                                pushStatus()
                                return
                        end
                        task.wait(1)
                end
        end)
end

local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)

task.spawn(function()
        if not PlayerScripts then
                antiCheatDead = true
                lastSpotOwned = true
                pushStatus()
                return
        end
        local anti = PlayerScripts:WaitForChild("AntiExploit", 8)
        if anti then
                pcall(function()
                        anti:Destroy()
                end)
        end
        antiCheatDead = true
        local loc = PlayerScripts:FindFirstChild("LastLocation")
        if loc then
                pcall(function()
                        loc:Destroy()
                end)
        end
        lastSpotOwned = true
        pushStatus()
        while alive do
                task.wait(WATCH_GAP)
                if not alive then
                        return
                end
                local a = PlayerScripts:FindFirstChild("AntiExploit")
                if a then
                        pcall(function()
                                a:Destroy()
                        end)
                end
                local l = PlayerScripts:FindFirstChild("LastLocation")
                if l then
                        pcall(function()
                                l:Destroy()
                        end)
                end
        end
end)

task.spawn(function()
        if not PlayerScripts then
                return
        end
        local rev = PlayerScripts:WaitForChild("ReviveCount", 10)
        if not rev then
                return
        end
        table.insert(conns, rev:GetPropertyChangedSignal("Value"):Connect(function()
                if blockKickback and rev.Value >= 3 then
                        rev.Value = 0
                end
        end))
end)

local function onCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid or not alive then
                return
        end
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or not alive then
                return
        end
        applyMovement(humanoid)
        humanoid.Died:Connect(function()
                local spot = root.Position
                if fakeSpotOn and savedSpot then
                        spot = savedSpot
                end
                pcall(function()
                        LastSpot:FireServer(spot)
                end)
        end)
        enableReset(10)
end

table.insert(conns, LocalPlayer.CharacterAdded:Connect(onCharacter))
if LocalPlayer.Character then
        task.spawn(onCharacter, LocalPlayer.Character)
end
enableReset(10)

table.insert(conns, UserInputService.JumpRequest:Connect(function()
        if not infJump then
                return
        end
        local _, humanoid = getChar()
        if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
end))

table.insert(conns, RunService.Heartbeat:Connect(function()
        if not aimActive or not targetPlayer then
                return
        end
        local character = targetPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
                return
        end
        pcall(function()
                TargetPointFix:FireServer(humanoid, Mouse.Hit.Position)
        end)
end))

local mainTab = Window:Tab("Main", "zap")
local moveSection = mainTab:Section("Movement")
local guardSection = mainTab:Section("Client Guards")

statusParagraph = guardSection:Paragraph({Text = statusText()})

walkSlider = moveSection:Slider({
        Text = "Walk Speed",
        Min = 16,
        Max = 500,
        Value = settings.walkSpeed,
        Callback = function(v)
                settings.walkSpeed = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

jumpSlider = moveSection:Slider({
        Text = "Jump Power",
        Min = 50,
        Max = 500,
        Value = settings.jumpPower,
        Callback = function(v)
                settings.jumpPower = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

hipSlider = moveSection:Slider({
        Text = "Hip Height",
        Min = 0,
        Max = 20,
        Value = settings.hipHeight,
        Callback = function(v)
                settings.hipHeight = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

jumpToggle = moveSection:Toggle({
        Text = "Infinite Jump",
        Value = false,
        Callback = function(v)
                infJump = v
        end,
})

godToggle = moveSection:Toggle({
        Text = "God Health",
        Value = false,
        Callback = function(v)
                godMode = v
                local _, humanoid = getChar()
                applyGod(humanoid)
                if v then
                        startHeal()
                end
        end,
})

moveSection:Button({
        Text = "Restore Defaults",
        Callback = function()
                settings.walkSpeed = 16
                settings.jumpPower = 50
                settings.hipHeight = 0
                if walkSlider then
                        walkSlider:Set(16, true)
                end
                if jumpSlider then
                        jumpSlider:Set(50, true)
                end
                if hipSlider then
                        hipSlider:Set(0, true)
                end
                if jumpToggle then
                        jumpToggle:Set(false, true)
                end
                if godToggle then
                        godToggle:Set(false, true)
                end
                local _, humanoid = getChar()
                if humanoid and antiCheatDead then
                        pcall(function()
                                humanoid.WalkSpeed = 16
                                humanoid.JumpPower = 50
                                humanoid.HipHeight = 0
                        end)
                end
                Window:Notify({
                        Title = "Specky Woods",
                        Description = "Defaults restored.",
                        Duration = 4,
                })
        end,
})

guardSection:Toggle({
        Text = "Block Revive Kickback",
        Value = true,
        Callback = function(v)
                blockKickback = v
                pushStatus()
        end,
})

local testsTab = Window:Tab("Tests", "skull")
local targetSection = testsTab:Section("Target")
local aimSection = testsTab:Section("TargetPointFix")
local tentSection = testsTab:Section("Tent Doors")
local spotSection = testsTab:Section("Death Spot")

local function playerOptions()
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                        table.insert(list, plr)
                end
        end
        return list
end

local function validTarget(value)
        return typeof(value) == "Instance" and value:IsA("Player") and value.Parent ~= nil
end

local function refreshPlayers()
        if not targetDropdown then
                return
        end
        targetDropdown:SetOptions(playerOptions())
        if validTarget(targetDropdown.Value) then
                targetPlayer = targetDropdown.Value
        else
                targetPlayer = nil
        end
end

targetDropdown = targetSection:Dropdown({
        Text = "Player",
        Options = playerOptions(),
        Callback = function(value)
                if validTarget(value) then
                        targetPlayer = value
                else
                        targetPlayer = nil
                end
        end,
})

table.insert(conns, Players.PlayerAdded:Connect(refreshPlayers))
table.insert(conns, Players.PlayerRemoving:Connect(function(leaving)
        if targetPlayer == leaving then
                targetPlayer = nil
        end
        refreshPlayers()
end))

aimSection:Toggle({
        Text = "Aim Target At Mouse",
        Value = false,
        Callback = function(v)
                aimActive = v
        end,
})

aimSection:Button({
        Text = "NaN Fling Target",
        Callback = function()
                if not validTarget(targetPlayer) then
                        Window:Notify({
                                Title = "TargetPointFix",
                                Description = "No target.",
                                Duration = 4,
                        })
                        return
                end
                local character = targetPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not humanoid then
                        Window:Notify({
                                Title = "TargetPointFix",
                                Description = "Target has no character.",
                                Duration = 4,
                        })
                        return
                end
                local poison = Vector3.new(NAN, NAN, NAN)
                for i = 1, 3 do
                        pcall(function()
                                TargetPointFix:FireServer(humanoid, poison)
                        end)
                end
                Window:Notify({
                        Title = "TargetPointFix",
                        Description = "NaN fired at " .. targetPlayer.Name .. ".",
                        Duration = 4,
                })
        end,
})

local function fireTent(rootName, label)
        if type(fireclickdetector) ~= "function" then
                Window:Notify({
                        Title = "Tents",
                        Description = "fireclickdetector unavailable.",
                        Duration = 4,
                })
                return
        end
        local tent = workspace:FindFirstChild(rootName)
        local entrance = tent and tent:FindFirstChild("Entrance")
        local clicker = entrance and entrance:FindFirstChild("Clicker")
        local cd = clicker and clicker:FindFirstChild("ClickDetector")
        if not cd then
                Window:Notify({
                        Title = "Tents",
                        Description = label .. " not found.",
                        Duration = 4,
                })
                return
        end
        pcall(function()
                fireclickdetector(cd)
        end)
        Window:Notify({
                Title = "Tents",
                Description = label .. " clicked.",
                Duration = 4,
        })
end

tentSection:Button({
        Text = "Toggle Red Tent",
        Callback = function()
                fireTent("RedTent", "Red Tent")
        end,
})

tentSection:Button({
        Text = "Toggle Blue Tent",
        Callback = function()
                fireTent("BlueTent", "Blue Tent")
        end,
})

spotSection:Button({
        Text = "Save Current Spot",
        Callback = function()
                local _, _, root = getChar()
                if not root then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No character.",
                                Duration = 4,
                        })
                        return
                end
                savedSpot = root.Position
                Window:Notify({
                        Title = "Death Spot",
                        Description = string.format(
                                "Saved (%.0f, %.0f, %.0f).",
                                savedSpot.X,
                                savedSpot.Y,
                                savedSpot.Z
                        ),
                        Duration = 4,
                })
        end,
})

spotSection:Toggle({
        Text = "Fake Death Spot",
        Value = false,
        Callback = function(v)
                fakeSpotOn = v
                if v and not savedSpot then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No spot saved yet.",
                                Duration = 4,
                        })
                end
        end,
})

spotSection:Button({
        Text = "Force Death",
        Callback = function()
                local _, humanoid = getChar()
                if not humanoid then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No character.",
                                Duration = 4,
                        })
                        return
                end
                humanoid.Health = 0
        end,
})

Global.__SpeckyWoodsCleanup = function()
        alive = false
        aimActive = false
        healToken = healToken + 1
        for _, c in ipairs(conns) do
                pcall(function()
                        c:Disconnect()
                end)
        end
        local _, humanoid = getChar()
        if humanoid and antiCheatDead then
                pcall(function()
                        humanoid.WalkSpeed = 16
                        humanoid.JumpPower = 50
                        humanoid.HipHeight = 0
                        humanoid.MaxHealth = 100
                        humanoid.Health = math.min(humanoid.Health, 100)
                end)
        end
        pcall(function()
                Window:Destroy()
        end)
        Global.__SpeckyWoodsCleanup = nil
end
