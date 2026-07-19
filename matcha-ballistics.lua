--[[
    Matcha Ballistics v3.3
]]

repeat task.wait() until game and game:GetService("Players")
local Players=game:GetService("Players")
repeat task.wait() until Players.LocalPlayer
local LP=Players.LocalPlayer
repeat task.wait() until workspace and workspace.CurrentCamera
local Camera=workspace.CurrentCamera
local RS=game:GetService("RunService")

local smoothCF=nil
local lastFire=0
local mode="Camlock"

local function Predict(origin,tPos,tVel,speed,grav,correction)
    correction=correction or 2
    local time=(tPos-origin).Magnitude/speed
    if time<0.001 then return tPos end
    local gVec=Vector3.new(0,math.abs(grav),0)
    return tPos+tVel*time+gVec*time*time/correction
end

local function GetTarget()
    local fov=UI.GetValue("fov")or 100
    local vs=Camera.ViewportSize
    if not vs or not vs.X then return nil end
    local center=vs/2
    local bestDist,bestPos=fov,nil
    for _,p in ipairs(Players:GetPlayers())do
        local skip=(p==LP)
        if not skip and(UI.GetValue("teamcheck")==true)and p.Team and LP.Team and p.Team==LP.Team then skip=true end
        if not skip then
            local c=p.Character
            if not c then skip=true end
            if not skip and(UI.GetValue("alivecheck")==true)then
                local h=c:FindFirstChildOfClass("Humanoid")
                if not h or h.Health<=0 then skip=true end
            end
            if not skip then
                local part=c:FindFirstChild(UI.GetValue("aimpart")or"Head")or c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("Head")
                if not part then skip=true end
                if not skip then
                    local pos=part.Position
                    local vel=part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
                    if(UI.GetValue("prediction")==true)then pos=Predict(Camera.Position,pos,vel,UI.GetValue("speed")or 2000,UI.GetValue("gravity")or 196.2)end
                    local ok,sp,on=pcall(WorldToScreen,pos)
                    if ok and on and sp and sp.X and sp.Y then
                        local dx=sp.X-center.X;local dy=sp.Y-center.Y
                        local dist=math.sqrt(dx*dx+dy*dy)
                        if dist<bestDist then bestDist,bestPos=dist,pos end
                    end
                end
            end
        end
    end
    return bestPos
end

local testC=Drawing.new("Circle")
testC.NumSides=72;testC.Thickness=2;testC.Visible=true;testC.ZIndex=9999
testC.Color=Color3.fromRGB(255,0,0);testC.Transparency=0.5
testC.Position=Vector2.new(400,400);testC.Radius=50

local fovC=Drawing.new("Circle")
fovC.NumSides=72;fovC.Thickness=1;fovC.Visible=false;fovC.ZIndex=999
fovC.Color=Color3.fromRGB(200,200,200);fovC.Transparency=0.7

RS.RenderStepped:Connect(function()
    local ok,err=pcall(function()
        local active=(UI.GetValue("aim_toggle")==true)or(UI.GetValue("aim_hold")==true)
        local modeIdx=UI.GetValue("modecombo")or 0
        local newMode=(modeIdx==0)and"Camlock"or"Mouse"
        if newMode~=mode then mode=newMode;smoothCF=nil end

        if UI.GetValue("showfov")==true and active then
            local vs=Camera.ViewportSize
            if vs and vs.X then
                fovC.Position=vs/2
                fovC.Radius=UI.GetValue("fov")or 100
                fovC.Visible=true
            end
        else fovC.Visible=false end

        if not active or not LP.Character then smoothCF=nil;return end
        local aimPos=GetTarget()
        if not aimPos then smoothCF=nil;return end

        local sp,on=WorldToScreen(aimPos)

        if mode=="Mouse"and sp and on then
            local cx,cy=Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2
            local s=(UI.GetValue("sens")or 5)/10
            local dx=(sp.X-cx)*s
            local dy=(sp.Y-cy)*s
            mousemoverel(dx,dy)
        end

        if mode=="Camlock" then
            local cp=Camera.Position;local cf=CFrame.lookAt(cp,aimPos)
            if not smoothCF then smoothCF=cf end
            smoothCF=smoothCF:Lerp(cf,UI.GetValue("smooth")or 0.45)
            local o2=pcall(function()Camera.CFrame=smoothCF end)
            if not o2 then pcall(Camera.lookAt,Camera,cp,aimPos)end
        end

        if UI.GetValue("autofire")==true then
            local n=tick();local r=(UI.GetValue("firerate")or 100)/1000
            if n-lastFire>=r then mouse1click();lastFire=n end
        end
    end)
    if not ok then print("[Ballistics]",err)end
end)

print("Loading Ballistics v3.3...")
UI.AddTab("Ballistics",function(tab)
    local ctrl=tab:Section("Controls","Left")
    ctrl:Keybind("aim_toggle",0x58,"toggle")  -- click to rebind
    ctrl:Keybind("aim_hold",0xA4,"hold")      -- click to rebind
    ctrl:Combo("modecombo","Mode",{"Camlock","Mouse"},0,function(idx)
        mode=(idx==0)and"Camlock"or"Mouse";smoothCF=nil
    end)

    local tgt=tab:Section("Targeting","Left")
    tgt:Combo("aimpart","Aim Part",{"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"},0)
    tgt:SliderInt("fov","FOV Radius",10,800,100)
    tgt:Toggle("teamcheck","Team Check",false)
    tgt:Toggle("alivecheck","Alive Check",true)
    tgt:Toggle("prediction","Prediction",true)

    local pred=tab:Section("Bullet Physics","Left")
    pred:SliderInt("speed","Bullet Speed",50,10000,2000)
    pred:SliderFloat("gravity","Gravity",0,500,196.2,"%.1f")

    local aim=tab:Section("Aiming","Right")
    aim:SliderFloat("smooth","Smoothness",0.05,1.0,0.45,"%.2f")
    aim:SliderFloat("sens","Mouse Sensitivity",0.5,20,5,"%.1f")
    aim:Toggle("autofire","Auto Fire",false)
    aim:SliderInt("firerate","Fire Rate(ms)",50,2000,100)

    local vis=tab:Section("Visuals","Right")
    vis:Toggle("showfov","FOV Circle",true)
    vis:ColorPicker("fovcolor",200,200,200,200,function(c,a)
        fovC.Color=c;fovC.Transparency=1-(a or 1)
    end)
end)
print("Ballistics v3.3 loaded")
