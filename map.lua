local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Google = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Google-UI/refs/heads/main/main.lua"))()

pcall(function()
	Google.SetTheme("DarkRed")
end)

local LocalPlayer = Players.LocalPlayer
local RENDER_BATCH_SIZE = 30
local PROPERTY_SYNC_INTERVAL = 0.2
local MIN_VISIBLE_VOLUME = 0.001

local Window = Google:CreateWindow({
	Title = "Live Map Visualizer",
	Subtitle = "Live 3D Workspace preview",
	Icon = "image",
	Size = UDim2.fromOffset(780, 550)
})

local MapTab = Window:CreateTab({
	Name = "Map",
	Icon = "image"
})

local function getTabPage(window, tab, tabName)
	if type(tab) == "table" then
		for _, key in ipairs({ "Page", "PageFrame", "Container", "Content", "Main", "Instance" }) do
			if typeof(tab[key]) == "Instance" then
				return tab[key]
			end
		end
	end

	for _, key in ipairs({ "PageWrap", "PageContainer", "Content", "Body", "Instance" }) do
		local holder = window[key]
		if typeof(holder) == "Instance" then
			local direct = holder:FindFirstChild("Page_" .. tabName, true)
			if direct and (direct:IsA("Frame") or direct:IsA("ScrollingFrame")) then
				return direct
			end

			for _, child in ipairs(holder:GetDescendants()) do
				if child:IsA("Frame") or child:IsA("ScrollingFrame") then
					if string.lower(child.Name):find(string.lower(tabName), 1, true) then
						return child
					end
				end
			end
		end
	end

	error("Could not find Google UI tab page.")
end

local Theme = Google.Theme or {
	Page = Color3.fromRGB(18, 13, 13),
	Card = Color3.fromRGB(36, 26, 25),
	CardAlt = Color3.fromRGB(43, 31, 30),
	Text = Color3.fromRGB(248, 238, 237),
	Muted = Color3.fromRGB(187, 153, 150),
	Border = Color3.fromRGB(64, 42, 40),
	Primary = Color3.fromRGB(234, 67, 53),
	PrimaryHover = Color3.fromRGB(247, 99, 87)
}

local Page = getTabPage(Window, MapTab, "Map")

if Page:IsA("ScrollingFrame") then
	Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Page.CanvasSize = UDim2.fromOffset(0, 0)
	Page.ScrollBarThickness = 3
end

local function create(className, props)
	local obj = Instance.new(className)
	for property, value in pairs(props or {}) do
		obj[property] = value
	end
	return obj
end

local function round(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent
	})
end

local function stroke(parent, color, transparency, thickness)
	return create("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent
	})
end

local Main = create("Frame", {
	Name = "LiveMapPreviewPanel",
	Size = UDim2.new(1, -20, 0, 430),
	BackgroundColor3 = Theme.Card,
	BorderSizePixel = 0,
	Parent = Page
})
round(Main, 12)
stroke(Main, Theme.Border, 0, 1)

local Header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundTransparency = 1,
	Parent = Main
})

local Title = create("TextLabel", {
	Name = "Title",
	Text = "Live 3D Map Visual",
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -390, 0, 22),
	Position = UDim2.fromOffset(14, 7),
	Parent = Header
})

local Status = create("TextLabel", {
	Name = "Status",
	Text = "Building live preview...",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -390, 0, 18),
	Position = UDim2.fromOffset(14, 31),
	Parent = Header
})

local ButtonBar = create("Frame", {
	Name = "ButtonBar",
	Size = UDim2.fromOffset(365, 32),
	Position = UDim2.new(1, -375, 0, 11),
	BackgroundTransparency = 1,
	Parent = Header
})

create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = ButtonBar
})

local function makeButton(text, width)
	local button = create("TextButton", {
		Name = text:gsub("%s+", ""),
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Theme.Primary,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(width, 30),
		Parent = ButtonBar
	})
	round(button, 8)

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.PrimaryHover or Theme.Primary
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.Primary
	end)

	return button
end

local LiveButton = makeButton("Live: On", 72)
local RebuildButton = makeButton("Rebuild", 68)
local ResetButton = makeButton("Reset View", 78)
local ZoomInButton = makeButton("Zoom +", 62)
local ZoomOutButton = makeButton("Zoom -", 62)

local Viewport = create("ViewportFrame", {
	Name = "MapViewport",
	Size = UDim2.new(1, -28, 1, -98),
	Position = UDim2.fromOffset(14, 56),
	BackgroundColor3 = Theme.Page,
	BorderSizePixel = 0,
	Ambient = Color3.fromRGB(170, 170, 170),
	LightColor = Color3.fromRGB(255, 255, 255),
	LightDirection = Vector3.new(-1, -1, -0.75),
	Parent = Main
})
round(Viewport, 10)
stroke(Viewport, Theme.Border, 0.1, 1)

