--[[
    Imp Hub X - Jujutsu Shenanigans
    Educational Script v2 - UI Fixed
    Press RightShift to toggle visibility
]]

-- ─────────────────────────────────────────────
-- SERVICES
-- ─────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

-- ─────────────────────────────────────────────
-- EXECUTOR-SAFE GUI PARENT
-- gethui() works on most modern executors
-- falls back to CoreGui, then PlayerGui
-- ─────────────────────────────────────────────
local function GetGuiParent()
    if gethui then return gethui() end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end
local GuiParent = GetGuiParent()

-- Destroy old instance if re-running
local old = GuiParent:FindFirstChild("ImpHubX")
if old then old:Destroy() end

-- ─────────────────────────────────────────────
-- COLORS
-- ─────────────────────────────────────────────
local C = {
    BgDark     = Color3.fromRGB(18,  18,  22 ),
    BgMid      = Color3.fromRGB(25,  25,  32 ),
    BgPanel    = Color3.fromRGB(30,  30,  38 ),
    BgSection  = Color3.fromRGB(36,  36,  46 ),
    Purple     = Color3.fromRGB(140, 60,  255),
    PurpleDim  = Color3.fromRGB(90,  40,  170),
    TextWhite  = Color3.fromRGB(230, 230, 235),
    TextGray   = Color3.fromRGB(150, 150, 160),
    TextRed    = Color3.fromRGB(255, 70,  70 ),
    TextGreen  = Color3.fromRGB(60,  220, 100),
    NavBg      = Color3.fromRGB(22,  22,  28 ),
    NavActive  = Color3.fromRGB(70,  40,  140),
    Separator  = Color3.fromRGB(50,  50,  65 ),
    ToggleOff  = Color3.fromRGB(60,  60,  75 ),
    ToggleOn   = Color3.fromRGB(140, 60,  255),
    CheckBg    = Color3.fromRGB(40,  40,  52 ),
    SliderBg   = Color3.fromRGB(50,  50,  65 ),
    SliderFill = Color3.fromRGB(140, 60,  255),
    DropBg     = Color3.fromRGB(35,  35,  45 ),
    ButtonBg   = Color3.fromRGB(45,  35,  70 ),
    ButtonHov  = Color3.fromRGB(70,  50,  120),
}

-- ─────────────────────────────────────────────
-- CONFIGURATION STATE
-- ─────────────────────────────────────────────
local Cfg = {
    Farm = {
        Enabled      = false,
        TargetPlayer = "All",
        TargetMethod = "Closest",
        FaceTarget   = true,
        FastAttack   = true,
        UseSkills    = true,
    },
    Block = {
        Enabled        = false,
        AutoBlock      = true,
        AutoPunish     = true,
        FaceAttacker   = true,
        ShowRange      = false,
        DetectRange    = 20,
        BlockDelay     = 0,
    },
    Aim = {
        Enabled    = false,
        Mode       = "Camera",
        TargetPart = "Head",
        Prediction = false,
    },
    Combat = {
        Enabled          = false,
        TpMethod         = "Tween",
        MoveMode         = "Orbit",
        TweenSpeed       = 135,
        FollowDist       = 4,
        SmartKiting      = true,
        AutoFlee         = false,
        FleeHP           = 20,
        PriorClosest     = true,
        HunterMode       = false,
        SkillName        = "Divergent Fist",
        SkillDelay       = 6,
        AvoidNoTarget    = true,
        SemiKillAura     = false,
        SpinBot          = false,
    },
    ESP = {
        Enabled   = false,
        Box       = true,
        Tracers   = true,
        HealthBar = true,
        Distance  = true,
        Name      = true,
        Moveset   = true,
    },
    Misc = {
        AntiRagdoll  = false,
        AutoTech     = false,
        WsBypass     = false,
        Speed        = 100,
        InfJump      = false,
        Fullbright   = false,
        WhiteScreen  = false,
        AntiAFK      = true,
        ClickTP      = false,
        TimeHour     = 14,
    },
}

-- ─────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────
local function Char(p)   return p and p.Character end
local function Root(p)   local c=Char(p) return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p)    local c=Char(p) return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p)  local h=Hum(p) return h and h.Health>0 end
local function Dist(p)
    local a,b = Root(LocalPlayer), Root(p)
    return (a and b) and (a.Position-b.Position).Magnitude or math.huge
end

