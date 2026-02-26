--[[
  IMP HUB X  v7  —  Jujutsu Shenanigans
  UI: Fluent Local (400x260, exact template)
  Game logic rebuilt from SafeScriptDump analysis:
    • Characters in workspace.Characters
    • Attack  → Knit.GetService(Moveset.."Service").Activated:Fire(isAir)
    • Block   → BlockService.Activated/Deactivated:Fire()
    • Skills  → Character.Moveset children (Key+Service attrs)
    • Dead    → Character:GetAttribute("Dead")
    • Ragdoll → Character:GetAttribute("Ragdoll") > 0
  Toggle GUI: RightShift
]]

-- ══════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- ══════════════════════════════════════════════
-- KNIT ACCESS  (from dump: require(RS.Knit.Knit))
-- ══════════════════════════════════════════════
local Knit = nil
pcall(function()
    Knit = require(game.ReplicatedStorage.Knit.Knit)
end)

local function GetKnitService(name)
    if not Knit then return nil end
    local ok, svc = pcall(function() return Knit.GetService(name) end)
    return ok and svc or nil
end

-- Cache services after character loads (Knit needs to be started first)
local BlockSvc      = nil
local function EnsureServices()
    if not BlockSvc  then BlockSvc  = GetKnitService("BlockService") end
end

-- ══════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════
local Cfg = {
    Farm   = { Enabled=false, TargetMethod="Closest",
               FaceTarget=true, FastAttack=true, UseSkills=true },
    Block  = { Enabled=false, AutoBlock=true, AutoPunish=true,
               FaceAttacker=true, DetectRange=20, BlockDelay=0 },
    Aim    = { Enabled=false, Mode="Camera", TargetPart="Head", Prediction=false },
    Combat = { TpMethod="Tween", MoveMode="Orbit", TweenSpeed=135,
               FollowDist=4, SmartKiting=true, AutoFlee=false, FleeHP=20,
               SkillDelay=0, AvoidNoTarget=true, SemiKillAura=false, SpinBot=false },
    ESP    = { Enabled=false, Box=true, Tracers=true, HealthBar=true,
               Distance=true, Name=true, Moveset=true },
    Misc   = { AntiRagdoll=false, AutoTech=false, WsBypass=false, Speed=100,
               InfJump=false, Fullbright=false, WhiteScreen=false,
               AntiAFK=true, ClickTP=false, TimeHour=14 },
}

-- ══════════════════════════════════════════════
-- GAME HELPERS  (workspace.Characters confirmed from dump)
-- ══════════════════════════════════════════════
local CharsFolder = workspace:FindFirstChild("Characters") or workspace

local function GetChar(p)
    -- Characters are in workspace.Characters per dump line 14147
    if p == LP then return LP.Character end
    local c = CharsFolder:FindFirstChild(p.Name)
    return c or p.Character
end
local function Root(p)
    local c = GetChar(p)
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function Hum(p)
    local c = GetChar(p)
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function Alive(p)
    -- From dump: character:GetAttribute("Dead") is the death flag
    local c = GetChar(p)
    if not c then return false end
    if c:GetAttribute("Dead") then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function Dist(p)
    local a, b = Root(LP), Root(p)
    return (a and b) and (a.Position - b.Position).Magnitude or math.huge
end