local Footer = create("TextLabel", {
	Name = "Footer",
	Text = "Live sync: players + moving parts update automatically • Click preview • Drag mouse to look • WASD move • Q/E down/up • Wheel zoom • Esc unlocks",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -28, 0, 26),
	Position = UDim2.new(0, 14, 1, -34),
	Parent = Main
})

local WorldModel = create("WorldModel", {
	Name = "LivePreviewWorld",
	Parent = Viewport
})

local PreviewModel = create("Model", {
	Name = "LiveRenderedMap",
	Parent = WorldModel
})

local PreviewCamera = create("Camera", {
	Name = "PreviewCamera",
	FieldOfView = 55,
	Parent = Viewport
})

Viewport.CurrentCamera = PreviewCamera

local trackedParts = {}
local connections = {}
local liveEnabled = true
local building = false
local focused = false
local mouseLooking = false
local lastMousePosition = nil
local keyDown = {}

local boundsMin = Vector3.zero
local boundsMax = Vector3.zero
local boundsCenter = Vector3.zero
local boundsSize = Vector3.new(100, 100, 100)
local mapScale = 100

local cameraPosition = Vector3.new(0, 40, 160)
local yaw = 0
local pitch = 0
local moveSpeed = 80
local renderedCount = 0
local skippedCount = 0
local lastPropertySync = 0

local function setStatus(text)
	Status.Text = text
end

local function disconnectAll()
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
end

local function getLookVector()
	local cosPitch = math.cos(pitch)
	return Vector3.new(
		-math.sin(yaw) * cosPitch,
		math.sin(pitch),
		-math.cos(yaw) * cosPitch
	)
end

local function getRightVector()
	return Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
end

local function updateCamera()
	PreviewCamera.CFrame = CFrame.lookAt(cameraPosition, cameraPosition + getLookVector())
end

local function setAnglesFromDirection(direction)
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, -0.2, -1)
	end

	direction = direction.Unit
	pitch = math.asin(math.clamp(direction.Y, -0.98, 0.98))
	yaw = math.atan2(-direction.X, -direction.Z)
end

local function resetView()
	mapScale = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 80)
	moveSpeed = math.clamp(mapScale / 3, 35, 900)
	cameraPosition = Vector3.new(0, math.max(boundsSize.Y * 0.35, 35), mapScale * 1.15)
	setAnglesFromDirection(Vector3.zero - cameraPosition)
	updateCamera()
	setStatus("Live preview active. Click the preview to control the camera.")
end

local function zoomCamera(amount)
	local zoomStep = math.clamp(mapScale * 0.09, 8, 300)
	cameraPosition += getLookVector() * amount * zoomStep
	updateCamera()
end

local function pointMouseInsideViewport()
	local mouse = UserInputService:GetMouseLocation()
	local pos = Viewport.AbsolutePosition
	local size = Viewport.AbsoluteSize

	return mouse.X >= pos.X
		and mouse.X <= pos.X + size.X
		and mouse.Y >= pos.Y
		and mouse.Y <= pos.Y + size.Y
end

local function isInsideGoogleUI(instance)
	local current = instance
	while current do
		if current == Window.Instance or current == Viewport or current == WorldModel or current == PreviewModel then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isRenderableBasePart(instance)
	if not instance:IsA("BasePart") then
		return false
	end

	if instance:IsA("Terrain") then
		return false
	end

	if not instance:IsDescendantOf(Workspace) then
		return false
	end

	if Workspace.CurrentCamera and instance:IsDescendantOf(Workspace.CurrentCamera) then
		return false
	end

	if isInsideGoogleUI(instance) then
		return false
	end

	if instance.Transparency >= 1 then
		return false
	end

	if instance.Size.X * instance.Size.Y * instance.Size.Z < MIN_VISIBLE_VOLUME then
		return false
	end

	return true
end

local function isPlayerPart(part)
	local current = part
	while current and current ~= Workspace do
		if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getPartCorners(part)
	local cf = part.CFrame
	local sx = part.Size.X / 2
	local sy = part.Size.Y / 2
	local sz = part.Size.Z / 2

	return {
		cf * Vector3.new(-sx, -sy, -sz),
		cf * Vector3.new(-sx, -sy, sz),
		cf * Vector3.new(-sx, sy, -sz),
		cf * Vector3.new(-sx, sy, sz),
		cf * Vector3.new(sx, -sy, -sz),
		cf * Vector3.new(sx, -sy, sz),
		cf * Vector3.new(sx, sy, -sz),
		cf * Vector3.new(sx, sy, sz)
	}
end

