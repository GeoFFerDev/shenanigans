--[[
  IMP HUB X  v6.5  —  Jujutsu Shenanigans (ANDROID / DELTA OPTIMIZED)
  Template: Fluent Local UI Framework
  Window: 400×260  |  Delta / Mobile / PC
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
local vim              = game:GetService("VirtualInputManager")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ══════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════
local Cfg = {
    Farm   = { Enabled=false, TargetMethod="Closest", FaceTarget=true,
               FastAttack=true, UseSkills=true },
    Block  = { Enabled=false, AutoBlock=true, AutoPunish=true,
               FaceAttacker=true, DetectRange=20, BlockDelay=0 },
    Aim    = { Enabled=false, Mode="Camera", TargetPart="Head", Prediction=false },
    -- Lerp is much safer for mobile physics engines
    Combat = { TpMethod="Lerp", MoveMode="Orbit", TweenSpeed=135,
               FollowDist=4, SmartKiting=true, AutoFlee=false, FleeHP=20,
               SkillDelay=0, AvoidNoTarget=true, SemiKillAura=false, SpinBot=false },
    ESP    = { Enabled=false, Box=true, Tracers=true, HealthBar=true,
               Distance=true, Name=true, Moveset=true },
    Misc   = { AntiRagdoll=false, AutoTech=false, WsBypass=false, Speed=100,
               InfJump=false, Fullbright=false, WhiteScreen=false,
               AntiAFK=true, ClickTP=false, TimeHour=14 },
}

-- Check Drawing API support for Delta Android
local HAS_DRAWING = pcall(function() local a = Drawing.new("Line"); a:Remove() end)

-- ══════════════════════════════════════════════
-- MOBILE INPUT WRAPPER
-- ══════════════════════════════════════════════
local function SimMobileClick()
    local x, y = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
    pcall(function()
        -- 1. Try Native Touch (Android Delta mapping)
        vim:SendTouchEvent(1, 0, x, y) -- State 0 = Began
        task.delay(0.05, function() 
            pcall(function() vim:SendTouchEvent(1, 2, x, y) end) -- State 2 = Ended
        end)
    end)
    pcall(function()
        -- 2. Fallback Mouse simulation
        vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.delay(0.05, function()
            pcall(function() vim:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
        end)
    end)
end

local function SimKey(k)
    pcall(function()
        vim:SendKeyEvent(true, k, false, game)
        task.delay(0.05, function() 
            pcall(function() vim:SendKeyEvent(false, k, false, game) end) 
        end)
    end)
end

-- ══════════════════════════════════════════════
-- GAME LOGIC
-- ══════════════════════════════════════════════
local function Char(p)  return p and p.Character end
local function Root(p)  local c=Char(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p)   local c=Char(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p) local h=Hum(p);  return h and h.Health > 0 end
local function Dist(p)
    local a,b = Root(LP),Root(p)
    return (a and b) and (a.Position-b.Position).Magnitude or math.huge
end

local function GetEnemies()
    local t={}
    local myRoot = Root(LP)
    if not myRoot then return t end
    
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and Alive(p) then 
            local pRoot = Root(p)
            -- Ignore people high up in the safezone lobby
            if pRoot and pRoot.Position.Y < 500 then
                t[#t+1]=p 
            end
        end
    end
    return t
end

local function GetTarget()
    local e = GetEnemies()
    if #e == 0 then return nil end
    local m = Cfg.Farm.TargetMethod
    
    pcall(function()
        if m == "Closest"  then table.sort(e,function(a,b) return Dist(a)<Dist(b) end)
        elseif m == "Furthest" then table.sort(e,function(a,b) return Dist(a)>Dist(b) end)
        elseif m == "Most HP"  then table.sort(e,function(a,b)
                local ha,hb=Hum(a),Hum(b)
                return (ha and ha.Health or 0)>(hb and hb.Health or 0) end)
        elseif m == "Least HP" then table.sort(e,function(a,b)
                local ha,hb=Hum(a),Hum(b)
                return (ha and ha.Health or 1e9)<(hb and hb.Health or 1e9) end)
        end
    end)
    if m == "Random" then return e[math.random(1,#e)] end
    return e[1]
end

local function FaceTarget(t)
    local r, tr = Root(LP), Root(t)
    if r and tr then 
        r.CFrame = CFrame.new(r.Position, Vector3.new(tr.Position.X, r.Position.Y, tr.Position.Z)) 
    end
end

local orbitAngle = 0
local function OrbitTarget(t)
    local r, tr = Root(LP), Root(t)
    if not r or not tr then return end
    orbitAngle = orbitAngle + 0.06
    local d = Cfg.Combat.FollowDist + 1.5
    local ox = tr.Position.X + math.cos(orbitAngle) * d
    local oz = tr.Position.Z + math.sin(orbitAngle) * d
    r.CFrame = CFrame.new(ox, tr.Position.Y, oz) * CFrame.Angles(0, math.atan2(tr.Position.X - ox, tr.Position.Z - oz), 0)
end

local function MoveToTarget(t)
    local r, tr = Root(LP), Root(t)
    if not r or not tr then return end
    local dir = (r.Position - tr.Position).Unit
    if dir.X ~= dir.X then dir = Vector3.new(0,0,1) end -- NaN fix
    
    local cf = CFrame.new(tr.Position + dir * Cfg.Combat.FollowDist) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
    local m = Cfg.Combat.TpMethod
    if m == "Instant" then r.CFrame = cf
    elseif m == "Lerp" then r.CFrame = r.CFrame:Lerp(cf, 0.25)
    else TweenService:Create(r, TweenInfo.new(math.clamp((r.Position - cf.Position).Magnitude / Cfg.Combat.TweenSpeed, 0.04, 1.5), Enum.EasingStyle.Linear), {CFrame=cf}):Play() end
end

local lastAtk = 0
local function DoAttack(t)
    if tick() - lastAtk < 0.15 then return end
    lastAtk = tick()
    SimMobileClick()
end

local isBlocking = false
local function SetBlock(s)
    if isBlocking == s then return end
    isBlocking = s
    pcall(function()
        if s then vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        else vim:SendKeyEvent(false, Enum.KeyCode.F, false, game) end
    end)
end

local lastSkill = 0
local function UseSkill(t)
    if not Cfg.Farm.UseSkills then return end
    if tick() - lastSkill < math.max(0.1, Cfg.Combat.SkillDelay) then return end
    if Cfg.Combat.AvoidNoTarget and not t then return end
    lastSkill = tick()
    
    -- JJS Skills are 1-4
    local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    SimKey(keys[math.random(1, #keys)])
end

-- One-shot features
local speedBV
local function SetSpeedBypass(on)
    local r=Root(LP); if not r then return end
    if on then
        if not speedBV then
            speedBV=Instance.new("BodyVelocity"); speedBV.MaxForce=Vector3.new(1e4,0,1e4)
            speedBV.Velocity=Vector3.new(0,0,0); speedBV.Parent=r
        end
    else if speedBV then speedBV:Destroy(); speedBV=nil end end
end

local jumpConn
local function SetInfJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn=nil end
    if on then jumpConn=UserInputService.JumpRequest:Connect(function()
        local h=Hum(LP); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end

local origAmb,origBrt
local function SetFullbright(on)
    if on then origAmb=Lighting.Ambient; origBrt=Lighting.Brightness
        Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.Brightness=2; Lighting.FogEnd=1e6
    else if origAmb then Lighting.Ambient=origAmb; Lighting.Brightness=origBrt or 1 end end
end

local spinConn
local function SetSpinBot(on)
    if spinConn then spinConn:Disconnect(); spinConn=nil end
    if on then spinConn=RunService.RenderStepped:Connect(function()
        local r=Root(LP); if r then r.CFrame=r.CFrame*CFrame.Angles(0,math.rad(18),0) end
    end) end
end

local killConn
local function SetKillAura(on)
    if killConn then killConn:Disconnect(); killConn=nil end
    if on then
        local lkA=0
        killConn=RunService.Heartbeat:Connect(function()
            if tick()-lkA<0.12 then return end; lkA=tick()
            for _,e in ipairs(GetEnemies()) do if Dist(e)<=25 then DoAttack(e) end end
        end)
    end
end

-- ══════════════════════════════════════════════
-- MOUNT (UI Builder)
-- ══════════════════════════════════════════════
local TargetParent
if gethui then pcall(function() TargetParent = gethui() end) end
if not TargetParent then pcall(function() TargetParent = game:GetService("CoreGui") end) end
if not TargetParent then TargetParent = LP:WaitForChild("PlayerGui") end

local _old=TargetParent:FindFirstChild("ImpHubXv6"); if _old then _old:Destroy() end

local ScreenGui=Instance.new("ScreenGui",TargetParent)
ScreenGui.Name="ImpHubXv6"; ScreenGui.ResetOnSpawn=false; ScreenGui.IgnoreGuiInset=true

local Theme={
    Background = Color3.fromRGB(24,24,28), Sidebar    = Color3.fromRGB(18,18,22),
    Accent     = Color3.fromRGB(110,45,220), AccentLt   = Color3.fromRGB(150,80,255),
    Text       = Color3.fromRGB(240,240,240), SubText    = Color3.fromRGB(150,150,150),
    Button     = Color3.fromRGB(35,35,40), Stroke     = Color3.fromRGB(60,60,65),
    Green      = Color3.fromRGB(50,210,85), Red        = Color3.fromRGB(235,60,60),
}

local ToggleIcon=Instance.new("TextButton",ScreenGui)
ToggleIcon.Size=UDim2.new(0,45,0,45); ToggleIcon.Position=UDim2.new(0.5,-22,0.05,0)
ToggleIcon.BackgroundColor3=Theme.Background; ToggleIcon.BackgroundTransparency=0.1
ToggleIcon.Text="⚔"; ToggleIcon.TextSize=22; ToggleIcon.TextColor3=Theme.Text
ToggleIcon.Font=Enum.Font.GothamBold; ToggleIcon.Visible=false
Instance.new("UICorner",ToggleIcon).CornerRadius=UDim.new(1,0)
local _is=Instance.new("UIStroke",ToggleIcon); _is.Color=Theme.Accent; _is.Thickness=2

local MainFrame=Instance.new("Frame",ScreenGui)
MainFrame.Size=UDim2.new(0,400,0,260); MainFrame.Position=UDim2.new(0.5,-200,0.5,-130)
MainFrame.BackgroundColor3=Theme.Background; MainFrame.BackgroundTransparency=0.1; MainFrame.Active=true
Instance.new("UICorner",MainFrame).CornerRadius=UDim.new(0,8)
local _mstk=Instance.new("UIStroke",MainFrame); _mstk.Color=Theme.Accent; _mstk.Transparency=0.5

local TopBar=Instance.new("Frame",MainFrame)
TopBar.Size=UDim2.new(1,0,0,30); TopBar.BackgroundTransparency=1

local Title=Instance.new("TextLabel",TopBar)
Title.Size=UDim2.new(0.6,0,1,0); Title.Position=UDim2.new(0,12,0,0)
Title.Text="Imp Hub X • Mobile JJS"; Title.Font=Enum.Font.GothamMedium
Title.TextColor3=Theme.Text; Title.TextSize=11; Title.TextXAlignment=Enum.TextXAlignment.Left
Title.BackgroundTransparency=1

local function AddControl(text,pos,col,cb)
    local btn=Instance.new("TextButton",TopBar)
    btn.Size=UDim2.new(0,30,0,20); btn.Position=pos
    btn.BackgroundColor3=Theme.Background; btn.BackgroundTransparency=1
    btn.Text=text; btn.TextColor3=col; btn.Font=Enum.Font.GothamMedium; btn.TextSize=14
    btn.MouseButton1Click:Connect(cb)
end
AddControl("✕",UDim2.new(1,-35,0.5,-10),Color3.fromRGB(255,80,80),function() ScreenGui:Destroy() end)
AddControl("—",UDim2.new(1,-70,0.5,-10),Theme.Text,function() MainFrame.Visible=false; ToggleIcon.Visible=true end)

ToggleIcon.MouseButton1Click:Connect(function() MainFrame.Visible=true; ToggleIcon.Visible=false end)

local function EnableDrag(obj,handle)
    local drag,start,startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; start=i.Position; startPos=obj.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-start
            obj.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end
EnableDrag(MainFrame,TopBar)
EnableDrag(ToggleIcon,ToggleIcon)

local Sidebar=Instance.new("Frame",MainFrame)
Sidebar.Size=UDim2.new(0,110,1,-30); Sidebar.Position=UDim2.new(0,0,0,30)
Sidebar.BackgroundColor3=Theme.Sidebar; Sidebar.BackgroundTransparency=0.5; Sidebar.BorderSizePixel=0
Instance.new("UICorner",Sidebar).CornerRadius=UDim.new(0,8)
local SidebarLayout=Instance.new("UIListLayout",Sidebar)
SidebarLayout.Padding=UDim.new(0,5); SidebarLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
Instance.new("UIPadding",Sidebar).PaddingTop=UDim.new(0,10)

local ContentArea=Instance.new("Frame",MainFrame)
ContentArea.Size=UDim2.new(1,-120,1,-30); ContentArea.Position=UDim2.new(0,115,0,30); ContentArea.BackgroundTransparency=1

local DropOverlay=Instance.new("Frame",ScreenGui)
DropOverlay.Size=UDim2.new(1,0,1,0); DropOverlay.BackgroundTransparency=1
DropOverlay.BorderSizePixel=0; DropOverlay.ZIndex=100; DropOverlay.Active=false

local openList=nil
local function CloseDrops() if openList then openList.Visible=false; openList=nil end; DropOverlay.Active=false end
DropOverlay.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then CloseDrops() end end)

local Tabs={}
local TabButtons={}

local function CreateTab(name,icon)
    local TabFrame=Instance.new("ScrollingFrame",ContentArea)
    TabFrame.Size=UDim2.new(1,0,1,-10); TabFrame.BackgroundTransparency=1; TabFrame.ScrollBarThickness=2
    TabFrame.ScrollBarImageColor3=Theme.AccentLt; TabFrame.Visible=false
    TabFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y; TabFrame.CanvasSize=UDim2.new(0,0,0,0); TabFrame.BorderSizePixel=0

    local Layout=Instance.new("UIListLayout",TabFrame)
    Layout.Padding=UDim.new(0,8); Layout.SortOrder=Enum.SortOrder.LayoutOrder
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TabFrame.CanvasSize=UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y+20) end)
    local _tp=Instance.new("UIPadding",TabFrame)
    _tp.PaddingTop=UDim.new(0,5); _tp.PaddingLeft=UDim.new(0,2); _tp.PaddingRight=UDim.new(0,4)

    local TabBtn=Instance.new("TextButton",Sidebar)
    TabBtn.Size=UDim2.new(0.9,0,0,30); TabBtn.BackgroundColor3=Theme.Accent; TabBtn.BackgroundTransparency=1
    TabBtn.Text="  "..icon.." "..name; TabBtn.TextColor3=Theme.SubText; TabBtn.Font=Enum.Font.GothamMedium
    TabBtn.TextSize=12; TabBtn.TextXAlignment=Enum.TextXAlignment.Left; TabBtn.AutoButtonColor=false
    Instance.new("UICorner",TabBtn).CornerRadius=UDim.new(0,5)

    local Indicator=Instance.new("Frame",TabBtn)
    Indicator.Size=UDim2.new(0,3,0.6,0); Indicator.Position=UDim2.new(0,2,0.2,0)
    Indicator.BackgroundColor3=Theme.Accent; Indicator.Visible=false; Instance.new("UICorner",Indicator).CornerRadius=UDim.new(1,0)

    TabBtn.MouseButton1Click:Connect(function()
        CloseDrops(); for _,t in pairs(Tabs) do t.Frame.Visible=false end
        for _,b in pairs(TabButtons) do b.Btn.BackgroundTransparency=1; b.Btn.TextColor3=Theme.SubText; b.Indicator.Visible=false end
        TabFrame.Visible=true; TabBtn.BackgroundTransparency=0.85; TabBtn.TextColor3=Theme.Text; Indicator.Visible=true
    end)
    table.insert(Tabs,{Frame=TabFrame}); table.insert(TabButtons,{Btn=TabBtn,Indicator=Indicator})
    return TabFrame
end

local function MkSection(parent,text,order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(0.98,0,0,18); f.BackgroundTransparency=1; f.LayoutOrder=order
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text=string.upper(text); l.Font=Enum.Font.GothamBold; l.TextSize=9; l.TextColor3=Theme.AccentLt; l.TextXAlignment=Enum.TextXAlignment.Left
    local line=Instance.new("Frame",f); line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,1,-1)
    line.BackgroundColor3=Theme.Accent; line.BackgroundTransparency=0.6; line.BorderSizePixel=0
end

local function MkToggle(parent,title,desc,default,order,cb)
    local state=default or false
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(0.98,0,0,45); btn.BackgroundColor3=Theme.Button; btn.Text=""; btn.AutoButtonColor=false; btn.LayoutOrder=order
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",btn).Color=Theme.Stroke
    local Txt=Instance.new("TextLabel",btn)
    Txt.Size=UDim2.new(0.7,0,0.5,0); Txt.Position=UDim2.new(0,10,0,5); Txt.Text=title; Txt.Font=Enum.Font.GothamMedium; Txt.TextSize=13; Txt.TextColor3=Theme.Text; Txt.TextXAlignment=Enum.TextXAlignment.Left; Txt.BackgroundTransparency=1
    local Sub=Instance.new("TextLabel",btn)
    Sub.Size=UDim2.new(0.7,0,0.5,0); Sub.Position=UDim2.new(0,10,0.5,0); Sub.Text=desc or ""; Sub.Font=Enum.Font.Gotham; Sub.TextSize=10; Sub.TextColor3=Theme.SubText; Sub.TextXAlignment=Enum.TextXAlignment.Left; Sub.BackgroundTransparency=1
    local Pill=Instance.new("Frame",btn)
    Pill.Size=UDim2.new(0,40,0,20); Pill.Position=UDim2.new(1,-50,0.5,-10); Pill.BackgroundColor3=state and Theme.Accent or Theme.Background
    Instance.new("UICorner",Pill).CornerRadius=UDim.new(1,0)
    local PStk=Instance.new("UIStroke",Pill); PStk.Color=state and Theme.Accent or Theme.Stroke
    local PTxt=Instance.new("TextLabel",Pill)
    PTxt.Size=UDim2.new(1,0,1,0); PTxt.BackgroundTransparency=1; PTxt.Text=state and "ON" or "OFF"; PTxt.Font=Enum.Font.GothamBold; PTxt.TextSize=10; PTxt.TextColor3=state and Theme.Background or Theme.SubText

    local function Refresh()
        PTxt.Text=state and "ON" or "OFF"; PTxt.TextColor3=state and Theme.Background or Theme.SubText
        Pill.BackgroundColor3=state and Theme.Accent or Theme.Background; PStk.Color=state and Theme.Accent or Theme.Stroke
        btn.BackgroundColor3=state and Color3.fromRGB(38,30,55) or Theme.Button
    end
    Refresh()
    btn.MouseButton1Click:Connect(function() state=not state; Refresh(); pcall(cb,state) end)
    return function() return state end
end

local function MkButton(parent,title,order,cb)
    local btn=Instance.new("TextButton",parent); btn.Size=UDim2.new(0.98,0,0,35); btn.BackgroundColor3=Theme.Button
    btn.Text="  "..title; btn.TextColor3=Theme.Text; btn.Font=Enum.Font.GothamMedium; btn.TextSize=13; btn.TextXAlignment=Enum.TextXAlignment.Left; btn.AutoButtonColor=false; btn.LayoutOrder=order
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",btn).Color=Theme.Stroke
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(45,40,60) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=Theme.Button end)
    btn.MouseButton1Click:Connect(function() pcall(cb) end)
    return btn
end

local sliderActive=nil
UserInputService.InputChanged:Connect(function(i)
    if not sliderActive then return end
    if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
    local s=sliderActive; local rel=math.clamp((i.Position.X-s.Track.AbsolutePosition.X)/s.Track.AbsoluteSize.X,0,1)
    s.Val=s.Min+math.floor(rel*(s.Max-s.Min)); s.Fill.Size=UDim2.new(rel,0,1,0); s.Knob.Position=UDim2.new(rel,-5,0.5,-5)
    s.VLbl.Text=tostring(s.Val)..s.Sfx; pcall(s.Cb,s.Val)
end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliderActive=nil end end)

local function MkSlider(parent,title,mn,mx,def,sfx,order,cb)
    sfx=sfx or ""
    local card=Instance.new("Frame",parent); card.Size=UDim2.new(0.98,0,0,44); card.BackgroundColor3=Theme.Button; card.BorderSizePixel=0; card.LayoutOrder=order
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",card).Color=Theme.Stroke
    local TL=Instance.new("TextLabel",card)
    TL.Size=UDim2.new(0.62,0,0,18); TL.Position=UDim2.new(0,10,0,5); TL.Text=title; TL.Font=Enum.Font.GothamMedium; TL.TextSize=12; TL.TextColor3=Theme.Text; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.BackgroundTransparency=1
    local VL=Instance.new("TextLabel",card)
    VL.Size=UDim2.new(0.38,-10,0,18); VL.Position=UDim2.new(0.62,0,0,5); VL.Text=tostring(def)..sfx; VL.Font=Enum.Font.GothamBold; VL.TextSize=12; VL.TextColor3=Theme.AccentLt; VL.TextXAlignment=Enum.TextXAlignment.Right; VL.BackgroundTransparency=1
    local Track=Instance.new("Frame",card)
    Track.Size=UDim2.new(1,-18,0,4); Track.Position=UDim2.new(0,9,0,30); Track.BackgroundColor3=Color3.fromRGB(45,45,55); Track.BorderSizePixel=0
    Instance.new("UICorner",Track).CornerRadius=UDim.new(1,0)
    local pct=(def-mn)/(mx-mn)
    local Fill=Instance.new("Frame",Track); Fill.Size=UDim2.new(pct,0,1,0); Fill.BackgroundColor3=Theme.Accent; Fill.BorderSizePixel=0; Instance.new("UICorner",Fill).CornerRadius=UDim.new(1,0)
    local Knob=Instance.new("Frame",Track); Knob.Size=UDim2.new(0,10,0,10); Knob.Position=UDim2.new(pct,-5,0.5,-5); Knob.BackgroundColor3=Color3.new(1,1,1); Knob.BorderSizePixel=0; Knob.ZIndex=3; Instance.new("UICorner",Knob).CornerRadius=UDim.new(1,0)

    local sd={Track=Track,Fill=Fill,Knob=Knob,VLbl=VL,Min=mn,Max=mx,Val=def,Sfx=sfx,Cb=cb}
    Track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            sliderActive=sd; local rel=math.clamp((i.Position.X-Track.AbsolutePosition.X)/Track.AbsoluteSize.X,0,1)
            sd.Val=mn+math.floor(rel*(mx-mn)); Fill.Size=UDim2.new(rel,0,1,0); Knob.Position=UDim2.new(rel,-5,0.5,-5)
            VL.Text=tostring(sd.Val)..sfx; pcall(cb,sd.Val)
        end
    end)
    return function() return sd.Val end
end

local function MkDrop(parent,title,opts,def,order,cb)
    local sel=def or opts[1]
    local card=Instance.new("Frame",parent); card.Size=UDim2.new(0.98,0,0,38); card.BackgroundColor3=Theme.Button; card.BorderSizePixel=0; card.LayoutOrder=order
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",card).Color=Theme.Stroke
    local TL=Instance.new("TextLabel",card)
    TL.Size=UDim2.new(0.44,0,1,0); TL.Position=UDim2.new(0,10,0,0); TL.Text=title; TL.Font=Enum.Font.GothamMedium; TL.TextSize=12; TL.TextColor3=Theme.Text; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.BackgroundTransparency=1
    local DBtn=Instance.new("TextButton",card)
    DBtn.Size=UDim2.new(0.54,-8,0,26); DBtn.Position=UDim2.new(0.46,0,0.5,-13); DBtn.BackgroundColor3=Color3.fromRGB(28,28,34); DBtn.BorderSizePixel=0; DBtn.Text=sel; DBtn.Font=Enum.Font.Gotham; DBtn.TextSize=11; DBtn.TextColor3=Theme.Text; DBtn.AutoButtonColor=false
    Instance.new("UICorner",DBtn).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",DBtn).Color=Theme.Stroke
    local Arr=Instance.new("TextLabel",DBtn)
    Arr.Size=UDim2.new(0,14,1,0); Arr.Position=UDim2.new(1,-16,0,0); Arr.BackgroundTransparency=1; Arr.Text="▾"; Arr.TextColor3=Theme.AccentLt; Arr.TextSize=11; Arr.Font=Enum.Font.GothamBold

    local List=Instance.new("Frame",DropOverlay)
    List.BackgroundColor3=Color3.fromRGB(28,28,34); List.BorderSizePixel=0; List.ZIndex=110; List.Visible=false
    Instance.new("UICorner",List).CornerRadius=UDim.new(0,6); local _ls=Instance.new("UIStroke",List); _ls.Color=Theme.Accent; _ls.Transparency=0.4
    local LL=Instance.new("UIListLayout",List); LL.SortOrder=Enum.SortOrder.LayoutOrder

    for idx,opt in ipairs(opts) do
        local ob=Instance.new("TextButton",List)
        ob.Size=UDim2.new(1,0,0,24); ob.BackgroundColor3=Color3.fromRGB(28,28,34); ob.BorderSizePixel=0; ob.LayoutOrder=idx; ob.ZIndex=111; ob.Text="  "..opt; ob.Font=Enum.Font.Gotham; ob.TextSize=11; ob.TextColor3=(opt==sel) and Theme.AccentLt or Theme.Text; ob.TextXAlignment=Enum.TextXAlignment.Left; ob.AutoButtonColor=false
        ob.MouseEnter:Connect(function() ob.BackgroundColor3=Color3.fromRGB(38,38,50) end)
        ob.MouseLeave:Connect(function() ob.BackgroundColor3=Color3.fromRGB(28,28,34) end)
        ob.MouseButton1Click:Connect(function()
            sel=opt; DBtn.Text=opt; CloseDrops()
            for _,c in ipairs(List:GetChildren()) do
                if c:IsA("TextButton") then c.TextColor3=c.Text:gsub("^%s+","")==opt and Theme.AccentLt or Theme.Text end
            end
            pcall(cb,sel)
        end)
    end

    DBtn.MouseButton1Click:Connect(function()
        if openList==List then CloseDrops(); return end
        CloseDrops(); local ap=DBtn.AbsolutePosition; local as=DBtn.AbsoluteSize
        List.Position=UDim2.new(0,ap.X,0,ap.Y+as.Y+2); List.Size=UDim2.new(0,as.X,0,#opts*24); List.Visible=true; openList=List; DropOverlay.Active=true
    end)
    return function() return sel end
end

local statBig,statSub
local function MkStatusCard(parent,order)
    local card=Instance.new("Frame",parent); card.Size=UDim2.new(0.98,0,0,44); card.BackgroundColor3=Theme.Button; card.BorderSizePixel=0; card.LayoutOrder=order
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",card).Color=Theme.Stroke
    statBig=Instance.new("TextLabel",card)
    statBig.Size=UDim2.new(1,-12,0,20); statBig.Position=UDim2.new(0,12,0,5); statBig.BackgroundTransparency=1; statBig.Text="[ DISABLED ]"; statBig.Font=Enum.Font.GothamBold; statBig.TextSize=13; statBig.TextColor3=Theme.Red; statBig.TextXAlignment=Enum.TextXAlignment.Left
    statSub=Instance.new("TextLabel",card)
    statSub.Size=UDim2.new(1,-12,0,14); statSub.Position=UDim2.new(0,12,0,26); statSub.BackgroundTransparency=1; statSub.Text="Wait for activation..."; statSub.Font=Enum.Font.Gotham; statSub.TextSize=10; statSub.TextColor3=Theme.SubText; statSub.TextXAlignment=Enum.TextXAlignment.Left
end

local TFarm   = CreateTab("Auto Farm","⚔")
local TCombat = CreateTab("Combat","⚙")
local TESP    = CreateTab("ESP","●")
local TMisc   = CreateTab("Misc","★")

-- FARM TAB
MkSection(TFarm,"Farming",1)
MkDrop(TFarm,"Target Method",{"Closest","Furthest","Random","Most HP","Least HP"},"Closest",2, function(v) Cfg.Farm.TargetMethod=v end)
MkToggle(TFarm,"Face At Target","Rotate toward enemy",true,3,function(v) Cfg.Farm.FaceTarget=v end)
MkToggle(TFarm,"Fast Attack","Spam attacks",true,4,function(v) Cfg.Farm.FastAttack=v end)
MkToggle(TFarm,"Use Skills","Fire skill keys (1-4)",true,5,function(v) Cfg.Farm.UseSkills=v end)

local farmBtn=MkButton(TFarm,"▶  Enable Farm",6,function() end)
local farmOn=false
farmBtn.MouseButton1Click:Connect(function()
    farmOn=not farmOn; Cfg.Farm.Enabled=farmOn
    farmBtn.Text=farmOn and "  ■  Disable Farm" or "  ▶  Enable Farm"
    farmBtn.BackgroundColor3=farmOn and Color3.fromRGB(38,28,58) or Theme.Button
end)

MkSection(TFarm,"Status",7); MkStatusCard(TFarm,8)

MkSection(TFarm,"Blocking",9)
MkToggle(TFarm,"Enable Auto Block","Hold F when enemies nearby",true,10,function(v) Cfg.Block.Enabled=v end)
MkToggle(TFarm,"Auto Punish","Counter after blocking",true,11,function(v) Cfg.Block.AutoPunish=v end)
MkSlider(TFarm,"Detection Range",5,80,20," studs",13,function(v) Cfg.Block.DetectRange=v end)

-- COMBAT TAB
MkSection(TCombat,"Settings",1)
MkDrop(TCombat,"Teleport Method",{"Lerp","Tween","Instant"},"Lerp",2,function(v) Cfg.Combat.TpMethod=v end)
MkDrop(TCombat,"Movement Mode",{"Orbit (Dodge)","Follow","Static"},"Orbit (Dodge)",3,function(v) Cfg.Combat.MoveMode=v:gsub(" %(Dodge%)","") end)
MkSlider(TCombat,"Tween Speed",50,400,135," studs/s",4,function(v) Cfg.Combat.TweenSpeed=v end)
MkSlider(TCombat,"Follow Distance",2,30,4," studs",5,function(v) Cfg.Combat.FollowDist=v end)
MkSection(TCombat,"Main Configurations",7)
MkToggle(TCombat,"Auto Flee (Low HP)","Retreat when HP is low",false,8,function(v) Cfg.Combat.AutoFlee=v end)
MkSlider(TCombat,"Flee Health %",5,80,20,"%",9,function(v) Cfg.Combat.FleeHP=v end)

-- ESP TAB
MkSection(TESP,"Enable",1)
MkToggle(TESP,"Enable ESP Players","Show enemy overlays",false,2,function(v) Cfg.ESP.Enabled=v end)
MkSection(TESP,"Configurations",3)
MkToggle(TESP,"Box","Draw bounding box",true,4,function(v) Cfg.ESP.Box=v end)
MkToggle(TESP,"Tracers","Draw tracer lines",true,5,function(v) Cfg.ESP.Tracers=v end)
MkToggle(TESP,"Health Bar","Show health bar",true,6,function(v) Cfg.ESP.HealthBar=v end)

-- MISC TAB
MkSection(TMisc,"Stuff",1)
MkToggle(TMisc,"Auto Tech (Jump on Ragdoll)","Auto-jump when ragdolled",false,3,function(v) Cfg.Misc.AutoTech=v end)
MkToggle(TMisc,"WalkSpeed Bypass (Velocity)","Speed via BodyVelocity",false,4,function(v) Cfg.Misc.WsBypass=v; SetSpeedBypass(v) end)
MkSlider(TMisc,"Speed Amount",16,500,100," studs/s",5,function(v) Cfg.Misc.Speed=v end)
MkToggle(TMisc,"Infinite Jump","Jump repeatedly in air",false,6,function(v) Cfg.Misc.InfJump=v; SetInfJump(v) end)
MkButton(TMisc,"⚡  FPS Boost",12,function()
    pcall(function() settings().Rendering.QualityLevel=1 end)
    Lighting.GlobalShadows=false
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Fire") then v.Enabled=false end
    end
end)

if TabButtons[1] then TabButtons[1].Btn.MouseButton1Click:Fire() end

-- ══════════════════════════════════════════════
-- STABILIZED HEARTBEAT LOOP (ISOLATED PCALLS)
-- ══════════════════════════════════════════════
local blockTimer=0; local lastBlocker=nil; local lastTech=0; local lastAfk=0

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Anti-AFK
    pcall(function()
        if Cfg.Misc.AntiAFK and now-lastAfk > 60 then
            lastAfk=now; local h=Hum(LP); if h then h.Jump=false end
        end
    end)

    -- Auto Tech
    pcall(function()
        if Cfg.Misc.AutoTech then
            local h=Hum(LP)
            if h then
                local st=h:GetState()
                if (st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown)
                and now-lastTech>0.3 then lastTech=now; h.Jump=true end
            end
        end
    end)

    -- Speed Bypass
    pcall(function()
        if Cfg.Misc.WsBypass and speedBV then
            local hum=Hum(LP)
            if hum then speedBV.Velocity=hum.MoveDirection*Cfg.Misc.Speed end
        end
    end)

    -- Auto Block
    pcall(function()
        if Cfg.Block.Enabled and Cfg.Block.AutoBlock then
            local should, att = false, nil
            for _,p in ipairs(GetEnemies()) do
                if Dist(p) <= Cfg.Block.DetectRange then should=true; att=p; break end
            end
            if should then
                if Cfg.Block.FaceAttacker and att then FaceTarget(att) end
                if now >= blockTimer then
                    blockTimer = now + Cfg.Block.BlockDelay; SetBlock(true); lastBlocker=att
                end
            else
                if isBlocking then
                    if Cfg.Block.AutoPunish and lastBlocker then SetBlock(false); DoAttack(lastBlocker)
                    else SetBlock(false) end
                    lastBlocker = nil
                end
            end
        else 
            SetBlock(false) 
        end
    end)

    -- Auto Farm
    pcall(function()
        if Cfg.Farm.Enabled then
            local t = GetTarget()
            if t then
                local h = Hum(LP)
                if Cfg.Combat.AutoFlee and h and (h.Health/h.MaxHealth*100) <= Cfg.Combat.FleeHP then
                    local r, tr = Root(LP), Root(t)
                    if r and tr then
                        local away = (r.Position - tr.Position).Unit
                        if away.X ~= away.X then away = Vector3.new(0,0,1) end
                        r.CFrame = CFrame.new(r.Position + away * 35)
                    end
                else
                    if Cfg.Combat.MoveMode == "Orbit" then OrbitTarget(t) else MoveToTarget(t) end
                    if Cfg.Farm.FaceTarget then FaceTarget(t) end
                    if Cfg.Farm.FastAttack then DoAttack(t) end
                    UseSkill(t)
                end
            end
            if statBig then
                statBig.Text="[ ACTIVE ]"; statBig.TextColor3=Theme.Green
                statSub.Text="Target: " .. (t and t.Name or "searching...")
            end
        else
            if statBig then
                statBig.Text="[ DISABLED ]"; statBig.TextColor3=Theme.Red
                statSub.Text="Wait for activation..."
            end
        end
    end)
end)

-- ══════════════════════════════════════════════
-- SAFE ESP (Drawing API Check)
-- ══════════════════════════════════════════════
if HAS_DRAWING then
    local ESPObjs={}
    local function MakeESP(p)
        if p==LP or ESPObjs[p] then return end
        local o={ Box={} }
        for i=1,4 do
            local l=Drawing.new("Line"); l.Thickness=1.5; l.Color=Theme.AccentLt; l.Visible=false; o.Box[i]=l
        end
        o.Tracer=Drawing.new("Line"); o.Tracer.Thickness=1; o.Tracer.Color=Theme.AccentLt; o.Tracer.Visible=false
        o.HpBg=Drawing.new("Square"); o.HpBg.Filled=true; o.HpBg.Color=Color3.fromRGB(18,18,18); o.HpBg.Visible=false
        o.Hp=Drawing.new("Square"); o.Hp.Filled=true; o.Hp.Color=Color3.fromRGB(0,205,60); o.Hp.Visible=false
        ESPObjs[p]=o
    end
    local function RemESP(p)
        local o=ESPObjs[p]; if not o then return end
        for _,v in pairs(o) do
            if type(v)=="table" then for _,l in ipairs(v) do pcall(function() l:Remove() end) end
            else pcall(function() v:Remove() end) end
        end
        ESPObjs[p]=nil
    end
    local function HideESP(o)
        for _,v in pairs(o) do
            if type(v)=="table" then for _,l in ipairs(v) do l.Visible=false end
            else v.Visible=false end
        end
    end
    RunService.RenderStepped:Connect(function()
        pcall(function()
            if not Cfg.ESP.Enabled then for _,o in pairs(ESPObjs) do HideESP(o) end; return end
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP then MakeESP(p) end end
            for p,o in pairs(ESPObjs) do
                if not p.Parent or not Alive(p) then RemESP(p)
                else
                    local r=Root(p); local h=Hum(p)
                    if not r or not h then HideESP(o)
                    else
                        local sp,vis,dep=Camera:WorldToViewportPoint(r.Position)
                        if not vis or dep<=0 then HideESP(o)
                        else
                            local tp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,3.2,0))
                            local bp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,-3.2,0))
                            local ht=math.abs(tp.Y-bp.Y); local wd=ht*0.52
                            local L,R,T,B=sp.X-wd/2,sp.X+wd/2,tp.Y,bp.Y
                            local corners={{Vector2.new(L,T),Vector2.new(R,T)},{Vector2.new(L,B),Vector2.new(R,B)},{Vector2.new(L,T),Vector2.new(L,B)},{Vector2.new(R,T),Vector2.new(R,B)}}
                            for i,ln in ipairs(o.Box) do ln.From=corners[i][1]; ln.To=corners[i][2]; ln.Visible=Cfg.ESP.Box end
                            local vp=Camera.ViewportSize
                            o.Tracer.From=Vector2.new(vp.X/2,vp.Y); o.Tracer.To=Vector2.new(sp.X,sp.Y); o.Tracer.Visible=Cfg.ESP.Tracers
                            local pct=math.clamp(h.Health/h.MaxHealth,0,1)
                            o.HpBg.Size=Vector2.new(4,ht); o.HpBg.Position=Vector2.new(L-7,T); o.HpBg.Visible=Cfg.ESP.HealthBar
                            o.Hp.Size=Vector2.new(4,ht*pct); o.Hp.Position=Vector2.new(L-7,T+ht*(1-pct)); o.Hp.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0); o.Hp.Visible=Cfg.ESP.HealthBar
                        end
                    end
                end
            end
        end)
    end)
    Players.PlayerRemoving:Connect(function(p) RemESP(p) end)
    ScreenGui.AncestryChanged:Connect(function() for p in pairs(ESPObjs) do RemESP(p) end end)
end