local function GetEnemies()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and Alive(p) then t[#t+1]=p end
    end
    return t
end

local function GetTarget()
    local enemies = GetEnemies()
    if #enemies==0 then return nil end
    if Cfg.Farm.TargetPlayer~="All" then
        for _,p in ipairs(enemies) do
            if p.Name==Cfg.Farm.TargetPlayer then return p end
        end
        return nil
    end
    local m = Cfg.Farm.TargetMethod
    if m=="Closest" then table.sort(enemies,function(a,b) return Dist(a)<Dist(b) end)
    elseif m=="Furthest" then table.sort(enemies,function(a,b) return Dist(a)>Dist(b) end)
    elseif m=="Most HP" then table.sort(enemies,function(a,b)
        return (Hum(a) and Hum(a).Health or 0)>(Hum(b) and Hum(b).Health or 0) end)
    elseif m=="Least HP" then table.sort(enemies,function(a,b)
        return (Hum(a) and Hum(a).Health or 0)<(Hum(b) and Hum(b).Health or 0) end)
    elseif m=="Random" then return enemies[math.random(1,#enemies)] end
    return enemies[1]
end

-- ─────────────────────────────────────────────
-- MOVEMENT
-- ─────────────────────────────────────────────
local orbitAngle = 0
local function TweenTo(cf, spd)
    local r=Root(LocalPlayer) if not r then return end
    local d = (r.Position-cf.Position).Magnitude
    local dur = math.clamp(d/spd, 0.05, 1.2)
    local tw = TweenService:Create(r, TweenInfo.new(dur,Enum.EasingStyle.Linear), {CFrame=cf})
    tw:Play() tw.Completed:Wait()
end

local function MoveToTarget(tgt)
    local r=Root(LocalPlayer) local tr=Root(tgt)
    if not r or not tr then return end
    local dir=(r.Position-tr.Position).Unit
    local cf=tr.CFrame*CFrame.new(dir*Cfg.Combat.FollowDist)
    if Cfg.Combat.TpMethod=="Instant" then r.CFrame=cf
    elseif Cfg.Combat.TpMethod=="Lerp" then r.CFrame=r.CFrame:Lerp(cf,0.3)
    else TweenTo(cf, Cfg.Combat.TweenSpeed) end
end

local function OrbitTarget(tgt)
    local r=Root(LocalPlayer) local tr=Root(tgt)
    if not r or not tr then return end
    orbitAngle=orbitAngle+0.05
    local d=Cfg.Combat.FollowDist+2
    local x=tr.Position.X+math.cos(orbitAngle)*d
    local z=tr.Position.Z+math.sin(orbitAngle)*d
    r.CFrame=CFrame.new(x,tr.Position.Y,z)*CFrame.Angles(0,math.atan2(tr.Position.X-x,tr.Position.Z-z),0)
end

local function FaceTarget(tgt)
    local r=Root(LocalPlayer) local tr=Root(tgt)
    if not r or not tr then return end
    r.CFrame=CFrame.new(r.Position,Vector3.new(tr.Position.X,r.Position.Y,tr.Position.Z))
end

-- ─────────────────────────────────────────────
-- ATTACK / SKILL
-- ─────────────────────────────────────────────
local lastAtk=0
local function DoAttack(tgt)
    if tick()-lastAtk < 0.15 then return end
    lastAtk=tick()
    local rs=game:GetService("ReplicatedStorage")
    local remote=rs:FindFirstChild("Combat") or rs:FindFirstChild("Attack") or rs:FindFirstChild("CombatEvent")
    if remote then
        if remote:IsA("RemoteEvent") then remote:FireServer("Attack",Root(tgt))
        elseif remote:IsA("RemoteFunction") then remote:InvokeServer("Attack",Root(tgt)) end
    end
end

local lastSkill=0
local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    if tick()-lastSkill < Cfg.Combat.SkillDelay then return end
    if Cfg.Combat.AvoidNoTarget and not tgt then return end
    lastSkill=tick()
    local vgp=pcall(function() return game:GetService("VirtualInputManager") end)
    local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F}
    local vgi=game:GetService("VirtualInputManager")
    if vgi then
        local k=keys[math.random(1,#keys)]
        vgi:SendKeyEvent(true,k,false,game)
        task.delay(0.05,function() vgi:SendKeyEvent(false,k,false,game) end)
    end
end

-- ─────────────────────────────────────────────
-- BLOCKING
-- ─────────────────────────────────────────────
local isBlocking=false
local function SetBlock(state)
    if isBlocking==state then return end
    isBlocking=state
    local rs=game:GetService("ReplicatedStorage")
    local rem=rs:FindFirstChild("Block") or rs:FindFirstChild("BlockEvent")
    if rem and rem:IsA("RemoteEvent") then
        rem:FireServer(state and "BlockStart" or "BlockEnd")
    end
end

local rangeAdorn
local function ToggleRangeSphere(show)
    if rangeAdorn then rangeAdorn:Destroy() rangeAdorn=nil end
    if show then
        local r=Root(LocalPlayer)
        if r then
            local s=Instance.new("SelectionSphere",r)
            s.Color3=Color3.fromRGB(100,100,255)
            s.SurfaceTransparency=0.7
            s.Adornee=r
            rangeAdorn=s
        end
    end
end

-- ─────────────────────────────────────────────
-- AIMLOCK
-- ─────────────────────────────────────────────
local aimConn
local function StartAimlock()
    if aimConn then aimConn:Disconnect() end
    aimConn=RunService.RenderStepped:Connect(function()
        if not Cfg.Aim.Enabled then return end
        local tgt=GetTarget()
        if not tgt then return end
        local char=Char(tgt)
        local part=char and (char:FindFirstChild(Cfg.Aim.TargetPart) or char:FindFirstChild("HumanoidRootPart"))
        if not part then return end
        local pos=part.Position
        if Cfg.Aim.Prediction then
            local v=part.AssemblyLinearVelocity
            pos=pos+v*0.1
        end
        if Cfg.Aim.Mode=="Camera" then
            Camera.CFrame=CFrame.new(Camera.CFrame.Position,pos)
        elseif Cfg.Aim.Mode=="Body" then
            local r=Root(LocalPlayer)
            if r then r.CFrame=CFrame.new(r.Position,Vector3.new(pos.X,r.Position.Y,pos.Z)) end
        end
    end)
end
StartAimlock()

-- ─────────────────────────────────────────────
-- ESP (Drawing API)
-- ─────────────────────────────────────────────
local ESPObjs={}

local function GetMoveset(p)
    local c=Char(p)
    if c then
        for _,n in ipairs({"Moveset","Class","Style"}) do
            local v=c:FindFirstChild(n) if v then return v.Value end
        end
    end
    local ls=p:FindFirstChild("leaderstats")
    if ls then
        for _,n in ipairs({"Moveset","Class"}) do
            local v=ls:FindFirstChild(n) if v then return v.Value end
        end
    end
    return "???"
end

local function MakeESP(p)
    if p==LocalPlayer or ESPObjs[p] then return end
    local o={}
    o.Box={}
    for i=1,4 do
        local l=Drawing.new("Line")
        l.Thickness=1.5 l.Color=Color3.fromRGB(160,60,255) l.Visible=false l.ZIndex=2
        o.Box[i]=l
    end
    o.Tracer=Drawing.new("Line")
    o.Tracer.Thickness=1 o.Tracer.Color=Color3.fromRGB(160,60,255) o.Tracer.Visible=false
    o.HpBg=Drawing.new("Square")
    o.HpBg.Filled=true o.HpBg.Color=Color3.fromRGB(20,20,20) o.HpBg.Visible=false
    o.Hp=Drawing.new("Square")
    o.Hp.Filled=true o.Hp.Color=Color3.fromRGB(0,200,60) o.Hp.Visible=false
    o.Name=Drawing.new("Text")
    o.Name.Size=13 o.Name.Color=Color3.fromRGB(255,255,255) o.Name.Center=true o.Name.Outline=true o.Name.Visible=false
    o.Dist=Drawing.new("Text")
    o.Dist.Size=11 o.Dist.Color=Color3.fromRGB(200,200,200) o.Dist.Center=true o.Dist.Outline=true o.Dist.Visible=false
    o.Move=Drawing.new("Text")
    o.Move.Size=11 o.Move.Color=Color3.fromRGB(180,140,255) o.Move.Center=true o.Move.Outline=true o.Move.Visible=false
    ESPObjs[p]=o
end

local function KillESP(p)
    local o=ESPObjs[p] if not o then return end
    for _,v in pairs(o) do
        if type(v)=="table" then for _,l in ipairs(v) do l:Remove() end
        elseif v.Remove then v:Remove() end
    end
    ESPObjs[p]=nil
end

local function HideESP(o)
    for _,v in pairs(o) do
        if type(v)=="table" then for _,l in ipairs(v) do l.Visible=false end
        elseif v then v.Visible=false end
    end
end

local espConn
local function StartESP()
    if espConn then espConn:Disconnect() end
    espConn=RunService.RenderStepped:Connect(function()
        if not Cfg.ESP.Enabled then
            for _,o in pairs(ESPObjs) do HideESP(o) end
            return
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then MakeESP(p) end
        end
        for p,o in pairs(ESPObjs) do
            if not p.Parent or not Alive(p) then
                KillESP(p)
            else
                local r=Root(p) local h=Hum(p)
                if not r or not h then HideESP(o) else
                    local sp,vis,dep=Camera:WorldToViewportPoint(r.Position)
                    if not vis or dep<=0 then HideESP(o) else
                        local tp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,2.8,0))
                        local bp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,-3,0))
                        local ht=math.abs(tp.Y-bp.Y)
                        local wd=ht*0.55
                        local L,R,T,B=sp.X-wd/2,sp.X+wd/2,tp.Y,bp.Y
                        local corners={{Vector2.new(L,T),Vector2.new(R,T)},{Vector2.new(L,B),Vector2.new(R,B)},
                                       {Vector2.new(L,T),Vector2.new(L,B)},{Vector2.new(R,T),Vector2.new(R,B)}}
                        for i,ln in ipairs(o.Box) do ln.From=corners[i][1] ln.To=corners[i][2] ln.Visible=Cfg.ESP.Box end
                        local vp=Camera.ViewportSize
                        o.Tracer.From=Vector2.new(vp.X/2,vp.Y) o.Tracer.To=Vector2.new(sp.X,sp.Y) o.Tracer.Visible=Cfg.ESP.Tracers
                        local pct=h.Health/h.MaxHealth
                        o.HpBg.Size=Vector2.new(4,ht) o.HpBg.Position=Vector2.new(L-6,T) o.HpBg.Visible=Cfg.ESP.HealthBar
                        o.Hp.Size=Vector2.new(4,ht*pct) o.Hp.Position=Vector2.new(L-6,T+ht*(1-pct))
                        o.Hp.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0) o.Hp.Visible=Cfg.ESP.HealthBar
                        o.Name.Text=p.Name o.Name.Position=Vector2.new(sp.X,T-15) o.Name.Visible=Cfg.ESP.Name
                        o.Dist.Text=math.floor(Dist(p)).." studs" o.Dist.Position=Vector2.new(sp.X,B+2) o.Dist.Visible=Cfg.ESP.Distance
                        o.Move.Text="["..GetMoveset(p).."]" o.Move.Position=Vector2.new(sp.X,B+14) o.Move.Visible=Cfg.ESP.Moveset
                    end
                end
            end
        end
    end)