local function GetEnemies()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and Alive(p) then t[#t+1] = p end
    end
    return t
end

local function GetTarget()
    local enemies = GetEnemies()
    if #enemies == 0 then return nil end
    local m = Cfg.Farm.TargetMethod
    if m == "Closest"  then table.sort(enemies, function(a,b) return Dist(a)<Dist(b) end)
    elseif m == "Furthest" then table.sort(enemies, function(a,b) return Dist(a)>Dist(b) end)
    elseif m == "Random"   then return enemies[math.random(1,#enemies)]
    elseif m == "Most HP"  then table.sort(enemies, function(a,b)
        local ha,hb = Hum(a),Hum(b)
        return (ha and ha.Health or 0) > (hb and hb.Health or 0) end)
    elseif m == "Least HP" then table.sort(enemies, function(a,b)
        local ha,hb = Hum(a),Hum(b)
        return (ha and ha.Health or 1e9) < (hb and hb.Health or 1e9) end)
    end
    return enemies[1]
end

local function FaceTarget(tgt)
    local r, tr = Root(LP), Root(tgt)
    if r and tr then
        r.CFrame = CFrame.new(r.Position,
            Vector3.new(tr.Position.X, r.Position.Y, tr.Position.Z))
    end
end

local orbitAngle = 0
local function OrbitTarget(tgt)
    local r, tr = Root(LP), Root(tgt)
    if not r or not tr then return end
    orbitAngle = orbitAngle + 0.06
    local d = Cfg.Combat.FollowDist + 1.5
    local ox = tr.Position.X + math.cos(orbitAngle) * d
    local oz = tr.Position.Z + math.sin(orbitAngle) * d
    r.CFrame = CFrame.new(ox, tr.Position.Y, oz)
           * CFrame.Angles(0, math.atan2(tr.Position.X - ox, tr.Position.Z - oz), 0)
end

local function MoveToTarget(tgt)
    local r, tr = Root(LP), Root(tgt)
    if not r or not tr then return end
    local dir = (r.Position - tr.Position).Unit
    local cf  = CFrame.new(tr.Position + dir * Cfg.Combat.FollowDist)
              * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
    local m = Cfg.Combat.TpMethod
    if m == "Instant" then r.CFrame = cf
    elseif m == "Lerp" then r.CFrame = r.CFrame:Lerp(cf, 0.25)
    else
        TweenService:Create(r, TweenInfo.new(
            math.clamp((r.Position-cf.Position).Magnitude/Cfg.Combat.TweenSpeed, 0.04, 1.5),
            Enum.EasingStyle.Linear), {CFrame=cf}):Play()
    end
end

-- ══════════════════════════════════════════════
-- ATTACK  (from dump: Knit MovesetsService.Activated:Fire(isAir))
-- Fallback: simulate MouseButton1 via UIS
-- ══════════════════════════════════════════════
local lastAtkTime = 0

local function DoAttack()
    if tick() - lastAtkTime < 0.12 then return end
    lastAtkTime = tick()
    local myChar = LP.Character
    if not myChar then return end

    pcall(function()
        local moveset = myChar:GetAttribute("Moveset")
        if moveset and moveset ~= "" then
            local svc = GetKnitService(moveset .. "Service")
            if svc and svc.Activated then
                local isAir = myChar:FindFirstChildOfClass("Humanoid") and
                              myChar:FindFirstChildOfClass("Humanoid").FloorMaterial == Enum.Material.Air
                svc.Activated:Fire(isAir and "Down" or false)
                return
            end
        end
    end)

    -- Fallback: fire via UIS simulation
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.delay(0.05, function()
            pcall(function()
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end)
end

-- ══════════════════════════════════════════════
-- BLOCK  (from dump: BlockService.Activated:Fire(target) / .Deactivated:Fire())
-- ══════════════════════════════════════════════
local isBlocking = false

local function SetBlock(on, targetChar)
    if isBlocking == on then return end
    isBlocking = on
    EnsureServices()
    pcall(function()
        if on then
            -- BlockService.Activated:Fire(target) — target is the character model
            if BlockSvc and BlockSvc.Activated then
                BlockSvc.Activated:Fire(targetChar)
            end
        else
            -- BlockService.Deactivated:Fire() — no args
            if BlockSvc and BlockSvc.Deactivated then
                BlockSvc.Deactivated:Fire()
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- SKILLS  (from dump: Character.Moveset children, Key+Service attrs)
-- Fire Knit.GetService(skill:GetAttribute("Service"))[skill.Name]:Fire(...)
-- ══════════════════════════════════════════════
local lastSkillTime = 0

local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    local delay = math.max(0, Cfg.Combat.SkillDelay)
    if tick() - lastSkillTime < delay then return end
    if Cfg.Combat.AvoidNoTarget and not tgt then return end

    local myChar = LP.Character
    if not myChar then return end
    local movesetFolder = myChar:FindFirstChild("Moveset")
    if not movesetFolder then return end

    -- Collect available skills from Character.Moveset folder
    local skills = {}
    for _, skill in ipairs(movesetFolder:GetChildren()) do
        local svcName = skill:GetAttribute("Service")
        local key     = skill:GetAttribute("Key")
        -- Skip if in cooldown (Info folder has skill name present when on CD)
        local info = myChar:FindFirstChild("Info")
        local onCD = info and info:GetAttribute("CD")
        if svcName and key and not onCD then
            skills[#skills+1] = skill
        end
    end

    if #skills == 0 then return end
    lastSkillTime = tick()

    -- Pick a random available skill and fire it
    local chosen = skills[math.random(1, #skills)]
    pcall(function()
        local svcName = chosen:GetAttribute("Service")
        local svc = GetKnitService(svcName)
        if svc then
            local tgtChar = tgt and GetChar(tgt)
            -- Activated is the standard signal name from dump
            if svc.Activated then
                svc.Activated:Fire(tgtChar)
            elseif svc[chosen.Name] then
                svc[chosen.Name]:Fire(tgtChar)
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- ONE-SHOT MISC FEATURES
-- ══════════════════════════════════════════════
local speedBV = nil
local function SetSpeedBypass(on)
    local r = Root(LP)
    if not r then return end
    if on then
        if not speedBV then
            speedBV = Instance.new("BodyVelocity")
            speedBV.MaxForce = Vector3.new(1e4, 0, 1e4)
            speedBV.Velocity  = Vector3.new(0, 0, 0)
            speedBV.Parent    = r
        end
    else
        if speedBV then speedBV:Destroy(); speedBV = nil end
    end
end

local jumpConn = nil
local function SetInfJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if on then
        jumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Hum(LP)
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local origAmb, origBrt = nil, nil
local function SetFullbright(on)
    if on then
        origAmb = Lighting.Ambient
        origBrt = Lighting.Brightness
        Lighting.Ambient    = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd     = 1e6
    else
        if origAmb then
            Lighting.Ambient    = origAmb
            Lighting.Brightness = origBrt or 1
        end
    end
end

local wsGui = nil
local function SetWhiteScreen(on)
    if wsGui then wsGui:Destroy(); wsGui = nil end
    if on then
        wsGui = Instance.new("ScreenGui", LP.PlayerGui)
        wsGui.Name = "ImpHubXWS"; wsGui.ResetOnSpawn = false
        local f = Instance.new("Frame", wsGui)
        f.Size = UDim2.new(1,0,1,0)
        f.BackgroundColor3 = Color3.new(1,1,1)
        f.BackgroundTransparency = 0.35
        f.BorderSizePixel = 0
    end
end

local ctpConn = nil
local function SetClickTP(on)
    if ctpConn then ctpConn:Disconnect(); ctpConn = nil end
    if on then
        ctpConn = UserInputService.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local r = Root(LP)
                if r then
                    r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
                end
            end
        end)
    end
end

local spinConn = nil
local function SetSpinBot(on)
    if spinConn then spinConn:Disconnect(); spinConn = nil end
    if on then
        spinConn = RunService.RenderStepped:Connect(function()
            local r = Root(LP)
            if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(18), 0) end
        end)
    end
end

local killConn = nil
local function SetKillAura(on)
    if killConn then killConn:Disconnect(); killConn = nil end
    if on then
        local lkA = 0
        killConn = RunService.Heartbeat:Connect(function()
            if tick() - lkA < 0.12 then return end
            lkA = tick()
            for _, e in ipairs(GetEnemies()) do
                if Dist(e) <= 25 then DoAttack() end
            end
        end)
    end
end

local specConn = nil
local function SpectatePlayer(tgt)
    if specConn then specConn:Disconnect(); specConn = nil end
    if not tgt then return end
    Camera.CameraType = Enum.CameraType.Scriptable
    specConn = RunService.RenderStepped:Connect(function()
        local tr = Root(tgt)
        if tr then
            Camera.CFrame = CFrame.new(tr.Position + Vector3.new(0, 6, 14), tr.Position)
        end
    end)
end
local function StopSpec()
    if specConn then specConn:Disconnect(); specConn = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

-- ══════════════════════════════════════════════
-- MOUNT  (exact template pattern)
-- ══════════════════════════════════════════════
pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() LP.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

local TargetParent = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or LP:WaitForChild("PlayerGui")
if not TargetParent then return end

local _old = TargetParent:FindFirstChild("ImpHubXv7")
if _old then _old:Destroy() end

local ScreenGui = Instance.new("ScreenGui", TargetParent)
ScreenGui.Name           = "ImpHubXv7"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true

-- ══════════════════════════════════════════════
-- THEME  (template colours)
-- ══════════════════════════════════════════════
local Theme = {
    Background = Color3.fromRGB(24, 24, 28),
    Sidebar    = Color3.fromRGB(18, 18, 22),
    Accent     = Color3.fromRGB(110, 45, 220),
    AccentLt   = Color3.fromRGB(150, 80, 255),
    Text       = Color3.fromRGB(240, 240, 240),
    SubText    = Color3.fromRGB(150, 150, 150),
    Button     = Color3.fromRGB(35, 35, 40),
    Stroke     = Color3.fromRGB(60, 60, 65),
    Green      = Color3.fromRGB(50, 210, 85),
    Red        = Color3.fromRGB(235, 60, 60),
}

-- ══════════════════════════════════════════════
-- TOGGLE ICON  (exact template)
-- ══════════════════════════════════════════════
local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size                  = UDim2.new(0, 45, 0, 45)
ToggleIcon.Position              = UDim2.new(0.5, -22, 0.05, 0)
ToggleIcon.BackgroundColor3      = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text      = "⚔"
ToggleIcon.TextSize  = 22
ToggleIcon.TextColor3 = Theme.Text
ToggleIcon.Font      = Enum.Font.GothamBold
ToggleIcon.Visible   = false
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1, 0)
local _is = Instance.new("UIStroke", ToggleIcon)
_is.Color = Theme.Accent; _is.Thickness = 2

-- ══════════════════════════════════════════════
-- MAIN FRAME  (exact template: 400x260)
-- ══════════════════════════════════════════════
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size               = UDim2.new(0, 400, 0, 260)
MainFrame.Position           = UDim2.new(0.5, -200, 0.5, -130)
MainFrame.BackgroundColor3   = Theme.Background
MainFrame.BackgroundTransparency = 0.1
MainFrame.Active             = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local _ms = Instance.new("UIStroke", MainFrame)
_ms.Color = Theme.Accent; _ms.Transparency = 0.5

-- ══════════════════════════════════════════════
-- TOP BAR  (exact template: 30px transparent)
-- ══════════════════════════════════════════════
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size                  = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", TopBar)
Title.Size               = UDim2.new(0.7, 0, 1, 0)
Title.Position           = UDim2.new(0, 12, 0, 0)
Title.Text               = "Imp Hub X  •  Jujutsu Shenanigans"
Title.Font               = Enum.Font.GothamMedium
Title.TextColor3         = Theme.Text
Title.TextSize           = 11
Title.TextXAlignment     = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local function AddControl(text, pos, col, cb)
    local btn = Instance.new("TextButton", TopBar)
    btn.Size               = UDim2.new(0, 30, 0, 20)
    btn.Position           = pos
    btn.BackgroundColor3   = Theme.Background
    btn.BackgroundTransparency = 1
    btn.Text               = text
    btn.TextColor3         = col
    btn.Font               = Enum.Font.GothamMedium
    btn.TextSize           = 14
    btn.MouseButton1Click:Connect(cb)
end
AddControl("✕", UDim2.new(1,-35,0.5,-10), Color3.fromRGB(255,80,80),
    function() ScreenGui:Destroy() end)
AddControl("—", UDim2.new(1,-70,0.5,-10), Theme.Text,
    function() MainFrame.Visible=false; ToggleIcon.Visible=true end)

ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = true; ToggleIcon.Visible = false
end)

-- ══════════════════════════════════════════════
-- DRAG  (exact template copy)
-- ══════════════════════════════════════════════
local function EnableDrag(obj, handle)
    local drag, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; startPos = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
                  or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

-- ══════════════════════════════════════════════
-- SIDEBAR  (exact template: 110px)
-- ══════════════════════════════════════════════
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size               = UDim2.new(0, 110, 1, -30)
Sidebar.Position           = UDim2.new(0, 0, 0, 30)
Sidebar.BackgroundColor3   = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel    = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding              = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 10)

-- ══════════════════════════════════════════════
-- CONTENT AREA  (exact template)
-- ══════════════════════════════════════════════
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size               = UDim2.new(1, -120, 1, -30)
ContentArea.Position           = UDim2.new(0, 115, 0, 30)
ContentArea.BackgroundTransparency = 1

-- ══════════════════════════════════════════════
-- DROPDOWN OVERLAY
-- ══════════════════════════════════════════════
local DropOverlay = Instance.new("Frame", ScreenGui)
DropOverlay.Size               = UDim2.new(1, 0, 1, 0)
DropOverlay.BackgroundTransparency = 1
DropOverlay.BorderSizePixel    = 0
DropOverlay.ZIndex             = 100
DropOverlay.Active             = false

local openList = nil
local function CloseDrops()
    if openList then openList.Visible = false; openList = nil end
    DropOverlay.Active = false
end
DropOverlay.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        CloseDrops()
    end
end)

-- ══════════════════════════════════════════════
-- TAB SYSTEM  (exact template)
-- ══════════════════════════════════════════════
local Tabs       = {}
local TabButtons = {}

local function CreateTab(name, icon)
    local TabFrame = Instance.new("ScrollingFrame", ContentArea)
    TabFrame.Size               = UDim2.new(1, 0, 1, -10)
    TabFrame.BackgroundTransparency = 1
    TabFrame.ScrollBarThickness = 2
    TabFrame.ScrollBarImageColor3 = Theme.AccentLt
    TabFrame.Visible            = false
    TabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
    TabFrame.BorderSizePixel    = 0

    local Layout = Instance.new("UIListLayout", TabFrame)
    Layout.Padding     = UDim.new(0, 8)
    Layout.SortOrder   = Enum.SortOrder.LayoutOrder
    -- Manual canvas fallback for Delta
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 20)
    end)
    local _tp = Instance.new("UIPadding", TabFrame)
    _tp.PaddingTop = UDim.new(0,5); _tp.PaddingLeft = UDim.new(0,2); _tp.PaddingRight = UDim.new(0,4)

    local TabBtn = Instance.new("TextButton", Sidebar)
    TabBtn.Size               = UDim2.new(0.9, 0, 0, 30)
    TabBtn.BackgroundColor3   = Theme.Accent
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text               = "  " .. icon .. " " .. name
    TabBtn.TextColor3         = Theme.SubText
    TabBtn.Font               = Enum.Font.GothamMedium
    TabBtn.TextSize           = 12
    TabBtn.TextXAlignment     = Enum.TextXAlignment.Left
    TabBtn.AutoButtonColor    = false
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 5)

    local Indicator = Instance.new("Frame", TabBtn)
    Indicator.Size            = UDim2.new(0, 3, 0.6, 0)
    Indicator.Position        = UDim2.new(0, 2, 0.2, 0)
    Indicator.BackgroundColor3 = Theme.Accent
    Indicator.Visible         = false
    Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

    TabBtn.MouseButton1Click:Connect(function()
        CloseDrops()
        for _, t in pairs(Tabs)       do t.Frame.Visible = false end
        for _, b in pairs(TabButtons) do
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3 = Theme.SubText
            b.Indicator.Visible = false
        end
        TabFrame.Visible              = true
        TabBtn.BackgroundTransparency = 0.85
        TabBtn.TextColor3             = Theme.Text
        Indicator.Visible             = true
    end)

    table.insert(Tabs, { Frame = TabFrame })
    table.insert(TabButtons, { Btn = TabBtn, Indicator = Indicator })
    return TabFrame
