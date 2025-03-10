local getData = require(game.ReplicatedStorage.GetData)
local tool = script.Parent



local function onActivated()
	local player = game.Players:GetPlayerFromCharacter(tool.Parent)
	local playerData = getData.getDataFromPlayer(player)
	local Hunger = playerData.Hunger

	if player then
		-- Example: Print a message when the tool is used
		print(player.Name .. " used the Mango!")

		local humanoid = tool.Parent:FindFirstChild("Humanoid")
		Hunger.Value = math.min(Hunger.Value + 10, 100)
		tool:Destroy()
	end
end

tool.Activated:Connect(onActivated)
