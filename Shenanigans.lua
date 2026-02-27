--[[
  IMP HUB X  v7  —  Jujutsu Shenanigans
  Rebuilt from SafeScriptDump analysis. Key findings:
    ▸ Characters live in  workspace.Characters  (not workspace)
    ▸ M1 Attack  → Knit.GetService(Moveset.."Service").Activated:Fire(isAir)
    ▸ Skill      → Knit.GetService(skill.Service).Activated:Fire(skillObj, false)
    ▸ Block ON   → Knit.GetService("BlockService").Activated:Fire(enemyChar)
    ▸ Block OFF  → Knit.GetService("BlockService").Deactivated:Fire()
    ▸ Dead check → character:GetAttribute("Dead")
    ▸ Ragdoll    → character:GetAttribute("Ragdoll") > 0
    ▸ Context    → {isAir, target, mouseTarget, moveVector} per skill
]]

-- ── Services ─────────────────────────────────────────────────
local Players   = game:GetService("Players")
local RS        = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local TweenSvc  = game:GetService("TweenService")
local Lighting  = game:GetService("Lighting")
local HttpSvc   = game:GetService("HttpService")
local TeleSvc   = game:GetService("TeleportService")
local StarterG  = game:GetService("StarterGui")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- ── Knit Access ──────────────────────────────────────────────
-- KnitRunClient already called Knit.Start(), so GetService() works from exploit.
local Knit = nil
pcall(function() Knit = require(game.ReplicatedStorage.Knit.Knit) end)

local _svcCache = {}
local function KS(name)
    if _svcCache[name] then return _svcCache[name] end
    if not Knit then return nil end
    local ok, s = pcall(function() return Knit.GetService(name) end)
    if ok and s then _svcCache[name] = s end
    return ok and s or nil
end

-- ── workspace.Characters (confirmed from dump line 14147) ─────
-- Characters folder is a direct child of workspace.
local ChrFolder = workspace:FindFirstChild("Characters") or workspace
RS.Heartbeat:Connect(function()
    local f = workspace:FindFirstChild("Characters")
    if f and f ~= ChrFolder then ChrFolder = f end
end)

-- ── Character Helpers ─────────────────────────────────────────
local function GetChar(p)
    if p == LP then return LP.Character end
    -- Characters are in workspace.Characters keyed by player Name
    return ChrFolder:FindFirstChild(p.Name) or p.Character
end
local function Root(p)  local c=GetChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p)   local c=GetChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p)
    local c=GetChar(p); if not c then return false end
    if c:GetAttribute("Dead") then return false end    -- dump confirmed
    local h=c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function Dist(p)
    local a,b = Root(LP), Root(p)
    return (a and b) and (a.Position-b.Position).Magnitude or math.huge
end

-- ── Config ────────────────────────────────────────────────────
local Cfg = {
    Farm   = {Enabled=false, Method="Closest", FaceTarget=true, FastAttack=true, UseSkills=true},
    Block  = {Enabled=false, AutoBlock=true, AutoPunish=true, FaceAtt=true, Range=20, Delay=0},
    Aim    = {Enabled=false, Mode="Camera", Part="Head", Predict=false},
    Combat = {TpMethod="Tween", MoveMode="Orbit", TweenSpd=135, FollowDist=4,
              AutoFlee=false, FleeHP=20, SkillDelay=8, AvoidNoTgt=true,
              SemiKA=false, SpinBot=false},
    ESP    = {Enabled=false, Box=true, Tracer=true, HPBar=true, Dist=true, Name=true, Move=true},
    Misc   = {AntRag=false, AutoTech=false, WSBypass=false, Speed=100,
              InfJump=false, Fullbright=false, WhiteScr=false, AntiAFK=true,
              ClickTP=false, TimeHour=14},
}

