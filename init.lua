local sources = {}

sources["shared.lua"] = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local shared = {}

shared.Players = Players
shared.RunService = RunService
shared.UIS = UIS
shared.Workspace = Workspace
shared.CoreGui = CoreGui
shared.GuiService = GuiService

shared.LocalPlayer = Players.LocalPlayer
shared.Camera = Workspace.CurrentCamera
shared.Mouse = shared.LocalPlayer:GetMouse()

shared.RMBHeld = false
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		shared.RMBHeld = true
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		shared.RMBHeld = false
	end
end)

shared.mousemoverel = mousemoverel or function() end
shared.mouse1press = mouse1press or function() end
shared.mouse1release = mouse1release or function() end

function shared.GetRelation(plr)
	if plr == shared.LocalPlayer then return nil end
	local lp = shared.LocalPlayer
	if lp.Team and plr.Team then
		if plr.Team == lp.Team or plr.TeamColor == lp.TeamColor then
			return "friendly"
		else
			return "enemy"
		end
	end
	return "enemy"
end

function shared.RainbowColor(offset)
	offset = offset or 0
	local t = (tick() * 0.2 + offset) % 1
	return Color3.fromHSV(t, 1, 1)
end

function shared.GetScreenCenter()
	local size = shared.Camera.ViewportSize
	return Vector2.new(size.X / 2, size.Y / 2)
end

shared.VisualsGui = Instance.new("ScreenGui")
shared.VisualsGui.Name = "Parvus2Visuals"
shared.VisualsGui.IgnoreGuiInset = true
shared.VisualsGui.ResetOnSpawn = false
shared.VisualsGui.Parent = CoreGui

shared.LerpColor = function(c1, c2)
	return function(t)
		return Color3.new(
			c1.R + (c2.R - c1.R) * t,
			c1.G + (c2.G - c1.G) * t,
			c1.B + (c2.B - c1.B) * t
		)
	end
end

return shared
]=]

