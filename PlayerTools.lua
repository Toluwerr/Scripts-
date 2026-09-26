local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AIMLOCK_BIND_NAME = "__PlayerToolsAimlock"
local FLY_BIND_NAME = "__PlayerToolsFly"
local VEHICLE_FLY_BIND_NAME = "__PlayerToolsVehicleFly"

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Global = (getgenv and getgenv()) or _G

if type(Global.__PlayerToolsCleanup) == "function" then
        pcall(Global.__PlayerToolsCleanup)
elseif type(Global.__AxiomCleanup) == "function" then
        pcall(Global.__AxiomCleanup)
elseif type(Global.__ProjectESPCleanup) == "function" then
        pcall(Global.__ProjectESPCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[PlayerTools] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Settings = {
        Enabled = false,
        TeamCheck = true,
        Highlight = true,
        ThroughWalls = true,
        ShowName = true,
        ShowHealth = true,
        ShowDistance = true,
        MaxDistance = 1500,
        FillTransparency = 0.74,
        Color = Color3.fromRGB(255, 255, 255)
}

local MovementSettings = {
        Enabled = false,
        Speed = 16,
        InfiniteJump = false,
        Noclip = false,
        Humanoid = nil,
        OriginalSpeed = nil,
        Updating = false,
        WatchConnection = nil,
        NoclipConnection = nil,
        CollisionStates = setmetatable({}, {__mode = "k"})
}

local ClickTeleportSettings = {
        Enabled = false,
        Cooldown = 0.12,
        LastTeleport = 0
}

local PlatformSettings = {
        Enabled = false,
        Part = nil,
        Connection = nil,
        UpHeld = false,
        DownHeld = false,
        ForwardHeld = false,
        MoveSpeed = 42,
        TrackHorizontalSpeed = 220,
        TrackUpSpeed = 150,
        TrackDownSpeed = 460,
        TrackSwoopSpeed = 760,
        TrackSnapDistance = 120,
        Size = Vector3.new(12, 1, 12)
}

local PartRingSettings = {
        Enabled = false,
        TargetUserId = nil,
        TargetPickerEnabled = false,
        HoveredPlayer = nil,
        PickerHighlight = nil,
        PickerRenderConnection = nil,
        PickerInputConnection = nil,
        ScanRadius = 90,
        Radius = 12,
        Height = 4,
        Speed = 3.5,
        RotationSpeed = 30,
        PullStrength = 60,
        MaximumAssemblyMass = 5000000,
        MaximumAssemblySize = 300,
        ReleasePower = 1,
        RescanInterval = 0.4,
        Parts = {},
        PartStates = setmetatable({}, {__mode = "k"}),
        Connection = nil,
        NextRescan = 0,
        CollisionStates = setmetatable({}, {__mode = "k"}),
        Cooldowns = setmetatable({}, {__mode = "k"}),
        LastStatus = nil,
        MovingCount = 0,
        ErrorCount = 0
}

local PartRing = {}

local PlayerTroll = {}


local AimlockSettings = {
        Enabled = false,
        TeamCheck = true,
        Holding = false,
        CursorRadius = 180,
        MaxDistance = 2500,
        TargetPlayer = nil,
        TargetCharacter = nil,
        TargetHumanoid = nil,
        TargetPart = nil
}

local FlingSettings = {
        Enabled = false,
        Power = 100,
        WorkerToken = 0,
        AntiFling = false,
        AntiFlingConnections = {},
        CollisionStates = setmetatable({}, {__mode = "k"})
}

local FlySettings = {
        Enabled = false,
        Speed = 50,
        Acceleration = 8,
        Deceleration = 12,
        Root = nil,
        Humanoid = nil,
        BodyVelocity = nil,
        BodyGyro = nil,
        CurrentVelocity = Vector3.zero,
        CurrentOrientation = nil,
        OriginalAutoRotate = nil,
        OriginalPlatformStand = nil,
        AnimationConnection = nil,
        AnimateScript = nil,
        OriginalAnimateDisabled = nil
}

local VehicleSettings = {
        Speed = 60,
        SteeringStrength = 8,
        CurrentSeat = nil,
        CurrentModel = nil,
        CurrentRoot = nil,
        OriginalMaxSpeed = setmetatable({}, {__mode = "k"}),
        OriginalTurnSpeed = setmetatable({}, {__mode = "k"}),
        SeatedConnection = nil,
        SpeedWatchConnection = nil,
        BoostConnection = nil,
        FlipGyro = nil,
        FlipRoot = nil,
        Updating = false
}

local VehicleFlySettings = {
        Enabled = false,
        Speed = 60,
        Acceleration = 8,
        Deceleration = 12,
        Root = nil,
        Seat = nil,
        BodyVelocity = nil,
        BodyGyro = nil,
        CurrentVelocity = Vector3.zero,
        CurrentOrientation = nil
}

local VehicleJumpSettings = {
        Power = 90,
        Cooldown = 0.65,
        LastJump = 0,
        Stabilizer = nil,
        StabilizerToken = 0
}

local VehicleTeleportSettings = {
        Enabled = false,
        Cooldown = 0.12,
        LastTeleport = 0,
        ReinforceDuration = 1.5,
        NearbyRadius = 70,
        ReinforceConnection = nil,
        ReinforceToken = 0,
        ReinforceRoot = nil,
        ReinforceSeat = nil,
        ReinforceParts = nil,
        ReinforceOffsets = nil
}

local VehicleFlingSettings = {
        Enabled = false,
        Power = 100,
        WorkerToken = 0
}

local PlayerTrollSettings = {
        BlastEnabled = false,
        BlastPower = 800,
        BlastCooldown = 1,
        MeteorEnabled = false,
        MeteorFlightTime = 1.5,
        MeteorInterval = 1.5,
        SwarmEnabled = false,
        SwarmRadius = 5,
        SwarmSpeed = 14,
        CageEnabled = false,
        CageSize = 7,
        ScanRadius = 90,
        RescanInterval = 0.4,
        TargetUserId = nil,
        TargetEveryone = false,
        TargetPickerEnabled = false,
        HoveredPlayer = nil,
        PickerHighlight = nil,
        PickerRenderConnection = nil,
        PickerInputConnection = nil,
        Parts = {},
        States = setmetatable({}, {__mode = "k"}),
        CollisionStates = setmetatable({}, {__mode = "k"}),
        Connection = nil,
        NextRescan = 0,
        NextBlast = 0,
        NextMeteor = 0,
        CycleIndex = 1,
        CurrentTarget = nil,
        MovingCount = 0,
        LastStatus = nil,
        ErrorCount = 0
}

local VehicleSpeedBoostSettings = {
        Power = 160,
        Cooldown = 0.65,
        Duration = 0.42,
        LastBoost = 0,
        ActiveUntil = 0
}

local Window
local stopVehicleFlyRuntime
local restartVehicleFly

local HIGHLIGHT_NAME = "__ProjectESPHighlight"
local TAG_NAME = "__ProjectESPLabel"
local TEXT_NAME = "__ProjectESPText"

local running = true
local connections = {}
local aimStatusLabel = nil

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnect(connection)
        if connection then
                pcall(function()
                        connection:Disconnect()
                end)
        end
end

local function getRoot(character)
        if not character then
                return nil
        end

        return character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("Torso")
end

do
        local TAU = math.pi * 2

        PartRing.getTargetOption = function()
                if not PartRingSettings.TargetUserId then
                        return "Me"
                end

                local player = Players:GetPlayerByUserId(PartRingSettings.TargetUserId)

                return player and player.Name or "Me"
        end

        PartRing.getTargetRoot = function()
                local player = LocalPlayer

                if PartRingSettings.TargetUserId then
                        player = Players:GetPlayerByUserId(PartRingSettings.TargetUserId)

                        if not player then
                                PartRingSettings.TargetUserId = nil

                                if type(PartRing.OnTargetChanged) == "function" then
                                        PartRing.OnTargetChanged("Me")
                                end

                                player = LocalPlayer
                        end
                end

                local character = player and player.Character
                local root = getRoot(character)

                if root and root.Parent then
                        return root
                end

                return nil
        end

        local function updatePartRingStatus(text)
                local message = tostring(text or "Chaos off")

                if PartRingSettings.LastStatus == message then
                        return
                end

                PartRingSettings.LastStatus = message

                if type(PartRing.OnStatusChanged) == "function" then
                        pcall(PartRing.OnStatusChanged, message)
                end
        end

        local function getPlayerFromPart(part)
                local current = part

                while current and current ~= Workspace do
                        if current:IsA("Model") then
                                local player = Players:GetPlayerFromCharacter(current)

                                if player then
                                        return player
                                end
                        end

                        current = current.Parent
                end

                return nil
        end

        local function clearPartRingPickerHighlight()
                local highlight = PartRingSettings.PickerHighlight
                PartRingSettings.PickerHighlight = nil
                PartRingSettings.HoveredPlayer = nil

                if highlight and highlight.Parent then
                        pcall(function()
                                highlight:Destroy()
                        end)
                end
        end

        local function showPartRingPickerHighlight(player)
                local character = player and player.Character

                if not character or not character.Parent then
                        clearPartRingPickerHighlight()
                        return
                end

                local highlight = PartRingSettings.PickerHighlight

                if not highlight or not highlight.Parent then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "__PlayerToolsPartRingTarget"
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.FillColor = Color3.fromRGB(66, 133, 244)
                        highlight.FillTransparency = 0.62
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0.08
                        highlight.Parent = Workspace
                        PartRingSettings.PickerHighlight = highlight
                end

                highlight.Adornee = character
                highlight.Enabled = true
                PartRingSettings.HoveredPlayer = player
        end

        PartRing.getHoveredPlayer = function()
                local camera = Workspace.CurrentCamera

                if not camera then
                        return nil
                end

                local mouseLocation = UserInputService:GetMouseLocation()
                local unitRay = camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)

                local filter = {}
                local seen = {}

                local function addFilter(instance)
                        if instance and instance.Parent and not seen[instance] then
                                seen[instance] = true
                                table.insert(filter, instance)
                        end
                end

                if LocalPlayer.Character then
                        addFilter(LocalPlayer.Character)
                end

                for _, root in ipairs(PartRingSettings.Parts) do
                        addFilter(root)

                        pcall(function()
                                for _, connected in ipairs(root:GetConnectedParts(true)) do
                                        addFilter(connected)
                                end
                        end)
                end

                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = filter
                params.IgnoreWater = false

                local result = Workspace:Raycast(
                        unitRay.Origin,
                        unitRay.Direction * 10000,
                        params
                )
                local player = getPlayerFromPart(result and result.Instance)

                return player ~= LocalPlayer and player or nil
        end

        local function updatePartRingTargetPicker()
                if not running or not PartRingSettings.TargetPickerEnabled then
                        return
                end

                local player = PartRing.getHoveredPlayer()

                if player then
                        showPartRingPickerHighlight(player)
                else
                        clearPartRingPickerHighlight()
                end
        end

        PartRing.stopTargetPicker = function()
                disconnect(PartRingSettings.PickerRenderConnection)
                disconnect(PartRingSettings.PickerInputConnection)
                PartRingSettings.PickerRenderConnection = nil
                PartRingSettings.PickerInputConnection = nil
                clearPartRingPickerHighlight()
        end

        PartRing.setTarget = function(value)
                if value == "Me" or not value then
                        PartRingSettings.TargetUserId = nil
                else
                        local player = nil

                        if typeof(value) == "Instance" and value:IsA("Player") then
                                player = value
                        else
                                player = Players:FindFirstChild(tostring(value))
                        end

                        PartRingSettings.TargetUserId = player and player.UserId or nil
                end

                if type(PartRing.OnTargetChanged) == "function" then
                        PartRing.OnTargetChanged(PartRing.getTargetOption())
                end

                if PartRingSettings.Enabled then
                        PartRing.refresh()
                end
        end

        PartRing.setPickerEnabled = function(value)
                local enabled = value and true or false

                PartRing.stopTargetPicker()
                PartRingSettings.TargetPickerEnabled = enabled

                if type(PartRing.OnPickerEnabledChanged) == "function" then
                        pcall(PartRing.OnPickerEnabledChanged, enabled)
                end

                if not enabled then
                        return
                end

                PartRingSettings.PickerRenderConnection = RunService.RenderStepped:Connect(
                        updatePartRingTargetPicker
                )

                PartRingSettings.PickerInputConnection = UserInputService.InputBegan:Connect(
                        function(input, gameProcessedEvent)
                                if gameProcessedEvent
                                        or not PartRingSettings.TargetPickerEnabled
                                        or UserInputService:GetFocusedTextBox() then
                                        return
                                end

                                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                                        return
                                end

                                local player = PartRingSettings.HoveredPlayer
                                        or PartRing.getHoveredPlayer()

                                if player then
                                        PartRing.setTarget(player)
                                        PartRing.setPickerEnabled(false)
                                end
                        end
                )
        end

        local function hasPartRingDisallowedAncestor(part)
                local current = part

                while current and current ~= Workspace do
                        if current:IsA("Tool") then
                                return true
                        end

                        if current:IsA("Model")
                                and current:FindFirstChildOfClass("Humanoid") then
                                return true
                        end

                        current = current.Parent
                end

                return false
        end

        local function getPartRingSearchRadius()
                local configuredRadius = math.clamp(
                        tonumber(PartRingSettings.ScanRadius) or 70,
                        15,
                        5000
                )
                local ringRadius = math.clamp(
                        tonumber(PartRingSettings.Radius) or 12,
                        3,
                        150
                )

                return math.clamp(
                        math.max(configuredRadius, ringRadius + 30),
                        15,
                        5000
                )
        end


        local function canRingPart(part, targetRoot)
                if not part
                        or not part:IsA("BasePart")
                        or not part.Parent
                        or part.Anchored
                        or part:IsA("Seat")
                        or part:IsA("VehicleSeat")
                        or part.AssemblyRootPart ~= part then
                        return false
                end

                if LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and part:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                if hasPartRingDisallowedAncestor(part) then
                        return false
                end

                local maximumAssemblyMass = math.clamp(
                        tonumber(PartRingSettings.MaximumAssemblyMass) or 5000000,
                        1,
                        10000000
                )
                local maximumAssemblySize = math.clamp(
                        tonumber(PartRingSettings.MaximumAssemblySize) or 300,
                        1,
                        10000
                )

                if part.AssemblyMass > maximumAssemblyMass
                        or part.Size.Magnitude > maximumAssemblySize then
                        return false
                end

                return (part.Position - targetRoot.Position).Magnitude
                        <= getPartRingSearchRadius()
        end

        local function getPartRingAssemblyParts(root)
                local parts = {}
                local seen = {}

                local function addPart(part)
                        if not part
                                or not part:IsA("BasePart")
                                or not part.Parent
                                or seen[part]
                                or part.AssemblyRootPart ~= root then
                                return
                        end

                        seen[part] = true
                        table.insert(parts, part)
                end

                addPart(root)

                pcall(function()
                        for _, part in ipairs(root:GetConnectedParts(true)) do
                                addPart(part)
                        end
                end)

                return parts
        end

        local function removeLegacyPartRingConstraints(root)
                for _, name in ipairs({
                        "__PlayerToolsPartRingAlign",
                        "__PlayerToolsPartRingAttachment"
                }) do
                        local object = root:FindFirstChild(name)

                        if object then
                                pcall(function()
                                        object:Destroy()
                                end)
                        end
                end
        end

        local function getPartRingState(root)
                local state = PartRingSettings.PartStates[root]

                if state then
                        return state
                end

                -- Chaos parameters: every part draws its own random orbit
                -- shape at capture time, so the swarm tangles instead of
                -- marching in an even circle.
                state = {
                        CollisionParts = {},
                        Angle = nil,
                        FailCount = 0,
                        PrevPos = nil,
                        LastSlot = nil,
                        RadiusScale = 0.3 + math.random() * 1.4,
                        HeightOffset = (math.random() - 0.5) * 10,
                        SpeedScale = 0.45 + math.random() * 1.3,
                        Direction = math.random() < 0.5 and -1 or 1,
                        WobbleAmplitude = 1 + math.random() * 5,
                        WobbleFrequency = 0.8 + math.random() * 2.6,
                        WobblePhase = math.random() * TAU,
                        SpinAxis = Vector3.new(
                                (math.random() - 0.5) * 0.8,
                                1,
                                (math.random() - 0.5) * 0.8
                        ).Unit,
                        SpinScale = 0.55 + math.random() * 0.9,
                        SpinSign = math.random() < 0.5 and -1 or 1
                }
                PartRingSettings.PartStates[root] = state

                return state
        end

        local function restorePartRingPart(root)
                -- Release a part back to the world. The fling is real
                -- physics for assemblies this client owns and inert for
                -- any other, so it is always safe to fire.
                local state = PartRingSettings.PartStates[root]
                local controlledParts = state and state.CollisionParts or {root}

                removeLegacyPartRingConstraints(root)

                local releasePower = math.clamp(
                        tonumber(PartRingSettings.ReleasePower) or 1,
                        0,
                        5
                )

                for _, part in ipairs(controlledParts) do
                        local originalCollision = PartRingSettings.CollisionStates[part]

                        if part and part.Parent then
                                pcall(function()
                                        if originalCollision ~= nil then
                                                part.CanCollide = originalCollision
                                        end
                                end)
                        end

                        PartRingSettings.CollisionStates[part] = nil
                end

                if root and root.Parent then
                        pcall(function()
                                if releasePower <= 0.001 then
                                        root.AssemblyLinearVelocity = Vector3.zero
                                        root.AssemblyAngularVelocity = Vector3.zero
                                else
                                        local linearVelocity = root.AssemblyLinearVelocity
                                        local angularVelocity = root.AssemblyAngularVelocity
                                        local verticalBoost = (releasePower - 1) * 25

                                        root.AssemblyLinearVelocity = linearVelocity * releasePower
                                                + Vector3.new(0, verticalBoost, 0)
                                        root.AssemblyAngularVelocity = angularVelocity
                                                * math.min(releasePower, 2)
                                end
                        end)
                end

                PartRingSettings.PartStates[root] = nil
        end

        local function preparePartForRing(root)
                removeLegacyPartRingConstraints(root)

                local state = getPartRingState(root)

                local known = {}

                for _, part in ipairs(state.CollisionParts) do
                        known[part] = true
                end

                for _, part in ipairs(getPartRingAssemblyParts(root)) do
                        if not known[part] then
                                known[part] = true
                                table.insert(state.CollisionParts, part)
                        end

                        if PartRingSettings.CollisionStates[part] == nil then
                                PartRingSettings.CollisionStates[part] = part.CanCollide
                        end

                        pcall(function()
                                part.CanCollide = false
                        end)
                end
        end

        local function isPartRingViable(part, targetRoot, distanceLimit)
                -- Cheap per-frame validity. The full rule set runs at rescan
                -- time; this only catches the ways a part can die between
                -- rescans: destroyed, merged into another assembly, flung out
                -- of range, or corrupted to a NaN position (NaN fails every
                -- comparison, so it drops out automatically).
                if not part
                        or not part.Parent
                        or part.AssemblyRootPart ~= part then
                        return false
                end

                local offset = part.Position - targetRoot.Position

                return offset.Magnitude <= distanceLimit
        end

        local function applyRingPlacement(
                part,
                targetNow,
                targetNext,
                tangentVelocity,
                stepTime,
                pullGain,
                carry,
                angularVelocity
        )
                part.CanCollide = false

                local currentPosition = part.Position

                -- Real-motion swarm: CFrame is never written here, because a
                -- client CFrame write only ever moves a part on this screen.
                -- The only motion that replicates to the server is physics on
                -- an assembly this client owns, so the swarm is driven purely
                -- by velocity commands. The correction below lands the part
                -- on its next slot after one physics step (gravity included).
                -- Nothing moderates it: there is no approach cap, no distance
                -- gate, no speed ceiling - a part 90 studs away is ordered to
                -- close the entire gap this frame at whatever velocity
                -- physics will actually deliver. Pull Strength only scales
                -- how hard that yank is: 1.0 would be an exact landing, the
                -- default 1.34 slams parts in with over-correction, and the
                -- slider max (1.9) is a violent snap.
                local residual = targetNext - currentPosition
                        - tangentVelocity * stepTime
                local correction = residual / stepTime * pullGain
                        + Vector3.new(0, 0.5 * Workspace.Gravity * stepTime, 0)

                local velocity = tangentVelocity + correction + carry

                part.AssemblyLinearVelocity = velocity
                part.AssemblyAngularVelocity = angularVelocity

                return velocity, currentPosition
        end

        local function composePartRingStatus()
                local parts = PartRingSettings.Parts
                local total = #parts

                if total > 0 then
                        local moving = tonumber(PartRingSettings.MovingCount) or 0
                        local label

                        if moving >= total then
                                label = "Chaos: " .. tostring(total) .. " parts swarming"
                        else
                                label = "Chaos: " .. tostring(moving) .. " of "
                                        .. tostring(total)
                                        .. " parts swarming (rest waiting on physics)"
                        end

                        updatePartRingStatus(label)
                else
                        updatePartRingStatus("No eligible loose parts")
                end
        end

        local function clearPartRingParts()
                for _, part in ipairs(PartRingSettings.Parts) do
                        restorePartRingPart(part)
                end

                PartRingSettings.Parts = {}
                PartRingSettings.PartStates = setmetatable({}, {__mode = "k"})
                PartRingSettings.CollisionStates = setmetatable({}, {__mode = "k"})
                PartRingSettings.Cooldowns = setmetatable({}, {__mode = "k"})
        end

        PartRing.refresh = function()
                local targetRoot = PartRing.getTargetRoot()

                if not targetRoot or not targetRoot.Parent then
                        clearPartRingParts()
                        updatePartRingStatus("Target unavailable")
                        return
                end

                local now = os.clock()
                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Exclude

                local filter = {}

                if LocalPlayer.Character then
                        table.insert(filter, LocalPlayer.Character)
                end

                local targetPlayer = PartRingSettings.TargetUserId
                        and Players:GetPlayerByUserId(PartRingSettings.TargetUserId)
                        or LocalPlayer

                if targetPlayer
                        and targetPlayer.Character
                        and targetPlayer.Character ~= LocalPlayer.Character then
                        table.insert(filter, targetPlayer.Character)
                end

                overlap.FilterDescendantsInstances = filter
                overlap.MaxParts = 0

                local nearby = {}

                pcall(function()
                        nearby = Workspace:GetPartBoundsInRadius(
                                targetRoot.Position,
                                getPartRingSearchRadius(),
                                overlap
                        )
                end)

                local candidates = {}
                local candidateSet = {}

                for _, part in ipairs(nearby) do
                        local cooldown = PartRingSettings.Cooldowns[part]

                        if canRingPart(part, targetRoot)
                                and not candidateSet[part]
                                and not (cooldown and cooldown > now) then
                                candidateSet[part] = true
                                table.insert(candidates, part)
                        end
                end

                table.sort(candidates, function(first, second)
                        return (first.Position - targetRoot.Position).Magnitude
                                < (second.Position - targetRoot.Position).Magnitude
                end)

                local nextParts = {}
                local selected = {}

                for _, part in ipairs(PartRingSettings.Parts) do
                        if candidateSet[part] then
                                selected[part] = true
                                table.insert(nextParts, part)
                        else
                                restorePartRingPart(part)
                        end
                end

                for _, part in ipairs(candidates) do
                        if not selected[part] then
                                selected[part] = true
                                table.insert(nextParts, part)
                        end
                end

                PartRingSettings.Parts = nextParts

                for _, part in ipairs(nextParts) do
                        preparePartForRing(part)
                end

                PartRingSettings.NextRescan = os.clock() + PartRingSettings.RescanInterval

                composePartRingStatus()
        end

        PartRing.stop = function()
                disconnect(PartRingSettings.Connection)
                PartRingSettings.Connection = nil
                clearPartRingParts()
                PartRingSettings.NextRescan = 0
                updatePartRingStatus("Chaos off")
        end

        local function updatePartRing(deltaTime)
                if not running or not PartRingSettings.Enabled then
                        return
                end

                local targetRoot = PartRing.getTargetRoot()

                if not targetRoot or not targetRoot.Parent then
                        -- Target died, left or is respawning: release every
                        -- part instead of leaving a frozen ring in the air.
                        if #PartRingSettings.Parts > 0 then
                                clearPartRingParts()
                                updatePartRingStatus("Target unavailable")
                        end

                        return
                end

                local now = os.clock()

                if now >= PartRingSettings.NextRescan then
                        PartRing.refresh()
                end

                local parts = PartRingSettings.Parts
                local searchLimit = getPartRingSearchRadius() * 1.02
                local removedAny = false

                -- The only reasons a part ever leaves the ring are physical:
                -- destroyed, flung out of range, or unwritable for 30 frames
                -- straight. Disobedience is NOT a reason: parts the server
                -- still owns simply hold position and keep receiving the
                -- velocity order every frame until Roblox hands their
                -- simulation to this client, at which point they fly in.
                for index = #parts, 1, -1 do
                        local part = parts[index]
                        local state = PartRingSettings.PartStates[part]

                        if not part or not part.Parent then
                                restorePartRingPart(part)
                                table.remove(parts, index)
                                removedAny = true
                        else
                                local failedTooOften = state ~= nil
                                        and (state.FailCount or 0) >= 30

                                if failedTooOften
                                        or not isPartRingViable(part, targetRoot, searchLimit) then
                                        restorePartRingPart(part)

                                        if failedTooOften then
                                                PartRingSettings.Cooldowns[part] = now + 6
                                        end

                                        table.remove(parts, index)
                                        removedAny = true
                                end
                        end
                end

                if removedAny then
                        composePartRingStatus()
                end

                local count = #parts

                if count == 0 then
                        return
                end

                local radius = math.clamp(
                        tonumber(PartRingSettings.Radius) or 12,
                        3,
                        150
                )
                local height = math.clamp(
                        tonumber(PartRingSettings.Height) or 4,
                        -10,
                        25
                )
                local spinSpeed = math.clamp(
                        tonumber(PartRingSettings.Speed) or 3.5,
                        0,
                        20
                )
                local rotationSpeed = math.clamp(
                        tonumber(PartRingSettings.RotationSpeed) or 30,
                        0,
                        300
                )
                local pullStrength = math.clamp(
                        tonumber(PartRingSettings.PullStrength) or 60,
                        1,
                        100
                )
                local stepTime = math.clamp(tonumber(deltaTime) or 0, 0, 0.1)

                if stepTime < 0.0001 then
                        return
                end

                local center = targetRoot.Position

                if center.X ~= center.X
                        or center.Y ~= center.Y
                        or center.Z ~= center.Z then
                        -- Corrupted target position; skip this frame rather
                        -- than scattering every part to NaN coordinates.
                        return
                end

                local carry = targetRoot.AssemblyLinearVelocity * 0.5

                if carry.X ~= carry.X
                        or carry.Y ~= carry.Y
                        or carry.Z ~= carry.Z then
                        carry = Vector3.zero
                elseif carry.Magnitude > 250 then
                        carry = carry.Unit * 250
                end

                -- Pull Strength is pure yank hardness with zero moderation
                -- behind it. The old approach cap is gone entirely: capture
                -- always runs at whatever speed physics can physically
                -- deliver this frame, from any distance. 1 maps to a loose
                -- drift (~0.51x), 60 to a hard slam (~1.34x), 100 to a
                -- violent over-corrected snap (~1.9x). Every value stays
                -- numerically stable (error factor |1 - gain| < 1).
                local pullGain = 0.5 + pullStrength * 0.014
                local slotTolerance = math.max(2.5, radius * 0.25)
                local movingCount = 0

                for index = 1, count do
                        local part = parts[index]
                        local state = PartRingSettings.PartStates[part]

                        if not state then
                                state = getPartRingState(part)
                        end

                        local currentPosition = part.Position

                        if state.Angle == nil then
                                -- The part enters the swarm from wherever it
                                -- currently is, so joining never teleports it.
                                local offsetX = currentPosition.X - center.X
                                local offsetZ = currentPosition.Z - center.Z

                                if offsetX ~= offsetX or offsetZ ~= offsetZ then
                                        state.Angle = 0
                                else
                                        state.Angle = math.atan2(offsetZ, offsetX) % TAU
                                end
                        end

                        -- Chaos trajectory: each part sweeps its own private
                        -- orbit - personal radius band, personal height,
                        -- personal speed, personal direction, breathing
                        -- wobble - so the swarm tangles around the target
                        -- instead of marching in a circle. The exact-landing
                        -- controller tracks this shape exactly like it tracked
                        -- the ring: land on targetNext after one step.
                        local angularSpeed = spinSpeed * state.SpeedScale
                                * state.Direction
                        local angle = state.Angle
                        local nextAngle = angle + angularSpeed * stepTime

                        state.Angle = nextAngle % TAU

                        local wobbleNow = math.sin(
                                now * state.WobbleFrequency + state.WobblePhase
                        ) * state.WobbleAmplitude
                        local wobbleNext = math.sin(
                                (now + stepTime) * state.WobbleFrequency
                                        + state.WobblePhase
                        ) * state.WobbleAmplitude
                        local verticalNow = math.cos(
                                now * state.WobbleFrequency * 0.7
                                        + state.WobblePhase * 1.3
                        ) * state.WobbleAmplitude * 0.6
                        local verticalNext = math.cos(
                                (now + stepTime) * state.WobbleFrequency * 0.7
                                        + state.WobblePhase * 1.3
                        ) * state.WobbleAmplitude * 0.6
                        local radiusNow = math.max(
                                2,
                                radius * state.RadiusScale + wobbleNow
                        )
                        local radiusNext = math.max(
                                2,
                                radius * state.RadiusScale + wobbleNext
                        )
                        local targetNow = center + Vector3.new(
                                math.cos(angle) * radiusNow,
                                height + state.HeightOffset + verticalNow,
                                math.sin(angle) * radiusNow
                        )
                        local targetNext = center + Vector3.new(
                                math.cos(nextAngle) * radiusNext,
                                height + state.HeightOffset + verticalNext,
                                math.sin(nextAngle) * radiusNext
                        )
                        local tangentSpeed = radiusNow * angularSpeed
                        local tangentVelocity = Vector3.new(
                                -math.sin(angle) * tangentSpeed,
                                0,
                                math.cos(angle) * tangentSpeed
                        )
                        local angularVelocity = state.SpinAxis
                                * (rotationSpeed * state.SpinScale
                                        * state.SpinSign)

                        -- Ownership-greedy command: every part receives the
                        -- exact same real physics order every single frame,
                        -- forever. Parts this client owns fly into the swarm
                        -- through replicating physics; parts still owned by
                        -- the server ignore the order for now, and the moment
                        -- Roblox hands their simulation to this client they
                        -- snap into the chaos - no probe, no release, no
                        -- restart, no giving up before ownership arrives.
                        -- There is no CFrame and no other client-only motion
                        -- anywhere in the engine, so nothing can look pulled
                        -- in without really being pulled in.
                        if state.PrevPos then
                                local moved = (currentPosition - state.PrevPos).Magnitude

                                if moved ~= moved then
                                        moved = 0
                                end

                                if moved > 0.05
                                        or (state.LastSlot
                                                and (currentPosition - state.LastSlot).Magnitude
                                                        <= slotTolerance) then
                                        movingCount = movingCount + 1
                                end
                        end

                        local placed, _, preWritePosition = pcall(
                                applyRingPlacement,
                                part,
                                targetNow,
                                targetNext,
                                tangentVelocity,
                                stepTime,
                                pullGain,
                                carry,
                                angularVelocity
                        )

                        state.PrevPos = preWritePosition
                        state.LastSlot = targetNow

                        if placed then
                                state.FailCount = 0
                        else
                                state.FailCount = state.FailCount + 1
                        end
                end

                PartRingSettings.MovingCount = movingCount
        end

        PartRing.setEnabled = function(value)
                local enabled = value and true or false

                if not enabled then
                        PartRing.setPickerEnabled(false)
                end

                PartRing.stop()
                PartRingSettings.Enabled = enabled

                if type(PartRing.OnEnabledChanged) == "function" then
                        pcall(PartRing.OnEnabledChanged, enabled)
                end

                if not enabled then
                        return
                end

                PartRing.refresh()
                PartRingSettings.Connection = RunService.Heartbeat:Connect(
                        function(stepTime)
                                -- One bad frame must never freeze the whole
                                -- ring silently; surface persistent errors in
                                -- the status label so they are actually
                                -- visible instead of "it just stopped working".
                                local ok, err = pcall(updatePartRing, stepTime)

                                if ok then
                                        PartRingSettings.ErrorCount = 0
                                        return
                                end

                                PartRingSettings.ErrorCount = PartRingSettings.ErrorCount + 1

                                if PartRingSettings.ErrorCount == 5 then
                                        updatePartRingStatus(
                                                "Engine error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )
        end

end

do
        local TAU = math.pi * 2

        -- ============================================================
        -- Player Troll: real-physics trolling aimed at OTHER PLAYERS.
        -- Loose parts near your character have their simulation handed
        -- to YOUR client, so velocity writes on them replicate to the
        -- server and everyone sees the motion. Volleys are launched
        -- with exact-landing ballistics - one velocity write that
        -- compensates gravity and leads the victim's velocity - so
        -- each part is guaranteed to arrive where the victim WILL be,
        -- no matter who simulates it mid-flight. Continuous modes
        -- (swarm, cage) track the victim every frame with the same
        -- exact-landing controller Chaos uses. Collisions stay ON, so
        -- every arrival is a real hit, a real body-block, a real
        -- wall. No CFrame anywhere: nothing can look trolled without
        -- really being trolled on the server.
        -- ============================================================

        local function updatePlayerTrollStatus(text)
                local message = tostring(text or "Player Troll off")

                if PlayerTrollSettings.LastStatus == message then
                        return
                end

                PlayerTrollSettings.LastStatus = message

                if type(PlayerTroll.OnStatusChanged) == "function" then
                        pcall(PlayerTroll.OnStatusChanged, message)
                end
        end

        local function getTrollMyRoot()
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if root and root.Parent then
                        return root
                end

                return nil
        end

        local function isPlayerTrollActive()
                return PlayerTrollSettings.BlastEnabled
                        or PlayerTrollSettings.MeteorEnabled
                        or PlayerTrollSettings.SwarmEnabled
                        or PlayerTrollSettings.CageEnabled
        end

        local function getTrollScanRadius()
                return math.clamp(
                        tonumber(PlayerTrollSettings.ScanRadius) or 90,
                        15,
                        500
                )
        end

        local function trollGetPlayerFromPart(part)
                local current = part

                while current and current ~= Workspace do
                        if current:IsA("Model") then
                                local player = Players:GetPlayerFromCharacter(current)

                                if player then
                                        return player
                                end
                        end

                        current = current.Parent
                end

                return nil
        end

        local function hasTrollDisallowedAncestor(part)
                local current = part

                while current and current ~= Workspace do
                        if current:IsA("Tool") then
                                return true
                        end

                        if current:IsA("Model")
                                and current:FindFirstChildOfClass("Humanoid") then
                                return true
                        end

                        current = current.Parent
                end

                return false
        end

        local function canTrollPart(part)
                if not part
                        or not part:IsA("BasePart")
                        or not part.Parent
                        or part.Anchored
                        or part:IsA("Seat")
                        or part:IsA("VehicleSeat")
                        or part.AssemblyRootPart ~= part then
                        return false
                end

                if LocalPlayer.Character
                        and part:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and part:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                if hasTrollDisallowedAncestor(part) then
                        return false
                end

                -- Never fight the Chaos engine over the same parts.
                if PartRingSettings.Enabled then
                        for _, ringed in ipairs(PartRingSettings.Parts) do
                                if ringed == part then
                                        return false
                                end
                        end
                end

                return true
        end

        local function getPlayerTrollTargetOption()
                if PlayerTrollSettings.TargetEveryone then
                        return "Everyone"
                end

                local player = PlayerTrollSettings.TargetUserId
                        and Players:GetPlayerByUserId(PlayerTrollSettings.TargetUserId)
                        or nil

                return player and player.DisplayName or "Nearest"
        end

        local function clearTrollPickerHighlight()
                local highlight = PlayerTrollSettings.PickerHighlight
                PlayerTrollSettings.PickerHighlight = nil
                PlayerTrollSettings.HoveredPlayer = nil

                if highlight and highlight.Parent then
                        pcall(function()
                                highlight:Destroy()
                        end)
                end
        end

        local function showTrollPickerHighlight(player)
                local character = player and player.Character

                if not character or not character.Parent then
                        clearTrollPickerHighlight()
                        return
                end

                local highlight = PlayerTrollSettings.PickerHighlight

                if not highlight or not highlight.Parent then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "__PlayerToolsTrollTarget"
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.FillColor = Color3.fromRGB(235, 64, 52)
                        highlight.FillTransparency = 0.62
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0.08
                        highlight.Parent = Workspace
                        PlayerTrollSettings.PickerHighlight = highlight
                end

                highlight.Adornee = character
                highlight.Enabled = true
                PlayerTrollSettings.HoveredPlayer = player
        end

        PlayerTroll.getHoveredPlayer = function()
                local camera = Workspace.CurrentCamera

                if not camera then
                        return nil
                end

                local mouseLocation = UserInputService:GetMouseLocation()
                local unitRay = camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)

                local filter = {}

                if LocalPlayer.Character then
                        table.insert(filter, LocalPlayer.Character)
                end

                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = filter
                params.IgnoreWater = false

                local result = Workspace:Raycast(
                        unitRay.Origin,
                        unitRay.Direction * 10000,
                        params
                )
                local player = trollGetPlayerFromPart(result and result.Instance)

                return player ~= LocalPlayer and player or nil
        end

        local function updateTrollTargetPicker()
                if not running or not PlayerTrollSettings.TargetPickerEnabled then
                        return
                end

                local player = PlayerTroll.getHoveredPlayer()

                if player then
                        showTrollPickerHighlight(player)
                else
                        clearTrollPickerHighlight()
                end
        end

        PlayerTroll.stopTargetPicker = function()
                disconnect(PlayerTrollSettings.PickerRenderConnection)
                disconnect(PlayerTrollSettings.PickerInputConnection)
                PlayerTrollSettings.PickerRenderConnection = nil
                PlayerTrollSettings.PickerInputConnection = nil
                clearTrollPickerHighlight()
        end

        PlayerTroll.setTarget = function(value)
                if value == "Nearest" or not value then
                        PlayerTrollSettings.TargetUserId = nil
                        PlayerTrollSettings.TargetEveryone = false
                else
                        local player = nil

                        if typeof(value) == "Instance" and value:IsA("Player") then
                                player = value
                        else
                                player = Players:FindFirstChild(tostring(value))
                        end

                        if player then
                                PlayerTrollSettings.TargetUserId = player.UserId
                                PlayerTrollSettings.TargetEveryone = false
                        end
                end

                if type(PlayerTroll.OnTargetChanged) == "function" then
                        pcall(PlayerTroll.OnTargetChanged, getPlayerTrollTargetOption())
                end

                if isPlayerTrollActive() then
                        PlayerTrollSettings.NextRescan = 0
                end
        end

        PlayerTroll.setTargetEveryone = function(value)
                PlayerTrollSettings.TargetEveryone = value and true or false

                if PlayerTrollSettings.TargetEveryone then
                        PlayerTrollSettings.TargetUserId = nil
                        PlayerTrollSettings.CycleIndex = 1
                end

                if type(PlayerTroll.OnTargetChanged) == "function" then
                        pcall(PlayerTroll.OnTargetChanged, getPlayerTrollTargetOption())
                end
        end

        PlayerTroll.setPickerEnabled = function(value)
                local enabled = value and true or false

                PlayerTroll.stopTargetPicker()
                PlayerTrollSettings.TargetPickerEnabled = enabled

                if type(PlayerTroll.OnPickerEnabledChanged) == "function" then
                        pcall(PlayerTroll.OnPickerEnabledChanged, enabled)
                end

                if not enabled then
                        return
                end

                PlayerTrollSettings.PickerRenderConnection = RunService.RenderStepped:Connect(
                        updateTrollTargetPicker
                )

                PlayerTrollSettings.PickerInputConnection = UserInputService.InputBegan:Connect(
                        function(input, gameProcessedEvent)
                                if gameProcessedEvent
                                        or not PlayerTrollSettings.TargetPickerEnabled
                                        or UserInputService:GetFocusedTextBox() then
                                        return
                                end

                                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                                        return
                                end

                                local player = PlayerTrollSettings.HoveredPlayer
                                        or PlayerTroll.getHoveredPlayer()

                                if player then
                                        PlayerTroll.setTarget(player)
                                        PlayerTroll.setPickerEnabled(false)
                                end
                        end
                )
        end

        local function collectTrollVictims()
                local victims = {}

                for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                                local character = player.Character
                                local root = character
                                        and character:FindFirstChild("HumanoidRootPart")

                                if root and root.Parent then
                                        table.insert(victims, {
                                                player = player,
                                                root = root
                                        })
                                end
                        end
                end

                return victims
        end

        local function resolveTrollVictim(myRoot, advanceCycle)
                local victims = collectTrollVictims()

                if #victims == 0 then
                        PlayerTrollSettings.CurrentTarget = nil
                        return nil
                end

                if PlayerTrollSettings.TargetEveryone then
                        if advanceCycle then
                                PlayerTrollSettings.CycleIndex = PlayerTrollSettings.CycleIndex + 1
                        end

                        local pick = ((PlayerTrollSettings.CycleIndex - 1) % #victims) + 1
                        PlayerTrollSettings.CurrentTarget = victims[pick].player

                        return victims[pick]
                end

                if PlayerTrollSettings.TargetUserId then
                        for _, victim in ipairs(victims) do
                                if victim.player.UserId == PlayerTrollSettings.TargetUserId then
                                        PlayerTrollSettings.CurrentTarget = victim.player

                                        return victim
                                end
                        end
                end

                -- Nearest living player to me, recomputed every frame.
                local nearest = nil
                local nearestDistance = nil

                for _, victim in ipairs(victims) do
                        local distance = (victim.root.Position - myRoot.Position).Magnitude

                        if not nearestDistance or distance < nearestDistance then
                                nearestDistance = distance
                                nearest = victim
                        end
                end

                PlayerTrollSettings.CurrentTarget = nearest.player

                return nearest
        end

        local function makeTrollState()
                local axis = Vector3.new(
                        math.random() * 2 - 1,
                        math.random() * 2 - 1,
                        math.random() * 2 - 1
                )

                if axis.Magnitude < 0.05 then
                        axis = Vector3.new(0, 1, 0)
                else
                        axis = axis.Unit
                end

                return {
                        Angle = nil,
                        RadiusScale = 0.55 + math.random() * 0.9,
                        HeightOffset = (math.random() - 0.5) * 4,
                        SpeedScale = 0.6 + math.random() * 0.9,
                        Direction = math.random() < 0.5 and -1 or 1,
                        SpinAxis = axis,
                        InFlightUntil = 0,
                        PrevPos = nil
                }
        end

        local function prepareTrollPart(part)
                if PlayerTrollSettings.CollisionStates[part] == nil then
                        PlayerTrollSettings.CollisionStates[part] = part.CanCollide
                end

                if PlayerTrollSettings.States[part] == nil then
                        PlayerTrollSettings.States[part] = makeTrollState()
                end

                pcall(function()
                        part.CanCollide = true
                end)
        end

        local function releaseTrollPart(part)
                local original = PlayerTrollSettings.CollisionStates[part]

                if original ~= nil then
                        pcall(function()
                                part.CanCollide = original
                        end)
                end

                PlayerTrollSettings.CollisionStates[part] = nil
                PlayerTrollSettings.States[part] = nil
        end

        local function refreshPlayerTroll(myRoot)
                local now = os.clock()
                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Exclude

                local filter = {}

                if LocalPlayer.Character then
                        table.insert(filter, LocalPlayer.Character)
                end

                overlap.FilterDescendantsInstances = filter
                overlap.MaxParts = 0

                local nearby = {}

                pcall(function()
                        nearby = Workspace:GetPartBoundsInRadius(
                                myRoot.Position,
                                getTrollScanRadius(),
                                overlap
                        )
                end)

                local candidateSet = {}

                for _, part in ipairs(nearby) do
                        if canTrollPart(part) then
                                candidateSet[part] = true
                        end
                end

                local nextParts = {}

                for _, part in ipairs(PlayerTrollSettings.Parts) do
                        if candidateSet[part] and part.Parent then
                                candidateSet[part] = nil
                                table.insert(nextParts, part)
                        else
                                releaseTrollPart(part)
                        end
                end

                local fresh = {}

                for _, part in ipairs(nearby) do
                        if candidateSet[part] then
                                table.insert(fresh, part)
                        end
                end

                table.sort(fresh, function(first, second)
                        return (first.Position - myRoot.Position).Magnitude
                                < (second.Position - myRoot.Position).Magnitude
                end)

                for _, part in ipairs(fresh) do
                        table.insert(nextParts, part)
                end

                PlayerTrollSettings.Parts = nextParts

                for _, part in ipairs(nextParts) do
                        prepareTrollPart(part)
                end

                PlayerTrollSettings.NextRescan = now + PlayerTrollSettings.RescanInterval
        end

        local function fireTrollVolley(victim, usePower, fixedTime, aimOffset, now)
                -- Exact-landing ballistics: one velocity write per part,
                -- launched while this client owns the assembly, that
                -- lands exactly where the victim WILL be after T
                -- seconds - gravity fully compensated, the victim's
                -- velocity fully led. After the write the part is
                -- ballistic, so it hits no matter who simulates the
                -- rest of its flight.
                local victimRoot = victim.root
                local victimVelocity = victimRoot.AssemblyLinearVelocity

                if victimVelocity.X ~= victimVelocity.X
                        or victimVelocity.Y ~= victimVelocity.Y
                        or victimVelocity.Z ~= victimVelocity.Z then
                        victimVelocity = Vector3.zero
                elseif victimVelocity.Magnitude > 500 then
                        victimVelocity = victimVelocity.Unit * 500
                end

                local victimPosition = victimRoot.Position

                if victimPosition.X ~= victimPosition.X
                        or victimPosition.Y ~= victimPosition.Y
                        or victimPosition.Z ~= victimPosition.Z then
                        return 0
                end

                local count = 0

                for _, part in ipairs(PlayerTrollSettings.Parts) do
                        local state = PlayerTrollSettings.States[part]

                        if state
                                and part.Parent
                                and now >= (state.InFlightUntil or 0) then
                                local position = part.Position

                                if position.X == position.X
                                        and position.Y == position.Y
                                        and position.Z == position.Z then
                                        local flightTime = fixedTime

                                        if not flightTime then
                                                local distance = (victimPosition - position).Magnitude

                                                flightTime = math.clamp(
                                                        distance / math.max(usePower or 800, 1),
                                                        0.06,
                                                        4
                                                )
                                        end

                                        local aim = victimPosition
                                                + victimVelocity * flightTime
                                                + aimOffset
                                        local launch = (aim - position) / flightTime
                                                + Vector3.new(
                                                        0,
                                                        0.5 * Workspace.Gravity * flightTime,
                                                        0
                                                )

                                        pcall(function()
                                                part.CanCollide = true
                                                part.AssemblyLinearVelocity = launch
                                                part.AssemblyAngularVelocity = state.SpinAxis * 25
                                        end)

                                        state.InFlightUntil = now + flightTime + 0.4
                                        count = count + 1
                                end
                        end
                end

                return count
        end

        local function composePlayerTrollStatus(victim)
                local total = #PlayerTrollSettings.Parts

                if not victim then
                        updatePlayerTrollStatus("No players in range")
                        return
                end

                if total == 0 then
                        updatePlayerTrollStatus("No loose parts in range")
                        return
                end

                local moving = tonumber(PlayerTrollSettings.MovingCount) or 0
                local name = victim.player.DisplayName

                if moving > 0 then
                        updatePlayerTrollStatus(
                                "Trolling " .. name .. ": " .. tostring(total)
                                        .. " parts (" .. tostring(moving) .. " moving)"
                        )
                else
                        updatePlayerTrollStatus(
                                "Trolling " .. name .. ": " .. tostring(total)
                                        .. " parts (rest waiting on physics)"
                        )
                end
        end

        local CAGE_OFFSETS = {
                Vector3.new(1, 0, 0),
                Vector3.new(-1, 0, 0),
                Vector3.new(0, 0, 1),
                Vector3.new(0, 0, -1),
                Vector3.new(0, 0.9, 0)
        }

        local function updatePlayerTroll(deltaTime)
                if not running or not isPlayerTrollActive() then
                        return
                end

                local myRoot = getTrollMyRoot()

                if not myRoot then
                        if #PlayerTrollSettings.Parts > 0 then
                                for _, part in ipairs(PlayerTrollSettings.Parts) do
                                        releaseTrollPart(part)
                                end

                                PlayerTrollSettings.Parts = {}
                        end

                        updatePlayerTrollStatus("Character unavailable")
                        return
                end

                local now = os.clock()

                if now >= PlayerTrollSettings.NextRescan then
                        refreshPlayerTroll(myRoot)
                end

                local stepTime = math.clamp(tonumber(deltaTime) or 0, 0, 0.1)

                if stepTime < 0.0001 then
                        return
                end

                local blastEnabled = PlayerTrollSettings.BlastEnabled
                local meteorEnabled = PlayerTrollSettings.MeteorEnabled
                local swarmEnabled = PlayerTrollSettings.SwarmEnabled
                local cageEnabled = PlayerTrollSettings.CageEnabled

                local blastDue = blastEnabled and now >= PlayerTrollSettings.NextBlast
                local meteorDue = meteorEnabled and now >= PlayerTrollSettings.NextMeteor

                local victim = resolveTrollVictim(myRoot, blastDue or meteorDue)

                if not victim then
                        composePlayerTrollStatus(nil)
                        return
                end

                if blastDue then
                        local power = math.clamp(
                                tonumber(PlayerTrollSettings.BlastPower) or 800,
                                50,
                                3000
                        )
                        local fired = fireTrollVolley(
                                victim,
                                power,
                                nil,
                                Vector3.new(0, 1, 0),
                                now
                        )

                        PlayerTrollSettings.NextBlast = now + math.clamp(
                                tonumber(PlayerTrollSettings.BlastCooldown) or 1,
                                0.15,
                                10
                        )

                        if fired > 0 then
                                updatePlayerTrollStatus(
                                        "Blasted " .. tostring(fired) .. " parts at "
                                                .. victim.player.DisplayName
                                )
                        end
                end

                if meteorDue then
                        local flightTime = math.clamp(
                                tonumber(PlayerTrollSettings.MeteorFlightTime) or 1.5,
                                0.4,
                                3
                        )
                        local fired = fireTrollVolley(
                                victim,
                                nil,
                                flightTime,
                                Vector3.new(0, 3, 0),
                                now
                        )

                        PlayerTrollSettings.NextMeteor = now + math.clamp(
                                tonumber(PlayerTrollSettings.MeteorInterval) or 1.5,
                                0.3,
                                10
                        )

                        if fired > 0 then
                                updatePlayerTrollStatus(
                                        "Rained " .. tostring(fired) .. " meteors on "
                                                .. victim.player.DisplayName
                                )
                        end
                end

                if not swarmEnabled and not cageEnabled then
                        composePlayerTrollStatus(victim)
                        return
                end

                local victimRoot = victim.root
                local victimPosition = victimRoot.Position

                if victimPosition.X ~= victimPosition.X
                        or victimPosition.Y ~= victimPosition.Y
                        or victimPosition.Z ~= victimPosition.Z then
                        return
                end

                local carry = victimRoot.AssemblyLinearVelocity * 0.5

                if carry.X ~= carry.X
                        or carry.Y ~= carry.Y
                        or carry.Z ~= carry.Z then
                        carry = Vector3.zero
                elseif carry.Magnitude > 250 then
                        carry = carry.Unit * 250
                end

                local swarmRadius = math.clamp(
                        tonumber(PlayerTrollSettings.SwarmRadius) or 5,
                        1.5,
                        15
                )
                local swarmSpeed = math.clamp(
                        tonumber(PlayerTrollSettings.SwarmSpeed) or 14,
                        0,
                        40
                )
                local cageSize = math.clamp(
                        tonumber(PlayerTrollSettings.CageSize) or 7,
                        3,
                        25
                )
                local gravityFeedForward = 0.5 * Workspace.Gravity * stepTime
                local movingCount = 0

                for index, part in ipairs(PlayerTrollSettings.Parts) do
                        local state = PlayerTrollSettings.States[part]

                        if state
                                and part.Parent
                                and now >= (state.InFlightUntil or 0) then
                                local position = part.Position

                                if position.X == position.X
                                        and position.Y == position.Y
                                        and position.Z == position.Z then
                                        local linearVelocity = nil

                                        if swarmEnabled then
                                                -- Tight personal orbits with
                                                -- collisions ON: a swirling
                                                -- cloud that body-blocks and
                                                -- shoves the victim while
                                                -- tracking them exactly.
                                                if state.Angle == nil then
                                                        state.Angle = math.atan2(
                                                                position.Z - victimPosition.Z,
                                                                position.X - victimPosition.X
                                                        ) % TAU
                                                end

                                                local angularSpeed = swarmSpeed
                                                        * state.SpeedScale
                                                        * state.Direction
                                                local angle = state.Angle
                                                local nextAngle = angle + angularSpeed * stepTime

                                                state.Angle = nextAngle % TAU

                                                local orbitRadius = math.max(
                                                        1.5,
                                                        swarmRadius * state.RadiusScale
                                                )
                                                local targetNow = victimPosition + Vector3.new(
                                                        math.cos(angle) * orbitRadius,
                                                        state.HeightOffset,
                                                        math.sin(angle) * orbitRadius
                                                )
                                                local targetNext = victimPosition + Vector3.new(
                                                        math.cos(nextAngle) * orbitRadius,
                                                        state.HeightOffset,
                                                        math.sin(nextAngle) * orbitRadius
                                                )
                                                local tangentSpeed = orbitRadius * angularSpeed
                                                local tangentVelocity = Vector3.new(
                                                        -math.sin(angle) * tangentSpeed,
                                                        0,
                                                        math.cos(angle) * tangentSpeed
                                                )
                                                local residual = targetNext - position
                                                        - tangentVelocity * stepTime

                                                linearVelocity = tangentVelocity
                                                        + residual / stepTime
                                                        + Vector3.new(0, gravityFeedForward, 0)
                                                        + carry
                                        elseif cageEnabled then
                                                -- Five real walls (four sides
                                                -- plus a lid) of collidable
                                                -- parts that follow the
                                                -- victim: a prison they have
                                                -- to punch their way out of.
                                                local offset = CAGE_OFFSETS[
                                                        ((index - 1) % #CAGE_OFFSETS) + 1
                                                ] * cageSize
                                                local target = victimPosition + offset
                                                local residual = target - position

                                                linearVelocity = residual / stepTime
                                                        + Vector3.new(0, gravityFeedForward, 0)
                                                        + carry
                                        end

                                        if linearVelocity then
                                                if state.PrevPos then
                                                        local moved = (position - state.PrevPos).Magnitude

                                                        if moved ~= moved then
                                                                moved = 0
                                                        end

                                                        if moved > 0.05 then
                                                                movingCount = movingCount + 1
                                                        end
                                                end

                                                pcall(function()
                                                        part.AssemblyLinearVelocity = linearVelocity
                                                        part.AssemblyAngularVelocity = state.SpinAxis * 20
                                                end)
                                        end

                                        state.PrevPos = position
                                end
                        end
                end

                PlayerTrollSettings.MovingCount = movingCount
                composePlayerTrollStatus(victim)
        end

        local function stopPlayerTroll()
                disconnect(PlayerTrollSettings.Connection)
                PlayerTrollSettings.Connection = nil

                for _, part in ipairs(PlayerTrollSettings.Parts) do
                        releaseTrollPart(part)
                end

                PlayerTrollSettings.Parts = {}
                PlayerTrollSettings.NextRescan = 0
                PlayerTrollSettings.NextBlast = 0
                PlayerTrollSettings.NextMeteor = 0
                PlayerTrollSettings.MovingCount = 0
                updatePlayerTrollStatus("Player Troll off")
        end

        PlayerTroll.syncConnection = function()
                if isPlayerTrollActive() then
                        if not PlayerTrollSettings.Connection then
                                PlayerTrollSettings.NextRescan = 0

                                PlayerTrollSettings.Connection = RunService.Heartbeat:Connect(
                                        function(stepTime)
                                                local ok, err = pcall(updatePlayerTroll, stepTime)

                                                if ok then
                                                        PlayerTrollSettings.ErrorCount = 0
                                                        return
                                                end

                                                PlayerTrollSettings.ErrorCount = PlayerTrollSettings.ErrorCount + 1

                                                if PlayerTrollSettings.ErrorCount == 5 then
                                                        updatePlayerTrollStatus(
                                                                "Engine error: "
                                                                        .. tostring(err):sub(1, 80)
                                                        )
                                                end
                                        end
                                )
                        end
                else
                        stopPlayerTroll()
                end
        end

        PlayerTroll.refresh = function()
                local myRoot = getTrollMyRoot()

                if myRoot then
                        refreshPlayerTroll(myRoot)
                end
        end
end


local function isAimTeammate(player)
        return AimlockSettings.TeamCheck
                and LocalPlayer.Team ~= nil
                and player.Team == LocalPlayer.Team
end

local function updateAimStatus()
        if not aimStatusLabel then
                return
        end

        if AimlockSettings.TargetPlayer then
                aimStatusLabel:Set("Target: " .. AimlockSettings.TargetPlayer.DisplayName)
        else
                aimStatusLabel:Set("Target: None")
        end
end

local function clearAimTarget()
        AimlockSettings.TargetPlayer = nil
        AimlockSettings.TargetCharacter = nil
        AimlockSettings.TargetHumanoid = nil
        AimlockSettings.TargetPart = nil
        updateAimStatus()
end

local function getAimCursorDistance(camera, screenPosition, character)
        local closestDistance = nil
        local candidateNames = {
                "Head",
                "UpperTorso",
                "Torso",
                "HumanoidRootPart",
                "LowerTorso"
        }

        for _, name in ipairs(candidateNames) do
                local part = character:FindFirstChild(name)

                if part and part:IsA("BasePart") then
                        local projected, onScreen = camera:WorldToScreenPoint(part.Position)

                        if onScreen and projected.Z > 0 then
                                local distance = (
                                        Vector2.new(projected.X, projected.Y)
                                        - screenPosition
                                ).Magnitude

                                if not closestDistance or distance < closestDistance then
                                        closestDistance = distance
                                end
                        end
                end
        end

        return closestDistance
end

local function getPlayerUnderPointer()
        local camera = Workspace.CurrentCamera
        local localRoot = getRoot(LocalPlayer.Character)

        if not camera then
                return nil
        end

        local mouseLocation = UserInputService:GetMouseLocation()
        local screenPosition = Vector2.new(mouseLocation.X, mouseLocation.Y)
        local closestPlayer = nil
        local closestCharacter = nil
        local closestHumanoid = nil
        local closestTargetPart = nil
        local closestDistance = AimlockSettings.CursorRadius

        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and not isAimTeammate(player) then
                        local character = player.Character
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        local targetPart = character and (
                                character:FindFirstChild("Head")
                                or getRoot(character)
                        )
                        local root = character and getRoot(character)

                        if humanoid
                                and humanoid.Health > 0
                                and targetPart
                                and targetPart:IsA("BasePart")
                                and root
                                and root:IsA("BasePart") then
                                local worldDistance = localRoot
                                        and (root.Position - localRoot.Position).Magnitude
                                        or (root.Position - camera.CFrame.Position).Magnitude

                                if worldDistance <= AimlockSettings.MaxDistance then
                                        local cursorDistance = getAimCursorDistance(
                                                camera,
                                                screenPosition,
                                                character
                                        )

                                        if cursorDistance and cursorDistance <= closestDistance then
                                                closestPlayer = player
                                                closestCharacter = character
                                                closestHumanoid = humanoid
                                                closestTargetPart = targetPart
                                                closestDistance = cursorDistance
                                        end
                                end
                        end
                end
        end

        return closestPlayer, closestCharacter, closestHumanoid, closestTargetPart
end

local function beginAimlock()
        if not running
                or not AimlockSettings.Enabled
                or AimlockSettings.Holding then
                return
        end

        AimlockSettings.Holding = true
        clearAimTarget()

        local player, character, humanoid, targetPart = getPlayerUnderPointer()

        if player then
                AimlockSettings.TargetPlayer = player
                AimlockSettings.TargetCharacter = character
                AimlockSettings.TargetHumanoid = humanoid
                AimlockSettings.TargetPart = targetPart
                updateAimStatus()
        end
end

local function endAimlock()
        AimlockSettings.Holding = false
        clearAimTarget()
end

local function setAimlockEnabled(value)
        AimlockSettings.Enabled = value and true or false

        if not AimlockSettings.Enabled then
                endAimlock()
        else
                updateAimStatus()
        end
end

local function updateAimlockCamera()
        if not running
                or not AimlockSettings.Enabled
                or not AimlockSettings.Holding
                or not AimlockSettings.TargetPlayer then
                return
        end

        local player = AimlockSettings.TargetPlayer
        local character = AimlockSettings.TargetCharacter
        local humanoid = AimlockSettings.TargetHumanoid
        local targetPart = AimlockSettings.TargetPart

        if player.Parent ~= Players
                or not character
                or not character.Parent
                or not humanoid
                or not humanoid.Parent
                or humanoid.Health <= 0
                or not targetPart
                or not targetPart.Parent then
                clearAimTarget()
                return
        end

        local camera = Workspace.CurrentCamera
        if camera then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
        end
end

local function removeESP(character)
        if not character then
                return
        end

        local highlight = character:FindFirstChild(HIGHLIGHT_NAME)
        if highlight then
                highlight:Destroy()
        end

        local tag = character:FindFirstChild(TAG_NAME)
        if tag then
                tag:Destroy()
        end
end

local function isTeammate(player)
        return Settings.TeamCheck
                and LocalPlayer.Team ~= nil
                and player.Team == LocalPlayer.Team
end

local function ensureESP(character, root)
        local highlight = character:FindFirstChild(HIGHLIGHT_NAME)

        if highlight and not highlight:IsA("Highlight") then
                highlight:Destroy()
                highlight = nil
        end

        if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = HIGHLIGHT_NAME
                highlight.Parent = character
        end

        local tag = character:FindFirstChild(TAG_NAME)

        if tag and not tag:IsA("BillboardGui") then
                tag:Destroy()
                tag = nil
        end

        if not tag then
                tag = Instance.new("BillboardGui")
                tag.Name = TAG_NAME
                tag.Size = UDim2.fromOffset(220, 64)
                tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
                tag.LightInfluence = 0
                tag.Parent = character
        end

        local label = tag:FindFirstChild(TEXT_NAME)

        if label and not label:IsA("TextLabel") then
                label:Destroy()
                label = nil
        end

        if not label then
                label = Instance.new("TextLabel")
                label.Name = TEXT_NAME
                label.BackgroundTransparency = 1
                label.Size = UDim2.fromScale(1, 1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.TextWrapped = true
                label.TextXAlignment = Enum.TextXAlignment.Center
                label.TextYAlignment = Enum.TextYAlignment.Center
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.TextStrokeTransparency = 0.25
                label.Parent = tag
        end

        highlight.Adornee = character
        tag.Adornee = root

        return highlight, tag, label
end

local function updatePlayer(player)
        if player == LocalPlayer then
                return
        end

        local character = player.Character

        if not Settings.Enabled or not character or isTeammate(player) then
                removeESP(character)
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = getRoot(character)
        local localRoot = getRoot(LocalPlayer.Character)

        if not humanoid or humanoid.Health <= 0 or not root or not localRoot then
                removeESP(character)
                return
        end

        local distance = (root.Position - localRoot.Position).Magnitude

        if distance > Settings.MaxDistance then
                removeESP(character)
                return
        end

        local showLabels = Settings.ShowName or Settings.ShowHealth or Settings.ShowDistance

        if not Settings.Highlight and not showLabels then
                removeESP(character)
                return
        end

        local highlight, tag, label = ensureESP(character, root)

        highlight.Enabled = Settings.Highlight
        highlight.FillColor = Settings.Color
        highlight.OutlineColor = Settings.Color
        highlight.FillTransparency = Settings.FillTransparency
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Settings.ThroughWalls
                and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded

        tag.Enabled = showLabels
        tag.AlwaysOnTop = Settings.ThroughWalls
        label.TextColor3 = Settings.Color

        local lines = {}

        if Settings.ShowName then
                table.insert(lines, player.DisplayName ~= "" and player.DisplayName or player.Name)
        end

        if Settings.ShowHealth then
                table.insert(lines, string.format(
                        "%d / %d HP",
                        math.floor(humanoid.Health + 0.5),
                        math.floor(humanoid.MaxHealth + 0.5)
                ))
        end

        if Settings.ShowDistance then
                table.insert(lines, string.format("%d studs", math.floor(distance + 0.5)))
        end

        label.Text = table.concat(lines, "\n")
end

local function refreshAll()
        for _, player in ipairs(Players:GetPlayers()) do
                updatePlayer(player)
        end
end

local function clearSpeedWatcher()
        disconnect(MovementSettings.WatchConnection)
        MovementSettings.WatchConnection = nil
end

local function applySpeed()
        local humanoid = MovementSettings.Humanoid

        if not running
                or not MovementSettings.Enabled
                or not humanoid
                or not humanoid.Parent then
                return
        end

        if humanoid.WalkSpeed == MovementSettings.Speed then
                return
        end

        MovementSettings.Updating = true
        humanoid.WalkSpeed = MovementSettings.Speed
        MovementSettings.Updating = false
end

local function watchSpeed()
        clearSpeedWatcher()

        local humanoid = MovementSettings.Humanoid
        if not humanoid or not humanoid.Parent then
                return
        end

        MovementSettings.WatchConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if running
                        and MovementSettings.Enabled
                        and not MovementSettings.Updating
                        and humanoid.WalkSpeed ~= MovementSettings.Speed then
                        task.defer(applySpeed)
                end
        end)
end

local function applyNoclip()
        if not running or not MovementSettings.Noclip then
                return
        end

        local character = LocalPlayer.Character

        if not character or not character.Parent then
                return
        end

        for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("BasePart") then
                        if MovementSettings.CollisionStates[object] == nil then
                                MovementSettings.CollisionStates[object] = object.CanCollide
                        end

                        if object.CanCollide then
                                object.CanCollide = false
                        end
                end
        end
end

local function clearNoclip()
        disconnect(MovementSettings.NoclipConnection)
        MovementSettings.NoclipConnection = nil

        for part, originalCanCollide in pairs(MovementSettings.CollisionStates) do
                if part and part.Parent then
                        pcall(function()
                                part.CanCollide = originalCanCollide
                        end)
                end
        end

        MovementSettings.CollisionStates = setmetatable({}, {__mode = "k"})
end

local function setNoclipEnabled(value)
        MovementSettings.Noclip = value and true or false

        clearNoclip()

        if not MovementSettings.Noclip then
                return
        end

        applyNoclip()

        MovementSettings.NoclipConnection = RunService.Stepped:Connect(function()
                applyNoclip()
        end)
end

local function clearPlatform()
        disconnect(PlatformSettings.Connection)
        PlatformSettings.Connection = nil

        local platform = PlatformSettings.Part
        PlatformSettings.Part = nil
        PlatformSettings.UpHeld = false
        PlatformSettings.DownHeld = false
        PlatformSettings.ForwardHeld = false

        if platform and platform.Parent then
                pcall(function()
                        platform:Destroy()
                end)
        end
end

local function getPlatformCharacterData()
        local character = LocalPlayer.Character

        if not character or not character.Parent then
                return nil, nil, nil
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = getRoot(character)

        if not humanoid
                or not humanoid.Parent
                or not root
                or not root.Parent then
                return nil, nil, nil
        end

        return character, humanoid, root
end

local function getPlatformStartCFrame()
        local _, humanoid, root = getPlatformCharacterData()

        if not humanoid or not root then
                return nil
        end

        local platformHalfHeight = PlatformSettings.Size.Y * 0.5
        local offset = humanoid.HipHeight + root.Size.Y * 0.5 + platformHalfHeight

        return CFrame.new(root.Position - Vector3.new(0, offset, 0))
end

local function shouldCarryCharacter(platform, root, humanoid)
        if not platform
                or not platform.Parent
                or not root
                or not root.Parent
                or not humanoid
                or not humanoid.Parent then
                return false
        end

        local point = platform.CFrame:PointToObjectSpace(root.Position)
        local expectedY = humanoid.HipHeight
                + root.Size.Y * 0.5
                + platform.Size.Y * 0.5

        return math.abs(point.X) <= platform.Size.X * 0.5 + 1
                and math.abs(point.Z) <= platform.Size.Z * 0.5 + 1
                and math.abs(point.Y - expectedY) <= 6
end

local function movePlatformBy(offset)
        local platform = PlatformSettings.Part

        if not platform or not platform.Parent then
                return
        end

        local nextCFrame = platform.CFrame + offset
        platform.CFrame = nextCFrame

        local _, humanoid, root = getPlatformCharacterData()

        if shouldCarryCharacter(platform, root, humanoid) then
                root.CFrame = root.CFrame + offset
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
end

local function getPlatformMoveDirection()
        local direction = Vector3.new(0, 0, 0)

        if PlatformSettings.UpHeld then
                direction += Vector3.new(0, 1, 0)
        end

        if PlatformSettings.DownHeld then
                direction -= Vector3.new(0, 1, 0)
        end

        if PlatformSettings.ForwardHeld then
                local camera = Workspace.CurrentCamera
                local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
                local forward = Vector3.new(look.X, 0, look.Z)

                if forward.Magnitude > 0.001 then
                        direction += forward.Unit
                end
        end

        return direction
end

local function updatePlatform(deltaTime)
        if not running
                or not PlatformSettings.Enabled
                or not PlatformSettings.Part
                or not PlatformSettings.Part.Parent then
                return
        end

        local duration = math.max(tonumber(deltaTime) or 0, 0)

        if duration <= 0 then
                return
        end

        local direction = getPlatformMoveDirection()

        if direction.Magnitude > 0.001 then
                movePlatformBy(direction.Unit * PlatformSettings.MoveSpeed * duration)
        end

        local platform = PlatformSettings.Part
        local _, humanoid, root = getPlatformCharacterData()

        if not platform
                or not platform.Parent
                or not humanoid
                or not root then
                return
        end

        local footOffset = humanoid.HipHeight
                + root.Size.Y * 0.5
                + platform.Size.Y * 0.5
        local targetPosition = root.Position - Vector3.new(0, footOffset, 0)
        local currentPosition = platform.Position
        local horizontalDelta = Vector3.new(
                targetPosition.X - currentPosition.X,
                0,
                targetPosition.Z - currentPosition.Z
        )
        local horizontalDistance = horizontalDelta.Magnitude
        local verticalDelta = targetPosition.Y - currentPosition.Y

        if horizontalDistance > PlatformSettings.TrackSnapDistance
                or math.abs(verticalDelta) > PlatformSettings.TrackSnapDistance then
                platform.CFrame = CFrame.new(targetPosition)
                return
        end

        local horizontalOffset = Vector3.new(0, 0, 0)

        if horizontalDistance > 0.001 then
                local horizontalStep = math.min(
                        horizontalDistance,
                        PlatformSettings.TrackHorizontalSpeed * duration
                )
                horizontalOffset = horizontalDelta.Unit * horizontalStep
        end

        local downwardVelocity = math.max(-root.AssemblyLinearVelocity.Y, 0)
        local verticalSpeed = PlatformSettings.TrackUpSpeed

        if verticalDelta < 0 then
                verticalSpeed = PlatformSettings.TrackDownSpeed + downwardVelocity * 5

                if root.Position.Y < currentPosition.Y - 3 then
                        verticalSpeed = math.max(
                                verticalSpeed,
                                PlatformSettings.TrackSwoopSpeed + downwardVelocity * 6
                        )
                end
        end

        local verticalOffset = math.clamp(
                verticalDelta,
                -verticalSpeed * duration,
                verticalSpeed * duration
        )

        if horizontalOffset.Magnitude > 0.001
                or math.abs(verticalOffset) > 0.001 then
                platform.CFrame = platform.CFrame + horizontalOffset
                        + Vector3.new(0, verticalOffset, 0)
        end
end

local function startPlatformForCharacter()
        clearPlatform()

        if not running or not PlatformSettings.Enabled then
                return
        end

        local cframe = getPlatformStartCFrame()

        if not cframe then
                return
        end

        local platform = Instance.new("Part")
        platform.Name = "__PlayerToolsPlatform"
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = true
        platform.CanQuery = false
        platform.Size = PlatformSettings.Size
        platform.CFrame = cframe
        platform.Material = Enum.Material.Plastic
        platform.Color = Color3.fromRGB(90, 130, 205)
        platform.TopSurface = Enum.SurfaceType.Studs
        platform.Parent = Workspace

        PlatformSettings.Part = platform
        PlatformSettings.Connection = RunService.Heartbeat:Connect(function(deltaTime)
                local ok = pcall(updatePlatform, deltaTime)

                if not ok then
                        clearPlatform()
                end
        end)
end

local function setPlatformEnabled(value)
        PlatformSettings.Enabled = value and true or false

        if not PlatformSettings.Enabled then
                clearPlatform()
                return
        end

        startPlatformForCharacter()
end

local function clearVehicleSeatedConnection()
        disconnect(VehicleSettings.SeatedConnection)
        VehicleSettings.SeatedConnection = nil
end

local function clearVehicleSpeedWatch()
        disconnect(VehicleSettings.SpeedWatchConnection)
        VehicleSettings.SpeedWatchConnection = nil
end

local function clearVehicleBoost()
        disconnect(VehicleSettings.BoostConnection)
        VehicleSettings.BoostConnection = nil
end

local function findVehicleModel(seat)
        local current = seat and seat.Parent

        while current and current ~= Workspace do
                if current:IsA("Model") then
                        return current
                end

                current = current.Parent
        end

        return nil
end

local function getVehicleRoot(seat, model)
        if seat and seat:IsA("BasePart") then
                local assemblyRoot = seat.AssemblyRootPart

                if assemblyRoot and assemblyRoot:IsA("BasePart") then
                        return assemblyRoot
                end
        end

        if model and model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
                return model.PrimaryPart
        end

        if model then
                for _, object in ipairs(model:GetDescendants()) do
                        if object:IsA("BasePart") then
                                local assemblyRoot = object.AssemblyRootPart

                                if assemblyRoot and assemblyRoot:IsA("BasePart") then
                                        return assemblyRoot
                                end

                                return object
                        end
                end
        end

        return seat
end

local function isVehicleSeatPart(seat)
        return seat
                and seat:IsA("BasePart")
                and (seat:IsA("Seat") or seat:IsA("VehicleSeat"))
end

local function clearVehicleJumpStabilizer()
        VehicleJumpSettings.StabilizerToken += 1

        if VehicleJumpSettings.Stabilizer then
                pcall(function()
                        VehicleJumpSettings.Stabilizer:Destroy()
                end)
        end

        VehicleJumpSettings.Stabilizer = nil
end

local function clearVehicleFlipAssist()
        if VehicleSettings.FlipGyro then
                pcall(function()
                        VehicleSettings.FlipGyro:Destroy()
                end)
        end

        VehicleSettings.FlipGyro = nil
        VehicleSettings.FlipRoot = nil
end

local function getVehicleUprightCFrame(root, seat)
        local heading = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)

        if heading.Magnitude < 0.001 then
                heading = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        end

        if heading.Magnitude < 0.001 then
                heading = Vector3.zAxis
        else
                heading = heading.Unit
        end

        return CFrame.lookAt(root.Position, root.Position + heading, Vector3.yAxis)
end

local function clearVehicleTeleportReinforcement()
        VehicleTeleportSettings.ReinforceToken += 1
        disconnect(VehicleTeleportSettings.ReinforceConnection)
        VehicleTeleportSettings.ReinforceConnection = nil
        VehicleTeleportSettings.ReinforceRoot = nil
        VehicleTeleportSettings.ReinforceSeat = nil
        VehicleTeleportSettings.ReinforceParts = nil
        VehicleTeleportSettings.ReinforceOffsets = nil
end

local function restoreVehicleSpeed()
        clearVehicleSpeedWatch()
        clearVehicleBoost()
        clearVehicleJumpStabilizer()
        clearVehicleFlipAssist()
        clearVehicleTeleportReinforcement()

        if stopVehicleFlyRuntime then
                stopVehicleFlyRuntime()
        end

        local seat = VehicleSettings.CurrentSeat

        if seat
                and seat.Parent
                and seat:IsA("VehicleSeat") then
                pcall(function()
                        if VehicleSettings.OriginalMaxSpeed[seat] ~= nil then
                                seat.MaxSpeed = VehicleSettings.OriginalMaxSpeed[seat]
                        end

                        if VehicleSettings.OriginalTurnSpeed[seat] ~= nil then
                                seat.TurnSpeed = VehicleSettings.OriginalTurnSpeed[seat]
                        end
                end)
        end

        VehicleSettings.CurrentSeat = nil
        VehicleSettings.CurrentModel = nil
        VehicleSettings.CurrentRoot = nil
        VehicleSettings.Updating = false
end

local function applyVehicleSeatSpeed()
        local seat = VehicleSettings.CurrentSeat

        if not running
                or not seat
                or not seat.Parent
                or not seat:IsA("VehicleSeat") then
                return
        end

        local speed = math.clamp(tonumber(VehicleSettings.Speed) or 60, 0, 500)

        pcall(function()
                if VehicleSettings.OriginalMaxSpeed[seat] == nil then
                        VehicleSettings.OriginalMaxSpeed[seat] = seat.MaxSpeed
                end

                if seat.MaxSpeed ~= speed then
                        VehicleSettings.Updating = true
                        seat.MaxSpeed = speed
                        VehicleSettings.Updating = false
                end
        end)
end

local function applyVehicleSeatSteering()
        local seat = VehicleSettings.CurrentSeat

        if not running
                or not seat
                or not seat.Parent
                or not seat:IsA("VehicleSeat") then
                return
        end

        local strength = math.clamp(tonumber(VehicleSettings.SteeringStrength) or 8, 0, 50)

        pcall(function()
                if VehicleSettings.OriginalTurnSpeed[seat] == nil then
                        VehicleSettings.OriginalTurnSpeed[seat] = seat.TurnSpeed
                end

                if seat.TurnSpeed ~= strength then
                        VehicleSettings.Updating = true
                        seat.TurnSpeed = strength
                        VehicleSettings.Updating = false
                end
        end)
end

local function getVehicleSteer(seat)
        if seat and seat:IsA("VehicleSeat") then
                local steer = 0

                pcall(function()
                        steer = tonumber(seat.SteerFloat) or 0
                end)

                if math.abs(steer) > 0.01 then
                        return math.clamp(steer, -1, 1)
                end

                pcall(function()
                        steer = tonumber(seat.Steer) or 0
                end)

                if math.abs(steer) > 0.01 then
                        return math.clamp(steer, -1, 1)
                end
        end

        local steer = 0

        if UserInputService:IsKeyDown(Enum.KeyCode.D)
                or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
                steer += 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.A)
                or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
                steer -= 1
        end

        return math.clamp(steer, -1, 1)
end

local function stabilizeVehicle(root, seat, deltaTime)
        if VehicleFlySettings.Enabled then
                clearVehicleFlipAssist()
                return
        end

        local upVector = root.CFrame.UpVector
        local needsCorrection = upVector.Y < 0.35
        local gyro = VehicleSettings.FlipGyro

        if not needsCorrection and gyro and upVector.Y >= 0.88 then
                clearVehicleFlipAssist()
                return
        end

        if not needsCorrection and not gyro then
                return
        end

        if not gyro
                or not gyro.Parent
                or VehicleSettings.FlipRoot ~= root then
                clearVehicleFlipAssist()

                gyro = Instance.new("BodyGyro")
                gyro.Name = "__PlayerToolsVehicleFlipStabilizer"
                gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
                gyro.P = 50000
                gyro.D = 2200
                gyro.Parent = root

                VehicleSettings.FlipGyro = gyro
                VehicleSettings.FlipRoot = root
        end

        gyro.CFrame = getVehicleUprightCFrame(root, seat)

        local angularVelocity = root.AssemblyAngularVelocity
        root.AssemblyAngularVelocity = Vector3.new(
                angularVelocity.X * 0.2,
                angularVelocity.Y * 0.8,
                angularVelocity.Z * 0.2
        )
end

local function getVehicleThrottle(seat)
        if seat and seat:IsA("VehicleSeat") then
                local throttle = 0

                pcall(function()
                        throttle = tonumber(seat.ThrottleFloat) or 0
                end)

                if math.abs(throttle) > 0.01 then
                        return math.clamp(throttle, -1, 1)
                end

                pcall(function()
                        throttle = tonumber(seat.Throttle) or 0
                end)

                if math.abs(throttle) > 0.01 then
                        return math.clamp(throttle, -1, 1)
                end
        end

        local throttle = 0

        if UserInputService:IsKeyDown(Enum.KeyCode.W)
                or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
                throttle += 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.S)
                or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
                throttle -= 1
        end

        return math.clamp(throttle, -1, 1)
