--!nocheck
--[[
	Endma Hub — Minimalist Roblox UI Library
	Version: 1.0.0
	License: MIT

	This library provides UI and callback infrastructure only.
	It does not include gameplay bypasses or authoritative game actions.
]]

local VERSION = "1.0.0"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--// Runtime compatibility

local function getEnvironment()
	if type(getgenv) == "function" then
		local ok, environment = pcall(getgenv)
		if ok and type(environment) == "table" then
			return environment
		end
	end

	return _G
end

local Environment = getEnvironment()

local function getGlobal(name)
	local value

	pcall(function()
		value = Environment[name]
	end)

	return value
end

local Synapse = getGlobal("syn")

local Runtime = {
	GetHiddenUI = getGlobal("gethui"),
	ProtectGui = getGlobal("protect_gui")
		or (type(Synapse) == "table" and Synapse.protect_gui),

	IsFile = getGlobal("isfile"),
	IsFolder = getGlobal("isfolder"),
	MakeFolder = getGlobal("makefolder"),
	ReadFile = getGlobal("readfile"),
	WriteFile = getGlobal("writefile"),
}

local function getGuiParent()
	if type(Runtime.GetHiddenUI) == "function" then
		local ok, hiddenUI = pcall(Runtime.GetHiddenUI)

		if ok and hiddenUI then
			return hiddenUI
		end
	end

	if LocalPlayer then
		return LocalPlayer:WaitForChild("PlayerGui")
	end

	return CoreGui
end

--// Utilities

local function create(className, properties)
	local instance = Instance.new(className)

	for property, value in pairs(properties or {}) do
		instance[property] = value
	end

	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 7),
		Parent = parent,
	})
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

local function addPadding(parent, top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		Parent = parent,
	})
end

