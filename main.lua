local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

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

pcall(function()
	if Google.SetTheme then
		Google.SetTheme("DarkRed")
	elseif Google.Themes and Google.Themes.DarkRed then
		Google.ActiveTheme = "DarkRed"
		Google.Theme = Google.Themes.DarkRed
	elseif Google.Themes and Google.Themes.Red then
		Google.ActiveTheme = "Red"
		Google.Theme = Google.Themes.Red
	end
end)

local SearchEndpoint = "https://scriptblox.com/api/script/search"
local DetailsEndpoint = "https://scriptblox.com/api/script/"
local RawEndpoint = "https://scriptblox.com/api/script/raw/"
local SiteURL = "https://scriptblox.com"
local ImageFolder = "ScriptBloxFinderImages"

local state = {
	query = "",
	page = 1,
	max = 12,
	sortBy = "updatedAt",
	order = "desc",
	unpatchedOnly = true,
	noKeyOnly = false,
	verifiedOnly = false,
	universalOnly = false,
	results = {},
	selected = nil,
	totalPages = 0,
	busy = false,
	lastUrl = ""
}

local ui = {
	searchInput = nil,
	maxInput = nil,
	sortDropdown = nil,
	orderDropdown = nil,
	status = nil,
	filterSummary = nil,
	scriptsInfo = nil,
	selectedImage = nil,
	selectedTitle = nil,
	selectedGame = nil,
	selectedMeta = nil,
	selectedFeatures = nil,
	selectedTags = nil,
	selectedPreview = nil
}

local Window
local SearchTab
local ScriptsTab
local SelectedTab
local searchScripts

local function theme()
	return Google.Theme or {}
end

local function color(name, fallback)
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
				otherTab.Button.BackgroundColor3 = active and color("PrimarySoft", Color3.fromRGB(69, 26, 26)) or color("Sidebar", Color3.fromRGB(14, 14, 18))
			end
			if otherTab.Accent then
				otherTab.Accent.Visible = active
			end
			if otherTab.TextLabel then
				otherTab.TextLabel.TextColor3 = active and color("Primary", Color3.fromRGB(248, 81, 73)) or color("Muted", Color3.fromRGB(148, 163, 184))
			end
			if otherTab.IconLabel and Google.SetIconColor then
				Google.SetIconColor(otherTab.IconLabel, active and color("Primary", Color3.fromRGB(248, 81, 73)) or color("Muted", Color3.fromRGB(148, 163, 184)))
			end
			otherTab.Active = active
		end
		Window.ActiveTab = tab
	end
end

local function requestGet(url)
	local ok, result = pcall(function()
		if type(request) == "function" then
			local response = request({Url = url, Method = "GET"})
			if response and response.Body then
				return response.Body
			end
		end

		if type(http_request) == "function" then
			local response = http_request({Url = url, Method = "GET"})
			if response and response.Body then
				return response.Body
			end
		end

		if syn and type(syn.request) == "function" then
			local response = syn.request({Url = url, Method = "GET"})
			if response and response.Body then
				return response.Body
			end
		end

		if fluxus and type(fluxus.request) == "function" then
			local response = fluxus.request({Url = url, Method = "GET"})
			if response and response.Body then
				return response.Body
			end
		end

		if http and type(http.request) == "function" then
			local response = http.request({Url = url, Method = "GET"})
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
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, strokeColor, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
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
	label.BackgroundColor3 = data.BackgroundColor3 or color("Card", Color3.fromRGB(24, 24, 27))
	label.BorderSizePixel = 0
	label.Font = data.Font or Enum.Font.Gotham
	label.Text = data.Text or ""
	label.TextSize = data.TextSize or 12
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
	panel.BackgroundColor3 = backgroundColor or color("Card", Color3.fromRGB(24, 24, 27))
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, -10, 0, height)
	panel.LayoutOrder = layoutOrder or 0
	panel.ClipsDescendants = true
	panel.Parent = parent

	addCorner(panel, 12)
	addStroke(panel, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)

	return panel
end

local function createButton(parent, text, position, size, callback, soft)
	local button = Instance.new("TextButton")
	button.Name = safeName(text)
	button.Text = text
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 12
	button.TextColor3 = soft and color("Primary", Color3.fromRGB(248, 81, 73)) or Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = soft and color("PrimarySoft", Color3.fromRGB(69, 26, 26)) or color("Primary", Color3.fromRGB(248, 81, 73))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Position = position
	button.Size = size
	button.Parent = parent

	addCorner(button, 8)

	local normal = button.BackgroundColor3
	local hover = soft and color("Hover", Color3.fromRGB(39, 39, 42)) or color("PrimaryHover", Color3.fromRGB(220, 38, 38))

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