sources["targeting.lua"] = [=[
local function MakeTargeting(S)
	local Players = S.Players
	local LocalPlayer = S.LocalPlayer
	local Camera = S.Camera
	local UIS = S.UIS
	local Workspace = S.Workspace

	local T = {}

	local WallCheckParams = RaycastParams.new()
	WallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
	WallCheckParams.IgnoreWater = true

	function T.Raycast(origin, direction, ignoreList)
		WallCheckParams.FilterDescendantsInstances = ignoreList
		return Workspace:Raycast(origin, direction, WallCheckParams)
	end

	function T.InEnemyTeam(teamCheck, plr)
		if not teamCheck then return true end
		if not LocalPlayer.Team or not plr.Team then return true end
		return LocalPlayer.Team ~= plr.Team
	end

	function T.WithinReach(distanceCheck, distance, limit)
		if not distanceCheck then return true end
		return distance <= limit
	end

	function T.ObjectOccluded(visibilityCheck, origin, targetPos, character)
		if not visibilityCheck then return false end
		local result = T.Raycast(origin, targetPos - origin, {character, LocalPlayer.Character})
		return result ~= nil
	end

	function T.SolveTrajectory(origin, velocity, time, gravityMag, correction)
		gravityMag = gravityMag or 196.2
		correction = correction or 2
		local g = Vector3.new(0, -gravityMag, 0)
		return origin + velocity * time + g * time * time / (2 * math.max(correction, 0.01))
	end

	function T.GetClosest(enabled, teamCheck, visibilityCheck, distanceCheck,
		distanceLimit, fovRadius, priority, bodyParts, predictionEnabled,
		projectileSpeed, gravity, gravityCorrection)

		if not enabled then return nil end

		local cameraPos = Camera.CFrame.Position
		local closestHit, closestMag = nil, fovRadius
		local mousePos = UIS:GetMouseLocation()

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local char = plr.Character
			if not char then continue end

			if not T.InEnemyTeam(teamCheck, plr) then continue end

			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then continue end

			local function checkPart(part)
				if not part then return end
				local pos = part.Position
				local distance = (pos - cameraPos).Magnitude
				if not T.WithinReach(distanceCheck, distance, distanceLimit) then return end

				if predictionEnabled and projectileSpeed and projectileSpeed > 0 then
					local travelTime = distance / projectileSpeed
					pos = T.SolveTrajectory(pos, part.AssemblyLinearVelocity, travelTime, gravity, gravityCorrection)
				end

				local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
				if not onScreen then return end
				if T.ObjectOccluded(visibilityCheck, cameraPos, pos, char) then return end

				local screen2d = Vector2.new(screenPos.X, screenPos.Y)
				local mag = (screen2d - mousePos).Magnitude
				if mag < closestMag then
					closestMag = mag
					closestHit = {plr, char, part, screen2d}
				end
			end

			if priority == "Random" then
				local partName = bodyParts[math.random(#bodyParts)]
				checkPart(char:FindFirstChild(partName))
			elseif priority ~= "Closest" then
				checkPart(char:FindFirstChild(priority))
			else
				for _, partName in ipairs(bodyParts) do
					checkPart(char:FindFirstChild(partName))
				end
			end
		end

		return closestHit
	end

	return T
end

return MakeTargeting
]=]

sources["menu.lua"] = [=[
return function(Tabs)
	local cb = Tabs.Combat

	local aimbot = cb:AddLeftGroupbox('Aimbot')
	local aimToggle = aimbot:AddToggle('AimbotEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Legit aimbot with smooth mouse movement',
	})
	aimToggle:AddKeyPicker('AimbotKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Aimbot',
		NoUI = false,
	})

	aimbot:AddToggle('AimbotAlwaysOn', {
		Text = 'Always On',
		Default = false,
		Tooltip = 'Aim without holding RMB',
	})

	aimbot:AddToggle('AimbotTeamCheck', {
		Text = 'Team Check',
		Default = false,
	})

	aimbot:AddToggle('AimbotDistanceCheck', {
		Text = 'Distance Check',
		Default = true,
	})

	aimbot:AddToggle('AimbotVisibilityCheck', {
		Text = 'Visibility Check',
		Default = false,
	})

	aimbot:AddToggle('AimbotPrediction', {
		Text = 'Prediction',
		Default = false,
		Tooltip = 'Lead targets based on velocity',
	})

	aimbot:AddSlider('AimbotSensitivity', {
		Text = 'Sensitivity',
		Default = 20,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})

	aimbot:AddSlider('AimbotFOV', {
		Text = 'FOV',
		Default = 100,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Suffix = ' px',
	})

	aimbot:AddSlider('AimbotDistanceLimit', {
		Text = 'Distance Limit',
		Default = 250,
		Min = 25,
		Max = 1000,
		Rounding = 0,
		Suffix = ' studs',
	})

	aimbot:AddDropdown('AimbotPriority', {
		Text = 'Priority',
		Values = {'Closest', 'Head', 'HumanoidRootPart'},
		Default = 'Closest',
		AllowNull = false,
	})

	local trig = cb:AddLeftGroupbox('Trigger Bot')
	local trigToggle = trig:AddToggle('TriggerEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Auto-fire when target enters FOV',
	})
	trigToggle:AddKeyPicker('TriggerKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Trigger',
		NoUI = false,
	})

	trig:AddToggle('TriggerAlwaysOn', {
		Text = 'Always On',
		Default = false,
	})

	trig:AddToggle('TriggerHoldMouse', {
		Text = 'Hold Mouse',
		Default = false,
	})

	trig:AddToggle('TriggerTeamCheck', {
		Text = 'Team Check',
		Default = false,
	})

	trig:AddToggle('TriggerDistanceCheck', {
		Text = 'Distance Check',
		Default = true,
	})

	trig:AddToggle('TriggerVisibilityCheck', {
		Text = 'Visibility Check',
		Default = false,
	})

	trig:AddToggle('TriggerPrediction', {
		Text = 'Prediction',
		Default = false,
	})

	trig:AddSlider('TriggerDelay', {
		Text = 'Delay',
		Default = 150,
		Min = 0,
		Max = 1000,
		Rounding = 0,
		Suffix = ' ms',
	})

	trig:AddSlider('TriggerFOV', {
		Text = 'FOV',
		Default = 25,
		Min = 0,
		Max = 500,
		Rounding = 0,
		Suffix = ' px',
	})

	trig:AddSlider('TriggerDistanceLimit', {
		Text = 'Distance Limit',
		Default = 250,
		Min = 25,
		Max = 1000,
		Rounding = 0,
		Suffix = ' studs',
	})

	trig:AddDropdown('TriggerPriority', {
		Text = 'Priority',
		Values = {'Closest', 'Head', 'HumanoidRootPart', 'Random'},
		Default = 'Closest',
		AllowNull = false,
	})

	local hitboxGrp = cb:AddRightGroupbox('Hitboxes')
	hitboxGrp:AddToggle('HitboxEnabled', {
		Text = 'Enabled',
		Default = false,
		Tooltip = 'Enlarge enemy hitboxes',
	})
	hitboxGrp:AddSlider('HitboxSize', {
		Text = 'Size',
		Default = 20,
		Min = 5,
		Max = 200,
		Rounding = 0,
		Suffix = ' studs',
	})

	local pred = cb:AddRightGroupbox('Prediction')
	pred:AddSlider('PredictionProjectileSpeed', {
		Text = 'Projectile Speed',
		Default = 1000,
		Min = 100,
		Max = 10000,
		Rounding = 0,
		Suffix = ' studs/s',
	})
	pred:AddSlider('PredictionGravity', {
		Text = 'Gravity',
		Default = 196.2,
		Min = 0,
		Max = 400,
		Rounding = 1,
	})
	pred:AddSlider('PredictionGravityCorrection', {
		Text = 'Gravity Correction',
		Default = 2,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local vb = Tabs.Visuals

	local skel = vb:AddLeftGroupbox('Skeleton ESP')
	local skEnToggle = skel:AddToggle('SkeletonEnemyEnabled', {
		Text = 'Enemy Skeleton',
		Default = false,
	})
	skEnToggle:AddKeyPicker('SkeletonKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Skeleton',
		NoUI = false,
	})
	skel:AddToggle('SkeletonEnemyRainbow', {
		Text = 'Enemy Rainbow',
		Default = false,
	})
	skel:AddLabel('Enemy Color'):AddColorPicker('SkeletonEnemyColor', {
		Default = Color3.fromRGB(0, 255, 255),
		Title = 'Enemy Skeleton',
	})
	skel:AddToggle('SkeletonFriendlyEnabled', {
		Text = 'Friendly Skeleton',
		Default = false,
	})
	skel:AddToggle('SkeletonFriendlyRainbow', {
		Text = 'Friendly Rainbow',
		Default = false,
	})
	skel:AddLabel('Friendly Color'):AddColorPicker('SkeletonFriendlyColor', {
		Default = Color3.fromRGB(0, 255, 0),
		Title = 'Friendly Skeleton',
	})
	skel:AddSlider('SkeletonThickness', {
		Text = 'Thickness',
		Default = 1.5,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local box3d = vb:AddLeftGroupbox('3D Box ESP')
	local bx3Toggle = box3d:AddToggle('Box3DEnabled', {
		Text = 'Enabled',
		Default = false,
	})
	bx3Toggle:AddKeyPicker('Box3DKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = '3D Boxes',
		NoUI = false,
	})
	box3d:AddToggle('Box3DTeamCheck', {
		Text = 'Team Check',
		Default = true,
	})
	box3d:AddLabel('Color'):AddColorPicker('Box3DColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = '3D Box',
	})
	box3d:AddSlider('Box3DOpacity', {
		Text = 'Opacity',
		Default = 25,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	box3d:AddSlider('Box3DThickness', {
		Text = 'Thickness',
		Default = 1,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})

	local fovGrp = vb:AddRightGroupbox('FOV Circles')
	fovGrp:AddToggle('FOVAimbotVisible', {
		Text = 'Show Aimbot FOV',
		Default = true,
	})
	fovGrp:AddToggle('FOVTriggerVisible', {
		Text = 'Show Trigger FOV',
		Default = true,
	})
	fovGrp:AddToggle('FOVFilled', {
		Text = 'Filled Circles',
		Default = false,
	})
	fovGrp:AddSlider('FOVThickness', {
		Text = 'Thickness',
		Default = 1.5,
		Min = 1,
		Max = 10,
		Rounding = 1,
	})
	fovGrp:AddSlider('FOVSides', {
		Text = 'Circle Sides',
		Default = 40,
		Min = 10,
		Max = 100,
		Rounding = 0,
	})
	fovGrp:AddLabel('Aimbot Color'):AddColorPicker('FOVAimbotColor', {
		Default = Color3.fromRGB(120, 170, 255),
		Title = 'Aimbot FOV',
	})
	fovGrp:AddLabel('Trigger Color'):AddColorPicker('FOVTriggerColor', {
		Default = Color3.fromRGB(120, 255, 170),
		Title = 'Trigger FOV',
	})

	local chams = vb:AddLeftGroupbox('Chams')
	local chEnToggle = chams:AddToggle('ChamsEnemyEnabled', {
		Text = 'Enemy Chams',
		Default = false,
	})
	chEnToggle:AddKeyPicker('ChamsKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Chams',
		NoUI = false,
	})
	chams:AddLabel('Enemy Fill'):AddColorPicker('ChamsEnemyFillColor', {
		Default = Color3.fromRGB(255, 0, 0),
		Title = 'Enemy Fill',
	})
	chams:AddLabel('Enemy Outline'):AddColorPicker('ChamsEnemyOutlineColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Enemy Outline',
	})
	chams:AddToggle('ChamsFriendlyEnabled', {
		Text = 'Friendly Chams',
		Default = false,
	})
	chams:AddLabel('Friendly Fill'):AddColorPicker('ChamsFriendlyFillColor', {
		Default = Color3.fromRGB(0, 255, 0),
		Title = 'Friendly Fill',
	})
	chams:AddLabel('Friendly Outline'):AddColorPicker('ChamsFriendlyOutlineColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Friendly Outline',
	})
	chams:AddSlider('ChamsFillOpacity', {
		Text = 'Fill Opacity',
		Default = 60,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	chams:AddSlider('ChamsOutlineOpacity', {
		Text = 'Outline Opacity',
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})

	local arrowGrp = vb:AddRightGroupbox('Arrows & Nametags')
	arrowGrp:AddToggle('ArrowEnabled', {
		Text = 'Off-screen Arrows',
		Default = false,
	})
	arrowGrp:AddToggle('ArrowTeamCheck', {
		Text = 'Arrow Team Check',
		Default = true,
	})
	arrowGrp:AddSlider('ArrowSize', {
		Text = 'Arrow Size',
		Default = 18,
		Min = 8,
		Max = 40,
		Rounding = 0,
		Suffix = ' px',
	})
	arrowGrp:AddSlider('ArrowRadius', {
		Text = 'Arrow Radius',
		Default = 220,
		Min = 50,
		Max = 400,
		Rounding = 0,
		Suffix = ' px',
	})
	arrowGrp:AddSlider('ArrowThickness', {
		Text = 'Arrow Thickness',
		Default = 2,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})
	arrowGrp:AddLabel('Color'):AddColorPicker('ArrowColor', {
		Default = Color3.fromRGB(255, 255, 255),
		Title = 'Arrow',
	})
	arrowGrp:AddDivider()
	arrowGrp:AddToggle('NameTagEnabled', {
		Text = 'Enable Name Tags',
		Default = false,
	})
	arrowGrp:AddToggle('NameTagShowDistance', {
		Text = 'Show Distance',
		Default = true,
	})
	arrowGrp:AddToggle('NameTagUseDisplay', {
		Text = 'Use Display Name',
		Default = true,
	})

	local radarGrp = vb:AddRightGroupbox('Radar & Aim Viewer')
	local radToggle = radarGrp:AddToggle('RadarEnabled', {
		Text = 'Enable Radar',
		Default = false,
	})
	radToggle:AddKeyPicker('RadarKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Radar',
		NoUI = false,
	})
	radarGrp:AddToggle('RadarTeamCheck', {
		Text = 'Team Check',
		Default = true,
	})
	radarGrp:AddToggle('RadarHealthColor', {
		Text = 'Health Color',
		Default = true,
	})
	radarGrp:AddSlider('RadarRadius', {
		Text = 'Radius',
		Default = 100,
		Min = 50,
		Max = 400,
		Rounding = 0,
		Suffix = ' px',
	})
	radarGrp:AddSlider('RadarScale', {
		Text = 'Scale',
		Default = 1,
		Min = 1,
		Max = 5,
		Rounding = 1,
	})
	radarGrp:AddSlider('RadarMaxDistance', {
		Text = 'Max Distance',
		Default = 1000,
		Min = 100,
		Max = 2000,
		Rounding = 0,
		Suffix = ' studs',
	})
	radarGrp:AddSlider('RadarDistanceTransparency', {
		Text = 'Distance Fade',
		Default = 0,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = '%',
	})
	radarGrp:AddDivider()
	local avToggle = radarGrp:AddToggle('AimViewerEnabled', {
		Text = 'Enable Aim Viewer',
		Default = false,
	})
	avToggle:AddKeyPicker('AimViewerKey', {
		Default = '',
		Mode = 'Toggle',
		SyncToggleState = true,
		Text = 'Aim Viewer',
		NoUI = false,
	})

	local mb = Tabs.Movement

	local mov = mb:AddLeftGroupbox('Movement')
	mov:AddSlider('MovementWalkSpeed', {
		Text = 'WalkSpeed',
		Default = 16,
		Min = 8,
		Max = 300,
		Rounding = 0,
		Suffix = ' studs/s',
	})
	mov:AddSlider('MovementJumpPower', {
		Text = 'JumpPower',
		Default = 50,
		Min = 25,
		Max = 500,
		Rounding = 0,
	})
	mov:AddToggle('MovementClickTP', {
		Text = 'Click Teleport',
		Default = false,
		Tooltip = 'Left-click to teleport',
	})

	local sb = Tabs.Settings
	local menuGroup = sb:AddLeftGroupbox('Menu')
	menuGroup:AddLabel('Menu key'):AddKeyPicker('MenuKeybind', {
		Default = 'End',
		Mode = 'Toggle',
		Text = 'Menu keybind',
		NoUI = true,
	})
end
]=]
sources["modules/esp_skeleton.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local LocalPlayer = S.LocalPlayer

local module = {}
local lines = {}
local conn
local stopping = false

local function getPartPos(char, partName, r15a, r15b, r6)
	local part = char:FindFirstChild(partName)
	if not part and r15a then part = char:FindFirstChild(r15a) end
	if not part and r15b then part = char:FindFirstChild(r15b) end
	if not part and r6 then part = char:FindFirstChild(r6) end
	if not part then return nil end
	local p, onScreen = Camera:WorldToViewportPoint(part.Position)
	if not onScreen then return nil end
	return Vector2.new(p.X, p.Y)
end

function module.stop()
	stopping = true
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, pLines in pairs(lines) do
		for _, l in ipairs(pLines) do
			l:Remove()
		end
	end
	lines = {}
	stopping = false
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if stopping then return end

		for plr, pLines in pairs(lines) do
			if not Players:FindFirstChild(plr.Name) then
				for _, l in ipairs(pLines) do l:Remove() end
				lines[plr] = nil
			end
		end

		local enemyOn = Toggles.SkeletonEnemyEnabled.Value
		local friendlyOn = Toggles.SkeletonFriendlyEnabled.Value
		if not (enemyOn or friendlyOn) then return end

		local enemyColor = Options.SkeletonEnemyColor.Value
		local friendlyColor = Options.SkeletonFriendlyColor.Value
		local enemyRainbow = Toggles.SkeletonEnemyRainbow.Value
		local friendlyRainbow = Toggles.SkeletonFriendlyRainbow.Value
		local thickness = Options.SkeletonThickness.Value

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local relation = S.GetRelation(plr)
			local wantEnemy = relation == "enemy" and enemyOn
			local wantFriendly = relation == "friendly" and friendlyOn
			if not (wantEnemy or wantFriendly) then
				if lines[plr] then
					for _, l in ipairs(lines[plr]) do l:Remove() end
					lines[plr] = nil
				end
				continue
			end

			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and hrp and hum and hum.Health > 0) then
				if lines[plr] then
					for _, l in ipairs(lines[plr]) do l:Remove() end
					lines[plr] = nil
				end
				continue
			end

			if not lines[plr] then
				local pLines = {}
				for i = 1, 6 do
					local ln = Drawing.new("Line")
					ln.Visible = false
					ln.Thickness = thickness
					ln.Transparency = 0
					table.insert(pLines, ln)
				end
				lines[plr] = pLines
			end

			local pLines = lines[plr]
			for _, l in ipairs(pLines) do
				l.Thickness = thickness
			end

			local color
			if relation == "enemy" then
				color = enemyRainbow and S.RainbowColor(0.1) or enemyColor
			else
				color = friendlyRainbow and S.RainbowColor(0.2) or friendlyColor
			end

			local headPos = getPartPos(char, "Head")
			local upperTorso = getPartPos(char, "UpperTorso", nil, nil, "Torso")
			local lowerTorso = getPartPos(char, "LowerTorso", nil, nil, "Torso")
			local leftArm = getPartPos(char, "LeftHand", "LeftLowerArm", nil, "Left Arm")
			local rightArm = getPartPos(char, "RightHand", "RightLowerArm", nil, "Right Arm")
			local leftLeg = getPartPos(char, "LeftFoot", "LeftLowerLeg", nil, "Left Leg")
			local rightLeg = getPartPos(char, "RightFoot", "RightLowerLeg", nil, "Right Leg")

			local idx = 1
			local function drawBone(a, b)
				local ln = pLines[idx]
				if a and b and ln then
					ln.Visible = true
					ln.Color = color
					ln.Thickness = thickness
					ln.From = a
					ln.To = b
				elseif ln then
					ln.Visible = false
				end
				idx = idx + 1
			end

			drawBone(headPos, upperTorso)
			drawBone(upperTorso, lowerTorso)
			drawBone(upperTorso, leftArm)
			drawBone(upperTorso, rightArm)
			drawBone(lowerTorso, leftLeg)
			drawBone(lowerTorso, rightLeg)
		end
	end)
