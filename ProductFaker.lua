local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local toggleKey = Enum.KeyCode.RightShift
local title = "PRODUCT FAKER V2 : @vaehz on yt"

local asciiCfg = {
        enabled = true,
        textSize = 13,
        padding = 80,
        fps = 30,
        ramp = " .,:;-=+*x#%@",
        color = Color3.fromRGB(255, 255, 255),
        mouse = true,
}

local env = typeof(getgenv) == "function" and getgenv() or _G
local previous = env.__ProductFaker or env.__ProductFakerUI
if previous then
        pcall(previous.Destroy, true)
end

local col = {
        bg = Color3.fromRGB(13, 13, 13),
        panel = Color3.fromRGB(30, 30, 30),
        panelHi = Color3.fromRGB(38, 38, 38),
        button = Color3.fromRGB(56, 56, 56),
        buttonHi = Color3.fromRGB(72, 72, 72),
        active = Color3.fromRGB(84, 84, 84),
        icon = Color3.fromRGB(193, 193, 193),
        dim = Color3.fromRGB(120, 120, 120),
        white = Color3.fromRGB(255, 255, 255),
        red = Color3.fromRGB(255, 57, 57),
        blue = Color3.fromRGB(94, 115, 255),
        yellow = Color3.fromRGB(238, 255, 131),
        green = Color3.fromRGB(110, 255, 150),
}

local roboto = "rbxasset://fonts/families/RobotoCondensed.json"
local fontBold = Font.new(roboto, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local fontReg = Font.new(roboto, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local fontItalic = Font.new(roboto, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local fontInput = Font.new("rbxassetid://16658246179", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local img = {
        close = "rbxassetid://89309313651390",
        home = "rbxassetid://70573525526341",
        faker = "rbxassetid://117975333704340",
        logger = "rbxassetid://109982256018444",
        supported = "rbxassetid://133954136637154",
        passes = "rbxassetid://84787327728949",
        join = "rbxassetid://88984171145049",
        copy = "rbxassetid://101160281432561",
}

local function getEnum(enum, item)
        local ok, v = pcall(function()
                return Enum[enum][item]
        end)
        return ok and v or nil
end

local strokeInner = getEnum("BorderStrokePosition", "Inner")

local function create(class, props, children)
        local ok, inst = pcall(Instance.new, class)
        if not ok then
                return nil
        end
        local parent
        for k, v in pairs(props or {}) do
                if k == "Parent" then
                        parent = v
                else
                        pcall(function()
                                inst[k] = v
                        end)
                end
        end
        for _, child in pairs(children or {}) do
                child.Parent = inst
        end
        if parent then
                inst.Parent = parent
        end
        return inst
end

local function corner(r)
        return create("UICorner", {CornerRadius = UDim.new(0, r or 8)})
end

local function stroke(t)
        return create("UIStroke", {Color = col.white, Transparency = t or 0.86, BorderStrokePosition = strokeInner})
end

local function tween(obj, t, props, style, dir)
        local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
end

local function label(props)
        props.BackgroundTransparency = 1
        props.BorderSizePixel = 0
        props.TextScaled = props.TextScaled ~= false
        props.TextWrapped = true
        props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
        props.FontFace = props.FontFace or fontReg
        props.TextColor3 = props.TextColor3 or col.white
        return create("TextLabel", props)
end

local function isClick(input)
        local t = input.UserInputType
        return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

local function commas(n)
        local s = tostring(math.floor(tonumber(n) or 0))
        return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function copy(text)
        local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
        return fn ~= nil and (pcall(fn, tostring(text)))
end

local connections = {}
local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(connections, c)
        return c
end

local function mount(gui)
        local parents = {}
        if typeof(gethui) == "function" then
                table.insert(parents, gethui)
        end
        table.insert(parents, function()
                return game:GetService("CoreGui")
        end)
        table.insert(parents, function()
                return LocalPlayer:WaitForChild("PlayerGui")
        end)
        for _, get in ipairs(parents) do
                if pcall(function() gui.Parent = get() end) and gui.Parent then
                        return
                end
        end
end

local fadeProps = {
        {"GuiObject", "BackgroundTransparency"},
        {"TextLabel", "TextTransparency"},
        {"TextButton", "TextTransparency"},
        {"TextBox", "TextTransparency"},
        {"ImageLabel", "ImageTransparency"},
        {"ImageButton", "ImageTransparency"},
        {"ScrollingFrame", "ScrollBarImageTransparency"},
        {"UIStroke", "Transparency"},
        {"UIShadow", "Transparency"},
}

-- don't make these weak, instance wrappers get collected and the originals get lost
local originals = {}
local fadeExclude = {}

local function getOriginal(inst)
        local o = originals[inst]
        if o then
                return o
        end
        o = {}
        for _, pair in ipairs(fadeProps) do
                local okIs, is = pcall(inst.IsA, inst, pair[1])
                if okIs and is then
                        local ok, v = pcall(function()
                                return inst[pair[2]]
                        end)
                        if ok and type(v) == "number" then
                                o[pair[2]] = v
                        end
                end
        end
        originals[inst] = o
        inst.Destroying:Connect(function()
                originals[inst] = nil
        end)
        return o
end

local function isExcluded(inst)
        for _, root in ipairs(fadeExclude) do
                if inst == root or inst:IsDescendantOf(root) then
                        return true
                end
        end
        return false
end

local function fade(root, alpha, t)
        local list = root:GetDescendants()
        table.insert(list, root)
        for _, inst in ipairs(list) do
                if not isExcluded(inst) then
                        local goal
                        for prop, v in pairs(getOriginal(inst)) do
                                goal = goal or {}
                                goal[prop] = v + (1 - v) * (1 - alpha)
                        end
                        if goal then
                                if t and t > 0 then
                                        tween(inst, t, goal, Enum.EasingStyle.Quad)
                                else
                                        for p, v in pairs(goal) do
                                                pcall(function()
                                                        inst[p] = v
                                                end)
                                        end
                                end
                        end
                end
        end
end

local glyphs = "!<>-_\\/[]{}=+*^?#@$%&"
local scrambleIds = {}

local function scramble(lbl, text, duration)
        local id = (scrambleIds[lbl] or 0) + 1
        scrambleIds[lbl] = id
        task.spawn(function()
                local start, len = os.clock(), #text
                while lbl.Parent and scrambleIds[lbl] == id do
                        local p = (os.clock() - start) / duration
                        if p >= 1 then
                                break
                        end
                        local revealed = math.floor(p * len)
                        local out = table.create(len)
                        for i = 1, len do
                                local ch = text:sub(i, i)
                                if i <= revealed or ch == " " then
                                        out[i] = ch
                                else
                                        local r = math.random(1, #glyphs)
                                        out[i] = glyphs:sub(r, r)
                                end
                        end
                        lbl.Text = table.concat(out)
                        task.wait(0.03)
                end
                if scrambleIds[lbl] == id then
                        lbl.Text = text
                end
        end)
end

local ScreenGui = create("ScreenGui", {
        Name = "ProductFakerV2",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
})
mount(ScreenGui)

local AsciiHolder = create("Frame", {
        Name = "AsciiBackdrop",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 1,
        Parent = ScreenGui,
})

local MainScale = create("UIScale", {Scale = 1})

local Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.285, 0.439),
        BackgroundColor3 = col.bg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = ScreenGui,
}, {
        corner(),
        create("UIShadow", {Transparency = 0.5, BlurRadius = UDim.new(0, 20)}),
        create("UIStroke", {Color = col.white, Transparency = 0.74}),
        create("UIAspectRatioConstraint", {AspectRatio = 1.2415}),
        create("UISizeConstraint", {MinSize = Vector2.new(380, 306)}),
        MainScale,
})

local idle = {BackgroundColor3 = col.button, ImageColor3 = col.icon}
local hover = {BackgroundColor3 = col.buttonHi, ImageColor3 = col.white}

local function buttonFx(btn, normal, hovered, isActive)
        normal = normal or idle
        hovered = hovered or hover
        local scale = btn:FindFirstChildOfClass("UIScale") or create("UIScale", {Parent = btn})
        local function active()
                return isActive and isActive()
        end

        btn.MouseEnter:Connect(function()
                if not active() then
                        tween(btn, 0.15, hovered)
                end
        end)
        btn.MouseLeave:Connect(function()
                tween(scale, 0.2, {Scale = 1})
                if not active() then
                        tween(btn, 0.2, normal)
                end
        end)
        btn.MouseButton1Down:Connect(function()
                tween(scale, 0.08, {Scale = 0.9})
        end)
        btn.MouseButton1Up:Connect(function()
                tween(scale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
        end)
end

local TopBar = create("Frame", {
        Name = "TopBar",
        Size = UDim2.fromScale(1, 0.125),
        BackgroundColor3 = col.panel,
        BorderSizePixel = 0,
        Parent = Main,
}, {
        create("UICorner", {BottomLeftRadius = UDim.new(0, 0), BottomRightRadius = UDim.new(0, 0)}),
})

local Title = label({
        Name = "Title",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0.034, 0.5),
        Size = UDim2.fromScale(0.8, 0.386),
        Text = title,
        FontFace = fontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
})

local CloseButton = create("ImageButton", {
        Name = "CloseButton",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.948, 0.5),
        Size = UDim2.fromScale(0.069, 0.693),
        BackgroundColor3 = col.button,
        BorderSizePixel = 0,
        Image = img.close,
        ImageColor3 = col.icon,
        AutoButtonColor = false,
        Parent = TopBar,
}, {corner(), stroke(), create("UIScale")})
buttonFx(CloseButton, idle, {BackgroundColor3 = Color3.fromRGB(150, 40, 40), ImageColor3 = col.white})

local BottomBar = create("Frame", {
        Name = "BottomBar",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 0.125),
        BackgroundColor3 = col.panel,
        BorderSizePixel = 0,
        Parent = Main,
}, {
        create("UICorner", {TopLeftRadius = UDim.new(0, 0), TopRightRadius = UDim.new(0, 0)}),
})

