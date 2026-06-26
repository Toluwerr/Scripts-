local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")

local AIMLOCK_BIND_NAME = "__PlayerToolsAimlock"
local FLY_BIND_NAME = "__PlayerToolsFly"
local VEHICLE_FLY_BIND_NAME = "__PlayerToolsVehicleFly"
local MAP_VIEWER_BIND_NAME = "__PlayerToolsMapViewer"
local MAP_BLOCK_ACTION_NAME = "__PlayerToolsMapBlockMovement"

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

local Google = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Google-UI/refs/heads/main/main.lua"))()
Google.SetTheme("Google")

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

local ColorState = {
	H = 0,
	S = 0,
	V = 1
}

local MovementSettings = {
	Enabled = false,
	Speed = 16,
	InfiniteJump = false,
	Humanoid = nil,
	OriginalSpeed = nil,
	Updating = false,
	WatchConnection = nil
}

local AimlockSettings = {
	Enabled = false,
	TeamCheck = true,
	Holding = false,
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
	LastTeleport = 0
}

local MapViewerSettings = {
	Enabled = false,
	Viewport = nil,
	Camera = nil,
	WorldModel = nil,
	RenderModel = nil,
	BoundsMin = nil,
	BoundsMax = nil,
	Position = nil,
	Yaw = 0,
	Pitch = 0,
	MoveSpeed = 100,
	MouseBehavior = nil,
	MouseIconEnabled = nil,
	WorldCamera = nil,
	WorldCameraType = nil,
	WorldCameraSubject = nil
}

local stopVehicleFlyRuntime
local restartVehicleFly
local stopMapViewerRuntime

local HIGHLIGHT_NAME = "__ProjectESPHighlight"
local TAG_NAME = "__ProjectESPLabel"
local TEXT_NAME = "__ProjectESPText"

local running = true
local connections = {}
local activePicker = nil
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

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
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

local function getPlayerFromInstance(instance)
	local current = instance

	while current and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player, current
			end
		end

		current = current.Parent
	end

	return nil, nil
end

local function getPlayerUnderPointer()
	local hit = Mouse.Target

	if not hit then
		local camera = Workspace.CurrentCamera
		if camera then
			local mouseLocation = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.IgnoreWater = true
			params.FilterDescendantsInstances = {LocalPlayer.Character}

			local result = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
			hit = result and result.Instance or nil
		end
	end

	local player, character = getPlayerFromInstance(hit)

	if not player
		or player == LocalPlayer
		or isAimTeammate(player)
		or not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local targetPart = character:FindFirstChild("Head") or getRoot(character)

	if not humanoid
		or humanoid.Health <= 0
		or not targetPart
		or not targetPart:IsA("BasePart") then
		return nil
	end

	return player, character, humanoid, targetPart
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

local function restoreVehicleSpeed()
	clearVehicleSpeedWatch()
	clearVehicleBoost()
	clearVehicleJumpStabilizer()
	clearVehicleFlipAssist()

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
			stabilizer.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
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
	local ray = camera:ViewportPointToRay(position.X, position.Y)
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

	clearVehicleFlipAssist()

	root.CFrame = desiredRoot
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	VehicleTeleportSettings.LastTeleport = now
end

local function setVehicleTeleportEnabled(value)
	VehicleTeleportSettings.Enabled = value and true or false
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
			part.CanCollide = originalCanCollide
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

			object.CanCollide = false
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

local MapIgnoredNames = {
	character = true,
	characters = true,
	player = true,
	players = true,
	npc = true,
	npcs = true,
	vehicle = true,
	vehicles = true,
	car = true,
	cars = true,
	tool = true,
	tools = true,
	effect = true,
	effects = true,
	camera = true,
	cameras = true,
	debris = true,
	sound = true,
	sounds = true,
	audio = true
}

local MapRootNames = {
	map = true,
	world = true,
	environment = true,
	level = true,
	terrain = true,
	city = true,
	island = true,
	stage = true,
	arena = true
}

local function isMapIgnoredAncestor(instance)
	local current = instance

	while current and current ~= Workspace do
		if MapIgnoredNames[string.lower(current.Name)] then
			return true
		end

		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isMapPartCandidate(part)
	if not part
		or not part:IsA("BasePart")
		or not part.Anchored
		or part:IsA("Seat")
		or part:IsA("VehicleSeat")
		or not part:IsDescendantOf(Workspace) then
		return false
	end

	if LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
		return false
	end

	return not isMapIgnoredAncestor(part.Parent)
end

local function countMapParts(root)
	local count = 0

	for _, object in ipairs(root:GetDescendants()) do
		if isMapPartCandidate(object) then
			count += 1
		end
	end

	return count
end