local function createInput(parent, title, placeholder, defaultValue, position, size, callback)
	createText(parent, {
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Position = position,
		Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 18)
	})

	local box = Instance.new("TextBox")
	box.Name = safeName(title) .. "Input"
	box.BackgroundColor3 = color("Input", Color3.fromRGB(31, 31, 35))
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.ClipsDescendants = true
	box.Font = Enum.Font.Gotham
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = color("Muted", Color3.fromRGB(148, 163, 184))
	box.Text = defaultValue or ""
	box.TextColor3 = color("Text", Color3.fromRGB(241, 245, 249))
	box.TextSize = 13
	box.TextWrapped = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 24)
	box.Size = size
	box.Parent = parent

	pcall(function()
		box.TextTruncate = Enum.TextTruncate.AtEnd
	end)

	addCorner(box, 10)
	addStroke(box, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)
	addPadding(box, 12, 0, 12, 0)

	box.FocusLost:Connect(function(enterPressed)
		callback(box.Text, enterPressed)
	end)

	return box
end

local function createCheck(parent, title, position, size, defaultValue, callback)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color("Input", Color3.fromRGB(31, 31, 35))
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Position = position
	button.Size = size
	button.Parent = parent

	addCorner(button, 10)
	addStroke(button, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)

	local box = Instance.new("Frame")
	box.BackgroundColor3 = defaultValue and color("Primary", Color3.fromRGB(248, 81, 73)) or color("CardAlt", Color3.fromRGB(39, 39, 42))
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(12, 10)
	box.Size = UDim2.fromOffset(18, 18)
	box.Parent = button
	addCorner(box, 5)

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
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -50, 1, 0)
	})

	local value = defaultValue == true

	local function refresh()
		box.BackgroundColor3 = value and color("Primary", Color3.fromRGB(248, 81, 73)) or color("CardAlt", Color3.fromRGB(39, 39, 42))
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
	page.ScrollBarImageColor3 = color("BorderStrong", Color3.fromRGB(107, 114, 128))
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
	return scriptData.slug or scriptData._id
end

local function getScriptTitle(scriptData)
	if not scriptData then
		return "Unknown"
	end
	return firstNonEmpty(scriptData.title, scriptData.name, scriptData.slug, scriptData._id, "Unknown")
end

local function getGameName(scriptData)
	if scriptData and type(scriptData.game) == "table" and scriptData.game.name then
		return scriptData.game.name
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
	return firstNonEmpty(scriptData.image, type(scriptData.game) == "table" and scriptData.game.imageUrl or "")
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
		return mergeTables(scriptData, decoded.script)
	end

	return scriptData
end

local function buildSearchUrl()
	local url = SearchEndpoint
	url = url .. "?q=" .. encode(state.query)
	url = url .. "&page=" .. encode(state.page)
	url = url .. "&max=" .. encode(state.max)
	url = url .. "&sortBy=" .. encode(state.sortBy)
	url = url .. "&order=" .. encode(state.order)
	url = url .. "&strict=false"
	url = url .. "&mode=free"

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

	local filters = {}

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

local function fetchRawSelected()
	if not state.selected then
		setStatus("Select a script first.")
		return nil
	end

	if type(state.selected.script) == "string" and state.selected.script ~= "" then
		return state.selected.script
	end

	local identifier = getScriptIdentifier(state.selected)
	if not identifier then
		setStatus("Missing script identifier.")
		return nil
	end

	setStatus("Fetching raw script...")

	local ok, body = requestGet(RawEndpoint .. encode(identifier))
	if not ok then
		setStatus("Failed to fetch raw script.")
		return nil
	end

	return body
end


local function setPreviewCode(text)
	text = tostring(text or "")

	if not ui.selectedPreview then
		return
	end

	if ui.selectedPreview.SetCode then
		ui.selectedPreview:SetCode(text)
	elseif ui.selectedPreview.SetText then
		ui.selectedPreview:SetText(text)
	elseif ui.selectedPreview.Label then
		ui.selectedPreview.Label.Text = text
	elseif ui.selectedPreview.Text ~= nil then
		ui.selectedPreview.Text = text
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
		return
	end

	local scriptData = state.selected
	local title = getScriptTitle(scriptData)
	local gameName = getGameName(scriptData)
	local author = getAuthorName(scriptData)
	local image = resolveImage(getScriptImage(scriptData), getScriptIdentifier(scriptData) or title)
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
		"Type: " .. tostring(scriptData.scriptType or "free")
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

	local raw = tostring(scriptData.script or "")
	if raw ~= "" then
		raw = raw:gsub("\r", "")
		if #raw > 1100 then
			raw = raw:sub(1, 1100) .. "\n..."
		end
		setPreviewCode(raw)
	else
		setPreviewCode("Use Copy Raw to fetch the raw script.")
	end