end
StartESP()

-- ─────────────────────────────────────────────
-- MISC SYSTEMS
-- ─────────────────────────────────────────────
local function AntiRagdoll(char)
    if not char then return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
            v.Enabled=not Cfg.Misc.AntiRagdoll
        end
    end
end

local speedBV
local function SetSpeedBypass(on)
    local r=Root(LocalPlayer) if not r then return end
    if on then
        if not speedBV then
            speedBV=Instance.new("BodyVelocity")
            speedBV.MaxForce=Vector3.new(1e4,0,1e4)
            speedBV.Velocity=Vector3.new(0,0,0)
            speedBV.Parent=r
        end
    else
        if speedBV then speedBV:Destroy() speedBV=nil end
    end
end

local jumpConn
local function SetInfJump(on)
    if jumpConn then jumpConn:Disconnect() jumpConn=nil end
    if on then
        jumpConn=UserInputService.JumpRequest:Connect(function()
            local h=Hum(LocalPlayer)
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local origAmb,origBright
local function SetFullbright(on)
    if on then
        origAmb=Lighting.Ambient origBright=Lighting.Brightness
        Lighting.Ambient=Color3.fromRGB(255,255,255) Lighting.Brightness=2 Lighting.FogEnd=1e6
    else
        if origAmb then Lighting.Ambient=origAmb Lighting.Brightness=origBright or 1 end
    end
end

local wsGui
local function SetWhiteScreen(on)
    if wsGui then wsGui:Destroy() wsGui=nil end
    if on then
        wsGui=Instance.new("ScreenGui",GuiParent)
        wsGui.Name="ImpHubXWhite" wsGui.ResetOnSpawn=false wsGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        local f=Instance.new("Frame",wsGui)
        f.Size=UDim2.new(1,0,1,0) f.BackgroundColor3=Color3.fromRGB(255,255,255) f.BackgroundTransparency=0.4 f.BorderSizePixel=0
    end
end

local ctpConn
local function SetClickTP(on)
    if ctpConn then ctpConn:Disconnect() ctpConn=nil end
    if on then
        ctpConn=UserInputService.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local r=Root(LocalPlayer)
                if r then r.CFrame=CFrame.new(Mouse.Hit.Position+Vector3.new(0,3,0)) end
            end
        end)
    end
end

local afkConn
local function SetAntiAFK(on)
    if afkConn then afkConn:Disconnect() afkConn=nil end
    if on then
        local vgi=game:GetService("VirtualInputManager")
        afkConn=RunService.Heartbeat:Connect(function()
            if vgi then
                -- tiny nudge to reset AFK timer
                vgi:SendMouseWheelEvent(0,0,true,game)
            end
        end)
    end
end

local spinConn
local function SetSpinBot(on)
    if spinConn then spinConn:Disconnect() spinConn=nil end
    if on then
        spinConn=RunService.RenderStepped:Connect(function()
            local r=Root(LocalPlayer)
            if r then r.CFrame=r.CFrame*CFrame.Angles(0,math.rad(20),0) end
        end)
    end
end

local killAuraConn
local function SetKillAura(on)
    if killAuraConn then killAuraConn:Disconnect() killAuraConn=nil end
    if on then
        killAuraConn=RunService.Heartbeat:Connect(function()
            for _,e in ipairs(GetEnemies()) do
                if Dist(e)<=25 then DoAttack(e) end
            end
        end)
    end
end

local specConn
local function SpectatePlayer(tgt)
    if specConn then specConn:Disconnect() specConn=nil end
    if not tgt then return end
    Camera.CameraType=Enum.CameraType.Scriptable
    specConn=RunService.RenderStepped:Connect(function()
        local tr=Root(tgt)
        if tr then Camera.CFrame=CFrame.new(tr.Position+Vector3.new(0,5,12),tr.Position) end
    end)
end
local function StopSpec()
    if specConn then specConn:Disconnect() specConn=nil end
    Camera.CameraType=Enum.CameraType.Custom
end

local function ServerHop()
    local ok,data=pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if not ok then return end
    for _,sv in ipairs(data.data or {}) do
        if sv.id~=game.JobId and sv.playing<sv.maxPlayers then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,sv.id,LocalPlayer)
            return
        end
    end
end

local function FPSBoost()
    settings().Rendering.QualityLevel=1
    Lighting.GlobalShadows=false
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Fire") then
            v.Enabled=false
        end
    end
end

-- ─────────────────────────────────────────────
-- MAIN FARM LOOP
-- ─────────────────────────────────────────────
local farmConn
local function StopFarm() if farmConn then farmConn:Disconnect() farmConn=nil end end
local function StartFarm()
    StopFarm()
    farmConn=RunService.Heartbeat:Connect(function()
        if not Cfg.Farm.Enabled then return end
        local tgt=GetTarget() if not tgt then return end
        -- Auto flee
        local h=Hum(LocalPlayer)
        if Cfg.Combat.AutoFlee and h and (h.Health/h.MaxHealth*100)<=Cfg.Combat.FleeHP then
            local r=Root(LocalPlayer) local tr=Root(tgt)
            if r and tr then
                local away=(r.Position-tr.Position).Unit
                r.CFrame=CFrame.new(r.Position+away*30)
            end
            return
        end
        -- Move
        if Cfg.Combat.MoveMode=="Orbit" then OrbitTarget(tgt) else MoveToTarget(tgt) end
        -- Face
        if Cfg.Farm.FaceTarget then FaceTarget(tgt) end
        -- Attack
        if Cfg.Farm.FastAttack then DoAttack(tgt) end
        -- Skill
        UseSkill(tgt)
    end)
end

-- Block loop
local blockConn
local lastAttacker
local function StartBlock()
    if blockConn then blockConn:Disconnect() end
    blockConn=RunService.Heartbeat:Connect(function()
        if not Cfg.Block.Enabled then SetBlock(false) return end
        if not Cfg.Block.AutoBlock then return end
        local shouldBlock,attacker=false,nil
        for _,p in ipairs(GetEnemies()) do
            if Dist(p)<=Cfg.Block.DetectRange then shouldBlock=true attacker=p break end
        end
        if shouldBlock then
            if Cfg.Block.FaceAttacker and attacker then FaceTarget(attacker) end
            task.wait(Cfg.Block.BlockDelay)
            SetBlock(true)
            lastAttacker=attacker
        else
            if isBlocking and Cfg.Block.AutoPunish and lastAttacker then
                SetBlock(false) task.wait(0.05) DoAttack(lastAttacker)
            else
                SetBlock(false)
            end
            lastAttacker=nil
        end
    end)
end
StartBlock()

-- Misc loop
local miscConn
local lastTech=0
local function StartMisc()
    if miscConn then miscConn:Disconnect() end
    miscConn=RunService.Heartbeat:Connect(function()
        -- Auto Tech
        if Cfg.Misc.AutoTech then
            local h=Hum(LocalPlayer)
            if h and (h:GetState()==Enum.HumanoidStateType.Ragdoll
                   or h:GetState()==Enum.HumanoidStateType.FallingDown) then
                if tick()-lastTech>0.3 then lastTech=tick() h.Jump=true end
            end
        end
        -- Speed bypass direction
        if Cfg.Misc.WsBypass and speedBV then
            local c=LocalPlayer.Character
            local hum=c and c:FindFirstChildOfClass("Humanoid")
            if hum then speedBV.Velocity=hum.MoveDirection*Cfg.Misc.Speed end
        end
        -- Anti ragdoll
        local c=LocalPlayer.Character
        if c then AntiRagdoll(c) end
        -- Time changer
        Lighting.ClockTime=Cfg.Misc.TimeHour
    end)
end
StartMisc()

-- CharAdded
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    AntiRagdoll(char)
    SetSpeedBypass(Cfg.Misc.WsBypass)
    SetInfJump(Cfg.Misc.InfJump)
    SetClickTP(Cfg.Misc.ClickTP)
