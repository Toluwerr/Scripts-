local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local NativePrint = print
local NativeWarn = warn
local ConsoleEntries = {}
local ConsoleRenderer = nil

function FormatConsoleParts(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	return table.concat(parts, " ")
end

function ConsoleLog(kind, ...)
	kind = tostring(kind or "console_output")
	if kind ~= "console_output" and kind ~= "console_info" and kind ~= "console_warning" and kind ~= "console_error" then
		return nil
	end
	local text = FormatConsoleParts(...)
	if text == "" then
		text = " "
	end
	local entry = {
		Kind = kind,
		Text = text,
		Time = os.date("%H:%M:%S")
	}
	table.insert(ConsoleEntries, entry)
	if #ConsoleEntries > 500 then
		table.remove(ConsoleEntries, 1)
	end
	if ConsoleRenderer then
		task.defer(ConsoleRenderer, entry)
	end
	return entry
end

function ConsoleKindFromMessageType(messageType)
	local text = tostring(messageType or "")
	if string.find(text, "Error") then
		return "console_error"
	elseif string.find(text, "Warning") then
		return "console_warning"
	elseif string.find(text, "Info") then
		return "console_info"
	end
	return "console_output"
end

local SeenConsoleMessages = {}
function CaptureConsoleMessage(message, messageType)
	message = tostring(message or "")
	if message == "" then
		return
	end
	local kind = ConsoleKindFromMessageType(messageType)
	local key = kind .. "|" .. message
	local now = os.clock()
	if SeenConsoleMessages[key] and now - SeenConsoleMessages[key] < 0.08 then
		return
	end
	SeenConsoleMessages[key] = now
	ConsoleLog(kind, message)
end

task.defer(function()
	local okHistory, history = pcall(function()
		return LogService:GetLogHistory()
	end)
	if okHistory and type(history) == "table" then
		local startIndex = math.max(1, #history - 120)
		for i = startIndex, #history do
			local item = history[i]
			if type(item) == "table" then
				CaptureConsoleMessage(item.message or item.Message or item.text or item.Text, item.messageType or item.MessageType or item.type or item.Type)
			end
		end
	end
	LogService.MessageOut:Connect(function(message, messageType)
		CaptureConsoleMessage(message, messageType)
	end)
end)

local GuiParent = PlayerGui
pcall(function()
	if type(gethui) == "function" then
		local hui = gethui()
		if hui then
			GuiParent = hui
		end
	end
end)

for _, child in ipairs(GuiParent:GetChildren()) do
	if child:IsA("ScreenGui") and string.find(string.lower(child.Name), "claude") then
		child:Destroy()
	end
end

local LOGO_IMAGE = "rbxthumb://type=Asset&id=96364738447644&w=420&h=420"

local Theme = {
	BG = Color3.fromRGB(10, 10, 9),
	BG2 = Color3.fromRGB(15, 15, 14),
	BG3 = Color3.fromRGB(21, 21, 19),
	BG4 = Color3.fromRGB(28, 24, 22),
	Editor = Color3.fromRGB(9, 9, 8),
	Stroke = Color3.fromRGB(40, 36, 33),
	StrokeSoft = Color3.fromRGB(31, 29, 27),
	Text = Color3.fromRGB(247, 241, 234),
	Muted = Color3.fromRGB(165, 155, 146),
	Orange = Color3.fromRGB(217, 119, 87),
	Orange2 = Color3.fromRGB(235, 147, 112),
	Green = Color3.fromRGB(150, 216, 112),
	Blue = Color3.fromRGB(122, 174, 255),
	Purple = Color3.fromRGB(190, 157, 248),
	Yellow = Color3.fromRGB(242, 202, 97),
	Red = Color3.fromRGB(235, 121, 121),
	Teal = Color3.fromRGB(100, 210, 200)
}

local IconAssets = {
	Code = "rbxassetid://7733749837",
	Box = "rbxassetid://7733917120",
	Settings = "rbxassetid://7734053495",
	Console = "rbxassetid://7734079055",
	Play = "rbxassetid://7743871480",
	Save = "rbxassetid://7734052335",
	Open = "rbxassetid://8997386062",
	Attach = "rbxassetid://7734021680",
	Search = "rbxassetid://7733918763",
	Copy = "rbxassetid://7733799901",
	ArrowLeft = "rbxassetid://7734058260",
	Refresh = "rbxassetid://7734051052"
}

function Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function Stroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = text or ""
	l.TextColor3 = color or Theme.Text
	l.TextSize = size or 13
	l.Font = font or Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = false
	l.Parent = parent
	return l
end

function DrawLine(parent, size, pos, rotation, color, zindex)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.Rotation = rotation or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zindex or 1
	f.Parent = parent
	Corner(f, 10)
	return f
end

function Tween(obj, props, time)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function MakeLucide(parent, iconName, size, color, position, zindex)
	local image = Instance.new("ImageLabel")
	image.Name = "Lucide_" .. iconName
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = IconAssets[iconName] or ""
	image.ImageColor3 = color or Theme.Text
	image.ScaleType = Enum.ScaleType.Fit
	image.Position = position or UDim2.fromOffset(0, 0)
	image.Size = UDim2.fromOffset(size or 16, size or 16)
	image.ZIndex = zindex or 1
	image.Parent = parent
	return image
end

function MakeSearchGlyph(parent, size, color, position, zindex)
	local root = Instance.new("Frame")
	root.Name = "SearchGlyph"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = position or UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(size or 18, size or 18)
	root.ZIndex = zindex or 1
	root.Parent = parent

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Position = UDim2.fromOffset(1, 1)
	ring.Size = UDim2.fromOffset(math.max(8, size - 7), math.max(8, size - 7))
	ring.ZIndex = (zindex or 1) + 1
	ring.Parent = root
	Corner(ring, 99)
	Stroke(ring, color or Theme.Text, 0, 2)

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.new(1, -4, 1, -4)
	handle.Size = UDim2.fromOffset(math.max(7, size - 10), 2)
	handle.Rotation = 45
	handle.BackgroundColor3 = color or Theme.Text
	handle.BorderSizePixel = 0
	handle.ZIndex = (zindex or 1) + 2
	handle.Parent = root
	Corner(handle, 3)

	return root
end

function MakeNavArrowGlyph(parent, direction, size, color, position, zindex)
	local root = Instance.new("Frame")
	root.Name = direction == "left" and "PrevGlyph" or "NextGlyph"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = position or UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(size or 16, size or 16)
	root.ZIndex = zindex or 1
	root.Parent = parent

	local z = (zindex or 1) + 1
	local c = color or Theme.Text
	DrawLine(root, UDim2.fromOffset(11, 2), UDim2.fromScale(0.5, 0.5), 0, c, z)
	if direction == "left" then
		DrawLine(root, UDim2.fromOffset(7, 2), UDim2.fromOffset(5, 5), -45, c, z + 1)
		DrawLine(root, UDim2.fromOffset(7, 2), UDim2.fromOffset(5, 11), 45, c, z + 1)
	else
		DrawLine(root, UDim2.fromOffset(7, 2), UDim2.fromOffset(11, 5), 45, c, z + 1)
		DrawLine(root, UDim2.fromOffset(7, 2), UDim2.fromOffset(11, 11), -45, c, z + 1)
	end

	return root
end

function MakeTopControl(parent, kind, x)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(x, 15)
	button.Size = UDim2.fromOffset(30, 30)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 7
	button.Parent = parent

	if kind == "min" then
		DrawLine(button, UDim2.fromOffset(12, 2), UDim2.fromScale(0.5, 0.5), 0, Theme.Orange2, 8)
	elseif kind == "max" then
		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.fromOffset(10, 10)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.ZIndex = 8
		box.Parent = button
		Stroke(box, Theme.Text, 0, 2)
	elseif kind == "close" then
		DrawLine(button, UDim2.fromOffset(17, 3), UDim2.fromScale(0.5, 0.5), 45, Theme.Text, 8)
		DrawLine(button, UDim2.fromOffset(17, 3), UDim2.fromScale(0.5, 0.5), -45, Theme.Text, 8)
	end

	button.MouseEnter:Connect(function()
		for _, obj in ipairs(button:GetDescendants()) do
			if obj:IsA("Frame") and obj.BackgroundTransparency < 1 then
				obj.BackgroundColor3 = Theme.Orange2
			elseif obj:IsA("UIStroke") then
				obj.Color = Theme.Orange2
			end
		end
	end)

	button.MouseLeave:Connect(function()
		for _, obj in ipairs(button:GetDescendants()) do
			if obj:IsA("Frame") and obj.BackgroundTransparency < 1 then
				obj.BackgroundColor3 = kind == "min" and Theme.Orange2 or Theme.Text
			elseif obj:IsA("UIStroke") then
				obj.Color = Theme.Text
			end
		end
	end)

	return button
end

function Trim(text)
	return string.match(text or "", "^%s*(.-)%s*$")
end

function EscapeRich(text)
	text = tostring(text or "")
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

function ToHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

local SyntaxColors = {
	plain = ToHex(Theme.Text),
	keyword = ToHex(Theme.Orange2),
	builtin = ToHex(Theme.Blue),
	string = ToHex(Theme.Green),
	number = ToHex(Theme.Yellow),
	comment = ToHex(Theme.Muted),
	operator = ToHex(Theme.Purple),
	boolean = ToHex(Theme.Red),
	nilvalue = ToHex(Theme.Red),
	property = ToHex(Theme.Teal)
}

local Keywords = {
	["and"] = true, ["break"] = true, ["continue"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["export"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,
	["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
	["return"] = true, ["self"] = true, ["then"] = true, ["true"] = true, ["type"] = true, ["typeof"] = true,
	["until"] = true, ["while"] = true
}

local Builtins = {
	["game"] = true, ["workspace"] = true, ["script"] = true, ["Enum"] = true, ["Color3"] = true, ["BrickColor"] = true,
	["UDim"] = true, ["UDim2"] = true, ["Vector2"] = true, ["Vector3"] = true, ["CFrame"] = true, ["Instance"] = true,
	["NumberRange"] = true, ["NumberSequence"] = true, ["ColorSequence"] = true, ["TweenInfo"] = true, ["RaycastParams"] = true,
	["math"] = true, ["string"] = true, ["table"] = true, ["task"] = true, ["coroutine"] = true, ["utf8"] = true, ["os"] = true,
	["print"] = true, ["warn"] = true, ["error"] = true, ["assert"] = true, ["pcall"] = true, ["xpcall"] = true,
	["pairs"] = true, ["ipairs"] = true, ["next"] = true, ["select"] = true, ["tonumber"] = true, ["tostring"] = true,
	["rawget"] = true, ["rawset"] = true, ["setmetatable"] = true, ["getmetatable"] = true, ["require"] = true, ["loadstring"] = true
}

local CompletionWords = {
	"and", "break", "continue", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "self", "then", "true", "until", "while",
	"game", "workspace", "script", "Players", "LocalPlayer", "PlayerGui", "UserInputService", "RunService", "TweenService", "HttpService", "Lighting", "ReplicatedStorage", "StarterGui", "SoundService",
	"Instance", "Vector2", "Vector3", "CFrame", "UDim", "UDim2", "Color3", "Enum", "TweenInfo", "RaycastParams",
	"GetService", "WaitForChild", "FindFirstChild", "FindFirstChildOfClass", "GetChildren", "GetDescendants", "IsA", "Destroy", "Clone", "Connect", "FireServer", "InvokeServer",
	"new", "fromRGB", "fromScale", "fromOffset", "Angles", "lookAt", "Lerp", "Create", "Play", "Cancel",
	"print", "warn", "error", "assert", "pcall", "xpcall", "pairs", "ipairs", "next", "select", "tonumber", "tostring", "type", "typeof", "require", "loadstring",
	"math", "string", "table", "task", "wait", "spawn", "delay", "defer", "abs", "floor", "ceil", "round", "random", "min", "max", "clamp", "find", "match", "gsub", "sub", "insert", "remove", "sort", "concat"
}

function WrapToken(text, colorKey)
	return '<font color="' .. SyntaxColors[colorKey] .. '">' .. EscapeRich(text) .. "</font>"
end

function HighlightLua(source)
	local out = {}
	local i = 1
	local n = #source

	while i <= n do
		local two = source:sub(i, i + 1)
		local four = source:sub(i, i + 3)
		local c = source:sub(i, i)

		if four == "--[[" then
			local closeAt = source:find("]]", i + 4, true)
			local stop = closeAt and (closeAt + 1) or n
			table.insert(out, WrapToken(source:sub(i, stop), "comment"))
			i = stop + 1
		elseif two == "--" then
			local nextNewline = source:find("\n", i, true)
			local stop = nextNewline and (nextNewline - 1) or n
			table.insert(out, WrapToken(source:sub(i, stop), "comment"))
			i = stop + 1
		elseif c == '"' or c == "'" then
			local quote = c
			local j = i + 1
			while j <= n do
				local ch = source:sub(j, j)
				if ch == "\\" then
					j = j + 2
				elseif ch == quote then
					j = j + 1
					break
				else
					j = j + 1
				end
			end
			table.insert(out, WrapToken(source:sub(i, math.min(j - 1, n)), "string"))
			i = j
		elseif two == "[[" then
			local closeAt = source:find("]]", i + 2, true)
			local stop = closeAt and (closeAt + 1) or n
			table.insert(out, WrapToken(source:sub(i, stop), "string"))
			i = stop + 1
		elseif c:match("[%a_]") then
			local j = i
			while j <= n and source:sub(j, j):match("[%w_]") do
				j = j + 1
			end
			local word = source:sub(i, j - 1)
			if word == "true" or word == "false" then
				table.insert(out, WrapToken(word, "boolean"))
			elseif word == "nil" then
				table.insert(out, WrapToken(word, "nilvalue"))
			elseif Keywords[word] then
				table.insert(out, WrapToken(word, "keyword"))
			elseif Builtins[word] then
				table.insert(out, WrapToken(word, "builtin"))
			else
				table.insert(out, EscapeRich(word))
			end
			i = j
		elseif c:match("%d") then
			local j = i
			while j <= n and source:sub(j, j):match("[%d%.eE_xXA-Fa-f]") do
				j = j + 1
			end
			table.insert(out, WrapToken(source:sub(i, j - 1), "number"))
			i = j
		elseif c == "." and source:sub(i + 1, i + 1):match("[%a_]") then
			table.insert(out, WrapToken(".", "operator"))
			i = i + 1
			local j = i
			while j <= n and source:sub(j, j):match("[%w_]") do
				j = j + 1
			end
			table.insert(out, WrapToken(source:sub(i, j - 1), "property"))
			i = j
		elseif c:match("[%+%-%*%^%%#=~<>%.,:%;%{%}%[%]%(%)%/]") then
			table.insert(out, WrapToken(c, "operator"))
			i = i + 1
		else
			table.insert(out, EscapeRich(c))
			i = i + 1
		end
	end

	return table.concat(out)
end

function SplitLines(text)
	local lines = {}
	text = text or ""
	for line in (text .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	if #lines == 0 then
		lines[1] = ""
	end
	return lines
end

function GetScriptLoader()
	if type(loadstring) == "function" then
		return loadstring
	end
	if type(getfenv) == "function" then
		local ok, env = pcall(getfenv)
		if ok and type(env) == "table" and type(rawget(env, "loadstring")) == "function" then
			return rawget(env, "loadstring")
		end
	end
	if type(_G) == "table" and type(rawget(_G, "loadstring")) == "function" then
		return rawget(_G, "loadstring")
	end
	return nil
end

function BindConsoleEnvironment(fn)
	if type(fn) ~= "function" or type(setfenv) ~= "function" or type(getfenv) ~= "function" then
		return
	end
	local okEnv, baseEnv = pcall(getfenv, fn)
	if not okEnv or type(baseEnv) ~= "table" then
		okEnv, baseEnv = pcall(getfenv)
	end
	if not okEnv or type(baseEnv) ~= "table" then
		baseEnv = _G
	end
	local env = {}
	setmetatable(env, {
		__index = function(_, key)
			if key == "print" then
				return function(...)
					NativePrint(...)
				end
			elseif key == "warn" then
				return function(...)
					NativeWarn(...)
				end
			end
			return baseEnv[key]
		end,
		__newindex = function(_, key, value)
			baseEnv[key] = value
		end
	})
	pcall(setfenv, fn, env)
end

function ExecuteSource(source)
	local code = Trim(source)
	if code == "" then
		NativeWarn("No script source to execute.")
		return false
	end
	local loader = GetScriptLoader()
	if not loader then
		NativeWarn("loadstring is not available in this runtime.")
		return false
	end
	local compiled, compileError = loader(code)
	if type(compiled) ~= "function" then
		NativeWarn("Compile error: " .. tostring(compileError))
		return false
	end
	BindConsoleEnvironment(compiled)
	local ok, runtimeError = pcall(compiled)
	if not ok then
		NativeWarn("Runtime error: " .. tostring(runtimeError))
		return false
	end
	return true
end

function CopyText(text)
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard, text or "")
		if ok then
			return true
		end
	end
	if type(toclipboard) == "function" then
		local ok = pcall(toclipboard, text or "")
		if ok then
			return true
		end
	end
	return false
end

function HttpGet(url)
	local okGame, bodyGame = pcall(function()
		if type(game.HttpGet) == "function" then
			return game:HttpGet(url, true)
		end
	end)
	if okGame and type(bodyGame) == "string" and bodyGame ~= "" then
		return true, bodyGame
	end
	local ok, body = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	if ok then
		return true, body
	end
	return false, tostring(body or bodyGame or "request failed")
end

function HttpGetWithHeaders(url, headers)
	headers = type(headers) == "table" and headers or {}
	local requestFunction = request or http_request or (syn and syn.request) or (http and http.request)
	if type(requestFunction) == "function" then
		local ok, response = pcall(function()
			return requestFunction({
				Url = url,
				Method = "GET",
				Headers = headers
			})
		end)
		if ok and type(response) == "table" then
			local body = response.Body or response.body
			if type(body) == "string" and body ~= "" then
				return true, body
			end
		elseif ok and type(response) == "string" and response ~= "" then
			return true, response
		end
	end
	local okRequest, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = headers
		})
	end)
	if okRequest and type(response) == "table" and response.Success and type(response.Body) == "string" then
		return true, response.Body
	end
	return HttpGet(url)
end

function JsonDecode(text)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok then
		return true, data
	end
	return false, data
end

local ImageCache = {}

function HashText(text)
	local hash = 5381
	for i = 1, #text do
		hash = ((hash * 33) + string.byte(text, i)) % 4294967296
	end
	return tostring(math.floor(hash))
end

function GetCustomAssetPath(fileName)
	local providers = {
		rawget(_G, "getcustomasset"),
		rawget(_G, "getsynasset"),
		getcustomasset,
		getsynasset
	}
	for _, provider in ipairs(providers) do
		if type(provider) == "function" then
			local ok, asset = pcall(provider, fileName)
			if ok and type(asset) == "string" and asset ~= "" then
				return asset
			end
		end
	end
	return ""
end

function EncodeUrl(value)
	local ok, encoded = pcall(function()
		return HttpService:UrlEncode(value)
	end)
	if ok and type(encoded) == "string" then
		return encoded
	end
	return tostring(value):gsub("([^%w%-_%.~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end)
end


function NormalizeImageUrl(value)
	if type(value) ~= "string" then
		return ""
	end
	local url = Trim(value)
	if url == "" then
		return ""
	end
	if url:match("^//") then
		return "https:" .. url
	end
	if url:match("^/") then
		return "https://rscripts.net" .. url
	end
	if not url:match("^https?://") and (url:find("assets/", 1, true) or url:find("uploads/", 1, true) or url:find("avatars/", 1, true)) then
		if url:sub(1, 1) ~= "/" then
			url = "/" .. url
		end
		return "https://rscripts.net" .. url
	end
	return url
end

function HttpGetImage(url)
	local requestFunction = request or http_request or (syn and syn.request) or (http and http.request)
	if type(requestFunction) == "function" then
		local ok, response = pcall(function()
			return requestFunction({
				Url = url,
				Method = "GET",
				Headers = {
					["Accept"] = "image/avif,image/webp,image/apng,image/png,image/jpeg,image/*,*/*;q=0.8",
					["User-Agent"] = "Mozilla/5.0"
				}
			})
		end)
		if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" and (response.Success == nil or response.Success == true or tonumber(response.StatusCode) == 200) then
			return true, response.Body
		end
	end
	return HttpGet(url)
end

function ImageDownloadUrls(url)
	url = NormalizeImageUrl(url)
	local urls = {}
	local used = {}
	local function add(value)
		if type(value) == "string" and value ~= "" and not used[value] then
			used[value] = true
			table.insert(urls, value)
		end
	end
	local lower = string.lower(url)
	if lower:find("%.webp", 1, true) or lower:find("rscripts.net/assets/avatars", 1, true) then
		local encoded = EncodeUrl(url)
		local stripped = url:gsub("^https?://", "")
		add("https://images.weserv.nl/?url=" .. stripped .. "&output=png&w=256&h=256&fit=cover")
		add("https://wsrv.nl/?url=" .. stripped .. "&output=png&w=256&h=256&fit=cover")
		add("https://images.weserv.nl/?url=" .. encoded .. "&output=png&w=256&h=256&fit=cover")
		add("https://wsrv.nl/?url=" .. encoded .. "&output=png&w=256&h=256&fit=cover")
		add((url:gsub("%.webp", ".png")))
		add((url:gsub("%.webp", ".jpg")))
	end
	add(url)
	return urls
end

function TryExternalImage(url)
	url = NormalizeImageUrl(url)
	if type(url) ~= "string" or url == "" then
		return ""
	end
	if not string.match(url, "^https?://") then
		return url
	end
	if ImageCache[url] then
		return ImageCache[url]
	end
	if type(writefile) == "function" then
		for _, downloadUrl in ipairs(ImageDownloadUrls(url)) do
			local ok, body = HttpGetImage(downloadUrl)
			if ok and type(body) == "string" and body ~= "" then
				local lower = string.lower(downloadUrl)
				local extension = (lower:find("output=png", 1, true) or lower:find("%.png", 1, true)) and ".png" or (lower:find("%.jpg", 1, true) or lower:find("%.jpeg", 1, true)) and ".jpg" or ".png"
				local fileName = "claude_rscripts_" .. HashText(downloadUrl) .. extension
				local wrote = pcall(function()
					writefile(fileName, body)
				end)
				if wrote then
					local asset = GetCustomAssetPath(fileName)
					if asset ~= "" then
						ImageCache[url] = asset
						ImageCache[downloadUrl] = asset
						return asset
					end
				end
			end
		end
	end
	return ""
end

function FirstString(...)
	for _, value in ipairs({...}) do
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return ""
end

function FirstNumber(...)
	for _, value in ipairs({...}) do
		local numberValue = tonumber(value)
		if numberValue and numberValue > 0 then
			return numberValue
		end
	end
	return nil
end

function MakeInput(parent, placeholder, text)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Theme.BG2
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = text or ""
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Theme.Muted
	box.TextColor3 = Theme.Text
	box.TextSize = 13
	box.Font = Enum.Font.GothamMedium
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.Parent = parent
	Corner(box, 8)
	Stroke(box, Theme.Stroke, 0.35, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = box
	return box
end


function MakeSearchInput(parent, placeholder, text)
	local shell = Instance.new("Frame")
	shell.Name = "SearchShell"
	shell.BackgroundColor3 = Theme.BG2
	shell.BorderSizePixel = 0
	shell.ClipsDescendants = true
	shell.Parent = parent
	Corner(shell, 8)
	Stroke(shell, Theme.Stroke, 0.35, 1)

	MakeSearchGlyph(shell, 17, Theme.Muted, UDim2.fromOffset(18, 10), 12)

	local box = Instance.new("TextBox")
	box.Name = "SearchBox"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = text or ""
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Theme.Muted
	box.TextColor3 = Theme.Text
	box.TextSize = 13
	box.Font = Enum.Font.GothamMedium
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.Position = UDim2.fromOffset(56, 0)
	box.Size = UDim2.new(1, -68, 1, 0)
	box.ZIndex = 13
	box.Parent = shell

	return shell, box
end

local ButtonRowTarget = nil

function ActionButton(parent, iconName, text, width, filled)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, 42)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.ClipsDescendants = false
	button.ZIndex = 20
	button.Parent = parent or ButtonRowTarget

	local surface = Instance.new("Frame")
	surface.Name = "ButtonSurface"
	surface.Position = UDim2.fromOffset(2, 2)
	surface.Size = UDim2.new(1, -4, 1, -4)
	surface.BackgroundColor3 = filled and Theme.Orange or Theme.BG2
	surface.BorderSizePixel = 0
	surface.ClipsDescendants = true
	surface.ZIndex = 20
	surface.Parent = button
	Corner(surface, 9)
	Stroke(surface, filled and Theme.Orange2 or Theme.Stroke, 0.35, 1)

	local iconX = filled and 18 or 14
	local textX = iconName and (filled and 42 or 38) or 14
	if iconName then
		if iconName == "Search" then
			MakeSearchGlyph(surface, 15, Theme.Text, UDim2.fromOffset(iconX, 12), 21)
		elseif iconName == "PrevArrow" then
			MakeNavArrowGlyph(surface, "left", 15, Theme.Text, UDim2.fromOffset(iconX, 12), 21)
		elseif iconName == "NextArrow" then
			MakeNavArrowGlyph(surface, "right", 15, Theme.Text, UDim2.fromOffset(iconX, 12), 21)
		else
			MakeLucide(surface, iconName, 15, Theme.Text, UDim2.fromOffset(iconX, 12), 21)
		end
	end
	local txt = Label(surface, text, 12, Theme.Text, Enum.Font.GothamBold)
	txt.Position = UDim2.fromOffset(textX, 0)
	txt.Size = UDim2.new(1, -textX, 1, 0)
	txt.TextXAlignment = iconName and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	txt.ZIndex = 22
	button.MouseEnter:Connect(function()
		Tween(surface, { BackgroundColor3 = filled and Theme.Orange2 or Theme.BG3 }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		Tween(surface, { BackgroundColor3 = filled and Theme.Orange or Theme.BG2 }, 0.12)
	end)
	return button
end

function CreateCodeEditor(parent, initialText, editable)
	local holder = Instance.new("Frame")
	holder.Name = "CodeEditor"
	holder.BackgroundColor3 = Theme.Editor
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = parent
	Corner(holder, 10)
	Stroke(holder, Theme.Stroke, 0.35, 1)

	local viewport = Instance.new("Frame")
	viewport.Name = "EditorViewport"
	viewport.BackgroundColor3 = Theme.Editor
	viewport.BackgroundTransparency = 0
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true
	viewport.Position = UDim2.fromOffset(2, 2)
	viewport.Size = UDim2.new(1, -4, 1, -4)
	viewport.ZIndex = 9
	viewport.Parent = holder
	Corner(viewport, 9)

	local gutterWidth = 58
	local padX = 14
	local padY = 10
	local textSize = 16
	local lineHeight = math.ceil(TextService:GetTextSize("Ag", textSize, Enum.Font.Code, Vector2.new(10000, 10000)).Y) + 4
	local lineLabels = {}
	local numberLabels = {}
	local focused = false
	local blinkAlive = false
	local scheduled = false
	local scheduleUpdate

	local gutter = Instance.new("Frame")
	gutter.Name = "Gutter"
	gutter.Position = UDim2.fromOffset(0, 0)
	gutter.Size = UDim2.new(0, gutterWidth, 1, 0)
	gutter.BackgroundColor3 = Theme.BG2
	gutter.BorderSizePixel = 0
	gutter.ClipsDescendants = true
	gutter.ZIndex = 12
	gutter.Parent = viewport
	Corner(gutter, 9)

	local gutterFill = Instance.new("Frame")
	gutterFill.AnchorPoint = Vector2.new(1, 0)
	gutterFill.Position = UDim2.new(1, 0, 0, 0)
	gutterFill.Size = UDim2.new(0, 12, 1, 0)
	gutterFill.BackgroundColor3 = Theme.BG2
	gutterFill.BorderSizePixel = 0
	gutterFill.ZIndex = 12
	gutterFill.Parent = gutter

	local gutterLine = Instance.new("Frame")
	gutterLine.AnchorPoint = Vector2.new(1, 0)
	gutterLine.Position = UDim2.new(1, 0, 0, 8)
	gutterLine.Size = UDim2.new(0, 1, 1, -16)
	gutterLine.BackgroundColor3 = Theme.StrokeSoft
	gutterLine.BorderSizePixel = 0
	gutterLine.ZIndex = 13
	gutterLine.Parent = gutter

	local numberLayer = Instance.new("Frame")
	numberLayer.Name = "NumberLayer"
	numberLayer.BackgroundTransparency = 1
	numberLayer.BorderSizePixel = 0
	numberLayer.Position = UDim2.fromOffset(0, padY)
	numberLayer.Size = UDim2.fromOffset(gutterWidth - 8, lineHeight)
	numberLayer.ZIndex = 14
	numberLayer.Parent = gutter

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "EditorScroll"
	scroll.Position = UDim2.fromOffset(gutterWidth + 4, 6)
	scroll.Size = UDim2.new(1, -gutterWidth - 12, 1, -12)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Stroke
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.ZIndex = 8
	scroll.ClipsDescendants = true
	scroll.Parent = viewport

	local linesLayer = Instance.new("Frame")
	linesLayer.Name = "LinesLayer"
	linesLayer.BackgroundTransparency = 1
	linesLayer.BorderSizePixel = 0
	linesLayer.Position = UDim2.fromOffset(0, 0)
	linesLayer.Size = UDim2.fromOffset(0, 0)
	linesLayer.ZIndex = 9
	linesLayer.Parent = scroll

	local codeBox = Instance.new("TextBox")
	codeBox.Name = "CodeBox"
	codeBox.BackgroundTransparency = 1
	codeBox.BorderSizePixel = 0
	codeBox.ClearTextOnFocus = false
	codeBox.MultiLine = true
	codeBox.TextEditable = editable ~= false
	codeBox.Text = initialText or ""
	codeBox.PlaceholderText = ""
	codeBox.TextColor3 = Theme.Text
	codeBox.TextTransparency = 1
	codeBox.TextSize = textSize
	codeBox.Font = Enum.Font.Code
	codeBox.TextXAlignment = Enum.TextXAlignment.Left
	codeBox.TextYAlignment = Enum.TextYAlignment.Top
	codeBox.Position = UDim2.fromOffset(padX, padY)
	codeBox.Size = UDim2.fromOffset(400, lineHeight)
	codeBox.ZIndex = 10
	codeBox.Parent = scroll

	local cursor = Instance.new("Frame")
	cursor.Name = "FakeCursor"
	cursor.BackgroundColor3 = Theme.Text
	cursor.BorderSizePixel = 0
	cursor.Size = UDim2.fromOffset(2, lineHeight - 4)
	cursor.Visible = false
	cursor.ZIndex = 30
	cursor.Parent = linesLayer

	local suggestionBox = Instance.new("Frame")
	suggestionBox.Name = "Autocomplete"
	suggestionBox.BackgroundColor3 = Theme.BG2
	suggestionBox.BorderSizePixel = 0
	suggestionBox.Visible = false
	suggestionBox.ZIndex = 45
	suggestionBox.Parent = linesLayer
	Corner(suggestionBox, 8)
	Stroke(suggestionBox, Theme.Stroke, 0.25, 1)

	local suggestionLayout = Instance.new("UIListLayout")
	suggestionLayout.FillDirection = Enum.FillDirection.Vertical
	suggestionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	suggestionLayout.Parent = suggestionBox

	local activeSuggestions = {}
	local selectedSuggestion = 1

	local function insertCompletion()
		suggestionBox.Visible = false
	end

	local function updateSuggestionSelection()
		suggestionBox.Visible = false
	end

	local function updateSuggestions()
		suggestionBox.Visible = false
	end

	local function getOrCreateLine(index)
		local label = lineLabels[index]
		if label then
			return label
		end
		label = Instance.new("TextLabel")
		label.Name = "CodeLine" .. index
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.RichText = true
		label.TextWrapped = false
		label.TextSize = textSize
		label.Font = Enum.Font.Code
		label.TextColor3 = Theme.Text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.ZIndex = 9
		label.Parent = linesLayer
		lineLabels[index] = label
		return label
	end

	local function getOrCreateNumber(index)
		local label = numberLabels[index]
		if label then
			return label
		end
		label = Instance.new("TextLabel")
		label.Name = "LineNumber" .. index
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.TextWrapped = false
		label.TextSize = 14
		label.Font = Enum.Font.Code
		label.TextColor3 = Theme.Muted
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.ZIndex = 15
		label.Parent = numberLayer
		numberLabels[index] = label
		return label
	end

	local function updateCursor()
		if not focused then
			cursor.Visible = false
			return
		end
		local pos = codeBox.CursorPosition
		local text = codeBox.Text or ""
		if not pos or pos < 1 then
			pos = #text + 1
		end
		pos = math.clamp(pos, 1, #text + 1)
		local before = text:sub(1, pos - 1)
		local line = 1
		local lastBreak = 0
		for i = 1, #before do
			if before:sub(i, i) == "\n" then
				line = line + 1
				lastBreak = i
			end
		end
		local prefix = before:sub(lastBreak + 1)
		local width = 0
		if prefix ~= "" then
			width = TextService:GetTextSize(prefix, textSize, Enum.Font.Code, Vector2.new(100000, 10000)).X
		end
		cursor.Position = UDim2.fromOffset(padX + width, padY + ((line - 1) * lineHeight) + 2)
		cursor.Visible = true
	end

	local function syncGutter()
		numberLayer.Position = UDim2.fromOffset(0, padY - scroll.CanvasPosition.Y)
	end

	local function updateNow()
		scheduled = false
		local lines = SplitLines(codeBox.Text)
		local maxWidth = 16
		for i, line in ipairs(lines) do
			local measureText = line == "" and " " or line
			local bounds = TextService:GetTextSize(measureText, textSize, Enum.Font.Code, Vector2.new(100000, 10000))
			if bounds.X > maxWidth then
				maxWidth = bounds.X
			end
		end
		local contentWidth = math.max(maxWidth + padX + 120, math.max(1, scroll.AbsoluteSize.X - 8))
		local contentHeight = math.max((#lines * lineHeight) + padY + 32, math.max(1, scroll.AbsoluteSize.Y - 8))
		linesLayer.Size = UDim2.fromOffset(contentWidth, contentHeight)
		numberLayer.Size = UDim2.fromOffset(gutterWidth - 8, contentHeight)
		codeBox.Size = UDim2.fromOffset(contentWidth - padX, contentHeight - padY)
		scroll.CanvasSize = UDim2.fromOffset(contentWidth, contentHeight)
		for i, line in ipairs(lines) do
			local codeLabel = getOrCreateLine(i)
			codeLabel.Visible = true
			codeLabel.Position = UDim2.fromOffset(padX, padY + ((i - 1) * lineHeight))
			codeLabel.Size = UDim2.fromOffset(contentWidth - padX, lineHeight)
			codeLabel.Text = HighlightLua(line)
			local numberLabel = getOrCreateNumber(i)
			numberLabel.Visible = true
			numberLabel.Position = UDim2.fromOffset(0, (i - 1) * lineHeight)
			numberLabel.Size = UDim2.fromOffset(gutterWidth - 12, lineHeight)
			numberLabel.Text = tostring(i)
		end
		for i = #lines + 1, #lineLabels do
			if lineLabels[i] then
				lineLabels[i].Visible = false
			end
		end
		for i = #lines + 1, #numberLabels do
			if numberLabels[i] then
				numberLabels[i].Visible = false
			end
		end
		syncGutter()
		updateCursor()
	end

	scheduleUpdate = function()
		if scheduled then
			return
		end
		scheduled = true
		task.defer(updateNow)
	end

	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		syncGutter()
	end)

	codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		scheduleUpdate()
		task.defer(updateSuggestions)
	end)
	codeBox:GetPropertyChangedSignal("CursorPosition"):Connect(function()
		updateCursor()
		task.defer(updateSuggestions)
	end)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleUpdate)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleUpdate)

	codeBox.Focused:Connect(function()
		focused = true
		updateCursor()
		task.defer(updateSuggestions)
		if not blinkAlive then
			blinkAlive = true
			task.spawn(function()
				while focused and codeBox.Parent do
					cursor.Visible = true
					task.wait(0.25)
				end
				blinkAlive = false
				cursor.Visible = false
			end)
		end
	end)

	codeBox.FocusLost:Connect(function()
		focused = false
		cursor.Visible = false
		suggestionBox.Visible = false
	end)

	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			codeBox:CaptureFocus()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not codeBox:IsFocused() or editable == false then
			return
		end
		if input.KeyCode == Enum.KeyCode.Down and suggestionBox.Visible then
			selectedSuggestion = math.clamp(selectedSuggestion + 1, 1, #activeSuggestions)
			updateSuggestionSelection()
			return
		elseif input.KeyCode == Enum.KeyCode.Up and suggestionBox.Visible then
			selectedSuggestion = math.clamp(selectedSuggestion - 1, 1, #activeSuggestions)
			updateSuggestionSelection()
			return
		elseif input.KeyCode == Enum.KeyCode.Tab then
			if suggestionBox.Visible and activeSuggestions[selectedSuggestion] then
				insertCompletion(activeSuggestions[selectedSuggestion])
				return
			end
			local pos = codeBox.CursorPosition
			if pos and pos > 0 then
				local text = codeBox.Text
				codeBox.Text = text:sub(1, pos - 1) .. "\t" .. text:sub(pos)
				codeBox.CursorPosition = pos + 1
			else
				codeBox.Text = codeBox.Text .. "\t"
			end
			scheduleUpdate()
			return
		elseif input.KeyCode == Enum.KeyCode.Escape then
			suggestionBox.Visible = false
		end
	end)

	scheduleUpdate()

	local api = {}
	api.Frame = holder
	api.TextBox = codeBox
	api.SetText = function(_, text)
		codeBox.Text = text or ""
		scheduleUpdate()
	end
	api.GetText = function()
		return codeBox.Text or ""
	end
	api.Refresh = scheduleUpdate
	api.Focus = function()
		codeBox:CaptureFocus()
	end
	return api
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "ClaudeExecutorPanelReplica"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 999999
Gui.Parent = GuiParent

local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Position = UDim2.fromScale(0.5, 0.5)
Panel.Size = UDim2.fromOffset(940, 540)
Panel.BackgroundColor3 = Theme.BG
Panel.BorderSizePixel = 0
Panel.ClipsDescendants = true
Panel.Active = true
Panel.Parent = Gui
Corner(Panel, 16)
Stroke(Panel, Theme.Stroke, 0.12, 1)

local NormalPosition = Panel.Position
local NormalSize = Panel.Size
local IsFullscreen = false
local IsMinimized = false

local MinimizedPill = Instance.new("TextButton")
MinimizedPill.Name = "MinimizedPill"
MinimizedPill.AnchorPoint = Vector2.new(1, 1)
MinimizedPill.Position = UDim2.new(1, -24, 1, -24)
MinimizedPill.Size = UDim2.fromOffset(164, 44)
MinimizedPill.BackgroundColor3 = Theme.BG
MinimizedPill.BorderSizePixel = 0
MinimizedPill.Text = ""
MinimizedPill.Visible = false
MinimizedPill.AutoButtonColor = false
MinimizedPill.Parent = Gui
Corner(MinimizedPill, 14)
Stroke(MinimizedPill, Theme.Stroke, 0.12, 1)

local MiniLogo = Instance.new("ImageLabel")
MiniLogo.BackgroundTransparency = 1
MiniLogo.Image = LOGO_IMAGE
MiniLogo.ScaleType = Enum.ScaleType.Fit
MiniLogo.Position = UDim2.fromOffset(12, 7)
MiniLogo.Size = UDim2.fromOffset(28, 28)
MiniLogo.Parent = MinimizedPill

local MiniText = Label(MinimizedPill, "claude", 22, Theme.Text, Enum.Font.Garamond)
MiniText.Position = UDim2.fromOffset(48, 0)
MiniText.Size = UDim2.new(1, -58, 1, 0)

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 66)
TopBar.BackgroundTransparency = 1
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 3
TopBar.Parent = Panel

local TopLine = Instance.new("Frame")
TopLine.AnchorPoint = Vector2.new(0, 1)
TopLine.Position = UDim2.new(0, 0, 1, 0)
TopLine.Size = UDim2.new(1, 0, 0, 1)
TopLine.BackgroundColor3 = Theme.StrokeSoft
TopLine.BorderSizePixel = 0
TopLine.ZIndex = 4
TopLine.Parent = TopBar

local Logo = Instance.new("ImageLabel")
Logo.Name = "Logo"
Logo.BackgroundTransparency = 1
Logo.Image = LOGO_IMAGE
Logo.ScaleType = Enum.ScaleType.Fit
Logo.Position = UDim2.fromOffset(20, 15)
Logo.Size = UDim2.fromOffset(36, 36)
Logo.ZIndex = 5
Logo.Parent = TopBar

local Title = Label(TopBar, "claude", 32, Theme.Text, Enum.Font.Garamond)
Title.Position = UDim2.fromOffset(66, 0)
Title.Size = UDim2.fromOffset(220, 66)
Title.ZIndex = 5

local Controls = Instance.new("Frame")
Controls.Name = "WindowControls"
Controls.AnchorPoint = Vector2.new(1, 0.5)
Controls.Position = UDim2.new(1, -18, 0, 33)
Controls.Size = UDim2.fromOffset(126, 30)
Controls.BackgroundTransparency = 1
Controls.ZIndex = 6
Controls.Parent = TopBar

local MinimizeButton = MakeTopControl(Controls, "min", 15)
local FullscreenButton = MakeTopControl(Controls, "max", 63)
local CloseButton = MakeTopControl(Controls, "close", 111)

CloseButton.MouseButton1Click:Connect(function()
	Gui:Destroy()
end)

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Position = UDim2.fromOffset(0, 66)
Content.Size = UDim2.new(1, 0, 1, -66)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ZIndex = 2
Content.Parent = Panel

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Position = UDim2.fromOffset(16, 24)
Sidebar.Size = UDim2.fromOffset(60, 184)
Sidebar.BackgroundColor3 = Theme.BG2
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 4
Sidebar.Parent = Content
Corner(Sidebar, 10)
Stroke(Sidebar, Theme.Stroke, 0.3, 1)

local SideLayout = Instance.new("UIListLayout")
SideLayout.FillDirection = Enum.FillDirection.Vertical
SideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Padding = UDim.new(0, 8)
SideLayout.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.Parent = Sidebar

local PageHost = Instance.new("Frame")
PageHost.Name = "PageHost"
PageHost.Position = UDim2.fromOffset(92, 22)
PageHost.Size = UDim2.new(1, -116, 1, -48)
PageHost.BackgroundTransparency = 1
PageHost.BorderSizePixel = 0
PageHost.ClipsDescendants = true
PageHost.ZIndex = 3
PageHost.Parent = Content

local CodePage = Instance.new("Frame")
CodePage.Name = "CodePage"
CodePage.Size = UDim2.fromScale(1, 1)
CodePage.BackgroundTransparency = 1
CodePage.BorderSizePixel = 0
CodePage.ZIndex = 4
CodePage.Parent = PageHost

local ExplorePage = Instance.new("Frame")
ExplorePage.Name = "ExplorePage"
ExplorePage.Size = UDim2.fromScale(1, 1)
ExplorePage.BackgroundTransparency = 1
ExplorePage.BorderSizePixel = 0
ExplorePage.Visible = false
ExplorePage.ZIndex = 4
ExplorePage.Parent = PageHost

local DetailPage = Instance.new("Frame")
DetailPage.Name = "DetailPage"
DetailPage.Size = UDim2.fromScale(1, 1)
DetailPage.BackgroundTransparency = 1
DetailPage.BorderSizePixel = 0
DetailPage.Visible = false
DetailPage.ClipsDescendants = true
DetailPage.ZIndex = 4
DetailPage.Parent = PageHost

local DetailScroll = Instance.new("ScrollingFrame")
DetailScroll.Name = "DetailScroll"
DetailScroll.Size = UDim2.new(1, -6, 1, 0)
DetailScroll.BackgroundTransparency = 1
DetailScroll.BorderSizePixel = 0
DetailScroll.ScrollBarThickness = 6
DetailScroll.ScrollBarImageColor3 = Theme.Stroke
DetailScroll.CanvasSize = UDim2.fromOffset(0, 940)
DetailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DetailScroll.ClipsDescendants = true
DetailScroll.ZIndex = 5
DetailScroll.Parent = DetailPage

local DetailCanvas = Instance.new("Frame")
DetailCanvas.Name = "DetailCanvas"
DetailCanvas.Size = UDim2.new(1, -30, 0, 940)
DetailCanvas.BackgroundTransparency = 1
DetailCanvas.BorderSizePixel = 0
DetailCanvas.ZIndex = 6
DetailCanvas.Parent = DetailScroll

local ConsolePage = Instance.new("Frame")
ConsolePage.Name = "ConsolePage"
ConsolePage.Size = UDim2.fromScale(1, 1)
ConsolePage.BackgroundTransparency = 1
ConsolePage.BorderSizePixel = 0
ConsolePage.Visible = false
ConsolePage.ClipsDescendants = false
ConsolePage.ZIndex = 4
ConsolePage.Parent = PageHost

local SideButtons = {}

function SideButton(iconName, text, pageName, active)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(48, 50)
	button.BackgroundColor3 = active and Color3.fromRGB(39, 30, 25) or Theme.BG2
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 5
	button.Parent = Sidebar
	Corner(button, 8)
	local stroke = Stroke(button, active and Theme.Orange or Theme.StrokeSoft, active and 0.05 or 0.58, 1)
	local icon = MakeLucide(button, iconName, 18, active and Theme.Orange2 or Theme.Text, UDim2.fromOffset(15, 7), 6)
	local txt = Label(button, text, 8, active and Theme.Orange2 or Theme.Text, Enum.Font.GothamBold)
	txt.TextXAlignment = Enum.TextXAlignment.Center
	txt.Position = UDim2.fromOffset(0, 31)
	txt.Size = UDim2.new(1, 0, 0, 14)
	txt.ZIndex = 6
	SideButtons[pageName] = {Button = button, Stroke = stroke, Icon = icon, Text = txt}
	return button
end

local CodeSide = SideButton("Code", "CODE", "Code", true)
local ExploreSide = SideButton("Box", "EXPLORE", "Explore", false)
local ConsoleSide = SideButton("Console", "CONSOLE", "Console", false)

local ConsoleHeader = Instance.new("Frame")
ConsoleHeader.Name = "ConsoleHeader"
ConsoleHeader.Position = UDim2.fromOffset(8, 0)
ConsoleHeader.Size = UDim2.new(1, -16, 0, 64)
ConsoleHeader.BackgroundTransparency = 1
ConsoleHeader.BorderSizePixel = 0
ConsoleHeader.ZIndex = 5
ConsoleHeader.Parent = ConsolePage

local ConsoleTitle = Label(ConsoleHeader, "Developer Console", 20, Theme.Text, Enum.Font.GothamBold)
ConsoleTitle.Position = UDim2.fromOffset(0, 0)
ConsoleTitle.Size = UDim2.new(1, -260, 0, 32)
ConsoleTitle.ZIndex = 6

local ConsoleStatus = Label(ConsoleHeader, "Roblox console output only", 12, Theme.Muted, Enum.Font.GothamMedium)
ConsoleStatus.Position = UDim2.fromOffset(0, 30)
ConsoleStatus.Size = UDim2.new(1, -260, 0, 22)
ConsoleStatus.ZIndex = 6

local ConsoleActions = Instance.new("Frame")
ConsoleActions.AnchorPoint = Vector2.new(1, 0)
ConsoleActions.Position = UDim2.new(1, -4, 0, 4)
ConsoleActions.Size = UDim2.fromOffset(220, 44)
ConsoleActions.BackgroundTransparency = 1
ConsoleActions.BorderSizePixel = 0
ConsoleActions.ZIndex = 8
ConsoleActions.Parent = ConsoleHeader

local ConsoleActionsLayout = Instance.new("UIListLayout")
ConsoleActionsLayout.FillDirection = Enum.FillDirection.Horizontal
ConsoleActionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ConsoleActionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ConsoleActionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ConsoleActionsLayout.Padding = UDim.new(0, 10)
ConsoleActionsLayout.Parent = ConsoleActions

local ConsoleCopy = ActionButton(ConsoleActions, "Copy", "COPY", 94, false)
local ConsoleClear = ActionButton(ConsoleActions, nil, "CLEAR", 86, false)

local ConsoleScroll = Instance.new("ScrollingFrame")
ConsoleScroll.Name = "ConsoleScroll"
ConsoleScroll.Position = UDim2.fromOffset(12, 76)
ConsoleScroll.Size = UDim2.new(1, -32, 1, -92)
ConsoleScroll.BackgroundColor3 = Color3.fromRGB(20, 21, 23)
ConsoleScroll.BorderSizePixel = 0
ConsoleScroll.ScrollBarThickness = 6
ConsoleScroll.ScrollBarImageColor3 = Theme.Stroke
ConsoleScroll.CanvasSize = UDim2.fromOffset(0, 0)
ConsoleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConsoleScroll.ScrollingDirection = Enum.ScrollingDirection.Y
pcall(function() ConsoleScroll.VerticalScrollBarInset = Enum.ScrollBarInset.Always end)
pcall(function() ConsoleScroll.ScrollBarImageTransparency = 0.05 end)
ConsoleScroll.ClipsDescendants = true
ConsoleScroll.ZIndex = 6
ConsoleScroll.Parent = ConsolePage
Corner(ConsoleScroll, 12)
Stroke(ConsoleScroll, Color3.fromRGB(70, 73, 78), 0.15, 1)

local ConsoleList = Instance.new("UIListLayout")
ConsoleList.FillDirection = Enum.FillDirection.Vertical
ConsoleList.HorizontalAlignment = Enum.HorizontalAlignment.Left
ConsoleList.SortOrder = Enum.SortOrder.LayoutOrder
ConsoleList.Padding = UDim.new(0, 6)
ConsoleList.Parent = ConsoleScroll

local ConsolePad = Instance.new("UIPadding")
ConsolePad.PaddingTop = UDim.new(0, 12)
ConsolePad.PaddingLeft = UDim.new(0, 16)
ConsolePad.PaddingRight = UDim.new(0, 26)
ConsolePad.PaddingBottom = UDim.new(0, 20)
ConsolePad.Parent = ConsoleScroll

local ConsoleRowCount = 0

function ConsoleKindColor(kind)
	kind = tostring(kind or "console_output")
	if kind == "console_error" or kind == "error" then
		return Color3.fromRGB(245, 97, 84)
	elseif kind == "console_warning" or kind == "warn" then
		return Color3.fromRGB(255, 221, 92)
	elseif kind == "console_info" then
		return Color3.fromRGB(151, 178, 255)
	end
	return Color3.fromRGB(232, 232, 232)
end

function PushConsoleRow(entry)
	if not ConsoleScroll.Parent then
		return
	end
	ConsoleRowCount = ConsoleRowCount + 1
	local row = Instance.new("Frame")
	row.Name = "ConsoleLine" .. tostring(ConsoleRowCount)
	row.Size = UDim2.new(1, -10, 0, 28)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.LayoutOrder = ConsoleRowCount
	row.ZIndex = 7
	row.Parent = ConsoleScroll

	local color = ConsoleKindColor(entry.Kind)
	local symbolText = "--"
	if entry.Kind == "console_error" then
		symbolText = "×"
	elseif entry.Kind == "console_warning" then
		symbolText = "!"
	elseif entry.Kind == "console_info" then
		symbolText = "i"
	end

	local symbol = Label(row, symbolText, 15, color, Enum.Font.GothamBold)
	symbol.TextXAlignment = Enum.TextXAlignment.Center
	symbol.Position = UDim2.fromOffset(6, 3)
	symbol.Size = UDim2.fromOffset(26, 20)
	symbol.ZIndex = 8

	local timeLabel = Label(row, tostring(entry.Time or "--:--:--"), 13, Color3.fromRGB(175, 175, 175), Enum.Font.Code)
	timeLabel.Position = UDim2.fromOffset(42, 2)
	timeLabel.Size = UDim2.fromOffset(80, 22)
	timeLabel.ZIndex = 8

	local message = Label(row, "--  " .. tostring(entry.Text or ""), 13, color, Enum.Font.Code)
	message.Position = UDim2.fromOffset(126, 2)
	message.Size = UDim2.new(1, -134, 0, 22)
	message.TextWrapped = true
	message.TextYAlignment = Enum.TextYAlignment.Top
	message.ZIndex = 8

	task.defer(function()
		local width = math.max(160, message.AbsoluteSize.X)
		local height = TextService:GetTextSize(message.Text, message.TextSize, message.Font, Vector2.new(width, 100000)).Y + 6
		row.Size = UDim2.new(1, -10, 0, math.max(28, height))
		ConsoleScroll.CanvasPosition = Vector2.new(0, math.max(0, ConsoleList.AbsoluteContentSize.Y))
	end)
end

ConsoleRenderer = PushConsoleRow
for _, entry in ipairs(ConsoleEntries) do
	PushConsoleRow(entry)
end

ConsoleClear.MouseButton1Click:Connect(function()
	for _, child in ipairs(ConsoleScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(ConsoleEntries)
	ConsoleRowCount = 0
	ConsoleStatus.Text = "Console cleared"
end)

ConsoleCopy.MouseButton1Click:Connect(function()
	local lines = {}
	for _, entry in ipairs(ConsoleEntries) do
		table.insert(lines, "[" .. tostring(entry.Time) .. "] [" .. tostring(entry.Kind) .. "] " .. tostring(entry.Text))
	end
	local ok = CopyText(table.concat(lines, "\n"))
	ConsoleStatus.Text = ok and "Console copied" or "Copy unavailable"
end)

local CodeHeader = Instance.new("Frame")
CodeHeader.Name = "CodeHeader"
CodeHeader.Position = UDim2.fromOffset(0, 0)
CodeHeader.Size = UDim2.new(1, 0, 0, 50)
CodeHeader.BackgroundTransparency = 1
CodeHeader.BorderSizePixel = 0
CodeHeader.ZIndex = 5
CodeHeader.Parent = CodePage

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Name = "TabScroll"
TabScroll.Position = UDim2.fromOffset(0, 2)
TabScroll.Size = UDim2.new(1, -58, 1, -2)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel = 0
TabScroll.ScrollBarThickness = 0
TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
TabScroll.CanvasSize = UDim2.fromOffset(0, 0)
TabScroll.ZIndex = 6
TabScroll.Parent = CodeHeader

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 8)
TabLayout.Parent = TabScroll

local PlusTab = Instance.new("TextButton")
PlusTab.Name = "PlusTab"
PlusTab.AnchorPoint = Vector2.new(1, 0)
PlusTab.Position = UDim2.new(1, -4, 0, 3)
PlusTab.Size = UDim2.fromOffset(44, 38)
PlusTab.BackgroundTransparency = 1
PlusTab.BorderSizePixel = 0
PlusTab.Text = ""
PlusTab.AutoButtonColor = false
PlusTab.ClipsDescendants = false
PlusTab.ZIndex = 7
PlusTab.Parent = CodeHeader

local PlusSurface = Instance.new("Frame")
PlusSurface.Name = "PlusSurface"
PlusSurface.Position = UDim2.fromOffset(2, 2)
PlusSurface.Size = UDim2.new(1, -4, 1, -4)
PlusSurface.BackgroundColor3 = Theme.BG2
PlusSurface.BorderSizePixel = 0
PlusSurface.ClipsDescendants = true
PlusSurface.ZIndex = 8
PlusSurface.Parent = PlusTab
Corner(PlusSurface, 8)
Stroke(PlusSurface, Theme.Stroke, 0.35, 1)

local PlusText = Label(PlusSurface, "+", 22, Theme.Text, Enum.Font.GothamMedium)
PlusText.TextXAlignment = Enum.TextXAlignment.Center
PlusText.Position = UDim2.fromOffset(0, -1)
PlusText.Size = UDim2.new(1, 0, 1, 0)
PlusText.ZIndex = 9

local EditorTabs = {
	{Name = "main.lua", Text = 'print("Hello World")'}
}
local ActiveEditorTab = 1
local CodeEditor
local CodeStatus

function SaveActiveEditorTab()
	if CodeEditor and EditorTabs[ActiveEditorTab] then
		EditorTabs[ActiveEditorTab].Text = CodeEditor:GetText()
	end
end

local RenderEditorTabs

function CloseEditorTab(index)
	if not EditorTabs[index] then
		return
	end
	if #EditorTabs <= 1 then
		EditorTabs[1] = {Name = "main.lua", Text = ""}
		ActiveEditorTab = 1
		if CodeEditor then
			CodeEditor:SetText("")
		end
		if CodeStatus then
			CodeStatus.Text = "Closed tab"
		end
		RenderEditorTabs()
		return
	end
	table.remove(EditorTabs, index)
	if ActiveEditorTab > #EditorTabs then
		ActiveEditorTab = #EditorTabs
	elseif ActiveEditorTab > index then
		ActiveEditorTab = ActiveEditorTab - 1
	elseif ActiveEditorTab == index then
		ActiveEditorTab = math.clamp(index, 1, #EditorTabs)
	end
	if CodeEditor and EditorTabs[ActiveEditorTab] then
		CodeEditor:SetText(EditorTabs[ActiveEditorTab].Text or "")
	end
	if CodeStatus then
		CodeStatus.Text = "Closed tab"
	end
	RenderEditorTabs()
end

RenderEditorTabs = function()
	for _, child in ipairs(TabScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, tabData in ipairs(EditorTabs) do
		local width = math.max(150, math.min(236, 104 + (#tabData.Name * 7)))
		local tab = Instance.new("TextButton")
		tab.Name = "ScriptTab" .. tostring(index)
		tab.Size = UDim2.fromOffset(width, 38)
		tab.BackgroundTransparency = 1
		tab.BorderSizePixel = 0
		tab.Text = ""
		tab.AutoButtonColor = false
		tab.ClipsDescendants = false
		tab.LayoutOrder = index
		tab.ZIndex = 7
		tab.Parent = TabScroll

		local surface = Instance.new("Frame")
		surface.Name = "TabSurface"
		surface.Position = UDim2.fromOffset(3, 3)
		surface.Size = UDim2.new(1, -6, 1, -6)
		surface.BackgroundColor3 = index == ActiveEditorTab and Theme.Orange or Theme.BG2
		surface.BorderSizePixel = 0
		surface.ClipsDescendants = true
		surface.ZIndex = 8
		surface.Parent = tab
		Corner(surface, 9)
		Stroke(surface, index == ActiveEditorTab and Theme.Orange2 or Theme.Stroke, 0.35, 1)

		local tabText = Label(surface, tabData.Name, 13, index == ActiveEditorTab and Color3.fromRGB(255, 247, 239) or Theme.Text, Enum.Font.GothamBold)
		tabText.TextXAlignment = Enum.TextXAlignment.Left
		tabText.TextTruncate = Enum.TextTruncate.AtEnd
		tabText.Position = UDim2.fromOffset(14, 0)
		tabText.Size = UDim2.new(1, -44, 1, 0)
		tabText.ZIndex = 9

		local close = Instance.new("TextButton")
		close.Name = "CloseTab"
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.new(1, -8, 0.5, 0)
		close.Size = UDim2.fromOffset(22, 22)
		close.BackgroundTransparency = 1
		close.BorderSizePixel = 0
		close.Text = "×"
		close.TextColor3 = index == ActiveEditorTab and Color3.fromRGB(255, 247, 239) or Theme.Muted
		close.TextSize = 17
		close.Font = Enum.Font.GothamBold
		close.AutoButtonColor = false
		close.ZIndex = 12
		close.Parent = surface

		close.MouseEnter:Connect(function()
			close.TextColor3 = Theme.Text
		end)
		close.MouseLeave:Connect(function()
			close.TextColor3 = index == ActiveEditorTab and Color3.fromRGB(255, 247, 239) or Theme.Muted
		end)
		close.MouseButton1Click:Connect(function()
			SaveActiveEditorTab()
			CloseEditorTab(index)
		end)

		tab.MouseButton1Click:Connect(function()
			if ActiveEditorTab == index then
				return
			end
			SaveActiveEditorTab()
			ActiveEditorTab = index
			if CodeEditor then
				CodeEditor:SetText(EditorTabs[ActiveEditorTab].Text or "")
				if CodeStatus then
					CodeStatus.Text = "Opened " .. EditorTabs[ActiveEditorTab].Name
				end
			end
			RenderEditorTabs()
		end)
	end
	task.defer(function()
		TabScroll.CanvasSize = UDim2.fromOffset(TabLayout.AbsoluteContentSize.X + 18, 0)
	end)
end

PlusTab.MouseButton1Click:Connect(function()
	SaveActiveEditorTab()
	local nextIndex = #EditorTabs + 1
	table.insert(EditorTabs, {Name = "script" .. tostring(nextIndex) .. ".lua", Text = ""})
	ActiveEditorTab = nextIndex
	if CodeEditor then
		CodeEditor:SetText("")
	end
	RenderEditorTabs()
end)

CodeEditor = CreateCodeEditor(CodePage, EditorTabs[ActiveEditorTab].Text, true)
CodeEditor.Frame.Position = UDim2.fromOffset(8, 58)
CodeEditor.Frame.Size = UDim2.new(1, -24, 1, -140)
CodeEditor.Frame.ZIndex = 6
CodeEditor.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if EditorTabs[ActiveEditorTab] then
		EditorTabs[ActiveEditorTab].Text = CodeEditor:GetText()
	end
end)
RenderEditorTabs()

local CodeBottom = Instance.new("Frame")
CodeBottom.Name = "CodeBottom"
CodeBottom.AnchorPoint = Vector2.new(0, 1)
CodeBottom.Position = UDim2.new(0, 0, 1, 0)
CodeBottom.Size = UDim2.new(1, 0, 0, 64)
CodeBottom.BackgroundTransparency = 1
CodeBottom.BorderSizePixel = 0
CodeBottom.ZIndex = 5
CodeBottom.Parent = CodePage

local BottomLine = Instance.new("Frame")
BottomLine.Size = UDim2.new(1, 0, 0, 1)
BottomLine.BackgroundColor3 = Theme.StrokeSoft
BottomLine.BorderSizePixel = 0
BottomLine.ZIndex = 6
BottomLine.Parent = CodeBottom

local Row = Instance.new("Frame")
Row.Name = "ButtonRow"
Row.Position = UDim2.fromOffset(6, 10)
Row.Size = UDim2.new(1, -280, 0, 44)
Row.BackgroundTransparency = 1
Row.ZIndex = 6
Row.Parent = CodeBottom

local RowLayout = Instance.new("UIListLayout")
RowLayout.FillDirection = Enum.FillDirection.Horizontal
RowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
RowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
RowLayout.SortOrder = Enum.SortOrder.LayoutOrder
RowLayout.Padding = UDim.new(0, 12)
RowLayout.Parent = Row

local Execute = ActionButton(Row, "Play", "EXECUTE", 150, true)
local CopyMain = ActionButton(Row, "Copy", "COPY", 104, false)
local ClearMain = ActionButton(Row, nil, "CLEAR", 96, false)
local Attach = ActionButton(Row, "Attach", "ATTACH", 116, false)

CodeStatus = Label(CodeBottom, "Ready", 12, Theme.Muted, Enum.Font.GothamMedium)
CodeStatus.AnchorPoint = Vector2.new(1, 0.5)
CodeStatus.Position = UDim2.new(1, -14, 0.5, 0)
CodeStatus.Size = UDim2.fromOffset(260, 20)
CodeStatus.TextXAlignment = Enum.TextXAlignment.Right
CodeStatus.ZIndex = 7

Execute.MouseButton1Click:Connect(function()
	SaveActiveEditorTab()
	local ok = ExecuteSource(CodeEditor:GetText())
	CodeStatus.Text = ok and "Executed" or "Execution failed; check Console"
end)

CopyMain.MouseButton1Click:Connect(function()
	SaveActiveEditorTab()
	local ok = CopyText(CodeEditor:GetText())
	CodeStatus.Text = ok and "Copied" or "Copy unavailable"
	ConsoleLog(ok and "success" or "warn", ok and "Editor source copied." or "Copy unavailable.")
end)

ClearMain.MouseButton1Click:Connect(function()
	CodeEditor:SetText("")
	SaveActiveEditorTab()
	CodeStatus.Text = "Cleared"
	ConsoleLog("info", "Editor cleared.")
end)

Attach.MouseButton1Click:Connect(function()
	CodeStatus.Text = "Attach is not needed for Studio"
	ConsoleLog("info", "Attach is not needed for Studio.")
end)

local SearchHeader = Instance.new("Frame")
SearchHeader.Name = "SearchHeader"
SearchHeader.Position = UDim2.fromOffset(0, 0)
SearchHeader.Size = UDim2.new(1, 0, 0, 98)
SearchHeader.BackgroundTransparency = 1
SearchHeader.BorderSizePixel = 0
SearchHeader.ZIndex = 5
SearchHeader.Parent = ExplorePage

local ExploreTitle = Label(SearchHeader, "Explore scripts", 19, Theme.Text, Enum.Font.GothamBold)
ExploreTitle.Position = UDim2.fromOffset(0, 0)
ExploreTitle.Size = UDim2.new(1, -220, 0, 30)
ExploreTitle.ZIndex = 6

local ExploreStatus = Label(SearchHeader, "Search Rscripts or load latest", 12, Theme.Muted, Enum.Font.GothamMedium)
ExploreStatus.Position = UDim2.fromOffset(0, 28)
ExploreStatus.Size = UDim2.new(1, -220, 0, 20)
ExploreStatus.ZIndex = 6

local SearchShell, SearchBox = MakeSearchInput(SearchHeader, "Search scripts, games, creators...", "")
SearchShell.Position = UDim2.fromOffset(0, 54)
SearchShell.Size = UDim2.new(1, -452, 0, 40)
SearchShell.ZIndex = 8

local SearchActions = Instance.new("Frame")
SearchActions.AnchorPoint = Vector2.new(1, 0)
SearchActions.Position = UDim2.new(1, -6, 0, 52)
SearchActions.Size = UDim2.fromOffset(430, 44)
SearchActions.BackgroundTransparency = 1
SearchActions.BorderSizePixel = 0
SearchActions.ZIndex = 8
SearchActions.Parent = SearchHeader

local SearchActionsLayout = Instance.new("UIListLayout")
SearchActionsLayout.FillDirection = Enum.FillDirection.Horizontal
SearchActionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
SearchActionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SearchActionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SearchActionsLayout.Padding = UDim.new(0, 10)
SearchActionsLayout.Parent = SearchActions

local SearchButton = ActionButton(SearchActions, "Search", "SEARCH", 104, true)
local LatestButton = ActionButton(SearchActions, "Refresh", "LATEST", 98, false)
local PrevButton = ActionButton(SearchActions, "PrevArrow", "PREV", 88, false)
local NextButton = ActionButton(SearchActions, "NextArrow", "NEXT", 88, false)

local ResultsScroll = Instance.new("ScrollingFrame")
ResultsScroll.Name = "ResultsScroll"
ResultsScroll.Position = UDim2.fromOffset(8, 106)
ResultsScroll.Size = UDim2.new(1, -24, 1, -118)
ResultsScroll.BackgroundTransparency = 1
ResultsScroll.BorderSizePixel = 0
ResultsScroll.ScrollBarThickness = 6
ResultsScroll.ScrollBarImageColor3 = Theme.Stroke
ResultsScroll.CanvasSize = UDim2.fromOffset(0, 0)
ResultsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ResultsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ResultsScroll.ClipsDescendants = true
ResultsScroll.ZIndex = 5
ResultsScroll.Parent = ExplorePage

local ResultsLayout = Instance.new("UIGridLayout")
ResultsLayout.CellPadding = UDim2.fromOffset(18, 18)
ResultsLayout.CellSize = UDim2.fromOffset(350, 146)
ResultsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ResultsLayout.Parent = ResultsScroll

local ResultsPad = Instance.new("UIPadding")
ResultsPad.PaddingTop = UDim.new(0, 2)
ResultsPad.PaddingLeft = UDim.new(0, 8)
ResultsPad.PaddingRight = UDim.new(0, 58)
ResultsPad.PaddingBottom = UDim.new(0, 64)
ResultsPad.Parent = ResultsScroll

local Profile = { CurrentUser = nil, SourcePage = "Detail", Scripts = {}, Loading = false }

local DetailTop = Instance.new("Frame")
DetailTop.Name = "DetailTop"
DetailTop.Position = UDim2.fromOffset(0, 0)
DetailTop.Size = UDim2.new(1, -4, 0, 360)
DetailTop.BackgroundTransparency = 1
DetailTop.BorderSizePixel = 0
DetailTop.ZIndex = 5
DetailTop.Parent = DetailCanvas

local BackButton = ActionButton(DetailTop, "ArrowLeft", "BACK", 98, false)
BackButton.Position = UDim2.fromOffset(0, 0)
BackButton.ZIndex = 8

local DetailImage = Instance.new("ImageLabel")
DetailImage.Position = UDim2.fromOffset(0, 66)
DetailImage.Size = UDim2.fromOffset(198, 118)
DetailImage.BackgroundTransparency = 1
DetailImage.BackgroundColor3 = Theme.BG2
DetailImage.BorderSizePixel = 0
DetailImage.ScaleType = Enum.ScaleType.Crop
DetailImage.ZIndex = 6
DetailImage.Parent = DetailTop
Corner(DetailImage, 10)

local DetailTitle = Label(DetailTop, "Select a script", 20, Theme.Text, Enum.Font.GothamBold)
DetailTitle.Position = UDim2.fromOffset(224, 64)
DetailTitle.Size = UDim2.new(1, -560, 0, 46)
DetailTitle.TextTruncate = Enum.TextTruncate.AtEnd
DetailTitle.ZIndex = 6

local DetailMeta = Label(DetailTop, "", 12, Theme.Muted, Enum.Font.GothamMedium)
DetailMeta.Position = UDim2.fromOffset(224, 108)
DetailMeta.Size = UDim2.new(1, -560, 0, 22)
DetailMeta.TextTruncate = Enum.TextTruncate.AtEnd
DetailMeta.ZIndex = 6

local DetailDescription = Label(DetailTop, "", 12, Theme.Text, Enum.Font.GothamMedium)
DetailDescription.Position = UDim2.fromOffset(224, 138)
DetailDescription.Size = UDim2.new(1, -560, 0, 92)
DetailDescription.TextWrapped = true
DetailDescription.TextYAlignment = Enum.TextYAlignment.Top
DetailDescription.ZIndex = 6

local AuthorAvatar = Instance.new("ImageLabel")
AuthorAvatar.AnchorPoint = Vector2.new(1, 0)
AuthorAvatar.Position = UDim2.new(1, -156, 0, 0)
AuthorAvatar.Size = UDim2.fromOffset(34, 34)
AuthorAvatar.BackgroundColor3 = Theme.BG2
AuthorAvatar.BorderSizePixel = 0
AuthorAvatar.ScaleType = Enum.ScaleType.Crop
AuthorAvatar.ZIndex = 7
AuthorAvatar.Parent = DetailTop
Corner(AuthorAvatar, 19)
Stroke(AuthorAvatar, Theme.Stroke, 0.35, 1)

local AuthorInfo = Label(DetailTop, "", 12, Theme.Text, Enum.Font.GothamBold)
AuthorInfo.AnchorPoint = Vector2.new(1, 0)
AuthorInfo.Position = UDim2.new(1, 0, 0, 0)
AuthorInfo.Size = UDim2.fromOffset(148, 34)
AuthorInfo.TextTruncate = Enum.TextTruncate.AtEnd
AuthorInfo.ZIndex = 7

Profile.AuthorButton = Instance.new("TextButton")
Profile.AuthorButton.Name = "AuthorProfileButton"
Profile.AuthorButton.AnchorPoint = Vector2.new(1, 0)
Profile.AuthorButton.Position = UDim2.new(1, -18, 0, 6)
Profile.AuthorButton.Size = UDim2.fromOffset(280, 64)
Profile.AuthorButton.BackgroundColor3 = Theme.BG2
Profile.AuthorButton.BorderSizePixel = 0
Profile.AuthorButton.Text = ""
Profile.AuthorButton.AutoButtonColor = false
Profile.AuthorButton.ClipsDescendants = false
Profile.AuthorButton.ZIndex = 6
Profile.AuthorButton.Parent = DetailTop
Corner(Profile.AuthorButton, 12)
Stroke(Profile.AuthorButton, Theme.Stroke, 0.35, 1)

AuthorAvatar.Parent = Profile.AuthorButton
AuthorAvatar.AnchorPoint = Vector2.new(0, 0)
AuthorAvatar.Position = UDim2.fromOffset(14, 12)
AuthorAvatar.Size = UDim2.fromOffset(40, 40)

AuthorInfo.Parent = Profile.AuthorButton
AuthorInfo.AnchorPoint = Vector2.new(0, 0)
AuthorInfo.Position = UDim2.fromOffset(68, 10)
AuthorInfo.Size = UDim2.new(1, -76, 0, 22)

Profile.AuthorHint = Label(Profile.AuthorButton, "VIEW PROFILE", 9, Theme.Muted, Enum.Font.GothamBold)
Profile.AuthorHint.Position = UDim2.fromOffset(68, 36)
Profile.AuthorHint.Size = UDim2.new(1, -76, 0, 16)
Profile.AuthorHint.ZIndex = 7

Profile.AuthorInitial = Label(Profile.AuthorButton, "?", 18, Theme.Orange2, Enum.Font.GothamBold)
Profile.AuthorInitial.TextXAlignment = Enum.TextXAlignment.Center
Profile.AuthorInitial.Position = UDim2.fromOffset(14, 12)
Profile.AuthorInitial.Size = UDim2.fromOffset(40, 40)
Profile.AuthorInitial.ZIndex = 9
Profile.AuthorInitial.Visible = false

Profile.AuthorButton.MouseEnter:Connect(function()
	Tween(Profile.AuthorButton, { BackgroundColor3 = Theme.BG3 }, 0.12)
end)
Profile.AuthorButton.MouseLeave:Connect(function()
	Tween(Profile.AuthorButton, { BackgroundColor3 = Theme.BG2 }, 0.12)
end)

local DetailButtons = Instance.new("Frame")
DetailButtons.Name = "DetailButtons"
DetailButtons.AnchorPoint = Vector2.new(1, 0)
DetailButtons.Position = UDim2.new(1, -4, 0, 270)
DetailButtons.Size = UDim2.fromOffset(398, 44)
DetailButtons.BackgroundTransparency = 1
DetailButtons.ZIndex = 8
DetailButtons.Parent = DetailTop

local DetailButtonsLayout = Instance.new("UIListLayout")
DetailButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
DetailButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
DetailButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
DetailButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
DetailButtonsLayout.Padding = UDim.new(0, 10)
DetailButtonsLayout.Parent = DetailButtons

local DetailExecute = ActionButton(DetailButtons, "Play", "EXECUTE", 122, true)
local DetailCopy = ActionButton(DetailButtons, "Copy", "COPY", 96, false)
local DetailEdit = ActionButton(DetailButtons, "Code", "EDITOR", 104, false)

local DetailCode = CreateCodeEditor(DetailCanvas, "", false)
DetailCode.Frame.Position = UDim2.fromOffset(8, 392)
DetailCode.Frame.Size = UDim2.new(1, -28, 0, 496)
DetailCode.Frame.ZIndex = 6

local CurrentPageName = "Code"
local CurrentQuery = ""
local CurrentPage = 1
local MaxPages = 1
local CurrentResults = {}
local SelectedScript = nil
local SelectedSource = ""
local Loading = false
local ResultRows = {}
local AutoUpdating = false
local AutoUpdateInterval = 45

function Profile.Setup()
	Profile.Page = Instance.new("Frame")
	Profile.Page.Name = "ProfilePage"
	Profile.Page.Size = UDim2.fromScale(1, 1)
	Profile.Page.BackgroundTransparency = 1
	Profile.Page.BorderSizePixel = 0
	Profile.Page.Visible = false
	Profile.Page.ClipsDescendants = false
	Profile.Page.ZIndex = 4
	Profile.Page.Parent = PageHost

	Profile.Scroll = Instance.new("ScrollingFrame")
	Profile.Scroll.Name = "ProfileScroll"
	Profile.Scroll.Position = UDim2.fromOffset(12, 0)
	Profile.Scroll.Size = UDim2.new(1, -24, 1, -10)
	Profile.Scroll.BackgroundTransparency = 1
	Profile.Scroll.BorderSizePixel = 0
	Profile.Scroll.ScrollBarThickness = 4
	Profile.Scroll.ScrollBarImageColor3 = Theme.Stroke
	Profile.Scroll.CanvasSize = UDim2.fromOffset(0, 760)
	Profile.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Profile.Scroll.ClipsDescendants = true
	Profile.Scroll.ZIndex = 5
	Profile.Scroll.Parent = Profile.Page

	Profile.Canvas = Instance.new("Frame")
	Profile.Canvas.Name = "ProfileCanvas"
	Profile.Canvas.Size = UDim2.new(1, -12, 0, 820)
	Profile.Canvas.BackgroundTransparency = 1
	Profile.Canvas.BorderSizePixel = 0
	Profile.Canvas.ZIndex = 6
	Profile.Canvas.Parent = Profile.Scroll

	Profile.Header = Instance.new("Frame")
	Profile.Header.Name = "ProfileHeader"
	Profile.Header.Position = UDim2.fromOffset(8, 8)
	Profile.Header.Size = UDim2.new(1, -28, 0, 238)
	Profile.Header.BackgroundColor3 = Theme.BG2
	Profile.Header.BorderSizePixel = 0
	Profile.Header.ClipsDescendants = false
	Profile.Header.ZIndex = 6
	Profile.Header.Parent = Profile.Canvas
	Corner(Profile.Header, 14)
	Stroke(Profile.Header, Theme.Stroke, 0.24, 1)

	Profile.Back = ActionButton(Profile.Header, "ArrowLeft", "BACK", 98, false)
	Profile.Back.Position = UDim2.fromOffset(16, 16)
	Profile.Back.ZIndex = 8

	Profile.Avatar = Instance.new("ImageLabel")
	Profile.Avatar.Position = UDim2.fromOffset(28, 82)
	Profile.Avatar.Size = UDim2.fromOffset(88, 88)
	Profile.Avatar.BackgroundColor3 = Theme.BG3
	Profile.Avatar.BorderSizePixel = 0
	Profile.Avatar.ScaleType = Enum.ScaleType.Crop
	Profile.Avatar.ImageTransparency = 1
	Profile.Avatar.ZIndex = 7
	Profile.Avatar.Parent = Profile.Header
	Corner(Profile.Avatar, 44)
	Stroke(Profile.Avatar, Theme.Stroke, 0.25, 1)

	Profile.Initial = Label(Profile.Header, "?", 32, Theme.Orange2, Enum.Font.GothamBold)
	Profile.Initial.TextXAlignment = Enum.TextXAlignment.Center
	Profile.Initial.Position = UDim2.fromOffset(28, 82)
	Profile.Initial.Size = UDim2.fromOffset(88, 88)
	Profile.Initial.ZIndex = 9
Profile.Initial.Visible = false

	Profile.Name = Label(Profile.Header, "@profile", 22, Theme.Text, Enum.Font.GothamBold)
	Profile.Name.Position = UDim2.fromOffset(136, 82)
	Profile.Name.Size = UDim2.new(1, -156, 0, 34)
	Profile.Name.TextTruncate = Enum.TextTruncate.AtEnd
	Profile.Name.ZIndex = 7

	Profile.Badges = Label(Profile.Header, "", 12, Theme.Orange2, Enum.Font.GothamBold)
	Profile.Badges.Position = UDim2.fromOffset(136, 116)
	Profile.Badges.Size = UDim2.new(1, -156, 0, 24)
	Profile.Badges.TextTruncate = Enum.TextTruncate.AtEnd
	Profile.Badges.ZIndex = 7

	Profile.Bio = Label(Profile.Header, "", 12, Theme.Text, Enum.Font.GothamMedium)
	Profile.Bio.Position = UDim2.fromOffset(136, 142)
	Profile.Bio.Size = UDim2.new(1, -156, 0, 46)
	Profile.Bio.TextWrapped = true
	Profile.Bio.TextYAlignment = Enum.TextYAlignment.Top
	Profile.Bio.ZIndex = 7

	Profile.Meta = Label(Profile.Header, "", 12, Theme.Muted, Enum.Font.GothamMedium)
	Profile.Meta.Position = UDim2.fromOffset(136, 196)
	Profile.Meta.Size = UDim2.new(1, -156, 0, 24)
	Profile.Meta.TextTruncate = Enum.TextTruncate.AtEnd
	Profile.Meta.ZIndex = 7

	Profile.ScriptsTitle = Label(Profile.Canvas, "Scripts by this creator", 18, Theme.Text, Enum.Font.GothamBold)
	Profile.ScriptsTitle.Position = UDim2.fromOffset(20, 270)
	Profile.ScriptsTitle.Size = UDim2.new(1, -40, 0, 30)
	Profile.ScriptsTitle.ZIndex = 6

	Profile.Status = Label(Profile.Canvas, "Select a creator to load profile.", 12, Theme.Muted, Enum.Font.GothamMedium)
	Profile.Status.Position = UDim2.fromOffset(20, 300)
	Profile.Status.Size = UDim2.new(1, -40, 0, 22)
	Profile.Status.ZIndex = 6

	Profile.List = Instance.new("Frame")
	Profile.List.Name = "ProfileScriptsList"
	Profile.List.Position = UDim2.fromOffset(20, 334)
	Profile.List.Size = UDim2.new(1, -40, 0, 460)
	Profile.List.BackgroundTransparency = 1
	Profile.List.BorderSizePixel = 0
	Profile.List.ZIndex = 6
	Profile.List.Parent = Profile.Canvas

	Profile.Layout = Instance.new("UIListLayout")
	Profile.Layout.FillDirection = Enum.FillDirection.Vertical
	Profile.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Profile.Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Profile.Layout.Padding = UDim.new(0, 10)
	Profile.Layout.Parent = Profile.List
end

Profile.Setup()

function SetSideActive(name)
	for pageName, data in pairs(SideButtons) do
		local active = pageName == name
		data.Button.BackgroundColor3 = active and Color3.fromRGB(39, 30, 25) or Theme.BG2
		data.Stroke.Color = active and Theme.Orange or Theme.StrokeSoft
		data.Stroke.Transparency = active and 0.05 or 0.58
		data.Icon.ImageColor3 = active and Theme.Orange2 or Theme.Text
		data.Text.TextColor3 = active and Theme.Orange2 or Theme.Text
	end
end

function ShowPage(name)
	CurrentPageName = name
	CodePage.Visible = name == "Code"
	ExplorePage.Visible = name == "Explore"
	DetailPage.Visible = name == "Detail"
	ConsolePage.Visible = name == "Console"
	if Profile.Page then
		Profile.Page.Visible = name == "Profile"
	end
	SetSideActive((name == "Detail" or name == "Profile") and "Explore" or name)
	if name == "Code" then
		task.defer(CodeEditor.Refresh)
	elseif name == "Detail" then
		task.defer(DetailCode.Refresh)
	elseif name == "Console" then
		ConsoleStatus.Text = "Showing " .. tostring(#ConsoleEntries) .. " events"
	end
end

function FormatCount(n)
	n = tonumber(n) or 0
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

function ScriptTitle(item)
	return tostring(item.title or item.name or "Untitled script")
end

function ScriptAuthor(item)
	local user = item.user or item.creator or {}
	return tostring(user.username or user.name or item.username or "Unknown")
end

function ScriptKey(item)
	if type(item) ~= "table" then
		return ""
	end
	local raw = item._id or item.id or item.slug or item.scriptId or item.script_id or item.rawScript or item.rawUrl or item.rawURL
	if raw ~= nil and tostring(raw) ~= "" then
		return tostring(raw)
	end
	return string.lower(ScriptTitle(item) .. "|" .. ScriptAuthor(item))
end

function ScriptGameName(item)
	if type(item) == "table" and type(item.game) == "table" and item.game.title then
		return tostring(item.game.title)
	end
	return ""
end

function ScriptMetaText(item)
	local metaText = FormatCount(item.views) .. " views   " .. FormatCount(item.likes) .. " likes"
	local gameName = ScriptGameName(item)
	if gameName ~= "" then
		metaText = gameName .. "   " .. metaText
	end
	return metaText
end

function DetailMetaText(item)
	local author = ScriptAuthor(item)
	local gameName = ScriptGameName(item)
	if gameName == "" then
		gameName = "Unknown game"
	end
	return "@" .. author .. "   " .. gameName .. "   " .. FormatCount(item.views) .. " views   " .. FormatCount(item.likes) .. " likes   " .. FormatCount(item.dislikes) .. " dislikes"
end

function MergeScriptStats(target, incoming)
	if type(target) ~= "table" or type(incoming) ~= "table" then
		return false
	end
	local changed = false
	for _, field in ipairs({"views", "likes", "dislikes"}) do
		if incoming[field] ~= nil and tostring(incoming[field]) ~= tostring(target[field]) then
			target[field] = incoming[field]
			changed = true
		end
	end
	for _, field in ipairs({"title", "name", "image", "description", "rawScript", "game", "user"}) do
		if target[field] == nil and incoming[field] ~= nil then
			target[field] = incoming[field]
		end
	end
	return changed
end

function ExtractPlaceId(value)
	if type(value) == "number" then
		return value
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local direct = tonumber(value)
	if direct then
		return direct
	end
	local fromGame = value:match("/games/(%d+)") or value:match("placeId=(%d+)") or value:match("gameId=(%d+)")
	return tonumber(fromGame)
end

function AddGameThumbSet(add, id)
	id = tonumber(id)
	if not id or id <= 0 then
		return
	end
	local textId = tostring(math.floor(id))
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=150&h=150")
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=420&h=420")
end

function AddPlaceThumbSet(add, id)
	id = tonumber(id)
	if not id or id <= 0 then
		return
	end
	local textId = tostring(math.floor(id))
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=150&h=150")
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=420&h=420")
end

function AddAssetThumbSet(add, id)
	id = tonumber(id)
	if not id or id <= 0 then
		return
	end
	local textId = tostring(math.floor(id))
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=150&h=150")
	add("rbxthumb://type=Asset&id=" .. textId .. "&w=420&h=420")
end

function ExtractAnyRobloxId(value)
	if type(value) == "number" then
		return value
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local patterns = {
		"rbxthumb://.-[?&]id=(%d+)",
		"/games/(%d+)",
		"placeId=(%d+)",
		"placeid=(%d+)",
		"gameId=(%d+)",
		"gameid=(%d+)",
		"universeId=(%d+)",
		"universeid=(%d+)",
		"rootPlaceId=(%d+)",
		"rootplaceid=(%d+)",
		"assetId=(%d+)",
		"assetid=(%d+)",
		"/library/(%d+)",
		"/catalog/(%d+)",
		"/assets/(%d+)",
		"[?&]id=(%d+)"
	}
	for _, pattern in ipairs(patterns) do
		local found = value:match(pattern)
		if found then
			return tonumber(found)
		end
	end
	if value:match("^%d+$") then
		return tonumber(value)
	end
	return nil
end

function AddImageFieldCandidates(add, value)
	if type(value) ~= "string" or value == "" then
		return
	end
	local custom = TryExternalImage(value)
	if custom ~= "" then
		add(custom)
		return
	end
	if value:match("^rbxthumb://") or value:match("^rbxasset://") or value:match("^rbxassetid://") or value:match("^http://www%.roblox%.com/asset/%?id=%d+") or value:match("^https://www%.roblox%.com/asset/%?id=%d+") then
		add(value)
		return
	end
	local id = ExtractAnyRobloxId(value)
	if id then
		AddGameThumbSet(add, id)
		AddPlaceThumbSet(add, id)
		AddAssetThumbSet(add, id)
	end
end

function CollectImageHints(source, add)
	if type(source) ~= "table" then
		return
	end
	for key, value in pairs(source) do
		local lowerKey = string.lower(tostring(key))
		if type(value) == "string" then
			if lowerKey:find("image", 1, true) or lowerKey:find("thumb", 1, true) or lowerKey:find("icon", 1, true) or lowerKey:find("logo", 1, true) or lowerKey:find("banner", 1, true) or lowerKey:find("cover", 1, true) or lowerKey:find("poster", 1, true) or lowerKey:find("url", 1, true) or lowerKey:find("link", 1, true) then
				AddImageFieldCandidates(add, value)
			end
		elseif type(value) == "table" and (lowerKey == "game" or lowerKey == "user" or lowerKey == "creator" or lowerKey == "media") then
			for nestedKey, nestedValue in pairs(value) do
				local nestedLower = string.lower(tostring(nestedKey))
				if type(nestedValue) == "string" and (nestedLower:find("image", 1, true) or nestedLower:find("thumb", 1, true) or nestedLower:find("icon", 1, true) or nestedLower:find("logo", 1, true) or nestedLower:find("banner", 1, true) or nestedLower:find("cover", 1, true) or nestedLower:find("poster", 1, true) or nestedLower:find("url", 1, true) or nestedLower:find("link", 1, true)) then
					AddImageFieldCandidates(add, nestedValue)
				end
			end
		end
	end
end

function ScriptImageCandidates(item)
	local candidates = {}
	local used = {}
	local function add(value)
		if type(value) == "string" and value ~= "" and not used[value] then
			used[value] = true
			table.insert(candidates, value)
		end
	end
	local gameData = type(item.game) == "table" and item.game or {}
	local values = {
		item.image,
		item.img,
		item.imageUrl,
		item.imageURL,
		item.image_url,
		item.thumbnail,
		item.thumbnailUrl,
		item.thumbnailURL,
		item.icon,
		item.iconUrl,
		item.iconURL,
		item.logo,
		item.logoUrl,
		item.banner,
		item.cover,
		item.poster,
		gameData.image,
		gameData.img,
		gameData.imgurl,
		gameData.imageUrl,
		gameData.imageURL,
		gameData.image_url,
		gameData.thumbnail,
		gameData.thumbnailUrl,
		gameData.thumbnailURL,
		gameData.icon,
		gameData.iconUrl,
		gameData.logo,
		gameData.banner,
		gameData.cover,
		gameData.poster
	}
	for _, value in ipairs(values) do
		AddImageFieldCandidates(add, value)
	end
	CollectImageHints(item, add)
	local universeIds = {
		gameData.universeId,
		gameData.universeid,
		gameData.universe_id,
		item.universeId,
		item.universeid,
		item.universe_id,
		gameData.gameId,
		gameData.gameid,
		item.gameId,
		item.gameid
	}
	for _, id in ipairs(universeIds) do
		AddGameThumbSet(add, id)
	end
	local placeIds = {
		gameData.id,
		gameData.placeId,
		gameData.placeid,
		gameData.rootPlaceId,
		gameData.rootPlaceid,
		gameData.root_place_id,
		item.placeId,
		item.placeid,
		item.rootPlaceId,
		item.rootPlaceid,
		item.root_place_id
	}
	for _, id in ipairs(placeIds) do
		AddPlaceThumbSet(add, id)
		AddAssetThumbSet(add, id)
	end
	local links = {
		gameData.gameLink,
		gameData.url,
		gameData.link,
		gameData.robloxUrl,
		gameData.robloxURL,
		item.gameLink,
		item.url,
		item.link,
		item.robloxUrl,
		item.robloxURL
	}
	for _, link in ipairs(links) do
		local extracted = ExtractAnyRobloxId(link)
		AddPlaceThumbSet(add, extracted)
		AddGameThumbSet(add, extracted)
		AddAssetThumbSet(add, extracted)
	end
	return candidates
end

function ScriptImage(item)
	local candidates = ScriptImageCandidates(item)
	return candidates[1] or ""
end

function SetScriptImage(label, item)
	local candidates = ScriptImageCandidates(item)
	if not candidates[1] then
		label.Image = ""
		label.ImageTransparency = 1
		return
	end
	label.ImageTransparency = 0
	label.Image = candidates[1]
end

function ClearResults()
	ResultRows = {}
	for _, child in ipairs(ResultsScroll:GetChildren()) do
		if child:IsA("GuiObject") and child ~= ResultsLayout and child ~= ResultsPad then
			child:Destroy()
		end
	end
end

function MakeResultCard(item, index)
	local card = Instance.new("TextButton")
	card.Name = "ResultCard"
	card.BackgroundColor3 = Theme.BG2
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.ClipsDescendants = false
	card.LayoutOrder = index
	card.ZIndex = 7
	card.Parent = ResultsScroll
	Corner(card, 10)
	Stroke(card, Theme.Stroke, 0.35, 1)

	local img = Instance.new("ImageLabel")
	img.Position = UDim2.fromOffset(12, 12)
	img.Size = UDim2.fromOffset(132, 82)
	img.BackgroundTransparency = 1
	img.BackgroundColor3 = Theme.BG3
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Crop
	img.ZIndex = 8
	img.Parent = card
	Corner(img, 8)
	SetScriptImage(img, item)

	local title = Label(card, ScriptTitle(item), 13, Theme.Text, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(160, 12)
	title.Size = UDim2.new(1, -176, 0, 46)
	title.TextWrapped = true
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.ZIndex = 8

	local author = Label(card, "@" .. ScriptAuthor(item), 11, Theme.Orange2, Enum.Font.GothamBold)
	author.Position = UDim2.fromOffset(160, 64)
	author.Size = UDim2.new(1, -176, 0, 18)
	author.TextTruncate = Enum.TextTruncate.AtEnd
	author.ZIndex = 8

	local meta = Label(card, ScriptMetaText(item), 10, Theme.Muted, Enum.Font.GothamMedium)
	meta.Position = UDim2.fromOffset(12, 116)
	meta.Size = UDim2.new(1, -26, 0, 20)
	meta.TextTruncate = Enum.TextTruncate.AtEnd
	meta.ZIndex = 8

	card.MouseEnter:Connect(function()
		Tween(card, { BackgroundColor3 = Theme.BG3 }, 0.12)
	end)
	card.MouseLeave:Connect(function()
		Tween(card, { BackgroundColor3 = Theme.BG2 }, 0.12)
	end)
	ResultRows[ScriptKey(item)] = {Card = card, Item = item, Meta = meta, Title = title, Author = author}

	card.MouseButton1Click:Connect(function()
		SelectedScript = item
		SelectedSource = ""
		ShowDetail(item)
	end)
end

function RenderResults()
	ClearResults()
	if #CurrentResults == 0 then
		local empty = Label(ResultsScroll, "No scripts loaded.", 14, Theme.Muted, Enum.Font.GothamMedium)
		empty.Size = UDim2.fromOffset(360, 60)
		empty.ZIndex = 6
		return
	end
	local gap = 18
	local safeInset = 90
	local availableWidth = math.max(300, ResultsScroll.AbsoluteSize.X - ResultsScroll.ScrollBarThickness - safeInset)
	local columns = availableWidth >= 690 and 2 or 1
	local cellWidth = math.floor((availableWidth - ((columns - 1) * gap)) / columns)
	cellWidth = math.max(300, math.min(356, cellWidth))
	ResultsLayout.CellSize = UDim2.fromOffset(cellWidth, 146)
	for i, item in ipairs(CurrentResults) do
		MakeResultCard(item, i)
	end
	task.defer(function()
		ResultsScroll.CanvasSize = UDim2.fromOffset(0, ResultsLayout.AbsoluteContentSize.Y + 72)
	end)
end

ResultsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ResultsScroll.CanvasSize = UDim2.fromOffset(0, ResultsLayout.AbsoluteContentSize.Y + 72)
end)

function NormalizeScriptList(data)
	if type(data) ~= "table" then
		return {}, 1, 1
	end
	local scripts = data.scripts or data.success or data.script or {}
	if type(scripts) ~= "table" then
		scripts = {}
	end
	if scripts[1] and scripts[1].script and not scripts[1].title then
		local normalized = {}
		for _, entry in ipairs(scripts) do
			local item = entry.script
			if type(item) == "table" then
				item.user = item.user or entry.user
				item.views = item.views or entry.views
				table.insert(normalized, item)
			end
		end
		scripts = normalized
	end
	local info = data.info or {}
	local current = tonumber(info.currentPage) or CurrentPage
	local max = tonumber(info.maxPages) or MaxPages or 1
	return scripts, current, max
end

function BuildScriptsUrl(query, page)
	local url = "https://rscripts.net/api/v2/scripts?page=" .. tostring(math.max(1, tonumber(page) or 1)) .. "&orderBy=date&sort=desc&notPaid=true"
	if Trim(query or "") ~= "" then
		url = url .. "&q=" .. HttpService:UrlEncode(Trim(query or ""))
	end
	return url
end

function Profile.Username(user, fallback)
	if type(user) ~= "table" then
		return tostring(fallback or "")
	end
	return tostring(user.username or user.name or user.displayName or fallback or "")
end

function Profile.AvatarUrls(user)
	local urls = {}
	local used = {}
	local function add(value)
		local url = NormalizeImageUrl(value)
		if type(url) == "string" and url ~= "" and not used[url] then
			used[url] = true
			table.insert(urls, url)
		end
	end
	if type(user) == "table" then
		add(user.image)
		add(user.avatar)
		add(user.avatarUrl)
		add(user.avatarURL)
		add(user.imageUrl)
		add(user.imageURL)
		add(user.profileImage)
		add(user.profilePicture)
		add(user.profile_image)
		add(user.pfp)
		add(user.photo)
		add(user.picture)
		add(user.profilePic)
		add(user.avatar_url)
		add(user.pfpUrl)
		add(user.pfpURL)
		add(user.icon)
		add(user.iconUrl)
		add(user.iconURL)
		if type(user.discord) == "table" then
			add(user.discord.avatar)
			add(user.discord.image)
			add(user.discord.icon)
		end
		if type(user.socials) == "table" then
			add(user.socials.avatar)
			add(user.socials.image)
			add(user.socials.pfp)
		end
	end
	return urls
end

function Profile.SetAvatar(label, user, fallbackName, fallbackLabel)
	if fallbackLabel then
		fallbackLabel.Visible = false
	end
	label.Image = ""
	label.ImageTransparency = 1
	local urls = Profile.AvatarUrls(user)
	if #urls == 0 then
		return
	end
	local token = tostring(os.clock()) .. tostring(math.random(1, 1000000))
	label:SetAttribute("AvatarLoadToken", token)
	task.spawn(function()
		for _, originalUrl in ipairs(urls) do
			if not label.Parent or label:GetAttribute("AvatarLoadToken") ~= token then
				return
			end
			local url = NormalizeImageUrl(originalUrl)
			if url ~= "" then
				if label.Parent and label:GetAttribute("AvatarLoadToken") == token then
					label.Image = url
					label.ImageTransparency = 0
					task.wait(0.08)
					local ok, size = pcall(function()
						return label.ContentImageSize
					end)
					if ok and size and (size.X or 0) > 2 and (size.Y or 0) > 2 then
						return
					end
				end
				local asset = TryExternalImage(url)
				if label.Parent and label:GetAttribute("AvatarLoadToken") == token and asset ~= "" then
					label.Image = asset
					label.ImageTransparency = 0
					return
				end
			end
		end
		if label.Parent and label:GetAttribute("AvatarLoadToken") == token then
			label.Image = ""
			label.ImageTransparency = 1
		end
	end)
end

function Profile.MetaText(user)
	if type(user) ~= "table" then
		return "No extra profile data provided."
	end
	local parts = {}
	local socials = type(user.socials) == "table" and user.socials or {}
	local discordData = type(user.discord) == "table" and user.discord or {}
	local discord = FirstString(discordData.username, user.discord, user.discordUsername, socials.discord, socials.discordServer)
	if discord ~= "" then
		table.insert(parts, "Discord: " .. discord)
	end
	local lastActive = FirstString(user.lastActive, user.last_active, user.updatedAt)
	if lastActive ~= "" then
		table.insert(parts, "Last active: " .. lastActive)
	end
	local website = FirstString(user.website, user.url, socials.website, socials.youtube, socials.github)
	if website ~= "" then
		table.insert(parts, website)
	end
	if #parts == 0 then
		return "No extra profile data provided."
	end
	return table.concat(parts, "   •   ")
end

function Profile.BadgeText(user, scripts)
	local parts = {}
	if type(user) == "table" then
		if user.verified then table.insert(parts, "VERIFIED") end
		if user.admin then table.insert(parts, "ADMIN") end
		if user.owner then table.insert(parts, "OWNER") end
	end
	if type(scripts) == "table" then
		table.insert(parts, tostring(#scripts) .. " SCRIPTS")
	end
	if #parts == 0 then
		return "CREATOR PROFILE"
	end
	return table.concat(parts, "   •   ")
end

function Profile.ClearScripts()
	for _, child in ipairs(Profile.List:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Profile.MakeScriptRow(item, order)
	local row = Instance.new("TextButton")
	row.Name = "ProfileScriptRow" .. tostring(order)
	row.Size = UDim2.new(1, -8, 0, 96)
	row.BackgroundColor3 = Theme.BG2
	row.BorderSizePixel = 0
	row.Text = ""
	row.AutoButtonColor = false
	row.ClipsDescendants = false
	row.LayoutOrder = order
	row.ZIndex = 7
	row.Parent = Profile.List
	Corner(row, 12)
	Stroke(row, Theme.Stroke, 0.35, 1)

	local img = Instance.new("ImageLabel")
	img.Position = UDim2.fromOffset(12, 12)
	img.Size = UDim2.fromOffset(118, 72)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Crop
	img.ZIndex = 8
	img.Parent = row
	Corner(img, 8)
	SetScriptImage(img, item)

	local title = Label(row, ScriptTitle(item), 15, Theme.Text, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(146, 14)
	title.Size = UDim2.new(1, -164, 0, 38)
	title.TextWrapped = true
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.ZIndex = 8

	local meta = Label(row, ScriptMetaText(item), 12, Theme.Muted, Enum.Font.GothamMedium)
	meta.Position = UDim2.fromOffset(146, 60)
	meta.Size = UDim2.new(1, -164, 0, 22)
	meta.TextTruncate = Enum.TextTruncate.AtEnd
	meta.ZIndex = 8

	row.MouseEnter:Connect(function()
		Tween(row, { BackgroundColor3 = Theme.BG3 }, 0.12)
	end)
	row.MouseLeave:Connect(function()
		Tween(row, { BackgroundColor3 = Theme.BG2 }, 0.12)
	end)
	row.MouseButton1Click:Connect(function()
		SelectedScript = item
		ShowDetail(item)
	end)
end

function Profile.RenderScripts(scripts)
	Profile.ClearScripts()
	if type(scripts) ~= "table" or #scripts == 0 then
		Profile.Status.Text = "No public scripts loaded for this creator."
		Profile.List.Size = UDim2.new(1, -40, 0, 120)
		Profile.Canvas.Size = UDim2.new(1, -12, 0, 560)
		Profile.Scroll.CanvasSize = UDim2.fromOffset(0, 560)
		return
	end
	Profile.Status.Text = tostring(#scripts) .. " public scripts loaded"
	for i, item in ipairs(scripts) do
		Profile.MakeScriptRow(item, i)
	end
	task.defer(function()
		local height = Profile.Layout.AbsoluteContentSize.Y + 24
		Profile.List.Size = UDim2.new(1, -40, 0, height)
		local canvasHeight = math.max(820, 360 + height)
		Profile.Canvas.Size = UDim2.new(1, -12, 0, canvasHeight)
		Profile.Scroll.CanvasSize = UDim2.fromOffset(0, canvasHeight)
	end)
end

function Profile.FetchScripts(username)
	username = Trim(username or "")
	if username == "" then
		return {}
	end
	local function decodeScripts(body)
		local decodedOk, data = JsonDecode(body)
		if not decodedOk then
			return {}
		end
		return NormalizeScriptList(data)
	end
	local function exactOnly(list)
		local filtered = {}
		for _, item in ipairs(list) do
			if string.lower(ScriptAuthor(item)) == string.lower(username) then
				table.insert(filtered, item)
			end
		end
		return filtered
	end
	local url = "https://rscripts.net/api/v2/scripts?page=1&orderBy=date&sort=desc&notPaid=true"
	local ok, body = HttpGetWithHeaders(url, {Username = username, username = username})
	if ok then
		local scripts = decodeScripts(body)
		local filtered = exactOnly(scripts)
		if #filtered > 0 then
			return filtered
		end
		if #scripts > 0 and string.lower(ScriptAuthor(scripts[1])) == string.lower(username) then
			return scripts
		end
	end
	local searchUrl = "https://rscripts.net/api/v2/scripts?page=1&orderBy=date&sort=desc&notPaid=true&q=" .. EncodeUrl(username)
	local searchOk, searchBody = HttpGet(searchUrl)
	if searchOk then
		local searchScripts = decodeScripts(searchBody)
		local filtered = exactOnly(searchScripts)
		if #filtered > 0 then
			return filtered
		end
		return searchScripts
	end
	return {}
end

function Profile.Show(user, fallbackName, sourcePage)
	if type(user) ~= "table" then
		user = {}
	end
	local username = Profile.Username(user, fallbackName)
	Profile.CurrentUser = user
	Profile.SourcePage = sourcePage or CurrentPageName or "Detail"
	Profile.Name.Text = username ~= "" and ("@" .. username) or "@profile"
	Profile.Bio.Text = tostring(user.bio or user.description or "No bio provided.")
	Profile.Meta.Text = Profile.MetaText(user)
	Profile.Badges.Text = Profile.BadgeText(user, nil)
	Profile.SetAvatar(Profile.Avatar, user, username, Profile.Initial)
	Profile.Status.Text = username ~= "" and ("Loading scripts by @" .. username .. "...") or "No profile username available."
	Profile.ClearScripts()
	ShowPage("Profile")
	Profile.Scroll.CanvasPosition = Vector2.new(0, 0)
	if username == "" then
		return
	end
	if Profile.Loading then
		return
	end
	Profile.Loading = true
	task.spawn(function()
		local scripts = Profile.FetchScripts(username)
		if Profile.CurrentUser ~= user then
			Profile.Loading = false
			return
		end
		Profile.Scripts = scripts
		if type(scripts) == "table" and type(scripts[1]) == "table" and type(scripts[1].user) == "table" then
			local fetchedUser = scripts[1].user
			if (user.image == nil or user.image == "") and fetchedUser.image ~= nil then user.image = fetchedUser.image end
			if (user.avatar == nil or user.avatar == "") and fetchedUser.avatar ~= nil then user.avatar = fetchedUser.avatar end
			if user.bio == nil and fetchedUser.bio ~= nil then user.bio = fetchedUser.bio end
			if user.discord == nil and fetchedUser.discord ~= nil then user.discord = fetchedUser.discord end
			if user.socials == nil and fetchedUser.socials ~= nil then user.socials = fetchedUser.socials end
			if user.verified == nil then user.verified = fetchedUser.verified end
			if user.admin == nil then user.admin = fetchedUser.admin end
			if user.lastActive == nil and fetchedUser.lastActive ~= nil then user.lastActive = fetchedUser.lastActive end
			Profile.Bio.Text = tostring(user.bio or user.description or "No bio provided.")
			Profile.Meta.Text = Profile.MetaText(user)
			Profile.SetAvatar(Profile.Avatar, user, username, Profile.Initial)
		end
		Profile.Badges.Text = Profile.BadgeText(user, scripts)
		Profile.RenderScripts(scripts)
		Profile.Loading = false
	end)
end

function SearchScripts(query, page)
	if Loading then
		return
	end
	Loading = true
	CurrentQuery = query or ""
	CurrentPage = math.max(1, tonumber(page) or 1)
	ExploreStatus.Text = "Loading..."
	ConsoleLog("info", "Searching Rscripts page " .. tostring(CurrentPage) .. (Trim(CurrentQuery) ~= "" and (" for " .. Trim(CurrentQuery)) or " latest"))
	local url = BuildScriptsUrl(CurrentQuery, CurrentPage)
	task.spawn(function()
		local ok, body = HttpGet(url)
		if not ok then
			ExploreStatus.Text = "Request failed. Check HTTP requests and Output."
			ConsoleLog("error", "Rscripts request failed:", tostring(body))
			Loading = false
			return
		end
		local decodedOk, data = JsonDecode(body)
		if not decodedOk then
			ExploreStatus.Text = "Bad API response. Check Output."
			ConsoleLog("error", "JSON decode failed:", tostring(data))
			Loading = false
			return
		end
		CurrentResults, CurrentPage, MaxPages = NormalizeScriptList(data)
		ExploreStatus.Text = "Page " .. tostring(CurrentPage) .. " of " .. tostring(MaxPages) .. "   " .. tostring(#CurrentResults) .. " scripts"
		RenderResults()
		ConsoleLog("success", "Loaded " .. tostring(#CurrentResults) .. " scripts from Rscripts.")
		Loading = false
	end)
end

function UpdateResultRow(item)
	local key = ScriptKey(item)
	local row = ResultRows[key]
	if row and row.Meta then
		row.Meta.Text = ScriptMetaText(item)
	end
	if SelectedScript and ScriptKey(SelectedScript) == key then
		DetailMeta.Text = DetailMetaText(item)
	end
end

function InsertLiveResult(item)
	if type(item) ~= "table" or ScriptKey(item) == "" then
		return
	end
	table.insert(CurrentResults, 1, item)
	ConsoleLog("update", "New script detected:", ScriptTitle(item))
	for i, result in ipairs(CurrentResults) do
		local row = ResultRows[ScriptKey(result)]
		if row and row.Card then
			row.Card.LayoutOrder = i
		end
	end
	MakeResultCard(item, 1)
	while #CurrentResults > 24 do
		local removed = table.remove(CurrentResults)
		local removedKey = ScriptKey(removed)
		local row = ResultRows[removedKey]
		if row and row.Card then
			row.Card:Destroy()
		end
		ResultRows[removedKey] = nil
	end
	for i, result in ipairs(CurrentResults) do
		local row = ResultRows[ScriptKey(result)]
		if row and row.Card then
			row.Card.LayoutOrder = i
		end
	end
end

function MergeLiveResults(incoming)
	if type(incoming) ~= "table" or #incoming == 0 then
		return
	end
	local currentByKey = {}
	local newItems = {}
	for _, item in ipairs(CurrentResults) do
		currentByKey[ScriptKey(item)] = item
	end
	for _, item in ipairs(incoming) do
		local key = ScriptKey(item)
		local existing = currentByKey[key]
		if existing then
			if MergeScriptStats(existing, item) then
				UpdateResultRow(existing)
				ConsoleLog("update", "Stats updated:", ScriptTitle(existing), ScriptMetaText(existing))
			end
		elseif CurrentPage == 1 then
			table.insert(newItems, item)
			currentByKey[key] = item
		end
	end
	for i = #newItems, 1, -1 do
		InsertLiveResult(newItems[i])
	end
	task.defer(function()
		ResultsScroll.CanvasSize = UDim2.fromOffset(0, ResultsLayout.AbsoluteContentSize.Y + 72)
	end)
end

function AutoUpdateScripts()
	if AutoUpdating or Loading or #CurrentResults == 0 then
		return
	end
	if CurrentPageName ~= "Explore" and CurrentPageName ~= "Detail" then
		return
	end
	AutoUpdating = true
	local query = CurrentQuery
	local page = CurrentPage
	local url = BuildScriptsUrl(query, page)
	task.spawn(function()
		local ok, body = HttpGet(url)
		if ok then
			local decodedOk, data = JsonDecode(body)
			if decodedOk then
				local incoming, returnedPage, returnedMax = NormalizeScriptList(data)
				if query == CurrentQuery and page == CurrentPage then
					MaxPages = returnedMax or MaxPages
					MergeLiveResults(incoming)
					ExploreStatus.Text = "Page " .. tostring(CurrentPage) .. " of " .. tostring(MaxPages) .. "   " .. tostring(#CurrentResults) .. " scripts"
				end
			end
		end
		AutoUpdating = false
	end)
end

function FetchRawScript(item)
	if type(item) ~= "table" then
		return false, ""
	end
	if type(item.source) == "string" and item.source ~= "" then
		return true, item.source
	end
	if type(item.script) == "string" and item.script ~= "" then
		return true, item.script
	end
	if type(item.code) == "string" and item.code ~= "" then
		return true, item.code
	end
	local raw = item.rawScript or item.raw or item.rawUrl or item.rawURL
	if type(raw) == "string" and raw ~= "" then
		return HttpGet(raw)
	end
	if type(item._id) == "string" then
		local ok, body = HttpGet("https://rscripts.net/api/v2/script?id=" .. HttpService:UrlEncode(item._id))
		if ok then
			local decodedOk, data = JsonDecode(body)
			if decodedOk and type(data) == "table" then
				local list = data.script or data.success
				local full = type(list) == "table" and (list[1] or list) or nil
				if type(full) == "table" then
					return FetchRawScript(full)
				end
			end
		end
	end
	return false, ""
end

function ShowDetail(item)
	DetailCanvas.Size = UDim2.new(1, -30, 0, 940)
	DetailScroll.CanvasSize = UDim2.fromOffset(0, 940)
	SetScriptImage(DetailImage, item)
	DetailTitle.Text = ScriptTitle(item)
	local author = ScriptAuthor(item)
	DetailMeta.Text = DetailMetaText(item)
	DetailDescription.Text = tostring(item.description or "No description provided.")
	local user = item.user or {}
	Profile.CurrentUser = user
	Profile.CurrentFallback = author
	Profile.SetAvatar(AuthorAvatar, user, author, Profile.AuthorInitial)
	AuthorInfo.Text = (user.verified and "✓ " or "") .. "@" .. author
	DetailCode:SetText("Loading script source...")
	ConsoleLog("info", "Opened script detail:", ScriptTitle(item))
	ShowPage("Detail")
	task.spawn(function()
		local ok, source = FetchRawScript(item)
		if SelectedScript ~= item then
			return
		end
		if ok and type(source) == "string" and source ~= "" then
			SelectedSource = source
			DetailCode:SetText(source)
			ConsoleLog("success", "Loaded raw source:", ScriptTitle(item), "(" .. tostring(#source) .. " chars)")
		else
			SelectedSource = ""
			DetailCode:SetText("Unable to load raw script source. Check HTTP requests and the API response in Output.")
			ConsoleLog("error", "Could not load raw script source for", ScriptTitle(item))
		end
	end)
end

DetailExecute.MouseButton1Click:Connect(function()
	ConsoleLog("run", "Executing selected script:", ScriptTitle(SelectedScript or {}))
	ExecuteSource(SelectedSource ~= "" and SelectedSource or DetailCode:GetText())
end)

DetailCopy.MouseButton1Click:Connect(function()
	local ok = CopyText(SelectedSource ~= "" and SelectedSource or DetailCode:GetText())
	ConsoleLog(ok and "success" or "warn", ok and "Selected script copied." or "Copy unavailable.")
end)

DetailEdit.MouseButton1Click:Connect(function()
	SaveActiveEditorTab()
	local text = SelectedSource ~= "" and SelectedSource or DetailCode:GetText()
	local name = ScriptTitle(SelectedScript or {})
	name = name:gsub("[^%w_%- ]", ""):sub(1, 18)
	if name == "" then
		name = "script" .. tostring(#EditorTabs + 1)
	end
	table.insert(EditorTabs, {Name = name .. ".lua", Text = text})
	ActiveEditorTab = #EditorTabs
	CodeEditor:SetText(text)
	RenderEditorTabs()
	ShowPage("Code")
	CodeStatus.Text = "Imported to new tab"
	ConsoleLog("success", "Imported selected script to editor:", name .. ".lua")
end)

BackButton.MouseButton1Click:Connect(function()
	ShowPage("Explore")
end)

Profile.AuthorButton.MouseButton1Click:Connect(function()
	if SelectedScript then
		Profile.Show(SelectedScript.user or {}, ScriptAuthor(SelectedScript), "Detail")
	end
end)

Profile.Back.MouseButton1Click:Connect(function()
	if Profile.SourcePage == "Detail" and SelectedScript then
		ShowPage("Detail")
	else
		ShowPage("Explore")
	end
end)

SearchButton.MouseButton1Click:Connect(function()
	SearchScripts(SearchBox.Text, 1)
end)

LatestButton.MouseButton1Click:Connect(function()
	SearchBox.Text = ""
	SearchScripts("", 1)
end)

PrevButton.MouseButton1Click:Connect(function()
	SearchScripts(CurrentQuery, math.max(1, CurrentPage - 1))
end)

NextButton.MouseButton1Click:Connect(function()
	SearchScripts(CurrentQuery, math.min(MaxPages, CurrentPage + 1))
end)

SearchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		SearchScripts(SearchBox.Text, 1)
	end
end)

ResultsScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	RenderResults()
end)

CodeSide.MouseButton1Click:Connect(function()
	ShowPage("Code")
end)

ExploreSide.MouseButton1Click:Connect(function()
	ShowPage("Explore")
	if #CurrentResults == 0 and not Loading then
		SearchScripts("", 1)
	end
end)

ConsoleSide.MouseButton1Click:Connect(function()
	ShowPage("Console")
end)

ConsoleLog("info", "Interface loaded.")

task.spawn(function()
	while Gui.Parent do
		task.wait(AutoUpdateInterval)
		AutoUpdateScripts()
	end
end)

function OpenPanel()
	IsMinimized = false
	MinimizedPill.Visible = false
	Panel.Visible = true
	Panel.BackgroundTransparency = 1
	Tween(Panel, { BackgroundTransparency = 0 }, 0.14)
	task.defer(function()
		CodeEditor:Refresh()
		DetailCode:Refresh()
	end)
end

function MinimizePanel()
	IsMinimized = true
	Panel.Visible = false
	MinimizedPill.Visible = true
end

function ToggleFullscreen()
	if IsMinimized then
		OpenPanel()
		return
	end
	IsFullscreen = not IsFullscreen
	if IsFullscreen then
		NormalPosition = Panel.Position
		NormalSize = Panel.Size
		Tween(Panel, {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -40, 1, -40)
		}, 0.18)
	else
		Tween(Panel, {
			Position = NormalPosition,
			Size = NormalSize
		}, 0.18)
	end
	task.delay(0.2, function()
		CodeEditor:Refresh()
		DetailCode:Refresh()
		RenderResults()
	end)
end

MinimizeButton.MouseButton1Click:Connect(MinimizePanel)
FullscreenButton.MouseButton1Click:Connect(ToggleFullscreen)
MinimizedPill.MouseButton1Click:Connect(OpenPanel)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		if IsMinimized or not Panel.Visible then
			OpenPanel()
		else
			MinimizePanel()
		end
	end
end)

local Dragging = false
local DragStart
local StartPos
local DragTarget = nil

TopBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not IsFullscreen then
		Dragging = true
		DragTarget = Panel
		DragStart = input.Position
		StartPos = Panel.Position
	end
end)

MinimizedPill.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = true
		DragTarget = MinimizedPill
		DragStart = input.Position
		StartPos = MinimizedPill.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = false
		DragTarget = nil
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement and DragTarget then
		local delta = input.Position - DragStart
		if DragTarget == Panel and not IsFullscreen then
			Panel.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
		elseif DragTarget == MinimizedPill then
			MinimizedPill.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
		end
	end
end)

ShowPage("Code")
CodeEditor:Refresh()
DetailCode:Refresh()
