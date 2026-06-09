local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer


local AutoRerunURL = "https://raw.githubusercontent.com/Toluwerr/Script-Finder/refs/heads/main/main.lua"
local AutoRerunFolder = "ScriptFinderSettings"
local AutoRerunConfig = AutoRerunFolder .. "/AutoRerun.txt"
local AutoRerunAutoexec = "autoexec/ScriptFinder.lua"

local function ensureAutoRerunFolder()
	if type(makefolder) == "function" and type(isfolder) == "function" then
		pcall(function()
			if not isfolder(AutoRerunFolder) then
				makefolder(AutoRerunFolder)
			end
		end)
	end
end

local function getAutoRerunEnabled()
	if type(isfile) == "function" and type(readfile) == "function" then
		local ok, result = pcall(function()
			if isfile(AutoRerunConfig) then
				return readfile(AutoRerunConfig)
			end
		end)

		if ok and type(result) == "string" then
			return result ~= "false"
		end
	end

	return true
end

local function writeAutoRerunEnabled(value)
	if type(writefile) ~= "function" then
		return
	end

	ensureAutoRerunFolder()

	pcall(function()
		writefile(AutoRerunConfig, value and "true" or "false")
	end)
end

local AutoRerunEnabled = getAutoRerunEnabled()

local AutoRerunLoader = [[
local Enabled = true
pcall(function()
	if type(isfile) == "function" and type(readfile) == "function" and isfile("ScriptFinderSettings/AutoRerun.txt") then
		Enabled = readfile("ScriptFinderSettings/AutoRerun.txt") ~= "false"
	end
end)
if Enabled then
	loadstring(game:HttpGet("]] .. AutoRerunURL .. [[?cache=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))))()
end
]]

local function getTeleportQueue()
	if type(queue_on_teleport) == "function" then
		return queue_on_teleport
	end

	if type(queueonteleport) == "function" then
		return queueonteleport
	end

	if syn and type(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end

	if fluxus and type(fluxus.queue_on_teleport) == "function" then
		return fluxus.queue_on_teleport
	end

	return nil
end

local function queueSelfOnTeleport()
	if not AutoRerunEnabled then
		return
	end

	local queueTeleport = getTeleportQueue()

	if queueTeleport then
		pcall(function()
			queueTeleport(AutoRerunLoader)
		end)
	end
end

local function saveAutoExecuteLoader()
	if type(writefile) ~= "function" then
		return
	end

	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("autoexec") then
			makefolder("autoexec")
		end

		if AutoRerunEnabled then
			writefile(AutoRerunAutoexec, AutoRerunLoader)
		else
			if type(delfile) == "function" and type(isfile) == "function" and isfile(AutoRerunAutoexec) then
				delfile(AutoRerunAutoexec)
			else
				writefile(AutoRerunAutoexec, "-- Script Finder auto rerun disabled")
			end
		end
	end)
end

local function saveConfigState()
	if Configs then
		pcall(function()
			Configs:Save("script_finder")
		end)
	end
end

local function setAutoRerun(value)
	AutoRerunEnabled = value == true
	writeAutoRerunEnabled(AutoRerunEnabled)
	saveAutoExecuteLoader()
	saveConfigState()

	if AutoRerunEnabled then
		queueSelfOnTeleport()
		setStatus("Auto reopen enabled.")
	else
		setStatus("Auto reopen disabled.")
	end
end

queueSelfOnTeleport()
saveAutoExecuteLoader()

pcall(function()
	TeleportService.TeleportInitFailed:Connect(function()
		queueSelfOnTeleport()
	end)
end)

local Google = "https://raw.githubusercontent.com/Toluwerr/Google-UI/refs/heads/main/main.lua"

local loaded, Google = pcall(function()
	local Source = game:HttpGet(Google .. "?cache=" .. tostring(os.time()) .. tostring(math.random(1000, 9999)))
	Source = Source:gsub("([,{]%s*)pad%s*=", "%1Padding =")
	Source = Source:gsub("%.pad", ".Padding")
	return loadstring(Source)()
end)

if not loaded or type(Google) ~= "table" then
	error("Failed to load Google UI: " .. tostring(Google))
end

if Google.Build ~= "components-config-system" then
	warn("Google UI config-system build was expected, got: " .. tostring(Google.Build))
end

pcall(function()
	if Google.SetTheme then
		Google.SetTheme("DarkGoogle")
	elseif Google.Themes and Google.Themes.DarkGoogle then
		Google.ActiveTheme = "DarkGoogle"
		Google.Theme = Google.Themes.DarkGoogle
	elseif Google.Themes and Google.Themes.DarkRed then
		Google.ActiveTheme = "DarkRed"
		Google.Theme = Google.Themes.DarkRed
	end
end)

local Configs = nil
pcall(function()
	if type(Google.CreateConfigManager) == "function" then
		Configs = Google:CreateConfigManager({
			Folder = "ScriptFinderSettings",
			Extension = ".json",
			Default = "script_finder",
			AutoSave = false
		})
		Configs:SetAutoload("script_finder")
	end
end)

local SearchEndpoint = "https://scriptblox.com/api/script/search"
local FetchEndpoint = "https://scriptblox.com/api/script/fetch"
local DetailsEndpoint = "https://scriptblox.com/api/script/"
local RawEndpoint = "https://scriptblox.com/api/script/raw/"
local RscriptsEndpoint = "https://rscripts.net/api/v2/scripts"
local RscriptsDetailsEndpoint = "https://rscripts.net/api/v2/script"
local SiteURL = "https://scriptblox.com"
local RscriptsSiteURL = "https://rscripts.net"
local ImageFolder = "ScriptBloxFinderImages"
local ScriptBloxLogoURL = "rbxthumb://type=Asset&id=84945399616047&w=150&h=150"
local RscriptsLogoURL = "rbxthumb://type=Asset&id=108648055077644&w=150&h=150"
local FavoritesFile = AutoRerunFolder .. "/Favorites.json"

local state = {
	query = "",
	source = "scriptblox",
	page = 1,
	max = 12,
	sortBy = "updatedAt",
	order = "desc",
	placeId = "",
	owner = "",
	unpatchedOnly = true,
	noKeyOnly = false,
	verifiedOnly = false,
	universalOnly = false,
	results = {},
	selected = nil,
	totalPages = 0,
	busy = false,
	lastUrl = "",
	favorites = {},
	favoriteMode = "Current Game"
}

local ui = {
	searchInput = nil,
	maxInput = nil,
	gameInput = nil,
	authorInput = nil,
	sortDropdown = nil,
	orderDropdown = nil,
	status = nil,
	filterSummary = nil,
	scriptsInfo = nil,
	sourceScriptBloxButton = nil,
	sourceRscriptsButton = nil,
	selectedImage = nil,
	selectedAuthorImage = nil,
	selectedTitle = nil,
	selectedGame = nil,
	selectedMeta = nil,
	selectedFeatures = nil,
	selectedTags = nil,
	selectedPreview = nil,
	previewRaw = "",
	previewScroll = nil,
	previewCode = nil,
	previewLines = nil,
	favoriteButton = nil,
	favoriteInfo = nil,
	favoriteCurrentButton = nil,
	favoriteUniversalButton = nil
}

local Window
local SearchTab
local ScriptsTab
local SelectedTab
local FavoritesTab
local searchScripts
local selectScript
local renderFavorites
local updateFavoriteButton
local favoriteSelected

local function theme()
	return Google.Theme or {}
end

local PaletteOverrides = {
	Card = Color3.fromRGB(17, 24, 39),
	CardAlt = Color3.fromRGB(30, 41, 59),
	Input = Color3.fromRGB(15, 23, 42),
	Hover = Color3.fromRGB(37, 49, 75),
	Border = Color3.fromRGB(51, 65, 85),
	BorderStrong = Color3.fromRGB(71, 85, 105),
	Primary = Color3.fromRGB(67, 135, 244),
	PrimaryHover = Color3.fromRGB(95, 158, 255),
	PrimarySoft = Color3.fromRGB(30, 58, 105),
	Text = Color3.fromRGB(241, 245, 249),
	Muted = Color3.fromRGB(148, 163, 184)
}

local function color(name, fallback)
	if PaletteOverrides[name] then
		return PaletteOverrides[name]
	end

	local t = theme()
	return t[name] or fallback
end

local function trim(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function encode(value)
	return HttpService:UrlEncode(tostring(value or ""))
end

local function setStatus(text)
	text = tostring(text or "")
	if ui.status then
		ui.status.Text = text

		local lowered = string.lower(text)
		if lowered:find("ready", 1, true) then
			ui.status.TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184))
		elseif lowered:find("failed", 1, true) or lowered:find("error", 1, true) then
			ui.status.TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244))
		elseif lowered:find("added", 1, true) or lowered:find("loaded", 1, true) or lowered:find("found", 1, true) then
			ui.status.TextColor3 = color("Text", Color3.fromRGB(248, 238, 237))
		else
			ui.status.TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244))
		end
	else
		print("[Script Finder] " .. text)
	end
end

local function safeSelectTab(tab)
	if Window and Window.SelectTab then
		local ok = pcall(function()
			Window:SelectTab(tab)
		end)
		if ok then
			return
		end
	end

	if Window and Window.Tabs then
		for _, otherTab in ipairs(Window.Tabs) do
			local active = otherTab == tab
			if otherTab.Page then
				otherTab.Page.Visible = active
			end
			if otherTab.Button then
				otherTab.Button.BackgroundTransparency = active and 0 or 1
				otherTab.Button.BackgroundColor3 = active and color("PrimarySoft", Color3.fromRGB(30, 58, 105)) or color("Sidebar", Color3.fromRGB(14, 14, 18))
			end
			if otherTab.Accent then
				otherTab.Accent.Visible = active
			end
			if otherTab.TextLabel then
				otherTab.TextLabel.TextColor3 = active and color("Primary", Color3.fromRGB(67, 135, 244)) or color("Muted", Color3.fromRGB(148, 163, 184))
			end
			if otherTab.IconLabel and Google.SetIconColor then
				Google.SetIconColor(otherTab.IconLabel, active and color("Primary", Color3.fromRGB(67, 135, 244)) or color("Muted", Color3.fromRGB(148, 163, 184)))
			end
			otherTab.Active = active
		end
		Window.ActiveTab = tab
	end
end

local function requestGet(url, headers)
	headers = type(headers) == "table" and headers or nil

	local ok, result = pcall(function()
		local requestData = {Url = url, Method = "GET"}
		if headers then
			requestData.Headers = headers
		end

		if type(request) == "function" then
			local response = request(requestData)
			if response and response.Body then
				return response.Body
			end
		end

		if type(http_request) == "function" then
			local response = http_request(requestData)
			if response and response.Body then
				return response.Body
			end
		end

		if syn and type(syn.request) == "function" then
			local response = syn.request(requestData)
			if response and response.Body then
				return response.Body
			end
		end

		if fluxus and type(fluxus.request) == "function" then
			local response = fluxus.request(requestData)
			if response and response.Body then
				return response.Body
			end
		end

		if http and type(http.request) == "function" then
			local response = http.request(requestData)
			if response and response.Body then
				return response.Body
			end
		end

		return game:HttpGet(url)
	end)

	if ok then
		return true, result
	end

	return false, tostring(result)