local ButtonContainer = create("Frame", {
        Name = "ButtonContainer",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.9588, 0.636),
        BackgroundTransparency = 1,
        Parent = BottomBar,
}, {
        create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
        }),
})

local Indicator = create("Frame", {
        Name = "TabIndicator",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.fromOffset(14, 2),
        BackgroundColor3 = col.white,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = BottomBar,
}, {corner(1)})

local function navButton(name, image, order)
        return create("ImageButton", {
                Name = name,
                LayoutOrder = order,
                Size = UDim2.fromScale(0.0668, 1),
                BackgroundColor3 = col.button,
                BorderSizePixel = 0,
                Image = image,
                ImageColor3 = col.icon,
                AutoButtonColor = false,
                Parent = ButtonContainer,
        }, {corner(), stroke(), create("UIScale")})
end

local HomeButton = navButton("HomeButton", img.home, 1)
local FakerButton = navButton("FakerButton", img.faker, 2)
local LoggerButton = navButton("LoggerButton", img.logger, 3)
local SupportedButton = navButton("SupportedButton", img.supported, 4)
local PassListButton = navButton("PassListButton", img.passes, 5)

local SectionsContainer = create("Frame", {
        Name = "SectionsContainer",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.938, 0.665),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = Main,
})

local emptyLabels = {}

local function makeScreen(name, scrolling)
        if not scrolling then
                return create("Frame", {
                        Name = name,
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        Visible = false,
                        Parent = SectionsContainer,
                })
        end

        local sf = create("ScrollingFrame", {
                Name = name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Visible = false,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = col.button,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Parent = SectionsContainer,
        }, {
                create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
                create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1)}),
        })

        local empty = label({
                Name = "Empty",
                AnchorPoint = Vector2.new(0, 0),
                Size = UDim2.new(1, -8, 0, 40),
                Text = "Nothing here yet.",
                TextScaled = false,
                TextSize = 14,
                TextColor3 = col.dim,
                LayoutOrder = -1e9,
                Parent = sf,
        })
        emptyLabels[sf] = empty

        local function refresh()
                for _, child in ipairs(sf:GetChildren()) do
                        if child:GetAttribute("IsRow") then
                                empty.Visible = false
                                return
                        end
                end
                empty.Visible = true
        end
        sf.ChildAdded:Connect(refresh)
        sf.ChildRemoved:Connect(refresh)

        return sf
end

local HomeScreen = makeScreen("HomeScreen", false)
local FakerScreen = makeScreen("FakerScreen", false)
local ProductLogger = makeScreen("ProductLogger", true)
local SupportedContainer = makeScreen("SupportedContainer", true)
local GamepassList = makeScreen("GamepassList", true)

local ToastStroke = create("UIStroke", {Color = col.white, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
local Toast = create("TextLabel", {
        Name = "Toast",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.875, -6),
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = col.panel,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = fontReg,
        TextSize = 14,
        TextColor3 = col.white,
        TextTransparency = 1,
        Text = "",
        ZIndex = 20,
        Parent = Main,
}, {
        corner(13),
        create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}),
        ToastStroke,
})
table.insert(fadeExclude, Toast)

local toastId = 0
local function toast(text, color)
        toastId += 1
        local id = toastId
        Toast.TextColor3 = color or col.white
        Toast.Position = UDim2.new(0.5, 0, 0.875, 4)
        tween(Toast, 0.3, {BackgroundTransparency = 0, TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.875, -6)})
        tween(ToastStroke, 0.3, {Transparency = 0.8})
        scramble(Toast, text, 0.25)
        task.delay(1.8, function()
                if id ~= toastId then
                        return
                end
                tween(Toast, 0.3, {BackgroundTransparency = 1, TextTransparency = 1})
                tween(ToastStroke, 0.3, {Transparency = 1})
        end)
end

label({
        Name = "Subhead",
        Text = "Fakes gamepass/product purchases.",
        FontFace = fontItalic,
        Size = UDim2.fromScale(0.824, 0.107),
        Position = UDim2.fromScale(0.5, 0.088),
        Parent = HomeScreen,
})

local function linkLabel(text, color, y, link)
        local lbl = label({
                Name = "Link",
                Text = text,
                TextColor3 = color,
                Size = UDim2.fromScale(0.824, 0.107),
                Position = UDim2.fromScale(0.5, y),
                Active = true,
                Parent = HomeScreen,
        })
        lbl.MouseEnter:Connect(function()
                tween(lbl, 0.15, {TextColor3 = color:Lerp(col.white, 0.45)})
        end)
        lbl.MouseLeave:Connect(function()
                tween(lbl, 0.2, {TextColor3 = color})
        end)
        lbl.InputBegan:Connect(function(input)
                if not isClick(input) then
                        return
                end
                if copy(link) then
                        toast("Copied " .. link)
                else
                        toast("Clipboard unavailable", col.red)
                end
        end)
end

linkLabel("YouTube: @vaehz", col.red, 0.297, "https://youtube.com/@vaehz")
linkLabel("Discord: discord.gg/vaehz", col.blue, 0.404, "https://discord.gg/vaehz")
linkLabel("Website: RobloxExploit.org", col.yellow, 0.511, "https://robloxexploit.org")

label({
        Name = "Notice",
        Text = "THIS WONT WORK ON MAJORITY OF GAMES, GET SOME KNOWLEDGE BEFORE COMPLAINING THAT THIS DOESNT WORK. SUPPORTED GAMES LIST CAN BE FOUND AT THE BOTTOM OF THIS UI.",
        Size = UDim2.fromScale(0.824, 0.222),
        Position = UDim2.fromScale(0.4988, 0.833),
        Parent = HomeScreen,
})

local idInputPos = UDim2.fromScale(0.0122, 0)

local IdStroke = stroke()
local IdInput = create("Frame", {
        Name = "IdInput",
        Position = idInputPos,
        Size = UDim2.fromScale(0.5805, 0.1838),
        BackgroundColor3 = col.panel,
        BorderSizePixel = 0,
        Parent = FakerScreen,
}, {corner(), IdStroke})

local InpBox = create("TextBox", {
        Name = "InpBox",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.9076, 0.4651),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = fontInput,
        PlaceholderText = "Paste ID here",
        PlaceholderColor3 = col.dim,
        Text = "",
        TextColor3 = col.white,
        TextScaled = true,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = IdInput,
})

InpBox.Focused:Connect(function()
        tween(IdStroke, 0.2, {Transparency = 0.55})
        tween(IdInput, 0.2, {BackgroundColor3 = col.panelHi})
end)

local FakeButton = create("ImageButton", {
        Name = "FakePurchaseBtn",
        Position = UDim2.fromScale(0.5976, 0),
        Size = UDim2.fromScale(0.3878, 0.1838),
        BackgroundColor3 = col.panel,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ImageTransparency = 1,
        Parent = FakerScreen,
}, {corner(), stroke(), create("UIScale")})

label({
        Name = "Label",
        Text = "Fake it!",
        FontFace = fontBold,
        Size = UDim2.fromScale(0.8176, 0.4651),
        Position = UDim2.fromScale(0.5, 0.5),
        Parent = FakeButton,
})

buttonFx(FakeButton, {BackgroundColor3 = col.panel}, {BackgroundColor3 = col.buttonHi})

label({
        Name = "Notice",
        Text = "Please note that this will NOT work in majority of games. Please do your research before complaining that this script is broken. At the bottom you'll find a list of games this supports.",
        Size = UDim2.fromScale(0.8244, 0.2222),
        Position = UDim2.fromScale(0.4841, 0.8889),
        Parent = FakerScreen,
})