local function findMapRoot()
	local bestRoot = nil
	local bestScore = 0

	for _, candidate in ipairs(Workspace:GetChildren()) do
		if (candidate:IsA("Model") or candidate:IsA("Folder"))
			and not isMapIgnoredAncestor(candidate)
			and candidate ~= LocalPlayer.Character then
			local count = countMapParts(candidate)

			if count > 0 then
				local name = string.lower(candidate.Name)
				local score = count

				if MapRootNames[name] then
					score += 1000000
				elseif string.find(name, "map", 1, true)
					or string.find(name, "world", 1, true)
					or string.find(name, "environment", 1, true)
					or string.find(name, "level", 1, true) then
					score += 100000
				end

				if score > bestScore then
					bestRoot = candidate
					bestScore = score
				end
			end
		end
	end

	return bestRoot
end

local function collectMapParts()
	local root = findMapRoot()
	local scanRoot = root or Workspace
	local parts = {}

	for _, object in ipairs(scanRoot:GetDescendants()) do
		if isMapPartCandidate(object) then
			table.insert(parts, object)
		end
	end

	return parts
end

local function expandMapBounds(minimum, maximum, part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local right = cframe.RightVector
	local up = cframe.UpVector
	local forward = cframe.LookVector
	local extents = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(forward.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(forward.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(forward.Z) * half.Z
	)
	local low = part.Position - extents
	local high = part.Position + extents

	if not minimum then
		return low, high
	end

	return Vector3.new(
		math.min(minimum.X, low.X),
		math.min(minimum.Y, low.Y),
		math.min(minimum.Z, low.Z)
	), Vector3.new(
		math.max(maximum.X, high.X),
		math.max(maximum.Y, high.Y),
		math.max(maximum.Z, high.Z)
	)
end

local function cloneMapPart(source)
	local clone = nil

	pcall(function()
		clone = source:Clone()
	end)

	if not clone or not clone:IsA("BasePart") then
		clone = Instance.new("Part")
		clone.Size = source.Size
		clone.CFrame = source.CFrame
		clone.Color = source.Color
		clone.Material = source.Material
		clone.Transparency = source.Transparency
		clone.Reflectance = source.Reflectance

		if source:IsA("Part") then
			clone.Shape = source.Shape
		end
	end

	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("Script")
			or object:IsA("LocalScript")
			or object:IsA("ModuleScript")
			or object:IsA("JointInstance")
			or object:IsA("Constraint")
			or object:IsA("Attachment")
			or object:IsA("BodyMover") then
			object:Destroy()
		end
	end

	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CanQuery = false
	clone.Massless = true
	clone.AssemblyLinearVelocity = Vector3.zero
	clone.AssemblyAngularVelocity = Vector3.zero

	return clone
end

local function destroyMapPreview()
	if MapViewerSettings.WorldModel then
		pcall(function()
			MapViewerSettings.WorldModel:Destroy()
		end)
	end

	MapViewerSettings.WorldModel = nil
	MapViewerSettings.RenderModel = nil
	MapViewerSettings.BoundsMin = nil
	MapViewerSettings.BoundsMax = nil
	MapViewerSettings.Position = nil
end

local function setMapCameraFromBounds()
	local camera = MapViewerSettings.Camera
	local minimum = MapViewerSettings.BoundsMin
	local maximum = MapViewerSettings.BoundsMax

	if not camera or not minimum or not maximum then
		return false
	end

	local center = (minimum + maximum) * 0.5
	local size = maximum - minimum
	local largestAxis = math.max(size.X, size.Y, size.Z, 50)
	local distance = math.max(largestAxis * 1.15, 80)
	local position = center + Vector3.new(distance * 0.65, distance * 0.5, distance * 0.65)
	local cframe = CFrame.lookAt(position, center)

	MapViewerSettings.Position = position
	MapViewerSettings.Pitch = math.asin(math.clamp(cframe.LookVector.Y, -1, 1))
	MapViewerSettings.Yaw = math.atan2(-cframe.LookVector.X, -cframe.LookVector.Z)
	MapViewerSettings.MoveSpeed = math.clamp(largestAxis * 0.14, 45, 2000)
	camera.CFrame = cframe

	return true
end

local function buildMapPreview()
	local viewport = MapViewerSettings.Viewport
	local camera = MapViewerSettings.Camera

	if not viewport or not viewport.Parent or not camera then
		return false
	end

	destroyMapPreview()

	local sourceParts = collectMapParts()

	if #sourceParts == 0 then
		return false
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "__PlayerToolsMapWorld"
	worldModel.Parent = viewport

	local renderModel = Instance.new("Model")
	renderModel.Name = "__PlayerToolsMapRender"
	renderModel.Parent = worldModel

	local minimum = nil
	local maximum = nil
	local rendered = 0

	for index, source in ipairs(sourceParts) do
		if source and source.Parent then
			local clone = cloneMapPart(source)

			if clone then
				clone.Parent = renderModel
				minimum, maximum = expandMapBounds(minimum, maximum, source)
				rendered += 1
			end
		end

		if index % 125 == 0 then
			task.wait()
		end
	end

	if rendered == 0 or not minimum or not maximum then
		worldModel:Destroy()
		return false
	end

	MapViewerSettings.WorldModel = worldModel
	MapViewerSettings.RenderModel = renderModel
	MapViewerSettings.BoundsMin = minimum
	MapViewerSettings.BoundsMax = maximum
	viewport.CurrentCamera = camera

	return setMapCameraFromBounds()
end

local function getMapMovementDirection()
	local camera = MapViewerSettings.Camera

	if not camera then
		return Vector3.zero
	end

	local direction = Vector3.zero
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector

	if UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		direction += look
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		direction -= look
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction += right
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction -= right
	end

	if direction.Magnitude > 0.001 then
		return direction.Unit
	end

	return Vector3.zero
end

local function updateMapViewer(deltaTime)
	if not running
		or not MapViewerSettings.Enabled
		or not MapViewerSettings.Camera
		or not MapViewerSettings.Position then
		return
	end

	local humanoid = MovementSettings.Humanoid

	if humanoid and humanoid.Parent then
		humanoid:Move(Vector3.zero, false)
	end

	local direction = getMapMovementDirection()

	if direction.Magnitude > 0 then
		MapViewerSettings.Position += direction
			* MapViewerSettings.MoveSpeed
			* math.max(tonumber(deltaTime) or 0, 0)
	end

	MapViewerSettings.Camera.CFrame = CFrame.new(MapViewerSettings.Position)
		* CFrame.fromOrientation(MapViewerSettings.Pitch, MapViewerSettings.Yaw, 0)
end

local function sinkMapMovement()
	return Enum.ContextActionResult.Sink
end

stopMapViewerRuntime = function()
	pcall(function()
		RunService:UnbindFromRenderStep(MAP_VIEWER_BIND_NAME)
	end)

	pcall(function()
		ContextActionService:UnbindAction(MAP_BLOCK_ACTION_NAME)
	end)

	if MapViewerSettings.WorldCamera
		and MapViewerSettings.WorldCamera.Parent
		and MapViewerSettings.WorldCameraType then
		pcall(function()
			MapViewerSettings.WorldCamera.CameraType = MapViewerSettings.WorldCameraType

			if MapViewerSettings.WorldCameraSubject then
				MapViewerSettings.WorldCamera.CameraSubject = MapViewerSettings.WorldCameraSubject
			end
		end)
	end

	if MapViewerSettings.MouseBehavior then
		UserInputService.MouseBehavior = MapViewerSettings.MouseBehavior
	end

	if MapViewerSettings.MouseIconEnabled ~= nil then
		UserInputService.MouseIconEnabled = MapViewerSettings.MouseIconEnabled
	end

	MapViewerSettings.MouseBehavior = nil
	MapViewerSettings.MouseIconEnabled = nil
	MapViewerSettings.WorldCamera = nil
	MapViewerSettings.WorldCameraType = nil
	MapViewerSettings.WorldCameraSubject = nil
end

local function startMapViewerRuntime()
	if not MapViewerSettings.RenderModel
		or not MapViewerSettings.RenderModel.Parent then
		if not buildMapPreview() then
			return false
		end
	end

	local worldCamera = Workspace.CurrentCamera

	if worldCamera then
		MapViewerSettings.WorldCamera = worldCamera
		MapViewerSettings.WorldCameraType = worldCamera.CameraType
		MapViewerSettings.WorldCameraSubject = worldCamera.CameraSubject
		worldCamera.CameraType = Enum.CameraType.Scriptable
	end

	MapViewerSettings.MouseBehavior = UserInputService.MouseBehavior
	MapViewerSettings.MouseIconEnabled = UserInputService.MouseIconEnabled
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	ContextActionService:BindActionAtPriority(
		MAP_BLOCK_ACTION_NAME,
		sinkMapMovement,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Space,
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.RightControl
	)

	pcall(function()
		RunService:UnbindFromRenderStep(MAP_VIEWER_BIND_NAME)
	end)

	RunService:BindToRenderStep(
		MAP_VIEWER_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 4,
		updateMapViewer
	)

	return true
end

local function setMapViewerEnabled(value)
	local enabled = value and true or false

	if MapViewerSettings.Enabled == enabled then
		return
	end

	MapViewerSettings.Enabled = enabled

	if not enabled then
		stopMapViewerRuntime()
		return
	end

	if not startMapViewerRuntime() then
		MapViewerSettings.Enabled = false
		stopMapViewerRuntime()
	end
end

local function cleanup()
	if not running then
		return
	end

	running = false
	Settings.Enabled = false
	AimlockSettings.Enabled = false
	FlingSettings.Enabled = false
	FlingSettings.WorkerToken += 1
	disableAntiFling()
	FlySettings.Enabled = false
	stopFlyRuntime()
	VehicleFlySettings.Enabled = false
	stopVehicleFlyRuntime()
	VehicleTeleportSettings.Enabled = false
	MapViewerSettings.Enabled = false
	stopMapViewerRuntime()
	destroyMapPreview()
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

	pcall(function()
		RunService:UnbindFromRenderStep(MAP_VIEWER_BIND_NAME)
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
end

Global.__PlayerToolsCleanup = cleanup
Global.__AxiomCleanup = cleanup
Global.__ProjectESPCleanup = cleanup

for _, player in ipairs(Players:GetPlayers()) do
	removeESP(player.Character)
end

bindMovementCharacter(LocalPlayer.Character)

local Window = Google:CreateWindow({
	Title = "PlayerTools",
	Icon = "eye",
	Size = UDim2.fromOffset(620, 420)
})

local ESPTab = Window:AddTab({
	Name = "ESP",
	Icon = "eye"
})

local MovementTab = Window:AddTab({
	Name = "Movement",
	Icon = "user"
})

local VehicleMovementTab = Window:AddTab({
	Name = "Vehicle Movment",
	Icon = "settings"
})

local MapTab = Window:AddTab({
	Name = "Map",
	Icon = "image"
})

local MapSection = MapTab:AddSection({
	Name = "3D Map"
})

local mapViewerCard = Instance.new("Frame")
mapViewerCard.Name = "MapViewer"
mapViewerCard.Size = UDim2.new(1, 0, 0, 286)
mapViewerCard.LayoutOrder = -10
mapViewerCard.BackgroundColor3 = Google.Theme.CardAlt
mapViewerCard.BorderSizePixel = 0
mapViewerCard.ClipsDescendants = true
mapViewerCard.Parent = MapSection.Content
addCorner(mapViewerCard, 10)
addStroke(mapViewerCard, Google.Theme.Border, 0.2)

local mapViewport = Instance.new("ViewportFrame")
mapViewport.Name = "MapViewport"
mapViewport.Size = UDim2.new(1, -16, 1, -16)
mapViewport.Position = UDim2.fromOffset(8, 8)
mapViewport.BackgroundColor3 = Google.Theme.CardAlt
mapViewport.BorderSizePixel = 0
mapViewport.Ambient = Color3.fromRGB(170, 170, 170)
mapViewport.LightColor = Color3.fromRGB(255, 255, 255)
mapViewport.LightDirection = Vector3.new(-1, -1, -0.5)
mapViewport.Parent = mapViewerCard
addCorner(mapViewport, 8)

local mapCamera = Instance.new("Camera")
mapCamera.Name = "MapCamera"
mapCamera.FieldOfView = 70
mapCamera.Parent = mapViewport
mapViewport.CurrentCamera = mapCamera
MapViewerSettings.Viewport = mapViewport
MapViewerSettings.Camera = mapCamera

local mapViewerToggle = MapSection:AddToggle({
	Name = "Enable Map View",
	Default = false,
	Callback = function(value)
		setMapViewerEnabled(value)
	end
})
mapViewerToggle.Instance.LayoutOrder = 1

local MainSection = ESPTab:AddSection({
	Name = "Player ESP",
})

MainSection:AddToggle({
	Name = "Enable ESP",
	Default = false,
	Callback = function(value)
		Settings.Enabled = value
		refreshAll()
	end
})

MainSection:AddToggle({
	Name = "Team Check",
	Default = true,
	Callback = function(value)
		Settings.TeamCheck = value
		refreshAll()
	end
})

MainSection:AddToggle({
	Name = "Through Walls",
	Default = true,
	Callback = function(value)
		Settings.ThroughWalls = value
		refreshAll()
	end
})

local LabelSection = ESPTab:AddSection({
	Name = "ESP Elements",
})

LabelSection:AddToggle({
	Name = "Highlight",
	Default = true,
	Callback = function(value)
		Settings.Highlight = value
		refreshAll()
	end
})

LabelSection:AddToggle({
	Name = "Show Name",
	Default = true,
	Callback = function(value)
		Settings.ShowName = value
		refreshAll()
	end
})

LabelSection:AddToggle({
	Name = "Show Health",
	Default = true,
	Callback = function(value)
		Settings.ShowHealth = value
		refreshAll()
	end
})

LabelSection:AddToggle({
	Name = "Show Distance",
	Default = true,
	Callback = function(value)
		Settings.ShowDistance = value
		refreshAll()
	end
})

local StyleSection = ESPTab:AddSection({
	Name = "Style",
})

local picker = Instance.new("Frame")
picker.Name = "HSVColorPicker"
picker.Size = UDim2.new(1, 0, 0, 218)
picker.LayoutOrder = -10
picker.BackgroundColor3 = Google.Theme.CardAlt
picker.BorderSizePixel = 0
picker.Parent = StyleSection.Content
addCorner(picker, 10)
local pickerStroke = addStroke(picker, Google.Theme.Border, 0.2)

local paletteIcon = Google.CreateIcon("palette", 16, Google.Theme.Primary, picker, {
	Position = UDim2.fromOffset(12, 11)
})

local pickerTitle = Instance.new("TextLabel")
pickerTitle.BackgroundTransparency = 1
pickerTitle.Position = UDim2.fromOffset(36, 10)
pickerTitle.Size = UDim2.new(1, -96, 0, 18)
pickerTitle.Font = Enum.Font.GothamBold
pickerTitle.Text = "ESP Color"
pickerTitle.TextSize = 13
pickerTitle.TextColor3 = Google.Theme.Text
pickerTitle.TextTruncate = Enum.TextTruncate.AtEnd
pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
pickerTitle.Parent = picker

local colorPreview = Instance.new("Frame")
colorPreview.Size = UDim2.fromOffset(38, 26)
colorPreview.Position = UDim2.new(1, -50, 0, 8)
colorPreview.BackgroundColor3 = Settings.Color
colorPreview.BorderSizePixel = 0
colorPreview.ZIndex = 3
colorPreview.Parent = picker
addCorner(colorPreview, 8)
local colorPreviewStroke = addStroke(colorPreview, Google.Theme.Border, 0.15)

local colorReadout = Instance.new("TextLabel")
colorReadout.BackgroundTransparency = 1
colorReadout.Position = UDim2.fromOffset(12, 30)
colorReadout.Size = UDim2.new(1, -80, 0, 16)
colorReadout.Font = Enum.Font.Gotham
colorReadout.TextSize = 12
colorReadout.TextColor3 = Google.Theme.Muted
colorReadout.TextTruncate = Enum.TextTruncate.AtEnd
colorReadout.TextXAlignment = Enum.TextXAlignment.Left
colorReadout.Parent = picker

local colorSquare = Instance.new("Frame")
colorSquare.Size = UDim2.new(1, -56, 0, 144)
colorSquare.Position = UDim2.fromOffset(12, 58)
colorSquare.BackgroundTransparency = 1
colorSquare.BorderSizePixel = 0
colorSquare.ClipsDescendants = true
colorSquare.Parent = picker
addCorner(colorSquare, 10)
local colorSquareStroke = addStroke(colorSquare, Google.Theme.Border, 0.2)

local colorVisual = Instance.new("Frame")
colorVisual.Size = UDim2.fromScale(1, 1)
colorVisual.BackgroundTransparency = 0
colorVisual.BackgroundColor3 = Color3.fromHSV(ColorState.H, 1, 1)
colorVisual.BorderSizePixel = 0
colorVisual.ClipsDescendants = true
colorVisual.Parent = colorSquare
addCorner(colorVisual, 10)

local saturationLayer = Instance.new("Frame")
saturationLayer.Size = UDim2.fromScale(1, 1)
saturationLayer.BackgroundColor3 = Color3.new(1, 1, 1)
saturationLayer.BorderSizePixel = 0
saturationLayer.Parent = colorVisual
addCorner(saturationLayer, 10)

local saturationGradient = Instance.new("UIGradient")
saturationGradient.Rotation = 0
saturationGradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
saturationGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1)
})
saturationGradient.Parent = saturationLayer