end

local function copyText(text)
	text = tostring(text or "")
	if text == "" then
		setStatus("Nothing to copy.")
		return false
	end

	local copied = false

	pcall(function()
		if type(setclipboard) == "function" then
			setclipboard(text)
			copied = true
		elseif type(toclipboard) == "function" then
			toclipboard(text)
			copied = true
		elseif type(set_clipboard) == "function" then
			set_clipboard(text)
			copied = true
		elseif Clipboard and type(Clipboard.set) == "function" then
			Clipboard.set(text)
			copied = true
		end
	end)

	if copied then
		setStatus("Copied.")
	else
		print(text)
		setStatus("Clipboard unavailable. Printed to console.")
	end

	return copied
end

local function writeSupported()
	return type(writefile) == "function" and (type(getcustomasset) == "function" or type(getsynasset) == "function")
end

local function customAsset(path)
	if type(getcustomasset) == "function" then
		local ok, result = pcall(function()
			return getcustomasset(path)
		end)
		if ok and result then
			return result
		end
	end

	if type(getsynasset) == "function" then
		local ok, result = pcall(function()
			return getsynasset(path)
		end)
		if ok and result then
			return result
		end
	end

	return ""
end

local function ensureImageFolder()
	if type(makefolder) == "function" and type(isfolder) == "function" then
		pcall(function()
			if not isfolder(ImageFolder) then
				makefolder(ImageFolder)
			end
		end)
	end
end

local function safeName(value)
	value = tostring(value or "image")
	value = value:gsub("[^%w_%-]", "_")
	value = value:gsub("_+", "_")
	if #value > 60 then
		value = value:sub(1, 60)
	end
	if value == "" then
		value = "image"
	end
	return value
end

local function normalizeImageURL(value)
	value = tostring(value or "")

	if value == "" then
		return ""
	end

	if value:match("^rbxassetid://") or value:match("^rbxthumb://") or value:match("^rbxasset://") then
		return value
	end

	if value:match("^//") then
		return "https:" .. value
	end

	if value:match("^/") then
		return SiteURL .. value
	end

	if value:match("^https?://") then
		return value
	end

	return SiteURL .. "/" .. value
end

local imageCache = {}

local function resolveImage(value, identifier)
	local url = normalizeImageURL(value)

	if url == "" then
		return ""
	end

	if url:match("^rbxassetid://") or url:match("^rbxthumb://") or url:match("^rbxasset://") then
		return url
	end

	if imageCache[url] then
		return imageCache[url]
	end

	if not writeSupported() then
		return ""
	end

	ensureImageFolder()

	local extension = url:match("%.([%w]+)%??[^/]*$") or "png"
	extension = extension:lower()

	if extension ~= "png" and extension ~= "jpg" and extension ~= "jpeg" and extension ~= "webp" then
		extension = "png"
	end

	local filename = ImageFolder .. "/" .. safeName(identifier) .. "." .. extension

	if type(isfile) ~= "function" or not isfile(filename) then
		local ok, body = requestGet(url)
		if ok and type(body) == "string" and body ~= "" then
			pcall(function()
				writefile(filename, body)
			end)
		end
	end

	if type(isfile) == "function" and not isfile(filename) then
		return ""
	end

	local asset = customAsset(filename)
	imageCache[url] = asset
	return asset
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	local value = radius or 6

	if value < 20 then
		value = math.min(value, 7)
	end

	corner.CornerRadius = UDim.new(0, value)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, strokeColor, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Transparency = math.max(transparency or 0.45, 0.32)
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addGradient(parent, topColor, bottomColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor)
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function addPadding(parent, left, top, right, bottom)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingRight = UDim.new(0, right or 0)
	padding.PaddingBottom = UDim.new(0, bottom or 0)
	padding.Parent = parent
	return padding
end

local function createText(parent, data)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = data.BackgroundTransparency or 1
	label.BackgroundColor3 = data.BackgroundColor3 or color("Card", Color3.fromRGB(17, 24, 39))
	label.BorderSizePixel = 0
	label.Font = data.Font or Enum.Font.GothamMedium
	label.Text = data.Text or ""
	label.TextSize = data.TextSize or 13
	label.TextColor3 = data.TextColor3 or color("Text", Color3.fromRGB(241, 245, 249))
	label.TextXAlignment = data.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = data.TextYAlignment or Enum.TextYAlignment.Center
	label.TextWrapped = data.TextWrapped == true
	label.TextTruncate = data.TextTruncate or Enum.TextTruncate.AtEnd
	label.Position = data.Position or UDim2.fromOffset(0, 0)
	label.Size = data.Size or UDim2.fromOffset(100, 20)
	label.LayoutOrder = data.LayoutOrder or 0
	label.ClipsDescendants = true
	label.Parent = parent
	return label
end

local function createPanel(parent, height, layoutOrder, backgroundColor)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = backgroundColor or color("Card", Color3.fromRGB(17, 24, 39))
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, -10, 0, height)
	panel.LayoutOrder = layoutOrder or 0
	panel.ClipsDescendants = true
	panel.Parent = parent

	addCorner(panel, 8)
	addStroke(panel, color("Border", Color3.fromRGB(51, 65, 85)), 0.36, 1)

	return panel
end

local function createButton(parent, text, position, size, callback, soft)
	local button = Instance.new("TextButton")
	button.Name = safeName(text)
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(241, 245, 249)
	button.BackgroundColor3 = soft and color("PrimarySoft", Color3.fromRGB(30, 58, 105)) or color("Primary", Color3.fromRGB(67, 135, 244))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Position = position
	button.Size = size
	button.Parent = parent

	addCorner(button, 8)
	addStroke(button, color("Border", Color3.fromRGB(51, 65, 85)), soft and 0.42 or 0.35, 1)

	local normal = button.BackgroundColor3
	local hover = soft and Color3.fromRGB(37, 49, 75) or color("PrimaryHover", Color3.fromRGB(95, 158, 255))

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = hover
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = normal
	end)

	button.MouseButton1Click:Connect(function()
		callback()
	end)

	return button
end

local function forceInputTextStyle(box)
	local inputTextColor = Color3.fromRGB(255, 255, 255)
	local placeholderColor = Color3.fromRGB(148, 163, 184)

	local function apply()
		if not box or not box.Parent then
			return
		end

		box.TextColor3 = inputTextColor
		box.TextTransparency = 0
		box.PlaceholderColor3 = placeholderColor
		box.Font = Enum.Font.GothamSemibold
		box.TextSize = 13
	end

	apply()

	pcall(function()
		box:GetPropertyChangedSignal("TextColor3"):Connect(apply)
		box:GetPropertyChangedSignal("TextTransparency"):Connect(apply)
		box:GetPropertyChangedSignal("PlaceholderColor3"):Connect(apply)
		box:GetPropertyChangedSignal("Font"):Connect(apply)
		box:GetPropertyChangedSignal("Text"):Connect(apply)
		box.Focused:Connect(apply)
		box.FocusLost:Connect(function()
			task.defer(apply)
		end)
	end)

	task.defer(apply)
	return box
end

local function createInput(parent, title, placeholder, defaultValue, position, size, callback)
	createText(parent, {
		Text = title,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		Position = position,
		Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 18)
	})

	local box = Instance.new("TextBox")
	box.Name = safeName(title) .. "Input"
	box.BackgroundColor3 = color("Input", Color3.fromRGB(15, 23, 42))
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.ClipsDescendants = true
	box.Font = Enum.Font.GothamSemibold
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Color3.fromRGB(148, 163, 184)
	box.Text = defaultValue or ""
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.TextTransparency = 0
	box.TextSize = 13
	box.TextWrapped = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	pcall(function()
		box.CursorPosition = -1
		box.TextEditable = true
	end)
	box.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 24)
	box.Size = size
	box.Parent = parent

	pcall(function()
		box.TextTruncate = Enum.TextTruncate.AtEnd
	end)

	addCorner(box, 12)
	addStroke(box, color("Border", Color3.fromRGB(51, 65, 85)), 0.16, 1)
	addPadding(box, 14, 0, 14, 0)
	forceInputTextStyle(box)

	box.FocusLost:Connect(function(enterPressed)
		callback(box.Text, enterPressed)
	end)

	return box
end

local function createCheck(parent, title, position, size, defaultValue, callback)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color("Input", Color3.fromRGB(15, 23, 42))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Position = position
	button.Size = size
	button.Parent = parent

	addCorner(button, 8)
	addStroke(button, color("Border", Color3.fromRGB(51, 65, 85)), 0.36, 1)

	local box = Instance.new("Frame")
	box.BackgroundColor3 = defaultValue and color("Primary", Color3.fromRGB(67, 135, 244)) or color("CardAlt", Color3.fromRGB(30, 41, 59))
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(12, 8)
	box.Size = UDim2.fromOffset(20, 20)
	box.Parent = button
	addCorner(box, 6)

	local mark = createText(box, {
		Text = defaultValue and "✓" or "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1)
	})

	createText(button, {
		Text = title,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -54, 1, 0)
	})

	local value = defaultValue == true

	local function refresh()
		box.BackgroundColor3 = value and color("Primary", Color3.fromRGB(67, 135, 244)) or color("CardAlt", Color3.fromRGB(30, 41, 59))
		mark.Text = value and "✓" or ""
	end

	button.MouseButton1Click:Connect(function()
		value = not value
		refresh()
		callback(value)
	end)

	return button
end

local function preparePage(tab)
	local page = tab and tab.Page
	if not page then
		return nil
	end

	if tab.Sections then
		table.clear(tab.Sections)
	end

	for _, child in ipairs(page:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local layout = tab.Layout or page:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = page
		tab.Layout = layout
	end

	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)

	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = color("BorderStrong", Color3.fromRGB(71, 85, 105))
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.ClipsDescendants = true

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if page and page.Parent then
			page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 28)
		end
	end)

	return page
end

local function firstNonEmpty(...)
	local values = {...}
	for _, value in ipairs(values) do
		if type(value) == "string" and trim(value) ~= "" then
			return value
		end
	end
	return ""
end

local function boolToText(value)
	return value and "Yes" or "No"
end

local function getScriptIdentifier(scriptData)
	if not scriptData then
		return nil
	end
	return scriptData.slug or scriptData._id or scriptData.id
end

local function getScriptTitle(scriptData)
	if not scriptData then
		return "Unknown"
	end
	return firstNonEmpty(scriptData.title, scriptData.name, scriptData.slug, scriptData._id, "Unknown")