end)
Players.PlayerRemoving:Connect(KillESP)

-- ═══════════════════════════════════════════════════════════
--   GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════════════

local SG=Instance.new("ScreenGui")
SG.Name="ImpHubX" SG.ResetOnSpawn=false SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset=true SG.Parent=GuiParent

-- ─── MAIN FRAME ───────────────────────────────────────────
local Main=Instance.new("Frame",SG)
Main.Name="Main" Main.Size=UDim2.new(0,800,0,540)
Main.Position=UDim2.new(0.5,-400,0.5,-270)
Main.BackgroundColor3=C.BgDark Main.BorderSizePixel=0 Main.ClipsDescendants=true
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,10)
local mstroke=Instance.new("UIStroke",Main)
mstroke.Color=C.Purple mstroke.Thickness=1.5 mstroke.Transparency=0.5

-- ─── TITLE BAR ────────────────────────────────────────────
local TBar=Instance.new("Frame",Main)
TBar.Size=UDim2.new(1,0,0,46) TBar.BackgroundColor3=C.BgMid TBar.BorderSizePixel=0
Instance.new("UICorner",TBar).CornerRadius=UDim.new(0,10)
-- patch bottom of TBar so it's flat
local tpatch=Instance.new("Frame",TBar)
tpatch.Size=UDim2.new(1,0,0.5,0) tpatch.Position=UDim2.new(0,0,0.5,0)
tpatch.BackgroundColor3=C.BgMid tpatch.BorderSizePixel=0

local TIcon=Instance.new("Frame",TBar)
TIcon.Size=UDim2.new(0,30,0,30) TIcon.Position=UDim2.new(0,10,0.5,-15)
TIcon.BackgroundColor3=C.Purple TIcon.BorderSizePixel=0
Instance.new("UICorner",TIcon).CornerRadius=UDim.new(0,6)
local TIconL=Instance.new("TextLabel",TIcon)
TIconL.Size=UDim2.new(1,0,1,0) TIconL.BackgroundTransparency=1
TIconL.Text="I" TIconL.Font=Enum.Font.GothamBold
TIconL.TextColor3=Color3.fromRGB(255,255,255) TIconL.TextSize=16

local TTitle=Instance.new("TextLabel",TBar)
TTitle.Size=UDim2.new(0,200,0,18) TTitle.Position=UDim2.new(0,48,0,5)
TTitle.BackgroundTransparency=1 TTitle.Text="Imp Hub X"
TTitle.Font=Enum.Font.GothamBold TTitle.TextColor3=C.TextWhite TTitle.TextSize=15
TTitle.TextXAlignment=Enum.TextXAlignment.Left

local TSub=Instance.new("TextLabel",TBar)
TSub.Size=UDim2.new(0,200,0,13) TSub.Position=UDim2.new(0,48,0,25)
TSub.BackgroundTransparency=1 TSub.Text="Jujutsu Shenanigans"
TSub.Font=Enum.Font.Gotham TSub.TextColor3=C.TextGray TSub.TextSize=11
TSub.TextXAlignment=Enum.TextXAlignment.Left

local BtnClose=Instance.new("TextButton",TBar)
BtnClose.Size=UDim2.new(0,24,0,24) BtnClose.Position=UDim2.new(1,-34,0.5,-12)
BtnClose.BackgroundColor3=Color3.fromRGB(200,55,55) BtnClose.BorderSizePixel=0
BtnClose.Text="✕" BtnClose.Font=Enum.Font.GothamBold
BtnClose.TextColor3=Color3.fromRGB(255,255,255) BtnClose.TextSize=13 BtnClose.AutoButtonColor=false
Instance.new("UICorner",BtnClose).CornerRadius=UDim.new(0,5)

local BtnMin=Instance.new("TextButton",TBar)
BtnMin.Size=UDim2.new(0,24,0,24) BtnMin.Position=UDim2.new(1,-64,0.5,-12)
BtnMin.BackgroundColor3=C.BgSection BtnMin.BorderSizePixel=0
BtnMin.Text="—" BtnMin.Font=Enum.Font.GothamBold
BtnMin.TextColor3=C.TextGray BtnMin.TextSize=11 BtnMin.AutoButtonColor=false
Instance.new("UICorner",BtnMin).CornerRadius=UDim.new(0,5)

-- Drag
local dragging,dragStart,startPos
TBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true dragStart=i.Position startPos=Main.Position end end)
TBar.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

local minimized=false
BtnMin.MouseButton1Click:Connect(function()
    minimized=not minimized
    Main.Size=minimized and UDim2.new(0,800,0,46) or UDim2.new(0,800,0,540)
end)
BtnClose.MouseButton1Click:Connect(function()
    StopFarm()
    for p,_ in pairs(ESPObjs) do KillESP(p) end
    SG:Destroy()
end)

-- ─── CONTENT AREA ─────────────────────────────────────────
local Content=Instance.new("Frame",Main)
Content.Size=UDim2.new(1,0,1,-46) Content.Position=UDim2.new(0,0,0,46)
Content.BackgroundTransparency=1 Content.BorderSizePixel=0

-- ─── LEFT NAV ──────────────────────────────────────────────
local NavFrame=Instance.new("Frame",Content)
NavFrame.Size=UDim2.new(0,182,1,0) NavFrame.BackgroundColor3=C.NavBg NavFrame.BorderSizePixel=0

local NavScroll=Instance.new("ScrollingFrame",NavFrame)
NavScroll.Size=UDim2.new(1,0,1,0) NavScroll.BackgroundTransparency=1
NavScroll.BorderSizePixel=0 NavScroll.ScrollBarThickness=3
NavScroll.ScrollBarImageColor3=C.Purple
NavScroll.CanvasSize=UDim2.new(0,0,0,0) NavScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y

local NavLayout=Instance.new("UIListLayout",NavScroll)
NavLayout.SortOrder=Enum.SortOrder.LayoutOrder NavLayout.Padding=UDim.new(0,3)
local NavPad=Instance.new("UIPadding",NavScroll)
NavPad.PaddingLeft=UDim.new(0,8) NavPad.PaddingRight=UDim.new(0,8)
NavPad.PaddingTop=UDim.new(0,10) NavPad.PaddingBottom=UDim.new(0,10)

-- ─── RIGHT PANEL ───────────────────────────────────────────
local RightFrame=Instance.new("Frame",Content)
RightFrame.Size=UDim2.new(1,-182,1,0) RightFrame.Position=UDim2.new(0,182,0,0)
RightFrame.BackgroundColor3=C.BgDark RightFrame.BorderSizePixel=0 RightFrame.ClipsDescendants=true

-- ════════════════════════════════════════════════════════════
--   UI COMPONENT FACTORIES
-- ════════════════════════════════════════════════════════════

-- Nav category header
local function NavHeader(txt,order)
    local f=Instance.new("Frame",NavScroll)
    f.Size=UDim2.new(1,0,0,26) f.BackgroundTransparency=1 f.LayoutOrder=order
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1
    l.Text=txt l.Font=Enum.Font.GothamBold l.TextColor3=C.TextGray l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
    local p=Instance.new("UIPadding",l)
    p.PaddingLeft=UDim.new(0,4) p.PaddingTop=UDim.new(0,8)
    return f
end

-- Nav button – returns button, icon label, text label
local navBtns={}
local function NavBtn(icon,txt,order)
    local btn=Instance.new("TextButton",NavScroll)
    btn.Size=UDim2.new(1,0,0,36) btn.BackgroundColor3=C.NavBg
    btn.BorderSizePixel=0 btn.Text="" btn.LayoutOrder=order btn.AutoButtonColor=false
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,7)

    local ico=Instance.new("TextLabel",btn)
    ico.Size=UDim2.new(0,22,0,22) ico.Position=UDim2.new(0,6,0.5,-11)
    ico.BackgroundColor3=C.BgSection ico.BorderSizePixel=0
    ico.Text=icon ico.Font=Enum.Font.GothamBold ico.TextColor3=C.TextGray ico.TextSize=11
    Instance.new("UICorner",ico).CornerRadius=UDim.new(0,5)

    local lbl=Instance.new("TextLabel",btn)
    lbl.Size=UDim2.new(1,-34,1,0) lbl.Position=UDim2.new(0,33,0,0)
    lbl.BackgroundTransparency=1 lbl.Text=txt
    lbl.Font=Enum.Font.Gotham lbl.TextColor3=C.TextGray lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Left

    table.insert(navBtns,{btn=btn,ico=ico,lbl=lbl})
    return btn,ico,lbl