local function shake(obj, base)
        task.spawn(function()
                for _, o in ipairs({7, -6, 4, -3, 2, 0}) do
                        tween(obj, 0.04, {Position = base + UDim2.fromOffset(o, 0)}, Enum.EasingStyle.Sine)
                        task.wait(0.04)
                end
                obj.Position = base
        end)
end

local function makeRow(list, data, actionImage, onAction)
        local row = create("Frame", {
                Name = "Row",
                Size = UDim2.new(1, -8, 0, 66),
                BackgroundColor3 = col.panel,
                BorderSizePixel = 0,
                LayoutOrder = data.order or 0,
        }, {corner(), stroke()})
        row:SetAttribute("IsRow", true)

        create("ImageLabel", {
                Name = "Icon",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 35, 0.5, 0),
                Size = UDim2.fromOffset(49, 49),
                BackgroundColor3 = col.button,
                BorderSizePixel = 0,
                Image = data.icon or "",
                ScaleType = Enum.ScaleType.Crop,
                Parent = row,
        }, {corner(), stroke()})

        label({
                Name = "Title",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 71, 0, 24),
                Size = UDim2.new(1, -120, 0, 17),
                Text = data.title or "",
                FontFace = fontBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
        })

        label({
                Name = "Sub",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 71, 0, 41),
                Size = UDim2.new(1, -120, 0, 17),
                Text = data.sub or "",
                TextColor3 = col.icon,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
        })

        local action = create("ImageButton", {
                Name = "Action",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -30, 0.5, 0),
                Size = UDim2.fromOffset(32, 32),
                BackgroundColor3 = col.button,
                BorderSizePixel = 0,
                Image = actionImage,
                ImageColor3 = col.icon,
                AutoButtonColor = false,
                Parent = row,
        }, {corner(), stroke(), create("UIScale")})
        buttonFx(action)
        action.MouseButton1Click:Connect(onAction)

        if data.onClick then
                row.InputBegan:Connect(function(input)
                        if isClick(input) then
                                data.onClick()
                        end
                end)
        end

        row.MouseEnter:Connect(function()
                tween(row, 0.15, {BackgroundColor3 = col.panelHi})
        end)
        row.MouseLeave:Connect(function()
                tween(row, 0.2, {BackgroundColor3 = col.panel})
        end)

        row.Parent = list

        if list.Visible and Main.Visible then
                fade(row, 0, 0)
                fade(row, 1, 0.3)
        end

        return row
end

local function clearList(list)
        for _, child in ipairs(list:GetChildren()) do
                if child:GetAttribute("IsRow") then
                        child:Destroy()
                end
        end
end

local function copyId(id)
        if copy(id) then
                toast("Copied " .. tostring(id), col.green)
        else
                toast("Clipboard unavailable", col.red)
        end
end

local tabs = {
        {name = "Home", button = HomeButton, screen = HomeScreen},
        {name = "Faker", button = FakerButton, screen = FakerScreen},
        {name = "Logger", button = LoggerButton, screen = ProductLogger},
        {name = "Supported", button = SupportedButton, screen = SupportedContainer},
        {name = "Passes", button = PassListButton, screen = GamepassList},
}

local navActive = {BackgroundColor3 = col.active, ImageColor3 = col.white}
local currentTab
local scanProducts
local loadSupported

local function moveIndicator(instant)
        if not currentTab then
                return
        end
        local btn = tabs[currentTab].button
        local s = MainScale.Scale > 0 and MainScale.Scale or 1
        local x = (btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2 - BottomBar.AbsolutePosition.X) / s
        local pos = UDim2.new(0, x, 1, -2)
        if instant then
                Indicator.Position = pos
        else
                tween(Indicator, 0.4, {Position = pos})
        end
end

local function setTab(index, instant)
        if index == currentTab then
                return
        end
        local prev = currentTab
        local dir = (prev and index < prev) and -1 or 1
        currentTab = index

        for i, tab in ipairs(tabs) do
                local goal = i == index and navActive or idle
                if instant then
                        for k, v in pairs(goal) do
                                tab.button[k] = v
                        end
                else
                        tween(tab.button, 0.2, goal)
                end
        end
        moveIndicator(instant)

        if prev then
                local old = tabs[prev].screen
                if instant then
                        old.Visible = false
                else
                        fade(old, 0, 0.15)
                        tween(old, 0.25, {Position = UDim2.fromScale(-0.06 * dir, 0)})
                        task.delay(0.25, function()
                                if tabs[currentTab].screen ~= old then
                                        old.Visible = false
                                end
                        end)
                end
        end

        local screen = tabs[index].screen
        screen.Visible = true
        if instant then
                screen.Position = UDim2.new()
                fade(screen, 1, 0)
        else
                screen.Position = UDim2.fromScale(0.06 * dir, 0)
                fade(screen, 0, 0)
                tween(screen, 0.4, {Position = UDim2.new()})
                fade(screen, 1, 0.3)
        end
end

local function setTabByName(name)
        for i, tab in ipairs(tabs) do
                if tab.name == name then
                        setTab(i)
                        return
                end
        end
end

for i, tab in ipairs(tabs) do
        buttonFx(tab.button, idle, hover, function()
                return currentTab == i
        end)
        tab.button.MouseButton1Click:Connect(function()
                if currentTab == i and tab.name == "Passes" and scanProducts then
                        scanProducts()
                elseif currentTab == i and tab.name == "Supported" and loadSupported then
                        loadSupported()
                else
                        setTab(i)
                end
        end)
end

BottomBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        moveIndicator(true)
end)
BottomBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        moveIndicator(true)
end)

do
        local dragging, dragStart, startPos
        TopBar.InputBegan:Connect(function(input)
                if not isClick(input) then
                        return
                end
                dragging, dragStart, startPos = true, input.Position, Main.Position
                local c
                c = input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                                dragging = false
                                c:Disconnect()
                        end
                end)
        end)

        bind(UserInputService.InputChanged, function(input)
                if not dragging then
                        return
                end
                local t = input.UserInputType
                if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
                        local d = input.Position - dragStart
                        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
        end)
end

local ascii = {}
do
        local font = Enum.Font.Code
        local huge = Vector2.new(1e5, 1e5)
        local size = asciiCfg.textSize

        local cw = TextService:GetTextSize(string.rep("M", 40), size, font, huge).X / 40
        local h1 = TextService:GetTextSize("M", size, font, huge).Y
        local h11 = TextService:GetTextSize(string.rep("M\n", 10) .. "M", size, font, huge).Y
        local ch = (h11 - h1) / 10
        if cw <= 0 then
                cw = size * 0.6
        end
        if ch <= 0 then
                ch = size
        end

        -- 3 stacked labels at different transparencies, cheaper than richtext per char
        local layers = {
                {min = 0.1, transparency = 0.84},
                {min = 0.4, transparency = 0.62},
                {min = 0.7, transparency = 0.3},
        }

        local labels = {}
        for i in ipairs(layers) do
                labels[i] = create("TextLabel", {
                        Name = "Layer" .. i,
                        BackgroundTransparency = 1,
                        Font = font,
                        TextSize = size,
                        TextColor3 = asciiCfg.color,
                        TextTransparency = 1,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = false,
                        RichText = false,
                        Text = "",
                        ZIndex = 1,
                        Parent = AsciiHolder,
                })
        end

        local ramp = {}
        for i = 1, #asciiCfg.ramp do
                ramp[i] = asciiCfg.ramp:sub(i, i)
        end
        local rampLen = #ramp

        local cols, rows, offX, offY = 0, 0, 0, 0
        local glow = {}
        local bufs = {{}, {}, {}}
        local lines = {{}, {}, {}}

        function ascii.rebuild(area, inner)
                cols = math.max(1, math.floor(area.X / cw))
                rows = math.max(1, math.floor(area.Y / ch))
                offX = (area.X - cols * cw) / 2
                offY = (area.Y - rows * ch) / 2

                for _, l in ipairs(labels) do
                        l.Position = UDim2.fromOffset(offX, offY)
                        l.Size = UDim2.fromOffset(cols * cw + 4, rows * ch + 4)
                end

                local cx, cy = area.X / 2, area.Y / 2
                local hw, hh = inner.X / 2, inner.Y / 2
                local pad = asciiCfg.padding
                table.clear(glow)
                for y = 0, rows - 1 do
                        local qy = math.max(math.abs(offY + (y + 0.5) * ch - cy) - hh, 0)
                        for x = 0, cols - 1 do
                                local qx = math.max(math.abs(offX + (x + 0.5) * cw - cx) - hw, 0)
                                local i = y * cols + x + 1
                                if qx == 0 and qy == 0 then
                                        glow[i] = -1
                                else
                                        local g = math.clamp(1 - math.sqrt(qx * qx + qy * qy) / pad, 0, 1)
                                        glow[i] = g * g * (3 - 2 * g)
                                end
                        end
                end
                for _, b in ipairs(bufs) do
                        table.clear(b)
                end
        end

        local noise, sin, cos, sqrt, exp, floor = math.noise, math.sin, math.cos, math.sqrt, math.exp, math.floor
        local min1, min2, min3 = layers[1].min, layers[2].min, layers[3].min
        local aspect = ch / cw

        function ascii.render(t, alpha, mx, my)
                local mcx, mcy
                if mx then
                        mcx, mcy = (mx - offX) / cw, (my - offY) / ch
                end
                local b1, b2, b3 = bufs[1], bufs[2], bufs[3]
                local l1, l2, l3 = lines[1], lines[2], lines[3]

                for y = 0, rows - 1 do
                        local base = y * cols
                        local ny = y * 0.11 - t * 0.35
                        local wy = cos(y * 0.21 - t * 0.7)
                        for x = 0, cols - 1 do
                                local g = glow[base + x + 1]
                                local c1, c2, c3 = " ", " ", " "
                                if g > 0 then
                                        local v = 0.45 + noise(x * 0.055, ny, t * 0.12) * 1.3 + sin(x * 0.12 + t * 1.1) * wy * 0.18
                                        if mcx then
                                                local dx, dy = x - mcx, (y - mcy) * aspect
                                                local d = sqrt(dx * dx + dy * dy)
                                                v += sin(d * 0.45 - t * 7) * exp(-d * 0.09) * 0.45
                                        end
                                        v *= g * alpha
                                        if v >= min1 then
                                                local idx = math.clamp(floor(v * rampLen) + 1, 2, rampLen)
                                                local glyph = ramp[idx]
                                                if v >= min3 then
                                                        c3 = glyph
                                                elseif v >= min2 then
                                                        c2 = glyph
                                                else
                                                        c1 = glyph
                                                end
                                        end
                                end
                                b1[x + 1], b2[x + 1], b3[x + 1] = c1, c2, c3
                        end
                        l1[y + 1] = table.concat(b1, "", 1, cols)
                        l2[y + 1] = table.concat(b2, "", 1, cols)
                        l3[y + 1] = table.concat(b3, "", 1, cols)
                end

                labels[1].Text = table.concat(l1, "\n", 1, rows)
                labels[2].Text = table.concat(l2, "\n", 1, rows)
                labels[3].Text = table.concat(l3, "\n", 1, rows)

                for i, layer in ipairs(layers) do
                        labels[i].TextTransparency = 1 - (1 - layer.transparency) * alpha
                end
        end
