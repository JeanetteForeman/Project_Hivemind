local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")



-- CHANGE THIS WHEN ITS MOVED INTO THE TERMINAL MODEL
local lanternEvent = game.Workspace.Lantern:WaitForChild("LanternEvent")




local holdingLantern = nil

-- Listen for proximity prompt


-- CHANGE THIS WHEN MOVED INTO TERMINAL MODEL
local lantern = game.Workspace.Lantern

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if holdingLantern == nil then
		if lantern:IsA("Model") and lantern.Name == "Lantern" then
			holdingLantern = lantern
			local prompt = game.Workspace.Lantern:WaitForChild("Handle"):FindFirstChild("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function()
					lanternEvent:FireServer("Pickup", lantern)
				end)
			end
		end
	else
		if input.KeyCode == Enum.KeyCode.Q then
			lanternEvent:FireServer("Drop", holdingLantern)
			holdingLantern = nil
		end
	end 
end)

---- Drop on Q press
--game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
--	if gameProcessed then return end
--	if input.KeyCode == Enum.KeyCode.Q and holdingLantern then
--		lanternEvent:FireServer("Drop", holdingLantern)
--	end
--end)

-- Listen for server updates
lanternEvent.OnClientEvent:Connect(function(action, lantern)
	if action == "Hold" then
		holdingLantern = lantern
	elseif action == "Release" then
		holdingLantern = nil
	end
end)