end

local function isVehicleSpeedBoostActive()
        return os.clock() < VehicleSpeedBoostSettings.ActiveUntil
end

local function updateVehicleBoost(deltaTime)
        if not running then
                return
        end

        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        if not seat
                or not seat.Parent
                or not root
                or not root.Parent
                or not humanoid
                or not humanoid.Parent
                or not isVehicleSeatPart(seat)
                or seat.Occupant ~= humanoid then
                clearVehicleFlipAssist()
                return
        end

        local delta = math.max(tonumber(deltaTime) or 0, 0)

        if not VehicleFlySettings.Enabled then
                applyVehicleSeatSpeed()
                applyVehicleSeatSteering()

                local forward = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)

                if forward.Magnitude > 0.001 then
                        forward = forward.Unit

                        local throttle = getVehicleThrottle(seat)
                        local speed = math.clamp(tonumber(VehicleSettings.Speed) or 60, 0, 500)
                        local velocity = root.AssemblyLinearVelocity
                        local forwardSpeed = velocity:Dot(forward)
                        local targetSpeed = throttle * speed

                        if isVehicleSpeedBoostActive() then
                                targetSpeed = math.max(
                                        targetSpeed,
                                        math.clamp(tonumber(VehicleSpeedBoostSettings.Power) or 160, 20, 600)
                                )
                        end

                        local alpha = 1 - math.exp(-18 * delta)
                        local nextForwardSpeed = forwardSpeed + (targetSpeed - forwardSpeed) * alpha
                        local lateralVelocity = velocity - forward * forwardSpeed

                        root.AssemblyLinearVelocity = lateralVelocity + forward * nextForwardSpeed

                        local steer = getVehicleSteer(seat)
                        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                        local movementFactor = math.clamp(horizontalSpeed / math.max(speed, 1), 0, 1)
                        local targetYaw = -steer
                                * math.clamp(tonumber(VehicleSettings.SteeringStrength) or 8, 0, 50)
                                * movementFactor
                        local angularVelocity = root.AssemblyAngularVelocity
                        local steeringAlpha = 1 - math.exp(-14 * delta)

                        root.AssemblyAngularVelocity = Vector3.new(
                                angularVelocity.X,
                                angularVelocity.Y + (targetYaw - angularVelocity.Y) * steeringAlpha,
                                angularVelocity.Z
                        )
                end
        end

        local jumpStabilizer = VehicleJumpSettings.Stabilizer

        if jumpStabilizer and jumpStabilizer.Parent then
                jumpStabilizer.CFrame = getVehicleUprightCFrame(root, seat)
        end

        stabilizeVehicle(root, seat, delta)
