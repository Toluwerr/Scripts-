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
        Mover = nil,
        RespawnConnection = nil,
        NoclipConnection = nil,
        BurstConnection = nil,
        DensitySaved = setmetatable({}, { __mode = "k" }),
        LastTouchAt = 0,
        CooldownUntil = 0,
        AntiFling = false,
        AntiFlingConnections = {},
        StripStates = setmetatable({}, { __mode = "k" }),
        StripCaches = setmetatable({}, { __mode = "k" }),
        SafeRoot = nil,
        SafeCFrame = nil,
        SafeVelocity = nil
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

local VehicleSpeedBoostSettings = {
        Power = 160,
        Cooldown = 0.65,
        Duration = 0.42,
        LastBoost = 0,
        ActiveUntil = 0
}

local ObjectHoldSettings = {
        Enabled = false,
        Responsiveness = 35,
        Root = nil,
        Rig = nil,
        HoveredRoot = nil,
        PickerRoot = nil,
        PickerHighlights = {},
        HoldHighlights = {},
        HoldGlowParts = {},
        HeldParts = nil,
        HoldBottomOffset = nil,
        PickerConnection = nil,
        InputConnection = nil,
        HeartbeatConnection = nil,
        FollowVelocity = nil,
        LastHeadPosition = nil,
        NextGlowRefresh = 0,
        NextPickerRun = 0,
        HoldBrokenSince = nil,
        NextClaimAt = 0,
        NextWakeNudge = 0,
        WakeToggle = false,
        ArrivingShown = false,
        ClickConsumedAt = 0,
        LastStatus = nil,
        ErrorCount = 0
}

local ObjectHold = {}

local ObjectPullSettings = {
        Enabled = false,
        KeepDistance = 7,
        SimBoost = false,
        Connection = nil,
        LastStatus = nil,
        NextEnvAt = 0,
        NextPassAt = 0
}

local ObjectPull = {}

local ShakerSettings = {
        Enabled = false,
        SimBoost = false,
        Connection = nil,
        LastStatus = nil,
        NextEnvAt = 0,
        NextScanAt = 0
}

local Shaker = {}