end

local asciiAlpha = Instance.new("NumberValue")

do
        local acc, lastArea = 0, nil
        local start = os.clock()

        bind(RunService.RenderStepped, function(dt)
                AsciiHolder.Position = Main.Position
                if not asciiCfg.enabled then
                        return
                end

                local alpha = asciiAlpha.Value
                if alpha <= 0.001 then
                        return
                end

                acc += dt
                if acc < 1 / asciiCfg.fps then
                        return
                end
                acc = 0

                local s = MainScale.Scale > 0 and MainScale.Scale or 1
                local abs = Main.AbsoluteSize
                local inner = Vector2.new(math.floor(abs.X / s + 0.5), math.floor(abs.Y / s + 0.5))
                local area = inner + Vector2.new(asciiCfg.padding * 2, asciiCfg.padding * 2)
                if area ~= lastArea then
                        lastArea = area
                        AsciiHolder.Size = UDim2.fromOffset(area.X, area.Y)
                        ascii.rebuild(area, inner)
                end

                local mx, my
                if asciiCfg.mouse then
                        local m = UserInputService:GetMouseLocation() - AsciiHolder.AbsolutePosition
                        if m.X >= 0 and m.Y >= 0 and m.X <= area.X and m.Y <= area.Y then
                                mx, my = m.X, m.Y
                        end
                end

                ascii.render(os.clock() - start, alpha, mx, my)
        end)
end

local UI = {}
local isOpen, destroyed = false, false

local function open()
        if isOpen or destroyed then
                return
        end
        isOpen = true
        Main.Visible = true
        AsciiHolder.Visible = asciiCfg.enabled

        MainScale.Scale = 0.88
        fade(Main, 0, 0)
        tween(MainScale, 0.55, {Scale = 1}, Enum.EasingStyle.Back)
        fade(Main, 1, 0.35)
        tween(asciiAlpha, 1, {Value = 1}, Enum.EasingStyle.Sine)
        scramble(Title, title, 0.6)
        task.defer(moveIndicator, true)
end

local function hide(callback)
        if not isOpen then
                if callback then
                        callback()
                end
                return
        end
        isOpen = false
        tween(MainScale, 0.25, {Scale = 0.9}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        fade(Main, 0, 0.22)
        tween(asciiAlpha, 0.35, {Value = 0}, Enum.EasingStyle.Quad)
        task.delay(0.36, function()
                if not isOpen then
                        Main.Visible = false
                        AsciiHolder.Visible = false
                end
                if callback then
                        callback()
                end
        end)
end

function UI.Toggle()
        if destroyed then
                return
        end
        if isOpen then
                hide()
        else
                open()
        end
end

function UI.Destroy(instant)
        if destroyed then
                return
        end
        destroyed = true
        local function finish()
                for _, c in ipairs(connections) do
                        c:Disconnect()
                end
                asciiAlpha:Destroy()
                ScreenGui:Destroy()
                if env.__ProductFaker == UI then
                        env.__ProductFaker = nil
                end
        end
        if instant then
                finish()
        else
                hide(finish)
        end
end

CloseButton.MouseButton1Click:Connect(function()
        UI.Destroy()
end)

bind(UserInputService.InputBegan, function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
                UI.Toggle()
        end
end)

local knownKinds = {}

local infoTypes = {
        Product = getEnum("InfoType", "Product"),
        Gamepass = getEnum("InfoType", "GamePass"),
        Asset = getEnum("InfoType", "Asset"),
        Bundle = getEnum("InfoType", "Bundle"),
        Subscription = getEnum("InfoType", "Subscription"),
}

local infoCache = {}
local function getInfo(kind, id)
        local key = kind .. ":" .. tostring(id)
        if infoCache[key] ~= nil then
                return infoCache[key]
        end
        local info = false
        if infoTypes[kind] and tonumber(id) then
                local ok, res = pcall(function()
                        return MarketplaceService:GetProductInfo(tonumber(id), infoTypes[kind])
                end)
                if ok and type(res) == "table" then
                        info = res
                end
        end
        infoCache[key] = info
        return info
end

local function sendToFaker(id)
        InpBox.Text = tostring(id)
        setTabByName("Faker")
        toast("ID loaded: " .. tostring(id))
end

-- fake

local fire = {
        Product = function(id)
                MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, id, true)
        end,
        Gamepass = function(id)
                MarketplaceService:SignalPromptGamePassPurchaseFinished(LocalPlayer, id, true)
        end,
        Asset = function(id)
                MarketplaceService:SignalPromptPurchaseFinished(LocalPlayer, id, true)
        end,
        Bundle = function(id)
                MarketplaceService:SignalPromptBundlePurchaseFinished(LocalPlayer, id, true)
        end,
}

local function detectKind(id)
        local known = knownKinds[tostring(id)]
        if known and fire[known] then
                return known
        end
        for _, kind in ipairs({"Product", "Gamepass", "Asset"}) do
                if getInfo(kind, id) then
                        knownKinds[tostring(id)] = kind
                        return kind
                end
        end
        return "Product"
end

local function fakePurchase(id)
        local kind = detectKind(id)
        fire[kind](id)
        return kind
end

local function submitFake()
        local id = tonumber((InpBox.Text:gsub("%s", "")):match("^%d+$"))
        if not id then
                shake(IdInput, idInputPos)
                IdStroke.Color = col.red
                IdStroke.Transparency = 0.3
                tween(IdStroke, 0.6, {Color = col.white, Transparency = 0.86})
                toast("Enter a valid ID", col.red)
                return
        end
        local ok, res = pcall(fakePurchase, id)
        if ok then
                toast("Fired " .. res:lower() .. " " .. id, col.green)
        else
                warn("[Product Faker] " .. tostring(res))
                toast("Error, check console", col.red)
        end
end

FakeButton.MouseButton1Click:Connect(submitFake)
InpBox.FocusLost:Connect(function(enterPressed)
        tween(IdStroke, 0.2, {Transparency = 0.86})
        tween(IdInput, 0.2, {BackgroundColor3 = col.panel})
        if enterPressed then
                submitFake()
        end
end)

-- pass finder

local function addPass(data)
        knownKinds[tostring(data.id)] = data.kind
        local icon = data.icon
        if not icon and data.kind == "Gamepass" then
                icon = ("rbxthumb://type=GamePass&id=%d&w=150&h=150"):format(data.id)
        end
        local price = data.price and ("R$" .. commas(data.price)) or "Offsale"
        return makeRow(GamepassList, {
                title = data.name or tostring(data.id),
                sub = data.kind .. "  •  " .. price,
                icon = icon,
                order = data.order,
                onClick = function()
                        sendToFaker(data.id)
                end,
        }, img.copy, function()
                copyId(data.id)
        end)