end

local function canVehicleJump()
        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        return running
                and seat
                and seat.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
                and isVehicleSeatPart(seat)
                and seat.Occupant == humanoid
end

local function jumpVehicle()
        if not canVehicleJump() then
                return
        end

        local now = os.clock()

        if now - VehicleJumpSettings.LastJump < VehicleJumpSettings.Cooldown then
                return
        end

        VehicleJumpSettings.LastJump = now

        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local power = math.clamp(tonumber(VehicleJumpSettings.Power) or 90, 20, 250)
        local velocity = root.AssemblyLinearVelocity
        local forward = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)

        if forward.Magnitude > 0.001 then
                forward = forward.Unit
        else
                forward = Vector3.zero
        end

        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local forwardKick = math.clamp(horizontalSpeed * 0.12, power * 0.08, power * 0.28)
        local upwardSpeed = math.max(velocity.Y, power)

        root.AssemblyLinearVelocity = Vector3.new(
                velocity.X,
                upwardSpeed,
                velocity.Z
        ) + forward * forwardKick

        local angularVelocity = root.AssemblyAngularVelocity
        root.AssemblyAngularVelocity = Vector3.new(
                0,
                angularVelocity.Y * 0.55,
                0
        )

        if not VehicleFlySettings.Enabled then
                clearVehicleJumpStabilizer()

                local heading = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)

                if heading.Magnitude < 0.001 then
                        heading = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
                end

                if heading.Magnitude > 0.001 then
                        heading = heading.Unit

                        local stabilizer = Instance.new("BodyGyro")
                        stabilizer.Name = "__PlayerToolsVehicleJumpStabilizer"
                        stabilizer.MaxTorque = Vector3.new(1e8, 0, 1e8)
                        stabilizer.P = 30000
                        stabilizer.D = 1600
                        stabilizer.CFrame = CFrame.lookAt(
                                root.Position,
                                root.Position + heading,
                                Vector3.yAxis
                        )
                        stabilizer.Parent = root

                        VehicleJumpSettings.Stabilizer = stabilizer
                        local token = VehicleJumpSettings.StabilizerToken
                        local holdTime = 0.45 + math.clamp(power / 250, 0, 1) * 0.55

                        task.delay(holdTime, function()
                                if VehicleJumpSettings.StabilizerToken == token
                                        and VehicleJumpSettings.Stabilizer == stabilizer then
                                        VehicleJumpSettings.Stabilizer = nil
                                        pcall(function()
                                                stabilizer:Destroy()
                                        end)
                                end
                        end)
                end
        end