end

-- ══════════════════════════════════════════════
-- UI COMPONENTS
-- ══════════════════════════════════════════════
local function MkSection(parent, text, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(0.98, 0, 0, 18)
    f.BackgroundTransparency = 1; f.LayoutOrder = order
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.Text = string.upper(text)
    l.Font = Enum.Font.GothamBold; l.TextSize = 9
    l.TextColor3 = Theme.AccentLt; l.TextXAlignment = Enum.TextXAlignment.Left
    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,1,-1)
    line.BackgroundColor3 = Theme.Accent; line.BackgroundTransparency = 0.6
    line.BorderSizePixel = 0
end

-- Toggle (exact template: 45px)
local function MkToggle(parent, title, desc, default, order, cb)
    local state = default or false
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98, 0, 0, 45)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = ""
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", btn).Color = Theme.Stroke

    local Txt = Instance.new("TextLabel", btn)
    Txt.Size     = UDim2.new(0.7,0,0.5,0); Txt.Position = UDim2.new(0,10,0,5)
    Txt.Text     = title; Txt.Font = Enum.Font.GothamMedium; Txt.TextSize = 13
    Txt.TextColor3 = Theme.Text; Txt.TextXAlignment = Enum.TextXAlignment.Left
    Txt.BackgroundTransparency = 1

    local Sub = Instance.new("TextLabel", btn)
    Sub.Size     = UDim2.new(0.7,0,0.5,0); Sub.Position = UDim2.new(0,10,0.5,0)
    Sub.Text     = desc or ""
    Sub.Font     = Enum.Font.Gotham; Sub.TextSize = 10
    Sub.TextColor3 = Theme.SubText; Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.BackgroundTransparency = 1

    local Pill = Instance.new("Frame", btn)
    Pill.Size     = UDim2.new(0,40,0,20); Pill.Position = UDim2.new(1,-50,0.5,-10)
    Pill.BackgroundColor3 = state and Theme.Accent or Theme.Background
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local PStk = Instance.new("UIStroke", Pill)
    PStk.Color = state and Theme.Accent or Theme.Stroke

    local PTxt = Instance.new("TextLabel", Pill)
    PTxt.Size   = UDim2.new(1,0,1,0); PTxt.BackgroundTransparency = 1
    PTxt.Text   = state and "ON" or "OFF"
    PTxt.Font   = Enum.Font.GothamBold; PTxt.TextSize = 10
    PTxt.TextColor3 = state and Theme.Background or Theme.SubText

    local function Refresh()
        PTxt.Text             = state and "ON" or "OFF"
        PTxt.TextColor3       = state and Theme.Background or Theme.SubText
        Pill.BackgroundColor3 = state and Theme.Accent or Theme.Background
        PStk.Color            = state and Theme.Accent or Theme.Stroke
        btn.BackgroundColor3  = state and Color3.fromRGB(38,30,55) or Theme.Button
    end
    Refresh()
    btn.MouseButton1Click:Connect(function()
        state = not state; Refresh(); pcall(cb, state)
    end)
    return function() return state end