-- ── Enemies & Targeting ───────────────────────────────────────
local function GetEnemies()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and Alive(p) then t[#t+1]=p end
    end
    return t
end
local function GetTarget()
    local e=GetEnemies(); if #e==0 then return nil end
    local m=Cfg.Farm.Method
    if m=="Closest"  then table.sort(e,function(a,b)return Dist(a)<Dist(b)end)
    elseif m=="Furthest" then table.sort(e,function(a,b)return Dist(a)>Dist(b)end)
    elseif m=="Random"   then return e[math.random(1,#e)]
    elseif m=="Most HP"  then table.sort(e,function(a,b)
        local ha,hb=Hum(a),Hum(b)
        return (ha and ha.Health or 0)>(hb and hb.Health or 0) end)
    elseif m=="Least HP" then table.sort(e,function(a,b)
        local ha,hb=Hum(a),Hum(b)
        return (ha and ha.Health or 1e9)<(hb and hb.Health or 1e9) end)
    end
    return e[1]
end
local function FaceTarget(tgt)
    local r,tr=Root(LP),Root(tgt)
    if r and tr then
        r.CFrame=CFrame.new(r.Position,Vector3.new(tr.Position.X,r.Position.Y,tr.Position.Z))
    end
end

local _orbit=0
local function OrbitTarget(tgt)
    local r,tr=Root(LP),Root(tgt)
    if not r or not tr then return end
    _orbit=_orbit+0.06
    local d=Cfg.Combat.FollowDist+1.5
    local ox=tr.Position.X+math.cos(_orbit)*d
    local oz=tr.Position.Z+math.sin(_orbit)*d
    r.CFrame=CFrame.new(ox,tr.Position.Y,oz)
            *CFrame.Angles(0,math.atan2(tr.Position.X-ox,tr.Position.Z-oz),0)
end

local function TweenTo(tgt)
    local r,tr=Root(LP),Root(tgt)
    if not r or not tr then return end
    local dir=(r.Position-tr.Position).Unit
    local cf=CFrame.new(tr.Position+dir*Cfg.Combat.FollowDist)
             *CFrame.Angles(0,math.atan2(dir.X,dir.Z),0)
    local m=Cfg.Combat.TpMethod
    if m=="Instant" then r.CFrame=cf
    elseif m=="Lerp" then r.CFrame=r.CFrame:Lerp(cf,0.25)
    else
        local mag=(r.Position-cf.Position).Magnitude
        TweenSvc:Create(r,TweenInfo.new(
            math.clamp(mag/Cfg.Combat.TweenSpd,0.04,1.5),
            Enum.EasingStyle.Linear),{CFrame=cf}):Play()
    end
end

-- ── ATTACK  (M1 via Knit service signal) ─────────────────────
-- From dump: UseSetService("Activated", isAir)
--   → Knit.GetService(Moveset.."Service").Activated:Fire(isAir)
-- This Knit client signal auto-routes to server. No manual remote needed.
local _lastAtk=0
local function DoAttack()
    if tick()-_lastAtk<0.12 then return end
    _lastAtk=tick()
    local char=LP.Character; if not char then return end
    pcall(function()
        local moveset=char:GetAttribute("Moveset")
        if moveset and moveset~="" then
            local svc=KS(moveset.."Service")
            if svc and svc.Activated then
                local hum=char:FindFirstChildOfClass("Humanoid")
                local isAir=hum and hum.FloorMaterial==Enum.Material.Air
                svc.Activated:Fire(isAir and "Down" or false)
                return
            end
        end
        -- Fallback: VIM mouse click (game's InputBegan has gameProcessed=false for VIM)
        pcall(function()
            local vim=game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0,0,0,true,game,1)
            task.delay(0.04,function()
                pcall(function() vim:SendMouseButtonEvent(0,0,0,false,game,1) end)
            end)
        end)
    end)
end

-- ── BLOCK  (Knit BlockService signals) ───────────────────────
-- From dump: Block() calls BlockService.Activated:Fire(target_char_model)
--            InputEnded/F release calls BlockService.Deactivated:Fire()
local _blocking=false
local function SetBlock(on, enemyChar)
    if _blocking==on then return end
    _blocking=on
    pcall(function()
        local bs=KS("BlockService")
        if not bs then return end
        if on then
            -- Pass enemy CHARACTER MODEL (not player object) as target
            bs.Activated:Fire(enemyChar)
        else
            bs.Deactivated:Fire()
        end
    end)
end

-- ── SKILLS  (Character.Moveset children with Key + Service attrs) ──
-- From dump UseTool: svc.Activated:Fire(skillInstance, contextData)
-- Context type from v_u_23 table: 1=isAir, 2=target, 3=mouseTarget, 4=moveVec, 5=all
-- We pass false as context (safe default — server handles nil gracefully)
local _lastSkill=0
local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    if tick()-_lastSkill < math.max(0,Cfg.Combat.SkillDelay) then return end
    if Cfg.Combat.AvoidNoTgt and not tgt then return end
    local char=LP.Character; if not char then return end
    local mFolder=char:FindFirstChild("Moveset"); if not mFolder then return end

    -- Collect skills not on cooldown
    local info=char:FindFirstChild("Info")
    local onCD=info and info:GetAttribute("CD")
    if onCD then return end

    local skills={}
    for _,skill in ipairs(mFolder:GetChildren()) do
        local svcName=skill:GetAttribute("Service")
        local key=skill:GetAttribute("Key")
        if svcName and key then skills[#skills+1]=skill end
    end
    if #skills==0 then return end

    _lastSkill=tick()
    local chosen=skills[math.random(1,#skills)]
    pcall(function()
        local svcName=chosen:GetAttribute("Service")
        local svc=KS(svcName)
        if svc and svc.Activated then
            -- Skills fire: Activated:Fire(skillInstance, contextData)
            -- contextData: we pass the target char for type-2 skills (most common)
            local tgtChar=tgt and GetChar(tgt)
            svc.Activated:Fire(chosen, tgtChar)
        end
    end)
end

-- ── MISC FEATURES ─────────────────────────────────────────────
local _speedBV=nil
local function SetSpeedBypass(on)
    local r=Root(LP); if not r then return end
    if on then
        if not _speedBV then
            _speedBV=Instance.new("BodyVelocity",r)
            _speedBV.MaxForce=Vector3.new(1e4,0,1e4)
            _speedBV.Velocity=Vector3.zero
        end
    else
        if _speedBV then _speedBV:Destroy(); _speedBV=nil end
    end
end

local _jumpConn=nil
local function SetInfJump(on)
    if _jumpConn then _jumpConn:Disconnect(); _jumpConn=nil end
    if on then
        _jumpConn=UIS.JumpRequest:Connect(function()
            local h=Hum(LP); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local _origAmb,_origBrt=nil,nil
local function SetFullbright(on)
    if on then
        _origAmb=Lighting.Ambient; _origBrt=Lighting.Brightness
        Lighting.Ambient=Color3.new(1,1,1); Lighting.Brightness=2; Lighting.FogEnd=1e6
    elseif _origAmb then
        Lighting.Ambient=_origAmb; Lighting.Brightness=_origBrt
    end
end

local _wsGui=nil
local function SetWhiteScreen(on)
    if _wsGui then _wsGui:Destroy(); _wsGui=nil end
    if on then
        _wsGui=Instance.new("ScreenGui",LP.PlayerGui)
        _wsGui.Name="ImpHubXWS"; _wsGui.ResetOnSpawn=false
        local f=Instance.new("Frame",_wsGui)
        f.Size=UDim2.new(1,0,1,0); f.BackgroundColor3=Color3.new(1,1,1)
        f.BackgroundTransparency=0.4; f.BorderSizePixel=0
    end
end

local _ctpConn=nil
local function SetClickTP(on)
    if _ctpConn then _ctpConn:Disconnect(); _ctpConn=nil end
    if on then
        _ctpConn=UIS.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                local r=Root(LP)
                if r then r.CFrame=CFrame.new(Mouse.Hit.Position+Vector3.new(0,3,0)) end
            end
        end)
    end
end

local _spinConn=nil
local function SetSpinBot(on)
    if _spinConn then _spinConn:Disconnect(); _spinConn=nil end
    if on then
        _spinConn=RS.RenderStepped:Connect(function()
            local r=Root(LP); if r then r.CFrame=r.CFrame*CFrame.Angles(0,math.rad(18),0) end
        end)
    end
end

local _kaConn=nil
local function SetKillAura(on)
    if _kaConn then _kaConn:Disconnect(); _kaConn=nil end
    if on then
        local _t=0
        _kaConn=RS.Heartbeat:Connect(function()
            if tick()-_t<0.12 then return end; _t=tick()
            for _,e in ipairs(GetEnemies()) do
                if Dist(e)<=25 then DoAttack(); break end
            end
        end)
    end
end

local _specConn=nil
local function SpectatePlayer(tgt)
    if _specConn then _specConn:Disconnect(); _specConn=nil end
    if not tgt then return end
    Camera.CameraType=Enum.CameraType.Scriptable
    _specConn=RS.RenderStepped:Connect(function()
        local tr=Root(tgt)
        if tr then Camera.CFrame=CFrame.new(tr.Position+Vector3.new(0,6,14),tr.Position) end
    end)
end
local function StopSpec()
    if _specConn then _specConn:Disconnect(); _specConn=nil end
    Camera.CameraType=Enum.CameraType.Custom
end

-- ════════════════════════════════════════════════════════════
-- GUI  (400×260 exact template)
-- ════════════════════════════════════════════════════════════
pcall(function() StarterG.ScreenOrientation=Enum.ScreenOrientation.LandscapeRight end)
pcall(function() LP.PlayerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeRight end)

local GuiParent=(type(gethui)=="function" and gethui())
    or pcall(function()return game:GetService("CoreGui")end) and game:GetService("CoreGui")
    or LP:WaitForChild("PlayerGui")

local old=GuiParent:FindFirstChild("ImpHubX_v7"); if old then old:Destroy() end

local ScreenGui=Instance.new("ScreenGui",GuiParent)
ScreenGui.Name="ImpHubX_v7"; ScreenGui.ResetOnSpawn=false; ScreenGui.IgnoreGuiInset=true

local T={
    BG=Color3.fromRGB(20,20,25),  Side=Color3.fromRGB(15,15,20),
    Acc=Color3.fromRGB(110,45,220), AccL=Color3.fromRGB(150,80,255),
    Txt=Color3.fromRGB(240,240,240), Sub=Color3.fromRGB(140,140,140),
    Btn=Color3.fromRGB(32,32,40), Stk=Color3.fromRGB(55,55,65),
    Grn=Color3.fromRGB(45,205,80), Red=Color3.fromRGB(230,55,55),
}

-- Toggle pill icon
local ToggleBtn=Instance.new("TextButton",ScreenGui)
ToggleBtn.Size=UDim2.new(0,45,0,45)
ToggleBtn.Position=UDim2.new(0.5,-22,0.05,0)
ToggleBtn.BackgroundColor3=T.BG
ToggleBtn.BackgroundTransparency=0.05
ToggleBtn.Text="⚔"; ToggleBtn.TextSize=22; ToggleBtn.Font=Enum.Font.GothamBold
ToggleBtn.TextColor3=T.Txt; ToggleBtn.Visible=false; ToggleBtn.AutoButtonColor=false
Instance.new("UICorner",ToggleBtn).CornerRadius=UDim.new(1,0)
local _tbs=Instance.new("UIStroke",ToggleBtn); _tbs.Color=T.Acc; _tbs.Thickness=2

-- Main frame (exact template: 400×260)
local MF=Instance.new("Frame",ScreenGui)
MF.Size=UDim2.new(0,400,0,260)
MF.Position=UDim2.new(0.5,-200,0.5,-130)
MF.BackgroundColor3=T.BG; MF.BackgroundTransparency=0.05
Instance.new("UICorner",MF).CornerRadius=UDim.new(0,8)
local _mfs=Instance.new("UIStroke",MF); _mfs.Color=T.Acc; _mfs.Transparency=0.5

-- Top bar (template: 30px, transparent)
local TB=Instance.new("Frame",MF)
TB.Size=UDim2.new(1,0,0,30); TB.BackgroundTransparency=1

local Title=Instance.new("TextLabel",TB)
Title.Size=UDim2.new(0.72,0,1,0); Title.Position=UDim2.new(0,12,0,0)
Title.Text="⚔  Imp Hub X  —  Jujutsu Shenanigans"
Title.Font=Enum.Font.GothamMedium; Title.TextSize=11
Title.TextColor3=T.Txt; Title.TextXAlignment=Enum.TextXAlignment.Left
Title.BackgroundTransparency=1

local function TopBtn(txt,xoff,col,fn)
    local b=Instance.new("TextButton",TB)
    b.Size=UDim2.new(0,28,0,20); b.Position=UDim2.new(1,xoff,0.5,-10)
    b.BackgroundTransparency=1; b.Text=txt; b.Font=Enum.Font.GothamMedium
    b.TextSize=15; b.TextColor3=col; b.AutoButtonColor=false
    b.MouseButton1Click:Connect(fn)
end
TopBtn("✕",-32,Color3.fromRGB(255,75,75),function() ScreenGui:Destroy() end)
TopBtn("—",-64,T.Sub,function() MF.Visible=false; ToggleBtn.Visible=true end)

ToggleBtn.MouseButton1Click:Connect(function() MF.Visible=true; ToggleBtn.Visible=false end)
UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
        MF.Visible=not MF.Visible; ToggleBtn.Visible=not MF.Visible
    end
end)

-- Drag (exact template pattern)
local function MkDrag(obj,handle)
    local drag,start,startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; start=i.Position; startPos=obj.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement
                  or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-start
            obj.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                    startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end
MkDrag(MF,TB); MkDrag(ToggleBtn,ToggleBtn)

-- Sidebar (template: 110px)
local Side=Instance.new("Frame",MF)
Side.Size=UDim2.new(0,110,1,-30); Side.Position=UDim2.new(0,0,0,30)
Side.BackgroundColor3=T.Side; Side.BackgroundTransparency=0.5; Side.BorderSizePixel=0
Instance.new("UICorner",Side).CornerRadius=UDim.new(0,8)
local SideLayout=Instance.new("UIListLayout",Side)
SideLayout.Padding=UDim.new(0,5); SideLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
Instance.new("UIPadding",Side).PaddingTop=UDim.new(0,10)

-- Content area (template)
local CA=Instance.new("Frame",MF)
CA.Size=UDim2.new(1,-120,1,-30); CA.Position=UDim2.new(0,115,0,30)
CA.BackgroundTransparency=1

-- Dropdown overlay
local DropOv=Instance.new("Frame",ScreenGui)
DropOv.Size=UDim2.new(1,0,1,0); DropOv.BackgroundTransparency=1
DropOv.BorderSizePixel=0; DropOv.ZIndex=100; DropOv.Active=false
local _openDrop=nil
local function CloseDrop()
    if _openDrop then _openDrop.Visible=false; _openDrop=nil end
    DropOv.Active=false
end
DropOv.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1
    or i.UserInputType==Enum.UserInputType.Touch then CloseDrop() end
end)

-- ── Tab system ────────────────────────────────────────────────
local TabList={}; local TabBtns={}
local function MkTab(label,icon)
    local frame=Instance.new("ScrollingFrame",CA)
    frame.Size=UDim2.new(1,0,1,-10)
    frame.BackgroundTransparency=1; frame.ScrollBarThickness=2
    frame.ScrollBarImageColor3=T.AccL; frame.Visible=false
    frame.AutomaticCanvasSize=Enum.AutomaticSize.Y
    frame.CanvasSize=UDim2.new(0,0,0,0); frame.BorderSizePixel=0

    local lay=Instance.new("UIListLayout",frame)
    lay.Padding=UDim.new(0,8); lay.SortOrder=Enum.SortOrder.LayoutOrder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+20)
    end)
    local pad=Instance.new("UIPadding",frame)
    pad.PaddingTop=UDim.new(0,5); pad.PaddingLeft=UDim.new(0,2); pad.PaddingRight=UDim.new(0,4)

    local btn=Instance.new("TextButton",Side)
    btn.Size=UDim2.new(0.9,0,0,30); btn.BackgroundColor3=T.Acc
    btn.BackgroundTransparency=1; btn.AutoButtonColor=false
    btn.Text="  "..icon.."  "..label
    btn.TextColor3=T.Sub; btn.Font=Enum.Font.GothamMedium; btn.TextSize=12
    btn.TextXAlignment=Enum.TextXAlignment.Left
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)

    local ind=Instance.new("Frame",btn)
    ind.Size=UDim2.new(0,3,0.6,0); ind.Position=UDim2.new(0,2,0.2,0)
    ind.BackgroundColor3=T.Acc; ind.Visible=false; ind.BorderSizePixel=0
    Instance.new("UICorner",ind).CornerRadius=UDim.new(1,0)

    btn.MouseButton1Click:Connect(function()
        CloseDrop()
        for _,t in ipairs(TabList) do t.Frame.Visible=false end
        for _,b in ipairs(TabBtns) do
            b.Btn.BackgroundTransparency=1; b.Btn.TextColor3=T.Sub; b.Ind.Visible=false
        end
        frame.Visible=true; btn.BackgroundTransparency=0.85
        btn.TextColor3=T.Txt; ind.Visible=true
    end)
    table.insert(TabList,{Frame=frame})
    table.insert(TabBtns,{Btn=btn,Ind=ind})
    return frame
end

-- ── Component builders ─────────────────────────────────────────
local function Sec(p,txt,lo)
    local f=Instance.new("Frame",p)
    f.Size=UDim2.new(0.98,0,0,18); f.BackgroundTransparency=1; f.LayoutOrder=lo
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,-4,1,0); l.Position=UDim2.new(0,4,0,0)
    l.BackgroundTransparency=1; l.Text=string.upper(txt)
    l.Font=Enum.Font.GothamBold; l.TextSize=9
    l.TextColor3=T.AccL; l.TextXAlignment=Enum.TextXAlignment.Left
