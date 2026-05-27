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