local valueLayer = Instance.new("Frame")
valueLayer.Size = UDim2.fromScale(1, 1)
valueLayer.BackgroundColor3 = Color3.new(0, 0, 0)
valueLayer.BorderSizePixel = 0
valueLayer.Parent = colorVisual
addCorner(valueLayer, 10)

local valueGradient = Instance.new("UIGradient")
valueGradient.Rotation = 90
valueGradient.Color = ColorSequence.new(Color3.new(0, 0, 0))
valueGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0)
})
valueGradient.Parent = valueLayer

local colorSquareInput = Instance.new("TextButton")
colorSquareInput.BackgroundTransparency = 1
colorSquareInput.Size = UDim2.fromScale(1, 1)
colorSquareInput.Text = ""
colorSquareInput.AutoButtonColor = false
colorSquareInput.Active = true
colorSquareInput.ZIndex = 3
colorSquareInput.Parent = colorSquare

local colorCursorOuter = Instance.new("Frame")
colorCursorOuter.AnchorPoint = Vector2.new(0.5, 0.5)
colorCursorOuter.Size = UDim2.fromOffset(16, 16)
colorCursorOuter.BackgroundColor3 = Google.Theme.Text
colorCursorOuter.BorderSizePixel = 0
colorCursorOuter.ZIndex = 4
colorCursorOuter.Parent = colorSquare
addCorner(colorCursorOuter, 99)