end

-- Toggle (45px — exact template)
local function MkTog(p,title,desc,def,lo,cb)
    local st=def==true
    local card=Instance.new("TextButton",p)
    card.Size=UDim2.new(0.98,0,0,45); card.BackgroundColor3=T.Btn
    card.Text=""; card.AutoButtonColor=false; card.LayoutOrder=lo
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",card).Color=T.Stk

    local ttl=Instance.new("TextLabel",card)
    ttl.Size=UDim2.new(0.72,0,0.5,0); ttl.Position=UDim2.new(0,10,0,4)
    ttl.Text=title; ttl.Font=Enum.Font.GothamMedium; ttl.TextSize=12
    ttl.TextColor3=T.Txt; ttl.TextXAlignment=Enum.TextXAlignment.Left
    ttl.BackgroundTransparency=1

    local sub=Instance.new("TextLabel",card)
    sub.Size=UDim2.new(0.72,0,0.45,0); sub.Position=UDim2.new(0,10,0.52,0)
    sub.Text=desc or ""; sub.Font=Enum.Font.Gotham; sub.TextSize=10
    sub.TextColor3=T.Sub; sub.TextXAlignment=Enum.TextXAlignment.Left
    sub.BackgroundTransparency=1

    local pill=Instance.new("Frame",card)
    pill.Size=UDim2.new(0,40,0,20); pill.Position=UDim2.new(1,-50,0.5,-10)
    pill.BackgroundColor3=st and T.Acc or T.Btn
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)
    local ps=Instance.new("UIStroke",pill); ps.Color=st and T.Acc or T.Stk

    local pt=Instance.new("TextLabel",pill)
    pt.Size=UDim2.new(1,0,1,0); pt.BackgroundTransparency=1
    pt.Text=st and "ON" or "OFF"; pt.Font=Enum.Font.GothamBold; pt.TextSize=10
    pt.TextColor3=st and T.BG or T.Sub

    local function Upd()
        pt.Text=st and "ON" or "OFF"; pt.TextColor3=st and T.BG or T.Sub
        pill.BackgroundColor3=st and T.Acc or T.Btn; ps.Color=st and T.Acc or T.Stk
        card.BackgroundColor3=st and Color3.fromRGB(36,28,55) or T.Btn
    end
    card.MouseButton1Click:Connect(function() st=not st; Upd(); pcall(cb,st) end)
    return function() return st end