local function addList(parent, gap, horizontal)
	return create("UIListLayout", {
		FillDirection = horizontal
			and Enum.FillDirection.Horizontal
			or Enum.FillDirection.Vertical,

		HorizontalAlignment = horizontal
			and Enum.HorizontalAlignment.Left
			or Enum.HorizontalAlignment.Center,

		VerticalAlignment = horizontal
			and Enum.VerticalAlignment.Center
			or Enum.VerticalAlignment.Top,

		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function roundTo(value, increment)
	increment = tonumber(increment) or 1

	if increment <= 0 then
		return value
	end

	local rounded = math.floor((value / increment) + 0.5) * increment
	local decimalPart = tostring(increment):match("%.(%d+)")

	if decimalPart then
		local multiplier = 10 ^ #decimalPart
		rounded = math.floor(rounded * multiplier + 0.5) / multiplier
	end

	return rounded
end

local function merge(base, overlay)
	local result = {}

	for key, value in pairs(base or {}) do
		result[key] = value
	end

	for key, value in pairs(overlay or {}) do
		result[key] = value
	end

	return result
end

local function normalizeConfig(config, defaultName)
	if type(config) == "string" then
		return {
			Name = config,
		}
	end

	config = config or {}

	if config.Name == nil and config.Text == nil and defaultName then
		config.Name = defaultName
	end

	return config
end

local function sanitizeName(value)
	local result = tostring(value or "default"):gsub("[^%w_%-]", "_")

	if result == "" then
		return "default"
	end

	return result
end

local function copyArray(array)
	local result = {}

	for index, value in ipairs(array or {}) do
		result[index] = value
	end

	return result
end

local function contains(array, value)
	return table.find(array, value) ~= nil
end

local function colorToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function hexToColor(hex)
	if type(hex) ~= "string" then
		return nil
	end

	hex = hex:gsub("#", "")

	if #hex == 3 then
		hex = hex:sub(1, 1):rep(2)
			.. hex:sub(2, 2):rep(2)
			.. hex:sub(3, 3):rep(2)
	end

	if #hex ~= 6 or not hex:match("^%x+$") then
		return nil
	end

	return Color3.fromRGB(
		tonumber(hex:sub(1, 2), 16),
		tonumber(hex:sub(3, 4), 16),
		tonumber(hex:sub(5, 6), 16)
	)
end

local function serializeValue(value, visited)
	local valueType = typeof(value)

	if valueType == "Color3" then
		return {
			__endmaType = "Color3",
			R = value.R,
			G = value.G,
			B = value.B,
		}
	end

	if valueType == "EnumItem" then
		return {
			__endmaType = "EnumItem",
			EnumType = tostring(value.EnumType),
			Name = value.Name,
		}
	end

	if type(value) == "table" then
		visited = visited or {}

		if visited[value] then
			return nil
		end

		visited[value] = true

		local result = {}

		for key, nestedValue in pairs(value) do
			if type(key) == "string" or type(key) == "number" then
				result[key] = serializeValue(nestedValue, visited)
			end
		end

		visited[value] = nil

		return result
	end

	if type(value) == "string"
		or type(value) == "number"
		or type(value) == "boolean"
	then
		return value
	end

	return nil
end

local function deserializeValue(value)
	if type(value) ~= "table" then
		return value
	end

	if value.__endmaType == "Color3" then
		return Color3.new(
			tonumber(value.R) or 0,
			tonumber(value.G) or 0,
			tonumber(value.B) or 0
		)
	end

	if value.__endmaType == "EnumItem"
		and value.EnumType == "Enum.KeyCode"
	then
		return Enum.KeyCode[value.Name]
	end

	local result = {}

	for key, nestedValue in pairs(value) do
		result[key] = deserializeValue(nestedValue)
	end

	return result
end

local function makeText(properties)
	return create("TextLabel", merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, properties))
end

local function makeButton(properties)
	return create("TextButton", merge({
		AutoButtonColor = false,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
	}, properties))
end

local function newMaid()
	local maid = {
		Connections = {},
		Tweens = {},
		Instances = {},
		Cleaned = false,
	}

	function maid:GiveConnection(connection)
		if connection then
			table.insert(self.Connections, connection)
		end

		return connection
	end

	function maid:GiveTween(tween)
		if tween then
			table.insert(self.Tweens, tween)
		end

		return tween
	end

	function maid:GiveInstance(instance)
		if instance then
			table.insert(self.Instances, instance)
		end

		return instance
	end

	function maid:Cleanup()
		if self.Cleaned then
			return
		end

		self.Cleaned = true

		for _, connection in ipairs(self.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		for _, tween in ipairs(self.Tweens) do
			pcall(function()
				tween:Cancel()
			end)
		end

		for index = #self.Instances, 1, -1 do
			pcall(function()
				self.Instances[index]:Destroy()
			end)
		end

		table.clear(self.Connections)
		table.clear(self.Tweens)
		table.clear(self.Instances)
	end

	return maid
end

--// Themes

local Themes = {
	Carbon = {
		Ink = Color3.fromRGB(8, 8, 11),
		Background = Color3.fromRGB(13, 13, 17),
		Surface = Color3.fromRGB(20, 20, 26),
		Surface2 = Color3.fromRGB(27, 27, 35),
		SurfaceHover = Color3.fromRGB(34, 34, 44),
		Stroke = Color3.fromRGB(50, 50, 62),
		Text = Color3.fromRGB(242, 242, 247),
		Muted = Color3.fromRGB(151, 151, 166),
		Accent = Color3.fromRGB(139, 92, 246),
		Success = Color3.fromRGB(82, 196, 126),
		Warning = Color3.fromRGB(221, 165, 72),
		Danger = Color3.fromRGB(224, 82, 101),
	},

	Monochrome = {
		Ink = Color3.fromRGB(5, 5, 5),
		Background = Color3.fromRGB(12, 12, 12),
		Surface = Color3.fromRGB(21, 21, 21),
		Surface2 = Color3.fromRGB(30, 30, 30),
		SurfaceHover = Color3.fromRGB(40, 40, 40),
		Stroke = Color3.fromRGB(57, 57, 57),
		Text = Color3.fromRGB(245, 245, 245),
		Muted = Color3.fromRGB(157, 157, 157),
		Accent = Color3.fromRGB(235, 235, 235),
		Success = Color3.fromRGB(105, 190, 126),
		Warning = Color3.fromRGB(210, 167, 89),
		Danger = Color3.fromRGB(215, 91, 100),
	},

	Slate = {
		Ink = Color3.fromRGB(8, 11, 16),
		Background = Color3.fromRGB(13, 17, 23),
		Surface = Color3.fromRGB(20, 26, 34),
		Surface2 = Color3.fromRGB(28, 35, 45),
		SurfaceHover = Color3.fromRGB(37, 46, 58),
		Stroke = Color3.fromRGB(55, 67, 82),
		Text = Color3.fromRGB(239, 243, 248),
		Muted = Color3.fromRGB(148, 160, 176),
		Accent = Color3.fromRGB(125, 145, 190),
		Success = Color3.fromRGB(83, 190, 126),
		Warning = Color3.fromRGB(218, 166, 80),
		Danger = Color3.fromRGB(220, 84, 101),
	},

	Cyan = {
		Ink = Color3.fromRGB(5, 12, 15),
		Background = Color3.fromRGB(9, 19, 23),
		Surface = Color3.fromRGB(14, 29, 34),
		Surface2 = Color3.fromRGB(20, 39, 45),
		SurfaceHover = Color3.fromRGB(27, 51, 58),
		Stroke = Color3.fromRGB(43, 73, 82),
		Text = Color3.fromRGB(238, 252, 253),
		Muted = Color3.fromRGB(143, 181, 187),
		Accent = Color3.fromRGB(34, 211, 238),
		Success = Color3.fromRGB(77, 202, 129),
		Warning = Color3.fromRGB(224, 173, 72),
		Danger = Color3.fromRGB(228, 82, 101),
	},

	Emerald = {
		Ink = Color3.fromRGB(6, 12, 10),
		Background = Color3.fromRGB(10, 19, 16),
		Surface = Color3.fromRGB(15, 29, 24),
		Surface2 = Color3.fromRGB(21, 40, 33),
		SurfaceHover = Color3.fromRGB(29, 52, 43),
		Stroke = Color3.fromRGB(46, 74, 63),
		Text = Color3.fromRGB(239, 250, 246),
		Muted = Color3.fromRGB(146, 180, 167),
		Accent = Color3.fromRGB(52, 211, 153),
		Success = Color3.fromRGB(75, 205, 127),
		Warning = Color3.fromRGB(222, 171, 73),
		Danger = Color3.fromRGB(226, 82, 101),
	},

	Crimson = {
		Ink = Color3.fromRGB(14, 6, 8),
		Background = Color3.fromRGB(23, 10, 13),
		Surface = Color3.fromRGB(34, 15, 20),
		Surface2 = Color3.fromRGB(46, 21, 27),
		SurfaceHover = Color3.fromRGB(60, 28, 35),
		Stroke = Color3.fromRGB(84, 43, 52),
		Text = Color3.fromRGB(251, 241, 244),
		Muted = Color3.fromRGB(189, 147, 157),
		Accent = Color3.fromRGB(225, 74, 101),
		Success = Color3.fromRGB(82, 194, 123),
		Warning = Color3.fromRGB(222, 167, 71),
		Danger = Color3.fromRGB(235, 72, 93),
	},

	Amber = {
		Ink = Color3.fromRGB(14, 10, 5),
		Background = Color3.fromRGB(23, 17, 9),
		Surface = Color3.fromRGB(34, 25, 13),
		Surface2 = Color3.fromRGB(46, 34, 18),
		SurfaceHover = Color3.fromRGB(59, 44, 24),
		Stroke = Color3.fromRGB(84, 64, 37),
		Text = Color3.fromRGB(252, 247, 237),
		Muted = Color3.fromRGB(191, 174, 144),
		Accent = Color3.fromRGB(235, 174, 62),
		Success = Color3.fromRGB(83, 194, 123),
		Warning = Color3.fromRGB(237, 178, 63),
		Danger = Color3.fromRGB(226, 80, 96),
	},

	Frost = {
		Ink = Color3.fromRGB(7, 11, 15),
		Background = Color3.fromRGB(12, 18, 24),
		Surface = Color3.fromRGB(18, 27, 35),
		Surface2 = Color3.fromRGB(25, 37, 47),
		SurfaceHover = Color3.fromRGB(33, 48, 61),
		Stroke = Color3.fromRGB(50, 70, 85),
		Text = Color3.fromRGB(241, 248, 252),
		Muted = Color3.fromRGB(151, 174, 189),
		Accent = Color3.fromRGB(125, 211, 252),
		Success = Color3.fromRGB(79, 196, 128),
		Warning = Color3.fromRGB(222, 170, 75),
		Danger = Color3.fromRGB(225, 82, 100),
	},
}

local RequiredThemeTokens = {
	"Ink",
	"Background",
	"Surface",
	"Surface2",
	"SurfaceHover",
	"Stroke",
	"Text",
	"Muted",
	"Accent",
	"Success",
	"Warning",
	"Danger",
}

local Library = {
	Version = VERSION,
	Themes = Themes,
	Windows = {},
	ActiveWindow = nil,
}

local function resolveTheme(theme)
	if type(theme) == "table" then
		return merge(Themes.Carbon, theme), "Custom"
	end

	local name = tostring(theme or "Carbon")

	if Library.Themes[name] then
		return Library.Themes[name], name
	end

	return Library.Themes.Carbon, "Carbon"
end

local function themeNames()
	local result = {}

	for name in pairs(Library.Themes) do
		table.insert(result, name)
	end

	table.sort(result)

	return result
end

function Library:RegisterTheme(name, values)
	assert(
		type(name) == "string" and name ~= "",
		"Endma Hub: theme name must be a non-empty string."
	)

	assert(
		type(values) == "table",
		"Endma Hub: theme values must be a table."
	)

	local theme = merge(Themes.Carbon, values)

	for _, token in ipairs(RequiredThemeTokens) do
		assert(
			typeof(theme[token]) == "Color3",
			("Endma Hub: theme token %s must be Color3."):format(token)
		)
	end

	self.Themes[name] = theme

	return theme
end

--// Window

function Library:CreateWindow(config)
	config = config or {}

	local maid = newMaid()
	local configOptions = type(config.Config) == "table" and config.Config or {}

	local configEnabled = config.SaveConfig == true
		or configOptions.Enabled == true

	local configFolder = sanitizeName(configOptions.Folder or "EndmaHub")
	local configFile = sanitizeName(
		configOptions.File or config.Title or "default"
	)

	local function configPath()
		return configFolder .. "/" .. configFile .. ".json"
	end

	local function canUseFiles()
		return type(Runtime.ReadFile) == "function"
			and type(Runtime.WriteFile) == "function"
	end

	local function readSavedData()
		if not configEnabled or not canUseFiles() then
			return nil
		end

		if type(Runtime.IsFile) == "function" then
			local checked, exists = pcall(Runtime.IsFile, configPath())

			if checked and not exists then
				return nil
			end
		end

		local readOk, contents = pcall(Runtime.ReadFile, configPath())

		if not readOk or type(contents) ~= "string" then
			return nil
		end

		local decodeOk, decoded = pcall(
			HttpService.JSONDecode,
			HttpService,
			contents
		)

		if decodeOk and type(decoded) == "table" then
			return decoded
		end

		return nil
	end

	local savedData = readSavedData()

	local requestedTheme = savedData and savedData.Theme or config.Theme
	local theme, themeName = resolveTheme(requestedTheme)

	local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

	if savedData
		and type(savedData.ToggleKey) == "string"
		and Enum.KeyCode[savedData.ToggleKey]
	then
		toggleKey = Enum.KeyCode[savedData.ToggleKey]
	end

	local window = {
		Library = self,
		Config = config,
		Theme = theme,
		ThemeName = themeName,
		ToggleKey = toggleKey,
		Scale = clamp(
			tonumber(savedData and savedData.Scale)
				or tonumber(config.Scale)
				or 1,
			0.75,
			1.25
		),

		ReducedMotion = savedData
				and savedData.ReducedMotion == true
			or config.ReducedMotion == true,

		DimBackground = savedData
				and savedData.DimBackground ~= false
			or config.DimBackground ~= false,

		Visible = true,
		Minimized = false,
		Destroyed = false,
		Flags = {},
		Tabs = {},
		Controls = {},
		ConfigEnabled = configEnabled,
		ConfigFolder = configFolder,
		ConfigFile = configFile,
		ThemeBindings = {},
		ThemeCallbacks = {},
		FlagControls = {},
		PendingFlags = deserializeValue(
			savedData and savedData.Flags or {}
		),

		Defaults = {},
		Maid = maid,
	}

	table.insert(self.Windows, window)
	self.ActiveWindow = window

	local windowId = sanitizeName(config.Id or config.Title or "EndmaHub")

	Environment.__ENDMA_HUB_WINDOWS = Environment.__ENDMA_HUB_WINDOWS or {}

	local registry = Environment.__ENDMA_HUB_WINDOWS
	local previousWindow = registry[windowId]

	if previousWindow and type(previousWindow.Destroy) == "function" then
		pcall(function()
			previousWindow:Destroy()
		end)
	end

	local guiParent = getGuiParent()
	local screenName = "EndmaHub_" .. windowId

	local oldGui = guiParent:FindFirstChild(screenName)

	if oldGui then
		oldGui:Destroy()
	end

	local screenGui = create("ScreenGui", {
		Name = screenName,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = tonumber(config.DisplayOrder) or 999999,
		Parent = guiParent,
	})

	window.ScreenGui = screenGui
	maid:GiveInstance(screenGui)

	if type(Runtime.ProtectGui) == "function" then
		pcall(Runtime.ProtectGui, screenGui)
	end

	local scrim = makeButton({
		Name = "Scrim",
		Text = "",
		BackgroundColor3 = theme.Ink,
		BackgroundTransparency = window.DimBackground and 0.56 or 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})

	local shadow = create("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 7, 0.5, 9),
		Size = config.Size or UDim2.fromOffset(760, 520),
		Parent = screenGui,
	})

	addCorner(shadow, 8)

	local main = create("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		GroupTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = config.Size or UDim2.fromOffset(760, 520),
		Parent = screenGui,
	})

	addCorner(main, 8)
	local mainStroke = addStroke(main, theme.Stroke, 2)

	local uiScale = create("UIScale", {
		Scale = window.Scale,
		Parent = main,
	})

	local topBar = create("Frame", {
		Name = "TopBar",
		Active = true,
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = main,
	})

	local topDivider = create("Frame", {
		Name = "Divider",
		BackgroundColor3 = theme.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = topBar,
	})

	local brandMark = create("Frame", {
		Name = "BrandMark",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 13),
		Size = UDim2.fromOffset(32, 32),
		Parent = topBar,
	})

	addCorner(brandMark, 7)

	local brandLetter = makeText({
		Name = "Letter",
		Font = Enum.Font.GothamBold,
		Text = "E",
		TextColor3 = theme.Background,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = brandMark,
	})

	local titleLabel = makeText({
		Name = "Title",
		Font = Enum.Font.GothamBold,
		Text = tostring(config.Title or "Endma Hub"),
		TextColor3 = theme.Text,
		TextSize = 16,
		Position = UDim2.fromOffset(60, 10),
		Size = UDim2.new(1, -205, 0, 22),
		Parent = topBar,
	})

	local subtitleLabel = makeText({
		Name = "Subtitle",
		Text = tostring(config.Subtitle or "Minimal UI Library"),
		TextColor3 = theme.Muted,
		TextSize = 11,
		Position = UDim2.fromOffset(60, 30),
		Size = UDim2.new(1, -205, 0, 17),
		Parent = topBar,
	})

	local minimizeButton = makeButton({
		Name = "Minimize",
		Text = "-",
		BackgroundColor3 = theme.Surface2,
		TextColor3 = theme.Text,
		TextSize = 16,
		Position = UDim2.new(1, -104, 0, 11),
		Size = UDim2.fromOffset(38, 36),
		Parent = topBar,
	})

	addCorner(minimizeButton, 7)
	local minimizeStroke = addStroke(
		minimizeButton,
		theme.Stroke,
		1
	)

	local closeButton = makeButton({
		Name = "Close",
		Text = "x",
		BackgroundColor3 = theme.Surface2,
		TextColor3 = theme.Danger,
		TextSize = 14,
		Position = UDim2.new(1, -56, 0, 11),
		Size = UDim2.fromOffset(38, 36),
		Parent = topBar,
	})

	addCorner(closeButton, 7)
	local closeStroke = addStroke(closeButton, theme.Stroke, 1)

	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		Parent = main,
	})

	local sidebar = create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 184, 1, 0),
		Parent = body,
	})

	local sidebarDivider = create("Frame", {
		BackgroundColor3 = theme.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})

	local searchBox = create("TextBox", {
		Name = "Search",
		BackgroundColor3 = theme.Surface2,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		PlaceholderText = "Search tabs",
		PlaceholderColor3 = theme.Muted,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 0, 40),
		Parent = sidebar,
	})

	addCorner(searchBox, 7)
	local searchStroke = addStroke(searchBox, theme.Stroke, 1)
	addPadding(searchBox, 0, 12, 0, 12)

	local tabList = create("ScrollingFrame", {
		Name = "Tabs",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = theme.Stroke,
		ScrollBarThickness = 2,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.new(1, -16, 1, -102),
		Parent = sidebar,
	})

	addList(tabList, 6)

	local footer = makeText({
		Name = "Footer",
		Font = Enum.Font.GothamMedium,
		Text = "ENDMA  /  " .. VERSION,
		TextColor3 = theme.Muted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 8, 1, -29),
		Size = UDim2.new(1, -16, 0, 18),
		Parent = sidebar,
	})

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(184, 0),
		Size = UDim2.new(1, -184, 1, 0),
		Parent = body,
	})

	local resizeHandle = makeButton({
		Name = "Resize",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = theme.Surface2,
		BackgroundTransparency = 0.05,
		Text = "",
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(22, 22),
		Visible = config.Resizable ~= false,
		ZIndex = 30,
		Parent = main,
	})

	addCorner(resizeHandle, 5)

	local resizeLineA = create("Frame", {
		BackgroundColor3 = theme.Muted,
		BorderSizePixel = 0,
		Rotation = -45,
		Position = UDim2.fromOffset(8, 12),
		Size = UDim2.fromOffset(11, 1),
		ZIndex = 31,
		Parent = resizeHandle,
	})

	local resizeLineB = create("Frame", {
		BackgroundColor3 = theme.Muted,
		BorderSizePixel = 0,
		Rotation = -45,
		Position = UDim2.fromOffset(13, 15),
		Size = UDim2.fromOffset(6, 1),
		ZIndex = 31,
		Parent = resizeHandle,
	})

	local mobileToggle = makeButton({
		Name = "MobileToggle",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = theme.Surface,
		Text = "E",
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.Accent,
		TextSize = 16,
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(48, 48),
		Visible = UserInputService.TouchEnabled,
		ZIndex = 200,
		Parent = screenGui,
	})

	addCorner(mobileToggle, 8)
	local mobileStroke = addStroke(mobileToggle, theme.Stroke, 2)

	local notificationStack = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(320, 500),
		ZIndex = 300,
		Parent = screenGui,
	})

	local notificationLayout = addList(
		notificationStack,
		8
	)

	notificationLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Right

	local modalLayer = create("Frame", {
		Name = "ModalLayer",
		BackgroundColor3 = theme.Ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 100,
		Parent = main,
	})

	window.Main = main
	window.Body = body
	window.Sidebar = sidebar
	window.Content = content
	window.MobileToggle = mobileToggle
	window.ModalLayer = modalLayer
	window.UIScale = uiScale

	--// Theme bindings

	function window:BindTheme(instance, property, token)
		instance[property] = self.Theme[token]

		table.insert(self.ThemeBindings, {
			Instance = instance,
			Property = property,
			Token = token,
		})

		return instance
	end

	function window:BindThemeCallback(callback)
		table.insert(self.ThemeCallbacks, callback)
		return callback
	end

	function window:SetTheme(nextTheme)
		local resolvedTheme, resolvedName = resolveTheme(nextTheme)

		self.Theme = resolvedTheme
		self.ThemeName = resolvedName

		for _, binding in ipairs(self.ThemeBindings) do
			local instance = binding.Instance

			if instance and instance.Parent then
				instance[binding.Property] =
					resolvedTheme[binding.Token]
			end
		end

		for _, callback in ipairs(self.ThemeCallbacks) do
			callback(resolvedTheme)
		end

		if self.SettingsThemeControl
			and self.SettingsThemeControl:Get() ~= resolvedName
		then
			self.SettingsThemeControl:Set(resolvedName, true)
		end

		return self
	end

	window:BindTheme(scrim, "BackgroundColor3", "Ink")
	window:BindTheme(shadow, "BackgroundColor3", "Ink")
	window:BindTheme(main, "BackgroundColor3", "Background")
	window:BindTheme(mainStroke, "Color", "Stroke")
	window:BindTheme(topBar, "BackgroundColor3", "Surface")
	window:BindTheme(topDivider, "BackgroundColor3", "Stroke")
	window:BindTheme(brandMark, "BackgroundColor3", "Accent")
	window:BindTheme(brandLetter, "TextColor3", "Background")
	window:BindTheme(titleLabel, "TextColor3", "Text")
	window:BindTheme(subtitleLabel, "TextColor3", "Muted")
	window:BindTheme(
		minimizeButton,
		"BackgroundColor3",
		"Surface2"
	)
	window:BindTheme(minimizeButton, "TextColor3", "Text")
	window:BindTheme(minimizeStroke, "Color", "Stroke")
	window:BindTheme(closeButton, "BackgroundColor3", "Surface2")
	window:BindTheme(closeButton, "TextColor3", "Danger")
	window:BindTheme(closeStroke, "Color", "Stroke")
	window:BindTheme(sidebar, "BackgroundColor3", "Surface")
	window:BindTheme(sidebarDivider, "BackgroundColor3", "Stroke")
	window:BindTheme(searchBox, "BackgroundColor3", "Surface2")
	window:BindTheme(searchBox, "TextColor3", "Text")
	window:BindTheme(searchBox, "PlaceholderColor3", "Muted")
	window:BindTheme(searchStroke, "Color", "Stroke")
	window:BindTheme(footer, "TextColor3", "Muted")
	window:BindTheme(resizeHandle, "BackgroundColor3", "Surface2")
	window:BindTheme(resizeLineA, "BackgroundColor3", "Muted")
	window:BindTheme(resizeLineB, "BackgroundColor3", "Muted")
	window:BindTheme(mobileToggle, "BackgroundColor3", "Surface")
	window:BindTheme(mobileToggle, "TextColor3", "Accent")
	window:BindTheme(mobileStroke, "Color", "Stroke")
	window:BindTheme(modalLayer, "BackgroundColor3", "Ink")

	window:BindThemeCallback(function(nextTheme)
		tabList.ScrollBarImageColor3 = nextTheme.Stroke
	end)

	--// Motion and callback safety

	function window:Tween(instance, duration, properties, style)
		if self.Destroyed or not instance or not instance.Parent then
			return nil
		end

		if self.ReducedMotion then
			for property, value in pairs(properties) do
				instance[property] = value
			end

			return nil
		end

		local tween = TweenService:Create(
			instance,
			TweenInfo.new(
				math.max(0.01, duration),
				style or Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			properties
		)

		maid:GiveTween(tween)
		tween:Play()

		return tween
	end

	function window:Invoke(callback, ...)
		if type(callback) ~= "function" then
			return true
		end

		local arguments = table.pack(...)

		local ok, result = xpcall(function()
			return callback(
				table.unpack(arguments, 1, arguments.n)
			)
		end, debug.traceback)

		if not ok then
			warn("[Endma Hub callback error]\n" .. tostring(result))

			self:Notify({
				Title = "Callback error",
				Content = tostring(result):match("^[^\n]+")
					or "A callback failed.",
				Type = "Error",
				Duration = 5,
			})
		end

		return ok, result
	end

	local function bindHover(button, normalToken, hoverToken)
		maid:GiveConnection(button.MouseEnter:Connect(function()
			if button:GetAttribute("EndmaDisabled") then
				return
			end

			button.BackgroundColor3 =
				window.Theme[hoverToken]
		end))

		maid:GiveConnection(button.MouseLeave:Connect(function()
			button.BackgroundColor3 =
				window.Theme[normalToken]
		end))
	end

	bindHover(minimizeButton, "Surface2", "SurfaceHover")
	bindHover(closeButton, "Surface2", "SurfaceHover")

	--// Dragging

	local dragging = false
	local dragStart
	local startPosition

	maid:GiveConnection(topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = main.Position
		end
	end))

	maid:GiveConnection(UserInputService.InputChanged:Connect(
		function(input)
			if not dragging then
				return
			end

			if input.UserInputType
					~= Enum.UserInputType.MouseMovement
				and input.UserInputType
					~= Enum.UserInputType.Touch
			then
				return
			end

			local delta = input.Position - dragStart

			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)

			shadow.Position = UDim2.new(
				main.Position.X.Scale,
				main.Position.X.Offset + 7,
				main.Position.Y.Scale,
				main.Position.Y.Offset + 9
			)
		end
	))

	maid:GiveConnection(UserInputService.InputEnded:Connect(
		function(input)
			if input.UserInputType
					== Enum.UserInputType.MouseButton1
				or input.UserInputType
					== Enum.UserInputType.Touch
			then
				dragging = false
			end
		end
	))

	--// Resizing

	local resizing = false
	local resizeStart
	local resizeSize

	maid:GiveConnection(resizeHandle.InputBegan:Connect(
		function(input)
			if input.UserInputType
					== Enum.UserInputType.MouseButton1
				or input.UserInputType
					== Enum.UserInputType.Touch
			then
				resizing = true
				resizeStart = input.Position
				resizeSize = main.AbsoluteSize
			end
		end
	))

	maid:GiveConnection(UserInputService.InputChanged:Connect(
		function(input)
			if not resizing then
				return
			end

			if input.UserInputType
					~= Enum.UserInputType.MouseMovement
				and input.UserInputType
					~= Enum.UserInputType.Touch
			then
				return
			end

			local camera = workspace.CurrentCamera
			local viewport = camera
				and camera.ViewportSize
				or Vector2.new(1280, 720)

			local delta = input.Position - resizeStart

			local width = clamp(
				resizeSize.X + delta.X,
				560,
				math.max(560, viewport.X - 24)
			)

			local height = clamp(
				resizeSize.Y + delta.Y,
				380,
				math.max(380, viewport.Y - 24)
			)

			main.Size = UDim2.fromOffset(width, height)
			shadow.Size = main.Size
		end
	))

	maid:GiveConnection(UserInputService.InputEnded:Connect(
		function(input)
			if input.UserInputType
					== Enum.UserInputType.MouseButton1
				or input.UserInputType
					== Enum.UserInputType.Touch
			then
				resizing = false
			end
		end
	))

	--// Responsive layout

	local desktopSize = main.Size

	function window:UpdateResponsive()
		if self.Destroyed then
			return
		end

		local camera = workspace.CurrentCamera
		local viewport = camera
			and camera.ViewportSize
			or Vector2.new(1280, 720)

		local mobile = viewport.X < 700

		if mobile then
			main.Size = UDim2.fromOffset(
				math.max(320, viewport.X - 20),
				math.max(360, viewport.Y - 20)
			)

			main.Position = UDim2.fromScale(0.5, 0.5)
			shadow.Size = main.Size
			shadow.Position = UDim2.new(0.5, 6, 0.5, 8)

			sidebar.Size = UDim2.new(0, 64, 1, 0)
			content.Position = UDim2.fromOffset(64, 0)
			content.Size = UDim2.new(1, -64, 1, 0)

			searchBox.Visible = false
			footer.Visible = false
			subtitleLabel.Visible = false
			resizeHandle.Visible = false

			tabList.Position = UDim2.fromOffset(7, 12)
			tabList.Size = UDim2.new(1, -14, 1, -24)

			for _, tab in ipairs(self.Tabs) do
				tab.ButtonText.Visible = false
			end
		else
			if main.AbsoluteSize.X < 700 then
				main.Size = desktopSize
				shadow.Size = desktopSize
			end

			sidebar.Size = UDim2.new(0, 184, 1, 0)
			content.Position = UDim2.fromOffset(184, 0)
			content.Size = UDim2.new(1, -184, 1, 0)

			searchBox.Visible = true
			footer.Visible = true
			subtitleLabel.Visible = true

			resizeHandle.Visible =
				config.Resizable ~= false

			tabList.Position = UDim2.fromOffset(8, 66)
			tabList.Size = UDim2.new(1, -16, 1, -102)

			for _, tab in ipairs(self.Tabs) do
				tab.ButtonText.Visible = true
			end
		end
	end

	window:UpdateResponsive()

	if workspace.CurrentCamera then
		maid:GiveConnection(
			workspace.CurrentCamera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(function()
				window:UpdateResponsive()
			end)
		)
	end

	--// Visibility

	function window:SetDimBackground(enabled)
		self.DimBackground = enabled ~= false

		scrim.BackgroundTransparency =
			self.DimBackground and 0.56 or 1

		return self
	end

	function window:SetScale(scale)
		self.Scale = clamp(tonumber(scale) or 1, 0.75, 1.25)
		uiScale.Scale = self.Scale
		return self
	end

	function window:SetToggleKey(keyCode)
		if typeof(keyCode) == "EnumItem"
			and keyCode.EnumType == Enum.KeyCode
		then
			self.ToggleKey = keyCode
		end

		return self
	end

	function window:SetVisible(visible)
		if self.Destroyed then
			return self
		end

		self.Visible = visible ~= false

		if self.Visible then
			main.Visible = true
			shadow.Visible = true
			scrim.Visible = true

			main.GroupTransparency = 1
			shadow.BackgroundTransparency = 1

			local targetSize = main.Size

			main.Size = UDim2.new(
				targetSize.X.Scale,
				math.floor(targetSize.X.Offset * 0.97),
				targetSize.Y.Scale,
				math.floor(targetSize.Y.Offset * 0.97)
			)

			self:Tween(main, 0.16, {
				GroupTransparency = 0,
				Size = targetSize,
			})

			self:Tween(shadow, 0.16, {
				BackgroundTransparency = 0.3,
			})
		else
			local originalSize = main.Size

			local tween = self:Tween(main, 0.13, {
				GroupTransparency = 1,
				Size = UDim2.new(
					originalSize.X.Scale,
					math.floor(
						originalSize.X.Offset * 0.97
					),
					originalSize.Y.Scale,
					math.floor(
						originalSize.Y.Offset * 0.97
					)
				),
			})

			self:Tween(shadow, 0.13, {
				BackgroundTransparency = 1,
			})

			local function finish()
				if not self.Visible and not self.Destroyed then
					main.Visible = false
					shadow.Visible = false
					scrim.Visible = false
					main.GroupTransparency = 0
					main.Size = originalSize
				end
			end

			if tween then
				local connection

				connection = tween.Completed:Connect(function()
					connection:Disconnect()
					finish()
				end)

				maid:GiveConnection(connection)
			else
				finish()
			end
		end

		return self
	end

	function window:Toggle()
		return self:SetVisible(not self.Visible)
	end

	function window:SetMinimized(minimized)
		if self.Destroyed then
			return self
		end

		self.Minimized = minimized == true

		if self.Minimized then
			self.RestoredSize = main.Size
			body.Visible = false
			resizeHandle.Visible = false
			minimizeButton.Text = "+"

			local minimizedSize = UDim2.fromOffset(
				math.max(330, main.AbsoluteSize.X),
				58
			)

			self:Tween(main, 0.15, {
				Size = minimizedSize,
			})

			self:Tween(shadow, 0.15, {
				Size = minimizedSize,
			})
		else
			local restoredSize = self.RestoredSize
				or UDim2.fromOffset(760, 520)

			body.Visible = true
			minimizeButton.Text = "-"

			self:Tween(main, 0.16, {
				Size = restoredSize,
			})

			self:Tween(shadow, 0.16, {
				Size = restoredSize,
			})

			task.defer(function()
				if not self.Destroyed then
					self:UpdateResponsive()
				end
			end)
		end

		return self
	end

	maid:GiveConnection(minimizeButton.MouseButton1Click:Connect(
		function()
			window:SetMinimized(not window.Minimized)
		end
	))

	maid:GiveConnection(closeButton.MouseButton1Click:Connect(
		function()
			window:SetVisible(false)
		end
	))

	maid:GiveConnection(mobileToggle.MouseButton1Click:Connect(
		function()
			window:Toggle()
		end
	))

	maid:GiveConnection(UserInputService.InputBegan:Connect(
		function(input)
			if window.Destroyed then
				return
			end

			if input.KeyCode == window.ToggleKey
				and UserInputService:GetFocusedTextBox() == nil
			then
				window:Toggle()
			end
		end
	))

	--// Flags and controls

	local function makeController(
		root,
		getter,
		setter,
		disabledChanged
	)
		local controller = {
			Instance = root,
			Disabled = false,
			Destroyed = false,
		}

		function controller:Get()
			if getter then
				return getter()
			end

			return nil
		end

		function controller:Set(value, silent)
			if not self.Destroyed and setter then
				setter(value, silent == true)
			end

			return self
		end

		function controller:SetDisabled(disabled)
			if self.Destroyed then
				return self
			end

			self.Disabled = disabled == true
			root:SetAttribute(
				"EndmaDisabled",
				self.Disabled
			)

			if disabledChanged then
				disabledChanged(self.Disabled)
			else
				root.BackgroundTransparency =
					self.Disabled and 0.45 or 0
			end

			return self
		end

		function controller:SetVisible(visible)
			if not self.Destroyed then
				root.Visible = visible ~= false
			end

			return self
		end

		function controller:Destroy()
			if self.Destroyed then
				return
			end

			self.Destroyed = true

			pcall(function()
				root:Destroy()
			end)
		end

		table.insert(window.Controls, controller)

		return controller
	end

	function window:RegisterFlag(flag, controller, defaultValue)
		if type(flag) ~= "string" or flag == "" then
			return
		end

		self.FlagControls[flag] = controller
		self.Defaults[flag] = defaultValue

		if self.PendingFlags[flag] ~= nil then
			controller:Set(self.PendingFlags[flag], true)
			self.PendingFlags[flag] = nil
		else
			self.Flags[flag] = defaultValue
		end
	end

	function window:SetFlagValue(flag, value)
		if type(flag) == "string" and flag ~= "" then
			self.Flags[flag] = value
		end
	end

	function window:GetFlag(flag)
		return self.Flags[flag]
	end

	function window:SetFlag(flag, value)
		local controller = self.FlagControls[flag]

		if controller then
			controller:Set(value)
		else
			self.Flags[flag] = value
			self.PendingFlags[flag] = value
		end

		return self
	end

	--// Notifications

	function window:Notify(notification)
		if self.Destroyed then
			return nil
		end

		if type(notification) == "string" then
			notification = {
				Content = notification,
			}
		end

		notification = notification or {}

		local notificationType =
			string.lower(tostring(notification.Type or "Info"))

		local colorToken = ({
			success = "Success",
			warning = "Warning",
			error = "Danger",
			danger = "Danger",
			info = "Accent",
		})[notificationType] or "Accent"

		local duration = clamp(
			tonumber(notification.Duration) or 4,
			1,
			30
		)

		local card = create("CanvasGroup", {
			Name = "Notification",
			BackgroundColor3 = self.Theme.Surface,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.fromOffset(310, 76),
			ZIndex = 301,
			Parent = notificationStack,
		})

		addCorner(card, 7)
		local cardStroke = addStroke(
			card,
			self.Theme.Stroke,
			1
		)

		local indicator = create("Frame", {
			BackgroundColor3 = self.Theme[colorToken],
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 1, 0),
			ZIndex = 302,
			Parent = card,
		})

		local notificationTitle = makeText({
			Font = Enum.Font.GothamBold,
			Text = tostring(
				notification.Title or "Endma Hub"
			),
			TextColor3 = self.Theme.Text,
			TextSize = 13,
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -50, 0, 20),
			ZIndex = 303,
			Parent = card,
		})

		local notificationContent = makeText({
			Text = tostring(
				notification.Content or "Notification"
			),
			TextColor3 = self.Theme.Muted,
			TextSize = 11,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 33),
			Size = UDim2.new(1, -50, 0, 32),
			ZIndex = 303,
			Parent = card,
		})

		local dismiss = makeButton({
			BackgroundTransparency = 1,
			Text = "x",
			TextColor3 = self.Theme.Muted,
			TextSize = 12,
			Position = UDim2.new(1, -34, 0, 7),
			Size = UDim2.fromOffset(26, 26),
			ZIndex = 304,
			Parent = card,
		})

		self:BindTheme(card, "BackgroundColor3", "Surface")
		self:BindTheme(cardStroke, "Color", "Stroke")
		self:BindTheme(
			indicator,
			"BackgroundColor3",
			colorToken
		)
		self:BindTheme(
			notificationTitle,
			"TextColor3",
			"Text"
		)
		self:BindTheme(
			notificationContent,
			"TextColor3",
			"Muted"
		)
		self:BindTheme(dismiss, "TextColor3", "Muted")

		local closed = false

		local function closeNotification()
			if closed or not card.Parent then
				return
			end

			closed = true

			local tween = self:Tween(card, 0.14, {
				GroupTransparency = 1,
				Position = UDim2.fromOffset(20, 0),
			})

			if tween then
				tween.Completed:Connect(function()
					if card.Parent then
						card:Destroy()
					end
				end)
			else
				card:Destroy()
			end
		end

		maid:GiveConnection(
			dismiss.MouseButton1Click:Connect(
				closeNotification
			)
		)

		self:Tween(card, 0.16, {
			GroupTransparency = 0,
			Position = UDim2.fromOffset(0, 0),
		})

		task.delay(duration, function()
			if not self.Destroyed then
				closeNotification()
			end
		end)

		return {
			Instance = card,
			Close = closeNotification,
		}
	end

	--// Dialogs

	function window:Dialog(dialogConfig)
		dialogConfig = dialogConfig or {}

		for _, child in ipairs(modalLayer:GetChildren()) do
			child:Destroy()
		end

		modalLayer.Visible = true

		local dialog = create("CanvasGroup", {
			Name = "Dialog",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = self.Theme.Surface,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, 210),
			ZIndex = 101,
			Parent = modalLayer,
		})

		addCorner(dialog, 8)
		local dialogStroke = addStroke(
			dialog,
			self.Theme.Stroke,
			1
		)

		local dialogTitle = makeText({
			Font = Enum.Font.GothamBold,
			Text = tostring(
				dialogConfig.Title or "Confirm action"
			),
			TextColor3 = self.Theme.Text,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.new(1, -48, 0, 26),
			ZIndex = 102,
			Parent = dialog,
		})

		local dialogContent = makeText({
			Text = tostring(
				dialogConfig.Content
					or "Are you sure you want to continue?"
			),
			TextColor3 = self.Theme.Muted,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(30, 61),
			Size = UDim2.new(1, -60, 0, 62),
			ZIndex = 102,
			Parent = dialog,
		})

		local cancel = makeButton({
			BackgroundColor3 = self.Theme.Surface2,
			Text = tostring(
				dialogConfig.CancelText or "Cancel"
			),
			TextColor3 = self.Theme.Text,
			Position = UDim2.new(0, 24, 1, -62),
			Size = UDim2.new(0.5, -30, 0, 40),
			ZIndex = 102,
			Parent = dialog,
		})

		addCorner(cancel, 7)
		local cancelStroke = addStroke(
			cancel,
			self.Theme.Stroke,
			1
		)

		local confirm = makeButton({
			BackgroundColor3 = self.Theme.Accent,
			Text = tostring(
				dialogConfig.ConfirmText or "Confirm"
			),
			TextColor3 = self.Theme.Background,
			Position = UDim2.new(0.5, 6, 1, -62),
			Size = UDim2.new(0.5, -30, 0, 40),
			ZIndex = 102,
			Parent = dialog,
		})

		addCorner(confirm, 7)

		self:BindTheme(dialog, "BackgroundColor3", "Surface")
		self:BindTheme(dialogStroke, "Color", "Stroke")
		self:BindTheme(dialogTitle, "TextColor3", "Text")
		self:BindTheme(dialogContent, "TextColor3", "Muted")
		self:BindTheme(cancel, "BackgroundColor3", "Surface2")
		self:BindTheme(cancel, "TextColor3", "Text")
		self:BindTheme(cancelStroke, "Color", "Stroke")
		self:BindTheme(confirm, "BackgroundColor3", "Accent")
		self:BindTheme(
			confirm,
			"TextColor3",
			"Background"
		)

		bindHover(cancel, "Surface2", "SurfaceHover")

		local closed = false

		local function closeDialog(result)
			if closed then
				return
			end

			closed = true

			local tween = self:Tween(dialog, 0.12, {
				GroupTransparency = 1,
			})

			local function finish()
				modalLayer.Visible = false

				for _, child in ipairs(
					modalLayer:GetChildren()
				) do
					child:Destroy()
				end

				self:Invoke(
					dialogConfig.Callback,
					result == true
				)

				if result then
					self:Invoke(dialogConfig.OnConfirm)
				else
					self:Invoke(dialogConfig.OnCancel)
				end
			end

			if tween then
				tween.Completed:Connect(finish)
			else
				finish()
			end
		end

		maid:GiveConnection(
			cancel.MouseButton1Click:Connect(function()
				closeDialog(false)
			end)
		)

		maid:GiveConnection(
			confirm.MouseButton1Click:Connect(function()
				closeDialog(true)
			end)
		)

		self:Tween(dialog, 0.14, {
			GroupTransparency = 0,
		})

		return {
			Instance = dialog,
			Close = closeDialog,
		}
	end

	--// Tab system

	function window:UpdateTabStyles()
		for _, tab in ipairs(self.Tabs) do
			local active = self.SelectedTab == tab

			tab.Button.BackgroundTransparency =
				active and 0 or 1

			tab.Button.BackgroundColor3 =
				active
				and self.Theme.Surface2
				or self.Theme.Surface

			tab.ButtonText.TextColor3 =
				active
				and self.Theme.Text
				or self.Theme.Muted

			tab.Badge.BackgroundColor3 =
				active
				and self.Theme.Accent
				or self.Theme.Surface2

			tab.BadgeText.TextColor3 =
				active
				and self.Theme.Background
				or self.Theme.Muted

			tab.ActiveLine.Visible = active
			tab.ActiveLine.BackgroundColor3 =
				self.Theme.Accent
		end
	end

	window:BindThemeCallback(function()
		window:UpdateTabStyles()
	end)

	function window:SelectTab(tab)
		if type(tab) == "string" then
			for _, possibleTab in ipairs(self.Tabs) do
				if possibleTab.Name == tab then
					tab = possibleTab
					break
				end
			end
		end

		if type(tab) ~= "table" or tab.Destroyed then
			return self
		end

		if self.OpenDropdown
			and self.OpenDropdown.Close
		then
			self.OpenDropdown:Close()
		end

		self.SelectedTab = tab

		for _, possibleTab in ipairs(self.Tabs) do
			possibleTab.Page.Visible =
				possibleTab == tab
		end

		self:UpdateTabStyles()

		return self
	end

	function window:CreateTab(tabConfig)
		tabConfig = normalizeConfig(tabConfig, "Tab")

		local tabName = tostring(
			tabConfig.Name or tabConfig.Text or "Tab"
		)

		local initial = tabName:sub(1, 1):upper()

		local tabButton = makeButton({
			Name = sanitizeName(tabName),
			BackgroundColor3 = self.Theme.Surface,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, 44),
			Parent = tabList,
		})

		addCorner(tabButton, 7)

		local activeLine = create("Frame", {
			BackgroundColor3 = self.Theme.Accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromOffset(3, 28),
			Visible = false,
			Parent = tabButton,
		})

		addCorner(activeLine, 3)

		local badge = create("Frame", {
			BackgroundColor3 = self.Theme.Surface2,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(9, 7),
			Size = UDim2.fromOffset(30, 30),
			Parent = tabButton,
		})

		addCorner(badge, 6)

		local badgeText = makeText({
			Font = Enum.Font.GothamBold,
			Text = initial,
			TextColor3 = self.Theme.Muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = badge,
		})

		local buttonText = makeText({
			Text = tabName,
			TextColor3 = self.Theme.Muted,
			TextSize = 12,
			Position = UDim2.fromOffset(49, 0),
			Size = UDim2.new(1, -58, 1, 0),
			Parent = tabButton,
		})

		local page = create("ScrollingFrame", {
			Name = sanitizeName(tabName) .. "Page",
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollBarImageColor3 = self.Theme.Stroke,
			ScrollBarThickness = 3,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = content,
		})

		addPadding(page, 18, 18, 18, 18)

		local pageLayout = addList(page, 12)

		local tab = {
			Window = self,
			Name = tabName,
			Internal = tabConfig.Internal == true,
			Button = tabButton,
			ButtonText = buttonText,
			Badge = badge,
			BadgeText = badgeText,
			ActiveLine = activeLine,
			Page = page,
			PageLayout = pageLayout,
			Sections = {},
			Destroyed = false,
		}

		table.insert(self.Tabs, tab)

		self:BindTheme(
			activeLine,
			"BackgroundColor3",
			"Accent"
		)

		self:BindThemeCallback(function(nextTheme)
			if page.Parent then
				page.ScrollBarImageColor3 =
					nextTheme.Stroke
			end
		end)

		maid:GiveConnection(
			tabButton.MouseButton1Click:Connect(
				function()
					if not tab.Destroyed then
						window:SelectTab(tab)
					end
				end
			)
		)

		maid:GiveConnection(tabButton.MouseEnter:Connect(
			function()
				if window.SelectedTab ~= tab then
					tabButton.BackgroundTransparency = 0
					tabButton.BackgroundColor3 =
						window.Theme.SurfaceHover
				end
			end
		))

		maid:GiveConnection(tabButton.MouseLeave:Connect(
			function()
				window:UpdateTabStyles()
			end
		))

		function tab:SetVisible(visible)
			tabButton.Visible = visible ~= false
			return self
		end

		function tab:Select()
			window:SelectTab(self)
			return self
		end

		function tab:Destroy()
			if self.Destroyed then
				return
			end

			self.Destroyed = true
			tabButton:Destroy()
			page:Destroy()

			local index = table.find(window.Tabs, self)

			if index then
				table.remove(window.Tabs, index)
			end

			if window.SelectedTab == self then
				window.SelectedTab = window.Tabs[1]

				if window.SelectedTab then
					window:SelectTab(window.SelectedTab)
				end
			end
		end

		--// Sections

		function tab:CreateSection(sectionConfig)
			sectionConfig = normalizeConfig(
				sectionConfig,
				"Section"
			)

			local sectionName = tostring(
				sectionConfig.Name
					or sectionConfig.Text
					or "Section"
			)

			local section = {
				Tab = self,
				Name = sectionName,
				Controls = {},
			}

			local sectionFrame = create("Frame", {
				Name = sanitizeName(sectionName),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = window.Theme.Surface,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = page,
			})

			addCorner(sectionFrame, 8)

			local sectionStroke = addStroke(
				sectionFrame,
				window.Theme.Stroke,
				1
			)

			local sectionLayout = addList(sectionFrame, 0)

			local sectionHeader = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 42),
				LayoutOrder = 1,
				Parent = sectionFrame,
			})

			local sectionTitle = makeText({
				Font = Enum.Font.GothamBold,
				Text = sectionName,
				TextColor3 = window.Theme.Text,
				TextSize = 13,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -28, 1, 0),
				Parent = sectionHeader,
			})

			local sectionDivider = create("Frame", {
				BackgroundColor3 = window.Theme.Stroke,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 1, -1),
				Size = UDim2.new(1, -28, 0, 1),
				Parent = sectionHeader,
			})

			local sectionBody = create("Frame", {
				Name = "Controls",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = sectionFrame,
			})

			addPadding(sectionBody, 10, 10, 10, 10)
			addList(sectionBody, 8)

			section.Instance = sectionFrame
			section.Body = sectionBody

			window:BindTheme(
				sectionFrame,
				"BackgroundColor3",
				"Surface"
			)

			window:BindTheme(
				sectionStroke,
				"Color",
				"Stroke"
			)

			window:BindTheme(
				sectionTitle,
				"TextColor3",
				"Text"
			)

			window:BindTheme(
				sectionDivider,
				"BackgroundColor3",
				"Stroke"
			)

			local function createRow(
				height,
				controlConfig,
				noDescription
			)
				local row = create("Frame", {
					BackgroundColor3 =
						window.Theme.Surface2,

					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, height),
					Parent = sectionBody,
				})

				addCorner(row, 7)

				local rowStroke = addStroke(
					row,
					window.Theme.Stroke,
					1,
					0.25
				)

				local description = tostring(
					controlConfig.Description or ""
				)

				local titleY = description ~= ""
					and 8
					or 0

				local titleHeight = description ~= ""
					and 19
					or height

				local title = makeText({
					Font = Enum.Font.GothamMedium,
					Text = tostring(
						controlConfig.Name
							or controlConfig.Text
							or "Control"
					),
					TextColor3 = window.Theme.Text,
					TextSize = 12,
					Position = UDim2.fromOffset(
						12,
						titleY
					),
					Size = UDim2.new(
						1,
						-150,
						0,
						titleHeight
					),
					Parent = row,
				})

				local descriptionLabel

				if description ~= ""
					and not noDescription
				then
					descriptionLabel = makeText({
						Text = description,
						TextColor3 =
							window.Theme.Muted,

						TextSize = 10,
						Position = UDim2.fromOffset(
							12,
							27
						),

						Size = UDim2.new(
							1,
							-150,
							0,
							17
						),

						Parent = row,
					})

					window:BindTheme(
						descriptionLabel,
						"TextColor3",
						"Muted"
					)
				end

				window:BindTheme(
					row,
					"BackgroundColor3",
					"Surface2"
				)

				window:BindTheme(
					rowStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					title,
					"TextColor3",
					"Text"
				)

				maid:GiveConnection(
					row.MouseEnter:Connect(function()
						if not row:GetAttribute(
							"EndmaDisabled"
						) then
							row.BackgroundColor3 =
								window.Theme.SurfaceHover
						end
					end)
				)

				maid:GiveConnection(
					row.MouseLeave:Connect(function()
						row.BackgroundColor3 =
							window.Theme.Surface2
					end)
				)

				return row, title, descriptionLabel
			end

			local function register(
				controller,
				controlConfig,
				defaultValue
			)
				table.insert(section.Controls, controller)

				window:RegisterFlag(
					controlConfig.Flag,
					controller,
					defaultValue
				)

				return controller
			end

			-- Button

			function section:AddButton(buttonConfig)
				buttonConfig = normalizeConfig(
					buttonConfig,
					"Button"
				)

				local row = createRow(52, buttonConfig)

				local action = makeButton({
					BackgroundColor3 =
						window.Theme.Accent,

					Text = tostring(
						buttonConfig.ButtonText
							or "Run"
					),

					TextColor3 =
						window.Theme.Background,

					TextSize = 11,
					Position = UDim2.new(
						1,
						-102,
						0.5,
						-16
					),

					Size = UDim2.fromOffset(90, 32),
					Parent = row,
				})

				addCorner(action, 6)

				window:BindTheme(
					action,
					"BackgroundColor3",
					"Accent"
				)

				window:BindTheme(
					action,
					"TextColor3",
					"Background"
				)

				local controller

				local function fire()
					if controller.Disabled then
						return
					end

					window:Invoke(
						buttonConfig.Callback
					)
				end

				controller = makeController(
					row,
					nil,
					nil,
					function(disabled)
						action.Active = not disabled
						action.BackgroundTransparency =
							disabled and 0.55 or 0

						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				function controller:Fire()
					fire()
					return self
				end

				function controller:SetText(text)
					action.Text = tostring(text)
					return self
				end

				maid:GiveConnection(
					action.MouseButton1Click:Connect(fire)
				)

				return register(
					controller,
					buttonConfig,
					nil
				)
			end

			-- Toggle and checkbox

			local function addBoolean(booleanConfig, checkbox)
				booleanConfig = normalizeConfig(
					booleanConfig,
					checkbox and "Checkbox" or "Toggle"
				)

				local row = createRow(52, booleanConfig)
				local value =
					booleanConfig.Default == true

				local controller
				local controlButton

				if checkbox then
					controlButton = makeButton({
						BackgroundColor3 =
							window.Theme.Surface,

						Text = "",
						Position = UDim2.new(
							1,
							-42,
							0.5,
							-11
						),

						Size = UDim2.fromOffset(22, 22),
						Parent = row,
					})

					addCorner(controlButton, 5)

					local checkboxStroke = addStroke(
						controlButton,
						window.Theme.Stroke,
						1
					)

					local check = makeText({
						Font = Enum.Font.GothamBold,
						Text = "x",
						TextColor3 =
							window.Theme.Background,

						TextSize = 11,
						TextXAlignment =
							Enum.TextXAlignment.Center,

						Size = UDim2.fromScale(1, 1),
						Parent = controlButton,
					})

					window:BindTheme(
						checkboxStroke,
						"Color",
						"Stroke"
					)

					window:BindTheme(
						check,
						"TextColor3",
						"Background"
					)

					local function render()
						controlButton.BackgroundColor3 =
							value
								and window.Theme.Accent
								or window.Theme.Surface

						check.Visible = value
					end

					controller = makeController(
						row,
						function()
							return value
						end,

						function(nextValue, silent)
							value = nextValue == true
							render()

							window:SetFlagValue(
								booleanConfig.Flag,
								value
							)

							if not silent then
								window:Invoke(
									booleanConfig.Callback,
									value
								)
							end
						end,

						function(disabled)
							controlButton.Active =
								not disabled

							controlButton.BackgroundTransparency =
								disabled and 0.55 or 0

							row.BackgroundTransparency =
								disabled and 0.35 or 0
						end
					)

					render()
				else
					controlButton = makeButton({
						BackgroundColor3 =
							window.Theme.Stroke,

						Text = "",
						Position = UDim2.new(
							1,
							-54,
							0.5,
							-12
						),

						Size = UDim2.fromOffset(42, 24),
						Parent = row,
					})

					addCorner(controlButton, 12)

					local knob = create("Frame", {
						BackgroundColor3 =
							window.Theme.Text,

						BorderSizePixel = 0,
						Position = UDim2.fromOffset(
							3,
							3
						),

						Size = UDim2.fromOffset(18, 18),
						Parent = controlButton,
					})

					addCorner(knob, 9)

					window:BindTheme(
						knob,
						"BackgroundColor3",
						"Text"
					)

					local function render()
						controlButton.BackgroundColor3 =
							value
								and window.Theme.Accent
								or window.Theme.Stroke

						knob.Position = value
							and UDim2.fromOffset(21, 3)
							or UDim2.fromOffset(3, 3)
					end

					controller = makeController(
						row,
						function()
							return value
						end,

						function(nextValue, silent)
							value = nextValue == true
							render()

							window:SetFlagValue(
								booleanConfig.Flag,
								value
							)

							if not silent then
								window:Invoke(
									booleanConfig.Callback,
									value
								)
							end
						end,

						function(disabled)
							controlButton.Active =
								not disabled

							controlButton.BackgroundTransparency =
								disabled and 0.55 or 0

							row.BackgroundTransparency =
								disabled and 0.35 or 0
						end
					)

					render()
				end

				maid:GiveConnection(
					controlButton.MouseButton1Click:Connect(
						function()
							if not controller.Disabled then
								controller:Set(not value)
							end
						end
					)
				)

				return register(
					controller,
					booleanConfig,
					value
				)
			end

			function section:AddToggle(toggleConfig)
				return addBoolean(toggleConfig, false)
			end

			function section:AddCheckbox(checkboxConfig)
				return addBoolean(checkboxConfig, true)
			end

			-- Slider

			function section:AddSlider(sliderConfig)
				sliderConfig = normalizeConfig(
					sliderConfig,
					"Slider"
				)

				local minimum =
					tonumber(sliderConfig.Min) or 0

				local maximum =
					tonumber(sliderConfig.Max) or 100

				if maximum < minimum then
					minimum, maximum = maximum, minimum
				end

				local increment =
					tonumber(sliderConfig.Increment) or 1

				local value = clamp(
					tonumber(sliderConfig.Default)
						or minimum,
					minimum,
					maximum
				)

				value = roundTo(value, increment)

				local row, title = createRow(
					76,
					sliderConfig,
					true
				)

				title.Size = UDim2.new(1, -100, 0, 34)
				title.Position = UDim2.fromOffset(12, 3)

				local valueLabel = makeText({
					Font = Enum.Font.GothamBold,
					TextColor3 = window.Theme.Accent,
					TextSize = 11,
					TextXAlignment =
						Enum.TextXAlignment.Right,

					Position = UDim2.new(
						1,
						-92,
						0,
						3
					),

					Size = UDim2.fromOffset(80, 34),
					Parent = row,
				})

				local track = makeButton({
					BackgroundColor3 =
						window.Theme.Surface,

					Text = "",
					Position = UDim2.fromOffset(
						12,
						51
					),

					Size = UDim2.new(1, -24, 0, 8),
					Parent = row,
				})

				addCorner(track, 4)

				local fill = create("Frame", {
					BackgroundColor3 =
						window.Theme.Accent,

					BorderSizePixel = 0,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = track,
				})

				addCorner(fill, 4)

				local knob = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 =
						window.Theme.Text,

					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(14, 14),
					Parent = track,
				})

				addCorner(knob, 7)
				local knobStroke = addStroke(
					knob,
					window.Theme.Background,
					2
				)

				window:BindTheme(
					valueLabel,
					"TextColor3",
					"Accent"
				)

				window:BindTheme(
					track,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					fill,
					"BackgroundColor3",
					"Accent"
				)

				window:BindTheme(
					knob,
					"BackgroundColor3",
					"Text"
				)

				window:BindTheme(
					knobStroke,
					"Color",
					"Background"
				)

				local controller
				local draggingSlider = false

				local function formatValue()
					return tostring(
						sliderConfig.Prefix or ""
					)
						.. tostring(value)
						.. tostring(
							sliderConfig.Suffix or ""
						)
				end

				local function render()
					local range = maximum - minimum
					local ratio = range == 0
							and 0
						or (value - minimum) / range

					fill.Size = UDim2.new(ratio, 0, 1, 0)
					knob.Position = UDim2.new(
						ratio,
						0,
						0.5,
						0
					)

					valueLabel.Text = formatValue()
				end

				controller = makeController(
					row,
					function()
						return value
					end,

					function(nextValue, silent)
						value = clamp(
							tonumber(nextValue) or minimum,
							minimum,
							maximum
						)

						value = roundTo(value, increment)
						render()

						window:SetFlagValue(
							sliderConfig.Flag,
							value
						)

						if not silent then
							window:Invoke(
								sliderConfig.Callback,
								value
							)
						end
					end,

					function(disabled)
						track.Active = not disabled
						track.BackgroundTransparency =
							disabled and 0.55 or 0

						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				local function updateFromInput(input)
					if controller.Disabled
						or track.AbsoluteSize.X <= 0
					then
						return
					end

					local ratio = clamp(
						(
							input.Position.X
							- track.AbsolutePosition.X
						) / track.AbsoluteSize.X,
						0,
						1
					)

					controller:Set(
						minimum
							+ (maximum - minimum)
								* ratio
					)
				end

				maid:GiveConnection(
					track.InputBegan:Connect(function(input)
						if input.UserInputType
								== Enum.UserInputType.MouseButton1
							or input.UserInputType
								== Enum.UserInputType.Touch
						then
							draggingSlider = true
							updateFromInput(input)
						end
					end)
				)

				maid:GiveConnection(
					UserInputService.InputChanged:Connect(
						function(input)
							if draggingSlider
								and (
									input.UserInputType
											== Enum.UserInputType.MouseMovement
										or input.UserInputType
											== Enum.UserInputType.Touch
								)
							then
								updateFromInput(input)
							end
						end
					)
				)

				maid:GiveConnection(
					UserInputService.InputEnded:Connect(
						function(input)
							if input.UserInputType
									== Enum.UserInputType.MouseButton1
								or input.UserInputType
									== Enum.UserInputType.Touch
							then
								draggingSlider = false
							end
						end
					)
				)

				render()

				return register(
					controller,
					sliderConfig,
					value
				)
			end

			-- Range slider

			function section:AddRangeSlider(rangeConfig)
				rangeConfig = normalizeConfig(
					rangeConfig,
					"Range"
				)

				local minimum =
					tonumber(rangeConfig.Min) or 0

				local maximum =
					tonumber(rangeConfig.Max) or 100

				if maximum < minimum then
					minimum, maximum = maximum, minimum
				end

				local increment =
					tonumber(rangeConfig.Increment) or 1

				local defaults =
					type(rangeConfig.Default) == "table"
						and rangeConfig.Default
						or {}

				local low = tonumber(
					defaults.Min or defaults[1]
				) or minimum

				local high = tonumber(
					defaults.Max or defaults[2]
				) or maximum

				low = clamp(
					roundTo(low, increment),
					minimum,
					maximum
				)

				high = clamp(
					roundTo(high, increment),
					low,
					maximum
				)

				local row, title = createRow(
					76,
					rangeConfig,
					true
				)

				title.Size = UDim2.new(1, -120, 0, 34)
				title.Position = UDim2.fromOffset(12, 3)

				local valueLabel = makeText({
					Font = Enum.Font.GothamBold,
					TextColor3 = window.Theme.Accent,
					TextSize = 11,
					TextXAlignment =
						Enum.TextXAlignment.Right,

					Position = UDim2.new(
						1,
						-120,
						0,
						3
					),

					Size = UDim2.fromOffset(108, 34),
					Parent = row,
				})

				local track = makeButton({
					BackgroundColor3 =
						window.Theme.Surface,

					Text = "",
					Position = UDim2.fromOffset(
						12,
						51
					),

					Size = UDim2.new(1, -24, 0, 8),
					Parent = row,
				})

				addCorner(track, 4)

				local fill = create("Frame", {
					BackgroundColor3 =
						window.Theme.Accent,

					BorderSizePixel = 0,
					Parent = track,
				})

				addCorner(fill, 4)

				local lowKnob = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 =
						window.Theme.Text,

					BorderSizePixel = 0,
					Size = UDim2.fromOffset(14, 14),
					Parent = track,
				})

				addCorner(lowKnob, 7)

				local highKnob = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 =
						window.Theme.Text,

					BorderSizePixel = 0,
					Size = UDim2.fromOffset(14, 14),
					Parent = track,
				})

				addCorner(highKnob, 7)

				window:BindTheme(
					valueLabel,
					"TextColor3",
					"Accent"
				)

				window:BindTheme(
					track,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					fill,
					"BackgroundColor3",
					"Accent"
				)

				window:BindTheme(
					lowKnob,
					"BackgroundColor3",
					"Text"
				)

				window:BindTheme(
					highKnob,
					"BackgroundColor3",
					"Text"
				)

				local controller
				local draggingHandle

				local function valueRatio(valueToConvert)
					if maximum == minimum then
						return 0
					end

					return (
						valueToConvert - minimum
					) / (maximum - minimum)
				end

				local function render()
					local lowRatio = valueRatio(low)
					local highRatio = valueRatio(high)

					fill.Position = UDim2.new(
						lowRatio,
						0,
						0,
						0
					)

					fill.Size = UDim2.new(
						highRatio - lowRatio,
						0,
						1,
						0
					)

					lowKnob.Position = UDim2.new(
						lowRatio,
						0,
						0.5,
						0
					)

					highKnob.Position = UDim2.new(
						highRatio,
						0,
						0.5,
						0
					)

					valueLabel.Text = tostring(low)
						.. " - "
						.. tostring(high)
						.. tostring(
							rangeConfig.Suffix or ""
						)
				end

				controller = makeController(
					row,
					function()
						return {
							Min = low,
							Max = high,
						}
					end,

					function(nextValue, silent)
						if type(nextValue) ~= "table" then
							return
						end

						local nextLow = tonumber(
							nextValue.Min
								or nextValue[1]
						) or low

						local nextHigh = tonumber(
							nextValue.Max
								or nextValue[2]
						) or high

						low = clamp(
							roundTo(
								nextLow,
								increment
							),
							minimum,
							maximum
						)

						high = clamp(
							roundTo(
								nextHigh,
								increment
							),
							low,
							maximum
						)

						render()

						local output = {
							Min = low,
							Max = high,
						}

						window:SetFlagValue(
							rangeConfig.Flag,
							output
						)

						if not silent then
							window:Invoke(
								rangeConfig.Callback,
								low,
								high
							)
						end
					end,

					function(disabled)
						track.Active = not disabled
						track.BackgroundTransparency =
							disabled and 0.55 or 0

						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				local function updateFromInput(input)
					if controller.Disabled
						or track.AbsoluteSize.X <= 0
					then
						return
					end

					local ratio = clamp(
						(
							input.Position.X
							- track.AbsolutePosition.X
						) / track.AbsoluteSize.X,
						0,
						1
					)

					local nextValue = roundTo(
						minimum
							+ (maximum - minimum)
								* ratio,
						increment
					)

					if not draggingHandle then
						local distanceLow =
							math.abs(nextValue - low)

						local distanceHigh =
							math.abs(nextValue - high)

						draggingHandle =
							distanceLow <= distanceHigh
								and "Low"
								or "High"
					end

					if draggingHandle == "Low" then
						controller:Set({
							Min = math.min(
								nextValue,
								high
							),
							Max = high,
						})
					else
						controller:Set({
							Min = low,
							Max = math.max(
								nextValue,
								low
							),
						})
					end
				end

				maid:GiveConnection(
					track.InputBegan:Connect(function(input)
						if input.UserInputType
								== Enum.UserInputType.MouseButton1
							or input.UserInputType
								== Enum.UserInputType.Touch
						then
							updateFromInput(input)
						end
					end)
				)

				maid:GiveConnection(
					UserInputService.InputChanged:Connect(
						function(input)
							if draggingHandle
								and (
									input.UserInputType
											== Enum.UserInputType.MouseMovement
										or input.UserInputType
											== Enum.UserInputType.Touch
								)
							then
								updateFromInput(input)
							end
						end
					)
				)

				maid:GiveConnection(
					UserInputService.InputEnded:Connect(
						function(input)
							if input.UserInputType
									== Enum.UserInputType.MouseButton1
								or input.UserInputType
									== Enum.UserInputType.Touch
							then
								draggingHandle = nil
							end
						end
					)
				)

				render()

				return register(
					controller,
					rangeConfig,
					{
						Min = low,
						Max = high,
					}
				)
			end

			-- Dropdowns

			local function addDropdown(
				dropdownConfig,
				multiple
			)
				dropdownConfig = normalizeConfig(
					dropdownConfig,
					multiple
							and "Multi dropdown"
						or "Dropdown"
				)

				local options = copyArray(
					dropdownConfig.Options or {}
				)

				local selected

				if multiple then
					selected = copyArray(
						dropdownConfig.Default or {}
					)
				else
					selected = dropdownConfig.Default

					if selected == nil then
						selected = options[1]
					end
				end

				local root = create("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 =
						window.Theme.Surface2,

					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					Parent = sectionBody,
				})

				addCorner(root, 7)
				local rootStroke = addStroke(
					root,
					window.Theme.Stroke,
					1,
					0.25
				)

				addList(root, 0)

				local header = create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 56),
					LayoutOrder = 1,
					Parent = root,
				})

				local title = makeText({
					Text = tostring(
						dropdownConfig.Name
							or dropdownConfig.Text
							or "Dropdown"
					),
					TextColor3 = window.Theme.Text,
					TextSize = 12,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -190, 1, 0),
					Parent = header,
				})

				local selector = makeButton({
					BackgroundColor3 =
						window.Theme.Surface,

					Text = "",
					Position = UDim2.new(
						1,
						-174,
						0.5,
						-18
					),

					Size = UDim2.fromOffset(162, 36),
					Parent = header,
				})

				addCorner(selector, 6)
				local selectorStroke = addStroke(
					selector,
					window.Theme.Stroke,
					1
				)

				local selectedLabel = makeText({
					TextColor3 = window.Theme.Text,
					TextSize = 11,
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -34, 1, 0),
					Parent = selector,
				})

				local arrow = makeText({
					Text = "v",
					TextColor3 = window.Theme.Muted,
					TextSize = 10,
					TextXAlignment =
						Enum.TextXAlignment.Center,

					Position = UDim2.new(1, -28, 0, 0),
					Size = UDim2.fromOffset(28, 36),
					Parent = selector,
				})

				local optionsHolder = create("Frame", {
					Name = "Options",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					Visible = false,
					Parent = root,
				})

				addPadding(optionsHolder, 0, 10, 10, 10)
				local optionsLayout = addList(
					optionsHolder,
					6
				)

				window:BindTheme(
					root,
					"BackgroundColor3",
					"Surface2"
				)

				window:BindTheme(
					rootStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					title,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					selector,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					selectorStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					selectedLabel,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					arrow,
					"TextColor3",
					"Muted"
				)

				local controller
				local open = false
				local optionButtons = {}

				local function displayText()
					if multiple then
						if #selected == 0 then
							return tostring(
								dropdownConfig.Placeholder
									or "None"
							)
						end

						return table.concat(selected, ", ")
					end

					if selected == nil then
						return tostring(
							dropdownConfig.Placeholder
								or "Select"
						)
					end

					return tostring(selected)
				end

				local function renderSelection()
					selectedLabel.Text = displayText()

					for option, data in pairs(
						optionButtons
					) do
						local active = multiple
								and contains(
									selected,
									option
								)
							or selected == option

						data.Indicator.Visible = active

						data.Button.BackgroundColor3 =
							active
								and window.Theme.SurfaceHover
								or window.Theme.Surface
					end
				end

				local function close()
					if not open then
						return
					end

					open = false
					arrow.Text = "v"

					local tween = window:Tween(
						optionsHolder,
						0.12,
						{
							Size = UDim2.new(
								1,
								0,
								0,
								0
							),
						}
					)

					local function finish()
						if not open
							and optionsHolder.Parent
						then
							optionsHolder.Visible = false
						end
					end

					if tween then
						tween.Completed:Connect(finish)
					else
						finish()
					end

					if window.OpenDropdown == controller then
						window.OpenDropdown = nil
					end
				end

				local function openDropdown()
					if open or controller.Disabled then
						return
					end

					if window.OpenDropdown
						and window.OpenDropdown ~= controller
					then
						window.OpenDropdown:Close()
					end

					open = true
					window.OpenDropdown = controller
					arrow.Text = "^"
					optionsHolder.Visible = true

					local targetHeight =
						optionsLayout.AbsoluteContentSize.Y
						+ 10

					window:Tween(
						optionsHolder,
						0.14,
						{
							Size = UDim2.new(
								1,
								0,
								0,
								targetHeight
							),
						}
					)
				end

				local function rebuildOptions()
					for _, child in ipairs(
						optionsHolder:GetChildren()
					) do
						if child:IsA("GuiButton") then
							child:Destroy()
						end
					end

					table.clear(optionButtons)

					for _, option in ipairs(options) do
						local optionButton = makeButton({
							BackgroundColor3 =
								window.Theme.Surface,

							Text = "",
							Size = UDim2.new(
								1,
								0,
								0,
								36
							),

							Parent = optionsHolder,
						})

						addCorner(optionButton, 6)

						local optionText = makeText({
							Text = tostring(option),
							TextColor3 =
								window.Theme.Text,

							TextSize = 11,
							Position =
								UDim2.fromOffset(10, 0),

							Size = UDim2.new(
								1,
								-42,
								1,
								0
							),

							Parent = optionButton,
						})

						local indicator = create("Frame", {
							BackgroundColor3 =
								window.Theme.Accent,

							BorderSizePixel = 0,
							Position = UDim2.new(
								1,
								-23,
								0.5,
								-5
							),

							Size = UDim2.fromOffset(
								10,
								10
							),

							Parent = optionButton,
						})

						addCorner(indicator, 5)

						window:BindTheme(
							optionText,
							"TextColor3",
							"Text"
						)

						window:BindTheme(
							indicator,
							"BackgroundColor3",
							"Accent"
						)

						optionButtons[option] = {
							Button = optionButton,
							Indicator = indicator,
						}

						maid:GiveConnection(
							optionButton.MouseButton1Click:Connect(
								function()
									if multiple then
										local index =
											table.find(
												selected,
												option
											)

										if index then
											table.remove(
												selected,
												index
											)
										else
											table.insert(
												selected,
												option
											)
										end

										controller:Set(
											selected
										)
									else
										controller:Set(
											option
										)

										close()
									end
								end
							)
						)

						maid:GiveConnection(
							optionButton.MouseEnter:Connect(
								function()
									optionButton.BackgroundColor3 =
										window.Theme.SurfaceHover
								end
							)
						)

						maid:GiveConnection(
							optionButton.MouseLeave:Connect(
								function()
									renderSelection()
								end
							)
						)
					end

					renderSelection()
				end

				controller = makeController(
					root,
					function()
						if multiple then
							return copyArray(selected)
						end

						return selected
					end,

					function(nextValue, silent)
						if multiple then
							selected = type(nextValue)
									== "table"
									and copyArray(
										nextValue
									)
								or {}
						else
							selected = nextValue
						end

						renderSelection()

						local output = multiple
								and copyArray(selected)
							or selected

						window:SetFlagValue(
							dropdownConfig.Flag,
							output
						)

						if not silent then
							window:Invoke(
								dropdownConfig.Callback,
								output
							)
						end
					end,

					function(disabled)
						selector.Active = not disabled
						selector.BackgroundTransparency =
							disabled and 0.55 or 0

						root.BackgroundTransparency =
							disabled and 0.35 or 0

						if disabled then
							close()
						end
					end
				)

				function controller:Open()
					openDropdown()
					return self
				end

				function controller:Close()
					close()
					return self
				end

				function controller:Refresh(
					nextOptions,
					keepValue
				)
					options = copyArray(nextOptions or {})

					if not keepValue then
						selected = multiple
								and {}
							or options[1]
					end

					rebuildOptions()
					renderSelection()

					return self
				end

				maid:GiveConnection(
					selector.MouseButton1Click:Connect(
						function()
							if open then
								close()
							else
								openDropdown()
							end
						end
					)
				)

				rebuildOptions()

				return register(
					controller,
					dropdownConfig,
					multiple
							and copyArray(selected)
						or selected
				)
			end

			function section:AddDropdown(dropdownConfig)
				return addDropdown(dropdownConfig, false)
			end

			function section:AddMultiDropdown(dropdownConfig)
				return addDropdown(dropdownConfig, true)
			end

			-- Input

			function section:AddInput(inputConfig)
				inputConfig = normalizeConfig(
					inputConfig,
					"Input"
				)

				local row = createRow(58, inputConfig)
				local value = tostring(
					inputConfig.Default or ""
				)

				local inputBox = create("TextBox", {
					BackgroundColor3 =
						window.Theme.Surface,

					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamMedium,
					PlaceholderText = tostring(
						inputConfig.Placeholder
							or "Enter value"
					),

					PlaceholderColor3 =
						window.Theme.Muted,

					Text = value,
					TextColor3 = window.Theme.Text,
					TextSize = 11,
					TextXAlignment =
						Enum.TextXAlignment.Left,

					Position = UDim2.new(
						1,
						-184,
						0.5,
						-18
					),

					Size = UDim2.fromOffset(172, 36),
					Parent = row,
				})

				addCorner(inputBox, 6)
				local inputStroke = addStroke(
					inputBox,
					window.Theme.Stroke,
					1
				)

				addPadding(inputBox, 0, 10, 0, 10)

				window:BindTheme(
					inputBox,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					inputBox,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					inputBox,
					"PlaceholderColor3",
					"Muted"
				)

				window:BindTheme(
					inputStroke,
					"Color",
					"Stroke"
				)

				local controller

				controller = makeController(
					row,
					function()
						return value
					end,

					function(nextValue, silent)
						value = tostring(nextValue or "")

						if inputConfig.Numeric then
							value = value:gsub(
								"[^%d%.%-]",
								""
							)
						end

						local maxLength =
							tonumber(
								inputConfig.MaxLength
							)

						if maxLength
							and #value > maxLength
						then
							value = value:sub(
								1,
								maxLength
							)
						end

						inputBox.Text = value

						window:SetFlagValue(
							inputConfig.Flag,
							value
						)

						if not silent then
							window:Invoke(
								inputConfig.Callback,
								value
							)
						end
					end,

					function(disabled)
						inputBox.TextEditable =
							not disabled

						inputBox.BackgroundTransparency =
							disabled and 0.55 or 0

						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				maid:GiveConnection(
					inputBox.FocusLost:Connect(
						function(enterPressed)
							if controller.Disabled then
								return
							end

							if inputConfig.EnterOnly
								and not enterPressed
							then
								inputBox.Text = value
								return
							end

							controller:Set(inputBox.Text)
						end
					)
				)

				return register(
					controller,
					inputConfig,
					value
				)
			end

			-- Keybind

			function section:AddKeybind(keybindConfig)
				keybindConfig = normalizeConfig(
					keybindConfig,
					"Keybind"
				)

				local row = createRow(54, keybindConfig)

				local value =
					keybindConfig.Default
					or Enum.KeyCode.Unknown

				local capture = false

				local keyButton = makeButton({
					BackgroundColor3 =
						window.Theme.Surface,

					Text = value.Name,
					TextColor3 = window.Theme.Text,
					TextSize = 11,
					Position = UDim2.new(
						1,
						-130,
						0.5,
						-17
					),

					Size = UDim2.fromOffset(118, 34),
					Parent = row,
				})

				addCorner(keyButton, 6)
				local keyStroke = addStroke(
					keyButton,
					window.Theme.Stroke,
					1
				)

				window:BindTheme(
					keyButton,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					keyButton,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					keyStroke,
					"Color",
					"Stroke"
				)

				local controller

				controller = makeController(
					row,
					function()
						return value
					end,

					function(nextValue, silent)
						if typeof(nextValue)
								~= "EnumItem"
							or nextValue.EnumType
								~= Enum.KeyCode
						then
							return
						end

						value = nextValue
						keyButton.Text = value.Name

						window:SetFlagValue(
							keybindConfig.Flag,
							value
						)

						if not silent then
							window:Invoke(
								keybindConfig.Callback,
								value
							)
						end
					end,

					function(disabled)
						keyButton.Active = not disabled
						keyButton.BackgroundTransparency =
							disabled and 0.55 or 0

						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				maid:GiveConnection(
					keyButton.MouseButton1Click:Connect(
						function()
							if controller.Disabled then
								return
							end

							capture = true
							keyButton.Text = "Press a key"
						end
					)
				)

				maid:GiveConnection(
					UserInputService.InputBegan:Connect(
						function(input)
							if not capture
								or controller.Disabled
							then
								return
							end

							if input.UserInputType
								== Enum.UserInputType.Keyboard
							then
								capture = false

								if input.KeyCode
									== Enum.KeyCode.Escape
								then
									keyButton.Text =
										value.Name

									return
								end

								controller:Set(
									input.KeyCode
								)
							end
						end
					)
				)

				return register(
					controller,
					keybindConfig,
					value
				)
			end

			-- Color picker

			function section:AddColorPicker(colorConfig)
				colorConfig = normalizeConfig(
					colorConfig,
					"Color"
				)

				local value =
					typeof(colorConfig.Default)
							== "Color3"
						and colorConfig.Default
						or Color3.fromRGB(139, 92, 246)

				local root = create("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 =
						window.Theme.Surface2,

					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					Parent = sectionBody,
				})

				addCorner(root, 7)
				local rootStroke = addStroke(
					root,
					window.Theme.Stroke,
					1,
					0.25
				)

				addList(root, 0)

				local header = create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 56),
					LayoutOrder = 1,
					Parent = root,
				})

				local title = makeText({
					Text = tostring(
						colorConfig.Name
							or colorConfig.Text
							or "Color"
					),
					TextColor3 = window.Theme.Text,
					TextSize = 12,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -178, 1, 0),
					Parent = header,
				})

				local hexInput = create("TextBox", {
					BackgroundColor3 =
						window.Theme.Surface,

					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamMedium,
					Text = colorToHex(value),
					TextColor3 = window.Theme.Text,
					TextSize = 10,
					TextXAlignment =
						Enum.TextXAlignment.Center,

					Position = UDim2.new(
						1,
						-136,
						0.5,
						-17
					),

					Size = UDim2.fromOffset(92, 34),
					Parent = header,
				})

				addCorner(hexInput, 6)
				local hexStroke = addStroke(
					hexInput,
					window.Theme.Stroke,
					1
				)

				local preview = makeButton({
					BackgroundColor3 = value,
					Text = "",
					Position = UDim2.new(
						1,
						-36,
						0.5,
						-12
					),

					Size = UDim2.fromOffset(24, 24),
					Parent = header,
				})

				addCorner(preview, 6)
				local previewStroke = addStroke(
					preview,
					window.Theme.Stroke,
					1
				)

				local panel = create("Frame", {
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					Visible = false,
					Parent = root,
				})

				addPadding(panel, 0, 12, 10, 12)
				local panelLayout = addList(panel, 8)

				window:BindTheme(
					root,
					"BackgroundColor3",
					"Surface2"
				)

				window:BindTheme(
					rootStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					title,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					hexInput,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					hexInput,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					hexStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					previewStroke,
					"Color",
					"Stroke"
				)

				local controller
				local open = false
				local channels = {}

				local function channelValue(channel)
					if channel == "R" then
						return math.floor(
							value.R * 255 + 0.5
						)
					elseif channel == "G" then
						return math.floor(
							value.G * 255 + 0.5
						)
					end

					return math.floor(
						value.B * 255 + 0.5
					)
				end

				local function render()
					preview.BackgroundColor3 = value
					hexInput.Text = colorToHex(value)

					for channel, data in pairs(channels) do
						local amount =
							channelValue(channel)

						data.Fill.Size = UDim2.new(
							amount / 255,
							0,
							1,
							0
						)

						data.Value.Text =
							tostring(amount)
					end
				end

				local function setChannel(channel, amount)
					local red = channelValue("R")
					local green = channelValue("G")
					local blue = channelValue("B")

					if channel == "R" then
						red = amount
					elseif channel == "G" then
						green = amount
					else
						blue = amount
					end

					controller:Set(
						Color3.fromRGB(
							red,
							green,
							blue
						)
					)
				end

				for _, channel in ipairs({
					{
						Name = "R",
						Color = Color3.fromRGB(
							220,
							80,
							90
						),
					},
					{
						Name = "G",
						Color = Color3.fromRGB(
							76,
							190,
							120
						),
					},
					{
						Name = "B",
						Color = Color3.fromRGB(
							80,
							135,
							220
						),
					},
				}) do
					local channelRow = create("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(
							1,
							0,
							0,
							25
						),

						Parent = panel,
					})

					local channelName = makeText({
						Font = Enum.Font.GothamBold,
						Text = channel.Name,
						TextColor3 =
							window.Theme.Muted,

						TextSize = 10,
						Size = UDim2.fromOffset(
							18,
							25
						),

						Parent = channelRow,
					})

					local track = makeButton({
						BackgroundColor3 =
							window.Theme.Surface,

						Text = "",
						Position = UDim2.fromOffset(
							24,
							9
						),

						Size = UDim2.new(
							1,
							-70,
							0,
							7
						),

						Parent = channelRow,
					})

					addCorner(track, 4)

					local fill = create("Frame", {
						BackgroundColor3 =
							channel.Color,

						BorderSizePixel = 0,
						Size = UDim2.new(
							0,
							0,
							1,
							0
						),

						Parent = track,
					})

					addCorner(fill, 4)

					local channelValueLabel = makeText({
						Text = "0",
						TextColor3 =
							window.Theme.Text,

						TextSize = 10,
						TextXAlignment =
							Enum.TextXAlignment.Right,

						Position = UDim2.new(
							1,
							-40,
							0,
							0
						),

						Size = UDim2.fromOffset(
							40,
							25
						),

						Parent = channelRow,
					})

					window:BindTheme(
						channelName,
						"TextColor3",
						"Muted"
					)

					window:BindTheme(
						track,
						"BackgroundColor3",
						"Surface"
					)

					window:BindTheme(
						channelValueLabel,
						"TextColor3",
						"Text"
					)

					channels[channel.Name] = {
						Fill = fill,
						Value = channelValueLabel,
					}

					local draggingChannel = false

					local function updateChannel(input)
						if controller.Disabled
							or track.AbsoluteSize.X <= 0
						then
							return
						end

						local ratio = clamp(
							(
								input.Position.X
								- track.AbsolutePosition.X
							) / track.AbsoluteSize.X,
							0,
							1
						)

						setChannel(
							channel.Name,
							math.floor(
								ratio * 255 + 0.5
							)
						)
					end

					maid:GiveConnection(
						track.InputBegan:Connect(
							function(input)
								if input.UserInputType
										== Enum.UserInputType.MouseButton1
									or input.UserInputType
										== Enum.UserInputType.Touch
								then
									draggingChannel =
										true

									updateChannel(input)
								end
							end
						)
					)

					maid:GiveConnection(
						UserInputService.InputChanged:Connect(
							function(input)
								if draggingChannel
									and (
										input.UserInputType
												== Enum.UserInputType.MouseMovement
											or input.UserInputType
												== Enum.UserInputType.Touch
									)
								then
									updateChannel(
										input
									)
								end
							end
						)
					)

					maid:GiveConnection(
						UserInputService.InputEnded:Connect(
							function(input)
								if input.UserInputType
										== Enum.UserInputType.MouseButton1
									or input.UserInputType
										== Enum.UserInputType.Touch
								then
									draggingChannel =
										false
								end
							end
						)
					)
				end

				controller = makeController(
					root,
					function()
						return value
					end,

					function(nextValue, silent)
						if typeof(nextValue) ~= "Color3" then
							return
						end

						value = nextValue
						render()

						window:SetFlagValue(
							colorConfig.Flag,
							value
						)

						if not silent then
							window:Invoke(
								colorConfig.Callback,
								value
							)
						end
					end,

					function(disabled)
						preview.Active = not disabled
						hexInput.TextEditable =
							not disabled

						root.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				local function setOpen(nextOpen)
					open = nextOpen == true

					if open then
						panel.Visible = true

						window:Tween(panel, 0.14, {
							Size = UDim2.new(
								1,
								0,
								0,
								91
							),
						})
					else
						local tween = window:Tween(
							panel,
							0.12,
							{
								Size = UDim2.new(
									1,
									0,
									0,
									0
								),
							}
						)

						local function finish()
							if not open and panel.Parent then
								panel.Visible = false
							end
						end

						if tween then
							tween.Completed:Connect(
								finish
							)
						else
							finish()
						end
					end
				end

				maid:GiveConnection(
					preview.MouseButton1Click:Connect(
						function()
							if not controller.Disabled then
								setOpen(not open)
							end
						end
					)
				)

				maid:GiveConnection(
					hexInput.FocusLost:Connect(function()
						local parsed = hexToColor(
							hexInput.Text
						)

						if parsed then
							controller:Set(parsed)
						else
							hexInput.Text =
								colorToHex(value)
						end
					end)
				)

				render()

				return register(
					controller,
					colorConfig,
					value
				)
			end

			-- Progress

			function section:AddProgress(progressConfig)
				progressConfig = normalizeConfig(
					progressConfig,
					"Progress"
				)

				local minimum =
					tonumber(progressConfig.Min) or 0

				local maximum =
					tonumber(progressConfig.Max) or 100

				local value = clamp(
					tonumber(progressConfig.Default)
						or minimum,
					minimum,
					maximum
				)

				local row, title = createRow(
					66,
					progressConfig,
					true
				)

				title.Size = UDim2.new(1, -90, 0, 34)
				title.Position = UDim2.fromOffset(12, 2)

				local valueLabel = makeText({
					Font = Enum.Font.GothamBold,
					TextColor3 = window.Theme.Accent,
					TextSize = 10,
					TextXAlignment =
						Enum.TextXAlignment.Right,

					Position = UDim2.new(
						1,
						-82,
						0,
						2
					),

					Size = UDim2.fromOffset(70, 34),
					Parent = row,
				})

				local track = create("Frame", {
					BackgroundColor3 =
						window.Theme.Surface,

					BorderSizePixel = 0,
					Position = UDim2.fromOffset(
						12,
						46
					),

					Size = UDim2.new(1, -24, 0, 8),
					Parent = row,
				})

				addCorner(track, 4)

				local fill = create("Frame", {
					BackgroundColor3 =
						window.Theme.Accent,

					BorderSizePixel = 0,
					Parent = track,
				})

				addCorner(fill, 4)

				window:BindTheme(
					valueLabel,
					"TextColor3",
					"Accent"
				)

				window:BindTheme(
					track,
					"BackgroundColor3",
					"Surface"
				)

				window:BindTheme(
					fill,
					"BackgroundColor3",
					"Accent"
				)

				local controller

				local function render()
					local range = maximum - minimum
					local ratio = range == 0
							and 0
						or (value - minimum) / range

					fill.Size = UDim2.new(
						clamp(ratio, 0, 1),
						0,
						1,
						0
					)

					valueLabel.Text = tostring(
						progressConfig.Prefix or ""
					)
						.. tostring(value)
						.. tostring(
							progressConfig.Suffix
								or "%"
						)
				end

				controller = makeController(
					row,
					function()
						return value
					end,

					function(nextValue, silent)
						value = clamp(
							tonumber(nextValue) or minimum,
							minimum,
							maximum
						)

						render()

						window:SetFlagValue(
							progressConfig.Flag,
							value
						)

						if not silent then
							window:Invoke(
								progressConfig.Callback,
								value
							)
						end
					end,

					function(disabled)
						row.BackgroundTransparency =
							disabled and 0.35 or 0
					end
				)

				render()

				return register(
					controller,
					progressConfig,
					value
				)
			end

			-- Label

			function section:AddLabel(labelConfig)
				labelConfig = normalizeConfig(
					labelConfig,
					"Label"
				)

				local value = tostring(
					labelConfig.Text
						or labelConfig.Name
						or "Label"
				)

				local root = create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 30),
					Parent = sectionBody,
				})

				local label = makeText({
					Text = value,
					TextColor3 = window.Theme.Muted,
					TextSize = 11,
					Position = UDim2.fromOffset(4, 0),
					Size = UDim2.new(1, -8, 1, 0),
					Parent = root,
				})

				window:BindTheme(
					label,
					"TextColor3",
					"Muted"
				)

				local controller

				controller = makeController(
					root,
					function()
						return value
					end,

					function(nextValue)
						value = tostring(nextValue or "")
						label.Text = value
					end
				)

				return register(
					controller,
					labelConfig,
					value
				)
			end

			-- Paragraph

			function section:AddParagraph(paragraphConfig)
				paragraphConfig = normalizeConfig(
					paragraphConfig,
					"Paragraph"
				)

				local heading = tostring(
					paragraphConfig.Name
						or paragraphConfig.Title
						or "Information"
				)

				local value = tostring(
					paragraphConfig.Content
						or paragraphConfig.Text
						or ""
				)

				local root = create("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 =
						window.Theme.Surface2,

					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					Parent = sectionBody,
				})

				addCorner(root, 7)
				local paragraphStroke = addStroke(
					root,
					window.Theme.Stroke,
					1,
					0.25
				)

				addPadding(root, 12, 12, 12, 12)
				addList(root, 4)

				local headingLabel = makeText({
					AutomaticSize = Enum.AutomaticSize.Y,
					Font = Enum.Font.GothamBold,
					Text = heading,
					TextColor3 = window.Theme.Text,
					TextSize = 12,
					Size = UDim2.new(1, 0, 0, 18),
					Parent = root,
				})

				local contentLabel = makeText({
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = value,
					TextColor3 = window.Theme.Muted,
					TextSize = 11,
					TextWrapped = true,
					TextYAlignment =
						Enum.TextYAlignment.Top,

					Size = UDim2.new(1, 0, 0, 18),
					Parent = root,
				})

				window:BindTheme(
					root,
					"BackgroundColor3",
					"Surface2"
				)

				window:BindTheme(
					paragraphStroke,
					"Color",
					"Stroke"
				)

				window:BindTheme(
					headingLabel,
					"TextColor3",
					"Text"
				)

				window:BindTheme(
					contentLabel,
					"TextColor3",
					"Muted"
				)

				local controller

				controller = makeController(
					root,
					function()
						return value
					end,

					function(nextValue)
						value = tostring(nextValue or "")
						contentLabel.Text = value
					end
				)

				function controller:SetTitle(nextTitle)
					heading = tostring(nextTitle or "")
					headingLabel.Text = heading
					return self
				end

				return register(
					controller,
					paragraphConfig,
					value
				)
			end

			-- Divider

			function section:AddDivider(dividerConfig)
				dividerConfig = dividerConfig or {}

				local root = create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					Parent = sectionBody,
				})

				local line = create("Frame", {
					BackgroundColor3 =
						window.Theme.Stroke,

					BorderSizePixel = 0,
					Position = UDim2.new(
						0,
						4,
						0.5,
						0
					),

					Size = UDim2.new(1, -8, 0, 1),
					Parent = root,
				})

				window:BindTheme(
					line,
					"BackgroundColor3",
					"Stroke"
				)

				local controller = makeController(root)

				return register(
					controller,
					dividerConfig,
					nil
				)
			end

			table.insert(self.Sections, section)
			return section
		end

		if not self.SelectedTab then
			self:SelectTab(tab)
		end

		if not tab.Internal and not self.FirstUserTab then
			self.FirstUserTab = tab
			self:SelectTab(tab)
		end

		self:UpdateResponsive()
		self:UpdateTabStyles()

		return tab
	end

	--// Search tabs

	maid:GiveConnection(searchBox:GetPropertyChangedSignal(
		"Text"
	):Connect(function()
		local query = string.lower(searchBox.Text)

		for _, tab in ipairs(window.Tabs) do
			tab.Button.Visible = query == ""
				or string.find(
					string.lower(tab.Name),
					query,
					1,
					true
				) ~= nil
		end
	end))

	--// Config

	function window:CanSaveConfig()
		return canUseFiles()
	end

	function window:SaveConfig()
		if not self.ConfigEnabled then
			return false, "Config saving is disabled."
		end

		if not self:CanSaveConfig() then
			return false, "File APIs are unavailable."
		end

		local payload = {
			Version = VERSION,
			Theme = self.ThemeName,
			ToggleKey = self.ToggleKey.Name,
			Scale = self.Scale,
			ReducedMotion = self.ReducedMotion,
			DimBackground = self.DimBackground,
			Flags = serializeValue(self.Flags),
		}

		local encodeOk, encoded = pcall(
			HttpService.JSONEncode,
			HttpService,
			payload
		)

		if not encodeOk then
			return false, tostring(encoded)
		end

		if type(Runtime.MakeFolder) == "function" then
			local createFolder = true

			if type(Runtime.IsFolder) == "function" then
				local checked, exists = pcall(
					Runtime.IsFolder,
					self.ConfigFolder
				)

				createFolder = not checked or not exists
			end

			if createFolder then
				pcall(
					Runtime.MakeFolder,
					self.ConfigFolder
				)
			end
		end

		local writeOk, writeError = pcall(
			Runtime.WriteFile,
			configPath(),
			encoded
		)

		if not writeOk then
			return false, tostring(writeError)
		end

		return true, configPath()
	end

	function window:LoadConfig()
		if not self.ConfigEnabled then
			return false, "Config loading is disabled."
		end

		if not self:CanSaveConfig() then
			return false, "File APIs are unavailable."
		end

		local data = readSavedData()

		if type(data) ~= "table" then
			return false, "No valid config was found."
		end

		if data.Theme then
			self:SetTheme(data.Theme)
		end

		if type(data.ToggleKey) == "string"
			and Enum.KeyCode[data.ToggleKey]
		then
			self:SetToggleKey(
				Enum.KeyCode[data.ToggleKey]
			)
		end

		if data.Scale then
			self:SetScale(data.Scale)
		end

		self.ReducedMotion =
			data.ReducedMotion == true

		self:SetDimBackground(
			data.DimBackground ~= false
		)

		local loadedFlags = deserializeValue(
			data.Flags or {}
		)

		for flag, value in pairs(loadedFlags) do
			local controller = self.FlagControls[flag]

			if controller then
				controller:Set(value, true)
			else
				self.Flags[flag] = value
				self.PendingFlags[flag] = value
			end
		end

		return true, configPath()
	end

	function window:ResetConfig()
		for flag, defaultValue in pairs(self.Defaults) do
			local controller = self.FlagControls[flag]

			if controller then
				controller:Set(defaultValue)
			else
				self.Flags[flag] = defaultValue
			end
		end

		self:SetTheme(config.Theme or "Carbon")
		self:SetToggleKey(
			config.ToggleKey or Enum.KeyCode.RightShift
		)

		self:SetScale(config.Scale or 1)

		self.ReducedMotion =
			config.ReducedMotion == true

		self:SetDimBackground(
			config.DimBackground ~= false
		)

		return self
	end

	--// Built-in settings

	local settingsTab = window:CreateTab({
		Name = "Settings",
		Internal = true,
	})

	local appearanceSection = settingsTab:CreateSection({
		Name = "Appearance",
	})

	window.SettingsThemeControl =
		appearanceSection:AddDropdown({
			Name = "Theme",
			Options = themeNames(),
			Default = window.ThemeName,

			Callback = function(nextTheme)
				window:SetTheme(nextTheme)
			end,
		})

	appearanceSection:AddSlider({
		Name = "UI scale",
		Min = 0.75,
		Max = 1.25,
		Default = window.Scale,
		Increment = 0.05,

		Callback = function(scale)
			window:SetScale(scale)
		end,
	})

	appearanceSection:AddKeybind({
		Name = "Toggle key",
		Default = window.ToggleKey,

		Callback = function(keyCode)
			window:SetToggleKey(keyCode)
		end,
	})

	appearanceSection:AddToggle({
		Name = "Reduced motion",
		Description = "Disables optional UI transitions.",
		Default = window.ReducedMotion,

		Callback = function(enabled)
			window.ReducedMotion = enabled
		end,
	})

	appearanceSection:AddToggle({
		Name = "Dim background",
		Description = "Darkens the game behind the menu.",
		Default = window.DimBackground,

		Callback = function(enabled)
			window:SetDimBackground(enabled)
		end,
	})

	local configSection = settingsTab:CreateSection({
		Name = "Configuration",
	})

	configSection:AddParagraph({
		Name = "Persistence",
		Content = window:CanSaveConfig()
				and "File APIs detected. Settings and flags can be saved."
			or "File APIs are unavailable. Values remain in memory.",
	})

	configSection:AddButton({
		Name = "Save configuration",
		ButtonText = "Save",

		Callback = function()
			local ok, message = window:SaveConfig()

			window:Notify({
				Title = ok and "Configuration saved"
					or "Save unavailable",

				Content = message,
				Type = ok and "Success" or "Warning",
			})
		end,
	})

	configSection:AddButton({
		Name = "Load configuration",
		ButtonText = "Load",

		Callback = function()
			local ok, message = window:LoadConfig()

			window:Notify({
				Title = ok and "Configuration loaded"
					or "Load unavailable",

				Content = message,
				Type = ok and "Success" or "Warning",
			})
		end,
	})

	configSection:AddButton({
		Name = "Reset interface",
		ButtonText = "Reset",

		Callback = function()
			window:Dialog({
				Title = "Reset interface",
				Content = "Reset themes, controls and interface settings to their defaults?",
				ConfirmText = "Reset",

				OnConfirm = function()
					window:ResetConfig()

					window:Notify({
						Title = "Interface reset",
						Content = "Default values were restored.",
						Type = "Success",
					})
				end,
			})
		end,
	})

	--// Destroy

	function window:Destroy()
		if self.Destroyed then
			return
		end

		self.Destroyed = true

		if registry[windowId] == self then
			registry[windowId] = nil
		end

		local index = table.find(
			self.Library.Windows,
			self
		)

		if index then
			table.remove(self.Library.Windows, index)
		end

		if self.Library.ActiveWindow == self then
			self.Library.ActiveWindow =
				self.Library.Windows[
					#self.Library.Windows
				]
		end

		self.Maid:Cleanup()
	end

	registry[windowId] = window

	window:UpdateResponsive()
	window:UpdateTabStyles()

	main.GroupTransparency = 1
	shadow.BackgroundTransparency = 1

	window:Tween(main, 0.16, {
		GroupTransparency = 0,
	})

	window:Tween(shadow, 0.16, {
		BackgroundTransparency = 0.3,
	})

	return window
end

--// Library-level helpers

function Library:Notify(config)
	if self.ActiveWindow
		and not self.ActiveWindow.Destroyed
	then
		return self.ActiveWindow:Notify(config)
	end

	return nil
end

function Library:Dialog(config)
	if self.ActiveWindow
		and not self.ActiveWindow.Destroyed
	then
		return self.ActiveWindow:Dialog(config)
	end

	return nil
end

function Library:DestroyAll()
	local windows = {}

	for _, window in ipairs(self.Windows) do
		table.insert(windows, window)
	end

	for _, window in ipairs(windows) do
		window:Destroy()
	end
end

return Library