end

local function canClickTeleport()
        local character = LocalPlayer.Character
        local root = getRoot(character)
        local humanoid = MovementSettings.Humanoid

        return running
                and ClickTeleportSettings.Enabled
                and character
                and character.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
end

local function getClickTeleportTarget(screenPosition)
        local camera = Workspace.CurrentCamera
        local character = LocalPlayer.Character

        if not camera then
                return nil
        end

        local position = screenPosition or UserInputService:GetMouseLocation()
        local ray = camera:ScreenPointToRay(position.X, position.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = character and {character} or {}
        params.IgnoreWater = false

        local result = Workspace:Raycast(ray.Origin, ray.Direction * 10000, params)

        if not result then
                return nil
        end

        return result.Position
end

local function teleportCharacterToMouse(screenPosition)
        if not canClickTeleport() then
                return
        end

        local now = os.clock()

        if now - ClickTeleportSettings.LastTeleport < ClickTeleportSettings.Cooldown then
                return
        end

        local destination = getClickTeleportTarget(screenPosition)

        if not destination then
                return
        end

        local root = getRoot(LocalPlayer.Character)

        if not root or not root.Parent then
                return
        end

        local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

        if look.Magnitude < 0.001 then
                look = Vector3.zAxis
        else
                look = look.Unit
        end

        local lift = math.max(root.Size.Y * 0.5 + 2, 3)
        local position = destination + Vector3.yAxis * lift

        root.CFrame = CFrame.lookAt(position, position + look)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        ClickTeleportSettings.LastTeleport = now
end

local function canVehicleSpeedBoost()
        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        return running
                and seat
                and seat.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
                and not VehicleFlySettings.Enabled
                and not VehicleFlingSettings.Enabled
                and not VehicleTeleportSettings.ReinforceConnection
                and isVehicleSeatPart(seat)
                and seat.Occupant == humanoid
end

local function boostVehicleSpeed()
        if not canVehicleSpeedBoost() then
                return
        end

        local now = os.clock()

        if now - VehicleSpeedBoostSettings.LastBoost < VehicleSpeedBoostSettings.Cooldown then
                return
        end

        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local forward = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)

        if forward.Magnitude < 0.001 then
                return
        end

        forward = forward.Unit

        local power = math.clamp(tonumber(VehicleSpeedBoostSettings.Power) or 160, 20, 600)
        local velocity = root.AssemblyLinearVelocity
        local forwardSpeed = velocity:Dot(forward)
        local lateralVelocity = velocity - forward * forwardSpeed
        local targetSpeed = math.max(forwardSpeed, power)

        root.AssemblyLinearVelocity = lateralVelocity + forward * targetSpeed
        VehicleSpeedBoostSettings.LastBoost = now
        VehicleSpeedBoostSettings.ActiveUntil = now + VehicleSpeedBoostSettings.Duration
