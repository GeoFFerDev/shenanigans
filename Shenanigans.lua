--[[
    Imp Hub X - Version 4 (Android Focused)
    Whole script with clear PART sections.

    Notes:
    - Built from your template style and screenshot layout.
    - Android friendly: responsive sizing, touch drag, scalable UI.
    - Fixed grouping overflow with scrollable sidebar + scrollable tab bodies.
    - Feature logic included as safe scaffolding (you can wire your own remotes).
]]

-- ==========================================
-- PART 1: Services, Mount, Theme, State
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() LocalPlayer.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

local ParentGui = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or LocalPlayer:WaitForChild("PlayerGui")

if not ParentGui then
    return
end

if ParentGui:FindFirstChild("ImpHubX_V4") then
    ParentGui.ImpHubX_V4:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ImpHubX_V4"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

local Theme = {
    BG = Color3.fromRGB(18, 19, 25),
    Sidebar = Color3.fromRGB(15, 16, 21),
    Panel = Color3.fromRGB(23, 24, 31),
    Stroke = Color3.fromRGB(63, 64, 80),
    Accent = Color3.fromRGB(170, 72, 255),
    Text = Color3.fromRGB(239, 240, 244),
    SubText = Color3.fromRGB(160, 161, 176),
    Success = Color3.fromRGB(83, 210, 120),
    Danger = Color3.fromRGB(255, 90, 90)
}

local State = {
    Toggles = {
        Farming = false,
        EnableFarm = false,
        FastAttack = true,
        UseSkills = true,
        FaceAtTarget = true,

        Blocking = true,
        AutoBlock = true,
        AutoPunish = true,
        FaceAttacker = true,
        ShowRange = false,

        Aimlock = false,
        ESP = false,
        Boxes = true,
        Tracers = true,
        TeamCheck = false,
    },
    Farming = {
        TargetMethod = "Closest", -- Closest / Lowest Health / Camera
        DetectionRange = 20,
        BlockDelay = 0,
    },
    Aim = {
        Mode = "Camera",
        TargetPart = "Head",
        Prediction = 0.135,
        Smoothness = 0.17,
    },
    Runtime = {
        Target = nil,
        LastBlock = 0,
        Status = "[ DISABLED ]"
    }
}

-- ==========================================
-- PART 2: Utility + Mechanics (Scaffold)
-- ==========================================
local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(player)
    local c = getCharacter(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
    local c = getCharacter(player)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isValidTarget(player)
    if not player or player == LocalPlayer then
        return false
    end

    if State.Toggles.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end

    local hum = getHumanoid(player)
    local root = getRoot(player)
    return hum and root and hum.Health > 0
end

local function distanceTo(player)
    local localRoot = getRoot(LocalPlayer)
    local targetRoot = getRoot(player)
    if not localRoot or not targetRoot then
        return math.huge
    end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function chooseTarget(method)
    local candidates = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            local dist = distanceTo(plr)
            if dist <= State.Farming.DetectionRange then
                table.insert(candidates, {Player = plr, Distance = dist})
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    if method == "Closest" then
        table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
        return candidates[1].Player
    end

    if method == "Lowest Health" then
        table.sort(candidates, function(a, b)
            return getHumanoid(a.Player).Health < getHumanoid(b.Player).Health
        end)
        return candidates[1].Player
    end

    -- Camera mode
    local center = Camera.ViewportSize / 2
    local best, bestScore = nil, math.huge

    for _, entry in ipairs(candidates) do
        local root = getRoot(entry.Player)
        if root then
            local p, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local delta = (Vector2.new(p.X, p.Y) - center).Magnitude
                local score = delta + (entry.Distance * 0.35)
                if score < bestScore then
                    bestScore = score
                    best = entry.Player
                end
            end
        end
    end

    return best
end

local function predictedPosition(part)
    local t = State.Aim.Prediction
    local vel = part.AssemblyLinearVelocity
    local gravity = Workspace.Gravity

    local pos = part.Position + vel * t

    -- slight gravity compensation for non-root aiming
    if State.Aim.TargetPart ~= "HumanoidRootPart" then
        pos += Vector3.new(0, -0.5 * gravity * (t * t) * 0.06, 0)
    end

    return pos
end

-- ==========================================
-- PART 3: Android-Responsive Window Base
-- ==========================================
local function getWindowSize()
    local view = Camera.ViewportSize

    -- Android/tablet safe bounds
    local width = math.clamp(math.floor(view.X * 0.90), 700, 1150)
    local height = math.clamp(math.floor(view.Y * 0.82), 410, 700)

    return width, height
end

local W, H = getWindowSize()

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(W, H)
Main.Position = UDim2.fromScale(0.5, 0.5) - UDim2.fromOffset(W / 2, H / 2)
Main.BackgroundColor3 = Theme.BG
Main.BackgroundTransparency = 0.07
Main.Parent = ScreenGui
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Theme.Stroke
MainStroke.Transparency = 0.30

local UIScale = Instance.new("UIScale")
UIScale.Parent = Main

local function refreshScale()
    local sx = Camera.ViewportSize.X / 1280
    local sy = Camera.ViewportSize.Y / 720
    UIScale.Scale = math.clamp(math.min(sx, sy), 0.75, 1.0)
end

refreshScale()
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local newW, newH = getWindowSize()
    Main.Size = UDim2.fromOffset(newW, newH)
    refreshScale()
end)