end

-- Button (exact template: 35px)
local function MkButton(parent, title, order, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98, 0, 0, 35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = "  " .. title
    btn.TextColor3       = Theme.Text
    btn.Font             = Enum.Font.GothamMedium
    btn.TextSize         = 13
    btn.TextXAlignment   = Enum.TextXAlignment.Left
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", btn).Color = Theme.Stroke
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(45,40,60) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Theme.Button end)
    btn.MouseButton1Click:Connect(function() pcall(cb) end)
    return btn
end

-- Slider (44px)
local sliderActive = nil
UserInputService.InputChanged:Connect(function(i)
    if not sliderActive then return end
    if i.UserInputType ~= Enum.UserInputType.MouseMovement
    and i.UserInputType ~= Enum.UserInputType.Touch then return end
    local s   = sliderActive
    local rel = math.clamp(
        (i.Position.X - s.Track.AbsolutePosition.X) / s.Track.AbsoluteSize.X, 0, 1)
    s.Val         = s.Min + math.floor(rel * (s.Max - s.Min))
    s.Fill.Size   = UDim2.new(rel, 0, 1, 0)
    s.Knob.Position = UDim2.new(rel, -5, 0.5, -5)
    s.VLbl.Text   = tostring(s.Val) .. s.Sfx
    pcall(s.Cb, s.Val)
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        sliderActive = nil
    end
end)