end

local function canVehicleFling()
        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        return running
                and VehicleFlingSettings.Enabled
                and seat
                and seat.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
                and isVehicleSeatPart(seat)
                and seat.Occupant == humanoid
end

local function setVehicleFlingEnabled(value)
        local enabled = value and true or false

        if VehicleFlingSettings.Enabled == enabled then
                return
        end

        VehicleFlingSettings.Enabled = enabled
        VehicleFlingSettings.WorkerToken += 1

        if not enabled then
                return
        end

        local workerToken = VehicleFlingSettings.WorkerToken

        task.spawn(function()
                local verticalJitter = 0.1

                while running
                        and VehicleFlingSettings.Enabled
                        and workerToken == VehicleFlingSettings.WorkerToken do
                        RunService.Heartbeat:Wait()

                        if not running
                                or not VehicleFlingSettings.Enabled
                                or workerToken ~= VehicleFlingSettings.WorkerToken then
                                break
                        end

                        if not VehicleFlySettings.Enabled
                                and not VehicleTeleportSettings.ReinforceConnection
                                and canVehicleFling() then
                                local root = VehicleSettings.CurrentRoot

                                if root and root.Parent then
                                        local savedVelocity = root.AssemblyLinearVelocity
                                        local power = math.clamp(
                                                tonumber(VehicleFlingSettings.Power) or 100,
                                                1,
                                                1000
                                        )

                                        root.AssemblyLinearVelocity = savedVelocity * power
                                                + Vector3.new(0, power, 0)

                                        RunService.RenderStepped:Wait()

                                        if running
                                                and VehicleFlingSettings.Enabled
                                                and workerToken == VehicleFlingSettings.WorkerToken
                                                and root
                                                and root.Parent
                                                and VehicleSettings.CurrentRoot == root then
                                                root.AssemblyLinearVelocity = savedVelocity
                                        end

                                        RunService.Stepped:Wait()

                                        if running
                                                and VehicleFlingSettings.Enabled
                                                and workerToken == VehicleFlingSettings.WorkerToken
                                                and root
                                                and root.Parent
                                                and VehicleSettings.CurrentRoot == root then
                                                root.AssemblyLinearVelocity = savedVelocity
                                                        + Vector3.new(0, verticalJitter, 0)
                                                verticalJitter = -verticalJitter
                                        end
                                end
                        end
                end
        end)