end

return module
]=]

sources["modules/esp_3dbox.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local LocalPlayer = S.LocalPlayer

local module = {}
local boxLines = {}
local boxQuads = {}
local conn

local function newLine()
	local l = Drawing.new("Line")
	l.Visible = false
	return l
end

local function newQuad()
	local q = Drawing.new("Quad")
	q.Visible = false
	q.Filled = true
	return q
end

local function clearAll()
	for _, l in ipairs(boxLines) do l:Remove() end
	for _, q in ipairs(boxQuads) do q:Remove() end
	boxLines = {}
	boxQuads = {}
end

local function getCorners(cf, size)
	local half = size / 2
	local corners = {}
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				table.insert(corners, (cf * CFrame.new(half * Vector3.new(x, y, z))).Position)
			end
		end
	end
	return corners
end

local function drawQuad(a, b, c, d, color, transparency)
	local sa, va = Camera:WorldToViewportPoint(a)
	local sb, vb = Camera:WorldToViewportPoint(b)
	local sc, vc = Camera:WorldToViewportPoint(c)
	local sd, vd = Camera:WorldToViewportPoint(d)
	if not (va or vb or vc or vd) then return end
	local q = newQuad()
	q.Color = color
	q.Transparency = 1 - transparency
	q.PointA = Vector2.new(sa.X, sa.Y)
	q.PointB = Vector2.new(sb.X, sb.Y)
	q.PointC = Vector2.new(sc.X, sc.Y)
	q.PointD = Vector2.new(sd.X, sd.Y)
	q.Visible = true
	table.insert(boxQuads, q)
end

local function drawLine(p0, p1, color, transparency, thickness)
	local s0, v0 = Camera:WorldToViewportPoint(p0)
	local s1, v1 = Camera:WorldToViewportPoint(p1)
	if not (v0 or v1) then return end
	local l = newLine()
	l.Color = color
	l.Thickness = thickness
	l.Transparency = 1 - transparency
	l.From = Vector2.new(s0.X, s0.Y)
	l.To = Vector2.new(s1.X, s1.Y)
	l.Visible = true
	table.insert(boxLines, l)
end

local function isEnemy(plr, teamCheck)
	if plr == LocalPlayer then return false end
	if not teamCheck then return true end
	if not LocalPlayer.Team or not plr.Team then return true end
	return plr.Team ~= LocalPlayer.Team
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	clearAll()
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.Box3DEnabled.Value then
			if #boxLines > 0 or #boxQuads > 0 then
				clearAll()
			end
			return
		end

		clearAll()

		local color = Options.Box3DColor.Value
		local transparency = Options.Box3DOpacity.Value / 100
		local thickness = Options.Box3DThickness.Value
		local teamCheck = Toggles.Box3DTeamCheck.Value

		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemy(plr, teamCheck) and plr.Character then
				local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local fake = {
						CFrame = hrp.CFrame * CFrame.new(0, -0.5, 0),
						Size = Vector3.new(3, 5, 3)
					}
					local c = getCorners(fake.CFrame, fake.Size)

					drawLine(c[1], c[2], color, transparency, thickness)
					drawLine(c[2], c[6], color, transparency, thickness)
					drawLine(c[6], c[5], color, transparency, thickness)
					drawLine(c[5], c[1], color, transparency, thickness)
					drawQuad(c[1], c[2], c[6], c[5], color, transparency)

					drawLine(c[1], c[3], color, transparency, thickness)
					drawLine(c[2], c[4], color, transparency, thickness)
					drawLine(c[6], c[8], color, transparency, thickness)
					drawLine(c[5], c[7], color, transparency, thickness)

					drawQuad(c[2], c[4], c[8], c[6], color, transparency)
					drawQuad(c[1], c[2], c[4], c[3], color, transparency)
					drawQuad(c[1], c[5], c[7], c[3], color, transparency)
					drawQuad(c[5], c[7], c[8], c[6], color, transparency)

					drawLine(c[3], c[4], color, transparency, thickness)
					drawLine(c[4], c[8], color, transparency, thickness)
					drawLine(c[8], c[7], color, transparency, thickness)
					drawLine(c[7], c[3], color, transparency, thickness)
					drawQuad(c[3], c[4], c[8], c[7], color, transparency)
				end
			end
		end
	end)