end

local function getGameName(scriptData)
	if scriptData and type(scriptData.game) == "table" then
		local name = firstNonEmpty(scriptData.game.name, scriptData.game.title, scriptData.game.gameName)
		if name ~= "" then
			return name
		end
	end

	if scriptData and scriptData.isUniversal then
		return "Universal"
	end

	return "Unknown Game"
end

local function getScriptImage(scriptData)
	if not scriptData then
		return ""
	end
	return firstNonEmpty(scriptData.image, type(scriptData.game) == "table" and firstNonEmpty(scriptData.game.imageUrl, scriptData.game.imgurl) or "")
end

local function getAuthorName(scriptData)
	if not scriptData then
		return ""
	end

	if type(scriptData.owner) == "table" then
		return firstNonEmpty(scriptData.owner.username, scriptData.owner.name, scriptData.owner.displayName)
	end

	if type(scriptData.user) == "table" then
		return firstNonEmpty(scriptData.user.username, scriptData.user.name, scriptData.user.displayName)
	end

	if type(scriptData.uploader) == "table" then
		return firstNonEmpty(scriptData.uploader.username, scriptData.uploader.name, scriptData.uploader.displayName)
	end

	if type(scriptData.author) == "table" then
		return firstNonEmpty(scriptData.author.username, scriptData.author.name, scriptData.author.displayName)
	end

	if type(scriptData.owner) == "string" then
		return scriptData.owner
	end

	if type(scriptData.author) == "string" then
		return scriptData.author
	end

	return ""
end

local function getAuthorImage(scriptData)
	if not scriptData then
		return ""
	end

	local possibleTables = {
		scriptData.owner,
		scriptData.user,
		scriptData.uploader,
		scriptData.author
	}

	for _, value in ipairs(possibleTables) do
		if type(value) == "table" then
			local image = firstNonEmpty(
				value.profilePicture,
				value.profilePictureUrl,
				value.avatar,
				value.avatarUrl,
				value.image,
				value.imageUrl,
				value.picture,
				value.pictureUrl,
				value.photo,
				value.photoUrl,
				value.pfp,
				value.pfpUrl
			)

			if image ~= "" then
				return image
			end
		end
	end

	return ""
end


local function formatDate(value)
	value = tostring(value or "")
	if value:match("^%d%d%d%d%-%d%d%-%d%d") then
		return value:sub(1, 10)
	end
	return ""
end

local function getDateLine(scriptData)
	if not scriptData then
		return ""
	end

	local updated = formatDate(scriptData.updatedAt)
	local created = formatDate(scriptData.createdAt)

	if updated ~= "" then
		return "Updated: " .. updated
	end

	if created ~= "" then
		return "Created: " .. created
	end

	return ""
end

local function getFeatures(scriptData)
	if not scriptData then
		return "No script selected."
	end

	local features = firstNonEmpty(scriptData.features, scriptData.description, scriptData.summary)
	if features ~= "" then
		return features
	end

	return "No feature text provided."
end

local function tagsToText(tags)
	if type(tags) ~= "table" or #tags == 0 then
		return "None"
	end

	local result = {}

	for _, tag in ipairs(tags) do
		if type(tag) == "string" and tag ~= "" then
			table.insert(result, tag)
		elseif type(tag) == "table" then
			local name = firstNonEmpty(tag.name, tag.title, tag.slug)
			if name ~= "" then
				table.insert(result, name)
			end
		end
	end

	return #result > 0 and table.concat(result, ", ") or "None"
end


local function truthy(value)
	return value == true or value == 1 or value == "1" or tostring(value):lower() == "true" or tostring(value):lower() == "yes"
end

local function currentPlaceId()
	return tostring(game.PlaceId or "")
end

local function getScriptPlaceId(scriptData)
	if not scriptData then
		return ""
	end

	local candidates = {
		scriptData.placeId,
		scriptData.gameId,
		scriptData.rootPlaceId,
		scriptData.PlaceId
	}

	if type(scriptData.game) == "table" then
		table.insert(candidates, scriptData.game.placeId)
		table.insert(candidates, scriptData.game.PlaceId)
		table.insert(candidates, scriptData.game.gameId)
		table.insert(candidates, scriptData.game.rootPlaceId)
		table.insert(candidates, scriptData.game.id)
	end

	for _, value in ipairs(candidates) do
		if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "0" then
			return tostring(value)
		end
	end

	return ""
end

local function isUniversalScript(scriptData)
	if not scriptData then
		return false
	end

	return truthy(scriptData.isUniversal) or truthy(scriptData.universal) or tostring(getGameName(scriptData)):lower() == "universal"
end

local function favoriteItems()
	local items = {}

	for _, item in pairs(state.favorites) do
		if type(item) == "table" then
			table.insert(items, item)
		end
	end

	table.sort(items, function(a, b)
		return tonumber(a.AddedAt or 0) > tonumber(b.AddedAt or 0)
	end)

	return items
end

local function loadFavorites()
	state.favorites = {}

	if Configs and Google.Options and Google.Options.ScriptFinderFavorites then
		local ok, loaded = pcall(function()
			return Configs:Load("script_finder")
		end)

		if ok and loaded then
			return
		end
	end

	if type(isfile) ~= "function" or type(readfile) ~= "function" then
		return
	end

	local ok, exists = pcall(function()
		return isfile(FavoritesFile)
	end)

	if not ok or not exists then
		return
	end

	local readOk, raw = pcall(function()
		return readfile(FavoritesFile)
	end)

	if not readOk or type(raw) ~= "string" or raw == "" then
		return
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)

	if not decodedOk or type(decoded) ~= "table" then
		return
	end

	local source = decoded.Items or decoded

	if type(source) ~= "table" then
		return
	end

	for key, item in pairs(source) do
		if type(item) == "table" then
			local id = tostring(item.Id or item.ID or item.id or key or "")
			if id ~= "" then
				item.Id = id
				state.favorites[id] = item
			end
		end
	end
end

local function saveFavorites()
	if Configs and Google.Options and Google.Options.ScriptFinderFavorites then
		local ok, saved = pcall(function()
			return Configs:Save("script_finder")
		end)

		if ok and saved then
			return true
		end
	end

	if type(writefile) ~= "function" then
		return false
	end

	ensureAutoRerunFolder()

	local data = {
		Version = 1,
		Items = favoriteItems()
	}

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)

	if not ok then
		return false
	end

	local writeOk = pcall(function()
		writefile(FavoritesFile, encoded)
	end)

	return writeOk == true
end

local function makeFavoriteEntry(scriptData)
	local id = getScriptIdentifier(scriptData)
	if not id then
		return nil
	end

	local universal = isUniversalScript(scriptData)
	local placeId = getScriptPlaceId(scriptData)
	local activePlaceId = trim(state.placeId or "")

	if universal then
		placeId = ""
	elseif activePlaceId ~= "" then
		placeId = activePlaceId
	elseif placeId == "" then
		placeId = currentPlaceId()
	end

	return {
		Id = tostring(id),
		Title = getScriptTitle(scriptData),
		Game = getGameName(scriptData),
		Source = scriptData._source or state.source or "scriptblox",
		Image = getScriptImage(scriptData),
		PlaceId = placeId,
		Universal = universal,
		AddedAt = os.time(),
		Data = scriptData
	}
end

local function isFavorite(scriptData)
	local id = getScriptIdentifier(scriptData)
	return id ~= nil and state.favorites[tostring(id)] ~= nil
end

updateFavoriteButton = function()
	if not ui.favoriteButton then
		return
	end

	if not state.selected then
		ui.favoriteButton.Text = "Favorite Script"
		return
	end

	ui.favoriteButton.Text = isFavorite(state.selected) and "Favorited" or "Favorite Script"
end

local function removeFavorite(id)
	id = tostring(id or "")
	if id == "" then
		return
	end

	state.favorites[id] = nil
	saveFavorites()

	if renderFavorites then
		renderFavorites()
	end

	if updateFavoriteButton then
		updateFavoriteButton()
	end

	setStatus("Removed favorite.")
end

favoriteSelected = function()
	if not state.selected then
		setStatus("Select a script first.")
		return
	end

	local entry = makeFavoriteEntry(state.selected)
	if not entry then
		setStatus("Missing script identifier.")
		return
	end

	if state.favorites[entry.Id] then
		setStatus("Already in favorites.")
		updateFavoriteButton()
		return
	end

	state.favorites[entry.Id] = entry
	local saved = saveFavorites()

	if renderFavorites then
		renderFavorites()
	end

	if updateFavoriteButton then
		updateFavoriteButton()
	end

	if saved then
		setStatus("Added to favorites.")
	else
		setStatus("Added to favorites for this session. File save unavailable.")
	end
end

local function setFavoritesFromSaved(value)
	state.favorites = {}

	local source = value
	if type(value) == "table" and type(value.Items) == "table" then
		source = value.Items
	end

	if type(source) ~= "table" then
		return
	end

	for key, item in pairs(source) do
		if type(item) == "table" then
			local id = tostring(item.Id or item.ID or item.id or key or "")
			if id ~= "" then
				item.Id = id
				state.favorites[id] = item
			end
		end
	end

	if renderFavorites then
		renderFavorites()
	end

	if updateFavoriteButton then
		updateFavoriteButton()
	end
end

local function registerConfigBackedState()
	if not Google.Options then
		return
	end

	Google.Options.ScriptFinderFavorites = {
		Get = function()
			return favoriteItems()
		end,
		Set = function(_, value)
			setFavoritesFromSaved(value)
		end
	}

	Google.Options.ScriptFinderFavoriteMode = {
		Get = function()
			return state.favoriteMode
		end,
		Set = function(_, value)
			value = tostring(value or "")
			if value == "Universal" or value == "Current Game" then
				state.favoriteMode = value
				if renderFavorites then
					renderFavorites()
				end
			end
		end
	}

	Google.Options.ScriptFinderAutoReopen = {
		Get = function()
			return AutoRerunEnabled
		end,
		Set = function(_, value)
			AutoRerunEnabled = value == true
			writeAutoRerunEnabled(AutoRerunEnabled)
			saveAutoExecuteLoader()
		end
	}
end



local function getSourceName(source)
	source = tostring(source or state.source or "scriptblox")
	if source == "rscripts" then
		return "Rscripts"
	end
	return "ScriptBlox"
end

local function isRscripts()
	return state.source == "rscripts"
end

local function mapSortForRscripts(value)
	value = tostring(value or "")
	if value == "views" then
		return "views"
	elseif value == "likeCount" then
		return "likes"
	elseif value == "createdAt" then
		return "date"
	end
	return "date"
end