end

local function canVehicleTeleport()
        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        return running
                and VehicleTeleportSettings.Enabled
                and seat
                and seat.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
                and isVehicleSeatPart(seat)
                and seat.Occupant == humanoid
end

local function getVehicleTeleportTarget(screenPosition)
        local root = VehicleSettings.CurrentRoot
        local model = VehicleSettings.CurrentModel
        local target = Mouse.Target

        if target
                and target:IsA("BasePart")
                and root
                and root.Parent
                and (not model or not target:IsDescendantOf(model))
                and target.AssemblyRootPart ~= root.AssemblyRootPart
                and Mouse.Hit then
                return Mouse.Hit.Position
        end

        local camera = Workspace.CurrentCamera

        if not camera then
                return nil
        end

        local position = screenPosition or UserInputService:GetMouseLocation()
        local ray = camera:ScreenPointToRay(position.X, position.Y)
        local filter = {}

        if LocalPlayer.Character then
                table.insert(filter, LocalPlayer.Character)
        end

        if model then
                table.insert(filter, model)
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = filter
        params.IgnoreWater = false

        local result = Workspace:Raycast(ray.Origin, ray.Direction * 10000, params)

        return result and result.Position or nil
end

local function hasHumanoidAncestor(instance)
        local current = instance

        while current and current ~= Workspace do
                if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
                        return true
                end

                current = current.Parent
        end

        return false
end

local function countModelBaseParts(model, limit)
        local count = 0

        for _, object in ipairs(model:GetDescendants()) do
                if object:IsA("BasePart") then
                        count += 1

                        if limit and count > limit then
                                return count
                        end
                end
        end

        return count
end

local function collectVehicleTeleportModels(root, model)
        local models = {}
        local seen = {}

        local function addModel(candidate)
                if candidate
                        and candidate:IsA("Model")
                        and candidate.Parent
                        and not seen[candidate]
                        and not hasHumanoidAncestor(candidate) then
                        seen[candidate] = true
                        table.insert(models, candidate)
                end
        end

        local current = root

        while current and current ~= Workspace do
                if current:IsA("Model") then
                        local partCount = countModelBaseParts(current, 450)

                        if partCount <= 450 then
                                addModel(current)
                        elseif #models > 0 then
                                break
                        end
                end

                current = current.Parent
        end

        if model and model.Parent then
                addModel(model)
        end

        return models
end

local function collectVehicleTeleportParts(root, model)
        local parts = {}
        local seen = {}
        local queue = {}
        local nearbyRadius = math.clamp(
                tonumber(VehicleTeleportSettings.NearbyRadius) or 70,
                25,
                150
        )

        local function addPart(part)
                if part
                        and part:IsA("BasePart")
                        and part.Parent
                        and not seen[part]
                        and not hasHumanoidAncestor(part) then
                        seen[part] = true
                        table.insert(parts, part)
                        table.insert(queue, part)
                end
        end

        addPart(root)

        for _, vehicleModel in ipairs(collectVehicleTeleportModels(root, model)) do
                for _, object in ipairs(vehicleModel:GetDescendants()) do
                        if object:IsA("BasePart") then
                                addPart(object)
                        end
                end
        end

        local queueIndex = 1

        while queueIndex <= #queue do
                local part = queue[queueIndex]
                queueIndex += 1

                pcall(function()
                        for _, connected in ipairs(part:GetConnectedParts(true)) do
                                addPart(connected)
                        end
                end)
        end

        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
        overlap.MaxParts = 0

        local nearbyParts = {}

        pcall(function()
                nearbyParts = Workspace:GetPartBoundsInRadius(
                        root.Position,
                        nearbyRadius,
                        overlap
                )
        end)

        for _, part in ipairs(nearbyParts) do
                if part
                        and part:IsA("BasePart")
                        and not part.Anchored
                        and not hasHumanoidAncestor(part)
                        and (part.Position - root.Position).Magnitude <= nearbyRadius then
                        addPart(part)
                end
        end

        queueIndex = 1

        while queueIndex <= #queue do
                local part = queue[queueIndex]
                queueIndex += 1

                pcall(function()
                        for _, connected in ipairs(part:GetConnectedParts(true)) do
                                addPart(connected)
                        end
                end)
        end

        return parts
end

local function captureVehicleTeleportOffsets(root, parts)
        local offsets = {}

        for _, part in ipairs(parts) do
                if part and part.Parent then
                        offsets[part] = root.CFrame:ToObjectSpace(part.CFrame)
                end
        end

        return offsets
end

local function applyVehicleTeleportState(root, desiredRoot, parts, offsets)
        if not root or not root.Parent then
                return
        end

        local movingParts = {}
        local targetCFrames = {}

        for _, part in ipairs(parts) do
                local offset = offsets[part]

                if part
                        and part.Parent
                        and offset then
                        table.insert(movingParts, part)
                        table.insert(targetCFrames, desiredRoot * offset)
                end
        end

        local moved = false

        if #movingParts > 0 then
                moved = pcall(function()
                        Workspace:BulkMoveTo(
                                movingParts,
                                targetCFrames,
                                Enum.BulkMoveMode.FireCFrameChanged
                        )
                end)
        end

        if not moved then
                for index, part in ipairs(movingParts) do
                        pcall(function()
                                part.CFrame = targetCFrames[index]
                        end)
                end
        end

        for _, part in ipairs(movingParts) do
                pcall(function()
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                end)
        end

        pcall(function()
                root.CFrame = desiredRoot
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
        end)
end

local function startVehicleTeleportReinforcement(root, seat, desiredRoot, parts, offsets)
        clearVehicleTeleportReinforcement()

        VehicleTeleportSettings.ReinforceRoot = root
        VehicleTeleportSettings.ReinforceSeat = seat
        VehicleTeleportSettings.ReinforceParts = parts
        VehicleTeleportSettings.ReinforceOffsets = offsets

        local token = VehicleTeleportSettings.ReinforceToken
        local expiresAt = os.clock() + VehicleTeleportSettings.ReinforceDuration

        VehicleTeleportSettings.ReinforceConnection = RunService.Heartbeat:Connect(function()
                local humanoid = MovementSettings.Humanoid

                if not running
                        or not VehicleTeleportSettings.Enabled
                        or token ~= VehicleTeleportSettings.ReinforceToken
                        or os.clock() >= expiresAt
                        or not root
                        or not root.Parent
                        or not seat
                        or not seat.Parent
                        or not humanoid
                        or not humanoid.Parent
                        or VehicleSettings.CurrentRoot ~= root
                        or VehicleSettings.CurrentSeat ~= seat
                        or seat.Occupant ~= humanoid then
                        clearVehicleTeleportReinforcement()
                        return
                end

                applyVehicleTeleportState(root, desiredRoot, parts, offsets)
        end)

        applyVehicleTeleportState(root, desiredRoot, parts, offsets)
end

local function teleportVehicleToMouse(screenPosition)
        if not canVehicleTeleport() then
                return
        end

        local now = os.clock()

        if now - VehicleTeleportSettings.LastTeleport < VehicleTeleportSettings.Cooldown then
                return
        end

        local destination = getVehicleTeleportTarget(screenPosition)

        if not destination then
                return
        end

        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local model = VehicleSettings.CurrentModel
        local lift = math.max(root.Size.Y * 0.5 + 1, 2)

        if model and model.Parent then
                local ok, _, size = pcall(function()
                        return model:GetBoundingBox()
                end)

                if ok and size then
                        lift = math.max(size.Y * 0.5 + 1, lift)
                end
        end

        local upright = getVehicleUprightCFrame(root, seat)
        local desiredRoot = CFrame.new(destination + Vector3.yAxis * lift)
                * (upright - upright.Position)
        local parts = collectVehicleTeleportParts(root, model)
        local offsets = captureVehicleTeleportOffsets(root, parts)

        clearVehicleFlipAssist()
        startVehicleTeleportReinforcement(root, seat, desiredRoot, parts, offsets)
        VehicleTeleportSettings.LastTeleport = now
end

local function setVehicleTeleportEnabled(value)
        VehicleTeleportSettings.Enabled = value and true or false

        if not VehicleTeleportSettings.Enabled then
                clearVehicleTeleportReinforcement()
        end
end

local function startVehicleBoost()
        clearVehicleBoost()

        VehicleSettings.BoostConnection = RunService.Heartbeat:Connect(updateVehicleBoost)
end

local function setVehicleSeat(seat)
        if seat == VehicleSettings.CurrentSeat then
                applyVehicleSeatSpeed()
                return
        end

        restoreVehicleSpeed()

        if not isVehicleSeatPart(seat) then
                return
        end

        VehicleSettings.CurrentSeat = seat
        VehicleSettings.CurrentModel = findVehicleModel(seat)
        VehicleSettings.CurrentRoot = getVehicleRoot(seat, VehicleSettings.CurrentModel)

        if not VehicleSettings.CurrentRoot or not VehicleSettings.CurrentRoot:IsA("BasePart") then
                restoreVehicleSpeed()
                return
        end

        if seat:IsA("VehicleSeat") then
                VehicleSettings.OriginalMaxSpeed[seat] = seat.MaxSpeed
                VehicleSettings.OriginalTurnSpeed[seat] = seat.TurnSpeed

                VehicleSettings.SpeedWatchConnection = seat:GetPropertyChangedSignal("MaxSpeed"):Connect(function()
                        if running
                                and VehicleSettings.CurrentSeat == seat
                                and not VehicleSettings.Updating
                                and seat.MaxSpeed ~= VehicleSettings.Speed then
                                task.defer(applyVehicleSeatSpeed)
                        end
                end)
        end

        applyVehicleSeatSpeed()
        applyVehicleSeatSteering()
        startVehicleBoost()

        if restartVehicleFly then
                restartVehicleFly()
        end
end

local function bindVehicleHumanoid(humanoid)
        clearVehicleSeatedConnection()
        restoreVehicleSpeed()

        if not running or not humanoid or not humanoid.Parent then
                return
        end

        VehicleSettings.SeatedConnection = humanoid.Seated:Connect(function(isSeated, seatPart)
                if isSeated then
                        setVehicleSeat(seatPart)
                else
                        setVehicleSeat(nil)
                end
        end)

        setVehicleSeat(humanoid.SeatPart)
end

local function bindMovementCharacter(character)
        clearSpeedWatcher()
        MovementSettings.Humanoid = nil
        MovementSettings.OriginalSpeed = nil

        if not character then
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
                humanoid = character:WaitForChild("Humanoid", 10)
        end

        if not running or not humanoid or not humanoid:IsA("Humanoid") then
                return
        end

        MovementSettings.Humanoid = humanoid
        bindVehicleHumanoid(humanoid)

        if MovementSettings.Noclip then
                applyNoclip()
        end

        if PlatformSettings.Enabled then
                task.defer(function()
                        if running
                                and PlatformSettings.Enabled
                                and LocalPlayer.Character == character then
                                startPlatformForCharacter()
                        end
                end)
        end

        if MovementSettings.Enabled then
                MovementSettings.OriginalSpeed = humanoid.WalkSpeed
                applySpeed()
                watchSpeed()
        end
end

local function setSpeedEnabled(value)
        MovementSettings.Enabled = value and true or false

        local humanoid = MovementSettings.Humanoid

        if not MovementSettings.Enabled then
                clearSpeedWatcher()

                if humanoid
                        and humanoid.Parent
                        and MovementSettings.OriginalSpeed ~= nil then
                        MovementSettings.Updating = true
                        humanoid.WalkSpeed = MovementSettings.OriginalSpeed
                        MovementSettings.Updating = false
                end

                MovementSettings.OriginalSpeed = nil
                return
        end

        if not humanoid or not humanoid.Parent then
                bindMovementCharacter(LocalPlayer.Character)
                humanoid = MovementSettings.Humanoid
        end

        if humanoid and humanoid.Parent then
                MovementSettings.OriginalSpeed = humanoid.WalkSpeed
                applySpeed()
                watchSpeed()
        end
end

local function clearFlyAnimationLock()
        disconnect(FlySettings.AnimationConnection)
        FlySettings.AnimationConnection = nil

        local animateScript = FlySettings.AnimateScript

        if animateScript
                and animateScript.Parent
                and FlySettings.OriginalAnimateDisabled ~= nil then
                pcall(function()
                        animateScript.Disabled = FlySettings.OriginalAnimateDisabled
                end)
        end

        FlySettings.AnimateScript = nil
        FlySettings.OriginalAnimateDisabled = nil
end

local function stopFlyAnimationTrack(track)
        if track then
                pcall(function()
                        track:Stop(0)
                end)
        end
end

local function lockFlyAnimations(character, humanoid)
        clearFlyAnimationLock()

        if not character
                or not character.Parent
                or not humanoid
                or not humanoid.Parent then
                return
        end

        local animateScript = character:FindFirstChild("Animate")

        if animateScript and animateScript:IsA("LocalScript") then
                FlySettings.AnimateScript = animateScript
                FlySettings.OriginalAnimateDisabled = animateScript.Disabled
                animateScript.Disabled = true
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")

        if not animator then
                local candidate = humanoid:FindFirstChild("Animator")

                if candidate and candidate:IsA("Animator") then
                        animator = candidate
                end
        end

        if not animator then
                return
        end

        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                stopFlyAnimationTrack(track)
        end

        FlySettings.AnimationConnection = animator.AnimationPlayed:Connect(function(track)
                if running
                        and FlySettings.Enabled
                        and FlySettings.Humanoid == humanoid then
                        task.defer(stopFlyAnimationTrack, track)
                end
        end)
end

local function destroyFlyBodyMovers()
        if FlySettings.BodyVelocity then
                pcall(function()
                        FlySettings.BodyVelocity:Destroy()
                end)
        end

        if FlySettings.BodyGyro then
                pcall(function()
                        FlySettings.BodyGyro:Destroy()
                end)
        end

        FlySettings.BodyVelocity = nil
        FlySettings.BodyGyro = nil
end

local function stopFlyRuntime()
        pcall(function()
                RunService:UnbindFromRenderStep(FLY_BIND_NAME)
        end)

        clearFlyAnimationLock()

        local root = FlySettings.Root
        local humanoid = FlySettings.Humanoid
        local carriedVelocity = FlySettings.CurrentVelocity

        destroyFlyBodyMovers()

        if root and root.Parent then
                root.AssemblyLinearVelocity = carriedVelocity * 0.15
                root.AssemblyAngularVelocity = Vector3.zero
        end

        if humanoid and humanoid.Parent then
                if FlySettings.OriginalAutoRotate ~= nil then
                        humanoid.AutoRotate = FlySettings.OriginalAutoRotate
                end

                if FlySettings.OriginalPlatformStand ~= nil then
                        humanoid.PlatformStand = FlySettings.OriginalPlatformStand
                end

                if humanoid.Health > 0 then
                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
        end

        FlySettings.Root = nil
        FlySettings.Humanoid = nil
        FlySettings.CurrentVelocity = Vector3.zero
        FlySettings.CurrentOrientation = nil
        FlySettings.OriginalAutoRotate = nil
        FlySettings.OriginalPlatformStand = nil
end

local function getFlyInput(camera)
        if UserInputService:GetFocusedTextBox() then
                return Vector3.zero, 0, 0
        end

        local forwardInput = 0
        local strafeInput = 0
        local verticalInput = 0

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                forwardInput += 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                forwardInput -= 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                strafeInput += 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                strafeInput -= 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                verticalInput += 1
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                verticalInput -= 1
        end

        local direction = (camera.CFrame.LookVector * forwardInput)
                + (camera.CFrame.RightVector * strafeInput)
                + (Vector3.yAxis * verticalInput)

        if direction.Magnitude > 0 then
                direction = direction.Unit
        end

        return direction, forwardInput, strafeInput
end

local function updateFly(deltaTime)
        if not running or not FlySettings.Enabled then
                return
        end

        local root = FlySettings.Root
        local humanoid = FlySettings.Humanoid
        local bodyVelocity = FlySettings.BodyVelocity
        local bodyGyro = FlySettings.BodyGyro
        local camera = Workspace.CurrentCamera

        if not root
                or not root.Parent
                or not humanoid
                or not humanoid.Parent
                or humanoid.Health <= 0
                or not bodyVelocity
                or not bodyVelocity.Parent
                or not bodyGyro
                or not bodyGyro.Parent
                or not camera then
                return
        end

        deltaTime = tonumber(deltaTime) or (1 / 60)

        local animator = humanoid:FindFirstChildOfClass("Animator")

        if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        stopFlyAnimationTrack(track)
                end
        end

        local direction, _, strafeInput = getFlyInput(camera)
        local targetVelocity = direction * FlySettings.Speed
        local currentVelocity = FlySettings.CurrentVelocity
        local response = targetVelocity.Magnitude > currentVelocity.Magnitude
                and FlySettings.Acceleration
                or FlySettings.Deceleration
        local velocityAlpha = 1 - math.exp(-response * deltaTime)

        FlySettings.CurrentVelocity = currentVelocity:Lerp(targetVelocity, velocityAlpha)
        bodyVelocity.Velocity = FlySettings.CurrentVelocity

        local lookVector = camera.CFrame.LookVector

        if lookVector.Magnitude > 0.001 then
                local velocityRatio = math.clamp(
                        FlySettings.CurrentVelocity.Magnitude / math.max(FlySettings.Speed, 1),
                        0,
                        1
                )
                local roll = -math.clamp(strafeInput, -1, 1) * math.rad(12) * velocityRatio
                local targetOrientation = CFrame.lookAt(
                        root.Position,
                        root.Position + lookVector,
                        camera.CFrame.UpVector
                ) * CFrame.Angles(0, 0, roll)

                if not FlySettings.CurrentOrientation then
                        FlySettings.CurrentOrientation = targetOrientation
                else
                        local orientationAlpha = 1 - math.exp(-18 * deltaTime)
                        FlySettings.CurrentOrientation = FlySettings.CurrentOrientation:Lerp(targetOrientation, orientationAlpha)
                end

                bodyGyro.CFrame = FlySettings.CurrentOrientation
        end
end