end

return module
]=]

sources["modules/esp_chams.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local VisualsGui = S.VisualsGui

local module = {}
local chams = {}
local conn

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, h in pairs(chams) do
		h:Destroy()
	end
	chams = {}
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local relation = S.GetRelation(plr)
			local wantEnemy = relation == "enemy" and Toggles.ChamsEnemyEnabled.Value
			local wantFriendly = relation == "friendly" and Toggles.ChamsFriendlyEnabled.Value

			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and hum and hum.Health > 0 and (wantEnemy or wantFriendly)) then
				if chams[plr] then
					chams[plr]:Destroy()
					chams[plr] = nil
				end
				continue
			end

			local highlight = chams[plr]
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "Parvus2Cham"
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = VisualsGui
				chams[plr] = highlight
			end

			highlight.Adornee = char
			if relation == "enemy" then
				highlight.FillColor = Options.ChamsEnemyFillColor.Value
				highlight.OutlineColor = Options.ChamsEnemyOutlineColor.Value
			else
				highlight.FillColor = Options.ChamsFriendlyFillColor.Value
				highlight.OutlineColor = Options.ChamsFriendlyOutlineColor.Value
			end
			highlight.FillTransparency = 1 - (Options.ChamsFillOpacity.Value / 100)
			highlight.OutlineTransparency = 1 - (Options.ChamsOutlineOpacity.Value / 100)
			highlight.Enabled = true
		end

		for plr, h in pairs(chams) do
			if not Players:FindFirstChild(plr.Name) or not plr.Character then
				h:Destroy()
				chams[plr] = nil
			end
		end
	end)