local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 38)
Topbar.BackgroundTransparency = 1
Topbar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "Imp Hub X"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamSemibold
Title.TextColor3 = Theme.Text
Title.TextSize = 15
Title.Parent = Topbar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -120, 0, 14)
Subtitle.Position = UDim2.fromOffset(14, 22)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Jujutsu Shenanigans - Version 4"
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextColor3 = Theme.SubText
Subtitle.TextSize = 11
Subtitle.Parent = Topbar

local MinimizedButton = Instance.new("TextButton")
MinimizedButton.Size = UDim2.fromOffset(46, 46)
MinimizedButton.Position = UDim2.new(0.5, -23, 0.04, 0)
MinimizedButton.BackgroundColor3 = Theme.BG
MinimizedButton.Text = "🜲"
MinimizedButton.TextColor3 = Theme.Text
MinimizedButton.TextSize = 22
MinimizedButton.Visible = false
MinimizedButton.Parent = ScreenGui
Instance.new("UICorner", MinimizedButton).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", MinimizedButton).Color = Theme.Accent

local function makeTopButton(text, xOff, color, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 24)
    b.Position = UDim2.new(1, xOff, 0.5, -12)
    b.BackgroundColor3 = Theme.Panel
    b.Text = text
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = Topbar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(callback)
end

makeTopButton("✕", -40, Theme.Danger, function() ScreenGui:Destroy() end)
makeTopButton("—", -76, Theme.Text, function()
    Main.Visible = false
    MinimizedButton.Visible = true
end)

MinimizedButton.MouseButton1Click:Connect(function()
    Main.Visible = true
    MinimizedButton.Visible = false
end)

-- touch/mouse drag
local function enableDrag(frame, dragHandle)
    local dragging = false
    local dragStart, startPos, dragInput

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

enableDrag(Main, Topbar)
enableDrag(MinimizedButton, MinimizedButton)

-- ==========================================
-- PART 4: Sidebar + Tabs (Scrollable Grouping Fix)
-- ==========================================
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, 220, 1, -48)
Sidebar.Position = UDim2.fromOffset(10, 38)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.30
Sidebar.ScrollBarThickness = 2
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new()
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

local SidebarPad = Instance.new("UIPadding", Sidebar)
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.PaddingBottom = UDim.new(0, 10)
SidebarPad.PaddingLeft = UDim.new(0, 8)
SidebarPad.PaddingRight = UDim.new(0, 8)

local SidebarList = Instance.new("UIListLayout", Sidebar)
SidebarList.Padding = UDim.new(0, 7)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, -240, 1, -48)
Body.Position = UDim2.fromOffset(230, 38)
Body.BackgroundTransparency = 1
Body.Parent = Main