end

-- Button (35px)
local function MkBtn(p,txt,lo,cb)
    local b=Instance.new("TextButton",p)
    b.Size=UDim2.new(0.98,0,0,35); b.BackgroundColor3=T.Btn
    b.Text="  "..txt; b.TextColor3=T.Txt; b.Font=Enum.Font.GothamMedium
    b.TextSize=12; b.TextXAlignment=Enum.TextXAlignment.Left
    b.AutoButtonColor=false; b.LayoutOrder=lo
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",b).Color=T.Stk
    b.MouseEnter:Connect(function() b.BackgroundColor3=Color3.fromRGB(42,36,62) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3=T.Btn end)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

-- Slider (44px)
local _sliderActive=nil
UIS.InputChanged:Connect(function(i)
    if not _sliderActive then return end
    if i.UserInputType~=Enum.UserInputType.MouseMovement
    and i.UserInputType~=Enum.UserInputType.Touch then return end
    local s=_sliderActive
    local rel=math.clamp((i.Position.X-s.T.AbsolutePosition.X)/s.T.AbsoluteSize.X,0,1)
    s.V=s.Mn+math.round(rel*(s.Mx-s.Mn))
    s.F.Size=UDim2.new(rel,0,1,0); s.K.Position=UDim2.new(rel,-5,0.5,-5)
    s.L.Text=tostring(s.V)..s.Sfx; pcall(s.Cb,s.V)
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1
    or i.UserInputType==Enum.UserInputType.Touch then _sliderActive=nil end
end)