local function startFlyForCharacter(character)
        stopFlyRuntime()

        if not running or not FlySettings.Enabled or not character then
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = getRoot(character)

        if not humanoid then
                humanoid = character:WaitForChild("Humanoid", 10)
        end

        if not root then
                root = character:WaitForChild("HumanoidRootPart", 10)
        end

        if not running
                or not FlySettings.Enabled
                or not humanoid
                or not humanoid:IsA("Humanoid")
                or not root
                or not root:IsA("BasePart") then
                return
        end

        FlySettings.Root = root
        FlySettings.Humanoid = humanoid
        FlySettings.CurrentVelocity = Vector3.zero
        FlySettings.OriginalAutoRotate = humanoid.AutoRotate
        FlySettings.OriginalPlatformStand = humanoid.PlatformStand

        humanoid.AutoRotate = false
        humanoid.PlatformStand = true
        lockFlyAnimations(character, humanoid)
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        local camera = Workspace.CurrentCamera
        if camera and camera.CFrame.LookVector.Magnitude > 0.001 then
                FlySettings.CurrentOrientation = CFrame.lookAt(
                        root.Position,
                        root.Position + camera.CFrame.LookVector,
                        camera.CFrame.UpVector
                )
        else
                FlySettings.CurrentOrientation = root.CFrame
        end

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "__PlayerToolsFlyVelocity"
        bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVelocity.P = 8000
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root
        FlySettings.BodyVelocity = bodyVelocity

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "__PlayerToolsFlyGyro"
        bodyGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
        bodyGyro.P = 7000
        bodyGyro.D = 600
        bodyGyro.CFrame = FlySettings.CurrentOrientation
        bodyGyro.Parent = root
        FlySettings.BodyGyro = bodyGyro

        pcall(function()
                RunService:UnbindFromRenderStep(FLY_BIND_NAME)
        end)

        RunService:BindToRenderStep(FLY_BIND_NAME, Enum.RenderPriority.Character.Value + 1, updateFly)
end

local function setFlyEnabled(value)
        local enabled = value and true or false

        if FlySettings.Enabled == enabled then
                return
        end

        FlySettings.Enabled = enabled

        if not enabled then
                stopFlyRuntime()
                return
        end

        startFlyForCharacter(LocalPlayer.Character)
end

local function destroyVehicleFlyBodyMovers()
        if VehicleFlySettings.BodyVelocity then
                pcall(function()
                        VehicleFlySettings.BodyVelocity:Destroy()
                end)
        end

        if VehicleFlySettings.BodyGyro then
                pcall(function()
                        VehicleFlySettings.BodyGyro:Destroy()
                end)
        end

        VehicleFlySettings.BodyVelocity = nil
        VehicleFlySettings.BodyGyro = nil
end

stopVehicleFlyRuntime = function()
        pcall(function()
                RunService:UnbindFromRenderStep(VEHICLE_FLY_BIND_NAME)
        end)

        local root = VehicleFlySettings.Root
        local carriedVelocity = VehicleFlySettings.CurrentVelocity

        destroyVehicleFlyBodyMovers()

        if root and root.Parent then
                root.AssemblyLinearVelocity = carriedVelocity * 0.15
                root.AssemblyAngularVelocity = Vector3.zero
        end

        VehicleFlySettings.Root = nil
        VehicleFlySettings.Seat = nil
        VehicleFlySettings.CurrentVelocity = Vector3.zero
        VehicleFlySettings.CurrentOrientation = nil
end

local function isVehicleFlyValid()
        local seat = VehicleFlySettings.Seat
        local root = VehicleFlySettings.Root
        local humanoid = MovementSettings.Humanoid

        return running
                and VehicleFlySettings.Enabled
                and seat
                and seat.Parent
                and root
                and root.Parent
                and humanoid
                and humanoid.Parent
                and isVehicleSeatPart(seat)
                and VehicleSettings.CurrentSeat == seat
                and VehicleSettings.CurrentRoot == root
                and seat.Occupant == humanoid
end

local function updateVehicleFly(deltaTime)
        if not isVehicleFlyValid() then
                if VehicleFlySettings.Root then
                        stopVehicleFlyRuntime()
                end
                return
        end

        local root = VehicleFlySettings.Root
        local bodyVelocity = VehicleFlySettings.BodyVelocity
        local bodyGyro = VehicleFlySettings.BodyGyro
        local camera = Workspace.CurrentCamera

        if not bodyVelocity
                or not bodyVelocity.Parent
                or not bodyGyro
                or not bodyGyro.Parent
                or not camera then
                stopVehicleFlyRuntime()
                return
        end

        deltaTime = math.max(tonumber(deltaTime) or (1 / 60), 0)

        local direction, _, strafeInput = getFlyInput(camera)
        local targetVelocity = direction * VehicleFlySettings.Speed
        local currentVelocity = VehicleFlySettings.CurrentVelocity
        local response = targetVelocity.Magnitude > currentVelocity.Magnitude
                and VehicleFlySettings.Acceleration
                or VehicleFlySettings.Deceleration
        local velocityAlpha = 1 - math.exp(-response * deltaTime)

        VehicleFlySettings.CurrentVelocity = currentVelocity:Lerp(targetVelocity, velocityAlpha)
        bodyVelocity.Velocity = VehicleFlySettings.CurrentVelocity

        local lookVector = camera.CFrame.LookVector

        if lookVector.Magnitude > 0.001 then
                local velocityRatio = math.clamp(
                        VehicleFlySettings.CurrentVelocity.Magnitude / math.max(VehicleFlySettings.Speed, 1),
                        0,
                        1
                )
                local roll = -math.clamp(strafeInput, -1, 1) * math.rad(12) * velocityRatio
                local targetOrientation = CFrame.lookAt(
                        root.Position,
                        root.Position + lookVector,
                        camera.CFrame.UpVector
                ) * CFrame.Angles(0, 0, roll)

                if not VehicleFlySettings.CurrentOrientation then
                        VehicleFlySettings.CurrentOrientation = targetOrientation
                else
                        local orientationAlpha = 1 - math.exp(-18 * deltaTime)
                        VehicleFlySettings.CurrentOrientation = VehicleFlySettings.CurrentOrientation:Lerp(
                                targetOrientation,
                                orientationAlpha
                        )
                end

                bodyGyro.CFrame = VehicleFlySettings.CurrentOrientation
        end
end

local function startVehicleFly()
        stopVehicleFlyRuntime()

        if not running
                or not VehicleFlySettings.Enabled
                or not VehicleSettings.CurrentSeat
                or not VehicleSettings.CurrentRoot
                or not MovementSettings.Humanoid then
                return
        end

        local seat = VehicleSettings.CurrentSeat
        local root = VehicleSettings.CurrentRoot
        local humanoid = MovementSettings.Humanoid

        if not isVehicleSeatPart(seat)
                or not root:IsA("BasePart")
                or not humanoid.Parent
                or seat.Occupant ~= humanoid then
                return
        end

        VehicleFlySettings.Seat = seat
        VehicleFlySettings.Root = root
        VehicleFlySettings.CurrentVelocity = Vector3.zero

        local camera = Workspace.CurrentCamera

        if camera and camera.CFrame.LookVector.Magnitude > 0.001 then
                VehicleFlySettings.CurrentOrientation = CFrame.lookAt(
                        root.Position,
                        root.Position + camera.CFrame.LookVector,
                        camera.CFrame.UpVector
                )
        else
                VehicleFlySettings.CurrentOrientation = root.CFrame
        end

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "__PlayerToolsVehicleFlyVelocity"
        bodyVelocity.MaxForce = Vector3.new(1e8, 1e8, 1e8)
        bodyVelocity.P = 8000
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root
        VehicleFlySettings.BodyVelocity = bodyVelocity

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "__PlayerToolsVehicleFlyGyro"
        bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bodyGyro.P = 7000
        bodyGyro.D = 600
        bodyGyro.CFrame = VehicleFlySettings.CurrentOrientation
        bodyGyro.Parent = root
        VehicleFlySettings.BodyGyro = bodyGyro

        pcall(function()
                RunService:UnbindFromRenderStep(VEHICLE_FLY_BIND_NAME)
        end)

        RunService:BindToRenderStep(
                VEHICLE_FLY_BIND_NAME,
                Enum.RenderPriority.Character.Value + 2,
                updateVehicleFly
        )
end

restartVehicleFly = function()
        if VehicleFlySettings.Enabled then
                startVehicleFly()
        else
                stopVehicleFlyRuntime()
        end
end

local function setVehicleFlyEnabled(value)
        local enabled = value and true or false

        if VehicleFlySettings.Enabled == enabled then
                return
        end

        VehicleFlySettings.Enabled = enabled

        if not enabled then
                stopVehicleFlyRuntime()
                return
        end

        startVehicleFly()
end

local function disconnectAntiFlingConnections()
        for _, connection in ipairs(FlingSettings.AntiFlingConnections) do
                disconnect(connection)
        end

        table.clear(FlingSettings.AntiFlingConnections)
end

local function restoreAntiFlingCollisions()
        for part, originalCanCollide in pairs(FlingSettings.CollisionStates) do
                if part and part.Parent then
                        pcall(function()
                                part.CanCollide = originalCanCollide
                        end)
                end
        end

        FlingSettings.CollisionStates = setmetatable({}, {__mode = "k"})
end

local function applyNoCollision(character)
        if not character then
                return
        end

        for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("BasePart") then
                        if FlingSettings.CollisionStates[object] == nil then
                                FlingSettings.CollisionStates[object] = object.CanCollide
                        end

                        pcall(function()
                                object.CanCollide = false
                        end)
                end
        end
end

local function watchNoCollisionCharacter(character)
        if not character then
                return
        end

        applyNoCollision(character)

        table.insert(FlingSettings.AntiFlingConnections, character.DescendantAdded:Connect(function(object)
                if FlingSettings.AntiFling and object:IsA("BasePart") then
                        if FlingSettings.CollisionStates[object] == nil then
                                FlingSettings.CollisionStates[object] = object.CanCollide
                        end

                        object.CanCollide = false
                end
        end))
end

local function disableAntiFling()
        FlingSettings.AntiFling = false
        disconnectAntiFlingConnections()
        restoreAntiFlingCollisions()
end

local function enableAntiFling()
        disableAntiFling()
        FlingSettings.AntiFling = true

        local function watchPlayer(player)
                if player == LocalPlayer then
                        return
                end

                if player.Character then
                        watchNoCollisionCharacter(player.Character)
                end

                table.insert(FlingSettings.AntiFlingConnections, player.CharacterAdded:Connect(function(character)
                        if FlingSettings.AntiFling then
                                watchNoCollisionCharacter(character)
                        end
                end))
        end

        for _, player in ipairs(Players:GetPlayers()) do
                watchPlayer(player)
        end

        table.insert(FlingSettings.AntiFlingConnections, Players.PlayerAdded:Connect(watchPlayer))
end

local function setAntiFlingEnabled(value)
        if value then
                enableAntiFling()
        else
                disableAntiFling()
        end
end

local function setFlingEnabled(value)
        local enabled = value and true or false

        if FlingSettings.Enabled == enabled then
                return
        end

        FlingSettings.Enabled = enabled
        FlingSettings.WorkerToken += 1

        if not enabled then
                return
        end

        local workerToken = FlingSettings.WorkerToken

        task.spawn(function()
                local verticalJitter = 0.1

                while running
                        and FlingSettings.Enabled
                        and workerToken == FlingSettings.WorkerToken do
                        RunService.Heartbeat:Wait()

                        if not running
                                or not FlingSettings.Enabled
                                or workerToken ~= FlingSettings.WorkerToken then
                                break
                        end

                        local root = getRoot(LocalPlayer.Character)

                        if root and root.Parent then
                                local savedVelocity = root.AssemblyLinearVelocity
                                local power = math.clamp(tonumber(FlingSettings.Power) or 100, 1, 1000)

                                root.AssemblyLinearVelocity = savedVelocity * power + Vector3.new(0, power, 0)

                                RunService.RenderStepped:Wait()

                                if running
                                        and FlingSettings.Enabled
                                        and workerToken == FlingSettings.WorkerToken
                                        and root
                                        and root.Parent then
                                        root.AssemblyLinearVelocity = savedVelocity
                                end

                                RunService.Stepped:Wait()

                                if running
                                        and FlingSettings.Enabled
                                        and workerToken == FlingSettings.WorkerToken
                                        and root
                                        and root.Parent then
                                        root.AssemblyLinearVelocity = savedVelocity + Vector3.new(0, verticalJitter, 0)
                                        verticalJitter = -verticalJitter
                                end
                        end
                end
        end)
end

local function cleanup()
        if not running then
                return
        end

        running = false
        Settings.Enabled = false
        AimlockSettings.Enabled = false
        MovementSettings.Noclip = false
        ClickTeleportSettings.Enabled = false
        PlatformSettings.Enabled = false
        PartRingSettings.Enabled = false
        PartRingSettings.TargetPickerEnabled = false
        PartRing.stop()
        PartRing.stopTargetPicker()
        clearPlatform()
        clearNoclip()
        FlingSettings.Enabled = false
        FlingSettings.WorkerToken += 1
        disableAntiFling()
        FlySettings.Enabled = false
        stopFlyRuntime()
        VehicleFlySettings.Enabled = false
        stopVehicleFlyRuntime()
        VehicleFlingSettings.Enabled = false
        VehicleFlingSettings.WorkerToken += 1
        PlayerTrollSettings.BlastEnabled = false
        PlayerTrollSettings.MeteorEnabled = false
        PlayerTrollSettings.SwarmEnabled = false
        PlayerTrollSettings.CageEnabled = false
        PlayerTrollSettings.TargetPickerEnabled = false
        pcall(function()
                PlayerTroll.syncConnection()
        end)
        pcall(function()
                PlayerTroll.stopTargetPicker()
        end)
        VehicleSpeedBoostSettings.ActiveUntil = 0
        VehicleTeleportSettings.Enabled = false
        clearVehicleTeleportReinforcement()
        clearVehicleFlipAssist()
        AimlockSettings.Holding = false
        AimlockSettings.TargetPlayer = nil
        AimlockSettings.TargetCharacter = nil
        AimlockSettings.TargetHumanoid = nil
        AimlockSettings.TargetPart = nil

        pcall(function()
                RunService:UnbindFromRenderStep(AIMLOCK_BIND_NAME)
        end)

        pcall(function()
                RunService:UnbindFromRenderStep(FLY_BIND_NAME)
        end)

        pcall(function()
                RunService:UnbindFromRenderStep(VEHICLE_FLY_BIND_NAME)
        end)

        clearSpeedWatcher()
        clearVehicleSeatedConnection()
        restoreVehicleSpeed()

        if MovementSettings.Humanoid
                and MovementSettings.Humanoid.Parent
                and MovementSettings.OriginalSpeed ~= nil then
                MovementSettings.Humanoid.WalkSpeed = MovementSettings.OriginalSpeed
        end

        for _, player in ipairs(Players:GetPlayers()) do
                removeESP(player.Character)
        end

        for _, connection in ipairs(connections) do
                disconnect(connection)
        end

        table.clear(connections)

        if Window then
                pcall(function()
                        Window:Destroy()
                end)
        end
end

Global.__PlayerToolsCleanup = cleanup
Global.__AxiomCleanup = cleanup
Global.__ProjectESPCleanup = cleanup

for _, player in ipairs(Players:GetPlayers()) do
        removeESP(player.Character)
end

bindMovementCharacter(LocalPlayer.Character)

Window = Reborn:CreateWindow({
        Title = "PlayerTools",
        Size = Vector2.new(680, 480)
})

local ESPTab = Window:Tab("ESP", "eye")
local MovementTab = Window:Tab("Movement", "user")
local VehicleMovementTab = Window:Tab("Vehicle Movement", "gauge")
local FunTab = Window:Tab("Fun", "star")

ESPTab:SetColumns(2)
MovementTab:SetColumns(2)
VehicleMovementTab:SetColumns(2)

do
local MainSection = ESPTab:Section("Player ESP")

MainSection:Toggle({
        Text = "Enable ESP",
        Value = false,
        Callback = function(value)
                Settings.Enabled = value
                refreshAll()
        end
})

MainSection:Toggle({
        Text = "Team Check",
        Value = true,
        Callback = function(value)
                Settings.TeamCheck = value
                refreshAll()
        end
})

MainSection:Toggle({
        Text = "Through Walls",
        Value = true,
        Callback = function(value)
                Settings.ThroughWalls = value
                refreshAll()
        end
})

local LabelSection = ESPTab:Section("ESP Elements")

LabelSection:Toggle({
        Text = "Highlight",
        Value = true,
        Callback = function(value)
                Settings.Highlight = value
                refreshAll()
        end
})

LabelSection:Toggle({
        Text = "Show Name",
        Value = true,
        Callback = function(value)
                Settings.ShowName = value
                refreshAll()
        end
})

LabelSection:Toggle({
        Text = "Show Health",
        Value = true,
        Callback = function(value)
                Settings.ShowHealth = value
                refreshAll()
        end
})

LabelSection:Toggle({
        Text = "Show Distance",
        Value = true,
        Callback = function(value)
                Settings.ShowDistance = value
                refreshAll()
        end
})
end

do
local StyleSection = ESPTab:Section("Style")

StyleSection:ColorPicker({
        Text = "ESP Color",
        Value = Settings.Color,
        Callback = function(hex, color)
                Settings.Color = color
                refreshAll()
        end
})

StyleSection:Slider({
        Text = "Fill Opacity",
        Min = 0,
        Max = 100,
        Value = 26,
        Callback = function(value)
                Settings.FillTransparency = 1 - (value / 100)
                refreshAll()
        end
})

StyleSection:Slider({
        Text = "Maximum Distance",
        Min = 100,
        Max = 5000,
        Value = 1500,
        Callback = function(value)
                Settings.MaxDistance = value
                refreshAll()
        end
})
end

do
local MovementSection = MovementTab:Section("Walk Speed")

local speedToggle = MovementSection:Toggle({
        Text = "Enable Speed",
        Value = false,
        Callback = function(value)
                setSpeedEnabled(value)
        end
})

local speedSlider = MovementSection:Slider({
        Text = "Walk Speed",
        Min = 0,
        Max = 250,
        Value = 16,
        Callback = function(value)
                MovementSettings.Speed = value
                applySpeed()
        end
})

MovementSection:Button({
        Text = "Set Normal Speed",
        Callback = function()
                speedSlider:Set(16, true)
        end
})