local function normalizeRscriptsScript(item)
	if type(item) ~= "table" then
		return nil
	end

	local user = type(item.user) == "table" and item.user or {}
	local gameInfo = type(item.game) == "table" and item.game or {}
	local title = firstNonEmpty(item.title, item.name, item._id, "Unknown")
	local description = firstNonEmpty(item.description, item.desc)
	local gameName = firstNonEmpty(gameInfo.title, gameInfo.name, "Unknown Game")
	local image = firstNonEmpty(item.image, gameInfo.imgurl, gameInfo.imageUrl)
	local isUniversal = tostring(title .. " " .. description .. " " .. gameName):lower():find("universal", 1, true) ~= nil

	return {
		_source = "rscripts",
		_id = item._id or item.id,
		id = item._id or item.id,
		title = title,
		name = title,
		image = image,
		description = description,
		features = description,
		views = item.views or 0,
		likeCount = item.likes or item.likeCount or 0,
		dislikeCount = item.dislikes or item.dislikeCount or 0,
		key = item.keySystem == true,
		isPatched = item.unpatched == false or item.patched == true,
		verified = user.verified == true or item.verified == true,
		isUniversal = isUniversal,
		scriptType = item.paid and "paid" or "free",
		rawScript = item.rawScript,
		createdAt = item.createdAt,
		updatedAt = item.lastUpdated or item.updatedAt,
		user = {
			username = firstNonEmpty(user.username, user.name),
			name = firstNonEmpty(user.username, user.name),
			image = firstNonEmpty(user.image, user.avatar, user.avatarUrl, user.profilePictureUrl),
			verified = user.verified
		},
		game = {
			name = gameName,
			title = gameName,
			placeId = gameInfo.placeId,
			imageUrl = firstNonEmpty(gameInfo.imgurl, gameInfo.imageUrl),
			imgurl = firstNonEmpty(gameInfo.imgurl, gameInfo.imageUrl)
		},
		_original = item
	}
end

local function normalizeRscriptsList(list)
	local output = {}
	if type(list) ~= "table" then
		return output
	end

	for _, item in ipairs(list) do
		local normalized = normalizeRscriptsScript(item)
		if normalized then
			table.insert(output, normalized)
		end
	end

	return output
end

local function buildSearchHeaders()
	if state.source == "rscripts" and trim(state.owner or "") ~= "" then
		return {
			Username = trim(state.owner)
		}
	end

	return nil
end

local function buildRscriptsSearchTerm()
	local parts = {}

	if trim(state.query) ~= "" then
		table.insert(parts, trim(state.query))
	end

	if trim(state.placeId) ~= "" then
		table.insert(parts, trim(state.placeId))
	end

	if state.universalOnly then
		table.insert(parts, "Universal")
	end

	return table.concat(parts, " ")
end


local function mergeTables(base, extra)
	local merged = {}

	if type(base) == "table" then
		for key, value in pairs(base) do
			merged[key] = value
		end
	end

	if type(extra) == "table" then
		for key, value in pairs(extra) do
			merged[key] = value
		end
	end

	return merged
end

local function fetchDetails(scriptData)
	local identifier = getScriptIdentifier(scriptData)

	if not identifier then
		return scriptData
	end

	if scriptData and scriptData._source == "rscripts" then
		local ok, body = requestGet(RscriptsDetailsEndpoint .. "?id=" .. encode(identifier))
		if not ok then
			return scriptData
		end

		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(body)
		end)

		if not decodedOk or type(decoded) ~= "table" then
			return scriptData
		end

		local item = nil
		if type(decoded.script) == "table" then
			item = decoded.script[1] or decoded.script
		elseif type(decoded.success) == "table" then
			item = decoded.success[1] or decoded.success
		end

		local normalized = normalizeRscriptsScript(item)
		if normalized then
			return mergeTables(scriptData, normalized)
		end

		return scriptData
	end

	local ok, body = requestGet(DetailsEndpoint .. encode(identifier))
	if not ok then
		return scriptData
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not decodedOk or type(decoded) ~= "table" then
		return scriptData
	end

	if type(decoded.script) == "table" then
		decoded.script._source = "scriptblox"
		return mergeTables(scriptData, decoded.script)
	end

	return scriptData
end

local function buildSearchUrl()
	if state.source == "rscripts" then
		local url = RscriptsEndpoint .. "?page=" .. encode(state.page)
		url = url .. "&orderBy=" .. encode(mapSortForRscripts(state.sortBy))
		url = url .. "&sort=" .. encode(state.order ~= "" and state.order or "desc")
		url = url .. "&notPaid=true"

		local searchTerm = buildRscriptsSearchTerm()
		if searchTerm ~= "" then
			url = url .. "&q=" .. encode(searchTerm)
		end

		if state.unpatchedOnly then
			url = url .. "&unpatched=true"
		end

		if state.noKeyOnly then
			url = url .. "&noKeySystem=true"
		end

		if state.verifiedOnly then
			url = url .. "&verifiedOnly=true"
		end

		state.lastUrl = url
		return url
	end

	local hasQuery = trim(state.query) ~= ""
	local url = hasQuery and SearchEndpoint or FetchEndpoint

	if hasQuery then
		url = url .. "?q=" .. encode(state.query)
	else
		url = url .. "?page=" .. encode(state.page)
	end

	if hasQuery then
		url = url .. "&page=" .. encode(state.page)
	end

	url = url .. "&max=" .. encode(state.max)
	url = url .. "&sortBy=" .. encode(state.sortBy ~= "" and state.sortBy or "updatedAt")
	url = url .. "&order=" .. encode(state.order ~= "" and state.order or "desc")
	url = url .. "&mode=free"

	if tostring(state.placeId or "") ~= "" then
		url = url .. "&placeId=" .. encode(state.placeId)
	end

	if tostring(state.owner or "") ~= "" then
		url = url .. "&owner=" .. encode(state.owner)
	end

	if hasQuery then
		url = url .. "&strict=false"
	end

	if state.unpatchedOnly then
		url = url .. "&patched=0"
	end

	if state.noKeyOnly then
		url = url .. "&key=0"
	end

	if state.verifiedOnly then
		url = url .. "&verified=1"
	end

	if state.universalOnly then
		url = url .. "&universal=1"
	end

	state.lastUrl = url
	return url
end

local function updateFilterSummary()
	if not ui.filterSummary then
		return
	end

	local filters = {getSourceName(state.source)}

	if state.unpatchedOnly then
		table.insert(filters, "Unpatched")
	end

	if state.noKeyOnly then
		table.insert(filters, "No Key")
	end

	if state.verifiedOnly then
		table.insert(filters, "Verified")
	end

	if state.universalOnly then
		table.insert(filters, "Universal")
	end

	if tostring(state.placeId or "") ~= "" then
		table.insert(filters, "Game: " .. tostring(state.placeId))
	end

	if trim(state.query) == "" then
		table.insert(filters, "Blank search: " .. getSortLabel())
	end

	if trim(state.owner or "") ~= "" then
		table.insert(filters, "Author: " .. state.owner)
	end

	ui.filterSummary.Text = #filters > 0 and table.concat(filters, "  •  ") or "No filters"
end

local function getSortByFromLabel(label)
	label = tostring(label or "")
	if label == "Newest" then
		return "updatedAt"
	elseif label == "Most Viewed" then
		return "views"
	elseif label == "Most Liked" then
		return "likeCount"
	elseif label == "Created" then
		return "createdAt"
	end
	return "updatedAt"
end

local function getOrderFromLabel(label)
	label = tostring(label or "")
	if label == "Ascending" then
		return "asc"
	end
	return "desc"
end

local function getSortLabel()
	if state.sortBy == "views" then
		return state.order == "asc" and "Least Viewed" or "Most Viewed"
	elseif state.sortBy == "likeCount" then
		return state.order == "asc" and "Least Liked" or "Most Liked"
	elseif state.sortBy == "createdAt" then
		return state.order == "asc" and "Oldest Created" or "Newest Created"
	end

	return state.order == "asc" and "Oldest Updated" or "Latest"
end

local function getScriptsTitle()
	local sourceName = getSourceName(state.source)

	if state.query ~= "" then
		return sourceName .. " Scripts"
	end

	if tostring(state.placeId or "") ~= "" then
		return sourceName .. " " .. getSortLabel() .. " Game Scripts"
	end

	return sourceName .. " " .. getSortLabel() .. " Scripts"
end

local function getLoadingText()
	local sourceName = getSourceName(state.source)

	if state.query ~= "" then
		return "Searching " .. sourceName .. "..."
	end

	if tostring(state.placeId or "") ~= "" then
		return "Loading " .. sourceName .. " " .. string.lower(getSortLabel()) .. " game scripts..."
	end

	return "Loading " .. sourceName .. " " .. string.lower(getSortLabel()) .. " scripts..."
end

local setPreviewCode

local function normalizeCodeText(text)
	text = tostring(text or "")
	text = text:gsub("\r\n", "\n")
	text = text:gsub("\r", "\n")
	text = text:gsub("\t", "    ")
	return text
end


local function extractScriptText(value)
	local text = tostring(value or "")
	local stripped = trim(text)

	if stripped == "" then
		return ""
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(stripped)
	end)

	if ok and type(decoded) == "table" then
		if type(decoded.script) == "string" then
			return decoded.script
		end

		if type(decoded.code) == "string" then
			return decoded.code
		end

		if type(decoded.raw) == "string" then
			return decoded.raw
		end

		if type(decoded.content) == "string" then
			return decoded.content
		end

		if type(decoded.result) == "table" then
			if type(decoded.result.script) == "string" then
				return decoded.result.script
			end

			if type(decoded.result.code) == "string" then
				return decoded.result.code
			end

			if type(decoded.result.raw) == "string" then
				return decoded.result.raw
			end

			if type(decoded.result.content) == "string" then
				return decoded.result.content
			end
		end
	end

	return normalizeCodeText(text)
end

local function resolveExecutableText(value)
	local text = extractScriptText(value)
	local stripped = trim(text)

	if stripped:match("^https?://") then
		setStatus("Fetching script URL...")

		local ok, body = requestGet(stripped)

		if ok and type(body) == "string" and body ~= "" then
			return extractScriptText(body)
		end

		setStatus("Failed to fetch script URL.")
		return nil
	end

	return text
end

local function runExecutableText(text)
	text = resolveExecutableText(text)

	if not text or trim(text) == "" then
		setStatus("No executable code found.")
		return false
	end

	if type(loadstring) ~= "function" then
		setStatus("loadstring is unavailable in this environment.")
		return false
	end

	local compiled, compileError = loadstring(text)

	if not compiled then
		setStatus("Compile failed.")
		warn(compileError)
		return false
	end

	local packed = {pcall(compiled)}
	local ok = table.remove(packed, 1)

	if not ok then
		setStatus("Runtime error.")
		warn(packed[1])
		return false
	end

	if type(packed[1]) == "function" then
		local returnedOk, returnedError = pcall(packed[1])

		if not returnedOk then
			setStatus("Returned function failed.")
			warn(returnedError)
			return false
		end
	end

	return true
end