local function MkSlider(parent, title, mn, mx, def, sfx, order, cb)
    sfx = sfx or ""
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 44)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", card).Color = Theme.Stroke

    local TL = Instance.new("TextLabel", card)
    TL.Size     = UDim2.new(0.62,0,0,18); TL.Position = UDim2.new(0,10,0,5)
    TL.Text     = title; TL.Font = Enum.Font.GothamMedium; TL.TextSize = 12
    TL.TextColor3 = Theme.Text; TL.TextXAlignment = Enum.TextXAlignment.Left
    TL.BackgroundTransparency = 1

    local VL = Instance.new("TextLabel", card)
    VL.Size     = UDim2.new(0.38,-10,0,18); VL.Position = UDim2.new(0.62,0,0,5)
    VL.Text     = tostring(def) .. sfx
    VL.Font     = Enum.Font.GothamBold; VL.TextSize = 12
    VL.TextColor3 = Theme.AccentLt; VL.TextXAlignment = Enum.TextXAlignment.Right
    VL.BackgroundTransparency = 1

    local Track = Instance.new("Frame", card)
    Track.Size            = UDim2.new(1,-18,0,4); Track.Position = UDim2.new(0,9,0,30)
    Track.BackgroundColor3 = Color3.fromRGB(45,45,55); Track.BorderSizePixel = 0
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local pct  = (def - mn) / (mx - mn)
    local Fill = Instance.new("Frame", Track)
    Fill.Size             = UDim2.new(pct, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent; Fill.BorderSizePixel = 0
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame", Track)
    Knob.Size             = UDim2.new(0,10,0,10); Knob.Position = UDim2.new(pct,-5,0.5,-5)
    Knob.BackgroundColor3 = Color3.new(1,1,1); Knob.BorderSizePixel = 0; Knob.ZIndex = 3
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local sd = {Track=Track, Fill=Fill, Knob=Knob, VLbl=VL,
                Min=mn, Max=mx, Val=def, Sfx=sfx, Cb=cb}
    Track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            sliderActive = sd
            local rel = math.clamp(
                (i.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            sd.Val        = mn + math.floor(rel * (mx - mn))
            Fill.Size     = UDim2.new(rel, 0, 1, 0)
            Knob.Position = UDim2.new(rel, -5, 0.5, -5)
            VL.Text       = tostring(sd.Val) .. sfx
            pcall(cb, sd.Val)
        end
    end)
    return function() return sd.Val end
end

-- Dropdown (38px, list in DropOverlay)
local function MkDrop(parent, title, opts, def, order, cb)
    local sel = def or opts[1]

    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 38)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", card).Color = Theme.Stroke

    local TL = Instance.new("TextLabel", card)
    TL.Size     = UDim2.new(0.44,0,1,0); TL.Position = UDim2.new(0,10,0,0)
    TL.Text     = title; TL.Font = Enum.Font.GothamMedium; TL.TextSize = 12
    TL.TextColor3 = Theme.Text; TL.TextXAlignment = Enum.TextXAlignment.Left
    TL.BackgroundTransparency = 1

    local DBtn = Instance.new("TextButton", card)
    DBtn.Size     = UDim2.new(0.54,-8,0,26); DBtn.Position = UDim2.new(0.46,0,0.5,-13)
    DBtn.BackgroundColor3 = Color3.fromRGB(28,28,34); DBtn.BorderSizePixel = 0
    DBtn.Text     = sel; DBtn.Font = Enum.Font.Gotham; DBtn.TextSize = 11
    DBtn.TextColor3 = Theme.Text; DBtn.AutoButtonColor = false
    Instance.new("UICorner", DBtn).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", DBtn).Color = Theme.Stroke
    local Arr = Instance.new("TextLabel", DBtn)
    Arr.Size = UDim2.new(0,14,1,0); Arr.Position = UDim2.new(1,-16,0,0)
    Arr.BackgroundTransparency = 1; Arr.Text = "▾"
    Arr.TextColor3 = Theme.AccentLt; Arr.TextSize = 11; Arr.Font = Enum.Font.GothamBold

    local List = Instance.new("Frame", DropOverlay)
    List.BackgroundColor3 = Color3.fromRGB(28,28,34); List.BorderSizePixel = 0
    List.ZIndex = 110; List.Visible = false
    Instance.new("UICorner", List).CornerRadius = UDim.new(0, 6)
    local _ls = Instance.new("UIStroke", List); _ls.Color = Theme.Accent; _ls.Transparency = 0.4
    Instance.new("UIListLayout", List).SortOrder = Enum.SortOrder.LayoutOrder

    for idx, opt in ipairs(opts) do
        local ob = Instance.new("TextButton", List)
        ob.Size   = UDim2.new(1,0,0,24); ob.BackgroundColor3 = Color3.fromRGB(28,28,34)
        ob.BorderSizePixel = 0; ob.LayoutOrder = idx; ob.ZIndex = 111
        ob.Text   = "  " .. opt; ob.Font = Enum.Font.Gotham; ob.TextSize = 11
        ob.TextColor3 = (opt == sel) and Theme.AccentLt or Theme.Text
        ob.TextXAlignment = Enum.TextXAlignment.Left; ob.AutoButtonColor = false
        ob.MouseEnter:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(38,38,50) end)
        ob.MouseLeave:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(28,28,34) end)
        ob.MouseButton1Click:Connect(function()
            sel = opt; DBtn.Text = opt; CloseDrops()
            for _, c in ipairs(List:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text:gsub("^%s+","") == opt
                                   and Theme.AccentLt or Theme.Text
                end
            end
            pcall(cb, sel)
        end)
    end

    DBtn.MouseButton1Click:Connect(function()
        if openList == List then CloseDrops(); return end
        CloseDrops()
        local ap, as = DBtn.AbsolutePosition, DBtn.AbsoluteSize
        List.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 2)
        List.Size     = UDim2.new(0, as.X, 0, #opts * 24)
        List.Visible  = true; openList = List
        DropOverlay.Active = true
    end)

    return function() return sel end
end

-- Status card
local statBig, statSub = nil, nil
local function MkStatusCard(parent, order)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 44)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", card).Color = Theme.Stroke

    statBig = Instance.new("TextLabel", card)
    statBig.Size   = UDim2.new(1,-12,0,20); statBig.Position = UDim2.new(0,12,0,5)
    statBig.BackgroundTransparency = 1; statBig.Text = "[ DISABLED ]"
    statBig.Font   = Enum.Font.GothamBold; statBig.TextSize = 13
    statBig.TextColor3 = Theme.Red; statBig.TextXAlignment = Enum.TextXAlignment.Left

    statSub = Instance.new("TextLabel", card)
    statSub.Size   = UDim2.new(1,-12,0,14); statSub.Position = UDim2.new(0,12,0,26)
    statSub.BackgroundTransparency = 1; statSub.Text = "Waiting..."
    statSub.Font   = Enum.Font.Gotham; statSub.TextSize = 10
    statSub.TextColor3 = Theme.SubText; statSub.TextXAlignment = Enum.TextXAlignment.Left
end

-- ══════════════════════════════════════════════
-- BUILD TABS
-- ══════════════════════════════════════════════
local TFarm   = CreateTab("Auto Farm", "⚔")
local TCombat = CreateTab("Combat",    "⚙")
local TESP    = CreateTab("ESP",       "●")
local TMisc   = CreateTab("Misc",      "★")
local TCreds  = CreateTab("Info",      "i")

-- ── TAB: AUTO FARM ────────────────────────────
MkSection(TFarm, "Farming", 1)

MkDrop(TFarm, "Target Method",
    {"Closest","Furthest","Random","Most HP","Least HP"}, "Closest", 2,
    function(v) Cfg.Farm.TargetMethod = v end)

MkToggle(TFarm, "Face At Target",  "Rotate toward enemy",    true,  3,
    function(v) Cfg.Farm.FaceTarget  = v end)
MkToggle(TFarm, "Fast Attack",     "Spam M1 via Knit signal", true,  4,
    function(v) Cfg.Farm.FastAttack  = v end)
MkToggle(TFarm, "Use Skills",      "Fire Moveset skills",     true,  5,
    function(v) Cfg.Farm.UseSkills   = v end)

local farmBtn = MkButton(TFarm, "▶  Enable Farm", 6, function() end)
local farmOn  = false
farmBtn.MouseButton1Click:Connect(function()
    farmOn = not farmOn; Cfg.Farm.Enabled = farmOn
    farmBtn.Text             = farmOn and "  ■  Disable Farm" or "  ▶  Enable Farm"
    farmBtn.BackgroundColor3 = farmOn and Color3.fromRGB(38,28,58) or Theme.Button
end)

MkSection(TFarm, "Status", 7)
MkStatusCard(TFarm, 8)

MkSection(TFarm, "Blocking", 9)
MkToggle(TFarm, "Enable Auto Block",        "Block when enemies nearby", true,  10,
    function(v) Cfg.Block.Enabled      = v end)
MkToggle(TFarm, "Auto Punish (Attack Back)","Counter after blocking",    true,  11,
    function(v) Cfg.Block.AutoPunish   = v end)
MkToggle(TFarm, "Face Attacker",            "Turn toward attacker",      true,  12,
    function(v) Cfg.Block.FaceAttacker = v end)

MkSlider(TFarm, "Detection Range", 5, 80, 20, " studs", 13,
    function(v) Cfg.Block.DetectRange = v end)
