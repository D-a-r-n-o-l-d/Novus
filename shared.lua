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