end

-- Tab panel (scrollable)
local tabs={}
local function TabPanel(name)
    local sf=Instance.new("ScrollingFrame",RightFrame)
    sf.Name=name sf.Size=UDim2.new(1,0,1,0)
    sf.BackgroundTransparency=1 sf.BorderSizePixel=0
    sf.ScrollBarThickness=4 sf.ScrollBarImageColor3=C.Purple
    sf.CanvasSize=UDim2.new(0,0,0,0) sf.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sf.Visible=false
    local layout=Instance.new("UIListLayout",sf)
    layout.SortOrder=Enum.SortOrder.LayoutOrder layout.Padding=UDim.new(0,8)
    local pad=Instance.new("UIPadding",sf)
    pad.PaddingLeft=UDim.new(0,10) pad.PaddingRight=UDim.new(0,10)
    pad.PaddingTop=UDim.new(0,10) pad.PaddingBottom=UDim.new(0,20)
    tabs[name]=sf
    return sf
end

-- Switch tab
local activeTab=nil
local function SwitchTab(name,btn,ico,lbl)
    for _,p in pairs(tabs) do p.Visible=false end
    for _,nb in ipairs(navBtns) do
        nb.btn.BackgroundColor3=C.NavBg
        nb.lbl.TextColor3=C.TextGray nb.lbl.Font=Enum.Font.Gotham
        nb.ico.BackgroundColor3=C.BgSection nb.ico.TextColor3=C.TextGray
    end
    if tabs[name] then tabs[name].Visible=true end
    activeTab=name
    btn.BackgroundColor3=C.NavActive
    lbl.TextColor3=C.TextWhite lbl.Font=Enum.Font.GothamBold
    ico.BackgroundColor3=C.Purple ico.TextColor3=Color3.fromRGB(255,255,255)
end

-- Two-column row frame
local function Row(parent,order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,0) f.AutomaticSize=Enum.AutomaticSize.Y
    f.BackgroundTransparency=1 f.LayoutOrder=order
    local l=Instance.new("UIListLayout",f)
    l.FillDirection=Enum.FillDirection.Horizontal
    l.HorizontalAlignment=Enum.HorizontalAlignment.Left
    l.Padding=UDim.new(0,8) l.SortOrder=Enum.SortOrder.LayoutOrder
    return f
end

-- Section card – returns card, body frame
local function Section(parent,title,order,w)
    w=w or 288
    local card=Instance.new("Frame",parent)
    card.Size=UDim2.new(0,w,0,0) card.AutomaticSize=Enum.AutomaticSize.Y
    card.BackgroundColor3=C.BgSection card.BorderSizePixel=0 card.LayoutOrder=order
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,8)

    -- header
    local hdr=Instance.new("Frame",card)
    hdr.Size=UDim2.new(1,0,0,38) hdr.BackgroundColor3=C.BgPanel hdr.BorderSizePixel=0
    Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,8)
    local hpatch=Instance.new("Frame",hdr)
    hpatch.Size=UDim2.new(1,0,0.5,0) hpatch.Position=UDim2.new(0,0,0.5,0)
    hpatch.BackgroundColor3=C.BgPanel hpatch.BorderSizePixel=0

    local ico=Instance.new("Frame",hdr)
    ico.Size=UDim2.new(0,22,0,22) ico.Position=UDim2.new(0,10,0.5,-11)
    ico.BackgroundColor3=C.BgSection ico.BorderSizePixel=0
    Instance.new("UICorner",ico).CornerRadius=UDim.new(1,0)
    local icoL=Instance.new("TextLabel",ico)
    icoL.Size=UDim2.new(1,0,1,0) icoL.BackgroundTransparency=1
    icoL.Text="⚙" icoL.Font=Enum.Font.GothamBold icoL.TextColor3=C.Purple icoL.TextSize=11

    local titL=Instance.new("TextLabel",hdr)
    titL.Size=UDim2.new(1,-90,1,0) titL.Position=UDim2.new(0,38,0,0)
    titL.BackgroundTransparency=1 titL.Text=title
    titL.Font=Enum.Font.GothamBold titL.TextColor3=C.TextWhite titL.TextSize=13
    titL.TextXAlignment=Enum.TextXAlignment.Left

    -- master toggle (decorative, each section wires its own)
    local tBg=Instance.new("TextButton",hdr)
    tBg.Size=UDim2.new(0,36,0,20) tBg.Position=UDim2.new(1,-46,0.5,-10)
    tBg.BackgroundColor3=C.ToggleOff tBg.BorderSizePixel=0 tBg.Text="" tBg.AutoButtonColor=false
    Instance.new("UICorner",tBg).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame",tBg)
    knob.Size=UDim2.new(0,14,0,14) knob.Position=UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3=Color3.fromRGB(200,200,200) knob.BorderSizePixel=0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    -- body
    local body=Instance.new("Frame",card)
    body.Size=UDim2.new(1,0,0,0) body.AutomaticSize=Enum.AutomaticSize.Y
    body.BackgroundTransparency=1
    local bl=Instance.new("UIListLayout",body)
    bl.SortOrder=Enum.SortOrder.LayoutOrder bl.Padding=UDim.new(0,0)
    local bp=Instance.new("UIPadding",body)
    bp.PaddingLeft=UDim.new(0,10) bp.PaddingRight=UDim.new(0,10)
    bp.PaddingTop=UDim.new(0,6) bp.PaddingBottom=UDim.new(0,10)

    return card,body,tBg,knob
end

-- Toggle (returns bg button, getter func, setter func)
local function Toggle(parent,txt,def,order)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,32) row.BackgroundTransparency=1 row.LayoutOrder=order
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-46,1,0) lbl.BackgroundTransparency=1
    lbl.Text=txt lbl.Font=Enum.Font.Gotham lbl.TextColor3=C.TextWhite lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local bg=Instance.new("TextButton",row)
    bg.Size=UDim2.new(0,36,0,20) bg.Position=UDim2.new(1,-36,0.5,-10)
    bg.BackgroundColor3=def and C.ToggleOn or C.ToggleOff
    bg.BorderSizePixel=0 bg.Text="" bg.AutoButtonColor=false
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
    local kn=Instance.new("Frame",bg)
    kn.Size=UDim2.new(0,14,0,14) kn.BorderSizePixel=0
    kn.BackgroundColor3=Color3.fromRGB(255,255,255)
    kn.Position=def and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)
    local state=def or false
    local function Set(v)
        state=v bg.BackgroundColor3=v and C.ToggleOn or C.ToggleOff
        TweenService:Create(kn,TweenInfo.new(0.12),{
            Position=v and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
    end
    bg.MouseButton1Click:Connect(function() Set(not state) end)
    return bg,function() return state end,Set
end

-- Checkbox
local function Checkbox(parent,txt,def,order)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,28) row.BackgroundTransparency=1 row.LayoutOrder=order
    local box=Instance.new("TextButton",row)
    box.Size=UDim2.new(0,16,0,16) box.Position=UDim2.new(0,0,0.5,-8)
    box.BackgroundColor3=def and C.Purple or C.CheckBg
    box.BorderSizePixel=0 box.Text=def and "✓" or ""
    box.Font=Enum.Font.GothamBold box.TextColor3=Color3.fromRGB(255,255,255)
    box.TextSize=10 box.AutoButtonColor=false
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,3)
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-22,1,0) lbl.Position=UDim2.new(0,22,0,0)
    lbl.BackgroundTransparency=1 lbl.Text=txt
    lbl.Font=Enum.Font.Gotham lbl.TextColor3=C.TextWhite lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local state=def or false
    local function Set(v)
        state=v box.BackgroundColor3=v and C.Purple or C.CheckBg box.Text=v and "✓" or "" end
    box.MouseButton1Click:Connect(function() Set(not state) end)
    lbl.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then Set(not state) end end)
    return box,function() return state end,Set