local Tabs = {}
local TabButtons = {}

local function createTab(tabName, icon)
    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Size = UDim2.new(1, 0, 1, 0)
    tabFrame.BackgroundTransparency = 1
    tabFrame.ScrollBarThickness = 2
    tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabFrame.CanvasSize = UDim2.new()
    tabFrame.Visible = false
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = Body

    local pad = Instance.new("UIPadding", tabFrame)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 4)

    local list = Instance.new("UIListLayout", tabFrame)
    list.Padding = UDim.new(0, 9)

    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 34)
    tabBtn.BackgroundColor3 = Theme.Panel
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = string.format("  %s  %s", icon, tabName)
    tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 13
    tabBtn.TextColor3 = Theme.SubText
    tabBtn.Parent = Sidebar
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)

    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 4, 0.6, 0)
    marker.Position = UDim2.new(0, 2, 0.2, 0)
    marker.BackgroundColor3 = Theme.Accent
    marker.Visible = false
    marker.Parent = tabBtn
    Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)

    tabBtn.MouseButton1Click:Connect(function()
        for _, data in ipairs(Tabs) do
            data.Frame.Visible = false
        end
        for _, data in ipairs(TabButtons) do
            data.Button.BackgroundTransparency = 1
            data.Button.TextColor3 = Theme.SubText
            data.Marker.Visible = false
        end

        tabFrame.Visible = true
        tabBtn.BackgroundTransparency = 0.35
        tabBtn.TextColor3 = Theme.Text
        marker.Visible = true
    end)

    table.insert(Tabs, {Frame = tabFrame})
    table.insert(TabButtons, {Button = tabBtn, Marker = marker})

    return tabFrame
end

local function createPanel(parent, title, toggleKey)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -6, 0, 44)
    panel.BackgroundColor3 = Theme.Panel
    panel.BackgroundTransparency = 0.10
    panel.Parent = parent
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", panel).Color = Theme.Stroke

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.fromOffset(12, 4)
    header.BackgroundTransparency = 1
    header.Text = title
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 15
    header.TextColor3 = Theme.Text
    header.Parent = panel

    if toggleKey then
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.fromOffset(44, 20)
        toggle.Position = UDim2.new(1, -54, 0.5, -10)
        toggle.Text = ""
        toggle.BackgroundColor3 = Color3.fromRGB(58, 58, 68)
        toggle.Parent = panel
        toggle.AutoButtonColor = false
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16, 16)
        knob.Position = UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Theme.Text
        knob.Parent = toggle
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function syncToggle()
            local on = State.Toggles[toggleKey]
            toggle.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(58, 58, 68)
            knob.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end

        syncToggle()
        toggle.MouseButton1Click:Connect(function()
            State.Toggles[toggleKey] = not State.Toggles[toggleKey]
            syncToggle()
        end)
    end

    local lineY = 36
    local function addLine(text, color, size)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -18, 0, size or 20)
        t.Position = UDim2.fromOffset(10, lineY)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Font = Enum.Font.Gotham
        t.TextSize = 13
        t.TextColor3 = color or Theme.SubText
        t.Parent = panel

        lineY += (size or 20)
        panel.Size = UDim2.new(1, -6, 0, lineY + 8)
        return t
    end

    return panel, addLine
end

-- ==========================================
-- PART 5: Build Screenshot-Like Sections
-- ==========================================
local TabCombat = createTab("Combat & Auto Farm", "⚔️")
local TabVisuals = createTab("ESP Engine", "👁️")
local TabMisc = createTab("Miscellaneous", "🧩")
local TabSettings = createTab("Credits & Settings", "⚙️")

local farmingPanel, farmLine = createPanel(TabCombat, "Farming", "Farming")
farmLine("Select Target Method: " .. State.Farming.TargetMethod)
farmLine("Force At Target / Fast Attack / Use Skills")
farmLine("EnableFarm gate: " .. tostring(State.Toggles.EnableFarm), Theme.Text)
farmLine("Detection Range: " .. State.Farming.DetectionRange .. " studs")