end

local httpRequest = (typeof(request) == "function" and request)
        or (typeof(http_request) == "function" and http_request)
        or (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)

local function getJson(url)
        local body
        if httpRequest then
                local ok, res = pcall(httpRequest, {Url = url, Method = "GET"})
                if ok and type(res) == "table" and (res.StatusCode == 200 or (res.StatusCode == nil and res.Success)) then
                        body = res.Body
                end
        end
        if not body then
                local ok, res = pcall(function()
                        return game:HttpGet(url)
                end)
                if ok then
                        body = res
                end
        end
        if type(body) ~= "string" or body == "" then
                return nil
        end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
        return ok and data or nil
end

local function nonEmpty(s)
        return type(s) == "string" and s ~= "" and s or nil
end

-- new endpoint first, legacy as fallback, roproxy for executors that block roblox.com
local passSources = {
        {
                hosts = {"apis.roblox.com", "apis.roproxy.com"},
                url = function(host, universeId, cursor)
                        local page = cursor and "&pageToken=" .. HttpService:UrlEncode(cursor) or ""
                        return ("https://%s/game-passes/v1/universes/%d/game-passes?passView=Full&pageSize=100%s"):format(host, universeId, page)
                end,
                parse = function(d)
                        if type(d) ~= "table" or type(d.gamePasses) ~= "table" then
                                return nil
                        end
                        local out = {}
                        for _, p in ipairs(d.gamePasses) do
                                local priceInfo = type(p.priceInformation) == "table" and p.priceInformation or {}
                                table.insert(out, {
                                        id = p.id or p.gamePassId,
                                        name = p.displayName or p.name,
                                        price = p.price or priceInfo.defaultPriceInRobux or priceInfo.price,
                                })
                        end
                        return out, nonEmpty(d.nextPageToken)
                end,
        },
        {
                hosts = {"games.roblox.com", "games.roproxy.com"},
                url = function(host, universeId, cursor)
                        local page = cursor and "&cursor=" .. HttpService:UrlEncode(cursor) or ""
                        return ("https://%s/v1/games/%d/game-passes?limit=100&sortOrder=Asc%s"):format(host, universeId, page)
                end,
                parse = function(d)
                        if type(d) ~= "table" or type(d.data) ~= "table" then
                                return nil
                        end
                        local out = {}
                        for _, p in ipairs(d.data) do
                                table.insert(out, {id = p.id, name = p.displayName or p.name, price = p.price})
                        end
                        return out, nonEmpty(d.nextPageCursor)
                end,
        },
}

local function fetchGamepasses(universeId)
        for _, source in ipairs(passSources) do
                for _, host in ipairs(source.hosts) do
                        local all, cursor = source.parse(getJson(source.url(host, universeId)))
                        if all then
                                local pages = 1
                                while cursor and pages < 25 do
                                        local more, nextCursor = source.parse(getJson(source.url(host, universeId, cursor)))
                                        if not more then
                                                break
                                        end
                                        for _, p in ipairs(more) do
                                                table.insert(all, p)
                                        end
                                        cursor, pages = nextCursor, pages + 1
                                end
                                return all
                        end
                end
        end
        return nil
end

local function fetchProducts()
        local ok, pages = pcall(function()
                return MarketplaceService:GetDeveloperProductsAsync()
        end)
        if not ok or not pages then
                return nil
        end
        local out = {}
        for _ = 1, 50 do
                local okPage, page = pcall(function()
                        return pages:GetCurrentPage()
                end)
                if not okPage then
                        break
                end
                for _, item in ipairs(page) do
                        local iconId = item.IconImageAssetId
                        table.insert(out, {
                                id = item.ProductId or item.DeveloperProductId,
                                name = item.Name or item.DisplayName,
                                price = item.PriceInRobux,
                                icon = iconId and iconId ~= 0 and "rbxassetid://" .. iconId or nil,
                        })
                end
                if pages.IsFinished or not pcall(function() pages:AdvanceToNextPageAsync() end) then
                        break
                end
        end
        return out
end

local scanning = false
scanProducts = function()
        if scanning or destroyed then
                return
        end
        scanning = true
        clearList(GamepassList)
        local empty = emptyLabels[GamepassList]
        empty.Text = "Scanning..."

        task.spawn(function()
                local passes, products
                task.spawn(function()
                        passes = fetchGamepasses(game.GameId) or false
                end)
                task.spawn(function()
                        products = fetchProducts() or false
                end)
                while (passes == nil or products == nil) and not destroyed do
                        task.wait()
                end
                if destroyed then
                        return
                end

                local function byPrice(a, b)
                        return (a.price or math.huge) < (b.price or math.huge)
                end

                local order = 0
                for _, group in ipairs({{passes, "Gamepass"}, {products, "Product"}}) do
                        local items, kind = group[1], group[2]
                        if items then
                                table.sort(items, byPrice)
                                for _, item in ipairs(items) do
                                        if item.id then
                                                order += 1
                                                addPass({id = item.id, name = item.name, price = item.price, icon = item.icon, kind = kind, order = order})
                                        end
                                end
                        end
                end

                empty.Text = "Nothing found for this game."
                local nPasses, nProducts = passes and #passes or 0, products and #products or 0
                if not passes and not products then
                        toast("Couldn't fetch passes or products", col.red)
                elseif not passes then
                        toast(("Found %d products, gamepass fetch failed"):format(nProducts), col.yellow)
                elseif not products then
                        toast(("Found %d gamepasses, product fetch failed"):format(nPasses), col.yellow)
                else
                        toast(("Found %d gamepasses, %d products"):format(nPasses, nProducts), col.green)
                end
                scanning = false
        end)
end

-- logger

emptyLabels[ProductLogger].Text = "Waiting for purchase prompts..."

local logLimit = 100
local logOrder = 0
local logRows = {}
local lastPrompt = {}
local pendingRows = {}

local function iconFor(kind, id, info)
        local n = tonumber(id)
        if n and kind == "Gamepass" then
                return ("rbxthumb://type=GamePass&id=%d&w=150&h=150"):format(n)
        elseif n and kind == "Asset" then
                return ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(n)
        elseif n and kind == "Bundle" then
                return ("rbxthumb://type=BundleThumbnail&id=%d&w=150&h=150"):format(n)
        end
        local iconId = info and info.IconImageAssetId
        if iconId and iconId ~= 0 then
                return "rbxassetid://" .. iconId
        end
end

local function addLog(data)
        logOrder -= 1
        knownKinds[tostring(data.id)] = data.kind
        local sub = {data.kind}
        if data.price then
                table.insert(sub, "R$" .. commas(data.price))
        end
        table.insert(sub, os.date("%H:%M:%S"))

        local row = makeRow(ProductLogger, {
                title = data.name or tostring(data.id),
                sub = table.concat(sub, "  •  "),
                icon = data.icon,
                order = logOrder,
                onClick = function()
                        sendToFaker(data.id)
                end,
        }, img.copy, function()
                copyId(data.id)
        end)

        table.insert(logRows, row)
        if #logRows > logLimit then
                table.remove(logRows, 1):Destroy()
        end
        return row
end

local function logPrompt(kind, id)
        if destroyed or id == nil then
                return
        end
        local key = kind .. ":" .. tostring(id)
        local now = os.clock()
        if lastPrompt[key] and now - lastPrompt[key] < 0.5 then
                return
        end
        lastPrompt[key] = now

        task.spawn(function()
                local info = getInfo(kind, id)
                if destroyed then
                        return
                end
                pendingRows[key] = addLog({
                        id = id,
                        kind = kind,
                        name = info and (info.Name or info.DisplayName),
                        price = info and (info.PriceInRobux or info.Price),
                        icon = iconFor(kind, id, info),
                })
                if not ProductLogger.Visible then
                        toast(("Logged %s %s"):format(kind:lower(), tostring(id)))
                end
        end)
end

local function markFinished(kind, id, purchased)
        local key = kind .. ":" .. tostring(id)
        local row = pendingRows[key]
        pendingRows[key] = nil
        local sub = row and row.Parent and row:FindFirstChild("Sub")
        if sub then
                sub.Text = sub.Text .. "  •  " .. (purchased and "Bought" or "Closed")
                tween(sub, 0.3, {TextColor3 = purchased and col.green or col.dim})
        end
end

local function firstId(...)
        for i = 1, select("#", ...) do
                local v = select(i, ...)
                if type(v) == "number" or (type(v) == "string" and v ~= "") then
                        return v
                end
        end
end

local function lastBool(...)
        for i = select("#", ...), 1, -1 do
                local v = select(i, ...)
                if type(v) == "boolean" then
                        return v
                end
        end
        return false
end