MovementSection:Toggle({
        Text = "Infinite Jump",
        Value = false,
        Callback = function(value)
                MovementSettings.InfiniteJump = value and true or false
        end
})

MovementSection:Toggle({
        Text = "Noclip",
        Value = false,
        Callback = function(value)
                setNoclipEnabled(value)
        end
})
end

do
local ClickTeleportSection = MovementTab:Section("Click Teleport")

ClickTeleportSection:Toggle({
        Text = "Enable Click Teleport",
        Value = false,
        Callback = function(value)
                ClickTeleportSettings.Enabled = value and true or false
        end
})
end

do
local PlatformSection = MovementTab:Section("Platform")

PlatformSection:Toggle({
        Text = "Enable Platform",
        Value = false,
        Callback = function(value)
                setPlatformEnabled(value)
        end
})
end

do
local PartRingSection = FunTab:Section("Chaos")

local partRingToggleValue = false
local partRingToggle = PartRingSection:Toggle({
        Text = "Enable Chaos",
        Value = false,
        Callback = function(value)
                partRingToggleValue = value and true or false
                PartRing.setEnabled(partRingToggleValue)
        end
})

PartRing.OnEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if partRingToggleValue == desiredValue then
                return
        end

        partRingToggleValue = desiredValue
        partRingToggle:Set(desiredValue)
end

local partRingTargetLabel = PartRingSection:Paragraph({
        Text = "Target: " .. PartRing.getTargetOption()
})

local partRingTargetPickerValue = false
local partRingTargetPickerToggle = PartRingSection:Toggle({
        Text = "Select Chaos Target",
        Value = false,
        Callback = function(value)
                partRingTargetPickerValue = value and true or false
                PartRing.setPickerEnabled(partRingTargetPickerValue)
        end
})

PartRingSection:Paragraph({
        Text = "Hover a player and left-click them to set the chaos target."
})

PartRing.OnPickerEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if partRingTargetPickerValue == desiredValue then
                return
        end

        partRingTargetPickerValue = desiredValue
        partRingTargetPickerToggle:Set(desiredValue)
end

PartRingSection:Button({
        Text = "Target Me",
        Callback = function()
                PartRing.setTarget("Me")
        end
})

local partRingStatusLabel = PartRingSection:Paragraph({
        Text = "Chaos off"
})

PartRing.OnStatusChanged = function(status)
        partRingStatusLabel:Set(tostring(status or "Chaos off"))
end

PartRing.OnTargetChanged = function(name)
        partRingTargetLabel:Set("Target: " .. tostring(name or "Me"))

        if partRingTargetPickerValue then
                PartRing.setPickerEnabled(false)
        end
end

PartRingSection:Slider({
        Text = "Search Range",
        Min = 15,
        Max = 5000,
        Value = PartRingSettings.ScanRadius,
        Callback = function(value)
                PartRingSettings.ScanRadius = value

                if PartRingSettings.Enabled then
                        PartRing.refresh()
                end
        end
})

PartRingSection:Slider({
        Text = "Chaos Radius",
        Min = 3,
        Max = 150,
        Value = PartRingSettings.Radius,
        Callback = function(value)
                PartRingSettings.Radius = math.clamp(
                        tonumber(value) or 12,
                        3,
                        150
                )

                if PartRingSettings.Enabled then
                        PartRingSettings.NextRescan = 0
                        PartRing.refresh()
                end
        end
})

PartRingSection:Slider({
        Text = "Chaos Height",
        Min = -10,
        Max = 25,
        Value = PartRingSettings.Height,
        Callback = function(value)
                PartRingSettings.Height = value
        end
})

PartRingSection:Slider({
        Text = "Chaos Speed",
        Min = 0,
        Max = 20,
        Step = 0.5,
        Value = PartRingSettings.Speed,
        Callback = function(value)
                PartRingSettings.Speed = value
        end
})

PartRingSection:Slider({
        Text = "Rotation Speed",
        Min = 0,
        Max = 300,
        Value = PartRingSettings.RotationSpeed,
        Callback = function(value)
                PartRingSettings.RotationSpeed = value
        end
})

PartRingSection:Button({
        Text = "Refresh Parts",
        Callback = function()
                PartRing.refresh()
        end
})
end

do
local RingPowerSection = FunTab:Section("Chaos Power")

RingPowerSection:Slider({
        Text = "Pull Strength",
        Min = 1,
        Max = 100,
        Value = PartRingSettings.PullStrength,
        Callback = function(value)
                PartRingSettings.PullStrength = value
        end
})

RingPowerSection:Slider({
        Text = "Max Part Mass",
        Min = 100,
        Max = 5000000,
        Value = PartRingSettings.MaximumAssemblyMass,
        Callback = function(value)
                PartRingSettings.MaximumAssemblyMass = value

                if PartRingSettings.Enabled then
                        PartRing.refresh()
                end
        end
})

RingPowerSection:Slider({
        Text = "Max Part Size",
        Min = 5,
        Max = 10000,
        Value = PartRingSettings.MaximumAssemblySize,
        Callback = function(value)
                PartRingSettings.MaximumAssemblySize = value

                if PartRingSettings.Enabled then
                        PartRing.refresh()
                end
        end
})

RingPowerSection:Slider({
        Text = "Release Fling",
        Min = 0,
        Max = 5,
        Step = 0.25,
        Value = PartRingSettings.ReleasePower,
        Callback = function(value)
                PartRingSettings.ReleasePower = value
        end
})

RingPowerSection:Paragraph({
        Text = "Release Fling: 0 freezes parts on release, 1 keeps their orbit momentum, 2-5 flings them outward with extra force."
})
end

do
local FlySection = MovementTab:Section("Fly")

FlySection:Toggle({
        Text = "Enable Fly",
        Value = false,
        Callback = function(value)
                setFlyEnabled(value)
        end
})

FlySection:Slider({
        Text = "Fly Speed",
        Min = 10,
        Max = 250,
        Value = FlySettings.Speed,
        Callback = function(value)
                FlySettings.Speed = value
        end
})
end

do
local AimlockSection = MovementTab:Section("Aimlock")

AimlockSection:Toggle({
        Text = "Enable Aimlock",
        Value = false,
        Callback = function(value)
                setAimlockEnabled(value)
        end
})

AimlockSection:Toggle({
        Text = "Team Check",
        Value = true,
        Callback = function(value)
                AimlockSettings.TeamCheck = value
        end
})

AimlockSection:Slider({
        Text = "Cursor Radius",
        Min = 50,
        Max = 600,
        Value = AimlockSettings.CursorRadius,
        Callback = function(value)
                AimlockSettings.CursorRadius = value
        end
})

AimlockSection:Slider({
        Text = "Maximum Distance",
        Min = 100,
        Max = 5000,
        Value = AimlockSettings.MaxDistance,
        Callback = function(value)
                AimlockSettings.MaxDistance = value
        end
})

aimStatusLabel = AimlockSection:Paragraph({
        Text = "Target: None"
})
end

do
local FlingSection = MovementTab:Section("Fling")

FlingSection:Toggle({
        Text = "Fling",
        Value = false,
        Callback = function(value)
                setFlingEnabled(value)
        end
})

FlingSection:Toggle({
        Text = "Anti Fling",
        Value = false,
        Callback = function(value)
                setAntiFlingEnabled(value)
        end
})

FlingSection:Input({
        Text = "Fling Power",
        Value = tostring(FlingSettings.Power),
        Placeholder = "100",
        Callback = function(value)
                local parsed = tonumber(value)

                if parsed then
                        FlingSettings.Power = math.clamp(parsed, 1, 1000)
                end
        end
})
end

do
local VehicleSection = VehicleMovementTab:Section("Vehicle Speed")

VehicleSection:Slider({
        Text = "Vehicle Speed",
        Min = 0,
        Max = 500,
        Value = VehicleSettings.Speed,
        Callback = function(value)
                VehicleSettings.Speed = value
                applyVehicleSeatSpeed()
        end
})

VehicleSection:Slider({
        Text = "Steering Strength",
        Min = 0,
        Max = 50,
        Value = VehicleSettings.SteeringStrength,
        Callback = function(value)
                VehicleSettings.SteeringStrength = value
                applyVehicleSeatSteering()
        end
})
end

do
local VehicleFlySection = VehicleMovementTab:Section("Vehicle Fly")

VehicleFlySection:Toggle({
        Text = "Enable Vehicle Fly",
        Value = false,
        Callback = function(value)
                setVehicleFlyEnabled(value)
        end
})

VehicleFlySection:Slider({
        Text = "Vehicle Fly Speed",
        Min = 10,
        Max = 250,
        Value = VehicleFlySettings.Speed,
        Callback = function(value)
                VehicleFlySettings.Speed = value
        end
})
end

do
local VehicleJumpSection = VehicleMovementTab:Section("Vehicle Jump")

VehicleJumpSection:Slider({
        Text = "Jump Power",
        Min = 20,
        Max = 250,
        Value = VehicleJumpSettings.Power,
        Callback = function(value)
                VehicleJumpSettings.Power = value
        end
})
end

do
local VehicleSpeedBoostSection = VehicleMovementTab:Section("Vehicle Speed Boost")

VehicleSpeedBoostSection:Slider({
        Text = "Boost Speed",
        Min = 20,
        Max = 600,
        Value = VehicleSpeedBoostSettings.Power,
        Callback = function(value)
                VehicleSpeedBoostSettings.Power = value
        end
})
end

do
local VehicleFlingSection = VehicleMovementTab:Section("Vehicle Fling")

VehicleFlingSection:Toggle({
        Text = "Vehicle Fling",
        Value = false,
        Callback = function(value)
                setVehicleFlingEnabled(value)
        end
})

VehicleFlingSection:Input({
        Text = "Vehicle Fling Power",
        Value = tostring(VehicleFlingSettings.Power),
        Placeholder = "100",
        Callback = function(value)
                local parsed = tonumber(value)

                if parsed then
                        VehicleFlingSettings.Power = math.clamp(parsed, 1, 1000)
                end
        end
})
end

do
local VehicleTeleportSection = VehicleMovementTab:Section("Vehicle Teleport")

VehicleTeleportSection:Toggle({
        Text = "Enable Vehicle Teleport",
        Value = false,
        Callback = function(value)
                setVehicleTeleportEnabled(value)
        end
})
end

do
local PlayerTrollSection = FunTab:Section("Player Troll")

local playerTrollStatusLabel = PlayerTrollSection:Paragraph({
        Text = "Player Troll off"
})

PlayerTroll.OnStatusChanged = function(status)
        playerTrollStatusLabel:Set(tostring(status or "Player Troll off"))
end

local playerTrollTargetLabel = PlayerTrollSection:Paragraph({
        Text = "Target: Nearest"
})

PlayerTroll.OnTargetChanged = function(name)
        playerTrollTargetLabel:Set("Target: " .. tostring(name or "Nearest"))
end

local playerTrollPickerValue = false
local playerTrollPickerToggle = PlayerTrollSection:Toggle({
        Text = "Select Troll Target",
        Value = false,
        Callback = function(value)
                playerTrollPickerValue = value and true or false
                PlayerTroll.setPickerEnabled(playerTrollPickerValue)
        end
})

PlayerTroll.OnPickerEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if playerTrollPickerValue == desiredValue then
                return
        end

        playerTrollPickerValue = desiredValue
        playerTrollPickerToggle:Set(desiredValue)
end

PlayerTrollSection:Paragraph({
        Text = "Hover a player and left-click them to set the troll target."
})

PlayerTrollSection:Button({
        Text = "Target Nearest",
        Callback = function()
                PlayerTroll.setTarget("Nearest")
        end
})

PlayerTrollSection:Toggle({
        Text = "Target Everyone",
        Value = false,
        Callback = function(value)
                PlayerTroll.setTargetEveryone(value)
        end
})

PlayerTrollSection:Toggle({
        Text = "Blast Players",
        Value = false,
        Callback = function(value)
                PlayerTrollSettings.BlastEnabled = value and true or false
                PlayerTroll.syncConnection()
        end
})

PlayerTrollSection:Slider({
        Text = "Blast Power",
        Min = 100,
        Max = 2500,
        Value = PlayerTrollSettings.BlastPower,
        Callback = function(value)
                PlayerTrollSettings.BlastPower = value
        end
})

PlayerTrollSection:Slider({
        Text = "Blast Cooldown",
        Min = 0.2,
        Max = 5,
        Step = 0.1,
        Value = PlayerTrollSettings.BlastCooldown,
        Callback = function(value)
                PlayerTrollSettings.BlastCooldown = value
        end
})
end

do
local PlayerTrollPowerSection = FunTab:Section("Player Troll Power")

PlayerTrollPowerSection:Toggle({
        Text = "Meteor Players",
        Value = false,
        Callback = function(value)
                PlayerTrollSettings.MeteorEnabled = value and true or false
                PlayerTroll.syncConnection()
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Meteor Flight Time",
        Min = 0.5,
        Max = 3,
        Step = 0.1,
        Value = PlayerTrollSettings.MeteorFlightTime,
        Callback = function(value)
                PlayerTrollSettings.MeteorFlightTime = value
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Meteor Interval",
        Min = 0.5,
        Max = 5,
        Step = 0.1,
        Value = PlayerTrollSettings.MeteorInterval,
        Callback = function(value)
                PlayerTrollSettings.MeteorInterval = value
        end
})

PlayerTrollPowerSection:Toggle({
        Text = "Swarm Players",
        Value = false,
        Callback = function(value)
                PlayerTrollSettings.SwarmEnabled = value and true or false
                PlayerTroll.syncConnection()
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Swarm Radius",
        Min = 2,
        Max = 12,
        Value = PlayerTrollSettings.SwarmRadius,
        Callback = function(value)
                PlayerTrollSettings.SwarmRadius = value
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Swarm Speed",
        Min = 2,
        Max = 40,
        Value = PlayerTrollSettings.SwarmSpeed,
        Callback = function(value)
                PlayerTrollSettings.SwarmSpeed = value
        end
})

PlayerTrollPowerSection:Toggle({
        Text = "Cage Players",
        Value = false,
        Callback = function(value)
                PlayerTrollSettings.CageEnabled = value and true or false
                PlayerTroll.syncConnection()
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Cage Size",
        Min = 4,
        Max = 15,
        Value = PlayerTrollSettings.CageSize,
        Callback = function(value)
                PlayerTrollSettings.CageSize = value
        end
})

PlayerTrollPowerSection:Slider({
        Text = "Scan Range",
        Min = 20,
        Max = 300,
        Value = PlayerTrollSettings.ScanRadius,
        Callback = function(value)
                PlayerTrollSettings.ScanRadius = value

                if PlayerTrollSettings.Connection then
                        PlayerTrollSettings.NextRescan = 0
                end
        end
})
end

track(LocalPlayer.CharacterAdded:Connect(function(character)
        bindMovementCharacter(character)

        if FlySettings.Enabled then
                task.defer(function()
                        if running and FlySettings.Enabled then
                                startFlyForCharacter(character)
                        end
                end)
        end
end))

track(UserInputService.JumpRequest:Connect(function()
        if not running
                or not MovementSettings.InfiniteJump
                or UserInputService:GetFocusedTextBox() then
                return
        end

        local humanoid = MovementSettings.Humanoid

        if humanoid
                and humanoid.Parent
                and humanoid.Health > 0
                and humanoid:GetState() ~= Enum.HumanoidStateType.Seated then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
end))

track(UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if PlatformSettings.Enabled
                and not UserInputService:GetFocusedTextBox() then
                if input.KeyCode == Enum.KeyCode.E then
                        PlatformSettings.UpHeld = true
                        return
                end

                if input.KeyCode == Enum.KeyCode.Q then
                        PlatformSettings.DownHeld = true
                        return
                end

                if input.KeyCode == Enum.KeyCode.LeftShift
                        or input.KeyCode == Enum.KeyCode.RightShift then
                        PlatformSettings.ForwardHeld = true
                        return
                end
        end

        if input.KeyCode == Enum.KeyCode.K
                and not UserInputService:GetFocusedTextBox() then
                Window:Toggle()
                return
        end

        if input.KeyCode == Enum.KeyCode.E
                and not UserInputService:GetFocusedTextBox() then
                boostVehicleSpeed()
                return
        end

        if gameProcessedEvent or UserInputService:GetFocusedTextBox() then
                return
        end

        if input.KeyCode == Enum.KeyCode.J then
                jumpVehicle()
                return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
                beginAimlock()
        end
end))

track(UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then
                PlatformSettings.UpHeld = false
                return
        end

        if input.KeyCode == Enum.KeyCode.Q then
                PlatformSettings.DownHeld = false
                return
        end

        if input.KeyCode == Enum.KeyCode.LeftShift
                or input.KeyCode == Enum.KeyCode.RightShift then
                PlatformSettings.ForwardHeld = false
                return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
                endAimlock()
        end
end))

track(Mouse.Button1Down:Connect(function()
        if not running or UserInputService:GetFocusedTextBox() then
                return
        end

        if PartRingSettings.TargetPickerEnabled then
                return
        end

        local position = UserInputService:GetMouseLocation()
        local overInterface = false
        local ok, objects = pcall(function()
                return UserInputService:GetGuiObjectsAtPosition(position.X, position.Y)
        end)

        if ok and objects and Window and Window.Gui then
                for _, object in ipairs(objects) do
                        if object:IsDescendantOf(Window.Gui)
                                or (Reborn._toastGui and object:IsDescendantOf(Reborn._toastGui)) then
                                overInterface = true
                                break
                        end
                end
        end

        if overInterface then
                return
        end

        if canVehicleTeleport() then
                teleportVehicleToMouse(position)
                return
        end

        teleportCharacterToMouse(position)
end))

pcall(function()
        RunService:UnbindFromRenderStep(AIMLOCK_BIND_NAME)
end)

RunService:BindToRenderStep(AIMLOCK_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, updateAimlockCamera)

track(Players.PlayerRemoving:Connect(function(player)
        removeESP(player.Character)
end))

local elapsed = 0
track(RunService.Heartbeat:Connect(function(deltaTime)
        if not running or not Settings.Enabled then
                return
        end

        elapsed = elapsed + deltaTime
        if elapsed < 0.1 then
                return
        end

        elapsed = 0
        refreshAll()
end))

track(Window.Gui.Destroying:Connect(cleanup))

updateAimStatus()
