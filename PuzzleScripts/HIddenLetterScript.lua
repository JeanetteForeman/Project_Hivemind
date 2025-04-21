local lantern = game.Workspace.TerminalPuzzle:WaitForChild("Lantern")
local revealPart = script.Parent
local light = lantern.Emitter:FindFirstChildWhichIsA("PointLight")

local revealDistance = 12 -- adjust based on your room size

game:GetService("RunService").Heartbeat:Connect(function()
	if lantern and revealPart then
		local distance = (lantern.PrimaryPart.Position - revealPart.Position).Magnitude
		if distance <= revealDistance then
			revealPart.SurfaceGui.D.TextTransparency = 0 -- make visible
		else
			revealPart.SurfaceGui.D.TextTransparency = 1 -- hide again
		end
	end
end)