local function calculateBounds(parts)
	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		if not isPlayerPart(part) then
			for _, point in ipairs(getPartCorners(part)) do
				minPoint = Vector3.new(
					math.min(minPoint.X, point.X),
					math.min(minPoint.Y, point.Y),
					math.min(minPoint.Z, point.Z)
				)

				maxPoint = Vector3.new(
					math.max(maxPoint.X, point.X),
					math.max(maxPoint.Y, point.Y),
					math.max(maxPoint.Z, point.Z)
				)
			end
		end
	end

	if minPoint.X == math.huge then
		minPoint = Vector3.new(-50, -50, -50)
		maxPoint = Vector3.new(50, 50, 50)
	end

	return minPoint, maxPoint
end

local function offsetCFrame(realPart)
	local rotationOnly = realPart.CFrame - realPart.Position
	return CFrame.new(realPart.Position - boundsCenter) * rotationOnly
end

local function cleanClone(clone)
	for _, item in ipairs(clone:GetDescendants()) do
		local className = item.ClassName
		local remove = false

		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			remove = true
		elseif item:IsA("Sound") or item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") then
			remove = true
		elseif item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") then
			remove = true
		elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			remove = true
		elseif item:IsA("ClickDetector") or item:IsA("ProximityPrompt") then
			remove = true
		elseif item:IsA("Attachment") then
			remove = true
		elseif item:IsA("Constraint") or item:IsA("Weld") or item:IsA("WeldConstraint") or item:IsA("Motor6D") then
			remove = true
		elseif item:IsA("BodyMover") or item:IsA("VectorForce") or item:IsA("LinearVelocity") or item:IsA("AngularVelocity") then
			remove = true
		elseif item:IsA("AlignPosition") or item:IsA("AlignOrientation") then
			remove = true
		elseif className == "TouchTransmitter" then
			remove = true
		end

		if remove then
			pcall(function()
				item:Destroy()
			end)
		end
	end

	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		clone.Massless = true
		clone.Locked = true
	end
end

local function makeFallbackPart(original)
	local part = Instance.new("Part")
	part.Name = original.Name
	part.Size = original.Size
	part.Color = original.Color
	part.Material = original.Material
	part.Transparency = original.Transparency
	part.Reflectance = original.Reflectance
	part.CastShadow = original.CastShadow
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Locked = true
	return part
end

local function syncVisualProperties(original, clone)
	if not original or not clone then
		return
	end

	pcall(function()
		if clone.Size ~= original.Size then
			clone.Size = original.Size
		end

		if clone.Color ~= original.Color then
			clone.Color = original.Color
		end

		if clone.Material ~= original.Material then
			clone.Material = original.Material
		end

		if clone.Transparency ~= original.Transparency then
			clone.Transparency = original.Transparency
		end

		if clone.Reflectance ~= original.Reflectance then
			clone.Reflectance = original.Reflectance
		end
	end)
end

local function addTrackedPart(original)
	if trackedParts[original] then
		return
	end

	if not isRenderableBasePart(original) then
		return
	end

	local oldArchivable = original.Archivable
	local clone = nil

	pcall(function()
		original.Archivable = true
	end)

	local ok = pcall(function()
		clone = original:Clone()
	end)

	pcall(function()
		original.Archivable = oldArchivable
	end)

	if not ok or not clone or not clone:IsA("BasePart") then
		clone = makeFallbackPart(original)
	end

	cleanClone(clone)
	clone.CFrame = offsetCFrame(original)
	clone.Parent = PreviewModel

	trackedParts[original] = {
		Clone = clone,
		IsPlayer = isPlayerPart(original),
		LastCFrame = original.CFrame,
		LastSize = original.Size,
		LastTransparency = original.Transparency
	}

	renderedCount += 1
end

local function removeTrackedPart(original)
	local record = trackedParts[original]
	if not record then
		return
	end

	trackedParts[original] = nil

	if record.Clone then
		pcall(function()
			record.Clone:Destroy()
		end)
	end
end

local function clearPreview()
	for original in pairs(trackedParts) do
		removeTrackedPart(original)
	end

	PreviewModel:ClearAllChildren()
	renderedCount = 0
	skippedCount = 0
end

