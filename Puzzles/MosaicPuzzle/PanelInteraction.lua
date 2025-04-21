local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local remote = game.Workspace.MosaicPuzzle:WaitForChild("PanelEvent")

local holdingPanel = nil

remote.OnClientEvent:Connect(function(action, panel)
	if action == "Hold" then
		holdingPanel = panel
	elseif action == "Release" then
		holdingPanel = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Send request to server
	if holdingPanel == nil then
		for _, panel in ipairs(game.Workspace.MosaicPuzzle.MosaicPuzzle.Model.Panels:GetChildren()) do
			local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function()
					if not holdingPanel then
						-- Tell server we want to pick up THIS panel
						remote:FireServer("Pickup", panel)
					end
				end)
			end
		end
	else
		if input.KeyCode == Enum.KeyCode.Q then
			-- drop
			remote:FireServer("Drop", holdingPanel)
			holdingPanel = nil
		end
	end
end)