end

return module
]=]

sources["modules/esp_arrows.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local LocalPlayer = S.LocalPlayer

local module = {}
local arrows = {}
local conn

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, tri in pairs(arrows) do
		tri:Remove()
	end
	arrows = {}
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.ArrowEnabled.Value then
			for _, tri in pairs(arrows) do
				tri.Visible = false
			end
			return
		end

		local center = S.GetScreenCenter()
		local viewport = Camera.ViewportSize
		local teamCheck = Toggles.ArrowTeamCheck.Value
		local size = Options.ArrowSize.Value
		local radius = Options.ArrowRadius.Value
		local thickness = Options.ArrowThickness.Value
		local color = Options.ArrowColor.Value

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local relation = S.GetRelation(plr)
			if teamCheck and relation ~= "enemy" then
				if arrows[plr] then
					arrows[plr].Visible = false
				end
				continue
			end

			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and hrp and hum and hum.Health > 0) then
				if arrows[plr] then
					arrows[plr]:Remove()
					arrows[plr] = nil
				end
				continue
			end

			local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
			local screenPos = Vector2.new(pos.X, pos.Y)

			local tri = arrows[plr]
			if not tri then
				tri = Drawing.new("Triangle")
				tri.Filled = true
				tri.Thickness = thickness
				tri.Transparency = 0
				arrows[plr] = tri
			end

			if onScreen and pos.Z > 0
				and screenPos.X >= 0 and screenPos.X <= viewport.X
				and screenPos.Y >= 0 and screenPos.Y <= viewport.Y then
				tri.Visible = false
			else
				local dir = screenPos - center
				if dir.Magnitude == 0 then dir = Vector2.new(0, -1) end
				dir = dir.Unit
				local baseDir = Vector2.new(-dir.Y, dir.X)
				local tip = center + dir * radius
				local baseHalf = size / 2

				tri.PointA = tip
				tri.PointB = tip - dir * size + baseDir * baseHalf
				tri.PointC = tip - dir * size - baseDir * baseHalf
				tri.Color = color
				tri.Thickness = thickness
				tri.Visible = true
			end
		end

		for plr, tri in pairs(arrows) do
			if not Players:FindFirstChild(plr.Name) then
				tri:Remove()
				arrows[plr] = nil
			end
		end
	end)
end

return module
]=]

sources["modules/esp_nametags.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local VisualsGui = S.VisualsGui

local module = {}
local tags = {}
local conn

local function getOrCreate(plr, char)
	local head = char:FindFirstChild("Head")
	if not head then return nil end

	local gui = tags[plr]
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Parvus2NameTag"
		gui.Size = UDim2.new(0, 200, 0, 40)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 500
		gui.Adornee = head

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.5
		label.TextScaled = true
		label.Parent = gui

		gui.Parent = VisualsGui
		tags[plr] = gui
	else
		gui.Adornee = head
	end

	return gui
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, gui in pairs(tags) do
		gui.Enabled = false
	end
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.NameTagEnabled.Value

		for plr, gui in pairs(tags) do
			if not Players:FindFirstChild(plr.Name)
				or not plr.Character
				or not plr.Character:FindFirstChild("Head")
				or not enabled then
				gui.Enabled = false
			end
		end

		if not enabled then return end

		local localChar = LocalPlayer.Character
		local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end

			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local head = char and char:FindFirstChild("Head")
			if not (char and hum and hum.Health > 0 and head) then
				if tags[plr] then tags[plr].Enabled = false end
				continue
			end

			local gui = getOrCreate(plr, char)
			local label = gui and gui:FindFirstChild("Text")
			if not (gui and label) then continue end

			gui.Enabled = true

			local baseName
			if Toggles.NameTagUseDisplay.Value and plr.DisplayName and plr.DisplayName ~= "" then
				if plr.DisplayName ~= plr.Name then
					baseName = plr.Name .. " (@" .. plr.DisplayName .. ")"
				else
					baseName = plr.Name
				end
			else
				baseName = plr.Name
			end

			local text = baseName
			if Toggles.NameTagShowDistance.Value and localHRP then
				local dist = (head.Position - localHRP.Position).Magnitude
				text = string.format("%s [%dm]", text, math.floor(dist + 0.5))
			end

			label.Text = text

			local relation = S.GetRelation(plr)
			if relation == "friendly" then
				label.TextColor3 = Color3.fromRGB(0, 255, 0)
			else
				label.TextColor3 = Color3.fromRGB(255, 80, 80)
			end
		end
	end)
end

return module
]=]

sources["modules/esp_radar.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local Camera = S.Camera
local UIS = S.UIS
local GuiService = S.GuiService
local LocalPlayer = S.LocalPlayer
local Mouse = S.Mouse

local module = {}
local dots, conns = {}, {}
local conn, playerAddedConn, hoverDot
local dragging = false
local dragOffset = Vector2.new(0, 0)
local inset = GuiService:GetGuiInset()
local radarPos = Vector2.new(200, 200)

local bg, border, localDot

local HealthLerp = S.LerpColor(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))

