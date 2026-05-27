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
