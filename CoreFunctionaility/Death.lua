local TPS = game:GetService("TeleportService")
local getData = require(game.ReplicatedStorage.GetData)
script.addPlayer.Event:Connect(function(player)
	local playerData = getData.getDataFromPlayer(player)
	playerData.Health.Changed:Connect(function(newVal)
		if newVal <= 0 then
			TPS:Teleport(80117807799605, player)
		end
	end)
end)