local promptKinds = {
        ProductPurchase = "Product",
        GamePassPurchase = "Gamepass",
        Purchase = "Asset",
        BundlePurchase = "Bundle",
        SubscriptionPurchase = "Subscription",
}

-- own logger handlers, so the finder's getconnections probe can skip them
local ownPromptFns = {}

local hooked = 0
for suffix, kind in pairs(promptKinds) do
        -- first arg is the player (or userId on product finished), skip it
        local onRequest = function(_, ...)
                logPrompt(kind, firstId(...))
        end
        local onFinish = function(_, ...)
                markFinished(kind, firstId(...), lastBool(...))
        end
        ownPromptFns[onRequest] = true
        ownPromptFns[onFinish] = true
        local ok = pcall(function()
                bind(MarketplaceService["Prompt" .. suffix .. "Requested"], onRequest)
        end)
        if ok then
                hooked += 1
        end
        pcall(function()
                bind(MarketplaceService["Prompt" .. suffix .. "Finished"], onFinish)
        end)
end

if hooked == 0 and typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
        local old
        local function handler(self, ...)
                local method = getnamecallmethod()
                if not destroyed and self == MarketplaceService and method:sub(1, 6) == "Prompt" then
                        local kind = promptKinds[method:sub(7)]
                        if kind then
                                task.spawn(logPrompt, kind, select(2, ...))
                        end
                end
                return old(self, ...)
        end
        pcall(function()
                old = hookmetamethod(game, "__namecall", typeof(newcclosure) == "function" and newcclosure(handler) or handler)
        end)
end

-- game finder: auto-detects whether the current game is fakeable, remembers
-- every checked game, and can hunt through small games to find supported ones

local function getFromHosts(path, hosts)
        for _, host in ipairs(hosts) do
                local d = getJson("https://" .. host .. path)
                if type(d) == "table" then
                        return d
                end
        end
end

local universeCache = {}
local function getUniverseId(placeId)
        if placeId == game.PlaceId and game.GameId ~= 0 then
                return game.GameId
        end
        if universeCache[placeId] then
                return universeCache[placeId]
        end
        local d = getFromHosts("/universes/v1/places/" .. placeId .. "/universe", {"apis.roblox.com", "apis.roproxy.com"})
        local id = d and tonumber(d.universeId)
        universeCache[placeId] = id
        return id
end