end

-- Slider
local function Slider(parent,txt,min,max,def,suf,order)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,48) row.BackgroundTransparency=1 row.LayoutOrder=order
    local top=Instance.new("Frame",row)
    top.Size=UDim2.new(1,0,0,18) top.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",top)
    lbl.Size=UDim2.new(0.6,0,1,0) lbl.BackgroundTransparency=1
    lbl.Text=txt lbl.Font=Enum.Font.Gotham lbl.TextColor3=C.TextWhite lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local val=Instance.new("TextLabel",top)
    val.Size=UDim2.new(0.4,0,1,0) val.Position=UDim2.new(0.6,0,0,0)
    val.BackgroundTransparency=1 val.Text=tostring(def)..(suf or "")
    val.Font=Enum.Font.Gotham val.TextColor3=C.Purple val.TextSize=12
    val.TextXAlignment=Enum.TextXAlignment.Right
    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(1,-20,0,5) track.Position=UDim2.new(0,10,0,30)
    track.BackgroundColor3=C.SliderBg track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.new((def-min)/(max-min),0,1,0)
    fill.BackgroundColor3=C.SliderFill fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
    local thumb=Instance.new("Frame",track)
    thumb.Size=UDim2.new(0,13,0,13) thumb.ZIndex=2
    thumb.Position=UDim2.new((def-min)/(max-min),-6,0.5,-7)
    thumb.BackgroundColor3=Color3.fromRGB(255,255,255) thumb.BorderSizePixel=0
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(1,0)
    local value=def local draggingSlider=false
    local function Update(inp)
        local rel=math.clamp((inp.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        value=math.floor(min+rel*(max-min))
        fill.Size=UDim2.new(rel,0,1,0)
        thumb.Position=UDim2.new(rel,-6,0.5,-7)
        val.Text=tostring(value)..(suf or "")
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then draggingSlider=true Update(i) end end)
    track.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then draggingSlider=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingSlider and i.UserInputType==Enum.UserInputType.MouseMovement then Update(i) end end)
    return row,function() return value end
end

-- Dropdown
local function Dropdown(parent,txt,opts,def,order)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,32) row.BackgroundTransparency=1
    row.LayoutOrder=order row.ClipsDescendants=false
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(0.44,0,1,0) lbl.BackgroundTransparency=1
    lbl.Text=txt lbl.Font=Enum.Font.Gotham lbl.TextColor3=C.TextWhite lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local dbtn=Instance.new("TextButton",row)
    dbtn.Size=UDim2.new(0.56,0,0,26) dbtn.Position=UDim2.new(0.44,0,0,3)
    dbtn.BackgroundColor3=C.DropBg dbtn.BorderSizePixel=0
    dbtn.Text=def or opts[1] dbtn.Font=Enum.Font.Gotham
    dbtn.TextColor3=C.TextWhite dbtn.TextSize=11 dbtn.AutoButtonColor=false
    dbtn.ClipsDescendants=false
    Instance.new("UICorner",dbtn).CornerRadius=UDim.new(0,5)
    local arrow=Instance.new("TextLabel",dbtn)
    arrow.Size=UDim2.new(0,14,1,0) arrow.Position=UDim2.new(1,-16,0,0)
    arrow.BackgroundTransparency=1 arrow.Text="▾"
    arrow.Font=Enum.Font.Gotham arrow.TextColor3=C.Purple arrow.TextSize=10
    local list=Instance.new("Frame",dbtn)
    list.Size=UDim2.new(1,0,0,0) list.Position=UDim2.new(0,0,1,2)
    list.BackgroundColor3=C.DropBg list.BorderSizePixel=0 list.ZIndex=20
    list.Visible=false list.ClipsDescendants=true
    Instance.new("UICorner",list).CornerRadius=UDim.new(0,5)
    local lStroke=Instance.new("UIStroke",list)
    lStroke.Color=C.Separator lStroke.Thickness=1
    local listLayout=Instance.new("UIListLayout",list)
    listLayout.SortOrder=Enum.SortOrder.LayoutOrder
    local sel=def or opts[1]
    local isOpen=false
    for i,opt in ipairs(opts) do
        local ob=Instance.new("TextButton",list)
        ob.Size=UDim2.new(1,0,0,24) ob.BackgroundColor3=C.DropBg ob.BorderSizePixel=0
        ob.Text="  "..opt ob.Font=Enum.Font.Gotham ob.LayoutOrder=i
        ob.TextColor3=opt==sel and C.Purple or C.TextWhite ob.TextSize=11
        ob.TextXAlignment=Enum.TextXAlignment.Left ob.ZIndex=21 ob.AutoButtonColor=false
        ob.MouseButton1Click:Connect(function()
            sel=opt dbtn.Text=opt
            for _,c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3=c.Text:match("^%s*(.-)%s*$")==opt and C.Purple or C.TextWhite end end
            isOpen=false list.Visible=false list.Size=UDim2.new(1,0,0,0)
        end)
    end
    dbtn.MouseButton1Click:Connect(function()
        isOpen=not isOpen list.Visible=isOpen
        list.Size=isOpen and UDim2.new(1,0,0,#opts*24) or UDim2.new(1,0,0,0)
    end)
    return row,function() return sel end
end

-- Button
local function Btn(parent,txt,order)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(1,0,0,30) b.BackgroundColor3=C.ButtonBg b.BorderSizePixel=0
    b.Text=txt b.Font=Enum.Font.GothamBold b.TextColor3=C.TextWhite b.TextSize=12
    b.LayoutOrder=order b.AutoButtonColor=false
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.ButtonHov}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.ButtonBg}):Play() end)
    return b
end

-- Sub-header
local function SubHdr(parent,txt,order)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(1,0,0,20) l.BackgroundTransparency=1
    l.Text=txt l.Font=Enum.Font.GothamBold l.TextColor3=C.TextGray l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Center l.LayoutOrder=order
    return l
end

-- Separator
local function Sep(parent,order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,1) f.BackgroundColor3=C.Separator f.BorderSizePixel=0 f.LayoutOrder=order
end

-- ════════════════════════════════════════════════════════════
--   BUILD NAV
-- ════════════════════════════════════════════════════════════
NavHeader("Combat & Auto Farm",1)
local bFarm,   iFarm,   lFarm   = NavBtn("⚔","Auto Farm",     2)
local bCombat, iCombat, lCombat = NavBtn("⊕","Combat System", 3)
NavHeader("ESP Engine",4)
local bVisl,   iVisl,   lVisl   = NavBtn("◎","Visuals",       5)
NavHeader("Miscellaneous",6)
local bMisc,   iMisc,   lMisc   = NavBtn("⚙","Misc",          7)
NavHeader("Credits & Settings",8)
local bCreds,  iCreds,  lCreds  = NavBtn("◎","Credits",       9)

bFarm.MouseButton1Click:Connect(function()   SwitchTab("Farm",   bFarm,  iFarm,  lFarm)  end)
bCombat.MouseButton1Click:Connect(function() SwitchTab("Combat", bCombat,iCombat,lCombat) end)
bVisl.MouseButton1Click:Connect(function()   SwitchTab("Visl",   bVisl,  iVisl,  lVisl)  end)
bMisc.MouseButton1Click:Connect(function()   SwitchTab("Misc",   bMisc,  iMisc,  lMisc)  end)
bCreds.MouseButton1Click:Connect(function()  SwitchTab("Credits",bCreds, iCreds, lCreds) end)