local colorCursorInner = Instance.new("Frame")
colorCursorInner.AnchorPoint = Vector2.new(0.5, 0.5)
colorCursorInner.Position = UDim2.fromScale(0.5, 0.5)
colorCursorInner.Size = UDim2.fromOffset(12, 12)
colorCursorInner.BackgroundColor3 = Google.Theme.Card
colorCursorInner.BorderSizePixel = 0
colorCursorInner.ZIndex = 5
colorCursorInner.Parent = colorCursorOuter
addCorner(colorCursorInner, 99)

local hueBar = Instance.new("Frame")
hueBar.Size = UDim2.fromOffset(28, 144)
hueBar.Position = UDim2.new(1, -40, 0, 58)
hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
hueBar.BorderSizePixel = 0
hueBar.ClipsDescendants = true
hueBar.Parent = picker
addCorner(hueBar, 10)
local hueBarStroke = addStroke(hueBar, Google.Theme.Border, 0.2)

local hueGradient = Instance.new("UIGradient")
hueGradient.Rotation = 90
hueGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
	ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
	ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
	ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
	ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
})
hueGradient.Parent = hueBar

local hueInput = Instance.new("TextButton")
hueInput.BackgroundTransparency = 1
hueInput.Size = UDim2.fromScale(1, 1)
hueInput.Text = ""
hueInput.AutoButtonColor = false
hueInput.Active = true
hueInput.ZIndex = 3
hueInput.Parent = hueBar

