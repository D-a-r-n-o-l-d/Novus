-- Matcha Ballistics v3.6 — aimbot + camlock with prediction

repeat task.wait() until game and game:GetService("Players")
local Players=game:GetService("Players")
repeat task.wait() until Players.LocalPlayer
local LP=Players.LocalPlayer
repeat task.wait() until workspace and workspace.CurrentCamera
local Camera=workspace.CurrentCamera
local RS=game:GetService("RunService")

local smoothCF=nil;local lastFire=0;local mode="Camlock"
local kbWidget;local masterOn=true
-- Config values captured from UI callbacks
local fovVal=100;local speedVal=2000;local gravVal=196.2
local smoothVal=0.45;local sensVal=5;local fireRateVal=100

local function Predict(o,p,v,s,g,c)
    c=c or 2;local t=(p-o).Magnitude/s
    if t<0.001 then return p end
    local gv=Vector3.new(0,math.abs(g),0)
    return p+v*t+gv*t*t/c
end

local function GetTarget(ox,oy)
    local fov=fovVal
    local vs=Camera.ViewportSize;if not vs or not vs.X then return nil end
    local bd,bp=fov,nil
    for _,p in ipairs(Players:GetPlayers())do
        local s=(p==LP)
        if not s and(UI.GetValue("teamcheck")==true)and p.Team and LP.Team and p.Team==LP.Team then s=true end
        if not s then
            local ch=p.Character;if not ch then s=true end
            if not s and(UI.GetValue("alivecheck")==true)then
                local h=ch:FindFirstChildOfClass("Humanoid");if not h or h.Health<=0 then s=true end
            end
            if not s then
                local pt=ch:FindFirstChild(UI.GetValue("aimpart")or"Head")or ch:FindFirstChild("HumanoidRootPart")or ch:FindFirstChild("Head")
                if not pt then s=true end
                if not s then
                    local pos=pt.Position;local vel=pt.AssemblyLinearVelocity or pt.Velocity or Vector3.new()
                    if(UI.GetValue("prediction")==true)then pos=Predict(Camera.Position,pos,vel,speedVal,gravVal)end
                    local ok,sp,on=pcall(WorldToScreen,pos)
                    if ok and on and sp and sp.X and sp.Y then
                        local d=math.sqrt((sp.X-ox)^2+(sp.Y-oy)^2)
                        if d<bd then bd,bp=d,pos end
                    end
                end
            end
        end
    end
    return bp
end

local fovC=Drawing.new("Circle");fovC.NumSides=72;fovC.Thickness=1;fovC.Visible=false;fovC.ZIndex=999
fovC.Color=Color3.fromRGB(200,200,200);fovC.Transparency=0.7

RS.RenderStepped:Connect(function()
    local ok,err=pcall(function()
        local active=masterOn and(kbWidget and kbWidget.IsEnabled and kbWidget:IsEnabled())

        local modeIdx=UI.GetValue("modecombo")or 0
        local nm=(modeIdx==0)and"Camlock"or"Mouse"
        if nm~=mode then mode=nm;smoothCF=nil end

        local fov=fovVal
        if UI.GetValue("showfov")==true and active then
            local vs=Camera.ViewportSize
            if vs and vs.X then
                if mode=="Mouse"then
                    local mx,my=LP:GetMouse().X,LP:GetMouse().Y
                    if type(mx)=="number"then fovC.Position=Vector2.new(mx,my)
                    else fovC.Position=vs/2 end
                else fovC.Position=vs/2 end
                fovC.Radius=fov;fovC.Visible=true
            end
        else fovC.Visible=false end

        if not active or not LP.Character then smoothCF=nil;return end
        local ox,oy
        if mode=="Mouse"then
            local mx,my=LP:GetMouse().X,LP:GetMouse().Y
            if type(mx)=="number"then ox,oy=mx,my else ox,oy=Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2 end
        else ox,oy=Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2 end
        local aimPos=GetTarget(ox,oy);if not aimPos then smoothCF=nil;return end
        local sp,on=WorldToScreen(aimPos)

        if mode=="Mouse"and sp and on then
            local mx,my=LP:GetMouse().X,LP:GetMouse().Y
            if type(mx)~="number"then local vs=Camera.ViewportSize;mx=vs.X/2;my=vs.Y/2 end
            mousemoverel((sp.X-mx)*sensVal/10,(sp.Y-my)*sensVal/10)
        end
        if mode=="Camlock" then
            local cp=Camera.Position;local cf=CFrame.lookAt(cp,aimPos)
            if not smoothCF then smoothCF=cf end
            smoothCF=smoothCF:Lerp(cf,smoothVal)
            local o2=pcall(function()Camera.CFrame=smoothCF end)
            if not o2 then pcall(Camera.lookAt,Camera,cp,aimPos)end
        end
        if UI.GetValue("autofire")==true then
            local n=tick();local r=fireRateVal/1000
            if n-lastFire>=r then mouse1click();lastFire=n end
        end
    end)
    if not ok then print("[Ballistics]",err)end
end)

UI.AddTab("Ballistics",function(tab)
    local ctrl=tab:Section("Controls","Left")
    ctrl:Toggle("master","Enabled",true,function(v)masterOn=v end)
    kbWidget=ctrl:Keybind("aim_kb",0x58,"hold")
    ctrl:Tip("Hold key to aim — click to rebind")
    ctrl:Combo("modecombo","Mode",{"Camlock","Mouse"},0,function(idx)mode=(idx==0)and"Camlock"or"Mouse";smoothCF=nil end)

    local tgt=tab:Section("Targeting","Left")
    tgt:Combo("aimpart","Part",{"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"},0)
    fovWidget=tgt:SliderInt("fov","FOV Radius",10,800,100,function(v)fovVal=v end)
    tgt:Toggle("teamcheck","Team Check",false)
    tgt:Toggle("alivecheck","Alive Check",true)
    tgt:Toggle("prediction","Prediction",true)

    local pred=tab:Section("Bullet Physics","Left")
    pred:SliderInt("speed","Bullet Speed",50,10000,2000,function(v)speedVal=v end)
    pred:SliderFloat("gravity","Gravity",0,500,196.2,"%.1f",function(v)gravVal=v end)

    local aim=tab:Section("Aiming","Right")
    aim:SliderFloat("smooth","Smoothness",0.05,1.0,0.45,"%.2f",function(v)smoothVal=v end)
    aim:SliderFloat("sens","Sensitivity",0.5,20,5,"%.1f",function(v)sensVal=v end)
    aim:Toggle("autofire","Auto Fire",false)
    aim:SliderInt("firerate","Rate(ms)",50,2000,100,function(v)fireRateVal=v end)

    local vis=tab:Section("Visuals","Right")
    vis:Toggle("showfov","FOV Circle",true)
    vis:ColorPicker("fovcolor",200,200,200,200,function(c,a)fovC.Color=c;fovC.Transparency=1-(a or 1)end)
end)
print("Ballistics v3.6 loaded")