-- ════════════════════════════════════════════════════════════
--   TAB: AUTO FARM
-- ════════════════════════════════════════════════════════════
local PFarm=TabPanel("Farm")

-- Row A: Farming | Aimlock
local rowA=Row(PFarm,1)

local _,bFarmSec = Section(rowA,"Farming",1,284)
local _,getTP    = Dropdown(bFarmSec,"Select Players",{"All","Specific"},                     "All",    1)
local _,getTM    = Dropdown(bFarmSec,"Target Method",{"Closest","Furthest","Random","Most HP","Least HP"},"Closest",2)
local _,getFace, _ = Checkbox(bFarmSec,"Face At Target",true, 3)
local _,getFast, _ = Checkbox(bFarmSec,"Fast Attack",   true, 4)
local _,getSkU,  _ = Checkbox(bFarmSec,"Use Skills",    true, 5)
SubHdr(bFarmSec,"Control",6)
local farmBtn=Btn(bFarmSec,"Enable Farm",7)
local farmOn=false
farmBtn.MouseButton1Click:Connect(function()
    farmOn=not farmOn
    Cfg.Farm.Enabled=farmOn
    farmBtn.BackgroundColor3=farmOn and C.Purple or C.ButtonBg
    farmBtn.Text=farmOn and "⬛  Disable Farm" or "▶  Enable Farm"
    if farmOn then StartFarm() else StopFarm() end
end)

local _,bAimSec = Section(rowA,"Aimlock",2,284)
local _,getAimOn,setAimOn = Checkbox(bAimSec,"Enable Aimlock",false,1)
local _,getAimMode  = Dropdown(bAimSec,"Aimlock Mode",{"Camera","Silent","Body"},   "Camera",2)
local _,getAimPart  = Dropdown(bAimSec,"Target Part", {"Head","HumanoidRootPart","Torso"},"Head",3)
local _,getAimPred,_ = Checkbox(bAimSec,"Prediction",false,4)

-- Status section (full width)
local _,bStat = Section(PFarm,"Status",2,576)
local statSys=Instance.new("TextLabel",bStat)
statSys.Size=UDim2.new(1,0,0,16) statSys.BackgroundTransparency=1
statSys.Text="System Status" statSys.Font=Enum.Font.GothamBold
statSys.TextColor3=C.TextWhite statSys.TextSize=12 statSys.TextXAlignment=Enum.TextXAlignment.Left
statSys.LayoutOrder=1
local statVal=Instance.new("TextLabel",bStat)
statVal.Size=UDim2.new(1,0,0,20) statVal.BackgroundTransparency=1
statVal.Text="[ DISABLED ]" statVal.Font=Enum.Font.GothamBold
statVal.TextColor3=C.TextRed statVal.TextSize=14 statVal.TextXAlignment=Enum.TextXAlignment.Left
statVal.LayoutOrder=2
local statSub=Instance.new("TextLabel",bStat)
statSub.Size=UDim2.new(1,0,0,14) statSub.BackgroundTransparency=1
statSub.Text="Wait for activation..." statSub.Font=Enum.Font.Gotham
statSub.TextColor3=C.TextGray statSub.TextSize=11 statSub.TextXAlignment=Enum.TextXAlignment.Left
statSub.LayoutOrder=3

-- Blocking section (full width)
local _,bBlock = Section(PFarm,"Blocking",3,576)
local _,getABlk, _ = Checkbox(bBlock,"Enable Auto Block",      true, 1)
local _,getAPun, _ = Checkbox(bBlock,"Auto Punish (Attack Back)",true, 2)
local _,getFAtt, _ = Checkbox(bBlock,"Face Attacker",           true, 3)
local showRangeOn=false
local showRangeBtn=Btn(bBlock,"Show Range",4)
showRangeBtn.MouseButton1Click:Connect(function()
    showRangeOn=not showRangeOn
    Cfg.Block.ShowRange=showRangeOn
    showRangeBtn.BackgroundColor3=showRangeOn and C.Purple or C.ButtonBg
    ToggleRangeSphere(showRangeOn)
end)
local _,getDetR = Slider(bBlock,"Detection Range",5,60,20," studs",5)
local _,getBlkD = Slider(bBlock,"Block Delay",    0,5, 0, "s",     6)

-- Wire Farm tab (single connection, no widget creation inside)
RunService.Heartbeat:Connect(function()
    Cfg.Farm.TargetPlayer  = getTP()
    Cfg.Farm.TargetMethod  = getTM()
    Cfg.Farm.FaceTarget    = getFace()
    Cfg.Farm.FastAttack    = getFast()
    Cfg.Farm.UseSkills     = getSkU()
    Cfg.Aim.Enabled        = getAimOn()
    Cfg.Aim.Mode           = getAimMode()
    Cfg.Aim.TargetPart     = getAimPart()
    Cfg.Aim.Prediction     = getAimPred()
    Cfg.Block.AutoBlock    = getABlk()
    Cfg.Block.AutoPunish   = getAPun()
    Cfg.Block.FaceAttacker = getFAtt()
    Cfg.Block.DetectRange  = getDetR()
    Cfg.Block.BlockDelay   = getBlkD()
    -- Status update
    if Cfg.Farm.Enabled then
        local tgt=GetTarget()
        statVal.Text="[ ACTIVE ]" statVal.TextColor3=C.TextGreen
        statSub.Text="Target: "..(tgt and tgt.Name or "searching...")
    else
        statVal.Text="[ DISABLED ]" statVal.TextColor3=C.TextRed
        statSub.Text="Wait for activation..."
    end
end)

-- ════════════════════════════════════════════════════════════
--   TAB: COMBAT SYSTEM
-- ════════════════════════════════════════════════════════════
local PCombat=TabPanel("Combat")
local _,bCS = Section(PCombat,"Settings",1,576)

local _,getCTpM  = Dropdown(bCS,"Teleport Method",{"Tween","Instant","Lerp"},       "Tween",        1)
local _,getCMove = Dropdown(bCS,"Movement Mode",  {"Orbit (Dodge)","Follow","Static"},"Orbit (Dodge)",2)
local _,getCSpd  = Slider(bCS,"Tween Speed",   50, 400,135," studs/s",3)
local _,getCFD   = Slider(bCS,"Follow Distance", 2,  30,  4," studs", 4)
local _,getCKit, _ = Checkbox(bCS,"Smart Kiting (Retreat on CD)",true, 5)
SubHdr(bCS,"Main Configurations",6)
local _,getCFlee,setCFlee = Checkbox(bCS,"Auto Flee (Low HP)",false,7)
local _,getCFHP  = Slider(bCS,"Flee Health %",5,80,20,"%",8)
local _,getCPrio,_ = Checkbox(bCS,"Priority Closest",true, 9)
local _,getCHunt,_ = Checkbox(bCS,"Hunter Mode",     false,10)
SubHdr(bCS,"Skill System",11)
local _,getCSk   = Dropdown(bCS,"Select Skills",{"Divergent Fist","Black Flash","Hollow Purple","Domain Expansion","All"},"Divergent Fist",12)
local _,getCSD   = Slider(bCS,"Use Skill Delay",0,30,6,"s",13)
local _,getCANT, _ = Checkbox(bCS,"Avoid Skills With Target Required",true,14)
Sep(bCS,15)
local _,getCSKA,setCSKA = Checkbox(bCS,"Semi Kill Aura (25 Studs)",false,16)
local _,getCSpin,setCspin = Checkbox(bCS,"SpinBot",false,17)