local hueMarker = Instance.new("Frame")
hueMarker.AnchorPoint = Vector2.new(0.5, 0.5)
hueMarker.Size = UDim2.new(1, 0, 0, 4)
hueMarker.BackgroundColor3 = Google.Theme.Card
hueMarker.BorderSizePixel = 0
hueMarker.ZIndex = 4
hueMarker.Parent = hueBar
addCorner(hueMarker, 99)
local hueMarkerStroke = addStroke(hueMarker, Google.Theme.Text, 0)

local function updateColorPicker()
	local color = Color3.fromHSV(ColorState.H, ColorState.S, ColorState.V)

	Settings.Color = color
	colorPreview.BackgroundColor3 = color
	colorVisual.BackgroundColor3 = Color3.fromHSV(ColorState.H, 1, 1)

	local colorWidth = math.max(colorSquare.AbsoluteSize.X, 1)
	local colorHeight = math.max(colorSquare.AbsoluteSize.Y, 1)
	local cursorHalfX = colorCursorOuter.AbsoluteSize.X > 0 and (colorCursorOuter.AbsoluteSize.X * 0.5) or 8
	local cursorHalfY = colorCursorOuter.AbsoluteSize.Y > 0 and (colorCursorOuter.AbsoluteSize.Y * 0.5) or 8
	local cursorScaleX = math.clamp(ColorState.S, cursorHalfX / colorWidth, 1 - (cursorHalfX / colorWidth))
	local cursorScaleY = math.clamp(1 - ColorState.V, cursorHalfY / colorHeight, 1 - (cursorHalfY / colorHeight))
	colorCursorOuter.Position = UDim2.fromScale(cursorScaleX, cursorScaleY)

	local hueHeight = math.max(hueBar.AbsoluteSize.Y, 1)
	local hueInset = ((hueMarker.AbsoluteSize.Y > 0 and hueMarker.AbsoluteSize.Y or 4) * 0.5) + 2
	local hueScale = math.clamp(ColorState.H, hueInset / hueHeight, 1 - (hueInset / hueHeight))
	hueMarker.Position = UDim2.new(0.5, 0, hueScale, 0)

	local red = math.floor(color.R * 255 + 0.5)
	local green = math.floor(color.G * 255 + 0.5)
	local blue = math.floor(color.B * 255 + 0.5)

	colorReadout.Text = string.format(
		"#%02X%02X%02X  •  RGB(%d, %d, %d)",
		red,
		green,
		blue,
		red,
		green,
		blue
	)

	refreshAll()