local function newCircle(transparency, color, radius, filled, thickness)
	local c = Drawing.new("Circle")
	c.Transparency = transparency
	c.Color = color
	c.Visible = false
	c.Thickness = thickness
	c.Position = Vector2.new(0, 0)
	c.Radius = radius
	c.NumSides = math.clamp(radius * 55 / 100, 10, 75)
	c.Filled = filled
	return c
end

local function getRelative(pos)
	local char = LocalPlayer.Character
	if char and char.PrimaryPart then
		local pmpart = char.PrimaryPart
		local camerapos = Vector3.new(Camera.CFrame.Position.X, pmpart.Position.Y, Camera.CFrame.Position.Z)
		local newcf = CFrame.new(pmpart.Position, camerapos)
		local r = newcf:PointToObjectSpace(pos)
		return r.X, r.Z
	end
	return 0, 0
end

local function updateRadarVisuals(radius)
	if bg then
		bg.Position = radarPos
		bg.Radius = radius
		bg.Visible = Toggles.RadarEnabled.Value
		border.Position = radarPos
		border.Radius = radius
		border.Visible = Toggles.RadarEnabled.Value
		if localDot then
			localDot.Visible = Toggles.RadarEnabled.Value
			localDot.Color = Color3.fromRGB(255, 255, 255)
			localDot.PointA = radarPos + Vector2.new(0, -6)
			localDot.PointB = radarPos + Vector2.new(-3, 6)
			localDot.PointC = radarPos + Vector2.new(3, 6)
		end
	end
end

local function placeDot(plr)
	local dot = newCircle(0, Color3.fromRGB(60, 170, 255), 3, true, 1)

	local dotConn = RunService.RenderStepped:Connect(function()
		if not Toggles.RadarEnabled.Value then
			dot.Visible = false
			return
		end

		local char = plr.Character
		if char and char:FindFirstChildOfClass("Humanoid") and char.PrimaryPart
			and char:FindFirstChildOfClass("Humanoid").Health > 0 then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local scale = Options.RadarScale.Value
			local relx, rely = getRelative(char.PrimaryPart.Position)
			local newpos = radarPos - Vector2.new(relx * scale, rely * scale)

			local dist3d = 0
			local localChar = LocalPlayer.Character
			local localRoot = localChar and localChar.PrimaryPart
			local maxDist = Options.RadarMaxDistance.Value
			if localRoot then
				dist3d = (char.PrimaryPart.Position - localRoot.Position).Magnitude
				if maxDist > 0 and dist3d > maxDist then
					dot.Visible = false
					return
				end
			end

			local radius = Options.RadarRadius.Value
			if (newpos - radarPos).Magnitude < radius - 2 then
				dot.Radius = 3
				dot.Position = newpos
				dot.Visible = true
			else
				local dist = (radarPos - newpos).Magnitude
				local calc = (radarPos - newpos).Unit * (dist - radius)
				local inside = Vector2.new(newpos.X + calc.X, newpos.Y + calc.Y)
				dot.Radius = 2
				dot.Position = inside
				dot.Visible = true
			end

			if Toggles.RadarTeamCheck.Value then
				if plr.TeamColor == LocalPlayer.TeamColor then
					dot.Color = Color3.fromRGB(0, 255, 0)
				else
					dot.Color = Color3.fromRGB(255, 0, 0)
				end
			else
				dot.Color = Color3.fromRGB(60, 170, 255)
			end

			if Toggles.RadarHealthColor.Value then
				dot.Color = HealthLerp(hum.Health / hum.MaxHealth)
			end

			local fade = Options.RadarDistanceTransparency.Value / 100
			if fade > 0 and maxDist > 0 then
				local t = math.clamp(dist3d / maxDist, 0, 1)
				dot.Transparency = t * fade
			else
				dot.Transparency = 0
			end
		else
			dot.Visible = false
			if not Players:FindFirstChild(plr.Name) then
				dot:Remove()
				dotConn:Disconnect()
			end
		end
	end)

	table.insert(conns, dotConn)
	table.insert(dots, dot)
end

function module.stop()
	if conn then conn:Disconnect() conn = nil end
	if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn = nil end
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	for _, d in ipairs(dots) do d:Remove() end
	dots = {}
	if bg then bg:Remove() bg = nil end
	if border then border:Remove() border = nil end
	if localDot then localDot:Remove() localDot = nil end
	if hoverDot then hoverDot:Remove() hoverDot = nil end
end

function module.start()
	if conn then return end

	bg = newCircle(0.1, Color3.fromRGB(10, 10, 10), 100, true, 1)
	border = newCircle(0.25, Color3.fromRGB(75, 75, 75), 100, false, 3)

	localDot = Drawing.new("Triangle")
	localDot.Visible = false
	localDot.Thickness = 1
	localDot.Filled = true
	localDot.Color = Color3.fromRGB(255, 255, 255)

	conn = RunService.RenderStepped:Connect(function()
		updateRadarVisuals(Options.RadarRadius.Value)
	end)

	for _, v in pairs(Players:GetPlayers()) do
		if v ~= LocalPlayer then
			placeDot(v)
		end
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(v)
		if v ~= LocalPlayer then
			placeDot(v)
		end
	end)

	hoverDot = newCircle(1, Color3.fromRGB(255, 255, 255), 3, true, 1)

	local hoverConn = RunService.RenderStepped:Connect(function()
		if not Toggles.RadarEnabled.Value then
			hoverDot.Visible = false
			return
		end
		local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
		if (mousePos - radarPos).Magnitude < Options.RadarRadius.Value then
			hoverDot.Position = mousePos
			hoverDot.Visible = true
		else
			hoverDot.Visible = false
		end
		if dragging then
			radarPos = Vector2.new(Mouse.X, Mouse.Y) + dragOffset
		end
	end)
	table.insert(conns, hoverConn)

	local dragConn = UIS.InputBegan:Connect(function(input)
		if not Toggles.RadarEnabled.Value then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
			if (mousePos - radarPos).Magnitude < Options.RadarRadius.Value then
				dragOffset = radarPos - Vector2.new(Mouse.X, Mouse.Y)
				dragging = true
			end
		end
	end)
	table.insert(conns, dragConn)

	local endConn = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	table.insert(conns, endConn)
end

return module
]=]