local function fetchRawSelected()
	if not state.selected then
		setStatus("Select a script first.")
		return nil
	end

	if type(state.selected.script) == "string" and state.selected.script ~= "" then
		local codeText = extractScriptText(state.selected.script)

		if setPreviewCode then
			setPreviewCode(codeText)
		end

		return codeText
	end

	local identifier = getScriptIdentifier(state.selected)
	if not identifier then
		setStatus("Missing script identifier.")
		return nil
	end

	setStatus("Fetching raw script...")

	local rawUrl = nil
	if state.selected._source == "rscripts" then
		rawUrl = state.selected.rawScript
	end

	local ok, body
	if rawUrl and tostring(rawUrl) ~= "" then
		ok, body = requestGet(rawUrl)
	else
		ok, body = requestGet(RawEndpoint .. encode(identifier))
	end

	if not ok or type(body) ~= "string" then
		setStatus("Failed to fetch raw script.")
		return nil
	end

	local codeText = extractScriptText(body)
	state.selected.script = codeText

	if setPreviewCode then
		setPreviewCode(codeText)
	end

	return codeText
end



local function escapeRichText(value)
	value = tostring(value or "")
	value = value:gsub("&", "&amp;")
	value = value:gsub("<", "&lt;")
	value = value:gsub(">", "&gt;")
	value = value:gsub('"', "&quot;")
	return value
end

local syntaxColors = {
	Text = "224,214,212",
	Comment = "106,153,85",
	String = "214,157,133",
	Number = "181,206,168",
	Keyword = "197,134,192",
	Constant = "86,156,214",
	Global = "78,201,176",
	Service = "86,182,194",
	Builtin = "220,220,170",
	Method = "156,220,254",
	Operator = "212,121,121",
	Punctuation = "145,130,128"
}

local keywordSet = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
	["local"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true,
	["then"] = true, ["until"] = true, ["while"] = true, ["continue"] = true, ["export"] = true,
	["type"] = true
}

local constantSet = {
	["true"] = true, ["false"] = true, ["nil"] = true, ["self"] = true
}

local globalSet = {
	game = true, workspace = true, script = true,
	Instance = true, Enum = true, Color3 = true, Vector2 = true, Vector3 = true,
	UDim = true, UDim2 = true, CFrame = true, TweenInfo = true,
	RaycastParams = true, NumberRange = true, NumberSequence = true,
	ColorSequence = true, BrickColor = true, Region3 = true
}

local serviceSet = {
	Players = true, RunService = true, UserInputService = true, TweenService = true,
	HttpService = true, CoreGui = true, Workspace = true, ReplicatedStorage = true,
	Lighting = true, StarterGui = true, StarterPack = true, StarterPlayer = true,
	Teams = true, SoundService = true, TextService = true, CollectionService = true,
	TeleportService = true, MarketplaceService = true, Debris = true, PathfindingService = true
}

local builtinSet = {
	print = true, warn = true, error = true, pcall = true, xpcall = true,
	pairs = true, ipairs = true, next = true, type = true, typeof = true,
	tostring = true, tonumber = true, require = true, loadstring = true,
	assert = true, select = true, unpack = true, getfenv = true, setfenv = true,
	rawequal = true, rawget = true, rawset = true, newproxy = true,
	math = true, table = true, string = true, task = true, coroutine = true,
	os = true, debug = true, utf8 = true, wait = true, spawn = true, delay = true
}

local function paint(value, colorName)
	return '<font color="rgb(' .. syntaxColors[colorName] .. ')">' .. escapeRichText(value) .. '</font>'
end

local function isAlpha(value)
	return value:match("[%a_]") ~= nil
end

local function isAlnum(value)
	return value:match("[%w_]") ~= nil
end

local function previousNonSpace(text, index)
	for i = index, 1, -1 do
		local char = text:sub(i, i)
		if char ~= " " and char ~= "\t" and char ~= "\n" then
			return char
		end
	end
	return ""
end

local function highlightLuau(source)
	source = normalizeCodeText(source)
	local result = {}
	local i = 1
	local length = #source

	while i <= length do
		local char = source:sub(i, i)
		local nextTwo = source:sub(i, i + 1)

		if nextTwo == "--" then
			if source:sub(i + 2, i + 3) == "[[" then
				local closeStart, closeEnd = source:find("%]%]", i + 4)
				local stop = closeEnd or length
				table.insert(result, paint(source:sub(i, stop), "Comment"))
				i = stop + 1
			else
				local lineEnd = source:find("\n", i + 2, true)
				local stop = lineEnd and (lineEnd - 1) or length
				table.insert(result, paint(source:sub(i, stop), "Comment"))
				i = stop + 1
			end
		elseif source:sub(i, i + 1) == "[[" then
			local closeStart, closeEnd = source:find("%]%]", i + 2)
			local stop = closeEnd or length
			table.insert(result, paint(source:sub(i, stop), "String"))
			i = stop + 1
		elseif char == '"' or char == "'" then
			local quote = char
			local j = i + 1
			while j <= length do
				local current = source:sub(j, j)
				if current == "\\" then
					j = j + 2
				elseif current == quote then
					j = j + 1
					break
				else
					j = j + 1
				end
			end
			table.insert(result, paint(source:sub(i, math.min(j - 1, length)), "String"))
			i = j
		elseif char:match("%d") then
			local j = i
			while j <= length and source:sub(j, j):match("[%w_%.]") do
				j = j + 1
			end
			table.insert(result, paint(source:sub(i, j - 1), "Number"))
			i = j
		elseif isAlpha(char) then
			local j = i
			while j <= length and isAlnum(source:sub(j, j)) do
				j = j + 1
			end

			local word = source:sub(i, j - 1)
			local previous = previousNonSpace(source, i - 1)

			if previous == "." or previous == ":" then
				table.insert(result, paint(word, "Method"))
			elseif keywordSet[word] then
				table.insert(result, paint(word, "Keyword"))
			elseif constantSet[word] then
				table.insert(result, paint(word, "Constant"))
			elseif serviceSet[word] then
				table.insert(result, paint(word, "Service"))
			elseif globalSet[word] then
				table.insert(result, paint(word, "Global"))
			elseif builtinSet[word] then
				table.insert(result, paint(word, "Builtin"))
			else
				table.insert(result, paint(word, "Text"))
			end

			i = j
		elseif char:match("[%+%-%*/%%%^#=<>~]") then
			table.insert(result, paint(char, "Operator"))
			i = i + 1
		elseif char:match("[%(%){%}%[%],;:]") or char == "." then
			table.insert(result, paint(char, "Punctuation"))
			i = i + 1
		else
			table.insert(result, escapeRichText(char))
			i = i + 1
		end
	end

	return table.concat(result)
end

local function highlightLuauWithLineNumbers(source)
	source = normalizeCodeText(source)
	local output = {}
	local lineNumber = 1
	local position = 1

	if source == "" then
		return paint("   1  ", "Punctuation")
	end

	while position <= #source + 1 do
		local nextNewline = source:find("\n", position, true)
		local line

		if nextNewline then
			line = source:sub(position, nextNewline - 1)
			position = nextNewline + 1
		else
			line = source:sub(position)
			position = #source + 2
		end

		table.insert(output, paint(string.format("%4d  ", lineNumber), "Punctuation"))
		table.insert(output, highlightLuau(line))

		if position <= #source + 1 then
			table.insert(output, "\n")
		end

		lineNumber = lineNumber + 1
	end

	return table.concat(output)
end

local function buildLineNumbers(text)
	text = normalizeCodeText(text)
	local lineCount = 1
	for _ in text:gmatch("\n") do
		lineCount = lineCount + 1
	end

	local lines = {}
	for i = 1, lineCount do
		lines[i] = tostring(i)
	end

	return table.concat(lines, "\n")
end

local function updateCustomCodeBlock(text)
	text = normalizeCodeText(text)
	ui.previewRaw = text

	if not ui.previewCode or not ui.previewScroll then
		return
	end

	ui.previewCode.RichText = true
	ui.previewCode.TextWrapped = false
	ui.previewCode.TextTruncate = Enum.TextTruncate.None
	ui.previewCode.Text = highlightLuauWithLineNumbers(text)

	task.defer(function()
		if not ui.previewCode or not ui.previewScroll then
			return
		end

		local bounds = ui.previewCode.TextBounds
		local width = math.max(bounds.X + 30, ui.previewScroll.AbsoluteSize.X + 1)
		local height = math.max(bounds.Y + 30, ui.previewScroll.AbsoluteSize.Y + 1)

		ui.previewCode.Size = UDim2.fromOffset(width, height)

		ui.previewScroll.CanvasSize = UDim2.fromOffset(width + 12, height + 12)
	end)
end

setPreviewCode = function(text)
	updateCustomCodeBlock(text)

	if ui.selectedPreview and ui.selectedPreview ~= ui.previewCode then
		text = normalizeCodeText(text)

		if type(ui.selectedPreview.SetCode) == "function" then
			pcall(function()
				ui.selectedPreview:SetCode(text)
			end)
		elseif type(ui.selectedPreview.SetText) == "function" then
			pcall(function()
				ui.selectedPreview:SetText(text)
			end)
		elseif ui.selectedPreview.Text ~= nil then
			pcall(function()
				ui.selectedPreview.Text = text
			end)
		end
	end
end

local function updateSelected()
	if not ui.selectedTitle then
		return
	end

	if not state.selected then
		ui.selectedTitle.Text = "No script selected"
		ui.selectedGame.Text = "Select a script from the Scripts tab."
		ui.selectedMeta.Text = "Author and stats will appear here."
		ui.selectedFeatures.Text = "Features will appear here."
		ui.selectedTags.Text = "Tags will appear here."
		setPreviewCode("Script preview will appear here.")
		ui.selectedImage.Image = ""
		if ui.selectedAuthorImage then
			ui.selectedAuthorImage.Image = ""
		end
		if updateFavoriteButton then
			updateFavoriteButton()
		end
		return
	end

	local scriptData = state.selected
	local title = getScriptTitle(scriptData)
	local gameName = getGameName(scriptData)
	local author = getAuthorName(scriptData)
	local image = resolveImage(getScriptImage(scriptData), getScriptIdentifier(scriptData) or title)
	local authorImage = resolveImage(getAuthorImage(scriptData), (getScriptIdentifier(scriptData) or title) .. "_author")
	local dateLine = getDateLine(scriptData)

	if author == "" then
		author = "Unavailable"
	end

	local meta = {
		"Author: " .. author,
		"Views: " .. tostring(scriptData.views or 0),
		"Likes: " .. tostring(scriptData.likeCount or "N/A"),
		"Dislikes: " .. tostring(scriptData.dislikeCount or "N/A"),
		"Verified: " .. boolToText(scriptData.verified),
		"Key: " .. boolToText(scriptData.key),
		"Patched: " .. boolToText(scriptData.isPatched),
		"Universal: " .. boolToText(scriptData.isUniversal),
		"Type: " .. tostring(scriptData.scriptType or "free"),
		"Source: " .. getSourceName(scriptData._source or state.source)
	}

	if dateLine ~= "" then
		table.insert(meta, 4, dateLine)
	end

	ui.selectedTitle.Text = title
	ui.selectedGame.Text = gameName
	ui.selectedMeta.Text = table.concat(meta, "\n")
	ui.selectedFeatures.Text = getFeatures(scriptData)
	ui.selectedTags.Text = tagsToText(scriptData.tags)
	ui.selectedImage.Image = image
	if ui.selectedAuthorImage then
		ui.selectedAuthorImage.Image = authorImage
	end

	local raw = tostring(scriptData.script or "")
	if raw ~= "" then
		raw = raw:gsub("\r", "")
		setPreviewCode(raw)
	else
		setPreviewCode("Use Copy Raw to fetch the raw script.")
	end

	if updateFavoriteButton then
		updateFavoriteButton()
	end