end

local function applyPickerTheme()
	picker.BackgroundColor3 = Google.Theme.CardAlt
	pickerStroke.Color = Google.Theme.Border
	pickerTitle.TextColor3 = Google.Theme.Text
	Google.SetIconColor(paletteIcon, Google.Theme.Primary)
	colorReadout.TextColor3 = Google.Theme.Muted
	colorPreviewStroke.Color = Google.Theme.Border
	colorSquareStroke.Color = Google.Theme.Border
	hueBarStroke.Color = Google.Theme.Border
	colorCursorOuter.BackgroundColor3 = Google.Theme.Text
	colorCursorInner.BackgroundColor3 = Google.Theme.Card
	hueMarker.BackgroundColor3 = Google.Theme.Card
	hueMarkerStroke.Color = Google.Theme.Text
end

local originalWindowApplyTheme = Window.ApplyTheme
function Window:ApplyTheme()
	originalWindowApplyTheme(self)
	applyPickerTheme()
end

local function setSaturationValue(position)
	if colorSquareInput.AbsoluteSize.X <= 0 or colorSquareInput.AbsoluteSize.Y <= 0 then
		return
	end

	ColorState.S = math.clamp(
		(position.X - colorSquareInput.AbsolutePosition.X) / colorSquareInput.AbsoluteSize.X,
		0,
		1
	)

	ColorState.V = 1 - math.clamp(
		(position.Y - colorSquareInput.AbsolutePosition.Y) / colorSquareInput.AbsoluteSize.Y,
		0,
		1
	)

	updateColorPicker()