local function buildPreview()
	if building then
		return
	end

	building = true
	RebuildButton.Text = "..."
	clearPreview()

	local parts = {}
	setStatus("Collecting visible Workspace parts and players...")

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			if isRenderableBasePart(obj) then
				table.insert(parts, obj)
			else
				skippedCount += 1
			end
		end
	end

	boundsMin, boundsMax = calculateBounds(parts)
	boundsCenter = (boundsMin + boundsMax) / 2
	boundsSize = boundsMax - boundsMin
	mapScale = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 80)

	setStatus("Rendering live preview: 0 / " .. tostring(#parts))

	for index, part in ipairs(parts) do
		local ok = pcall(function()
			addTrackedPart(part)
		end)

		if not ok then
			skippedCount += 1
		end

		if index % RENDER_BATCH_SIZE == 0 then
			setStatus("Rendering live preview: " .. tostring(index) .. " / " .. tostring(#parts))
			task.wait()
		end
	end

	resetView()

	if Workspace.StreamingEnabled then
		setStatus("Live preview active. Rendered loaded parts: " .. tostring(renderedCount) .. ". Streaming may hide far parts until loaded.")
	else
		setStatus("Live preview active. Rendered parts and players: " .. tostring(renderedCount) .. ".")
	end

	RebuildButton.Text = "Rebuild"
	building = false
end

local function bindWorkspaceLiveSync()
	disconnectAll()

	table.insert(connections, Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("BasePart") then
			task.defer(function()
				if liveEnabled and instance.Parent and instance:IsDescendantOf(Workspace) then
					addTrackedPart(instance)
				end
			end)
		end
	end))

	table.insert(connections, Workspace.DescendantRemoving:Connect(function(instance)
		if trackedParts[instance] then
			removeTrackedPart(instance)
		end
	end))
end

Viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		focused = true
		mouseLooking = true
		lastMousePosition = input.Position
		setStatus("Camera control active. Press Esc to unlock.")
	end
end)

Viewport.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseLooking = false
		lastMousePosition = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		focused = false
		mouseLooking = false
		lastMousePosition = nil
		table.clear(keyDown)
		setStatus("Camera control unlocked.")
		return
	end

	if focused then
		keyDown[input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	keyDown[input.KeyCode] = false
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and mouseLooking and lastMousePosition then
		local delta = input.Position - lastMousePosition
		lastMousePosition = input.Position

		yaw -= delta.X * 0.006
		pitch = math.clamp(pitch - delta.Y * 0.0045, math.rad(-87), math.rad(87))
		updateCamera()
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel and pointMouseInsideViewport() then
		zoomCamera(input.Position.Z)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if liveEnabled then
		for original, record in pairs(trackedParts) do
			local clone = record.Clone

			if not original or not original.Parent or not original:IsDescendantOf(Workspace) or not clone or not clone.Parent then
				removeTrackedPart(original)
			else
				if original.Transparency >= 1 then
					clone.Transparency = 1
				else
					local realCFrame = original.CFrame
					if record.LastCFrame ~= realCFrame then
						clone.CFrame = offsetCFrame(original)
						record.LastCFrame = realCFrame
					elseif record.IsPlayer or not original.Anchored then
						clone.CFrame = offsetCFrame(original)
					end
				end
			end
		end
	end

	lastPropertySync += dt
	if lastPropertySync >= PROPERTY_SYNC_INTERVAL then
		lastPropertySync = 0
		for original, record in pairs(trackedParts) do
			if original and original.Parent and record.Clone and record.Clone.Parent then
				syncVisualProperties(original, record.Clone)
			end
		end
	end

	if focused then
		local move = Vector3.zero
		local look = getLookVector()
		local right = getRightVector()

		if keyDown[Enum.KeyCode.W] then
			move += look
		end

		if keyDown[Enum.KeyCode.S] then
			move -= look
		end

		if keyDown[Enum.KeyCode.D] then
			move += right
		end

		if keyDown[Enum.KeyCode.A] then
			move -= right
		end

		if keyDown[Enum.KeyCode.E] then
			move += Vector3.yAxis
		end

		if keyDown[Enum.KeyCode.Q] then
			move -= Vector3.yAxis
		end

		if move.Magnitude > 0 then
			local speed = moveSpeed

			if keyDown[Enum.KeyCode.LeftShift] or keyDown[Enum.KeyCode.RightShift] then
				speed *= 2.5
			end

			if keyDown[Enum.KeyCode.LeftControl] or keyDown[Enum.KeyCode.RightControl] then
				speed *= 0.35
			end

			cameraPosition += move.Unit * speed * dt
			updateCamera()
		end
	end
end)

LiveButton.MouseButton1Click:Connect(function()
	liveEnabled = not liveEnabled
	LiveButton.Text = liveEnabled and "Live: On" or "Live: Off"
	setStatus(liveEnabled and "Live sync enabled." or "Live sync paused.")
end)

RebuildButton.MouseButton1Click:Connect(function()
	task.spawn(buildPreview)
end)

ResetButton.MouseButton1Click:Connect(function()
	resetView()
end)

ZoomInButton.MouseButton1Click:Connect(function()
	zoomCamera(1)
end)

ZoomOutButton.MouseButton1Click:Connect(function()
	zoomCamera(-1)
end)

updateCamera()
bindWorkspaceLiveSync()

task.defer(function()
	task.wait(0.35)
	buildPreview()
end)