end


local function executeSelected()
	local raw = fetchRawSelected()

	if not raw or trim(raw) == "" then
		setStatus("No script available to execute.")
		return
	end

	setStatus("Executing selected script...")

	if runExecutableText(raw) then
		setStatus("Executed selected script.")
	end
end

selectScript = function(scriptData)
	state.selected = fetchDetails(scriptData)

	if not (type(state.selected.script) == "string" and state.selected.script ~= "") then
		local identifier = getScriptIdentifier(state.selected)

		if state.selected._source == "rscripts" and state.selected.rawScript and tostring(state.selected.rawScript) ~= "" then
			local ok, body = requestGet(state.selected.rawScript)
			if ok and type(body) == "string" and body ~= "" then
				state.selected.script = extractScriptText(body)
			end
		elseif identifier then
			local ok, body = requestGet(RawEndpoint .. encode(identifier))
			if ok and type(body) == "string" and body ~= "" then
				state.selected.script = extractScriptText(body)
			end
		end
	end

	updateSelected()
	safeSelectTab(SelectedTab)
	setStatus("Selected: " .. getScriptTitle(state.selected))
end

local function clearScriptsPage()
	local page = ScriptsTab and ScriptsTab.Page
	if not page then
		return
	end

	for _, child in ipairs(page:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	if ScriptsTab.Sections then
		table.clear(ScriptsTab.Sections)
	end
end

local function createEmptyScripts(text)
	clearScriptsPage()

	local page = ScriptsTab.Page
	local panel = createPanel(page, 96, 1, color("Card", Color3.fromRGB(17, 24, 39)))
	panel.Name = "EmptyScripts"

	createText(panel, {
		Text = text or "No scripts loaded",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(14, 16),
		Size = UDim2.new(1, -28, 0, 24)
	})

	createText(panel, {
		Text = "Use the Search tab to load results.",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 0, 22)
	})
end

local function createScriptCard(parent, scriptData, index)
	local card = Instance.new("TextButton")
	card.Name = "ScriptCard_" .. tostring(index)
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = color("Card", Color3.fromRGB(17, 24, 39))
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Parent = parent

	addCorner(card, 12)
	addStroke(card, color("Border", Color3.fromRGB(51, 65, 85)), 0.14, 1)

	local title = getScriptTitle(scriptData)
	local imageAsset = resolveImage(getScriptImage(scriptData), getScriptIdentifier(scriptData) or title)

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.BackgroundColor3 = color("CardAlt", Color3.fromRGB(30, 41, 59))
	thumbnail.BorderSizePixel = 0
	thumbnail.Position = UDim2.fromOffset(10, 10)
	thumbnail.Size = UDim2.new(1, -20, 1, -46)
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Image = imageAsset
	thumbnail.Parent = card

	addCorner(thumbnail, 10)
	addStroke(thumbnail, color("Border", Color3.fromRGB(51, 65, 85)), 0.2, 1)

	if imageAsset == "" then
		createText(thumbnail, {
			Text = "No Image",
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1)
		})
	end

	createText(card, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Position = UDim2.new(0, 10, 1, -30),
		Size = UDim2.new(1, -20, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = color("Hover", Color3.fromRGB(30, 41, 59))
	end)

	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = color("Card", Color3.fromRGB(17, 24, 39))
	end)

	card.MouseButton1Click:Connect(function()
		selectScript(scriptData)
	end)

	return card
end


local function clearFavoritesPage()
	local page = FavoritesTab and FavoritesTab.Page
	if not page then
		return
	end

	for _, child in ipairs(page:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function getVisibleFavorites()
	local visible = {}
	local placeId = currentPlaceId()

	for _, item in ipairs(favoriteItems()) do
		if state.favoriteMode == "Universal" then
			if item.Universal == true then
				table.insert(visible, item)
			end
		else
			if item.Universal ~= true and tostring(item.PlaceId or "") == placeId then
				table.insert(visible, item)
			end
		end
	end

	return visible
end

local function createFavoriteCard(parent, item, index)
	local data = item.Data or item
	local card = Instance.new("TextButton")
	card.Name = "FavoriteCard_" .. tostring(index)
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = color("Card", Color3.fromRGB(17, 24, 39))
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Parent = parent

	addCorner(card, 12)
	addStroke(card, color("Border", Color3.fromRGB(51, 65, 85)), 0.14, 1)

	local title = firstNonEmpty(item.Title, getScriptTitle(data))
	local imageAsset = resolveImage(firstNonEmpty(item.Image, getScriptImage(data)), item.Id or getScriptIdentifier(data) or title)

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.BackgroundColor3 = color("CardAlt", Color3.fromRGB(30, 41, 59))
	thumbnail.BorderSizePixel = 0
	thumbnail.Position = UDim2.fromOffset(10, 10)
	thumbnail.Size = UDim2.new(1, -20, 0, 82)
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Image = imageAsset
	thumbnail.Parent = card
	addCorner(thumbnail, 10)
	addStroke(thumbnail, color("Border", Color3.fromRGB(51, 65, 85)), 0.2, 1)

	if imageAsset == "" then
		createText(thumbnail, {
			Text = "No Image",
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1)
		})
	end

	createText(card, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Position = UDim2.fromOffset(10, 98),
		Size = UDim2.new(1, -20, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	createText(card, {
		Text = item.Universal and "Universal" or (firstNonEmpty(item.Game, "Unknown Game") .. "  •  " .. tostring(item.PlaceId or "Unknown")),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
		Position = UDim2.fromOffset(10, 118),
		Size = UDim2.new(1, -20, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	local remove = createButton(card, "Remove", UDim2.new(1, -82, 1, -30), UDim2.fromOffset(70, 22), function()
		removeFavorite(item.Id)
	end, true)

	remove.TextSize = 11

	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = color("Hover", Color3.fromRGB(30, 41, 59))
	end)

	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = color("Card", Color3.fromRGB(17, 24, 39))
	end)

	card.MouseButton1Click:Connect(function()
		selectScript(data)
	end)

	return card
end

renderFavorites = function()
	if not FavoritesTab then
		return
	end

	clearFavoritesPage()

	local page = FavoritesTab.Page
	local visible = getVisibleFavorites()

	local top = createPanel(page, 116, 1, color("Card", Color3.fromRGB(17, 24, 39)))
	top.Name = "FavoritesTop"

	createText(top, {
		Text = "Favorite scripts",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244)),
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 22)
	})

	ui.favoriteInfo = createText(top, {
		Text = state.favoriteMode .. "  •  " .. tostring(#visible) .. " saved",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244)),
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 18)
	})

	ui.favoriteCurrentButton = createButton(top, "Current Game", UDim2.fromOffset(14, 66), UDim2.fromOffset(130, 30), function()
		state.favoriteMode = "Current Game"
		saveConfigState()
		renderFavorites()
	end, state.favoriteMode ~= "Current Game")

	ui.favoriteUniversalButton = createButton(top, "Universal", UDim2.fromOffset(154, 66), UDim2.fromOffset(110, 30), function()
		state.favoriteMode = "Universal"
		saveConfigState()
		renderFavorites()
	end, state.favoriteMode ~= "Universal")

	createText(top, {
		Text = "Current PlaceId: " .. currentPlaceId(),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -292, 0, 72),
		Size = UDim2.fromOffset(278, 18),
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	if #visible == 0 then
		local empty = createPanel(page, 96, 2, color("Card", Color3.fromRGB(17, 24, 39)))

		createText(empty, {
			Text = state.favoriteMode == "Universal" and "No universal favorites yet" or "No favorites for this game yet",
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.new(1, -28, 0, 24)
		})

		createText(empty, {
			Text = "Use the Selected tab to add a script to favorites.",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -28, 0, 22)
		})

		return
	end

	local grid = Instance.new("Frame")
	grid.Name = "FavoritesGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ClipsDescendants = true
	grid.LayoutOrder = 2
	grid.Size = UDim2.new(1, -10, 0, 0)
	grid.Parent = page

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.333333, -10, 0, 172)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for index, item in ipairs(visible) do
		createFavoriteCard(grid, item, index)
	end

	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		grid.Size = UDim2.new(1, -10, 0, gridLayout.AbsoluteContentSize.Y + 8)
	end)

	grid.Size = UDim2.new(1, -10, 0, gridLayout.AbsoluteContentSize.Y + 8)
end



local function createSourceCircle(parent, source, xOffset, labelText, logoUrl)
	local active = state.source == source

	local button = Instance.new("TextButton")
	button.Name = source .. "SourceButton"
	button.Text = ""
	button.BackgroundColor3 = active and color("PrimarySoft", Color3.fromRGB(30, 58, 105)) or color("CardAlt", Color3.fromRGB(30, 41, 59))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Position = UDim2.new(1, xOffset, 0, 8)
	button.Size = UDim2.fromOffset(46, 46)
	button.Parent = parent
	addCorner(button, 8)
	addStroke(button, active and color("Primary", Color3.fromRGB(67, 135, 244)) or color("Border", Color3.fromRGB(51, 65, 85)), active and 0.08 or 0.28, 1)

	local img = Instance.new("ImageLabel")
	img.Name = "Logo"
	img.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	img.BackgroundTransparency = 0
	img.BorderSizePixel = 0
	img.Position = UDim2.fromOffset(5, 5)
	img.Size = UDim2.fromOffset(36, 36)
	img.Image = logoUrl
	img.ImageTransparency = 0
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = button
	addCorner(img, 7)

	if source == "scriptblox" then
		ui.sourceScriptBloxButton = button
	else
		ui.sourceRscriptsButton = button
	end

	button.MouseButton1Click:Connect(function()
		if state.source == source then
			return
		end

		state.source = source
		state.page = 1
		setStatus("Switched to " .. getSourceName(source) .. ".")
		searchScripts()
	end)

	return button
end