MkSlider(TFarm, "Block Delay",     0,  5,  0, "s",      14,
    function(v) Cfg.Block.BlockDelay  = v end)

MkSection(TFarm, "Aimlock", 15)
MkToggle(TFarm, "Enable Aimlock",   "Aim assist toward target",  false, 16,
    function(v) Cfg.Aim.Enabled    = v end)
MkDrop(TFarm, "Aimlock Mode", {"Camera","Body","Silent"}, "Camera", 17,
    function(v) Cfg.Aim.Mode       = v end)
MkDrop(TFarm, "Target Part",  {"Head","HumanoidRootPart","Torso"}, "Head", 18,
    function(v) Cfg.Aim.TargetPart = v end)
MkToggle(TFarm, "Prediction",       "Lead moving targets",       false, 19,
    function(v) Cfg.Aim.Prediction = v end)

-- ── TAB: COMBAT ───────────────────────────────
MkSection(TCombat, "Movement", 1)
MkDrop(TCombat, "Teleport Method",   {"Tween","Instant","Lerp"},          "Tween",        2,
    function(v) Cfg.Combat.TpMethod  = v end)
MkDrop(TCombat, "Movement Mode",     {"Orbit (Dodge)","Follow","Static"}, "Orbit (Dodge)",3,
    function(v) Cfg.Combat.MoveMode  = v:gsub(" %(Dodge%)","") end)
MkSlider(TCombat, "Tween Speed",   50,  400, 135, " studs/s", 4,
    function(v) Cfg.Combat.TweenSpeed  = v end)
MkSlider(TCombat, "Follow Distance", 2, 30,   4,  " studs",   5,
    function(v) Cfg.Combat.FollowDist  = v end)
MkToggle(TCombat, "Smart Kiting", "Dodge back on skill CD", true, 6,
    function(v) Cfg.Combat.SmartKiting = v end)

MkSection(TCombat, "Main Config", 7)
MkToggle(TCombat, "Auto Flee (Low HP)", "Retreat when HP low", false, 8,
    function(v) Cfg.Combat.AutoFlee   = v end)
MkSlider(TCombat, "Flee Health %", 5, 80, 20, "%", 9,
    function(v) Cfg.Combat.FleeHP     = v end)

MkSection(TCombat, "Skills", 10)
MkSlider(TCombat, "Skill Fire Delay", 0, 30, 0, "s", 11,
    function(v) Cfg.Combat.SkillDelay = v end)
MkToggle(TCombat, "Avoid Skills (No Target)", "Skip when no target", true, 12,
    function(v) Cfg.Combat.AvoidNoTarget = v end)
MkToggle(TCombat, "Semi Kill Aura (25 Studs)", "Attack all nearby", false, 13,
    function(v) Cfg.Combat.SemiKillAura = v; SetKillAura(v) end)
MkToggle(TCombat, "SpinBot", "Spin continuously", false, 14,
    function(v) Cfg.Combat.SpinBot = v; SetSpinBot(v) end)

-- ── TAB: ESP ──────────────────────────────────
MkSection(TESP, "Enable", 1)
MkToggle(TESP, "Enable ESP Players", "Show enemy overlays", false, 2,
    function(v) Cfg.ESP.Enabled   = v end)
MkSection(TESP, "Configurations", 3)
MkToggle(TESP, "Box",          "Draw bounding box",  true, 4, function(v) Cfg.ESP.Box       = v end)
MkToggle(TESP, "Tracers",      "Draw tracer lines",  true, 5, function(v) Cfg.ESP.Tracers   = v end)
MkToggle(TESP, "Health Bar",   "Show health bar",    true, 6, function(v) Cfg.ESP.HealthBar = v end)
MkToggle(TESP, "Distance",     "Show stud distance", true, 7, function(v) Cfg.ESP.Distance  = v end)
MkToggle(TESP, "Name",         "Show player name",   true, 8, function(v) Cfg.ESP.Name      = v end)
MkToggle(TESP, "Moveset/Class","Show moveset name",  true, 9, function(v) Cfg.ESP.Moveset   = v end)

-- ── TAB: MISC ─────────────────────────────────
MkSection(TMisc, "Stuff", 1)
MkToggle(TMisc, "Anti Ragdoll",              "Disable ragdoll constraints",  false,  2,
    function(v) Cfg.Misc.AntiRagdoll = v end)
MkToggle(TMisc, "Auto Tech (Jump on Ragdoll)","Auto-jump when ragdolled",    false,  3,
    function(v) Cfg.Misc.AutoTech    = v end)
MkToggle(TMisc, "WalkSpeed Bypass",          "Speed via BodyVelocity",       false,  4,
    function(v) Cfg.Misc.WsBypass    = v; SetSpeedBypass(v) end)
MkSlider(TMisc, "Speed Amount",   16, 500, 100, " studs/s",  5,
    function(v) Cfg.Misc.Speed       = v end)
MkToggle(TMisc, "Infinite Jump",             "Jump repeatedly in air",       false,  6,
    function(v) Cfg.Misc.InfJump     = v; SetInfJump(v) end)
MkToggle(TMisc, "Fullbright",                "Max ambient lighting",         false,  7,
    function(v) Cfg.Misc.Fullbright  = v; SetFullbright(v) end)
MkToggle(TMisc, "White Screen",              "White overlay",                false,  8,
    function(v) Cfg.Misc.WhiteScreen = v; SetWhiteScreen(v) end)
MkToggle(TMisc, "Anti AFK",                  "Prevent auto-kick",            true,   9,
    function(v) Cfg.Misc.AntiAFK     = v end)
MkToggle(TMisc, "Click TP (Ctrl+Click)",     "Teleport to clicked spot",     false, 10,
    function(v) Cfg.Misc.ClickTP     = v; SetClickTP(v) end)
MkSlider(TMisc, "Time Changer",   0, 24, 14, "h", 11,
    function(v) Cfg.Misc.TimeHour    = v end)

MkButton(TMisc, "⚡  FPS Boost", 12, function()
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    Lighting.GlobalShadows = false
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke")
        or v:IsA("Sparkles") or v:IsA("Fire") then v.Enabled = false end
    end
end)

MkButton(TMisc, "🌐  Server Hop", 13, function()
    pcall(function()
        local d = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Asc&limit=100"))
        for _, sv in ipairs(d.data or {}) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LP)
                return
            end
        end
    end)
end)

MkSection(TMisc, "Player Control", 14)
local function PlayerNames()
    local t = {"(none)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then t[#t+1] = p.Name end
    end
    return t
end
local getSP = MkDrop(TMisc, "Select Player", PlayerNames(), "(none)", 15, function() end)
MkButton(TMisc, "▶  Spectate Player",   16, function()
    local p = Players:FindFirstChild(getSP()); if p then SpectatePlayer(p) end
end)
MkButton(TMisc, "■  Stop Spectate",     17, function() StopSpec() end)
MkButton(TMisc, "↑  Teleport to Player",18, function()
    local p = Players:FindFirstChild(getSP()); if not p then return end
    local r, tr = Root(LP), Root(p)
    if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, -3) end
end)