local VehicleStorm = {
        Settings = {
                Enabled = false,
                Mode = 1,
                SimBoost = false,
                Connection = nil,
                LastStatus = nil,
                NextEnvAt = 0,
                NextScanAt = 0
        }
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

-- Fling: a touch fling rebuilt from the pattern working fling
-- scripts actually ship. While it is on, three protections make us
-- the immovable one. Our parts get near-infinite density, so the
-- contact reaction on us rounds to zero. Our collisions are also
-- stripped locally every Stepped - a CanCollide write is local
-- only, so every other client still sees us solid and resolves the
-- contact on their side (that is the half that flings THEM), while
-- our own client never resolves it at all (that is the half that
-- stops us flinging OURSELVES). And our velocities are zeroed the
-- moment a burst ends. The spin itself is a BodyAngularVelocity
-- mover enforced by the solver every step, but it only exists while
-- someone is actually in touch range - no idle spinning - so we
-- whirl for a fraction of a second per contact and stand still the
-- rest of the time while they get launched.
local FLING_SPIN_PER_POWER = 100
local FLING_TOUCH_RANGE = 9
local FLING_BURST_CAP = 1
local FLING_COOLDOWN = 0.35
local FLING_PHYSICS = PhysicalProperties.new(math.huge, 0.3, 0.5)

local function getFlingSpin()
        return math.clamp(tonumber(FlingSettings.Power) or 100, 1, 1000)
                * FLING_SPIN_PER_POWER
end

local function applyFlingCharacterSetup(character)
        local root = getRoot(character)

        if not root or not root.Parent then
                return
        end

        -- Near-infinite density on every part of us: contact impulses
        -- land on everyone else and the reaction on us approaches
        -- nothing. The original properties are remembered so disable
        -- puts everything back exactly as it was.
        for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                        if FlingSettings.DensitySaved[part] == nil then
                                FlingSettings.DensitySaved[part] = {
                                        physics = part.CustomPhysicalProperties or false,
                                        canCollide = part.CanCollide
                                }
                        end

                        pcall(function()
                                part.CustomPhysicalProperties = FLING_PHYSICS
                        end)
                end
        end

        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
                pcall(function()
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end)
        end
end

local function createFlingMover(root)
        local mover = Instance.new("BodyAngularVelocity")
        mover.Name = "FlingSpin"
        mover.AngularVelocity = Vector3.new(0, getFlingSpin(), 0)
        mover.MaxTorque = Vector3.new(0, math.huge, 0)
        mover.P = 1e9
        mover.Parent = root
        FlingSettings.Mover = mover
end

local function destroyFlingMover()
        local mover = FlingSettings.Mover
        FlingSettings.Mover = nil

        if mover then
                pcall(function()
                        mover:Destroy()
                end)
        end

        local root = getRoot(LocalPlayer.Character)

        if root and root.Parent then
                pcall(function()
                        root.AssemblyAngularVelocity = Vector3.zero
                        root.AssemblyLinearVelocity = Vector3.zero
                end)
        end
end

local function findFlingTouch(root)
        local position = root.Position
        local rangeSq = FLING_TOUCH_RANGE * FLING_TOUCH_RANGE

        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                        local target = getRoot(player.Character)

                        if target and target.Parent then
                                local offset = target.Position - position

                                if offset:Dot(offset) <= rangeSq then
                                        return true
                                end
                        end
                end
        end

        return false
end

local function stopFling()
        FlingSettings.Enabled = false
        disconnect(FlingSettings.RespawnConnection)
        FlingSettings.RespawnConnection = nil
        disconnect(FlingSettings.NoclipConnection)
        FlingSettings.NoclipConnection = nil
        disconnect(FlingSettings.BurstConnection)
        FlingSettings.BurstConnection = nil

        destroyFlingMover()

        for part, saved in pairs(FlingSettings.DensitySaved) do
                if part and part.Parent then
                        pcall(function()
                                part.CustomPhysicalProperties =
                                        saved.physics == false and nil or saved.physics
                                part.CanCollide = saved.canCollide
                        end)
                end
        end

        table.clear(FlingSettings.DensitySaved)

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
                pcall(function()
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                end)
        end
end

local function startFling()
        stopFling()
        FlingSettings.Enabled = true
        FlingSettings.LastTouchAt = 0
        FlingSettings.CooldownUntil = 0
        applyFlingCharacterSetup(LocalPlayer.Character)

        FlingSettings.RespawnConnection = LocalPlayer.CharacterAdded:Connect(
                function(character)
                        if not FlingSettings.Enabled then
                                return
                        end

                        local root = character:WaitForChild("HumanoidRootPart", 10)

                        if root and root.Parent then
                                applyFlingCharacterSetup(character)
                        end
                end
        )

        -- The local collision strip. Re-applied every physics step
        -- because the humanoid re-enables collisions on its own every
        -- frame; without the loop the protection lasts one step.
        FlingSettings.NoclipConnection = RunService.Stepped:Connect(function()
                local character = LocalPlayer.Character

                if not character or not character.Parent then
                        return
                end

                for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                                pcall(function()
                                        part.CanCollide = false
                                end)
                        end
                end
        end
        )

        -- Burst driver: spin only while someone is touching us. They
        -- leave - usually because they just got launched - and the
        -- mover comes straight off with our velocities zeroed, so we
        -- never drift and never self-fling. Continuous contact is
        -- capped and cycled so a hug cannot pin the spin on forever.
        FlingSettings.BurstConnection = RunService.Heartbeat:Connect(function()
                if not FlingSettings.Enabled then
                        return
                end

                local root = getRoot(LocalPlayer.Character)

                if not root or not root.Parent then
                        return
                end

                local now = os.clock()
                local touching = findFlingTouch(root)

                if touching then
                        FlingSettings.LastTouchAt = now
                end

                if touching and now >= (FlingSettings.CooldownUntil or 0) then
                        if not FlingSettings.Mover then
                                createFlingMover(root)
                        end
                elseif FlingSettings.Mover
                        and (not touching
                                or now - (FlingSettings.LastTouchAt or 0) >= FLING_BURST_CAP) then
                        destroyFlingMover()
                        FlingSettings.CooldownUntil = now + FLING_COOLDOWN
                end
        end
        )
end

local function setFlingEnabled(value)
        if value then
                startFling()
        else
                stopFling()
        end
end

-- Anti Fling: two layers. The structural one is what working
-- scripts ship: a fling is a physics contact, and a contact needs
-- two collidable sides, so every other player's character parts
-- get CanCollide stripped locally at 20 Hz - a local write that
-- does not replicate, so they still collide normally with the
-- world and each other, but their spin can never resolve a contact
-- against us on our client, and only owners resolve contacts on
-- their own assembly. Nothing to resolve, nothing to fling us.
-- The watchdog layer stays underneath for everything that is not a
-- player contact - disaster physics, NaN exploits, loose debris:
-- we always own our own character, so any fling aimed at us ends
-- up as a sudden huge jump in root velocity or spin between two
-- frames, and legit motion (walking, falling, our Fly) never jumps
-- like that. Snap the root back to the last safe pose; because we
-- own the assembly the correction replicates and nobody sees us
-- move. The spin check is skipped while our own Fling is running,
-- since our spin mover would trip it - enemy spin flings still
-- shove us linearly, and that half of the watchdog keeps working.
local ANTI_FLING_SPEED_JUMP = 300
local ANTI_FLING_SPIN = 250
local ANTI_FLING_SWEEP = 3

local function disableAntiFling()
        FlingSettings.AntiFling = false
        disconnectAntiFlingConnections()

        for part, originalCanCollide in pairs(FlingSettings.StripStates) do
                if part and part.Parent then
                        pcall(function()
                                part.CanCollide = originalCanCollide
                        end)
                end
        end

        table.clear(FlingSettings.StripStates)
        table.clear(FlingSettings.StripCaches)

        FlingSettings.SafeRoot = nil
        FlingSettings.SafeCFrame = nil
        FlingSettings.SafeVelocity = nil
end

local function enableAntiFling()
        disableAntiFling()
        FlingSettings.AntiFling = true

        table.insert(FlingSettings.AntiFlingConnections, RunService.Heartbeat:Connect(function()
                if not FlingSettings.AntiFling then
                        return
                end

                local character = LocalPlayer.Character
                local root = getRoot(character)

                if not root or not root.Parent then
                        return
                end

                local velocity = root.AssemblyLinearVelocity
                local spin = root.AssemblyAngularVelocity.Magnitude
                local nan = velocity.X ~= velocity.X
                        or velocity.Y ~= velocity.Y
                        or velocity.Z ~= velocity.Z

                if root ~= FlingSettings.SafeRoot then
                        -- fresh or respawned character: re-baseline
                        FlingSettings.SafeRoot = root
                        FlingSettings.SafeCFrame = root.CFrame
                        FlingSettings.SafeVelocity = velocity
                        return
                end

                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local seated = humanoid ~= nil and humanoid.SeatPart ~= nil

                if not seated
                        and (nan
                                or (velocity - FlingSettings.SafeVelocity).Magnitude > ANTI_FLING_SPEED_JUMP
                                or (not FlingSettings.Enabled
                                        and (spin > ANTI_FLING_SPIN or spin ~= spin))) then
                        root.CFrame = FlingSettings.SafeCFrame
                        root.AssemblyLinearVelocity = FlingSettings.SafeVelocity
                        root.AssemblyAngularVelocity = Vector3.zero

                        if humanoid then
                                pcall(function()
                                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                                end)
                        end
                else
                        FlingSettings.SafeCFrame = root.CFrame
                        FlingSettings.SafeVelocity = velocity
                end
        end))

        -- Structural shield: strip collisions off every other
        -- player's character locally. 20 Hz is plenty - the server
        -- does not re-enable them every frame. Caches are weak and
        -- per character, a DescendantAdded hook catches parts that
        -- stream in later (accessories), and the strip only ever
        -- remembers parts that were collidable when found, so
        -- disable restores exactly what was taken.
        local sweep = 0

        table.insert(FlingSettings.AntiFlingConnections, RunService.Stepped:Connect(function()
                if not FlingSettings.AntiFling then
                        return
                end

                sweep += 1

                if sweep % ANTI_FLING_SWEEP ~= 0 then
                        return
                end

                for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                                local character = player.Character

                                if character and character.Parent then
                                        local cache = FlingSettings.StripCaches[character]

                                        if not cache then
                                                cache = { parts = {} }

                                                for _, part in ipairs(character:GetDescendants()) do
                                                        if part:IsA("BasePart") then
                                                                table.insert(cache.parts, part)
                                                        end
                                                end

                                                local connection = character.DescendantAdded:Connect(
                                                        function(descendant)
                                                                if descendant:IsA("BasePart") then
                                                                        table.insert(cache.parts, descendant)
                                                                end
                                                        end
                                                )

                                                table.insert(FlingSettings.AntiFlingConnections, connection)
                                                FlingSettings.StripCaches[character] = cache
                                        end

                                        for index = #cache.parts, 1, -1 do
                                                local part = cache.parts[index]

                                                if not part or not part.Parent then
                                                        table.remove(cache.parts, index)
                                                elseif part.CanCollide then
                                                        if FlingSettings.StripStates[part] == nil then
                                                                FlingSettings.StripStates[part] = true
                                                        end

                                                        pcall(function()
                                                                part.CanCollide = false
                                                        end)
                                                end
                                        end
                                end
                        end
                end
        end))
end

local function setAntiFlingEnabled(value)
        if value then
                enableAntiFling()
        else
                disableAntiFling()
        end
end

do
        -- ============================================================
        -- Object Hover: real-physics hold built on AlignPosition and
        -- AlignOrientation mover constraints - the modern successors
        -- to the deprecated BodyPosition/BodyGyro movers.
        --
        -- How it works: grabbing an assembly attaches a small local
        -- rig to its root part - one Attachment, one AlignPosition in
        -- OneAttachment mode chasing a goal position above the head,
        -- and one AlignOrientation holding the object level. The
        -- constraints apply continuous force and the physics solver
        -- integrates it: nothing is teleported, no velocity is
        -- snapped, no CFrame is ever written. The object collides
        -- with the world, supports riders (MaxForce is unlimited, so
        -- added weight simply produces added counter-force), snags
        -- and slides against geometry like real matter, and keeps
        -- its momentum as a genuine toss on release.
        --
        -- Replication: per the official Network Ownership docs, the
        -- engine automatically hands simulation of unanchored parts
        -- near a player's character to that player's client, and a
        -- client-owned assembly's simulated physics replicates to
        -- the server and every other player. The slot floats right
        -- above the holder's head, so ownership - and therefore
        -- replication - is the steady state. A server-owned grab
        -- from far away simply becomes client-owned as the object
        -- approaches, and the hold continues seamlessly.
        -- ============================================================

        local function updateHoldStatus(text)
                local message = tostring(text or "Object Hover off")

                if ObjectHoldSettings.LastStatus == message then
                        return
                end

                ObjectHoldSettings.LastStatus = message

                if type(ObjectHold.OnStatusChanged) == "function" then
                        pcall(ObjectHold.OnStatusChanged, message)
                end
        end

        local function hasHoldBlockedAncestor(instance)
                local current = instance

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

        local function isHoldableRoot(root)
                if not root
                        or not root:IsA("BasePart")
                        or not root.Parent
                        or root.Anchored
                        or root:IsA("Seat")
                        or root:IsA("VehicleSeat")
                        or root.AssemblyRootPart ~= root then
                        return false
                end

                if LocalPlayer.Character
                        and root:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and root:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                if hasHoldBlockedAncestor(root) then
                        return false
                end

                return true
        end

        local function getHoldAssemblyParts(root)
                local parts = { root }
                local seen = { [root] = true }

                pcall(function()
                        for _, part in ipairs(root:GetConnectedParts(true)) do
                                if part:IsA("BasePart")
                                        and part.Parent
                                        and not seen[part] then
                                        seen[part] = true
                                        table.insert(parts, part)
                                end
                        end
                end)

                return parts
        end

        -- Cap well under the engine's 31-live-Highlight rendering
        -- limit (hold glow + picker glow together): going over it
        -- makes highlights drop out and churns render cost.
        local MAX_GLOW_PARTS = 8

        local function clearGlowList(list)
                for index = #list, 1, -1 do
                        local highlight = list[index]
                        list[index] = nil

                        if highlight then
                                pcall(function()
                                        highlight:Destroy()
                                end)
                        end
                end
        end

        local function glowAssembly(
                root,
                list,
                name,
                fillColor,
                outlineColor,
                fillTransparency,
                depthMode
        )
                clearGlowList(list)

                local parts = getHoldAssemblyParts(root)
                local count = math.min(#parts, MAX_GLOW_PARTS)

                for index = 1, count do
                        local highlight = Instance.new("Highlight")
                        highlight.Name = name
                        highlight.Adornee = parts[index]
                        highlight.DepthMode = depthMode
                                or Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.FillColor = fillColor
                        highlight.FillTransparency = fillTransparency
                        highlight.OutlineColor = outlineColor
                        highlight.OutlineTransparency = 0.05
                        highlight.Parent = Workspace
                        list[index] = highlight
                end
        end

        local function glowPartsMatch(cached, parts, count)
                if #cached ~= count then
                        return false
                end

                for index = 1, count do
                        if cached[index] ~= parts[index] then
                                return false
                        end
                end

                return true
        end

        -- Rebuild the hold glow only when the assembly's part set
        -- actually changed: steady state costs zero instance churn,
        -- which is what keeps the framerate healthy on long holds.
        local function refreshHoldGlow(root)
                local parts = getHoldAssemblyParts(root)
                local count = math.min(#parts, MAX_GLOW_PARTS)
                local cached = ObjectHoldSettings.HoldGlowParts

                ObjectHoldSettings.HeldParts = parts

                -- Vertical offset from the root part's center down
                -- to the assembly's lowest point (negative or zero).
                -- The auto slot in updateObjectHold uses it to park
                -- the object's bottom edge, not its center, a fixed
                -- clearance above the head. Axis-aligned sizes are
                -- accurate here because the hold keeps the assembly
                -- level. Runs on the slow tick, never per frame.
                local lowest = -(root.Size.Y / 2)
                local scanned = 0

                for _, part in ipairs(parts) do
                        scanned += 1

                        if scanned > 2000 then
                                break
                        end

                        local offset = part.Position.Y
                                - root.Position.Y
                                - part.Size.Y / 2

                        if offset == offset and offset < lowest then
                                lowest = offset
                        end
                end

                ObjectHoldSettings.HoldBottomOffset = lowest

                if glowPartsMatch(cached, parts, count) then
                        return
                end

                glowAssembly(
                        root,
                        ObjectHoldSettings.HoldHighlights,
                        "__PlayerToolsHoldGlow",
                        Color3.fromRGB(64, 170, 255),
                        Color3.fromRGB(140, 210, 255),
                        0.78,
                        Enum.HighlightDepthMode.Occluded
                )

                table.clear(cached)

                for index = 1, count do
                        cached[index] = parts[index]
                end
        end

        local function castForHoldTarget(includeHeld)
                local camera = Workspace.CurrentCamera

                if not camera then
                        return nil
                end

                local mouseLocation = UserInputService:GetMouseLocation()
                local unitRay = camera:ScreenPointToRay(
                        mouseLocation.X,
                        mouseLocation.Y
                )
                local filter = {}

                if LocalPlayer.Character then
                        table.insert(filter, LocalPlayer.Character)
                end

                local held = ObjectHoldSettings.Root

                if held and held.Parent and not includeHeld then
                        table.insert(filter, held)

                        -- Cached at grab time and refreshed on the
                        -- slow glow tick: walking GetConnectedParts on
                        -- a big held assembly every frame was a real
                        -- framerate killer.
                        local heldParts = ObjectHoldSettings.HeldParts

                        if heldParts then
                                for _, connected in ipairs(heldParts) do
                                        if connected ~= held
                                                and connected.Parent then
                                                table.insert(filter, connected)
                                        end
                                end
                        end
                end

                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = filter
                params.IgnoreWater = false

                local direction = unitRay.Direction * 10000

                -- Cast through anything that can never be picked: a
                -- player standing on the liftable object eats the first
                -- hit, so each dead end joins the filter and the ray
                -- continues behind it.
                for _ = 1, 6 do
                        local result = Workspace:Raycast(
                                unitRay.Origin,
                                direction,
                                params
                        )
                        local part = result and result.Instance

                        if not part or not part:IsA("BasePart") then
                                return nil
                        end

                        local root = part.AssemblyRootPart

                        if root == ObjectHoldSettings.Root then
                                return includeHeld and root or nil
                        end

                        if isHoldableRoot(root) then
                                return root
                        end

                        pcall(function()
                                table.insert(filter, root or part)

                                if root and root.Parent then
                                        for _, connected in ipairs(root:GetConnectedParts(true)) do
                                                if connected.Parent then
                                                        table.insert(filter, connected)
                                                end
                                        end
                                end
                        end)

                        params.FilterDescendantsInstances = filter
                end

                return nil
        end

        local function computeLevelHoldCFrame(root)
                local look = root.CFrame.LookVector
                local horizontal = Vector3.new(look.X, 0, look.Z)

                if horizontal.Magnitude < 0.05 then
                        return CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
                end

                return CFrame.lookAt(Vector3.zero, horizontal.Unit)
        end

        local function buildHoldRig(root, holdCFrame)
                local attachment = Instance.new("Attachment")
                attachment.Name = "__PlayerToolsHoldAttachment"
                attachment.Parent = root

                local alignPosition = Instance.new("AlignPosition")
                alignPosition.Name = "__PlayerToolsHoldPosition"
                alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
                alignPosition.Attachment0 = attachment
                alignPosition.ApplyAtCenterOfMass = true
                alignPosition.MaxForce = math.huge
                -- Bounded start value; updateObjectHold retunes it
                -- every frame from the player's live speed. An
                -- uncapped servo (math.huge) corrects any
                -- displacement at unlimited speed - a rider landing
                -- on the object became a launcher. A fixed low cap
                -- trails behind at high speed. The live retune does
                -- neither.
                alignPosition.MaxVelocity = 200
                alignPosition.Responsiveness = math.clamp(
                        tonumber(ObjectHoldSettings.Responsiveness) or 35,
                        5,
                        100
                )
                alignPosition.RigidityEnabled = false
                alignPosition.Position = root.Position
                alignPosition.Parent = root

                local alignOrientation = Instance.new("AlignOrientation")
                alignOrientation.Name = "__PlayerToolsHoldOrientation"
                alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
                alignOrientation.Attachment0 = attachment
                alignOrientation.MaxTorque = math.huge
                alignOrientation.Responsiveness = 25
                alignOrientation.RigidityEnabled = false
                alignOrientation.CFrame = holdCFrame
                alignOrientation.Parent = root

                return {
                        Attachment = attachment,
                        AlignPosition = alignPosition,
                        AlignOrientation = alignOrientation
                }
        end

        local function destroyHoldRig()
                local rig = ObjectHoldSettings.Rig
                ObjectHoldSettings.Rig = nil

                if not rig then
                        return
                end

                for _, object in ipairs({
                        rig.AlignPosition,
                        rig.AlignOrientation,
                        rig.Attachment
                }) do
                        if object then
                                pcall(function()
                                        object:Destroy()
                                end)
                        end
                end
        end

        local function releaseObject(message)
                destroyHoldRig()

                ObjectHoldSettings.Root = nil
                ObjectHoldSettings.ErrorCount = 0
                ObjectHoldSettings.NextGlowRefresh = 0
                ObjectHoldSettings.HoldBrokenSince = nil
                ObjectHoldSettings.NextClaimAt = 0
                ObjectHoldSettings.NextWakeNudge = 0
                ObjectHoldSettings.WakeToggle = false
                ObjectHoldSettings.ArrivingShown = false
                ObjectHoldSettings.HeldParts = nil
                ObjectHoldSettings.HoldBottomOffset = nil

                table.clear(ObjectHoldSettings.HoldGlowParts)

                clearGlowList(ObjectHoldSettings.HoldHighlights)
                updateHoldStatus(message or "Released - click an object")
        end

        -- Best-effort ownership claim. Claiming every physics step
        -- (the previous attempt) started a war with the server's
        -- auto-assignment: whenever a rider stood on the object,
        -- simulation ping-ponged between machines every step and the
        -- whole thing stuttered. The calm contract instead: claim
        -- once on grab, and afterwards only when the convergence
        -- watchdog in updateObjectHold sees the hold actually break.
        local function claimHoldOwnership(root)
                pcall(function()
                        root:SetNetworkOwner(LocalPlayer)
                end)

                pcall(function()
                        sethiddenproperty(
                                LocalPlayer,
                                "SimulationRadius",
                                math.huge
                        )
                end)

                pcall(function()
                        setsimulationradius(math.huge, math.huge)
                end)
        end

        local function grabObject(root)
                releaseObject()

                ObjectHoldSettings.Root = root
                ObjectHoldSettings.ErrorCount = 0
                ObjectHoldSettings.Rig = buildHoldRig(
                        root,
                        computeLevelHoldCFrame(root)
                )

                -- Ownership assist: auto-assignment already favors
                -- this client because the slot floats right above
                -- the head; claim directly where the environment
                -- allows it so far-away grabs engage replication
                -- immediately too.
                claimHoldOwnership(root)

                refreshHoldGlow(root)

                updateHoldStatus("Holding: " .. tostring(root.Name):sub(1, 32))
        end

        local function updateObjectHold(stepTime)
                if not running or not ObjectHoldSettings.Enabled then
                        return
                end

                local root = ObjectHoldSettings.Root

                if not root then
                        updateHoldStatus("Enabled - click an object")
                        return
                end

                if not root.Parent
                        or root.Anchored
                        or root.AssemblyRootPart ~= root then
                        releaseObject("Object lost")
                        return
                end

                local character = LocalPlayer.Character
                local head = character and character:FindFirstChild("Head")

                if not head or not head.Parent or not head:IsA("BasePart") then
                        releaseObject("Character unavailable - object dropped")
                        return
                end

                local rig = ObjectHoldSettings.Rig

                if not rig
                        or not rig.AlignPosition
                        or not rig.AlignPosition.Parent then
                        releaseObject("Hold rig lost")
                        return
                end

                local headPosition = head.Position

                -- Speed matching, part one: measure how fast the
                -- character is actually moving from frame-to-frame
                -- head positions. This works the same whether the
                -- player walks, sprints, uses Fly or rides a vehicle
                -- - no matter what moves the character, the measured
                -- velocity is the truth.
                local step = tonumber(stepTime)

                if step and step > 0 and step < 0.5 then
                        local last = ObjectHoldSettings.LastHeadPosition

                        if last then
                                local delta = headPosition - last

                                if delta.Magnitude < 100 then
                                        local instant = delta / step
                                        local smoothed =
                                                ObjectHoldSettings.FollowVelocity

                                        if smoothed then
                                                ObjectHoldSettings.FollowVelocity =
                                                        smoothed:Lerp(instant, 0.35)
                                        else
                                                ObjectHoldSettings.FollowVelocity =
                                                        instant
                                        end
                                else
                                        -- Position jumped (teleport):
                                        -- no honest velocity this frame.
                                        ObjectHoldSettings.FollowVelocity = nil
                                end
                        end
                end

                ObjectHoldSettings.LastHeadPosition = headPosition

                -- Speed matching, part two: a critically damped
                -- AlignPosition trails a moving goal by roughly
                -- 2 * speed / responsiveness studs. Leading the goal
                -- by exactly that cancels the trail at ANY speed, so
                -- the object rides level with the player instead of
                -- perpetually catching up. No slider, no cap - it
                -- just matches whatever speed the player goes.
                local responsiveness = tonumber(rig.AlignPosition.Responsiveness)
                        or 35
                local lead = Vector3.zero
                local velocity = ObjectHoldSettings.FollowVelocity

                if velocity then
                        local leadTime = math.clamp(
                                2 / responsiveness,
                                0.02,
                                0.12
                        )

                        lead = velocity * leadTime

                        if lead.Magnitude > 15 then
                                lead = lead.Unit * 15
                        end
                end

                -- Auto slot - no height setting. Auto ownership
                -- follows proximity, so the slot rides as close to
                -- the player as physics allows. With Noclip on,
                -- character parts are non-collidable and the object
                -- can sit right in the head at zero distance,
                -- unbeatable in the proximity contest. With Noclip
                -- off, the object's bottom edge is parked a fixed
                -- clearance above the head top - the shortest
                -- distance that never snags on the character.
                -- Flips live, so toggling Noclip mid-hold just
                -- glides the object between the two slots.
                local bottomOffset = ObjectHoldSettings.HoldBottomOffset

                if type(bottomOffset) ~= "number"
                        or bottomOffset ~= bottomOffset then
                        bottomOffset = -(root.Size.Y / 2)
                end

                bottomOffset = math.clamp(bottomOffset, -40, 5)

                local slotOffset

                if MovementSettings.Noclip then
                        slotOffset = 0
                else
                        slotOffset = math.clamp(
                                head.Size.Y / 2 + 1 - bottomOffset,
                                1,
                                45
                        )
                end

                local goal = headPosition
                        + Vector3.new(0, slotOffset, 0)
                        + lead

                if goal.X ~= goal.X or goal.Y ~= goal.Y or goal.Z ~= goal.Z then
                        return
                end

                -- The single per-frame order: move the goal the
                -- constraint chases. Force, solver, replication - the
                -- engine does the rest.
                local ok = pcall(function()
                        rig.AlignPosition.Position = goal
                end)

                if not ok then
                        ObjectHoldSettings.ErrorCount += 1

                        if ObjectHoldSettings.ErrorCount >= 30 then
                                releaseObject("Object unwritable - dropped")
                        end

                        return
                end

                ObjectHoldSettings.ErrorCount = 0

                local now = os.clock()
                local distance = (root.Position - goal).Magnitude

                -- Live speed cap, retuned every frame: fast enough
                -- to sit level at full fly speed and to reel in a
                -- far grab, bounded enough that a hard displacement
                -- (a rider landing on the object) glides back to the
                -- slot instead of rocketing through it.
                local followSpeed = velocity and velocity.Magnitude or 0
                local wantedCap = math.clamp(
                        math.max(
                                followSpeed * 2.5 + 60,
                                (distance == distance and distance or 0) * 3
                        ),
                        80,
                        500
                )

                if math.abs(
                        (tonumber(rig.AlignPosition.MaxVelocity) or 0)
                                - wantedCap
                ) >= 2 then
                        pcall(function()
                                rig.AlignPosition.MaxVelocity = wantedCap
                        end)
                end

                -- Convergence watchdog: a hold only "breaks" when the
                -- object sits far off its slot - which is exactly
                -- what losing the ownership fight to a rider or the
                -- server looks like. While broken, re-claim at a
                -- calm 0.4s cadence until the servo wins control
                -- back. While healthy, zero ownership traffic at
                -- all - no war, no stutter.
                if distance == distance and distance > 10 then
                        if not ObjectHoldSettings.HoldBrokenSince then
                                ObjectHoldSettings.HoldBrokenSince = now
                        end

                        if now - ObjectHoldSettings.HoldBrokenSince > 0.6
                                and now >= (ObjectHoldSettings.NextClaimAt or 0) then
                                ObjectHoldSettings.NextClaimAt = now + 0.4
                                claimHoldOwnership(root)
                        end
                else
                        ObjectHoldSettings.HoldBrokenSince = nil
                end

                -- Anti-sleep, minimal edition: an assembly hovering
                -- in perfect equilibrium can be put to sleep by the
                -- engine, freezing replication for everyone else.
                -- Only a real physics touch keeps an assembly
                -- simulated, so nudge with a negligible alternating
                -- velocity - but only while the object is actually
                -- near-still, so flying in and carrying riders are
                -- never touched.
                if now >= (ObjectHoldSettings.NextWakeNudge or 0) then
                        ObjectHoldSettings.NextWakeNudge = now + 0.4
                        ObjectHoldSettings.WakeToggle =
                                not ObjectHoldSettings.WakeToggle

                        local currentVelocity = root.AssemblyLinearVelocity

                        if currentVelocity.Magnitude < 0.05 then
                                local nudge = ObjectHoldSettings.WakeToggle
                                        and Vector3.new(0, 0.01, 0)
                                        or Vector3.new(0, -0.01, 0)

                                pcall(function()
                                        root.AssemblyLinearVelocity =
                                                currentVelocity + nudge
                                end)
                        end
                end

                if now >= (ObjectHoldSettings.NextGlowRefresh or 0) then
                        ObjectHoldSettings.NextGlowRefresh = now + 1.25
                        refreshHoldGlow(root)
                end

                if distance == distance then
                        local arriving = ObjectHoldSettings.ArrivingShown

                        if arriving then
                                if distance < 5 then
                                        arriving = false
                                end
                        elseif distance > 10 then
                                arriving = true
                        end

                        ObjectHoldSettings.ArrivingShown = arriving
                end

                if ObjectHoldSettings.ArrivingShown then
                        updateHoldStatus(
                                "Holding: "
                                        .. tostring(root.Name):sub(1, 32)
                                        .. " (arriving)"
                        )
                else
                        updateHoldStatus(
                                "Holding: " .. tostring(root.Name):sub(1, 32)
                        )
                end
        end

        local function updateHoldPicker()
                if not running or not ObjectHoldSettings.Enabled then
                        return
                end

                local root = castForHoldTarget(false)
                ObjectHoldSettings.HoveredRoot = root

                if root then
                        if ObjectHoldSettings.PickerRoot ~= root then
                                ObjectHoldSettings.PickerRoot = root
                                glowAssembly(
                                        root,
                                        ObjectHoldSettings.PickerHighlights,
                                        "__PlayerToolsHoldPick",
                                        Color3.fromRGB(64, 205, 98),
                                        Color3.fromRGB(120, 255, 160),
                                        0.72,
                                        Enum.HighlightDepthMode.AlwaysOnTop
                                )
                        end
                else
                        ObjectHoldSettings.PickerRoot = nil
                        clearGlowList(ObjectHoldSettings.PickerHighlights)
                end
        end

        local function isPointerOverInterface()
                local position = UserInputService:GetMouseLocation()
                local ok, objects = pcall(function()
                        return UserInputService:GetGuiObjectsAtPosition(
                                position.X,
                                position.Y
                        )
                end)

                if ok and objects and Window and Window.Gui then
                        for _, object in ipairs(objects) do
                                if object:IsDescendantOf(Window.Gui)
                                        or (Reborn._toastGui
                                                and object:IsDescendantOf(Reborn._toastGui)) then
                                        return true
                                end
                        end
                end

                return false
        end

        local function onHoldInput(input, gameProcessedEvent)
                if gameProcessedEvent
                        or not running
                        or not ObjectHoldSettings.Enabled
                        or UserInputService:GetFocusedTextBox() then
                        return
                end

                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end

                if isPointerOverInterface() then
                        return
                end

                local held = ObjectHoldSettings.Root

                if held and held.Parent then
                        -- Clicking the held object itself drops it; the
                        -- cast must include the held assembly to see it.
                        local clicked = castForHoldTarget(true)

                        if clicked == held then
                                ObjectHoldSettings.ClickConsumedAt = os.clock()
                                releaseObject("Dropped - click an object")
                                return
                        end
                end

                local root = ObjectHoldSettings.HoveredRoot
                        or castForHoldTarget(false)

                if root
                        and root ~= ObjectHoldSettings.Root
                        and isHoldableRoot(root) then
                        ObjectHoldSettings.ClickConsumedAt = os.clock()
                        grabObject(root)
                end
        end

        local function stopObjectHold()
                disconnect(ObjectHoldSettings.PickerConnection)
                ObjectHoldSettings.PickerConnection = nil
                disconnect(ObjectHoldSettings.InputConnection)
                ObjectHoldSettings.InputConnection = nil
                disconnect(ObjectHoldSettings.HeartbeatConnection)
                ObjectHoldSettings.HeartbeatConnection = nil

                releaseObject("Object Hover off")
                clearGlowList(ObjectHoldSettings.PickerHighlights)

                ObjectHoldSettings.HoveredRoot = nil
                ObjectHoldSettings.PickerRoot = nil
                ObjectHoldSettings.ErrorCount = 0
                ObjectHoldSettings.FollowVelocity = nil
                ObjectHoldSettings.LastHeadPosition = nil
                ObjectHoldSettings.HoldBrokenSince = nil
                ObjectHoldSettings.NextClaimAt = 0
                ObjectHoldSettings.NextWakeNudge = 0
                ObjectHoldSettings.WakeToggle = false
                ObjectHoldSettings.NextPickerRun = 0
        end

        ObjectHold.release = function()
                if not ObjectHoldSettings.Enabled then
                        return
                end

                releaseObject("Released - click an object")
        end

        ObjectHold.setEnabled = function(value)
                local enabled = value and true or false

                stopObjectHold()
                ObjectHoldSettings.Enabled = enabled

                if type(ObjectHold.OnEnabledChanged) == "function" then
                        pcall(ObjectHold.OnEnabledChanged, enabled)
                end

                if not enabled then
                        return
                end

                updateHoldStatus("Enabled - click an object")

                ObjectHoldSettings.PickerConnection = RunService.RenderStepped:Connect(
                        function()
                                -- 20 Hz is plenty for a hover glow;
                                -- six raycasts every single frame was
                                -- real per-frame cost.
                                if os.clock()
                                        < (ObjectHoldSettings.NextPickerRun or 0) then
                                        return
                                end

                                ObjectHoldSettings.NextPickerRun = os.clock() + 0.05

                                local ok, err = pcall(updateHoldPicker)

                                if not ok then
                                        updateHoldStatus(
                                                "Picker error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )

                ObjectHoldSettings.InputConnection = UserInputService.InputBegan:Connect(
                        function(input, gameProcessedEvent)
                                local ok, err = pcall(
                                        onHoldInput,
                                        input,
                                        gameProcessedEvent
                                )

                                if not ok then
                                        updateHoldStatus(
                                                "Input error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )

                ObjectHoldSettings.HeartbeatConnection = RunService.Heartbeat:Connect(
                        function(deltaTime)
                                local ok, err = pcall(updateObjectHold, deltaTime)

                                if not ok then
                                        updateHoldStatus(
                                                "Engine error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )
        end
end

-- ============================================================
-- Object Pull: rebuilt from five working sources - the Project
-- Gravity engine (the NDS blackhole script), Bring Loose Parts
-- (open source), the classic telekinesis holds, the tornado
-- windfields, and the devforum thread that documented the
-- client side ownership check.
--
-- Claiming stays the simulation radius war: our own radius is
-- re-asserted every single frame and everyone else's gets
-- pinned to zero twice a second, so debris all over the island
-- arbitrates to our client and what we do to it becomes real
-- replicated physics. The movement itself is now the puppet
-- pattern the working bring-parts scripts use: each claimed
-- assembly gets a tiny invisible anchored target part plus an
-- AlignPosition and AlignOrientation with unlimited force, and
-- the pull just moves the target. The engine's own constraint
-- solver then accelerates, brakes, fights gravity and holds the
-- ring on every physics substep - which per-frame velocity
-- writes (the old version) can never do, and why the old ring
-- bobbed and sagged. A constraint on an assembly we do not
-- simulate does nothing at all, so there is no fake client-only
-- dragging either. Anchored parts are no longer touched at all:
-- an anchored part is server-static, no client can ever move it
-- for real, so the old seizure was client-side theatre. Only
-- genuinely unanchored assemblies are claimed, and ReceiveAge -
-- zero means the assembly is genuinely ours, the
-- devforum-verified check - reports how much of the swarm is
-- really held. The old radius query
-- silently truncated at 8192 parts and missed most of a busy
-- NDS island, so a throttled full-workspace walk now claims
-- everything, and debris that appears mid-disaster is picked up
-- by the next pass. Small velocity pokes keep assemblies from
-- dozing off mid-flight.
-- ============================================================
do
        local ENV_INTERVAL = 0.5
        local SCAN_RADIUS = 1000
        local PASS_INTERVAL = 1.5
        local WALK_INSTANCES = 2000
        local WALK_SECONDS = 0.002
        local POKE_INTERVAL = 3
        local ALIGN_RESPONSIVENESS = 200
        local ALIGN_MAX_VELOCITY = 800
        local ANTI_SLEEP = Vector3.new(0.5, 0.5, 0.5)
        local MAX_DIMENSION = 120
        local DEFAULT_KEEP = 7
        local MIN_KEEP = 3
        local MAX_KEEP = 50
        local SIM_RADIUS = 9e9
        local LIGHT_PHYSICS = PhysicalProperties.new(0.001, 0, 0, 0, 0)

        local EXCLUDED_NAMES = {
                Terrain = true,
                Baseplate = true,
                HumanoidRootPart = true,
                Handle = true,
                ["__PlayerToolsPlatform"] = true,
                ["__ObjectShakerTarget"] = true
        }

        local claimedRoots = setmetatable({}, { __mode = "k" })
        local claimedParts = setmetatable({}, { __mode = "k" })
        local envOriginals = setmetatable({}, { __mode = "k" })
        local allowSleepSaved = nil
        local pullFolder = nil
        local walkStack = {}
        local walkSeen = setmetatable({}, { __mode = "k" })
        local frameTick = 0

        local function updatePullStatus(text)
                local message = tostring(text or "Object Pull off")

                if ObjectPullSettings.LastStatus == message then
                        return
                end

                ObjectPullSettings.LastStatus = message

                if type(ObjectPull.OnStatusChanged) == "function" then
                        pcall(ObjectPull.OnStatusChanged, message)
                end
        end

        local function getKeepDistance()
                return math.clamp(
                        tonumber(ObjectPullSettings.KeepDistance) or DEFAULT_KEEP,
                        MIN_KEEP,
                        MAX_KEEP
                )
        end

        local function pullReadProperty(object, key, hidden)
                if hidden and type(gethiddenproperty) == "function" then
                        local ok, value = pcall(gethiddenproperty, object, key)

                        if ok then
                                return value
                        end
                end

                local ok, value = pcall(function()
                        return object[key]
                end)

                if ok then
                        return value
                end

                return nil
        end

        local function pullWriteProperty(object, key, value, hidden)
                if hidden and type(sethiddenproperty) == "function" then
                        local ok = pcall(sethiddenproperty, object, key, value)

                        if ok then
                                return true
                        end
                end

                return pcall(function()
                        object[key] = value
                end)
        end

        local function pullRemember(object, key, value, hidden)
                local saved = envOriginals[object]

                if not saved then
                        saved = {}
                        envOriginals[object] = saved
                end

                if saved[key] == nil then
                        saved[key] = {
                                value = pullReadProperty(object, key, hidden),
                                hidden = hidden
                        }
                end

                pullWriteProperty(object, key, value, hidden)
        end

        local function pullSimBoostActive()
                -- The engine's own default radius is 1000 studs; anything
                -- six orders of magnitude above that means the hidden
                -- write genuinely took on this executor.
                local radius = pullReadProperty(LocalPlayer, "SimulationRadius", true)

                if type(radius) == "number" and radius >= 1e6 then
                        return true
                end

                local maximum = pullReadProperty(LocalPlayer, "MaximumSimulationRadius", false)

                return type(maximum) == "number" and maximum >= 1e6
        end

        local function assertSelfBoost()
                -- Re-asserted every single frame, exactly like the
                -- working bring-parts scripts: the boost decays the
                -- moment you stop writing it.
                pullRemember(LocalPlayer, "MaximumSimulationRadius", SIM_RADIUS)
                pullRemember(LocalPlayer, "SimulationRadius", SIM_RADIUS, true)
                pullRemember(LocalPlayer, "NetworkIsSleeping", false, true)
        end

        local function applyPullEnvironment(rootPart)
                -- Ourselves: maximum simulation reach, always awake,
                -- replication centred where the pull is.
                assertSelfBoost()
                pullRemember(LocalPlayer, "ReplicationFocus", rootPart.CFrame)

                if allowSleepSaved == nil then
                        local ok, value = pcall(function()
                                return settings().Physics.AllowSleep
                        end)

                        allowSleepSaved = ok and value or false
                end

                pcall(function()
                        settings().Physics.AllowSleep = false
                end)

                -- Everyone else pinned to zero radius: the arbitration
                -- for every loose part near them lands on us instead.
                -- Local writes, undone on disable.
                for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                                pullRemember(player, "MaximumSimulationRadius", 0)
                                pullRemember(player, "SimulationRadius", 0, true)
                        end
                end

                ObjectPullSettings.SimBoost = pullSimBoostActive()
        end

        local function restorePullEnvironment()
                for object, saved in pairs(envOriginals) do
                        for key, original in pairs(saved) do
                                pcall(pullWriteProperty, object, key, original.value, original.hidden)
                        end
                end

                table.clear(envOriginals)

                if allowSleepSaved ~= nil then
                        pcall(function()
                                settings().Physics.AllowSleep = allowSleepSaved
                        end)

                        allowSleepSaved = nil
                end
        end

        local function claimPullRoot(root)
                if claimedRoots[root] then
                        return
                end

                if not pullFolder then
                        pullFolder = Instance.new("Folder")
                        pullFolder.Name = "__ObjectPullRuntime"
                        pullFolder.Parent = Workspace
                end

                -- The whole assembly is claimed, not just the root:
                -- welded structures flow in as one piece. GetConnectedParts
                -- never includes the root itself, so it is added first -
                -- the old version skipped it, which left solo debris (most
                -- of a disaster) unfeathered and collidable. Player
                -- character parts are skipped - never theirs to touch,
                -- even when a seat welds a driver into the assembly.
                local characters = {}

                for _, player in ipairs(Players:GetPlayers()) do
                        if player.Character then
                                table.insert(characters, player.Character)
                        end
                end

                local parts = { root }

                pcall(function()
                        for _, part in ipairs(root:GetConnectedParts(true)) do
                                if part and part:IsA("BasePart") and part.Parent then
                                        table.insert(parts, part)
                                end
                        end
                end)

                local list = {}

                for _, part in ipairs(parts) do
                        local inCharacter = false

                        for _, character in ipairs(characters) do
                                if part:IsDescendantOf(character) then
                                        inCharacter = true
                                        break
                                end
                        end

                        if not inCharacter then
                                if claimedParts[part] == nil then
                                        claimedParts[part] = {
                                                canCollide = part.CanCollide,
                                                physics = part.CustomPhysicalProperties or false
                                        }

                                        pcall(function()
                                                part.CanCollide = false
                                                part.CustomPhysicalProperties = LIGHT_PHYSICS
                                        end)
                                end

                                table.insert(list, part)
                        end
                end

                -- The puppet: an invisible anchored target the assembly
                -- is strung to with unlimited-force aligns. Moving the
                -- target IS the pull - the engine's constraint solver
                -- does the acceleration, braking and gravity fighting on
                -- every physics substep, and on an assembly we do not
                -- simulate the constraints simply do nothing, so nothing
                -- ever fakes.
                local target = Instance.new("Part")
                target.Name = "PullTarget"
                target.Size = Vector3.new(0.2, 0.2, 0.2)
                target.Transparency = 1
                target.Anchored = true
                target.CanCollide = false
                target.CanTouch = false
                target.CanQuery = false
                target.CastShadow = false
                target.CFrame = root.CFrame
                target.Parent = pullFolder

                local targetAttachment = Instance.new("Attachment")
                targetAttachment.Parent = target

                local attachment = Instance.new("Attachment")
                attachment.Parent = root

                local align = Instance.new("AlignPosition")
                -- Singular "TwoAttachment" - the live API enum is
                -- PositionAlignmentMode.TwoAttachment, and the plural
                -- spelling would nil-index and kill every claim.
                align.Mode = Enum.PositionAlignmentMode.TwoAttachment
                align.Attachment0 = attachment
                align.Attachment1 = targetAttachment
                align.MaxForce = math.huge
                align.MaxVelocity = ALIGN_MAX_VELOCITY
                align.Responsiveness = ALIGN_RESPONSIVENESS
                align.ApplyAtCenterOfMass = true
                align.RigidityEnabled = false
                align.Parent = root

                local orient = Instance.new("AlignOrientation")
                orient.Mode = Enum.OrientationAlignmentMode.TwoAttachment
                orient.Attachment0 = attachment
                orient.Attachment1 = targetAttachment
                orient.MaxTorque = math.huge
                orient.MaxAngularVelocity = math.huge
                orient.Responsiveness = ALIGN_RESPONSIVENESS
                orient.RigidityEnabled = false
                orient.Parent = root

                claimedRoots[root] = {
                        target = target,
                        attachment = attachment,
                        align = align,
                        orient = orient,
                        parts = list,
                        rotation = root.CFrame - root.CFrame.Position
                }
        end

        local function releasePullRoot(root)
                local rec = claimedRoots[root]

                if not rec then
                        return
                end

                claimedRoots[root] = nil

                pcall(function()
                        rec.align:Destroy()
                        rec.orient:Destroy()
                        rec.attachment:Destroy()
                        rec.target:Destroy()
                end)

                for _, part in ipairs(rec.parts) do
                        local saved = claimedParts[part]

                        if saved then
                                claimedParts[part] = nil

                                if part and part.Parent then
                                        pcall(function()
                                                part.CanCollide = saved.canCollide
                                                part.CustomPhysicalProperties =
                                                        saved.physics == false and nil or saved.physics
                                        end)
                                end
                        end
                end
        end

        local function isPullableRoot(root)
                if not root
                        or not root:IsA("BasePart")
                        or not root.Parent
                        or root.AssemblyRootPart ~= root then
                        return false
                end

                if pullFolder and root:IsDescendantOf(pullFolder) then
                        return false
                end

                -- Anchored means the server holds it static and no
                -- client can ever move it for real, so it is not ours
                -- to pull: the old seizure was client-side theatre.
                if root.Anchored then
                        return false
                end

                if EXCLUDED_NAMES[root.Name] then
                        return false
                end

                -- Giant slabs: oceans, tsunami water, lava planes.
                local size = root.Size

                if size.X > MAX_DIMENSION
                        or size.Y > MAX_DIMENSION
                        or size.Z > MAX_DIMENSION then
                        return false
                end

                -- Burning debris: NDS fire rides on parts as a Fire
                -- child, and pulling it in would set us on fire.
                if root:FindFirstChildOfClass("Fire") then
                        return false
                end

                -- Characters, NPCs, tools and accessories are never
                -- ours to pull: walk the ancestors and bail on any
                -- humanoid rig or gear.
                local target = root.Parent

                while target and target ~= Workspace and target ~= game do
                        if target:IsA("Accessory") or target:IsA("Tool") then
                                return false
                        end

                        if target:IsA("Model")
                                and (target:FindFirstChildOfClass("Humanoid")
                                        or target:FindFirstChildOfClass("AnimationController")) then
                                return false
                        end

                        target = target.Parent
                end

                if LocalPlayer.Character
                        and root:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and root:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                local held = ObjectHoldSettings.Root

                if held and held.Parent and root == held then
                        return false
                end

                if Shaker.IsClaimed and Shaker.IsClaimed(root) then
                        return false
                end

                if VehicleStorm.IsClaimed and VehicleStorm.IsClaimed(root) then
                        return false
                end

                return true
        end

        local function startWalkPass()
                table.clear(walkStack)
                table.clear(walkSeen)

                for _, child in ipairs(Workspace:GetChildren()) do
                        table.insert(walkStack, child)
                end
        end

        local function processWalk(center)
                -- The old radius query truncated at 8192 parts and never
                -- told anyone, which on a busy NDS island meant most of
                -- the map never even got claimed. A throttled walk of the
                -- whole workspace claims everything pullable within a
                -- hard per-frame budget instead.
                local deadline = os.clock() + WALK_SECONDS
                local processed = 0

                while #walkStack > 0
                        and processed < WALK_INSTANCES
                        and os.clock() < deadline do
                        local instance = walkStack[#walkStack]
                        walkStack[#walkStack] = nil
                        processed += 1

                        if instance:IsA("BasePart") then
                                local root = instance.AssemblyRootPart

                                if root and not walkSeen[root] then
                                        walkSeen[root] = true

                                        if isPullableRoot(root) then
                                                local offset = root.Position - center

                                                if offset:Dot(offset) <= SCAN_RADIUS * SCAN_RADIUS then
                                                        claimPullRoot(root)
                                                end
                                        end
                                end
                        else
                                local children = instance:GetChildren()

                                for index = #children, 1, -1 do
                                        walkStack[#walkStack + 1] = children[index]
                                end
                        end
                end

                return #walkStack > 0
        end

        local function finishWalkPass(center)
                -- Drop anything that left the range or got cleaned up
                -- while the pass was running.
                local limit = (SCAN_RADIUS + 100) * (SCAN_RADIUS + 100)

                for root in pairs(claimedRoots) do
                        if not root.Parent then
                                releasePullRoot(root)
                        else
                                local offset = root.Position - center

                                if offset:Dot(offset) > limit then
                                        releasePullRoot(root)
                                end
                        end
                end
        end

        local function updatePullStatusCounts()
                -- ReceiveAge is zero only on assemblies our client
                -- actually simulates - the devforum-verified client side
                -- ownership check - so this counts what is really held
                -- instead of what was merely claimed.
                local held = 0
                local contested = 0

                for root in pairs(claimedRoots) do
                        if root.Parent then
                                if root.ReceiveAge == 0 then
                                        held += 1
                                else
                                        contested += 1
                                end
                        end
                end

                local suffix = ObjectPullSettings.SimBoost
                        and ""
                        or " (no sim boost - executor limited)"

                if held + contested == 0 then
                        updatePullStatus("No liftable objects in range" .. suffix)
                        return
                end

                local text = "Holding " .. held

                if contested > 0 then
                        text = text .. " + " .. contested .. " contested"
                end

                updatePullStatus(text .. suffix)
        end

        local function updateObjectPull()
                if not running or not ObjectPullSettings.Enabled then
                        return
                end

                local character = LocalPlayer.Character
                local rootPart = character
                        and character:FindFirstChild("HumanoidRootPart")

                if not rootPart or not rootPart.Parent then
                        updatePullStatus("Character unavailable")
                        return
                end

                local now = os.clock()

                frameTick += 1

                -- The boost is re-asserted every frame; the rest of the
                -- environment war runs on its own cadence.
                assertSelfBoost()

                if now >= (ObjectPullSettings.NextEnvAt or 0) then
                        ObjectPullSettings.NextEnvAt = now + ENV_INTERVAL
                        applyPullEnvironment(rootPart)

                        -- Between passes only: the moment a pass is due,
                        -- let the walk start and speak through its own
                        -- results instead of flashing a zero count.
                        if #walkStack == 0
                                and now < (ObjectPullSettings.NextPassAt or 0) then
                                updatePullStatusCounts()
                        end
                end

                local center = rootPart.Position

                if #walkStack == 0
                        and now >= (ObjectPullSettings.NextPassAt or 0) then
                        ObjectPullSettings.NextPassAt = now + PASS_INTERVAL
                        startWalkPass()
                end

                if #walkStack > 0 then
                        processWalk(center)

                        if #walkStack == 0 then
                                finishWalkPass(center)
                                updatePullStatusCounts()
                        end
                end

                -- The puppet show: each target is placed on its own ring
                -- point, Keep Distance studs from us along the assembly's
                -- approach direction, and the aligns do the rest. Far
                -- objects race in at the MaxVelocity cap, arrivals brake
                -- on the responsiveness curve, and the hold has no
                -- gravity sag because the constraint never sleeps
                -- between frames. A small poke keeps the assembly from
                -- dozing off mid-flight.
                local keep = getKeepDistance()
                local poke = frameTick % POKE_INTERVAL == 0

                for root, rec in pairs(claimedRoots) do
                        if not root.Parent then
                                releasePullRoot(root)
                        elseif not rec.target.Parent then
                                -- A destroyed puppet (some games sweep the
                                -- workspace client-side) must not be allowed
                                -- to abort the whole servo through an error.
                                releasePullRoot(root)
                        else
                                local toPlayer = center - root.Position
                                local gap = toPlayer.Magnitude

                                if gap == gap and gap > 0.01 then
                                        local ringPos = center - toPlayer.Unit * keep
                                        rec.target.CFrame = CFrame.new(ringPos) * rec.rotation
                                end

                                if poke then
                                        pcall(function()
                                                root.AssemblyLinearVelocity = ANTI_SLEEP
                                        end)
                                end
                        end
                end
        end

        local function stopObjectPull()
                disconnect(ObjectPullSettings.Connection)
                ObjectPullSettings.Connection = nil
                ObjectPullSettings.NextEnvAt = 0
                ObjectPullSettings.NextPassAt = 0

                for root in pairs(claimedRoots) do
                        releasePullRoot(root)
                end

                table.clear(walkStack)
                table.clear(walkSeen)

                if pullFolder then
                        local folder = pullFolder
                        pullFolder = nil

                        pcall(function()
                                folder:Destroy()
                        end)
                end

                restorePullEnvironment()
        end

        -- Shared with the shaker so the two storm engines never
        -- claim the same assembly and fight over it.
        ObjectPull.IsClaimed = function(root)
                return claimedRoots[root] ~= nil
        end

        ObjectPull.setEnabled = function(value)
                local enabled = value and true or false

                stopObjectPull()
                ObjectPullSettings.Enabled = enabled

                if type(ObjectPull.OnEnabledChanged) == "function" then
                        pcall(ObjectPull.OnEnabledChanged, enabled)
                end

                if not enabled then
                        updatePullStatus("Object Pull off")
                        return
                end

                pullFolder = Instance.new("Folder")
                pullFolder.Name = "__ObjectPullRuntime"
                pullFolder.Parent = Workspace

                local rootPart = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                if rootPart and rootPart.Parent then
                        applyPullEnvironment(rootPart)
                end

                ObjectPullSettings.NextPassAt = 0

                updatePullStatus("Scanning for objects...")

                ObjectPullSettings.Connection = RunService.Heartbeat:Connect(
                        function()
                                local ok, err = pcall(updateObjectPull)

                                if not ok then
                                        updatePullStatus(
                                                "Engine error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )
        end
end

-- ============================================================
-- Object Shaker v2: the Fun tab storm engine, rebuilt on the
-- puppet actuation the pull uses. The v40 velocity writes
-- re-randomized every Heartbeat produced a random walk that
-- barely moved anywhere, and on assemblies we do not simulate
-- they were local writes the server instantly corrected -
-- that is where most of the jitter came from. The v40 anchored
-- seizure is gone entirely: an anchored part is server-static,
-- no client can ever move it for real, so shaking it was pure
-- client-side theatre. Only genuinely unanchored assemblies
-- are claimed now, and each gets an invisible anchored whip
-- target strung to it with unlimited-force AlignPosition and
-- AlignOrientation, exactly like the pull's puppet. The target
-- orbits the player on a random axis at 5-13 rad/s on a 10-26
-- stud shell, and every quarter second or so the whole orbit
-- is re-thrown onto a completely new axis, radius, speed and
-- orientation - so every part is perpetually either whipping
-- around the player or tearing across the shell at the 800
-- studs/s solver cap, tumbling the entire time. Joints are
-- never touched: assemblies keep their welds and hinges and
-- flail as connected pieces. The shell tracks the player every
-- frame, so the whole storm travels with you. Claimed parts go
-- non-collidable while shaken so the storm cannot smash the
-- player running it; collision is restored exactly on release.
-- Constraints no-op on assemblies we do not simulate, so
-- nothing can ever fake. No sliders on purpose.
-- ============================================================
do
        local ENV_INTERVAL = 0.5
        local SHAKE_RADIUS = 100
        local RELEASE_SLACK = 40
        local SCAN_INTERVAL = 0.5
        local POKE_INTERVAL = 3
        local MAX_DIMENSION = 120
        local SIM_RADIUS = 9e9
        local WHIP_MIN_RADIUS = 10
        local WHIP_MAX_RADIUS = 26
        local WHIP_MIN_SECS = 0.2
        local WHIP_MAX_SECS = 0.45
        local SPIN_MIN_SPEED = 5
        local SPIN_MAX_SPEED = 13
        local ALIGN_RESPONSIVENESS = 200
        local ALIGN_MAX_VELOCITY = 800
        local ORIENT_MAX_ANGULAR = 40
        local ANTI_SLEEP = Vector3.new(0.5, 0.5, 0.5)

        local EXCLUDED_NAMES = {
                Terrain = true,
                Baseplate = true,
                HumanoidRootPart = true,
                Handle = true,
                ["__PlayerToolsPlatform"] = true
        }

        local claimedRoots = setmetatable({}, { __mode = "k" })
        local claimedParts = setmetatable({}, { __mode = "k" })
        local envOriginals = setmetatable({}, { __mode = "k" })
        local allowSleepSaved = nil
        local shakerFolder = nil
        local frameTick = 0

        -- A real MaxParts budget: the v40 default query cap silently
        -- truncated the storm on busy islands, so whole crowds of
        -- debris never got claimed at all.
        local overlapParams = OverlapParams.new()
        overlapParams.MaxParts = 100000

        local function updateShakeStatus(text)
                local message = tostring(text or "Object Shaker off")

                if ShakerSettings.LastStatus == message then
                        return
                end

                ShakerSettings.LastStatus = message

                if type(Shaker.OnStatusChanged) == "function" then
                        pcall(Shaker.OnStatusChanged, message)
                end
        end

        local function randomUnit()
                local vector = Vector3.new(
                        math.random() * 2 - 1,
                        math.random() * 2 - 1,
                        math.random() * 2 - 1
                )

                if vector.Magnitude < 0.05 then
                        return Vector3.new(0, 1, 0)
                end

                return vector.Unit
        end

        local function randomWhipDirection()
                -- Always biased above the horizon so orbits ride up
                -- around the player instead of grinding the ground,
                -- and normalized so the shell stays a real 10-26
                -- studs out instead of collapsing into the player.
                local dir = randomUnit()
                local biased = Vector3.new(
                        dir.X,
                        math.abs(dir.Y) * 0.7 + 0.25,
                        dir.Z
                )

                return biased.Unit
        end

        local function randomWhipRotation()
                return CFrame.Angles(
                        math.random() * math.pi * 2,
                        math.random() * math.pi * 2,
                        math.random() * math.pi * 2
                )
        end

        local function shakeReadProperty(object, key, hidden)
                if hidden and type(gethiddenproperty) == "function" then
                        local ok, value = pcall(gethiddenproperty, object, key)

                        if ok then
                                return value
                        end
                end

                local ok, value = pcall(function()
                        return object[key]
                end)

                if ok then
                        return value
                end

                return nil
        end

        local function shakeWriteProperty(object, key, value, hidden)
                if hidden and type(sethiddenproperty) == "function" then
                        local ok = pcall(sethiddenproperty, object, key, value)

                        if ok then
                                return true
                        end
                end

                return pcall(function()
                        object[key] = value
                end)
        end

        local function shakeRemember(object, key, value, hidden)
                local saved = envOriginals[object]

                if not saved then
                        saved = {}
                        envOriginals[object] = saved
                end

                if saved[key] == nil then
                        saved[key] = {
                                value = shakeReadProperty(object, key, hidden),
                                hidden = hidden
                        }
                end

                shakeWriteProperty(object, key, value, hidden)
        end

        local function shakeSimBoostActive()
                -- Same read-back contract as the pull: the engine's own
                -- default radius is 1000 studs, so anything six orders of
                -- magnitude above that means the hidden write genuinely
                -- took on this executor.
                local radius = shakeReadProperty(LocalPlayer, "SimulationRadius", true)

                if type(radius) == "number" and radius >= 1e6 then
                        return true
                end

                local maximum = shakeReadProperty(LocalPlayer, "MaximumSimulationRadius", false)

                return type(maximum) == "number" and maximum >= 1e6
        end

        local function assertSelfBoost()
                -- Re-asserted every single frame exactly like the pull:
                -- the boost decays the moment you stop writing it.
                shakeRemember(LocalPlayer, "MaximumSimulationRadius", SIM_RADIUS)
                shakeRemember(LocalPlayer, "SimulationRadius", SIM_RADIUS, true)
                shakeRemember(LocalPlayer, "NetworkIsSleeping", false, true)
        end

        local function applyShakeEnvironment(rootPart)
                assertSelfBoost()
                shakeRemember(LocalPlayer, "ReplicationFocus", rootPart.CFrame)

                if allowSleepSaved == nil then
                        local ok, value = pcall(function()
                                return settings().Physics.AllowSleep
                        end)

                        allowSleepSaved = ok and value or false
                end

                pcall(function()
                        settings().Physics.AllowSleep = false
                end)

                -- Everyone else pinned to zero radius so every loose
                -- assembly near them arbitrates to us instead.
                for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                                shakeRemember(player, "MaximumSimulationRadius", 0)
                                shakeRemember(player, "SimulationRadius", 0, true)
                        end
                end

                ShakerSettings.SimBoost = shakeSimBoostActive()
        end

        local function restoreShakeEnvironment()
                for object, saved in pairs(envOriginals) do
                        for key, original in pairs(saved) do
                                pcall(shakeWriteProperty, object, key, original.value, original.hidden)
                        end
                end

                table.clear(envOriginals)

                if allowSleepSaved ~= nil then
                        pcall(function()
                                settings().Physics.AllowSleep = allowSleepSaved
                        end)

                        allowSleepSaved = nil
                end
        end

        local function claimShakeRoot(root)
                if claimedRoots[root] then
                        return
                end

                if not shakerFolder then
                        shakerFolder = Instance.new("Folder")
                        shakerFolder.Name = "__ObjectShakerRuntime"
                        shakerFolder.Parent = Workspace
                end

                -- The whole assembly is claimed, not just the root, so
                -- welded structures flail as one connected piece. Player
                -- character parts are skipped - never theirs to touch,
                -- even when a seat welds a driver into the assembly.
                local characters = {}

                for _, player in ipairs(Players:GetPlayers()) do
                        if player.Character then
                                table.insert(characters, player.Character)
                        end
                end

                local parts = { root }

                pcall(function()
                        for _, part in ipairs(root:GetConnectedParts(true)) do
                                if part and part:IsA("BasePart") and part.Parent then
                                        table.insert(parts, part)
                                end
                        end
                end)

                local list = {}

                for _, part in ipairs(parts) do
                        local inCharacter = false

                        for _, character in ipairs(characters) do
                                if part:IsDescendantOf(character) then
                                        inCharacter = true
                                        break
                                end
                        end

                        if not inCharacter then
                                if claimedParts[part] == nil then
                                        claimedParts[part] = {
                                                canCollide = part.CanCollide
                                        }

                                        pcall(function()
                                                part.CanCollide = false
                                        end)
                                end

                                table.insert(list, part)
                        end
                end

                -- The puppet, same pattern as the pull: an invisible
                -- anchored whip target the assembly is strung to with
                -- unlimited-force aligns. The target orbits the player
                -- and is re-thrown onto a brand new orbit every whip;
                -- moving it IS the storm - the engine's constraint
                -- solver does the acceleration, gravity fighting and
                -- tumbling on every physics substep, and on an assembly
                -- we do not simulate the constraints simply do nothing,
                -- so nothing ever fakes.
                local target = Instance.new("Part")
                target.Name = "__ObjectShakerTarget"
                target.Size = Vector3.new(0.2, 0.2, 0.2)
                target.Transparency = 1
                target.Anchored = true
                target.CanCollide = false
                target.CanTouch = false
                target.CanQuery = false
                target.CastShadow = false
                target.CFrame = root.CFrame
                target.Parent = shakerFolder

                local targetAttachment = Instance.new("Attachment")
                targetAttachment.Parent = target

                local attachment = Instance.new("Attachment")
                attachment.Parent = root

                local align = Instance.new("AlignPosition")
                align.Mode = Enum.PositionAlignmentMode.TwoAttachment
                align.Attachment0 = attachment
                align.Attachment1 = targetAttachment
                align.MaxForce = math.huge
                align.MaxVelocity = ALIGN_MAX_VELOCITY
                align.Responsiveness = ALIGN_RESPONSIVENESS
                align.ApplyAtCenterOfMass = true
                align.RigidityEnabled = false
                align.Parent = root

                local orient = Instance.new("AlignOrientation")
                orient.Mode = Enum.OrientationAlignmentMode.TwoAttachment
                orient.Attachment0 = attachment
                orient.Attachment1 = targetAttachment
                orient.MaxTorque = math.huge
                orient.MaxAngularVelocity = ORIENT_MAX_ANGULAR
                orient.Responsiveness = ALIGN_RESPONSIVENESS
                orient.RigidityEnabled = false
                orient.Parent = root

                claimedRoots[root] = {
                        target = target,
                        attachment = attachment,
                        align = align,
                        orient = orient,
                        parts = list,
                        spinAxis = randomUnit(),
                        spinPhase = math.random() * math.pi * 2,
                        spinSpeed = SPIN_MIN_SPEED
                                + math.random() * (SPIN_MAX_SPEED - SPIN_MIN_SPEED),
                        startOffset = randomWhipDirection()
                                * (WHIP_MIN_RADIUS + math.random() * (WHIP_MAX_RADIUS - WHIP_MIN_RADIUS)),
                        whipRotation = randomWhipRotation(),
                        nextWhipAt = os.clock()
                                + WHIP_MIN_SECS
                                + math.random() * (WHIP_MAX_SECS - WHIP_MIN_SECS)
                }
        end

        local function releaseShakeRoot(root)
                local rec = claimedRoots[root]

                if not rec then
                        return
                end

                claimedRoots[root] = nil

                pcall(function()
                        rec.align:Destroy()
                        rec.orient:Destroy()
                        rec.attachment:Destroy()
                        rec.target:Destroy()
                end)

                for _, part in ipairs(rec.parts) do
                        local saved = claimedParts[part]

                        if saved then
                                claimedParts[part] = nil

                                if part and part.Parent then
                                        pcall(function()
                                                part.CanCollide = saved.canCollide
                                        end)
                                end
                        end
                end
        end

        local function isShakableRoot(root)
                if not root
                        or not root:IsA("BasePart")
                        or not root.Parent
                        or root.AssemblyRootPart ~= root then
                        return false
                end

                -- Anchored means the server holds it static and no
                -- client can ever move it for real, so it is not ours
                -- to shake: the v40 version locally unanchored these
                -- and shook them, which was pure client-side theatre.
                if root.Anchored then
                        return false
                end

                if EXCLUDED_NAMES[root.Name] then
                        return false
                end

                -- Giant slabs: oceans, tsunami water, lava planes.
                local size = root.Size

                if size.X > MAX_DIMENSION
                        or size.Y > MAX_DIMENSION
                        or size.Z > MAX_DIMENSION then
                        return false
                end

                -- Burning debris: NDS fire rides on parts as a Fire
                -- child, and whipping it past us would set us on fire.
                if root:FindFirstChildOfClass("Fire") then
                        return false
                end

                -- Characters, NPCs, tools and accessories are never ours
                -- to shake: walk the ancestors and bail on any humanoid
                -- rig or gear.
                local target = root.Parent

                while target and target ~= Workspace and target ~= game do
                        if target:IsA("Accessory") or target:IsA("Tool") then
                                return false
                        end

                        if target:IsA("Model")
                                and (target:FindFirstChildOfClass("Humanoid")
                                        or target:FindFirstChildOfClass("AnimationController")) then
                                return false
                        end

                        target = target.Parent
                end

                if LocalPlayer.Character
                        and root:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and root:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                local held = ObjectHoldSettings.Root

                if held and held.Parent and root == held then
                        return false
                end

                if ObjectPull.IsClaimed and ObjectPull.IsClaimed(root) then
                        return false
                end

                if VehicleStorm.IsClaimed and VehicleStorm.IsClaimed(root) then
                        return false
                end

                return true
        end

        local function updateShakeStatusCounts()
                -- ReceiveAge is zero only on assemblies our client
                -- actually simulates, so this counts what is really being
                -- shaken instead of what was merely claimed.
                local held = 0
                local contested = 0

                for root in pairs(claimedRoots) do
                        if root.Parent then
                                if root.ReceiveAge == 0 then
                                        held += 1
                                else
                                        contested += 1
                                end
                        end
                end

                local suffix = ShakerSettings.SimBoost
                        and ""
                        or " (no sim boost - executor limited)"

                if held + contested == 0 then
                        updateShakeStatus("Nothing to shake nearby" .. suffix)
                        return
                end

                local text = "Shaking " .. held

                if contested > 0 then
                        text = text .. " + " .. contested .. " contested"
                end

                updateShakeStatus(text .. suffix)
        end

        local function updateObjectShaker(deltaTime)
                if not running or not ShakerSettings.Enabled then
                        return
                end

                local character = LocalPlayer.Character
                local rootPart = character
                        and character:FindFirstChild("HumanoidRootPart")

                if not rootPart or not rootPart.Parent then
                        updateShakeStatus("Character unavailable")
                        return
                end

                local now = os.clock()
                local dt = math.clamp(tonumber(deltaTime) or 1 / 60, 0.001, 0.25)

                frameTick += 1

                assertSelfBoost()

                if now >= (ShakerSettings.NextEnvAt or 0) then
                        ShakerSettings.NextEnvAt = now + ENV_INTERVAL
                        applyShakeEnvironment(rootPart)
                end

                local center = rootPart.Position

                if now >= (ShakerSettings.NextScanAt or 0) then
                        ShakerSettings.NextScanAt = now + SCAN_INTERVAL

                        -- Release pass first: anything destroyed or flung
                        -- beyond the storm's edge is let go mid-flight.
                        local limit = (SHAKE_RADIUS + RELEASE_SLACK)
                                * (SHAKE_RADIUS + RELEASE_SLACK)

                        for root in pairs(claimedRoots) do
                                if not root.Parent then
                                        releaseShakeRoot(root)
                                else
                                        local offset = root.Position - center

                                        if offset:Dot(offset) > limit then
                                                releaseShakeRoot(root)
                                        end
                                end
                        end

                        -- Claim pass: one spatial query over the bubble
                        -- with a real MaxParts budget (the v40 default
                        -- silently truncated the storm), mapped onto
                        -- assembly roots so welded structures arrive as
                        -- one piece each.
                        local found = Workspace:GetPartBoundsInRadius(
                                center,
                                SHAKE_RADIUS,
                                overlapParams
                        )

                        for _, part in ipairs(found) do
                                local root = part.AssemblyRootPart

                                if root
                                        and not claimedRoots[root]
                                        and isShakableRoot(root) then
                                        local offset = root.Position - center

                                        if offset:Dot(offset) <= SHAKE_RADIUS * SHAKE_RADIUS then
                                                claimShakeRoot(root)
                                        end
                                end
                        end

                        updateShakeStatusCounts()
                end

                -- The storm: every claimed assembly's whip target orbits
                -- the player on its own axis, and each whip re-throws it
                -- onto a brand new orbit. The aligns drag the assembly
                -- along; on an assembly we do not simulate they no-op,
                -- so there is nothing to rubber-band.
                local poke = frameTick % POKE_INTERVAL == 0

                for root, rec in pairs(claimedRoots) do
                        if not root.Parent then
                                releaseShakeRoot(root)
                        elseif not rec.target.Parent then
                                -- A destroyed puppet (some games sweep the
                                -- workspace client-side) must not abort the
                                -- whole servo through an error.
                                releaseShakeRoot(root)
                        else
                                if now >= (rec.nextWhipAt or 0) then
                                        rec.spinAxis = randomUnit()
                                        rec.spinSpeed = SPIN_MIN_SPEED
                                                + math.random() * (SPIN_MAX_SPEED - SPIN_MIN_SPEED)
                                        rec.startOffset = randomWhipDirection()
                                                * (WHIP_MIN_RADIUS + math.random() * (WHIP_MAX_RADIUS - WHIP_MIN_RADIUS))
                                        rec.whipRotation = randomWhipRotation()
                                        rec.nextWhipAt = now + WHIP_MIN_SECS
                                                + math.random() * (WHIP_MAX_SECS - WHIP_MIN_SECS)
                                end

                                rec.spinPhase += rec.spinSpeed * dt

                                local spin = CFrame.fromAxisAngle(rec.spinAxis, rec.spinPhase)
                                local anchor = center + spin:VectorToWorldSpace(rec.startOffset)

                                rec.target.CFrame = CFrame.new(anchor)
                                        * rec.whipRotation
                                        * spin

                                if poke then
                                        pcall(function()
                                                root.AssemblyLinearVelocity = ANTI_SLEEP
                                        end)
                                end
                        end
                end
        end

        local function stopObjectShaker()
                disconnect(ShakerSettings.Connection)
                ShakerSettings.Connection = nil
                ShakerSettings.NextEnvAt = 0
                ShakerSettings.NextScanAt = 0

                for root in pairs(claimedRoots) do
                        releaseShakeRoot(root)
                end

                if shakerFolder then
                        local folder = shakerFolder
                        shakerFolder = nil

                        pcall(function()
                                folder:Destroy()
                        end)
                end

                restoreShakeEnvironment()
        end

        -- Shared with the pull so the two storm engines never claim
        -- the same assembly and fight over it.
        Shaker.IsClaimed = function(root)
                return claimedRoots[root] ~= nil
        end

        Shaker.setEnabled = function(value)
                local enabled = value and true or false

                stopObjectShaker()
                ShakerSettings.Enabled = enabled

                if type(Shaker.OnEnabledChanged) == "function" then
                        pcall(Shaker.OnEnabledChanged, enabled)
                end

                if not enabled then
                        updateShakeStatus("Object Shaker off")
                        return
                end

                local rootPart = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                if rootPart and rootPart.Parent then
                        applyShakeEnvironment(rootPart)
                end

                if not shakerFolder then
                        shakerFolder = Instance.new("Folder")
                        shakerFolder.Name = "__ObjectShakerRuntime"
                        shakerFolder.Parent = Workspace
                end

                ShakerSettings.NextScanAt = 0

                updateShakeStatus("Scanning for objects...")

                ShakerSettings.Connection = RunService.Heartbeat:Connect(
                        function(deltaTime)
                                local ok, err = pcall(updateObjectShaker, deltaTime)

                                if not ok then
                                        updateShakeStatus(
                                                "Engine error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )
        end
end

-- ============================================================
-- Vehicle Storm: the Fun tab vehicle engine. Every other
-- player's car - anything seat-and-wheel shaped - within the
-- bubble is claimed as a whole assembly, driver included since
-- the seat welds them into it, and driven through four modes
-- cycled from one button, no sliders on purpose. Vortex drags
-- them into a rising tornado shell around the player. Fling
-- re-launches them skyward on random tangents. Slam hoists
-- each one up a column in front of the player and hammers it
-- into the ground on a loop. Freeze zeroes their velocities
-- every frame so traffic stops dead in the air. Vortex and
-- Slam act through the same puppet rig the pull and shaker
-- use - an invisible anchored target strung to the assembly
-- with unlimited-force aligns - and constraints no-op on
-- assemblies we do not simulate, so those modes can never
-- fake. Fling and Freeze write velocities, and every write is
-- gated on ReceiveAge == 0, so they only ever land on
-- assemblies our client genuinely simulates - the same honest
-- contract the pull and shaker hold. No part properties are
-- touched on vehicles: collisions stay on, cars smash into
-- each other, the map and their drivers exactly as the engine
-- intends, and there is nothing to restore on release. Own
-- character, own current vehicle, hover-held, pull-claimed
-- and shaker-claimed assemblies are excluded so the three
-- engines never fight over the same root.
-- ============================================================
-- The engine lives inside a function instead of a plain do-block:
-- the main chunk rides close to the engine's 200-active-locals
-- budget already (the pull and shaker blocks sit in it), and a
-- function scope gets a fresh budget of its own.
local function buildVehicleStorm()
        local ENV_INTERVAL = 0.5
        local SCAN_INTERVAL = 0.5
        local STORM_RADIUS = 130
        local RELEASE_SLACK = 60
        local MAX_DIMENSION = 120
        local SIM_RADIUS = 9e9
        local POKE_INTERVAL = 3

        local MODES = { "Vortex", "Fling", "Slam", "Freeze" }

        -- The settings table rides as a field on VehicleStorm so the
        -- main chunk stays inside the engine's 200-local budget; this
        -- block-scoped alias keeps the engine code identical to the
        -- pull's and shaker's.
        local VehicleStormSettings = VehicleStorm.Settings

        local VORTEX_MIN_RADIUS = 30
        local VORTEX_MAX_RADIUS = 55
        local VORTEX_MIN_SPEED = 3.2
        local VORTEX_MAX_SPEED = 4.8
        local VORTEX_LIFT_MIN = 8
        local VORTEX_LIFT_SPAN = 26
        local VORTEX_LIFT_CYCLE = 3
        local SPIN_MIN_SPEED = 2
        local SPIN_MAX_SPEED = 5

        local FLING_MIN_SECS = 0.55
        local FLING_MAX_SECS = 0.9
        local FLING_UP_MIN = 260
        local FLING_UP_MAX = 340
        local FLING_SIDE_MIN = 320
        local FLING_SIDE_MAX = 420
        local FLING_SPIN_MIN = 50
        local FLING_SPIN_MAX = 90

        local SLAM_COLUMN_DISTANCE = 30
        local SLAM_RING_MIN = 10
        local SLAM_RING_MAX = 22
        local SLAM_UP_HEIGHT = 75
        local SLAM_UP_SECS = 0.5
        local SLAM_DOWN_SECS = 0.5

        local ALIGN_RESPONSIVENESS = 200
        local ALIGN_MAX_VELOCITY = 800
        local ORIENT_MAX_ANGULAR = 40
        local ANTI_SLEEP = Vector3.new(0.5, 0.5, 0.5)

        local EXCLUDED_NAMES = {
                Terrain = true,
                Baseplate = true,
                HumanoidRootPart = true,
                Handle = true,
                ["__PlayerToolsPlatform"] = true,
                ["__ObjectShakerTarget"] = true
        }

        local claimedRoots = setmetatable({}, { __mode = "k" })
        local vehicleCheckCache = setmetatable({}, { __mode = "k" })
        local envOriginals = setmetatable({}, { __mode = "k" })
        local allowSleepSaved = nil
        local stormFolder = nil
        local anchoredSkipped = 0
        local frameTick = 0

        -- Same real MaxParts budget as the shaker: the default
        -- query cap silently truncates claims on busy islands.
        local overlapParams = OverlapParams.new()
        overlapParams.MaxParts = 100000

        local function updateStormStatus(text)
                local message = tostring(text or "Vehicle Storm off")

                if VehicleStormSettings.LastStatus == message then
                        return
                end

                VehicleStormSettings.LastStatus = message

                if type(VehicleStorm.OnStatusChanged) == "function" then
                        pcall(VehicleStorm.OnStatusChanged, message)
                end
        end

        local function randomUnit()
                local vector = Vector3.new(
                        math.random() * 2 - 1,
                        math.random() * 2 - 1,
                        math.random() * 2 - 1
                )

                if vector.Magnitude < 0.05 then
                        return Vector3.new(0, 1, 0)
                end

                return vector.Unit
        end

        local function stormReadProperty(object, key, hidden)
                if hidden and type(gethiddenproperty) == "function" then
                        local ok, value = pcall(gethiddenproperty, object, key)

                        if ok then
                                return value
                        end
                end

                local ok, value = pcall(function()
                        return object[key]
                end)

                if ok then
                        return value
                end

                return nil
        end

        local function stormWriteProperty(object, key, value, hidden)
                if hidden and type(sethiddenproperty) == "function" then
                        local ok = pcall(sethiddenproperty, object, key, value)

                        if ok then
                                return true
                        end
                end

                return pcall(function()
                        object[key] = value
                end)
        end

        local function stormRemember(object, key, value, hidden)
                local saved = envOriginals[object]

                if not saved then
                        saved = {}
                        envOriginals[object] = saved
                end

                if saved[key] == nil then
                        saved[key] = {
                                value = stormReadProperty(object, key, hidden),
                                hidden = hidden
                        }
                end

                stormWriteProperty(object, key, value, hidden)
        end

        local function stormSimBoostActive()
                -- Same read-back contract as the pull and shaker: the
                -- engine default radius is 1000 studs, so six orders of
                -- magnitude above it means the hidden write genuinely
                -- took on this executor.
                local radius = stormReadProperty(LocalPlayer, "SimulationRadius", true)

                if type(radius) == "number" and radius >= 1e6 then
                        return true
                end

                local maximum = stormReadProperty(LocalPlayer, "MaximumSimulationRadius", false)

                return type(maximum) == "number" and maximum >= 1e6
        end

        local function assertSelfBoost()
                -- Re-asserted every single frame exactly like the pull
                -- and shaker: the boost decays the moment you stop.
                stormRemember(LocalPlayer, "MaximumSimulationRadius", SIM_RADIUS)
                stormRemember(LocalPlayer, "SimulationRadius", SIM_RADIUS, true)
                stormRemember(LocalPlayer, "NetworkIsSleeping", false, true)
        end

        local function applyStormEnvironment(rootPart)
                assertSelfBoost()
                stormRemember(LocalPlayer, "ReplicationFocus", rootPart.CFrame)

                if allowSleepSaved == nil then
                        local ok, value = pcall(function()
                                return settings().Physics.AllowSleep
                        end)

                        allowSleepSaved = ok and value or false
                end

                pcall(function()
                        settings().Physics.AllowSleep = false
                end)

                for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                                stormRemember(player, "MaximumSimulationRadius", 0)
                                stormRemember(player, "SimulationRadius", 0, true)
                        end
                end

                VehicleStormSettings.SimBoost = stormSimBoostActive()
        end

        local function restoreStormEnvironment()
                for object, saved in pairs(envOriginals) do
                        for key, original in pairs(saved) do
                                pcall(stormWriteProperty, object, key, original.value, original.hidden)
                        end
                end

                table.clear(envOriginals)

                if allowSleepSaved ~= nil then
                        pcall(function()
                                settings().Physics.AllowSleep = allowSleepSaved
                        end)

                        allowSleepSaved = nil
                end
        end

        local function assemblyIsVehicle(root)
                -- Positive vehicle test on the whole assembly, cached
                -- per root: a VehicleSeat welded in, or a plain Seat
                -- riding with wheel/tire named parts. Chairs and
                -- benches have seats but no wheels, so they stay out.
                local cached = vehicleCheckCache[root]

                if cached ~= nil then
                        return cached
                end

                local hasVehicleSeat = false
                local hasSeat = false
                local hasWheel = false

                pcall(function()
                        for _, part in ipairs(root:GetConnectedParts(true)) do
                                if part:IsA("VehicleSeat") then
                                        hasVehicleSeat = true
                                elseif part:IsA("Seat") then
                                        hasSeat = true
                                else
                                        local name = string.lower(part.Name)

                                        if string.find(name, "wheel", 1, true)
                                                or string.find(name, "tire", 1, true) then
                                                hasWheel = true
                                        end
                                end
                        end
                end)

                local result = hasVehicleSeat or (hasSeat and hasWheel)

                vehicleCheckCache[root] = result

                return result
        end

        local function buildPuppet(root)
                -- Same invisible anchored whip target as the pull and
                -- shaker: moving the target IS the mode, the solver
                -- does the dragging, and on an assembly we do not
                -- simulate the constraints simply do nothing.
                local target = Instance.new("Part")
                target.Name = "__VehicleStormTarget"
                target.Size = Vector3.new(0.2, 0.2, 0.2)
                target.Transparency = 1
                target.Anchored = true
                target.CanCollide = false
                target.CanTouch = false
                target.CanQuery = false
                target.CastShadow = false
                target.CFrame = root.CFrame
                target.Parent = stormFolder

                local targetAttachment = Instance.new("Attachment")
                targetAttachment.Parent = target

                local attachment = Instance.new("Attachment")
                attachment.Parent = root

                local align = Instance.new("AlignPosition")
                align.Mode = Enum.PositionAlignmentMode.TwoAttachment
                align.Attachment0 = attachment
                align.Attachment1 = targetAttachment
                align.MaxForce = math.huge
                align.MaxVelocity = ALIGN_MAX_VELOCITY
                align.Responsiveness = ALIGN_RESPONSIVENESS
                align.ApplyAtCenterOfMass = true
                align.RigidityEnabled = false
                align.Parent = root

                local orient = Instance.new("AlignOrientation")
                orient.Mode = Enum.OrientationAlignmentMode.TwoAttachment
                orient.Attachment0 = attachment
                orient.Attachment1 = targetAttachment
                orient.MaxTorque = math.huge
                orient.MaxAngularVelocity = ORIENT_MAX_ANGULAR
                orient.Responsiveness = ALIGN_RESPONSIVENESS
                orient.RigidityEnabled = false
                orient.Parent = root

                return {
                        target = target,
                        attachment = attachment,
                        align = align,
                        orient = orient
                }
        end

        local function modeUsesPuppet()
                local mode = MODES[VehicleStormSettings.Mode]

                return mode == "Vortex" or mode == "Slam"
        end

        local function claimStormRoot(root, rootPart)
                if claimedRoots[root] then
                        return
                end

                if not stormFolder then
                        stormFolder = Instance.new("Folder")
                        stormFolder.Name = "__VehicleStormRuntime"
                        stormFolder.Parent = Workspace
                end

                -- Slam column direction is locked to the player's look
                -- at claim time so turning the camera never whips the
                -- whole column around; the column itself still tracks
                -- the player every frame.
                local look = rootPart.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)

                if flat.Magnitude < 0.05 then
                        flat = Vector3.new(0, 0, -1)
                end

                local ringAngle = math.random() * math.pi * 2
                local ringDistance = SLAM_RING_MIN
                        + math.random() * (SLAM_RING_MAX - SLAM_RING_MIN)

                local rec = {
                        angle = math.random() * math.pi * 2,
                        radius = VORTEX_MIN_RADIUS
                                + math.random() * (VORTEX_MAX_RADIUS - VORTEX_MIN_RADIUS),
                        angular = VORTEX_MIN_SPEED
                                + math.random() * (VORTEX_MAX_SPEED - VORTEX_MIN_SPEED),
                        spinAxis = randomUnit(),
                        spinPhase = math.random() * math.pi * 2,
                        spinSpeed = SPIN_MIN_SPEED
                                + math.random() * (SPIN_MAX_SPEED - SPIN_MIN_SPEED),
                        liftT = math.random() * VORTEX_LIFT_CYCLE,
                        liftCycle = 0,
                        nextFlingAt = os.clock()
                                + math.random() * FLING_MAX_SECS,
                        columnDir = flat.Unit,
                        ringOffset = Vector3.new(
                                math.cos(ringAngle) * ringDistance,
                                0,
                                math.sin(ringAngle) * ringDistance
                        ),
                        phase = 0,
                        phaseT = math.random() * 0.5
                }

                if modeUsesPuppet() then
                        rec.rig = buildPuppet(root)
                end

                claimedRoots[root] = rec
        end

        local function releaseStormRoot(root)
                local rec = claimedRoots[root]

                if not rec then
                        return
                end

                claimedRoots[root] = nil

                -- No part properties are ever saved or restored on
                -- vehicles: released mid-flight with whatever velocity
                -- they already carry, exactly how they should be.
                if rec.rig then
                        pcall(function()
                                rec.rig.align:Destroy()
                                rec.rig.orient:Destroy()
                                rec.rig.attachment:Destroy()
                                rec.rig.target:Destroy()
                        end)
                end
        end

        local function isStormableVehicleRoot(root)
                if not root
                        or not root:IsA("BasePart")
                        or not root.Parent
                        or root.AssemblyRootPart ~= root then
                        return false
                end

                -- Anchored means the server holds it static and no
                -- client can ever move it for real - counted and
                -- skipped, never faked.
                if root.Anchored then
                        anchoredSkipped += 1
                        return false
                end

                if EXCLUDED_NAMES[root.Name] then
                        return false
                end

                -- Giant slabs: oceans, tsunami water, lava planes.
                local size = root.Size

                if size.X > MAX_DIMENSION
                        or size.Y > MAX_DIMENSION
                        or size.Z > MAX_DIMENSION then
                        return false
                end

                -- Burning wrecks: NDS fire rides on parts as a Fire
                -- child, and dragging one through us would set us on
                -- fire.
                if root:FindFirstChildOfClass("Fire") then
                        return false
                end

                -- Characters, NPCs, tools and accessories are never
                -- ours: walk the ancestors and bail on any humanoid
                -- rig or gear. The driver is never excluded by this -
                -- they are welded INTO the car assembly, not parented
                -- under it.
                local target = root.Parent

                while target and target ~= Workspace and target ~= game do
                        if target:IsA("Accessory") or target:IsA("Tool") then
                                return false
                        end

                        if target:IsA("Model")
                                and (target:FindFirstChildOfClass("Humanoid")
                                        or target:FindFirstChildOfClass("AnimationController")) then
                                return false
                        end

                        target = target.Parent
                end

                if LocalPlayer.Character
                        and root:IsDescendantOf(LocalPlayer.Character) then
                        return false
                end

                if VehicleSettings.CurrentModel
                        and VehicleSettings.CurrentModel.Parent
                        and root:IsDescendantOf(VehicleSettings.CurrentModel) then
                        return false
                end

                local held = ObjectHoldSettings.Root

                if held and held.Parent and root == held then
                        return false
                end

                if ObjectPull.IsClaimed and ObjectPull.IsClaimed(root) then
                        return false
                end

                if Shaker.IsClaimed and Shaker.IsClaimed(root) then
                        return false
                end

                return assemblyIsVehicle(root)
        end

        local function updateStormStatusCounts()
                -- ReceiveAge is zero only on assemblies our client
                -- actually simulates, so this counts what is really
                -- being driven versus merely claimed.
                local held = 0
                local contested = 0

                for root in pairs(claimedRoots) do
                        if root.Parent then
                                if root.ReceiveAge == 0 then
                                        held += 1
                                else
                                        contested += 1
                                end
                        end
                end

                local mode = MODES[VehicleStormSettings.Mode]
                local suffix = VehicleStormSettings.SimBoost
                        and ""
                        or " (no sim boost - executor limited)"

                if held + contested == 0 then
                        local anchoredNote = ""

                        if anchoredSkipped > 0 then
                                anchoredNote = " ("
                                        .. anchoredSkipped
                                        .. " anchored ignored)"
                        end

                        updateStormStatus(
                                mode
                                        .. ": no vehicles within "
                                        .. STORM_RADIUS
                                        .. " studs"
                                        .. anchoredNote
                                        .. suffix
                        )
                        return
                end

                local verb = "held"

                if mode == "Vortex" then
                        verb = "orbiting"
                elseif mode == "Fling" then
                        verb = "launching"
                elseif mode == "Slam" then
                        verb = "slamming"
                elseif mode == "Freeze" then
                        verb = "frozen"
                end

                local text = mode .. ": " .. held .. " " .. verb

                if contested > 0 then
                        text = text .. " + " .. contested .. " contested"
                end

                updateStormStatus(text .. suffix)
        end

        local function updateVehicleStorm(deltaTime)
                if not running or not VehicleStormSettings.Enabled then
                        return
                end

                local character = LocalPlayer.Character
                local rootPart = character
                        and character:FindFirstChild("HumanoidRootPart")

                if not rootPart or not rootPart.Parent then
                        updateStormStatus("Character unavailable")
                        return
                end

                local now = os.clock()
                local dt = math.clamp(tonumber(deltaTime) or 1 / 60, 0.001, 0.25)

                frameTick += 1

                assertSelfBoost()

                if now >= (VehicleStormSettings.NextEnvAt or 0) then
                        VehicleStormSettings.NextEnvAt = now + ENV_INTERVAL
                        applyStormEnvironment(rootPart)
                end

                local center = rootPart.Position

                if now >= (VehicleStormSettings.NextScanAt or 0) then
                        VehicleStormSettings.NextScanAt = now + SCAN_INTERVAL
                        anchoredSkipped = 0

                        -- Release pass first: destroyed wrecks and cars
                        -- flung past the storm's edge are let go
                        -- mid-flight with the velocity they carry.
                        local limit = (STORM_RADIUS + RELEASE_SLACK)
                                * (STORM_RADIUS + RELEASE_SLACK)

                        for root in pairs(claimedRoots) do
                                if not root.Parent then
                                        releaseStormRoot(root)
                                else
                                        local offset = root.Position - center

                                        if offset:Dot(offset) > limit then
                                                releaseStormRoot(root)
                                        end
                                end
                        end

                        -- Claim pass: one spatial query over the bubble
                        -- mapped onto assembly roots, so every car
                        -- arrives as one connected piece, driver
                        -- included.
                        local found = Workspace:GetPartBoundsInRadius(
                                center,
                                STORM_RADIUS,
                                overlapParams
                        )

                        for _, part in ipairs(found) do
                                local root = part.AssemblyRootPart

                                if root
                                        and not claimedRoots[root]
                                        and isStormableVehicleRoot(root) then
                                        local offset = root.Position - center

                                        if offset:Dot(offset) <= STORM_RADIUS * STORM_RADIUS then
                                                claimStormRoot(root, rootPart)
                                        end
                                end
                        end

                        updateStormStatusCounts()
                end

                local mode = MODES[VehicleStormSettings.Mode]
                local poke = frameTick % POKE_INTERVAL == 0

                for root, rec in pairs(claimedRoots) do
                        if not root.Parent then
                                releaseStormRoot(root)
                        elseif (mode == "Vortex" or mode == "Slam")
                                and (not rec.rig or not rec.rig.target.Parent) then
                                -- A missing or destroyed puppet (some
                                -- games sweep the workspace client-side)
                                -- is released so the next scan rebuilds
                                -- a fresh rig instead of erroring.
                                releaseStormRoot(root)
                        elseif mode == "Vortex" then
                                rec.angle += rec.angular * dt
                                rec.liftT += dt
                                rec.spinPhase += rec.spinSpeed * dt

                                -- Every lift cycle the orbit is
                                -- re-thrown onto a fresh radius and
                                -- speed, so the tornado never settles
                                -- into one hypnotic ring.
                                local cycle = math.floor(rec.liftT / VORTEX_LIFT_CYCLE)

                                if cycle ~= rec.liftCycle then
                                        rec.liftCycle = cycle
                                        rec.radius = VORTEX_MIN_RADIUS
                                                + math.random()
                                                        * (VORTEX_MAX_RADIUS - VORTEX_MIN_RADIUS)
                                        rec.angular = VORTEX_MIN_SPEED
                                                + math.random()
                                                        * (VORTEX_MAX_SPEED - VORTEX_MIN_SPEED)
                                end

                                local radial = Vector3.new(
                                        math.cos(rec.angle),
                                        0,
                                        math.sin(rec.angle)
                                )
                                local height = VORTEX_LIFT_MIN
                                        + VORTEX_LIFT_SPAN
                                        * ((rec.liftT % VORTEX_LIFT_CYCLE) / VORTEX_LIFT_CYCLE)

                                rec.rig.target.CFrame = CFrame.new(
                                        center
                                                + radial * rec.radius
                                                + Vector3.new(0, height, 0)
                                ) * CFrame.fromAxisAngle(rec.spinAxis, rec.spinPhase)

                                if poke and root.ReceiveAge == 0 then
                                        pcall(function()
                                                root.AssemblyLinearVelocity = ANTI_SLEEP
                                        end)
                                end
                        elseif mode == "Slam" then
                                rec.phaseT += dt
                                rec.spinPhase += rec.spinSpeed * dt

                                if rec.phase == 0 then
                                        if rec.phaseT >= SLAM_UP_SECS then
                                                rec.phase = 1
                                                rec.phaseT = 0
                                        end
                                else
                                        if rec.phaseT >= SLAM_DOWN_SECS then
                                                rec.phase = 0
                                                rec.phaseT = 0
                                        end
                                end

                                local span = rec.phase == 0
                                        and SLAM_UP_SECS
                                        or SLAM_DOWN_SECS
                                local progress = math.clamp(rec.phaseT / span, 0, 1)
                                local height = rec.phase == 0
                                        and SLAM_UP_HEIGHT * progress
                                        or SLAM_UP_HEIGHT * (1 - progress)

                                local columnBase = center
                                        + rec.columnDir * SLAM_COLUMN_DISTANCE
                                        + rec.ringOffset

                                rec.rig.target.CFrame = CFrame.new(
                                        columnBase + Vector3.new(0, height, 0)
                                ) * CFrame.fromAxisAngle(rec.spinAxis, rec.spinPhase)

                                if poke and root.ReceiveAge == 0 then
                                        pcall(function()
                                                root.AssemblyLinearVelocity = ANTI_SLEEP
                                        end)
                                end
                        elseif mode == "Fling" then
                                if now >= (rec.nextFlingAt or 0) then
                                        rec.nextFlingAt = now + FLING_MIN_SECS
                                                + math.random()
                                                        * (FLING_MAX_SECS - FLING_MIN_SECS)

                                        -- One big impulse per beat, then
                                        -- hands off so it actually flies.
                                        -- The ReceiveAge gate means the
                                        -- write only ever lands on an
                                        -- assembly we truly simulate -
                                        -- no local-only theatre.
                                        if root.ReceiveAge == 0 then
                                                local side = randomUnit()
                                                local flat = Vector3.new(side.X, 0, side.Z)

                                                if flat.Magnitude < 0.05 then
                                                        flat = Vector3.new(1, 0, 0)
                                                end

                                                local speed = FLING_SIDE_MIN
                                                        + math.random()
                                                                * (FLING_SIDE_MAX - FLING_SIDE_MIN)
                                                local lift = FLING_UP_MIN
                                                        + math.random()
                                                                * (FLING_UP_MAX - FLING_UP_MIN)

                                                pcall(function()
                                                        root.AssemblyLinearVelocity =
                                                                flat.Unit * speed
                                                                + Vector3.new(0, lift, 0)
                                                        root.AssemblyAngularVelocity = randomUnit()
                                                                * (FLING_SPIN_MIN
                                                                        + math.random()
                                                                                * (FLING_SPIN_MAX - FLING_SPIN_MIN))
                                                end)
                                        end
                                end
                        elseif mode == "Freeze" then
                                -- Zeroing velocity every frame on an
                                -- assembly we simulate is a real freeze:
                                -- gravity's per-step gain is cancelled
                                -- before it can ever show.
                                if root.ReceiveAge == 0 then
                                        pcall(function()
                                                root.AssemblyLinearVelocity = Vector3.zero
                                                root.AssemblyAngularVelocity = Vector3.zero
                                        end)
                                end
                        end
                end
        end

        local function stopVehicleStorm()
                disconnect(VehicleStormSettings.Connection)
                VehicleStormSettings.Connection = nil
                VehicleStormSettings.NextEnvAt = 0
                VehicleStormSettings.NextScanAt = 0

                for root in pairs(claimedRoots) do
                        releaseStormRoot(root)
                end

                if stormFolder then
                        local folder = stormFolder
                        stormFolder = nil

                        pcall(function()
                                folder:Destroy()
                        end)
                end

                restoreStormEnvironment()
        end

        -- Shared with the pull and shaker so the three engines never
        -- claim the same assembly and fight over it.
        VehicleStorm.IsClaimed = function(root)
                return claimedRoots[root] ~= nil
        end

        VehicleStorm.getModeName = function()
                return MODES[VehicleStormSettings.Mode] or MODES[1]
        end

        VehicleStorm.cycleMode = function()
                VehicleStormSettings.Mode = (VehicleStormSettings.Mode % #MODES) + 1

                if VehicleStormSettings.Enabled then
                        -- Claims are released so the next scan re-claims
                        -- every car with the rig the new mode needs:
                        -- puppet modes build targets, velocity modes
                        -- stay rig-free.
                        for root in pairs(claimedRoots) do
                                releaseStormRoot(root)
                        end

                        VehicleStormSettings.NextScanAt = 0
                        updateStormStatus(VehicleStorm.getModeName() .. ": scanning...")
                else
                        updateStormStatus(
                                "Vehicle Storm off - mode "
                                        .. VehicleStorm.getModeName()
                        )
                end
        end

        VehicleStorm.setEnabled = function(value)
                local enabled = value and true or false

                stopVehicleStorm()
                VehicleStormSettings.Enabled = enabled

                if type(VehicleStorm.OnEnabledChanged) == "function" then
                        pcall(VehicleStorm.OnEnabledChanged, enabled)
                end

                if not enabled then
                        updateStormStatus(
                                "Vehicle Storm off - mode "
                                        .. VehicleStorm.getModeName()
                        )
                        return
                end

                local rootPart = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                if rootPart and rootPart.Parent then
                        applyStormEnvironment(rootPart)
                end

                if not stormFolder then
                        stormFolder = Instance.new("Folder")
                        stormFolder.Name = "__VehicleStormRuntime"
                        stormFolder.Parent = Workspace
                end

                VehicleStormSettings.NextScanAt = 0

                updateStormStatus(
                        VehicleStorm.getModeName() .. ": scanning for vehicles..."
                )

                VehicleStormSettings.Connection = RunService.Heartbeat:Connect(
                        function(deltaTime)
                                local ok, err = pcall(updateVehicleStorm, deltaTime)

                                if not ok then
                                        updateStormStatus(
                                                "Engine error: "
                                                        .. tostring(err):sub(1, 80)
                                        )
                                end
                        end
                )
        end
end

buildVehicleStorm()

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
        clearPlatform()
        ObjectHoldSettings.Enabled = false
        pcall(function()
                ObjectHold.setEnabled(false)
        end)
        ObjectPullSettings.Enabled = false
        pcall(function()
                ObjectPull.setEnabled(false)
        end)
        ShakerSettings.Enabled = false
        pcall(function()
                Shaker.setEnabled(false)
        end)
        VehicleStorm.Settings.Enabled = false
        pcall(function()
                VehicleStorm.setEnabled(false)
        end)
        clearNoclip()
        stopFling()
        disableAntiFling()
        FlySettings.Enabled = false
        stopFlyRuntime()
        VehicleFlySettings.Enabled = false
        stopVehicleFlyRuntime()
        VehicleFlingSettings.Enabled = false
        VehicleFlingSettings.WorkerToken += 1
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
FunTab:SetColumns(2)

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
local ObjectHoverSection = FunTab:Section("Object Hover")

local objectHoverStatusLabel = ObjectHoverSection:Paragraph({
        Text = "Object Hover off"
})

ObjectHold.OnStatusChanged = function(status)
        objectHoverStatusLabel:Set(tostring(status or "Object Hover off"))
end

local objectHoverToggleValue = false
local objectHoverToggle = ObjectHoverSection:Toggle({
        Text = "Enable Object Hover",
        Value = false,
        Callback = function(value)
                objectHoverToggleValue = value and true or false
                ObjectHold.setEnabled(objectHoverToggleValue)
        end
})

ObjectHold.OnEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if objectHoverToggleValue == desiredValue then
                return
        end

        objectHoverToggleValue = desiredValue
        objectHoverToggle:Set(desiredValue)
end

ObjectHoverSection:Button({
        Text = "Release Object",
        Callback = function()
                ObjectHold.release()
        end
})

ObjectHoverSection:Slider({
        Text = "Hold Snappiness",
        Min = 10,
        Max = 60,
        Value = ObjectHoldSettings.Responsiveness,
        Callback = function(value)
                ObjectHoldSettings.Responsiveness = value

                local rig = ObjectHoldSettings.Rig

                if rig and rig.AlignPosition then
                        pcall(function()
                                rig.AlignPosition.Responsiveness = math.clamp(
                                        tonumber(value) or 35,
                                        5,
                                        100
                                )
                        end)
                end
        end
})

local ObjectPullSection = FunTab:Section("Object Pull")

local objectPullStatusLabel = ObjectPullSection:Paragraph({
        Text = "Object Pull off"
})

ObjectPull.OnStatusChanged = function(status)
        objectPullStatusLabel:Set(tostring(status or "Object Pull off"))
end

local objectPullToggleValue = false
local objectPullToggle = ObjectPullSection:Toggle({
        Text = "Enable Object Pull",
        Value = false,
        Callback = function(value)
                objectPullToggleValue = value and true or false
                ObjectPull.setEnabled(objectPullToggleValue)
        end
})

ObjectPull.OnEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if objectPullToggleValue == desiredValue then
                return
        end

        objectPullToggleValue = desiredValue
        objectPullToggle:Set(desiredValue)
end

ObjectPullSection:Slider({
        Text = "Keep Distance",
        Min = 3,
        Max = 50,
        Value = ObjectPullSettings.KeepDistance,
        Callback = function(value)
                ObjectPullSettings.KeepDistance = tonumber(value) or 7
        end
})

local ObjectShakerSection = FunTab:Section("Object Shaker")

local objectShakerStatusLabel = ObjectShakerSection:Paragraph({
        Text = "Object Shaker off"
})

Shaker.OnStatusChanged = function(status)
        objectShakerStatusLabel:Set(tostring(status or "Object Shaker off"))
end

local objectShakerToggleValue = false
local objectShakerToggle = ObjectShakerSection:Toggle({
        Text = "Enable Object Shaker",
        Value = false,
        Callback = function(value)
                objectShakerToggleValue = value and true or false
                Shaker.setEnabled(objectShakerToggleValue)
        end
})

Shaker.OnEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if objectShakerToggleValue == desiredValue then
                return
        end

        objectShakerToggleValue = desiredValue
        objectShakerToggle:Set(desiredValue)
end
end

do
local VehicleStormSection = FunTab:Section("Vehicle Storm")

local vehicleStormStatusLabel = VehicleStormSection:Paragraph({
        Text = "Vehicle Storm off"
})

VehicleStorm.OnStatusChanged = function(status)
        vehicleStormStatusLabel:Set(tostring(status or "Vehicle Storm off"))
end

VehicleStormSection:Button({
        Text = "Next Mode",
        Callback = function()
                VehicleStorm.cycleMode()
        end
})

local vehicleStormToggleValue = false
local vehicleStormToggle = VehicleStormSection:Toggle({
        Text = "Enable Vehicle Storm",
        Value = false,
        Callback = function(value)
                vehicleStormToggleValue = value and true or false
                VehicleStorm.setEnabled(vehicleStormToggleValue)
        end
})

VehicleStorm.OnEnabledChanged = function(enabled)
        local desiredValue = enabled and true or false

        if vehicleStormToggleValue == desiredValue then
                return
        end

        vehicleStormToggleValue = desiredValue
        vehicleStormToggle:Set(desiredValue)
end
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

                        if FlingSettings.Mover then
                                pcall(function()
                                        FlingSettings.Mover.AngularVelocity =
                                                Vector3.new(0, getFlingSpin(), 0)
                                end)
                        end
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

        if ObjectHoldSettings.Enabled
                and os.clock() - (ObjectHoldSettings.ClickConsumedAt or 0) < 0.05 then
                -- Object Hover consumed this click (grab or drop);
                -- do not also teleport on it.
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