local function MkSlider(p,title,mn,mx,def,sfx,lo,cb)
    sfx=sfx or ""
    local card=Instance.new("Frame",p)
    card.Size=UDim2.new(0.98,0,0,44); card.BackgroundColor3=T.Btn
    card.BorderSizePixel=0; card.LayoutOrder=lo
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",card).Color=T.Stk

    local tl=Instance.new("TextLabel",card)
    tl.Size=UDim2.new(0.62,0,0,18); tl.Position=UDim2.new(0,10,0,5)
    tl.Text=title; tl.Font=Enum.Font.GothamMedium; tl.TextSize=12
    tl.TextColor3=T.Txt; tl.TextXAlignment=Enum.TextXAlignment.Left
    tl.BackgroundTransparency=1

    local vl=Instance.new("TextLabel",card)
    vl.Size=UDim2.new(0.38,-10,0,18); vl.Position=UDim2.new(0.62,0,0,5)
    vl.Text=tostring(def)..sfx; vl.Font=Enum.Font.GothamBold; vl.TextSize=12
    vl.TextColor3=T.AccL; vl.TextXAlignment=Enum.TextXAlignment.Right
    vl.BackgroundTransparency=1

    local tr=Instance.new("Frame",card)
    tr.Size=UDim2.new(1,-18,0,4); tr.Position=UDim2.new(0,9,0,30)
    tr.BackgroundColor3=Color3.fromRGB(42,42,52); tr.BorderSizePixel=0
    Instance.new("UICorner",tr).CornerRadius=UDim.new(1,0)

    local pct=(def-mn)/(mx-mn)
    local fill=Instance.new("Frame",tr)
    fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=T.Acc
    fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob=Instance.new("Frame",tr)
    knob.Size=UDim2.new(0,10,0,10); knob.Position=UDim2.new(pct,-5,0.5,-5)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=3
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local sd={T=tr,F=fill,K=knob,L=vl,Mn=mn,Mx=mx,V=def,Sfx=sfx,Cb=cb}
    local function slide(inp)
        local rel=math.clamp((inp.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        sd.V=mn+math.round(rel*(mx-mn)); fill.Size=UDim2.new(rel,0,1,0)
        knob.Position=UDim2.new(rel,-5,0.5,-5); vl.Text=tostring(sd.V)..sfx; pcall(cb,sd.V)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then _sliderActive=sd; slide(i) end
    end)
    return function() return sd.V end
end

-- Dropdown (38px)
local function MkDrop(p,title,opts,def,lo,cb)
    local sel=def or opts[1]
    local card=Instance.new("Frame",p)
    card.Size=UDim2.new(0.98,0,0,38); card.BackgroundColor3=T.Btn
    card.BorderSizePixel=0; card.LayoutOrder=lo
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",card).Color=T.Stk

    local lbl=Instance.new("TextLabel",card)
    lbl.Size=UDim2.new(0.44,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.Text=title; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12
    lbl.TextColor3=T.Txt; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.BackgroundTransparency=1

    local dbtn=Instance.new("TextButton",card)
    dbtn.Size=UDim2.new(0.54,-6,0,26); dbtn.Position=UDim2.new(0.46,0,0.5,-13)
    dbtn.BackgroundColor3=Color3.fromRGB(26,26,32); dbtn.BorderSizePixel=0
    dbtn.Text=sel; dbtn.Font=Enum.Font.Gotham; dbtn.TextSize=11
    dbtn.TextColor3=T.Txt; dbtn.AutoButtonColor=false
    Instance.new("UICorner",dbtn).CornerRadius=UDim.new(0,5)
    Instance.new("UIStroke",dbtn).Color=T.Stk
    local arr=Instance.new("TextLabel",dbtn)
    arr.Size=UDim2.new(0,14,1,0); arr.Position=UDim2.new(1,-16,0,0)
    arr.BackgroundTransparency=1; arr.Text="▾"
    arr.TextColor3=T.AccL; arr.TextSize=11; arr.Font=Enum.Font.GothamBold

    local list=Instance.new("Frame",DropOv)
    list.BackgroundColor3=Color3.fromRGB(26,26,32); list.BorderSizePixel=0
    list.ZIndex=110; list.Visible=false
    Instance.new("UICorner",list).CornerRadius=UDim.new(0,6)
    local _ls=Instance.new("UIStroke",list); _ls.Color=T.Acc; _ls.Transparency=0.4
    Instance.new("UIListLayout",list).SortOrder=Enum.SortOrder.LayoutOrder

    for i,opt in ipairs(opts) do
        local ob=Instance.new("TextButton",list)
        ob.Size=UDim2.new(1,0,0,24); ob.BackgroundColor3=Color3.fromRGB(26,26,32)
        ob.BorderSizePixel=0; ob.LayoutOrder=i; ob.ZIndex=111
        ob.Text="  "..opt; ob.Font=Enum.Font.Gotham; ob.TextSize=11
        ob.TextColor3=opt==sel and T.AccL or T.Txt
        ob.TextXAlignment=Enum.TextXAlignment.Left; ob.AutoButtonColor=false
        ob.MouseEnter:Connect(function() ob.BackgroundColor3=Color3.fromRGB(36,36,48) end)
        ob.MouseLeave:Connect(function() ob.BackgroundColor3=Color3.fromRGB(26,26,32) end)
        ob.MouseButton1Click:Connect(function()
            sel=opt; dbtn.Text=opt; CloseDrop()
            for _,c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3=c.Text:gsub("^%s+","")==opt and T.AccL or T.Txt
                end
            end
            pcall(cb,sel)
        end)
    end
    dbtn.MouseButton1Click:Connect(function()
        if _openDrop==list then CloseDrop(); return end
        CloseDrop()
        local ap,as=dbtn.AbsolutePosition,dbtn.AbsoluteSize
        list.Position=UDim2.new(0,ap.X,0,ap.Y+as.Y+2)
        list.Size=UDim2.new(0,as.X,0,#opts*24)
        list.Visible=true; _openDrop=list; DropOv.Active=true
    end)
    return function() return sel end
end

-- ════════════════════════════════════════════════════════════
-- BUILD TABS
-- ════════════════════════════════════════════════════════════
local TFarm=MkTab("Auto Farm","⚔")
local TCmbt=MkTab("Combat","⚙")
local TESP =MkTab("ESP","●")
local TMisc=MkTab("Misc","★")
local TInfo=MkTab("Info","i")

-- ── AUTO FARM ────────────────────────────────────────────────
Sec(TFarm,"Farming",1)
MkDrop(TFarm,"Target",{"Closest","Furthest","Random","Most HP","Least HP"},"Closest",2,
    function(v) Cfg.Farm.Method=v end)
MkTog(TFarm,"Face At Target",    "Rotate toward enemy",          true,  3,function(v)Cfg.Farm.FaceTarget=v end)
MkTog(TFarm,"Fast Attack (M1)",  "Auto-spam M1 via Knit signal",  true,  4,function(v)Cfg.Farm.FastAttack=v end)
MkTog(TFarm,"Use Skills",        "Fire Moveset skills by Knit",   true,  5,function(v)Cfg.Farm.UseSkills=v end)

local farmBtn=MkBtn(TFarm,"▶  Enable Auto Farm",6,function()end)
local _farmOn=false
farmBtn.MouseButton1Click:Connect(function()
    _farmOn=not _farmOn; Cfg.Farm.Enabled=_farmOn
    farmBtn.Text=_farmOn and "  ■  Disable Farm" or "  ▶  Enable Auto Farm"
    farmBtn.BackgroundColor3=_farmOn and Color3.fromRGB(36,26,56) or T.Btn
end)

Sec(TFarm,"Status",7)
local _scard=Instance.new("Frame",TFarm)
_scard.Size=UDim2.new(0.98,0,0,44); _scard.BackgroundColor3=T.Btn
_scard.BorderSizePixel=0; _scard.LayoutOrder=8
Instance.new("UICorner",_scard).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",_scard).Color=T.Stk
local _sBig=Instance.new("TextLabel",_scard)
_sBig.Size=UDim2.new(1,-12,0,22); _sBig.Position=UDim2.new(0,12,0,5)
_sBig.BackgroundTransparency=1; _sBig.Text="[ DISABLED ]"
_sBig.Font=Enum.Font.GothamBold; _sBig.TextSize=13
_sBig.TextColor3=T.Red; _sBig.TextXAlignment=Enum.TextXAlignment.Left
local _sSub=Instance.new("TextLabel",_scard)
_sSub.Size=UDim2.new(1,-12,0,14); _sSub.Position=UDim2.new(0,12,0,27)
_sSub.BackgroundTransparency=1; _sSub.Text="Idle..."
_sSub.Font=Enum.Font.Gotham; _sSub.TextSize=10
_sSub.TextColor3=T.Sub; _sSub.TextXAlignment=Enum.TextXAlignment.Left

Sec(TFarm,"Auto Block",9)
MkTog(TFarm,"Enable Auto Block",  "BlockService signal on detect", true, 10,function(v)Cfg.Block.Enabled=v end)
MkTog(TFarm,"Auto Punish",        "Attack back after blocking",    true, 11,function(v)Cfg.Block.AutoPunish=v end)
MkTog(TFarm,"Face Attacker",      "Turn toward nearby enemy",      true, 12,function(v)Cfg.Block.FaceAtt=v end)
MkSlider(TFarm,"Detect Range",5,80,20," studs",13,function(v)Cfg.Block.Range=v end)
MkSlider(TFarm,"Block Delay",  0, 5, 0,"s",    14,function(v)Cfg.Block.Delay=v end)

Sec(TFarm,"Aimlock",15)
MkTog(TFarm,"Enable Aimlock",  "Camera/Body/Silent aim assist",false,16,function(v)Cfg.Aim.Enabled=v end)
MkDrop(TFarm,"Mode",{"Camera","Body","Silent"},"Camera",17,function(v)Cfg.Aim.Mode=v end)
MkDrop(TFarm,"Target Part",{"Head","HumanoidRootPart","Torso"},"Head",18,
    function(v)Cfg.Aim.Part=v end)
MkTog(TFarm,"Prediction","Lead moving targets",false,19,function(v)Cfg.Aim.Predict=v end)

-- ── COMBAT ───────────────────────────────────────────────────
Sec(TCmbt,"Movement",1)
MkDrop(TCmbt,"Teleport Method",{"Tween","Instant","Lerp"},"Tween",2,
    function(v)Cfg.Combat.TpMethod=v end)
MkDrop(TCmbt,"Move Mode",{"Orbit","Follow","Static"},"Orbit",3,
    function(v)Cfg.Combat.MoveMode=v end)
MkSlider(TCmbt,"Tween Speed",50,400,135," st/s",4,function(v)Cfg.Combat.TweenSpd=v end)
MkSlider(TCmbt,"Follow Dist", 2, 30,  4," studs",5,function(v)Cfg.Combat.FollowDist=v end)

Sec(TCmbt,"Main Config",6)
MkTog(TCmbt,"Auto Flee (Low HP)","Retreat when HP low",false,7,function(v)Cfg.Combat.AutoFlee=v end)
MkSlider(TCmbt,"Flee HP %",5,80,20,"%",8,function(v)Cfg.Combat.FleeHP=v end)

Sec(TCmbt,"Skills",9)
MkSlider(TCmbt,"Skill Delay",0,30,8,"s",10,function(v)Cfg.Combat.SkillDelay=v end)
MkTog(TCmbt,"Skip if No Target","Avoid skills needing target",true,11,
    function(v)Cfg.Combat.AvoidNoTgt=v end)
MkTog(TCmbt,"Semi Kill Aura","Attack enemies ≤25 studs",false,12,
    function(v)Cfg.Combat.SemiKA=v; SetKillAura(v) end)
MkTog(TCmbt,"SpinBot","Spin continuously",false,13,
    function(v)Cfg.Combat.SpinBot=v; SetSpinBot(v) end)

-- ── ESP ──────────────────────────────────────────────────────
Sec(TESP,"Toggle",1)
MkTog(TESP,"Enable ESP","Draw overlays on all enemies",false,2,function(v)Cfg.ESP.Enabled=v end)
Sec(TESP,"Elements",3)
MkTog(TESP,"Box",         "Bounding box",       true,4,function(v)Cfg.ESP.Box=v end)
MkTog(TESP,"Tracers",     "Line to player",     true,5,function(v)Cfg.ESP.Tracer=v end)
MkTog(TESP,"Health Bar",  "HP gradient bar",    true,6,function(v)Cfg.ESP.HPBar=v end)
MkTog(TESP,"Distance",    "Studs from you",     true,7,function(v)Cfg.ESP.Dist=v end)
MkTog(TESP,"Name",        "Player username",    true,8,function(v)Cfg.ESP.Name=v end)
MkTog(TESP,"Moveset",     "Character:GetAttribute(\"Moveset\")",true,9,function(v)Cfg.ESP.Move=v end)

-- ── MISC ─────────────────────────────────────────────────────
Sec(TMisc,"Utility",1)
MkTog(TMisc,"Anti Ragdoll",       "Disable ragdoll constraints",false,2,
    function(v)Cfg.Misc.AntRag=v end)
MkTog(TMisc,"Auto Tech",          "Jump when Ragdoll attr > 0",false,3,
    function(v)Cfg.Misc.AutoTech=v end)
MkTog(TMisc,"WalkSpeed Bypass",   "BodyVelocity speed override",false,4,
    function(v)Cfg.Misc.WSBypass=v; SetSpeedBypass(v) end)
MkSlider(TMisc,"Speed",16,500,100," st/s",5,function(v)Cfg.Misc.Speed=v end)
MkTog(TMisc,"Infinite Jump",      "JumpRequest override",false,6,
    function(v)Cfg.Misc.InfJump=v; SetInfJump(v) end)
MkTog(TMisc,"Fullbright",         "Max Lighting.Ambient",false,7,
    function(v)Cfg.Misc.Fullbright=v; SetFullbright(v) end)
MkTog(TMisc,"White Screen",       "Semi-transparent overlay",false,8,
    function(v)Cfg.Misc.WhiteScr=v; SetWhiteScreen(v) end)
MkTog(TMisc,"Anti AFK",           "Prevent kick (Humanoid pulse)",true,9,
    function(v)Cfg.Misc.AntiAFK=v end)
MkTog(TMisc,"Click TP (Ctrl+LMB)","Teleport to clicked point",false,10,
    function(v)Cfg.Misc.ClickTP=v; SetClickTP(v) end)
MkSlider(TMisc,"Time Changer",0,24,14,"h",11,function(v)Cfg.Misc.TimeHour=v end)

MkBtn(TMisc,"⚡  FPS Boost",12,function()
    pcall(function() settings().Rendering.QualityLevel=1 end)
    Lighting.GlobalShadows=false
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke")
        or v:IsA("Sparkles") or v:IsA("Fire") then v.Enabled=false end
    end
end)
MkBtn(TMisc,"🌐  Server Hop",13,function()
    local ok,data=pcall(function()
        return HttpSvc:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId..
            "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and data and data.data then
        for _,sv in ipairs(data.data) do
            if sv.id~=game.JobId and sv.playing<sv.maxPlayers then
                TeleSvc:TeleportToPlaceInstance(game.PlaceId,sv.id,LP); return
            end
        end
    end
end)

Sec(TMisc,"Player Control",14)
local function GetPNames()
    local t={"(none)"}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    return t
end
local getSP=MkDrop(TMisc,"Select Player",GetPNames(),"(none)",15,function()end)
MkBtn(TMisc,"▶  Spectate",16,function()
    local p=Players:FindFirstChild(getSP()); if p then SpectatePlayer(p) end
end)
MkBtn(TMisc,"■  Stop Spectate",17,StopSpec)
MkBtn(TMisc,"↑  Teleport To",18,function()
    local p=Players:FindFirstChild(getSP()); if not p then return end
    local r,tr=Root(LP),Root(p)
    if r and tr then r.CFrame=tr.CFrame*CFrame.new(0,0,-3) end
end)

-- ── INFO ─────────────────────────────────────────────────────
local function InfoCard(p,txt,col,lo)
    local f=Instance.new("Frame",p)
    f.Size=UDim2.new(0.98,0,0,34); f.BackgroundColor3=T.Btn
    f.BorderSizePixel=0; f.LayoutOrder=lo
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",f).Color=T.Stk
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text=txt; l.Font=Enum.Font.GothamBold; l.TextSize=11
    l.TextColor3=col or T.Txt; l.TextXAlignment=Enum.TextXAlignment.Center
end
InfoCard(TInfo,"Imp Hub X",T.AccL,1)
InfoCard(TInfo,"Jujutsu Shenanigans",T.Txt,2)
InfoCard(TInfo,"v7  •  Knit-accurate mechanics",T.Sub,3)
InfoCard(TInfo,"M1 = Knit MovesetsService.Activated",T.Sub,4)
InfoCard(TInfo,"Block = BlockService.Activated/Deactivated",T.Sub,5)
InfoCard(TInfo,"Skills = Moveset folder Knit signals",T.Sub,6)
InfoCard(TInfo,"Toggle: RightShift",T.AccL,7)

-- Open first tab
if TabBtns[1] then TabBtns[1].Btn.MouseButton1Click:Fire() end

-- ════════════════════════════════════════════════════════════
-- HEARTBEAT LOOP
-- ════════════════════════════════════════════════════════════
local _bTimer=0; local _lastBlocker=nil
local _techT=0;  local _afkT=0

RS.Heartbeat:Connect(function()
    local now=tick()
    local myChar=LP.Character

    -- Time changer
    pcall(function() Lighting.ClockTime=Cfg.Misc.TimeHour end)

    -- Anti-AFK (humanoid health pulse prevents kick)
    if Cfg.Misc.AntiAFK and now-_afkT>55 then
        _afkT=now
        pcall(function()
            if myChar then
                local h=myChar:FindFirstChildOfClass("Humanoid")
                if h then h.Jump=true; task.delay(0.1,function() pcall(function()h.Jump=false end)end) end
            end
        end)
    end

    -- Auto Tech (dump: character:GetAttribute("Ragdoll") > 0 means ragdolled)
    if Cfg.Misc.AutoTech and myChar and now-_techT>0.28 then
        local rag=myChar:GetAttribute("Ragdoll") or 0
        if rag>0 then
            _techT=now
            local h=myChar:FindFirstChildOfClass("Humanoid")
            if h then h.Jump=true end
        end
    end

    -- Speed bypass (drive BodyVelocity in direction of movement)
    if Cfg.Misc.WSBypass and _speedBV and myChar then
        local h=myChar:FindFirstChildOfClass("Humanoid")
        if h then _speedBV.Velocity=h.MoveDirection*Cfg.Misc.Speed end
    end

    -- Anti Ragdoll (disable BallSocketConstraint + HingeConstraint — dump confirmed)
    if Cfg.Misc.AntRag and myChar then
        for _,v in ipairs(myChar:GetDescendants()) do
            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                v.Enabled=false
            end
        end
    end

    -- ── Auto Block ──────────────────────────────────────────
    -- Uses BlockService.Activated:Fire(enemyChar) and .Deactivated:Fire()
    if Cfg.Block.Enabled then
        local shouldBlock,attacker=false,nil
        for _,p in ipairs(GetEnemies()) do
            if Dist(p)<=Cfg.Block.Range then
                shouldBlock=true; attacker=p; break
            end
        end
        if shouldBlock then
            if Cfg.Block.FaceAtt and attacker then FaceTarget(attacker) end
            if now>=_bTimer then
                _bTimer=now+Cfg.Block.Delay
                SetBlock(true, attacker and GetChar(attacker))
                _lastBlocker=attacker
            end
        else
            if _blocking then
                SetBlock(false,nil)
                if Cfg.Block.AutoPunish and _lastBlocker then
                    DoAttack()
                end
                _lastBlocker=nil
            end
        end
    elseif _blocking then
        SetBlock(false,nil)
    end

    -- ── Aimlock ─────────────────────────────────────────────
    if Cfg.Aim.Enabled then
        local tgt=GetTarget()
        if tgt then
            local ch=GetChar(tgt)
            local part=ch and (ch:FindFirstChild(Cfg.Aim.Part)
                            or ch:FindFirstChild("HumanoidRootPart"))
            if part then
                local pos=part.Position
                if Cfg.Aim.Predict then
                    pcall(function() pos=pos+part.AssemblyLinearVelocity*0.1 end)
                end
                if Cfg.Aim.Mode=="Camera" or Cfg.Aim.Mode=="Silent" then
                    Camera.CFrame=CFrame.new(Camera.CFrame.Position,pos)
                elseif Cfg.Aim.Mode=="Body" then
                    local r=Root(LP)
                    if r then r.CFrame=CFrame.new(r.Position,
                        Vector3.new(pos.X,r.Position.Y,pos.Z)) end
                end
            end
        end
    end

    -- ── Auto Farm ───────────────────────────────────────────
    if Cfg.Farm.Enabled then
        local tgt=GetTarget()

        -- Auto Flee (teleport away from target)
        if Cfg.Combat.AutoFlee and tgt then
            local h=myChar and myChar:FindFirstChildOfClass("Humanoid")
            if h and (h.Health/h.MaxHealth*100)<=Cfg.Combat.FleeHP then
                local r,tr=Root(LP),Root(tgt)
                if r and tr then
                    local away=(r.Position-tr.Position).Unit
                    r.CFrame=CFrame.new(r.Position+away*35)
                end
            end
        end

        if tgt then
            -- Move toward target
            if Cfg.Combat.MoveMode=="Orbit" then
                OrbitTarget(tgt)
            elseif Cfg.Combat.MoveMode=="Follow" then
                TweenTo(tgt)
            end
            -- (Static = don't move)

            -- Face target
            if Cfg.Farm.FaceTarget then FaceTarget(tgt) end

            -- M1 Attack (Knit MovesetsService.Activated)
            if Cfg.Farm.FastAttack then DoAttack() end

            -- Skills (Moveset folder → Knit service signals)
            UseSkill(tgt)
        end

        -- Status display
        _sBig.Text="[ ACTIVE ]"; _sBig.TextColor3=T.Grn
        _sSub.Text="Target: "..(tgt and tgt.Name or "searching...")
    else
        if not _farmOn then
            _sBig.Text="[ DISABLED ]"; _sBig.TextColor3=T.Red; _sSub.Text="Idle..."
        end
    end
end)

-- ════════════════════════════════════════════════════════════
-- ESP  (Drawing API)
-- ════════════════════════════════════════════════════════════
local ESPStore={}

local function GetMoveset(p)
    local ch=GetChar(p)
    if ch then
        local m=ch:GetAttribute("Moveset")  -- dump confirmed attribute
        if m and m~="" then return m end
    end
    return "???"
end

local function MakeESP(p)
    if p==LP or ESPStore[p] then return end
    local ok,_=pcall(function() local _=Drawing.new("Line") end)
    if not ok then return end  -- Drawing not available

    local o={}
    o.Box={}
    for i=1,4 do
        local l=Drawing.new("Line"); l.Thickness=1.5
        l.Color=Color3.fromRGB(120,40,230); l.Visible=false; l.ZIndex=2
        o.Box[i]=l
    end
    o.Trc=Drawing.new("Line"); o.Trc.Thickness=1
    o.Trc.Color=Color3.fromRGB(120,40,230); o.Trc.Visible=false

    o.HBg=Drawing.new("Square"); o.HBg.Filled=true
    o.HBg.Color=Color3.fromRGB(16,16,16); o.HBg.Visible=false
    o.HBr=Drawing.new("Square"); o.HBr.Filled=true
    o.HBr.Color=T.Grn; o.HBr.Visible=false

    o.Nme=Drawing.new("Text"); o.Nme.Size=13
    o.Nme.Color=Color3.new(1,1,1); o.Nme.Center=true
    o.Nme.Outline=true; o.Nme.Visible=false

    o.Dst=Drawing.new("Text"); o.Dst.Size=11
    o.Dst.Color=Color3.fromRGB(200,200,200); o.Dst.Center=true
    o.Dst.Outline=true; o.Dst.Visible=false

    o.Mvs=Drawing.new("Text"); o.Mvs.Size=11
    o.Mvs.Color=Color3.fromRGB(165,120,255); o.Mvs.Center=true
    o.Mvs.Outline=true; o.Mvs.Visible=false

    ESPStore[p]=o
end

local function RemESP(p)
    local o=ESPStore[p]; if not o then return end
    for _,v in pairs(o) do
        if type(v)=="table" then for _,l in ipairs(v) do pcall(function()l:Remove()end) end
        else pcall(function()v:Remove()end) end
    end
    ESPStore[p]=nil
end

local function HideAll(o)
    for _,v in pairs(o) do
        if type(v)=="table" then for _,l in ipairs(v) do l.Visible=false end
        else v.Visible=false end
    end
end

RS.RenderStepped:Connect(function()
    if not Cfg.ESP.Enabled then
        for _,o in pairs(ESPStore) do HideAll(o) end; return
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then MakeESP(p) end
    end
    for p,o in pairs(ESPStore) do
        if not p.Parent or not Alive(p) then RemESP(p)
        else
            local r=Root(p); local h=Hum(p)
            if not r or not h then HideAll(o)
            else
                local sp,vis=Camera:WorldToViewportPoint(r.Position)
                if not vis then HideAll(o)
                else
                    local tp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,3.2,0))
                    local bp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,-3.2,0))
                    local ht=math.abs(tp.Y-bp.Y); local wd=ht*0.52
                    local L,R,Top,Bot=sp.X-wd/2,sp.X+wd/2,tp.Y,bp.Y

                    local corners={{Vector2.new(L,Top),Vector2.new(R,Top)},
                                   {Vector2.new(L,Bot),Vector2.new(R,Bot)},
                                   {Vector2.new(L,Top),Vector2.new(L,Bot)},
                                   {Vector2.new(R,Top),Vector2.new(R,Bot)}}
                    for i,seg in ipairs(o.Box) do
                        seg.From=corners[i][1]; seg.To=corners[i][2]
                        seg.Visible=Cfg.ESP.Box
                    end

                    local vp=Camera.ViewportSize
                    o.Trc.From=Vector2.new(vp.X/2,vp.Y)
                    o.Trc.To=Vector2.new(sp.X,sp.Y)
                    o.Trc.Visible=Cfg.ESP.Tracer

                    local pct=math.clamp(h.Health/h.MaxHealth,0,1)
                    o.HBg.Size=Vector2.new(4,ht); o.HBg.Position=Vector2.new(L-8,Top)
                    o.HBg.Visible=Cfg.ESP.HPBar
                    o.HBr.Size=Vector2.new(4,ht*pct)
                    o.HBr.Position=Vector2.new(L-8,Top+ht*(1-pct))
                    o.HBr.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0)
                    o.HBr.Visible=Cfg.ESP.HPBar

                    o.Nme.Text=p.Name; o.Nme.Position=Vector2.new(sp.X,Top-16)
                    o.Nme.Visible=Cfg.ESP.Name

                    o.Dst.Text=math.floor(Dist(p)).." st"
                    o.Dst.Position=Vector2.new(sp.X,Bot+3); o.Dst.Visible=Cfg.ESP.Dist

                    o.Mvs.Text="["..GetMoveset(p).."]"
                    o.Mvs.Position=Vector2.new(sp.X,Bot+15); o.Mvs.Visible=Cfg.ESP.Move
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════
-- CLEANUP
-- ════════════════════════════════════════════════════════════
Players.PlayerRemoving:Connect(RemESP)

LP.CharacterAdded:Connect(function()
    task.wait(2)  -- wait for Knit to re-init after respawn
    _svcCache={}  -- clear service cache (Knit reinits services on respawn)
    _speedBV=nil; _blocking=false
    if Cfg.Misc.WSBypass then SetSpeedBypass(true) end
    if Cfg.Misc.InfJump   then SetInfJump(true) end
    if Cfg.Misc.ClickTP   then SetClickTP(true) end
end)

ScreenGui.AncestryChanged:Connect(function()
    for p in pairs(ESPStore) do RemESP(p) end
    SetBlock(false,nil); StopSpec()
    if _spinConn  then _spinConn:Disconnect() end
    if _kaConn    then _kaConn:Disconnect()   end
    if _jumpConn  then _jumpConn:Disconnect() end
    if _ctpConn   then _ctpConn:Disconnect()  end
    if _speedBV   then pcall(function()_speedBV:Destroy()end) end
end)

print("[ImpHubX v7] Loaded — workspace.Characters + Knit-accurate signals")
print("[ImpHubX v7] Moveset attack: "..tostring(Knit~=nil and "Knit OK" or "Knit FAIL - will use VIM"))