-- ── TAB: INFO ─────────────────────────────────
local function InfoLine(parent, txt, col, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(0.98,0,0,34); f.BackgroundColor3 = Theme.Button
    f.BorderSizePixel = 0; f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", f).Color = Theme.Stroke
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.Text = txt; l.Font = Enum.Font.GothamBold; l.TextSize = 11
    l.TextColor3 = col or Theme.Text; l.TextXAlignment = Enum.TextXAlignment.Center
end
InfoLine(TCreds, "Imp Hub X",                       Theme.AccentLt, 1)
InfoLine(TCreds, "Jujutsu Shenanigans",              Theme.Text,     2)
InfoLine(TCreds, "v7  •  Rebuilt from Script Dump",  Theme.SubText,  3)
InfoLine(TCreds, "⚔ Farm | ⚙ Combat | ● ESP | ★ Misc", Theme.SubText, 4)
InfoLine(TCreds, "Toggle: RightShift",               Theme.AccentLt, 5)

-- ══════════════════════════════════════════════
-- OPEN DEFAULT TAB  (exact template)
-- ══════════════════════════════════════════════
if TabButtons[1] then
    TabButtons[1].Btn.MouseButton1Click:Fire()
end

-- RightShift toggle
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible   = not MainFrame.Visible
        ToggleIcon.Visible  = not MainFrame.Visible
    end
end)

-- ══════════════════════════════════════════════
-- HEARTBEAT LOOP
-- ══════════════════════════════════════════════
local blockTimer   = 0
local lastBlocker  = nil
local lastTech     = 0
local lastAfk      = 0

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Refresh workspace.Characters ref in case it was nil
    if CharsFolder == workspace and workspace:FindFirstChild("Characters") then
        CharsFolder = workspace.Characters
    end

    -- Ensure Knit services cached
    EnsureServices()

    -- Time changer
    pcall(function() Lighting.ClockTime = Cfg.Misc.TimeHour end)

    -- Anti-AFK (dump confirms humanoid jump pulse works)
    if Cfg.Misc.AntiAFK and now - lastAfk > 60 then
        lastAfk = now
        pcall(function()
            local h = Hum(LP); if h then h.Jump = false end
        end)
    end

    -- Auto Tech (jump on ragdoll — dump shows Info:FindFirstChild("Knockback") pattern)
    if Cfg.Misc.AutoTech then
        local myChar = LP.Character
        if myChar then
            -- Check ragdoll attribute from dump: character:GetAttribute("Ragdoll") > 0
            local ragVal = myChar:GetAttribute("Ragdoll") or 0
            if ragVal > 0 and now - lastTech > 0.3 then
                lastTech = now
                local h = myChar:FindFirstChildOfClass("Humanoid")
                if h then h.Jump = true end
            end
        end
    end

    -- Speed bypass
    if Cfg.Misc.WsBypass and speedBV then
        local myChar = LP.Character
        local hum    = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if hum then
            speedBV.Velocity = hum.MoveDirection * Cfg.Misc.Speed
        end
    end

    -- Anti Ragdoll (disable BallSocketConstraint/HingeConstraint per dump)
    if Cfg.Misc.AntiRagdoll then
        local myChar = LP.Character
        if myChar then
            for _, v in ipairs(myChar:GetDescendants()) do
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                    v.Enabled = false
                end
            end
        end
    end

    -- ── Auto Block ──────────────────────────────
    -- BlockService.Activated:Fire(targetChar) to start
    -- BlockService.Deactivated:Fire() to stop
    if Cfg.Block.Enabled and Cfg.Block.AutoBlock then
        local shouldBlock, attacker = false, nil
        for _, p in ipairs(GetEnemies()) do
            if Dist(p) <= Cfg.Block.DetectRange then
                shouldBlock = true; attacker = p; break
            end
        end
        if shouldBlock then
            if Cfg.Block.FaceAttacker and attacker then FaceTarget(attacker) end
            if now >= blockTimer then
                blockTimer = now + Cfg.Block.BlockDelay
                local tChar = attacker and GetChar(attacker)
                SetBlock(true, tChar)
                lastBlocker = attacker
            end
        else
            if isBlocking then
                SetBlock(false, nil)
                if Cfg.Block.AutoPunish and lastBlocker then
                    DoAttack()
                end
                lastBlocker = nil
            end
        end
    else
        if isBlocking then SetBlock(false, nil) end
    end

    -- ── Aimlock ─────────────────────────────────
    if Cfg.Aim.Enabled then
        local tgt = GetTarget()
        if tgt then
            local ch   = GetChar(tgt)
            local part = ch and (ch:FindFirstChild(Cfg.Aim.TargetPart)
                               or ch:FindFirstChild("HumanoidRootPart"))
            if part then
                local pos = part.Position
                if Cfg.Aim.Prediction then
                    pcall(function()
                        pos = pos + part.AssemblyLinearVelocity * 0.1
                    end)
                end
                if Cfg.Aim.Mode == "Camera" or Cfg.Aim.Mode == "Silent" then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
                elseif Cfg.Aim.Mode == "Body" then
                    local r = Root(LP)
                    if r then
                        r.CFrame = CFrame.new(r.Position,
                            Vector3.new(pos.X, r.Position.Y, pos.Z))
                    end
                end
            end
        end
    end

    -- ── Auto Farm ───────────────────────────────
    if Cfg.Farm.Enabled then
        local tgt = GetTarget()

        -- Auto Flee
        if Cfg.Combat.AutoFlee then
            local myChar = LP.Character
            local h = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if h and tgt and (h.Health / h.MaxHealth * 100) <= Cfg.Combat.FleeHP then
                local r, tr = Root(LP), Root(tgt)
                if r and tr then
                    local away = (r.Position - tr.Position).Unit
                    r.CFrame = CFrame.new(r.Position + away * 35)
                end
            end
        end

        if tgt then
            -- Movement
            if Cfg.Combat.MoveMode == "Orbit" then
                OrbitTarget(tgt)
            else
                MoveToTarget(tgt)
            end

            -- Face
            if Cfg.Farm.FaceTarget then FaceTarget(tgt) end

            -- Attack (M1 via Knit service)
            if Cfg.Farm.FastAttack then DoAttack() end

            -- Skills (Character.Moveset children)
            UseSkill(tgt)
        end

        -- Status update
        if statBig then
            local t2 = GetTarget()
            statBig.Text      = "[ ACTIVE ]"
            statBig.TextColor3 = Theme.Green
            statSub.Text      = "Target: " .. (t2 and t2.Name or "searching...")
        end
    else
        if statBig then
            statBig.Text       = "[ DISABLED ]"
            statBig.TextColor3 = Theme.Red
            statSub.Text       = "Waiting..."
        end
    end