local function renderScripts()
	clearScriptsPage()

	local page = ScriptsTab.Page

	local top = createPanel(page, 96, 1, color("Card", Color3.fromRGB(17, 24, 39)))
	top.Name = "ScriptsTop"

	createText(top, {
		Text = getScriptsTitle(),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244)),
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 22)
	})

	ui.scriptsInfo = createText(top, {
		Text = "Page " .. tostring(state.page) .. " / " .. tostring(state.totalPages > 0 and state.totalPages or "?") .. "  •  " .. tostring(#state.results) .. " results",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -300, 0, 18)
	})

	createSourceCircle(top, "scriptblox", -114, "SB", ScriptBloxLogoURL)
	createSourceCircle(top, "rscripts", -60, "R", RscriptsLogoURL)

	createButton(top, "Previous", UDim2.new(1, -214, 0, 56), UDim2.fromOffset(96, 28), function()
		if state.page <= 1 then
			setStatus("Already on the first page.")
			return
		end
		state.page = math.max(1, state.page - 1)
		searchScripts()
	end, true)

	createButton(top, "Next", UDim2.new(1, -108, 0, 56), UDim2.fromOffset(82, 28), function()
		if state.totalPages <= 0 or state.page >= state.totalPages then
			setStatus("Already on the last page.")
			return
		end
		state.page = state.page + 1
		searchScripts()
	end, false)

	local grid = Instance.new("Frame")
	grid.Name = "ScriptGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ClipsDescendants = true
	grid.LayoutOrder = 2
	grid.Size = UDim2.new(1, -10, 0, 0)
	grid.Parent = page

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.333333, -10, 0, 158)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for index, scriptData in ipairs(state.results) do
		createScriptCard(grid, scriptData, index)
	end

	if #state.results == 0 then
		local empty = createPanel(page, 92, 3, color("Card", Color3.fromRGB(17, 24, 39)))
		empty.Name = "NoResults"

		createText(empty, {
			Text = "No scripts found",
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.new(1, -28, 0, 24)
		})

		createText(empty, {
			Text = "Try removing filters, changing the game PlaceId, or searching by name.",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.new(1, -28, 0, 36)
		})
	end

	local rows = math.max(0, math.ceil(#state.results / 3))
	grid.Size = UDim2.new(1, -10, 0, rows * 168)
end

searchScripts = function()
	if state.busy then
		return
	end

	if ui.searchInput then
		state.query = trim(ui.searchInput.Text)
	end

	if ui.maxInput then
		local parsed = tonumber(ui.maxInput.Text)
		if parsed then
			state.max = math.clamp(math.floor(parsed), 1, 30)
			ui.maxInput.Text = tostring(state.max)
		end
	end

	if ui.authorInput then
		state.owner = trim(ui.authorInput.Text)
	end

	if ui.gameInput then
		local rawPlaceId = trim(ui.gameInput.Text)
		if rawPlaceId ~= "" then
			local parsedPlaceId = tonumber(rawPlaceId)
			if parsedPlaceId then
				state.placeId = tostring(math.floor(parsedPlaceId))
				ui.gameInput.Text = state.placeId
			else
				state.placeId = ""
				ui.gameInput.Text = ""
				setStatus("Game filter must be a numeric PlaceId.")
				return
			end
		else
			state.placeId = ""
		end
	end

	if ui.sortDropdown then
		local ok, value = pcall(function()
			if ui.sortDropdown.Get then
				return ui.sortDropdown:Get()
			end
			return ui.sortDropdown.Value
		end)
		if ok and value then
			state.sortBy = getSortByFromLabel(value)
		end
	end

	if ui.orderDropdown then
		local ok, value = pcall(function()
			if ui.orderDropdown.Get then
				return ui.orderDropdown:Get()
			end
			return ui.orderDropdown.Value
		end)
		if ok and value then
			state.order = getOrderFromLabel(value)
		end
	end

	state.busy = true

	local loadingText = getLoadingText()
	setStatus(loadingText)
	createEmptyScripts(loadingText)

	local ok, body = requestGet(buildSearchUrl(), buildSearchHeaders())
	if not ok then
		state.busy = false
		createEmptyScripts("Request failed")
		setStatus("Request failed.")
		warn(body)
		safeSelectTab(ScriptsTab)
		return
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not decodedOk then
		state.busy = false
		createEmptyScripts("Failed to decode response")
		setStatus("Failed to decode response.")
		warn(body)
		safeSelectTab(ScriptsTab)
		return
	end

	if decoded.message or decoded.error then
		state.busy = false
		createEmptyScripts(tostring(decoded.message or decoded.error))
		setStatus(tostring(decoded.message or decoded.error))
		safeSelectTab(ScriptsTab)
		return
	end

	if state.source == "rscripts" then
		if type(decoded.scripts) ~= "table" then
			state.results = {}
			state.totalPages = 0
			state.busy = false
			createEmptyScripts("No scripts found")
			setStatus("No scripts found.")
			safeSelectTab(ScriptsTab)
			return
		end

		state.results = normalizeRscriptsList(decoded.scripts)
		state.totalPages = decoded.info and tonumber(decoded.info.maxPages) or 0
	else
		if not decoded.result or type(decoded.result.scripts) ~= "table" then
			state.results = {}
			state.totalPages = 0
			state.busy = false
			createEmptyScripts("No scripts found")
			setStatus("No scripts found.")
			safeSelectTab(ScriptsTab)
			return
		end

		state.results = decoded.result.scripts
		for _, item in ipairs(state.results) do
			if type(item) == "table" then
				item._source = "scriptblox"
			end
		end
		state.totalPages = tonumber(decoded.result.totalPages) or 0
	end

	renderScripts()
	safeSelectTab(ScriptsTab)
	if state.query == "" and tostring(state.placeId or "") ~= "" then
		setStatus("Loaded " .. tostring(#state.results) .. " " .. getSourceName(state.source) .. " scripts for selected game.")
	elseif tostring(state.owner or "") ~= "" then
		setStatus("Loaded " .. tostring(#state.results) .. " " .. getSourceName(state.source) .. " scripts by " .. state.owner .. ".")
	elseif state.query == "" then
		setStatus("Loaded " .. tostring(#state.results) .. " " .. getSourceName(state.source) .. " scripts.")
	else
		setStatus("Found " .. tostring(#state.results) .. " scripts.")
	end
	state.busy = false
end

Window = Google:CreateWindow({
	Title = "Script Finder",
	Subtitle = "Powered by ScriptBlox.com and Rscripts.net",
	Icon = "search",
	Size = UDim2.fromOffset(740, 530),
	MobileSize = UDim2.fromOffset(430, 610),
	AllowMultiple = false
})

SearchTab = Window:CreateTab({
	Name = "Search",
	Icon = "search"
})

ScriptsTab = Window:CreateTab({
	Name = "Scripts",
	Icon = "image"
})

SelectedTab = Window:CreateTab({
	Name = "Selected",
	Icon = "info"
})

FavoritesTab = Window:CreateTab({
	Name = "Favorite scripts",
	Icon = "star"
})

local searchPage = preparePage(SearchTab)
preparePage(ScriptsTab)
local selectedPage = preparePage(SelectedTab)
preparePage(FavoritesTab)

local searchPanel = createPanel(searchPage, 290, 1, color("Card", Color3.fromRGB(17, 24, 39)))

ui.searchInput = createInput(
	searchPanel,
	"Search",
	"Search scripts or leave blank for latest",
	"",
	UDim2.fromOffset(14, 12),
	UDim2.new(1, -28, 0, 36),
	function(value, enterPressed)
		state.query = trim(value)
		if enterPressed then
			state.page = 1
			searchScripts()
		end
	end
)

ui.authorInput = createInput(
	searchPanel,
	"Author",
	"Optional username filter",
	"",
	UDim2.fromOffset(14, 84),
	UDim2.new(1, -28, 0, 36),
	function(value, enterPressed)
		state.owner = trim(value)
		if enterPressed then
			state.page = 1
			searchScripts()
		end
	end
)

ui.maxInput = createInput(
	searchPanel,
	"Max",
	"12",
	"12",
	UDim2.fromOffset(14, 156),
	UDim2.fromOffset(86, 34),
	function(value)
		local parsed = tonumber(value)
		if parsed then
			state.max = math.clamp(math.floor(parsed), 1, 30)
		end
	end
)

ui.gameInput = createInput(
	searchPanel,
	"Game PlaceId",
	"Optional exact game filter",
	"",
	UDim2.fromOffset(116, 156),
	UDim2.new(1, -246, 0, 34),
	function(value)
		local rawPlaceId = trim(value)
		if rawPlaceId == "" then
			state.placeId = ""
			return
		end

		local parsedPlaceId = tonumber(rawPlaceId)
		if parsedPlaceId then
			state.placeId = tostring(math.floor(parsedPlaceId))
			ui.gameInput.Text = state.placeId
		else
			state.placeId = ""
			ui.gameInput.Text = ""
			setStatus("Game filter must be a numeric PlaceId.")
		end
	end
)

createButton(searchPanel, "Current Game", UDim2.new(1, -116, 0, 180), UDim2.fromOffset(102, 32), function()
	state.placeId = tostring(game.PlaceId)

	if ui.gameInput then
		ui.gameInput.Text = state.placeId
	end

	setStatus("Game filter set to current game.")
end, true)

createButton(searchPanel, "Search", UDim2.fromOffset(14, 226), UDim2.fromOffset(96, 34), function()
	state.page = 1
	searchScripts()
end, false)

createButton(searchPanel, "Clear", UDim2.fromOffset(120, 226), UDim2.fromOffset(82, 34), function()
	state.query = ""
	state.results = {}
	state.totalPages = 0
	state.selected = nil

	if ui.searchInput then
		ui.searchInput.Text = ""
	end

	if ui.maxInput then
		ui.maxInput.Text = tostring(state.max)
	end

	if ui.gameInput then
		ui.gameInput.Text = ""
	end

	if ui.authorInput then
		ui.authorInput.Text = ""
	end

	state.placeId = ""
	state.owner = ""

	createEmptyScripts()
	updateSelected()
	setStatus("Cleared.")
end, true)

local statusWrap = Instance.new("Frame")
statusWrap.BackgroundColor3 = color("CardAlt", Color3.fromRGB(30, 41, 59))
statusWrap.BorderSizePixel = 0
statusWrap.ClipsDescendants = true
statusWrap.Position = UDim2.fromOffset(214, 232)
statusWrap.Size = UDim2.new(1, -228, 0, 22)
statusWrap.Parent = searchPanel

addCorner(statusWrap, 10)
addStroke(statusWrap, color("Border", Color3.fromRGB(51, 65, 85)), 0.18, 1)

ui.status = createText(statusWrap, {
	Text = "Ready.",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244)),
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(1, -20, 1, 0)
})

local filtersPanel = createPanel(searchPage, 162, 2, color("Card", Color3.fromRGB(17, 24, 39)))

createText(filtersPanel, {
	Text = "Filters",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 22)
})

createCheck(filtersPanel, "Unpatched", UDim2.fromOffset(14, 42), UDim2.new(0.5, -20, 0, 36), true, function(value)
	state.unpatchedOnly = value
	updateFilterSummary()
end)

createCheck(filtersPanel, "No Key", UDim2.new(0.5, 6, 0, 42), UDim2.new(0.5, -20, 0, 36), false, function(value)
	state.noKeyOnly = value
	updateFilterSummary()
end)

createCheck(filtersPanel, "Verified", UDim2.fromOffset(14, 82), UDim2.new(0.5, -20, 0, 36), false, function(value)
	state.verifiedOnly = value
	updateFilterSummary()
end)

createCheck(filtersPanel, "Universal", UDim2.new(0.5, 6, 0, 82), UDim2.new(0.5, -20, 0, 36), false, function(value)
	state.universalOnly = value
	updateFilterSummary()
end)

local orderBox
local sortBox = Instance.new("TextButton")
sortBox.Text = "Sort: Newest"
sortBox.Font = Enum.Font.GothamMedium
sortBox.TextSize = 12
sortBox.TextColor3 = color("Text", Color3.fromRGB(241, 245, 249))
sortBox.BackgroundColor3 = color("Input", Color3.fromRGB(31, 31, 35))
sortBox.BorderSizePixel = 0
sortBox.AutoButtonColor = false
sortBox.Position = UDim2.fromOffset(14, 122)
sortBox.Size = UDim2.new(0.5, -20, 0, 30)
sortBox.Parent = filtersPanel
addCorner(sortBox, 10)
addStroke(sortBox, color("Border", Color3.fromRGB(51, 65, 85)), 0.08, 1)

local sortModes = {
	{"Newest", "updatedAt"},
	{"Most Viewed", "views"},
	{"Most Liked", "likeCount"},
	{"Created", "createdAt"}
}
local sortIndex = 1

sortBox.MouseButton1Click:Connect(function()
	sortIndex = sortIndex + 1
	if sortIndex > #sortModes then
		sortIndex = 1
	end
	sortBox.Text = "Sort: " .. sortModes[sortIndex][1]
	state.sortBy = sortModes[sortIndex][2]

	if state.sortBy == "views" then
		state.order = "desc"
		if orderBox then
			orderBox.Text = "Order: Desc"
		end
	end

	updateFilterSummary()
end)

orderBox = Instance.new("TextButton")
orderBox.Text = "Order: Desc"
orderBox.Font = Enum.Font.GothamMedium
orderBox.TextSize = 12
orderBox.TextColor3 = color("Text", Color3.fromRGB(241, 245, 249))
orderBox.BackgroundColor3 = color("Input", Color3.fromRGB(31, 31, 35))
orderBox.BorderSizePixel = 0
orderBox.AutoButtonColor = false
orderBox.Position = UDim2.new(0.5, 6, 0, 122)
orderBox.Size = UDim2.new(0.5, -20, 0, 30)
orderBox.Parent = filtersPanel
addCorner(orderBox, 10)
addStroke(orderBox, color("Border", Color3.fromRGB(51, 65, 85)), 0.08, 1)

orderBox.MouseButton1Click:Connect(function()
	if state.order == "desc" then
		state.order = "asc"
		orderBox.Text = "Order: Asc"
	else
		state.order = "desc"
		orderBox.Text = "Order: Desc"
	end

	updateFilterSummary()
end)

ui.filterSummary = Instance.new("TextLabel")
ui.filterSummary.Name = "FilterSummaryHidden"
ui.filterSummary.BackgroundTransparency = 1
ui.filterSummary.BorderSizePixel = 0
ui.filterSummary.Text = ""
ui.filterSummary.Visible = false
ui.filterSummary.Size = UDim2.fromOffset(0, 0)
ui.filterSummary.Parent = searchPage

local startupPanel = createPanel(searchPage, 74, 3, color("Card", Color3.fromRGB(17, 24, 39)))

createText(startupPanel, {
	Text = "Startup",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 20)
})

createCheck(startupPanel, "Auto Reopen", UDim2.fromOffset(14, 36), UDim2.new(1, -28, 0, 32), AutoRerunEnabled, function(value)
	setAutoRerun(value)
end)

local selectedTop = createPanel(selectedPage, 248, 1, color("Card", Color3.fromRGB(17, 24, 39)))

ui.selectedImage = Instance.new("ImageLabel")
ui.selectedImage.BackgroundColor3 = color("CardAlt", Color3.fromRGB(30, 41, 59))
ui.selectedImage.BorderSizePixel = 0
ui.selectedImage.Position = UDim2.fromOffset(14, 14)
ui.selectedImage.Size = UDim2.fromOffset(142, 142)
ui.selectedImage.ScaleType = Enum.ScaleType.Crop
ui.selectedImage.Image = ""
ui.selectedImage.Parent = selectedTop

addCorner(ui.selectedImage, 12)
addStroke(ui.selectedImage, color("Border", Color3.fromRGB(51, 65, 85)), 0.18, 1)

local authorWrap = Instance.new("Frame")
authorWrap.BackgroundColor3 = color("Input", Color3.fromRGB(15, 23, 42))
authorWrap.BorderSizePixel = 0
authorWrap.Position = UDim2.fromOffset(104, 104)
authorWrap.Size = UDim2.fromOffset(46, 46)
authorWrap.Parent = selectedTop
addCorner(authorWrap, 23)
addStroke(authorWrap, color("Border", Color3.fromRGB(51, 65, 85)), 0.16, 1)

ui.selectedAuthorImage = Instance.new("ImageLabel")
ui.selectedAuthorImage.BackgroundTransparency = 1
ui.selectedAuthorImage.BorderSizePixel = 0
ui.selectedAuthorImage.Position = UDim2.fromOffset(4, 4)
ui.selectedAuthorImage.Size = UDim2.fromOffset(38, 38)
ui.selectedAuthorImage.ScaleType = Enum.ScaleType.Crop
ui.selectedAuthorImage.Image = ""
ui.selectedAuthorImage.Parent = authorWrap
addCorner(ui.selectedAuthorImage, 19)

ui.selectedTitle = createText(selectedTop, {
	Text = "No script selected",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	Position = UDim2.fromOffset(174, 14),
	Size = UDim2.new(1, -188, 0, 24)
})

ui.selectedGame = createText(selectedTop, {
	Text = "Select a script from the Scripts tab.",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = color("Primary", Color3.fromRGB(67, 135, 244)),
	Position = UDim2.fromOffset(174, 40),
	Size = UDim2.new(1, -188, 0, 18)
})

ui.selectedMeta = createText(selectedTop, {
	Text = "Author and stats will appear here.",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(174, 66),
	Size = UDim2.new(1, -188, 0, 94)
})

createButton(selectedTop, "Copy Raw", UDim2.fromOffset(174, 168), UDim2.fromOffset(104, 30), function()
	local raw = fetchRawSelected()
	if raw then
		copyText(raw)
	end
end, false)

createButton(selectedTop, "Copy Page", UDim2.fromOffset(286, 168), UDim2.fromOffset(104, 30), function()
	if not state.selected then
		setStatus("Select a script first.")
		return
	end

	local identifier = getScriptIdentifier(state.selected)
	if identifier then
		if state.selected._source == "rscripts" then
			copyText(RscriptsSiteURL .. "/script/" .. identifier)
		else
			copyText(SiteURL .. "/script/" .. identifier)
		end
	else
		setStatus("Missing script page.")
	end
end, true)

createButton(selectedTop, "Execute", UDim2.fromOffset(398, 168), UDim2.fromOffset(104, 30), function()
	executeSelected()
end, false)

ui.favoriteButton = createButton(selectedTop, "Favorite Script", UDim2.fromOffset(174, 204), UDim2.new(1, -188, 0, 30), function()
	favoriteSelected()
end, true)

local featurePanel = createPanel(selectedPage, 132, 2, color("Card", Color3.fromRGB(17, 24, 39)))

createText(featurePanel, {
	Text = "Features",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 20)
})

ui.selectedFeatures = createText(featurePanel, {
	Text = "Features will appear here.",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(14, 36),
	Size = UDim2.new(1, -28, 0, 82)
})

local tagsPanel = createPanel(selectedPage, 72, 3, color("Card", Color3.fromRGB(17, 24, 39)))

createText(tagsPanel, {
	Text = "Tags",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 20)
})

ui.selectedTags = createText(tagsPanel, {
	Text = "Tags will appear here.",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(14, 34),
	Size = UDim2.new(1, -28, 0, 28)
})

local previewPanel = createPanel(selectedPage, 340, 4, color("Card", Color3.fromRGB(17, 24, 39)))
previewPanel.Name = "ScriptPreview"

createText(previewPanel, {
	Text = "Script Preview",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -150, 0, 22)
})

createButton(previewPanel, "Copy", UDim2.new(1, -96, 0, 8), UDim2.fromOffset(82, 28), function()
	copyText(ui.previewRaw or "")
end, true)

local codeFrame = Instance.new("Frame")
codeFrame.BackgroundColor3 = color("Input", Color3.fromRGB(15, 23, 42))
codeFrame.BorderSizePixel = 0
codeFrame.ClipsDescendants = true
codeFrame.Position = UDim2.fromOffset(14, 44)
codeFrame.Size = UDim2.new(1, -28, 1, -58)
codeFrame.Parent = previewPanel
addCorner(codeFrame, 10)
addStroke(codeFrame, color("Border", Color3.fromRGB(51, 65, 85)), 0.08, 1)

ui.previewScroll = Instance.new("ScrollingFrame")
ui.previewScroll.BackgroundTransparency = 1
ui.previewScroll.BorderSizePixel = 0
ui.previewScroll.Position = UDim2.fromOffset(0, 0)
ui.previewScroll.Size = UDim2.fromScale(1, 1)
ui.previewScroll.CanvasSize = UDim2.fromOffset(0, 0)
ui.previewScroll.ScrollBarThickness = 6
ui.previewScroll.ScrollingDirection = Enum.ScrollingDirection.XY
ui.previewScroll.ScrollBarImageColor3 = color("BorderStrong", Color3.fromRGB(71, 85, 105))
ui.previewScroll.Parent = codeFrame

ui.previewCode = createText(ui.previewScroll, {
	Text = "   1  Script preview will appear here.",
	Font = Enum.Font.Code,
	TextSize = 12,
	TextColor3 = color("Text", Color3.fromRGB(241, 245, 249)),
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.None,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(500, 120),
	RichText = true,
	ClipsDescendants = false
})

ui.selectedPreview = ui.previewCode

registerConfigBackedState()
loadFavorites()
createEmptyScripts()
renderFavorites()
updateFilterSummary()
updateSelected()
safeSelectTab(SearchTab)
setStatus("Ready.")