local prevCSKA,prevCSpin=false,false
RunService.Heartbeat:Connect(function()
    Cfg.Combat.TpMethod      = getCTpM()
    local mm=getCMove()
    Cfg.Combat.MoveMode      = mm:gsub(" %(Dodge%)","")
    Cfg.Combat.TweenSpeed    = getCSpd()
    Cfg.Combat.FollowDist    = getCFD()
    Cfg.Combat.SmartKiting   = getCKit()
    Cfg.Combat.AutoFlee      = getCFlee()
    Cfg.Combat.FleeHP        = getCFHP()
    Cfg.Combat.PriorClosest  = getCPrio()
    Cfg.Combat.HunterMode    = getCHunt()
    Cfg.Combat.SkillName     = getCSk()
    Cfg.Combat.SkillDelay    = getCSD()
    Cfg.Combat.AvoidNoTarget = getCANT()
    local ska=getCSKA()
    if ska~=prevCSKA then prevCSKA=ska SetKillAura(ska) end
    local sp=getCSpin()
    if sp~=prevCSpin then prevCSpin=sp SetSpinBot(sp) end
end)

-- ════════════════════════════════════════════════════════════
--   TAB: VISUALS
-- ════════════════════════════════════════════════════════════
local PVisl=TabPanel("Visl")
local rowV=Row(PVisl,1)

local _,bVEn  = Section(rowV,"Enable",         1,284)
local _,getESP,setESP = Checkbox(bVEn,"Enable Esp Players",false,1)

local _,bVCfg = Section(rowV,"Configurations", 2,284)
local _,getVBox,  _ = Checkbox(bVCfg,"Box",            true,1)
local _,getVTr,   _ = Checkbox(bVCfg,"Tracers",        true,2)
local _,getVHP,   _ = Checkbox(bVCfg,"Health Bar",     true,3)
local _,getVDist, _ = Checkbox(bVCfg,"Distance",       true,4)
local _,getVName, _ = Checkbox(bVCfg,"Name",           true,5)
local _,getVMove, _ = Checkbox(bVCfg,"Moveset (Class)",true,6)

local prevESP=false
RunService.Heartbeat:Connect(function()
    local e=getESP()
    Cfg.ESP.Box     =getVBox()  Cfg.ESP.Tracers  =getVTr()
    Cfg.ESP.HealthBar=getVHP() Cfg.ESP.Distance  =getVDist()
    Cfg.ESP.Name    =getVName() Cfg.ESP.Moveset  =getVMove()
    Cfg.ESP.Enabled =e
    if e and not prevESP then
        for _,p in ipairs(Players:GetPlayers()) do MakeESP(p) end
    elseif not e and prevESP then
        for _,o in pairs(ESPObjs) do HideESP(o) end
    end
    prevESP=e
end)

-- ════════════════════════════════════════════════════════════
--   TAB: MISC
-- ════════════════════════════════════════════════════════════
local PMisc=TabPanel("Misc")
local rowM=Row(PMisc,1)

local _,bStuff = Section(rowM,"Stuff",1,284)
local _,getAR,  _ = Checkbox(bStuff,"Anti Ragdoll",                 false,1)
local _,getAT,  _ = Checkbox(bStuff,"Auto Tech (Jump on Ragdoll)",  false,2)
local _,getWS,  _ = Checkbox(bStuff,"WalkSpeed Bypass (Velocity)",  false,3)
local _,getSpd    = Slider(bStuff,  "Speed Amount",16,500,100," studs/s",4)
local _,getIJ,  _ = Checkbox(bStuff,"Infinite Jump",                false,5)
local _,getFB,  _ = Checkbox(bStuff,"Fullbright",                   false,6)
local _,getWSc, _ = Checkbox(bStuff,"White Screen",                 false,7)
local _,getAFK, _ = Checkbox(bStuff,"Anti AFK",                     true, 8)
local _,getCTP, _ = Checkbox(bStuff,"Click TP (Ctrl+Click)",        false,9)
local _,getTC     = Slider(bStuff,  "Time Changer",0,24,14,"h",    10)
Sep(bStuff,11)
local fpsBtn2=Btn(bStuff,"FPS Boost",12)
local hopBtn =Btn(bStuff,"Server Hop",13)
fpsBtn2.MouseButton1Click:Connect(FPSBoost)
hopBtn.MouseButton1Click:Connect(ServerHop)

local _,bPC=Section(rowM,"Player Control",2,284)
local function PlayerNames()
    local t={"(none)"}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then t[#t+1]=p.Name end end
    return t
end
local _,getSP=Dropdown(bPC,"Select Player",PlayerNames(),"(none)",1)
local specBtn=Btn(bPC,"Spectate Player",   2)
local stopSBtn=Btn(bPC,"Stop Spectate",    3)
local tpBtn  =Btn(bPC,"Teleport to Player",4)
specBtn.MouseButton1Click:Connect(function()
    local p=Players:FindFirstChild(getSP()) if p then SpectatePlayer(p) end end)
stopSBtn.MouseButton1Click:Connect(StopSpec)
tpBtn.MouseButton1Click:Connect(function()
    local p=Players:FindFirstChild(getSP())
    if p then
        local r=Root(LocalPlayer) local tr=Root(p)
        if r and tr then r.CFrame=tr.CFrame*CFrame.new(0,0,-3) end
    end
end)

-- Wire Misc (no widgets created here, only reads + calls)
local prev={WS=false,IJ=false,FB=false,WSc=false,AFK=nil,CTP=false}
RunService.Heartbeat:Connect(function()
    Cfg.Misc.AntiRagdoll = getAR()
    Cfg.Misc.AutoTech    = getAT()
    Cfg.Misc.Speed       = getSpd()
    Cfg.Misc.TimeHour    = getTC()
    local ws=getWS() if ws~=prev.WS then prev.WS=ws Cfg.Misc.WsBypass=ws SetSpeedBypass(ws) end
    local ij=getIJ() if ij~=prev.IJ then prev.IJ=ij Cfg.Misc.InfJump=ij SetInfJump(ij) end
    local fb=getFB() if fb~=prev.FB then prev.FB=fb Cfg.Misc.Fullbright=fb SetFullbright(fb) end
    local wsc=getWSc() if wsc~=prev.WSc then prev.WSc=wsc Cfg.Misc.WhiteScreen=wsc SetWhiteScreen(wsc) end
    local afk=getAFK()
    if prev.AFK==nil then prev.AFK=afk SetAntiAFK(afk)
    elseif afk~=prev.AFK then prev.AFK=afk Cfg.Misc.AntiAFK=afk SetAntiAFK(afk) end
    local ctp=getCTP() if ctp~=prev.CTP then prev.CTP=ctp Cfg.Misc.ClickTP=ctp SetClickTP(ctp) end
end)

-- ════════════════════════════════════════════════════════════
--   TAB: CREDITS
-- ════════════════════════════════════════════════════════════
local PCreds=TabPanel("Credits")
local _,bCred=Section(PCreds,"Credits",1,576)
local function CLine(t,col,sz,o)
    local l=Instance.new("TextLabel",bCred)
    l.Size=UDim2.new(1,0,0,sz+8) l.BackgroundTransparency=1
    l.Text=t l.Font=Enum.Font.GothamBold l.TextColor3=col l.TextSize=sz
    l.TextXAlignment=Enum.TextXAlignment.Center l.LayoutOrder=o end
CLine("Imp Hub X",           C.Purple,    22, 1)
CLine("Jujutsu Shenanigans", C.TextWhite, 14, 2)
CLine("Version 2.0 - Fixed",C.TextGray,  11, 3)
Sep(bCred,4)
CLine("Auto Farm  •  Combat  •  ESP  •  Misc  •  Aimlock",C.TextGray,10,5)
Sep(bCred,6)
CLine("For educational purposes only.",C.TextGray,10,7)

-- ════════════════════════════════════════════════════════════
--   INITIAL STATE
-- ════════════════════════════════════════════════════════════
SwitchTab("Farm", bFarm, iFarm, lFarm)
SetAntiAFK(true)

-- RightShift toggles GUI
UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        Main.Visible=not Main.Visible end end)

print("[ImpHubX v2] Loaded! Press RightShift to toggle GUI.")