end)

-- ══════════════════════════════════════════════
-- ESP  (workspace.Characters confirmed from dump)
-- ══════════════════════════════════════════════
local ESPObjs = {}

-- From dump: character:GetAttribute("Moveset") is the moveset string
local function GetMoveset(p)
    local ch = GetChar(p)
    if ch then
        local m = ch:GetAttribute("Moveset")
        if m and m ~= "" then return tostring(m) end
        -- Also check leaderstats as fallback
        for _, n in ipairs({"Moveset","Class","Style"}) do
            local ls = p:FindFirstChild("leaderstats")
            if ls then
                local v = ls:FindFirstChild(n)
                if v then return tostring(v.Value) end
            end
        end
    end
    return "???"
end

local function MakeESP(p)
    if p == LP or ESPObjs[p] then return end
    local o = {}
    o.Box = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5; l.Color = Color3.fromRGB(130, 45, 235)
        l.Visible = false; l.ZIndex = 2
        o.Box[i] = l
    end
    o.Tracer = Drawing.new("Line")
    o.Tracer.Thickness = 1; o.Tracer.Color = Color3.fromRGB(130,45,235)
    o.Tracer.Visible = false

    o.HpBg = Drawing.new("Square"); o.HpBg.Filled = true
    o.HpBg.Color = Color3.fromRGB(18,18,18); o.HpBg.Visible = false
    o.Hp = Drawing.new("Square"); o.Hp.Filled = true
    o.Hp.Color = Color3.fromRGB(0,205,60); o.Hp.Visible = false

    o.Name = Drawing.new("Text"); o.Name.Size = 13
    o.Name.Color = Color3.new(1,1,1); o.Name.Center = true
    o.Name.Outline = true; o.Name.Visible = false

    o.Dist = Drawing.new("Text"); o.Dist.Size = 11
    o.Dist.Color = Color3.fromRGB(200,200,200); o.Dist.Center = true
    o.Dist.Outline = true; o.Dist.Visible = false

    o.Move = Drawing.new("Text"); o.Move.Size = 11
    o.Move.Color = Color3.fromRGB(170,125,255); o.Move.Center = true
    o.Move.Outline = true; o.Move.Visible = false

    ESPObjs[p] = o
end

local function RemESP(p)
    local o = ESPObjs[p]; if not o then return end
    for _, v in pairs(o) do
        if type(v) == "table" then
            for _, l in ipairs(v) do pcall(function() l:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
    ESPObjs[p] = nil
end

local function HideESP(o)
    for _, v in pairs(o) do
        if type(v) == "table" then
            for _, l in ipairs(v) do l.Visible = false end
        else
            v.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Cfg.ESP.Enabled then
        for _, o in pairs(ESPObjs) do HideESP(o) end
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then MakeESP(p) end
    end
    for p, o in pairs(ESPObjs) do
        if not p.Parent or not Alive(p) then
            RemESP(p)
        else
            local r = Root(p); local h = Hum(p)
            if not r or not h then
                HideESP(o)
            else
                local sp, vis, dep = Camera:WorldToViewportPoint(r.Position)
                if not vis or dep <= 0 then
                    HideESP(o)
                else
                    local tp = Camera:WorldToViewportPoint(r.Position + Vector3.new(0, 3.2, 0))
                    local bp = Camera:WorldToViewportPoint(r.Position + Vector3.new(0,-3.2, 0))
                    local ht = math.abs(tp.Y - bp.Y)
                    local wd = ht * 0.52
                    local L, R, T, B = sp.X-wd/2, sp.X+wd/2, tp.Y, bp.Y

                    local corners = {
                        {Vector2.new(L,T), Vector2.new(R,T)},
                        {Vector2.new(L,B), Vector2.new(R,B)},
                        {Vector2.new(L,T), Vector2.new(L,B)},
                        {Vector2.new(R,T), Vector2.new(R,B)},
                    }
                    for i, ln in ipairs(o.Box) do
                        ln.From = corners[i][1]; ln.To = corners[i][2]
                        ln.Visible = Cfg.ESP.Box
                    end

                    local vp = Camera.ViewportSize
                    o.Tracer.From = Vector2.new(vp.X/2, vp.Y)
                    o.Tracer.To   = Vector2.new(sp.X, sp.Y)
                    o.Tracer.Visible = Cfg.ESP.Tracers

                    local pct = math.clamp(h.Health / h.MaxHealth, 0, 1)
                    o.HpBg.Size     = Vector2.new(4, ht)
                    o.HpBg.Position = Vector2.new(L-7, T)
                    o.HpBg.Visible  = Cfg.ESP.HealthBar
                    o.Hp.Size       = Vector2.new(4, ht*pct)
                    o.Hp.Position   = Vector2.new(L-7, T + ht*(1-pct))
                    o.Hp.Color      = Color3.fromRGB(
                        math.floor(255*(1-pct)), math.floor(255*pct), 0)
                    o.Hp.Visible    = Cfg.ESP.HealthBar

                    o.Name.Text     = p.Name
                    o.Name.Position = Vector2.new(sp.X, T-16)
                    o.Name.Visible  = Cfg.ESP.Name

                    o.Dist.Text     = math.floor(Dist(p)) .. "st"
                    o.Dist.Position = Vector2.new(sp.X, B+3)
                    o.Dist.Visible  = Cfg.ESP.Distance

                    o.Move.Text     = "[" .. GetMoveset(p) .. "]"
                    o.Move.Position = Vector2.new(sp.X, B+15)
                    o.Move.Visible  = Cfg.ESP.Moveset
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════════════
Players.PlayerRemoving:Connect(function(p) RemESP(p) end)

LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    -- Re-cache services after respawn (Knit may re-init)
    BlockSvc = nil
    EnsureServices()
    if Cfg.Misc.WsBypass  then SetSpeedBypass(true) end
    if Cfg.Misc.InfJump   then SetInfJump(true) end
    if Cfg.Misc.ClickTP   then SetClickTP(true) end
end)

ScreenGui.AncestryChanged:Connect(function()
    for p in pairs(ESPObjs) do RemESP(p) end
    if spinConn then spinConn:Disconnect() end
    if killConn then killConn:Disconnect() end
    if specConn then specConn:Disconnect() end
    if jumpConn then jumpConn:Disconnect() end
    if ctpConn  then ctpConn:Disconnect()  end
    if speedBV  then pcall(function() speedBV:Destroy() end) end
    SetBlock(false, nil)
    StopSpec()
end)

print("[ImpHubX v7] Loaded — workspace.Characters + Knit services active")
print("[ImpHubX v7] Toggle: RightShift | Parent: " .. tostring(TargetParent))