sources["modules/esp_aimviewer.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local LocalPlayer = S.LocalPlayer
local Workspace = S.Workspace

local module = {}
local beams = {}
local charConns = {}

local Terrain = Workspace.Terrain

local aimColours = {
	At = ColorSequence.new(Color3.new(1, 0, 0)),
	Away = ColorSequence.new(Color3.new(0, 1, 0)),
}

local function isBeamHit(beam, mousePos)
	if not beam or not beam.Attachment0 or not beam.Attachment1 then return end

	local character = LocalPlayer.Character
	local origin = beam.Attachment0.WorldPosition
	local direction = mousePos - origin

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character, Workspace.CurrentCamera }

	local result = Workspace:Raycast(origin, direction * 2, raycastParams)
	if not result then
		beam.Color = aimColours.Away
		beam.Attachment1.WorldPosition = mousePos
		beam.Enabled = Toggles.AimViewerEnabled.Value
		return
	end

	if character then
		local hitOwnChar = result.Instance:IsDescendantOf(character)
		beam.Color = hitOwnChar and aimColours.At or aimColours.Away
	end

	beam.Attachment1.WorldPosition = result.Position
	beam.Enabled = Toggles.AimViewerEnabled.Value
end

local function createBeam(character)
	if beams[character] then return beams[character] end

	local head = character:FindFirstChild("Head")
	if not head then return nil end

	local faceAttachment = head:FindFirstChild("FaceCenterAttachment")
	if not faceAttachment then return nil end

	local beam = Instance.new("Beam")
	beam.Attachment0 = faceAttachment
	beam.Enabled = false
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.Parent = character

	beams[character] = beam
	return beam
end

local function updateBeamEnabled()
	for character, beam in pairs(beams) do
		if beam and beam.Parent then
			local hasGun = character:FindFirstChild("GunScript", true) ~= nil
			beam.Enabled = Toggles.AimViewerEnabled.Value and hasGun
		end
	end
end

local function onCharacter(character)
	if not character then return end

	local bodyEffects = character:FindFirstChild("BodyEffects")
	local mousePosVal = bodyEffects and bodyEffects:FindFirstChild("MousePos")
	if not mousePosVal then
		task.spawn(function()
			local be = character:WaitForChild("BodyEffects", 5)
			if not be then return end
			local mp = be:WaitForChild("MousePos", 5)
			if not mp then return end
			onCharacter(character)
		end)
		return
	end

	local beam = createBeam(character)
	if not beam then return end

	local attachment = Instance.new("Attachment")
	attachment.Parent = Terrain
	beam.Attachment1 = attachment

	isBeamHit(beam, mousePosVal.Value)

	local conn = mousePosVal.Changed:Connect(function()
		if not Toggles.AimViewerEnabled.Value then return end
		isBeamHit(beam, mousePosVal.Value)
	end)
	if not charConns[character] then charConns[character] = {} end
	table.insert(charConns[character], conn)

	local gunConn = character.DescendantAdded:Connect(function(desc)
		if desc.Name == "GunScript" then
			updateBeamEnabled()
		end
	end)
	table.insert(charConns[character], gunConn)

	local remConn = character.DescendantRemoving:Connect(function(desc)
		if desc.Name == "GunScript" then
			updateBeamEnabled()
		end
	end)
	table.insert(charConns[character], remConn)

	updateBeamEnabled()
end

local function onPlayer(plr)
	if plr == LocalPlayer then return end

	if plr.Character then
		onCharacter(plr.Character)
	end

	plr.CharacterAdded:Connect(function(char)
		onCharacter(char)
	end)
end



local playerAddedConn

function module.start()
	if playerAddedConn then return end

	for _, plr in ipairs(Players:GetPlayers()) do
		onPlayer(plr)
	end
	playerAddedConn = Players.PlayerAdded:Connect(onPlayer)
end

function module.stop()
	for _, beam in pairs(beams) do
		if beam and beam.Parent then
			beam:Destroy()
		end
	end
	beams = {}
	for _, conns in pairs(charConns) do
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
	end
	charConns = {}
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
end

return module
]=]

sources["modules/esp_fov.lua"] = [=[
local S = _G.Parvus2.Shared
local RunService = S.RunService
local UIS = S.UIS

local module = {}
local aimbotFOV = Drawing.new("Circle")
local triggerFOV = Drawing.new("Circle")
local conn

aimbotFOV.Visible = false
triggerFOV.Visible = false

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	aimbotFOV.Visible = false
	triggerFOV.Visible = false
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local mousePos = UIS:GetMouseLocation()
		local filled = Toggles.FOVFilled.Value
		local thickness = Options.FOVThickness.Value
		local sides = Options.FOVSides.Value

		if Toggles.AimbotEnabled.Value and Options.AimbotFOV.Value > 0 and Toggles.FOVAimbotVisible.Value then
			aimbotFOV.Position = mousePos
			aimbotFOV.Radius = Options.AimbotFOV.Value
			aimbotFOV.Color = Options.FOVAimbotColor.Value
			aimbotFOV.Thickness = thickness
			aimbotFOV.Filled = filled
			aimbotFOV.NumSides = sides
			aimbotFOV.Visible = true
		else
			aimbotFOV.Visible = false
		end

		if Toggles.TriggerEnabled.Value and Options.TriggerFOV.Value > 0 and Toggles.FOVTriggerVisible.Value then
			triggerFOV.Position = mousePos
			triggerFOV.Radius = Options.TriggerFOV.Value
			triggerFOV.Color = Options.FOVTriggerColor.Value
			triggerFOV.Thickness = thickness
			triggerFOV.Filled = filled
			triggerFOV.NumSides = sides
			triggerFOV.Visible = true
		else
			triggerFOV.Visible = false
		end
	end)
end

return module
]=]

sources["modules/aimbot_legit.lua"] = [=[
local S = _G.Parvus2.Shared
local T = _G.Parvus2.Targeting
local RunService = S.RunService
local UIS = S.UIS

local module = {}
local conn

local bodyParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.AimbotEnabled.Value
		if not enabled then return end

		local alwaysOn = Toggles.AimbotAlwaysOn.Value
		if not (alwaysOn or S.RMBHeld) then return end

		local hit = T.GetClosest(true,
			Toggles.AimbotTeamCheck.Value,
			Toggles.AimbotVisibilityCheck.Value,
			Toggles.AimbotDistanceCheck.Value,
			Options.AimbotDistanceLimit.Value,
			Options.AimbotFOV.Value,
			Options.AimbotPriority.Value,
			bodyParts,
			Toggles.AimbotPrediction.Value,
			Options.PredictionProjectileSpeed.Value,
			Options.PredictionGravity.Value,
			Options.PredictionGravityCorrection.Value
		)

		if not hit then return end

		local mouseLoc = UIS:GetMouseLocation()
		local sensitivity = Options.AimbotSensitivity.Value / 100
		local dx = (hit[4].X - mouseLoc.X) * sensitivity
		local dy = (hit[4].Y - mouseLoc.Y) * sensitivity
		S.mousemoverel(dx, dy)
	end)
end

return module
]=]