local function getGameStats(universeIds)
        local out = {}
        for i = 1, #universeIds, 50 do
                local chunk = table.concat(universeIds, ",", i, math.min(i + 49, #universeIds))
                local d = getFromHosts("/v1/games?universeIds=" .. chunk, {"games.roblox.com", "games.roproxy.com"})
                if d and type(d.data) == "table" then
                        for _, g in ipairs(d.data) do
                                out[tonumber(g.id)] = g
                        end
                end
        end
        return out
end

local loadingSupported = false

local Finder = {
        db = {},
        ui = {},
        built = false,
        checking = false,
        huntFetching = false,
        current = {placeId = game.PlaceId, state = "pending", evidence = nil, name = nil},
        hunt = {on = false, queue = {}, idx = 0, hops = 0, found = 0, maxHops = 15, fails = 0, lastHop = 0},
        canFiles = typeof(writefile) == "function" and typeof(readfile) == "function",
        dbPath = "productfaker/found-games.json",
        huntPath = "productfaker/hunt-state.json",
        verdictMeta = {
                pending = {col.dim, "AUTO-CHECK SOON"},
                checking = {col.blue, "CHECKING THIS GAME..."},
                supported = {col.green, "SUPPORTED"},
                possible = {col.yellow, "POSSIBLY SUPPORTED"},
                ["not-supported"] = {col.red, "NOT SUPPORTED"},
                ["no-monetization"] = {col.dim, "NO PASSES / PRODUCTS"},
                unknown = {col.dim, "UNKNOWN"},
        },
        finishedSignals = {
                "PromptProductPurchaseFinished",
                "PromptGamePassPurchaseFinished",
                "PromptPurchaseFinished",
                "PromptBundlePurchaseFinished",
                "PromptSubscriptionPurchaseFinished",
        },
}

-- ---------- persistence ----------

function Finder.readJson(path)
        local ok, s = pcall(readfile, path)
        if not ok or type(s) ~= "string" or s == "" then
                return nil
        end
        local okD, data = pcall(HttpService.JSONDecode, HttpService, s)
        if okD and type(data) == "table" then
                return data
        end
        return nil
end

function Finder.saveJson(path, t)
        if not Finder.canFiles then
                return
        end
        if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
                if not pcall(isfolder, "productfaker") then
                        pcall(makefolder, "productfaker")
                end
        end
        local ok, s = pcall(HttpService.JSONEncode, HttpService, t)
        if ok then
                pcall(writefile, path, s)
        end
end

function Finder.saveDb()
        local keys = {}
        for k in pairs(Finder.db) do
                table.insert(keys, k)
        end
        while #keys > 300 do
                -- evict lowest-value oldest entries first
                local worst, worstScore = nil, nil
                for _, k in ipairs(keys) do
                        local e = Finder.db[k]
                        local rank = (e.verdict == "supported" and 3) or (e.verdict == "possible" and 2) or 1
                        local score = rank * 1e11 + (e.when or 0)
                        if not worstScore or score < worstScore then
                                worst, worstScore = k, score
                        end
                end
                Finder.db[worst] = nil
                for i, k in ipairs(keys) do
                        if k == worst then
                                table.remove(keys, i)
                                break
                        end
                end
        end
        Finder.saveJson(Finder.dbPath, Finder.db)
end

function Finder.saveHunt()
        Finder.saveJson(Finder.huntPath, Finder.hunt)
end

if Finder.canFiles then
        local db = Finder.readJson(Finder.dbPath)
        if type(db) == "table" then
                Finder.db = db
        end
        local h = Finder.readJson(Finder.huntPath)
        if type(h) == "table" and type(h.queue) == "table" then
                for k, v in pairs(h) do
                        Finder.hunt[k] = v
                end
        end
end

do
        local h = Finder.hunt
        if type(h.queue) ~= "table" then
                h.queue = {}
        end
        if type(h.on) ~= "boolean" then
                h.on = false
        end
        for _, k in ipairs({"idx", "hops", "found", "maxHops", "fails", "lastHop"}) do
                if type(h[k]) ~= "number" then
                        h[k] = 0
                end
        end
        if h.maxHops < 1 then
                h.maxHops = 15
        end
end

-- ---------- shared helpers ----------

function Finder.trim(s)
        if type(s) ~= "string" or s == "" then
                return nil
        end
        if #s <= 52 then
                return s
        end
        return s:sub(1, 50) .. "..."
end

-- ---------- detection ----------

-- probe A: are any non-roblox scripts listening to the purchase signals?
-- a client-side listener is the exact thing this script exploits
function Finder.countHandlers()
        if typeof(getconnections) ~= "function" then
                return nil
        end
        local total = 0
        local labels, seen = {}, {}
        for _, sigName in ipairs(Finder.finishedSignals) do
                local okSig, sig = pcall(function()
                        return MarketplaceService[sigName]
                end)
                if okSig and sig then
                        local okC, conns = pcall(getconnections, sig)
                        if okC and type(conns) == "table" then
                                for _, cn in ipairs(conns) do
                                        local fn
                                        pcall(function()
                                                fn = cn.Function
                                        end)
                                        if fn == nil then
                                                pcall(function()
                                                        fn = cn["function"]
                                                end)
                                        end
                                        if fn ~= nil and not ownPromptFns[fn] then
                                                local src = ""
                                                pcall(function()
                                                        src = tostring((debug.getinfo(fn, "S") or {}).short_src or "")
                                                end)
                                                if not src:find("CoreGui", 1, true) and not src:find("CorePackages", 1, true) and not src:find("CoreScripts", 1, true) then
                                                        total += 1
                                                        local label = src ~= "" and src or sigName
                                                        if not seen[label] then
                                                                seen[label] = true
                                                                table.insert(labels, label)
                                                        end
                                                end
                                        end
                                end
                        end
                end
        end
        return {count = total, labels = labels}
end

-- probe B: fire every pass/product the game has and watch what changes
function Finder.snapNow()
        local s = {tools = {}, gear = {}, gui = {}, stats = {}}
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
                for _, c in ipairs(bp:GetChildren()) do
                        s.tools[c.Name] = true
                end
        end
        local char = LocalPlayer.Character
        if char then
                for _, c in ipairs(char:GetChildren()) do
                        if c:IsA("Tool") then
                                s.tools[c.Name] = true
                        end
                end
        end
        local sg = LocalPlayer:FindFirstChildOfClass("StarterGear")
        if sg then
                for _, c in ipairs(sg:GetChildren()) do
                        s.gear[c.Name] = true
                        s.tools[c.Name] = true
                end
        end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
                for _, c in ipairs(pg:GetChildren()) do
                        if c.Name ~= ScreenGui.Name then
                                s.gui[c.Name] = true
                        end
                end
        end
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
                for _, c in ipairs(ls:GetChildren()) do
                        if c:IsA("ValueBase") then
                                local v = c.Value
                                if type(v) == "number" then
                                        s.stats[c.Name] = v
                                end
                        end
                end
        end
        return s
end

function Finder.collectEvidence(before, after, seen, guiFirstSeen, strong, possible, now)
        for name in pairs(after.tools) do
                if not before.tools[name] and not seen.tool[name] then
                        seen.tool[name] = true
                        table.insert(strong, "granted tool: " .. name)
                end
        end
        for name in pairs(after.gear) do
                if not before.gear[name] and not seen.gear[name] then
                        seen.gear[name] = true
                        table.insert(strong, "granted gear: " .. name)
                end
        end
        for name in pairs(after.gui) do
                if not before.gui[name] then
                        if not guiFirstSeen[name] then
                                guiFirstSeen[name] = now
                        elseif now - guiFirstSeen[name] >= 1.1 and not seen.gui[name] then
                                seen.gui[name] = true
                                table.insert(strong, "new ui: " .. name)
                        end
                end
        end
        for k, v in pairs(after.stats) do
                local b = before.stats[k]
                if b ~= nil and v ~= b and not seen.stat[k] then
                        seen.stat[k] = true
                        table.insert(possible, k .. " " .. commas(b) .. " to " .. commas(v))
                end
        end
end

function Finder.finish(state, evidence)
        Finder.checking = false
        Finder.current.state = state
        Finder.current.evidence = evidence
        Finder.db[tostring(game.PlaceId)] = {
                placeId = game.PlaceId,
                universeId = game.GameId ~= 0 and game.GameId or nil,
                name = Finder.current.name,
                verdict = state,
                evidence = evidence,
                when = os.time(),
                playing = #Players:GetPlayers(),
        }
        Finder.saveDb()
        if Finder.hunt.on and (state == "supported" or state == "possible") then
                Finder.hunt.found += 1
        end
        Finder.updateCurrentRow()
        if Finder.built and not loadingSupported then
                loadSupported()
        end
        if state == "supported" then
                toast("THIS GAME IS SUPPORTED", col.green)
        elseif state == "possible" then
                toast("This game might be supported", col.yellow)
        end
        Finder.afterCheck()
end

function Finder.autoCheck()
        if Finder.checking or destroyed then
                if Finder.checking then
                        toast("Already checking this game", col.yellow)
                end
                return
        end
        Finder.checking = true
        Finder.current = {placeId = game.PlaceId, state = "checking", evidence = nil, name = Finder.current.name}
        Finder.updateCurrentRow()

        task.spawn(function()
                -- resolve current game name in the background
                task.spawn(function()
                        local ok, stats = pcall(getGameStats, {game.GameId})
                        local g = ok and type(stats) == "table" and stats[game.GameId]
                        if g and g.name then
                                Finder.current.name = g.name
                                Finder.updateCurrentRow()
                        end
                end)

                local handlers = Finder.countHandlers()

                local passes, products
                task.spawn(function()
                        passes = fetchGamepasses(game.GameId) or false
                end)
                task.spawn(function()
                        products = fetchProducts() or false
                end)
                local t0 = os.clock()
                while (passes == nil or products == nil) and os.clock() - t0 < 20 and not destroyed do
                        task.wait(0.1)
                end
                if passes == nil then
                        passes = false
                end
                if products == nil then
                        products = false
                end
                if destroyed then
                        Finder.checking = false
                        return
                end

                local ids = {}
                if type(passes) == "table" then
                        for _, p in ipairs(passes) do
                                if p.id then
                                        table.insert(ids, {id = p.id, kind = "Gamepass"})
                                end
                        end
                end
                if type(products) == "table" then
                        for _, p in ipairs(products) do
                                if p.id then
                                        table.insert(ids, {id = p.id, kind = "Product"})
                                end
                        end
                end

                if #ids == 0 then
                        local fetched = type(passes) == "table" or type(products) == "table"
                        if handlers and handlers.count > 0 then
                                Finder.finish("possible", handlers.count .. " client handler(s) but no passes to fake")
                        elseif fetched then
                                Finder.finish("no-monetization", "no gamepasses or products found")
                        else
                                Finder.finish("unknown", "couldn't scan this game")
                        end
                        return
                end

                -- fire every pass/product and watch what the game grants
                local cap = math.min(#ids, 80)
                local before = Finder.snapNow()
                local strong, possible = {}, {}
                local seen = {tool = {}, gear = {}, gui = {}, stat = {}}
                local guiFirstSeen = {}

                task.spawn(function()
                        for i = 1, cap do
                                if destroyed then
                                        return
                                end
                                local item = ids[i]
                                local fn = fire[item.kind]
                                if fn then
                                        pcall(fn, item.id)
                                end
                                task.wait(0.12)
                        end
                end)

                local deadline = os.clock() + 0.5 + cap * 0.12 + 7
                local lastPoll = os.clock()
                while os.clock() < deadline and not destroyed do
                        task.wait(0.15)
                        if os.clock() - lastPoll >= 1.2 then
                                lastPoll = os.clock()
                                Finder.collectEvidence(before, Finder.snapNow(), seen, guiFirstSeen, strong, possible, os.clock())
                        end
                end
                if destroyed then
                        Finder.checking = false
                        return
                end

                if #strong > 6 then
                        local extra = #strong - 6
                        for i = #strong, 7, -1 do
                                table.remove(strong)
                        end
                        table.insert(strong, "+" .. extra .. " more")
                end
                if #possible > 4 then
                        local extra = #possible - 4
                        for i = #possible, 5, -1 do
                                table.remove(possible)
                        end
                        table.insert(possible, "+" .. extra .. " more")
                end

                local parts = {}
                if handlers and handlers.count > 0 then
                        table.insert(parts, handlers.count .. " client handler(s)")
                end
                for _, e in ipairs(strong) do
                        table.insert(parts, e)
                end
                for _, e in ipairs(possible) do
                        table.insert(parts, e)
                end
                local evidence = table.concat(parts, ", ")
                if evidence == "" then
                        evidence = "fired " .. cap .. " passes, nothing granted"
                end

                if #strong > 0 then
                        Finder.finish("supported", evidence)
                elseif (handlers and handlers.count > 0) or #possible > 0 then
                        Finder.finish("possible", evidence)
                else
                        Finder.finish("not-supported", evidence)
                end
        end)
end

-- ---------- auto-hunt ----------

function Finder.huntText()
        if Finder.huntFetching then
                return "Fetching candidate games..."
        end
        local h = Finder.hunt
        if not h.on then
                return "OFF  •  hops through small games to find supported ones"
        end
        return ("ON  •  hop %d/%d  •  %d found  •  %d queued"):format(h.hops, h.maxHops, h.found, math.max(#h.queue - h.idx, 0))
end

function Finder.refreshHuntRow()
        local row = Finder.ui.huntRow
        if row and row.Parent then
                row.Sub.Text = Finder.huntText()
                row.Sub.TextColor3 = Finder.hunt.on and col.green or col.icon
        end
end

function Finder.fetchCandidates()
        local out, seen = {}, {}
        local hosts = {"games.roblox.com", "games.roproxy.com"}
        for _, host in ipairs(hosts) do
                local cursor, param, pages = nil, "pageToken", 0
                while pages < 8 and #out < 250 and not destroyed do
                        local url = ("https://%s/v1/games/list?model.sortToken=Default&pageSize=100&sessionId=%s"):format(host, HttpService:GenerateGUID(false))
                        if cursor then
                                url = url .. "&" .. param .. "=" .. HttpService:UrlEncode(cursor)
                        end
                        local d = getJson(url)
                        local list = (d and type(d.data) == "table" and #d.data > 0) and d.data or nil
                        if list then
                                pages += 1
                                for _, g in ipairs(list) do
                                        local pid, playing = tonumber(g.id), tonumber(g.playerCount)
                                        if pid and playing and playing >= 1 and playing <= 100 and not seen[pid] then
                                                seen[pid] = true
                                                if not Finder.db[tostring(pid)] then
                                                        table.insert(out, pid)
                                                end
                                        end
                                end
                                local nextCursor = d.nextPageCursor or d.nextPageToken
                                if not nextCursor then
                                        break
                                end
                                cursor = nextCursor
                        elseif cursor and param == "pageToken" then
                                -- other pagination param name, retry same page
                                param = "cursor"
                        else
                                break
                        end
                        task.wait(0.2)
                end
                if #out >= 25 or destroyed then
                        break
                end
        end
        for i = #out, 2, -1 do
                local j = math.random(i)
                out[i], out[j] = out[j], out[i]
        end
        return out
end

function Finder.startHunt()
        Finder.huntFetching = true
        Finder.refreshHuntRow()
        toast("Hunt: fetching candidate games...")
        task.spawn(function()
                local queue = Finder.fetchCandidates()
                Finder.huntFetching = false
                if destroyed then
                        return
                end
                if not queue or #queue == 0 then
                        toast("Hunt: no candidate games found", col.red)
                        Finder.refreshHuntRow()
                        return
                end
                local h = Finder.hunt
                h.on = true
                h.queue = queue
                h.idx = 0
                h.hops = 0
                h.found = 0
                h.fails = 0
                h.lastHop = os.time()
                Finder.hopping = false
                Finder.saveHunt()
                toast(("Hunt on: %d candidates queued"):format(#queue), col.green)
                Finder.refreshHuntRow()
                task.delay(1.5, Finder.hopNext)
        end)
end

function Finder.stopHunt(reason)
        Finder.hunt.on = false
        Finder.hopping = false
        Finder.saveHunt()
        if reason then
                toast("Hunt " .. reason, col.yellow)
        end
        Finder.refreshHuntRow()
end

function Finder.toggleHunt()
        if Finder.huntFetching then
                return
        end
        if Finder.hunt.on then
                Finder.stopHunt("stopped")
        else
                Finder.startHunt()
        end
end

function Finder.hopNext()
        local h = Finder.hunt
        if not h.on or destroyed or Finder.hopping then
                return
        end
        if h.hops >= h.maxHops then
                Finder.stopHunt(("finished: %d of %d games supported"):format(h.found, h.hops))
                return
        end
        if h.fails >= 5 then
                Finder.stopHunt("stopped: teleports keep failing")
                return
        end
        local place
        while h.idx < #h.queue do
                h.idx += 1
                local pid = h.queue[h.idx]
                if pid and pid ~= game.PlaceId and not Finder.db[tostring(pid)] then
                        place = pid
                        break
                end
        end
        if not place then
                Finder.stopHunt(("finished: %d of %d games supported"):format(h.found, h.hops))
                return
        end
        h.hops += 1
        h.lastHop = os.time()
        Finder.saveHunt()
        Finder.refreshHuntRow()
        toast(("Hunt: joining game %d of %d"):format(h.hops, h.maxHops))
        Finder.hopping = true
        local ok = pcall(TeleportService.Teleport, TeleportService, place, LocalPlayer)
        if not ok then
                Finder.hopping = false
                h.fails += 1
                task.delay(3, Finder.hopNext)
        end
end

-- roblox reports failed teleports through this signal instead of errors;
-- without it the hunt would stall whenever a hop target is full or blocked
pcall(function()
        bind(TeleportService.TeleportInitFailed, function()
                if Finder.hunt.on and Finder.hopping then
                        Finder.hopping = false
                        Finder.hunt.fails += 1
                        task.delay(3, Finder.hopNext)
                end
        end)
end)

function Finder.afterCheck()
        if Finder.hunt.on and not destroyed then
                task.delay(2, Finder.hopNext)
        end
end

-- continue a hunt after a teleport once this script re-executes
function Finder.resumeHunt()
        local h = Finder.hunt
        if not h.on then
                return
        end
        if os.time() - (h.lastHop or 0) > 180 then
                h.on = false
                Finder.saveHunt()
                toast("Hunt expired", col.yellow)
                return
        end
        toast(("Hunt: resuming, hop %d/%d, %d found"):format(h.hops, h.maxHops, h.found), col.blue)
end

-- ---------- supported tab ui ----------

function Finder.verdictText()
        local m = Finder.verdictMeta[Finder.current.state] or Finder.verdictMeta.unknown
        local parts = {m[2]}
        local ev = Finder.trim(Finder.current.evidence)
        if ev then
                table.insert(parts, ev)
        end
        return table.concat(parts, "  •  ")
end

function Finder.updateCurrentRow()
        local row = Finder.ui.currentRow
        if not row or not row.Parent then
                return
        end
        if Finder.current.name and row.Title.Text ~= Finder.current.name then
                row.Title.Text = Finder.current.name
        end
        local m = Finder.verdictMeta[Finder.current.state] or Finder.verdictMeta.unknown
        row.Sub.Text = Finder.verdictText()
        row.Sub.TextColor3 = m[1]
end

function Finder.entrySub(e)
        local m = Finder.verdictMeta[e.verdict] or Finder.verdictMeta.unknown
        local parts = {m[2]}
        local ev = Finder.trim(e.evidence)
        if ev then
                table.insert(parts, ev)
        end
        if e.playing then
                table.insert(parts, commas(e.playing) .. " playing")
        end
        if e.when then
                table.insert(parts, os.date("%m/%d %H:%M", e.when))
        end
        return table.concat(parts, "  •  ")
end

function Finder.sortedDb()
        local rank = {supported = 0, possible = 1, ["not-supported"] = 2, ["no-monetization"] = 3, unknown = 4}
        local entries = {}
        for _, e in pairs(Finder.db) do
                if type(e) == "table" and e.placeId then
                        table.insert(entries, e)
                end
        end
        table.sort(entries, function(a, b)
                local ra, rb = rank[a.verdict] or 5, rank[b.verdict] or 5
                if ra ~= rb then
                        return ra < rb
                end
                return (a.when or 0) > (b.when or 0)
        end)
        while #entries > 100 do
                table.remove(entries)
        end
        return entries
end

loadSupported = function()
        if loadingSupported or destroyed then
                return
        end
        loadingSupported = true

        local empty = emptyLabels[SupportedContainer]
        clearList(SupportedContainer)
        empty.Text = "Building your found-games list..."
        Finder.ui = {}

        task.spawn(function()
                -- current game + verdict
                Finder.ui.currentRow = makeRow(SupportedContainer, {
                        title = Finder.current.name or "This game",
                        sub = Finder.verdictText(),
                        icon = ("rbxthumb://type=GameIcon&id=%d&w=150&h=150"):format(game.PlaceId),
                        order = -3,
                        onClick = function()
                                copyId(game.PlaceId)
                        end,
                }, img.supported, function()
                        toast("Re-checking this game...")
                        Finder.autoCheck()
                end)
                Finder.updateCurrentRow()

                -- hunt toggle
                Finder.ui.huntRow = makeRow(SupportedContainer, {
                        title = "Auto-Hunt",
                        sub = Finder.huntText(),
                        icon = img.join,
                        order = -2,
                }, img.join, function()
                        Finder.toggleHunt()
                end)
                Finder.refreshHuntRow()

                -- every game found so far
                local entries = Finder.sortedDb()
                for i, e in ipairs(entries) do
                        local here = e.placeId == game.PlaceId
                        e.row = makeRow(SupportedContainer, {
                                title = e.name or ("Place " .. tostring(e.placeId)),
                                sub = Finder.entrySub(e),
                                icon = ("rbxthumb://type=GameIcon&id=%d&w=150&h=150"):format(e.placeId),
                                order = i,
                                onClick = function()
                                        copyId(e.placeId)
                                end,
                        }, img.join, function()
                                if here then
                                        toast("You're already in this game", col.yellow)
                                else
                                        toast("Teleporting...")
                                        pcall(TeleportService.Teleport, TeleportService, e.placeId, LocalPlayer)
                                end
                        end)
                        if here then
                                e.row.Sub.TextColor3 = col.green
                        end
                end

                empty.Text = "Every game you join gets auto-checked. Found games are saved."
                Finder.built = true

                -- resolve names + live player counts
                local tEnrich = os.clock()
                local pending = #entries
                for _, e in ipairs(entries) do
                        task.spawn(function()
                                if not e.universeId then
                                        local okId, uid = pcall(getUniverseId, e.placeId)
                                        if okId then
                                                e.universeId = uid
                                        end
                                end
                                pending -= 1
                        end)
                end
                while pending > 0 and not destroyed and os.clock() - tEnrich < 15 do
                        task.wait()
                end
                if destroyed then
                        loadingSupported = false
                        return
                end
                local ids, seenIds = {}, {}
                for _, e in ipairs(entries) do
                        if e.universeId and not seenIds[e.universeId] then
                                seenIds[e.universeId] = true
                                table.insert(ids, e.universeId)
                        end
                end
                local stats = #ids > 0 and getGameStats(ids) or {}
                if destroyed then
                        loadingSupported = false
                        return
                end
                for _, e in ipairs(entries) do
                        local row = e.row
                        if row and row.Parent then
                                local g = e.universeId and stats[e.universeId]
                                if g then
                                        if g.playing then
                                                e.playing = g.playing
                                        end
                                        if g.name and not e.name then
                                                e.name = g.name
                                                row.Title.Text = g.name
                                        end
                                        row.Sub.Text = Finder.entrySub(e)
                                end
                        end
                end
                loadingSupported = false
        end)
end

setTab(1, true)
env.__ProductFaker = UI
open()
scanProducts()
loadSupported()
Finder.resumeHunt()
task.delay(7, Finder.autoCheck)