end

local function setHue(position)
	if hueInput.AbsoluteSize.Y <= 0 then
		return
	end

	ColorState.H = math.clamp(
		(position.Y - hueInput.AbsolutePosition.Y) / hueInput.AbsoluteSize.Y,
		0,
		1
	)

	updateColorPicker()
end

track(colorSquareInput.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		activePicker = "Color"
		setSaturationValue(input.Position)
	end
end))

track(hueInput.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		activePicker = "Hue"
		setHue(input.Position)
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if activePicker == "Color"
		and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
		setSaturationValue(input.Position)
	elseif activePicker == "Hue"
		and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
		setHue(input.Position)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		activePicker = nil
	end
end))

local fillSlider = StyleSection:AddSlider({
	Name = "Fill Opacity",
	Min = 0,
	Max = 100,
	Default = 26,
	Callback = function(value)
		Settings.FillTransparency = 1 - (value / 100)
		refreshAll()
	end
})
fillSlider.Instance.LayoutOrder = 1

local distanceSlider = StyleSection:AddSlider({
	Name = "Maximum Distance",
	Min = 100,
	Max = 5000,
	Default = 1500,
	Callback = function(value)
		Settings.MaxDistance = value
		refreshAll()
	end
})
distanceSlider.Instance.LayoutOrder = 2

local MovementSection = MovementTab:AddSection({
	Name = "Walk Speed",
})

local speedToggle = MovementSection:AddToggle({
	Name = "Enable Speed",
	Default = false,
	Callback = function(value)
		setSpeedEnabled(value)
	end
})
speedToggle.Instance.LayoutOrder = 1

local speedSlider = MovementSection:AddSlider({
	Name = "Walk Speed",
	Min = 0,
	Max = 250,
	Default = 16,
	Callback = function(value)
		MovementSettings.Speed = value
		applySpeed()
	end
})
speedSlider.Instance.LayoutOrder = 2

local normalSpeedButton = MovementSection:AddButton({
	Name = "Set Normal Speed",
	Icon = "refresh-cw",
	Callback = function()
		speedSlider:Set(16)
	end
})
normalSpeedButton.Instance.LayoutOrder = 3

local infiniteJumpToggle = MovementSection:AddToggle({
	Name = "Infinite Jump",
	Default = false,
	Callback = function(value)
		MovementSettings.InfiniteJump = value and true or false
	end
})
infiniteJumpToggle.Instance.LayoutOrder = 4

local FlySection = MovementTab:AddSection({
	Name = "Fly",
})

local flyToggle = FlySection:AddToggle({
	Name = "Enable Fly",
	Default = false,
	Callback = function(value)
		setFlyEnabled(value)
	end
})
flyToggle.Instance.LayoutOrder = 1

local flySpeedSlider = FlySection:AddSlider({
	Name = "Fly Speed",
	Min = 10,
	Max = 250,
	Default = FlySettings.Speed,
	Callback = function(value)
		FlySettings.Speed = value
	end
})
flySpeedSlider.Instance.LayoutOrder = 2

local AimlockSection = MovementTab:AddSection({
	Name = "Aimlock",
})

local aimlockToggle = AimlockSection:AddToggle({
	Name = "Enable Aimlock",
	Default = false,
	Callback = function(value)
		setAimlockEnabled(value)
	end
})
aimlockToggle.Instance.LayoutOrder = 1

local aimTeamToggle = AimlockSection:AddToggle({
	Name = "Team Check",
	Default = true,
	Callback = function(value)
		AimlockSettings.TeamCheck = value
	end
})
aimTeamToggle.Instance.LayoutOrder = 2

aimStatusLabel = AimlockSection:AddLabel({
	Name = "Target: None"
})
aimStatusLabel.Instance.LayoutOrder = 3

local FlingSection = MovementTab:AddSection({
	Name = "Fling",
})

local flingToggle = FlingSection:AddToggle({
	Name = "Fling",
	Default = false,
	Callback = function(value)
		setFlingEnabled(value)
	end
})
flingToggle.Instance.LayoutOrder = 1

local antiFlingToggle = FlingSection:AddToggle({
	Name = "Anti Fling",
	Default = false,
	Callback = function(value)
		setAntiFlingEnabled(value)
	end
})
antiFlingToggle.Instance.LayoutOrder = 2