sources["modules/trigger_bot.lua"] = [=[
local S = _G.Parvus2.Shared
local T = _G.Parvus2.Targeting
local RunService = S.RunService

local module = {}
local conn
local busy = false

local bodyParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	busy = false
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		local enabled = Toggles.TriggerEnabled.Value
		if not enabled then return end

		local alwaysOn = Toggles.TriggerAlwaysOn.Value
		if not (alwaysOn or S.RMBHeld) then return end

		if busy then return end

		local hit = T.GetClosest(true,
			Toggles.TriggerTeamCheck.Value,
			Toggles.TriggerVisibilityCheck.Value,
			Toggles.TriggerDistanceCheck.Value,
			Options.TriggerDistanceLimit.Value,
			Options.TriggerFOV.Value,
			Options.TriggerPriority.Value,
			bodyParts,
			Toggles.TriggerPrediction.Value,
			Options.PredictionProjectileSpeed.Value,
			Options.PredictionGravity.Value,
			Options.PredictionGravityCorrection.Value
		)

		if not hit then return end

		busy = true
		local delay = Options.TriggerDelay.Value / 1000
		task.spawn(function()
			task.wait(delay)
			if not enabled then
				busy = false
				return
			end
			S.mouse1press()
			if Toggles.TriggerHoldMouse.Value then
				while enabled and (alwaysOn or S.RMBHeld) do
					local again = T.GetClosest(true,
						Toggles.TriggerTeamCheck.Value,
						Toggles.TriggerVisibilityCheck.Value,
						Toggles.TriggerDistanceCheck.Value,
						Options.TriggerDistanceLimit.Value,
						Options.TriggerFOV.Value,
						Options.TriggerPriority.Value,
						bodyParts,
						Toggles.TriggerPrediction.Value,
						Options.PredictionProjectileSpeed.Value,
						Options.PredictionGravity.Value,
						Options.PredictionGravityCorrection.Value
					)
					if not again then break end
					RunService.RenderStepped:Wait()
				end
			end
			S.mouse1release()
			busy = false
		end)
	end)
end

return module
]=]

sources["modules/hitbox.lua"] = [=[
local S = _G.Parvus2.Shared
local Players = S.Players
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer

local module = {}
local conn

local DEFAULT_SIZE = Vector3.new(2, 2, 2)

local function resetAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Size = DEFAULT_SIZE
				hrp.Transparency = 0.9
				hrp.BrickColor = BrickColor.new("Really black")
				hrp.Material = Enum.Material.Neon
				hrp.CanCollide = true
			end
		end
	end
end

function module.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	resetAll()
end

function module.start()
	if conn then return end

	conn = RunService.RenderStepped:Connect(function()
		if not Toggles.HitboxEnabled.Value then return end

		local size = Vector3.new(Options.HitboxSize.Value, Options.HitboxSize.Value, Options.HitboxSize.Value)

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = plr.Character.HumanoidRootPart
				hrp.Size = size
				hrp.Transparency = 0.7
				hrp.BrickColor = BrickColor.new("Really black")
				hrp.Material = Enum.Material.Neon
				hrp.CanCollide = false
			end
		end
	end)
end

return module
]=]

sources["modules/movement.lua"] = [=[
local S = _G.Parvus2.Shared
local RunService = S.RunService
local LocalPlayer = S.LocalPlayer
local Mouse = S.Mouse
local Workspace = S.Workspace

local module = {}
local teleporting = false
local conn, charConn, mouseConn

local function getHumanoidRootPart()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function teleportToPosition(pos)
	if teleporting then return end
	local hrp = getHumanoidRootPart()
	if not hrp then return end

	teleporting = true
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	task.delay(0.1, function()
		teleporting = false
	end)
end

local function applyWalkSpeed()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = Options.MovementWalkSpeed.Value end
end

local function applyJumpPower()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = Options.MovementJumpPower.Value end
end

function module.stop()
	if conn then conn:Disconnect() conn = nil end
	if charConn then charConn:Disconnect() charConn = nil end
	if mouseConn then mouseConn:Disconnect() mouseConn = nil end
	teleporting = false
end

function module.start()
	if charConn then return end

	conn = RunService.RenderStepped:Connect(function()
		applyWalkSpeed()
		applyJumpPower()
	end)

	charConn = LocalPlayer.CharacterAdded:Connect(function()
		applyWalkSpeed()
		applyJumpPower()
		teleporting = false
	end)

	mouseConn = Mouse.Button1Down:Connect(function()
		if not Toggles.MovementClickTP.Value then return end
		local target = Mouse.Target
		if target and target:IsDescendantOf(Workspace) then
			teleportToPosition(Mouse.Hit.p)
		end
	end)
end

return module
]=]

local function loadLocal(path)
	local src = sources[path]
	if not src then
		error("[Parvus2] Embedded module not found: " .. path)
	end
	local fn, err = loadstring(src)
	if not fn then
		error("[Parvus2] " .. path .. ": " .. tostring(err))
	end
	return fn()
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Shared = loadLocal("shared.lua")
local Targeting = loadLocal("targeting.lua")(Shared)

_G.Parvus2 = {
	Shared = Shared,
	Targeting = Targeting,
}

local Window = Library:CreateWindow({
	Title = 'Parvus 2',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
})

local Tabs = {
	Combat = Window:AddTab('Combat'),
	Visuals = Window:AddTab('Visuals'),
	Movement = Window:AddTab('Movement'),
	Settings = Window:AddTab('Settings'),
}

local BuildMenu = loadLocal("menu.lua")
BuildMenu(Tabs)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder('Parvus2')
SaveManager:SetFolder('Parvus2')
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})

ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true

SaveManager:LoadAutoloadConfig()

local moduleFiles = {
	"modules/esp_fov",
	"modules/esp_skeleton",
	"modules/esp_3dbox",
	"modules/esp_chams",
	"modules/esp_arrows",
	"modules/esp_nametags",
	"modules/esp_radar",
	"modules/esp_aimviewer",
	"modules/aimbot_legit",
	"modules/trigger_bot",
	"modules/hitbox",
	"modules/movement",
}

local activeModules = {}

for _, name in ipairs(moduleFiles) do
	local ok, mod = pcall(function()
		return loadLocal(name .. ".lua")
	end)
	if ok and mod and mod.start then
		mod.start()
		table.insert(activeModules, mod)
	else
		warn("[Parvus2] Failed to load " .. name)
	end
end

Library:Notify('Parvus 2 loaded!', 3)

Library:OnUnload(function()
	for _, mod in ipairs(activeModules) do
		if mod.stop then
			pcall(mod.stop)
		end
	end
	_G.Parvus2 = nil
end)