local blockPanel, blockLine = createPanel(TabCombat, "Blocking", "Blocking")
blockLine("Enable Auto Block")
blockLine("Auto Punish (Attack Back)")
blockLine("Face Attacker")
blockLine("Block Delay: " .. State.Farming.BlockDelay .. "s", Theme.Text)

local aimPanel, aimLine = createPanel(TabCombat, "Aimlock", "Aimlock")
aimLine("Mode: " .. State.Aim.Mode)
aimLine("Target Part: " .. State.Aim.TargetPart)
aimLine("Prediction: " .. string.format("%.3f", State.Aim.Prediction))
aimLine("Smoothness: " .. string.format("%.2f", State.Aim.Smoothness), Theme.Text)

local statusPanel, statusLine = createPanel(TabCombat, "Status", nil)
statusLine("System Status", Theme.Text)
local statusValue = statusLine(State.Runtime.Status, Theme.Danger, 24)
statusValue.Font = Enum.Font.GothamBold
statusLine("Wait for activation...")

local espPanel, espLine = createPanel(TabVisuals, "Configurations", "ESP")
espLine("Box: " .. tostring(State.Toggles.Boxes))
espLine("Tracers: " .. tostring(State.Toggles.Tracers))
espLine("Team Check: " .. tostring(State.Toggles.TeamCheck))
espLine("Health Bar / Name / Distance can be added here", Theme.Text)

local miscPanel, miscLine = createPanel(TabMisc, "Misc", nil)
miscLine("Android-friendly scalable UI enabled")
miscLine("Scrollable categories fixed")
miscLine("Add your extra tools inside this tab", Theme.Text)

local settingsPanel, settingsLine = createPanel(TabSettings, "Credits", nil)
settingsLine("UI Template: Fluent style")
settingsLine("Version: V4 Android")
settingsLine("Wire game remotes where noted below", Theme.Text)

-- ==========================================
-- PART 6: Runtime Loop (Mechanic Scaffolding)
-- ==========================================
local function setStatus(enabled)
    State.Runtime.Status = enabled and "[ ENABLED ]" or "[ DISABLED ]"
    statusValue.Text = State.Runtime.Status
    statusValue.TextColor3 = enabled and Theme.Success or Theme.Danger
end

RunService.Heartbeat:Connect(function(dt)
    local target = chooseTarget(State.Farming.TargetMethod)
    State.Runtime.Target = target

    local active = State.Toggles.Farming or State.Toggles.Blocking or State.Toggles.Aimlock
    setStatus(active)

    if target and State.Toggles.Farming and State.Toggles.EnableFarm then
        local localRoot = getRoot(LocalPlayer)
        local targetRoot = getRoot(target)

        if localRoot and targetRoot and State.Toggles.FaceAtTarget then
            local desired = CFrame.lookAt(localRoot.Position, targetRoot.Position)
            localRoot.CFrame = localRoot.CFrame:Lerp(desired, math.clamp(7 * dt, 0, 1))
        end

        -- TODO: place your attack/skill remote logic here
    end

    if target and State.Toggles.Aimlock then
        local ch = target.Character
        local part = ch and ch:FindFirstChild(State.Aim.TargetPart)
        if part then
            local pred = predictedPosition(part)
            local cam = Camera.CFrame
            local goal = CFrame.lookAt(cam.Position, pred)
            Camera.CFrame = cam:Lerp(goal, State.Aim.Smoothness)
        end
    end

    if target and State.Toggles.Blocking and State.Toggles.AutoBlock then
        local now = tick()
        if (now - State.Runtime.LastBlock) >= State.Farming.BlockDelay then
            if distanceTo(target) <= State.Farming.DetectionRange then
                State.Runtime.LastBlock = now
                -- TODO: place your block remote logic here
            end
        end
    end
end)

-- open first tab by default
if TabButtons[1] then
    TabButtons[1].Button.MouseButton1Click:Fire()
end