local flingPowerInput = FlingSection:AddInput({
	Name = "Fling Power",
	Placeholder = "100",
	Default = tostring(FlingSettings.Power),
	ClearButton = false,
	Callback = function(value)
		local parsed = tonumber(value)

		if parsed then
			FlingSettings.Power = math.clamp(parsed, 1, 1000)
		end
	end
})
flingPowerInput.Instance.LayoutOrder = 3

local VehicleSection = VehicleMovementTab:AddSection({
	Name = "Vehicle Speed"
})

local vehicleSpeedSlider = VehicleSection:AddSlider({
	Name = "Vehicle Speed",
	Min = 0,
	Max = 500,
	Default = VehicleSettings.Speed,
	Callback = function(value)
		VehicleSettings.Speed = value
		applyVehicleSeatSpeed()
	end
})
vehicleSpeedSlider.Instance.LayoutOrder = 1

local steeringStrengthSlider = VehicleSection:AddSlider({
	Name = "Steering Strength",
	Min = 0,
	Max = 50,
	Default = VehicleSettings.SteeringStrength,
	Callback = function(value)
		VehicleSettings.SteeringStrength = value
		applyVehicleSeatSteering()
	end
})
steeringStrengthSlider.Instance.LayoutOrder = 2

local VehicleFlySection = VehicleMovementTab:AddSection({
	Name = "Vehicle Fly"
})

local vehicleFlyToggle = VehicleFlySection:AddToggle({
	Name = "Enable Vehicle Fly",
	Default = false,
	Callback = function(value)
		setVehicleFlyEnabled(value)
	end
})
vehicleFlyToggle.Instance.LayoutOrder = 1

local vehicleFlySpeedSlider = VehicleFlySection:AddSlider({
	Name = "Vehicle Fly Speed",
	Min = 10,
	Max = 250,
	Default = VehicleFlySettings.Speed,
	Callback = function(value)
		VehicleFlySettings.Speed = value
	end
})
vehicleFlySpeedSlider.Instance.LayoutOrder = 2

local VehicleJumpSection = VehicleMovementTab:AddSection({
	Name = "Vehicle Jump"
})

local vehicleJumpPowerSlider = VehicleJumpSection:AddSlider({
	Name = "Jump Power",
	Min = 20,
	Max = 250,
	Default = VehicleJumpSettings.Power,
	Callback = function(value)
		VehicleJumpSettings.Power = value
	end
})
vehicleJumpPowerSlider.Instance.LayoutOrder = 1

local VehicleTeleportSection = VehicleMovementTab:AddSection({
	Name = "Vehicle Teleport"
})

local vehicleTeleportToggle = VehicleTeleportSection:AddToggle({
	Name = "Enable Vehicle Teleport",
	Default = false,
	Callback = function(value)
		setVehicleTeleportEnabled(value)
	end
})
vehicleTeleportToggle.Instance.LayoutOrder = 1

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
	if MapViewerSettings.Enabled and input.KeyCode == Enum.KeyCode.Escape then
		setMapViewerEnabled(false)
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
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		endAimlock()
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if MapViewerSettings.Enabled
		and input.UserInputType == Enum.UserInputType.MouseMovement then
		MapViewerSettings.Yaw -= input.Delta.X * 0.003
		MapViewerSettings.Pitch = math.clamp(
			MapViewerSettings.Pitch - input.Delta.Y * 0.003,
			-math.rad(85),
			math.rad(85)
		)
	end
end))

track(Mouse.Button1Down:Connect(function()
	if not running
		or not VehicleTeleportSettings.Enabled
		or UserInputService:GetFocusedTextBox() then
		return
	end

	local position = UserInputService:GetMouseLocation()
	local overWindow = false
	local ok, objects = pcall(function()
		return UserInputService:GetGuiObjectsAtPosition(position.X, position.Y)
	end)

	if ok and objects and Window and Window.Instance then
		for _, object in ipairs(objects) do
			if object == Window.Instance or object:IsDescendantOf(Window.Instance) then
				overWindow = true
				break
			end
		end
	end

	if not overWindow then
		teleportVehicleToMouse(position)
	end
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

local layoutRefreshQueued = false
local function queueLayoutRefresh()
	if layoutRefreshQueued or not running then
		return
	end

	layoutRefreshQueued = true
	task.defer(function()
		layoutRefreshQueued = false

		if running then
			StyleSection:Refresh()
			MovementSection:Refresh()
			FlySection:Refresh()
			AimlockSection:Refresh()
			FlingSection:Refresh()
			VehicleSection:Refresh()
			VehicleFlySection:Refresh()
			VehicleJumpSection:Refresh()
			VehicleTeleportSection:Refresh()
			MapSection:Refresh()
		end
	end)
end

track(Window.Instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueLayoutRefresh))

applyPickerTheme()
updateColorPicker()
updateAimStatus()
queueLayoutRefresh()
task.defer(queueLayoutRefresh)
