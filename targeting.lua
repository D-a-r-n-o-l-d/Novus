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