end

local function selectScript(scriptData)
	state.selected = fetchDetails(scriptData)
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
	local panel = createPanel(page, 96, 1, color("Card", Color3.fromRGB(24, 24, 27)))
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
	card.BackgroundColor3 = color("Card", Color3.fromRGB(24, 24, 27))
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = index
	card.Parent = parent

	addCorner(card, 12)
	addStroke(card, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)

	local title = getScriptTitle(scriptData)
	local imageAsset = resolveImage(getScriptImage(scriptData), getScriptIdentifier(scriptData) or title)

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.BackgroundColor3 = color("CardAlt", Color3.fromRGB(39, 39, 42))
	thumbnail.BorderSizePixel = 0
	thumbnail.Position = UDim2.fromOffset(10, 10)
	thumbnail.Size = UDim2.new(1, -20, 1, -46)
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Image = imageAsset
	thumbnail.Parent = card

	addCorner(thumbnail, 10)

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
		card.BackgroundColor3 = color("Hover", Color3.fromRGB(39, 39, 42))
	end)

	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = color("Card", Color3.fromRGB(24, 24, 27))
	end)

	card.MouseButton1Click:Connect(function()
		selectScript(scriptData)
	end)

	return card
end

local function renderScripts()
	clearScriptsPage()

	local page = ScriptsTab.Page

	local top = createPanel(page, 76, 1, color("PrimarySoft", Color3.fromRGB(69, 26, 26)))
	top.Name = "ScriptsTop"

	createText(top, {
		Text = "Scripts",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = color("Primary", Color3.fromRGB(248, 81, 73)),
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 22)
	})

	ui.scriptsInfo = createText(top, {
		Text = "Page " .. tostring(state.page) .. " / " .. tostring(state.totalPages > 0 and state.totalPages or "?") .. "  •  " .. tostring(#state.results) .. " results",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = color("Primary", Color3.fromRGB(248, 81, 73)),
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -260, 0, 18)
	})

	createButton(top, "Previous", UDim2.new(1, -214, 0, 36), UDim2.fromOffset(96, 28), function()
		if state.page <= 1 then
			setStatus("Already on the first page.")
			return
		end
		state.page = math.max(1, state.page - 1)
		searchScripts()
	end, true)

	createButton(top, "Next", UDim2.new(1, -108, 0, 36), UDim2.fromOffset(82, 28), function()
		if state.totalPages > 0 and state.page >= state.totalPages then
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
	gridLayout.CellSize = UDim2.new(0.333333, -10, 0, 148)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for index, scriptData in ipairs(state.results) do
		createScriptCard(grid, scriptData, index)
	end

	local rows = math.max(1, math.ceil(#state.results / 3))
	grid.Size = UDim2.new(1, -10, 0, rows * 158)
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

	if state.query == "" then
		setStatus("Enter a search query.")
		return
	end

	state.busy = true
	setStatus("Searching...")
	createEmptyScripts("Searching...")

	local ok, body = requestGet(buildSearchUrl())
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

	if decoded.message then
		state.busy = false
		createEmptyScripts(tostring(decoded.message))
		setStatus(tostring(decoded.message))
		safeSelectTab(ScriptsTab)
		return
	end

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
	state.totalPages = tonumber(decoded.result.totalPages) or 0

	renderScripts()
	safeSelectTab(ScriptsTab)
	setStatus("Found " .. tostring(#state.results) .. " scripts.")
	state.busy = false
end

Window = Google:CreateWindow({
	Title = "Script Finder",
	Subtitle = "Powered by ScriptBlox.com",
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

local searchPage = preparePage(SearchTab)
preparePage(ScriptsTab)
local selectedPage = preparePage(SelectedTab)

local searchPanel = createPanel(searchPage, 178, 1, color("Card", Color3.fromRGB(24, 24, 27)))

ui.searchInput = createInput(
	searchPanel,
	"Search",
	"Search scripts or games",
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

ui.maxInput = createInput(
	searchPanel,
	"Max",
	"12",
	"12",
	UDim2.fromOffset(14, 84),
	UDim2.fromOffset(86, 34),
	function(value)
		local parsed = tonumber(value)
		if parsed then
			state.max = math.clamp(math.floor(parsed), 1, 30)
		end
	end
)

createButton(searchPanel, "Search", UDim2.fromOffset(116, 106), UDim2.fromOffset(96, 34), function()
	state.page = 1
	searchScripts()
end, false)

createButton(searchPanel, "Clear", UDim2.fromOffset(222, 106), UDim2.fromOffset(82, 34), function()
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

	createEmptyScripts()
	updateSelected()
	setStatus("Cleared.")
end, true)

local statusWrap = Instance.new("Frame")
statusWrap.BackgroundColor3 = color("PrimarySoft", Color3.fromRGB(69, 26, 26))
statusWrap.BorderSizePixel = 0
statusWrap.ClipsDescendants = true
statusWrap.Position = UDim2.fromOffset(14, 148)
statusWrap.Size = UDim2.new(1, -28, 0, 22)
statusWrap.Parent = searchPanel

addCorner(statusWrap, 8)

ui.status = createText(statusWrap, {
	Text = "Ready.",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = color("Primary", Color3.fromRGB(248, 81, 73)),
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(1, -20, 1, 0)
})

local filtersPanel = createPanel(searchPage, 162, 2, color("Card", Color3.fromRGB(24, 24, 27)))

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
addStroke(sortBox, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)

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
end)

local orderBox = Instance.new("TextButton")
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
addStroke(orderBox, color("Border", Color3.fromRGB(74, 85, 104)), 0.08, 1)

orderBox.MouseButton1Click:Connect(function()
	if state.order == "desc" then
		state.order = "asc"
		orderBox.Text = "Order: Asc"
	else
		state.order = "desc"
		orderBox.Text = "Order: Desc"
	end
end)

local filterWrap = createPanel(searchPage, 38, 3, color("PrimarySoft", Color3.fromRGB(69, 26, 26)))
ui.filterSummary = createText(filterWrap, {
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = color("Primary", Color3.fromRGB(248, 81, 73)),
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -24, 1, 0)
})

local selectedTop = createPanel(selectedPage, 210, 1, color("Card", Color3.fromRGB(24, 24, 27)))

ui.selectedImage = Instance.new("ImageLabel")
ui.selectedImage.BackgroundColor3 = color("CardAlt", Color3.fromRGB(39, 39, 42))
ui.selectedImage.BorderSizePixel = 0
ui.selectedImage.Position = UDim2.fromOffset(14, 14)
ui.selectedImage.Size = UDim2.fromOffset(142, 142)
ui.selectedImage.ScaleType = Enum.ScaleType.Crop
ui.selectedImage.Image = ""
ui.selectedImage.Parent = selectedTop

addCorner(ui.selectedImage, 12)

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
	TextColor3 = color("Primary", Color3.fromRGB(248, 81, 73)),
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

createButton(selectedTop, "Copy Raw", UDim2.fromOffset(174, 168), UDim2.fromOffset(110, 30), function()
	local raw = fetchRawSelected()
	if raw then
		copyText(raw)
	end
end, false)

createButton(selectedTop, "Copy Page", UDim2.fromOffset(294, 168), UDim2.fromOffset(110, 30), function()
	if not state.selected then
		setStatus("Select a script first.")
		return
	end

	local identifier = getScriptIdentifier(state.selected)
	if identifier then
		copyText(SiteURL .. "/script/" .. identifier)
	else
		setStatus("Missing script page.")
	end
end, true)

local featurePanel = createPanel(selectedPage, 132, 2, color("Card", Color3.fromRGB(24, 24, 27)))

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

local tagsPanel = createPanel(selectedPage, 72, 3, color("Card", Color3.fromRGB(24, 24, 27)))

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

local previewSection = SelectedTab:CreateSection({
	Name = "Script Preview",
	Icon = "file",
	Collapsed = false
})

if previewSection and previewSection.Instance then
	previewSection.Instance.LayoutOrder = 4
end

if previewSection and previewSection.CreateCodeBlock then
	ui.selectedPreview = previewSection:CreateCodeBlock({
		Code = "Script preview will appear here.",
		Language = "lua",
		CopyButton = true,
		MaxHeight = 190,
		Wrap = true
	})
else
	local previewPanel = createPanel(selectedPage, 180, 4, color("Card", Color3.fromRGB(24, 24, 27)))

	createText(previewPanel, {
		Text = "Script Preview",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 20)
	})

	ui.selectedPreview = createText(previewPanel, {
		Text = "Script preview will appear here.",
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = color("Muted", Color3.fromRGB(148, 163, 184)),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 128)
	})
end

createEmptyScripts()
updateFilterSummary()
updateSelected()
safeSelectTab(SearchTab)
setStatus("Ready.")
