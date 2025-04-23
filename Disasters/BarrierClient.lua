local getData = require(game.ReplicatedStorage.GetData)
TS = game:GetService("TweenService")
local barrier = game.ReplicatedStorage.Barrier:Clone()

game.ReplicatedStorage.RemoteEvents.Barrier.OnClientEvent:Connect(function(action, location, duration, radius)
	if action == "Enable" then
		barrier.Parent = workspace
	end
	if action == "Disable" then
		barrier.Parent = game.ReplicatedStorage
	end
	if action == "Move" then
		local stuff = barrier:GetChildren()
		for i = 1, #stuff do
			if stuff[i].Name ~= "Center" then
				local tweenPartInfo = TweenInfo.new(duration,Enum.EasingStyle.Linear)
				local tweeenPartData = {Scale = Vector3.new(radius,radius,radius)}
				local tweenPartSize = TS:Create(stuff[i].Mesh,tweenPartInfo,tweeenPartData)
				tweenPartSize:Play()
			end
		end
		local tweenCenterInfo = TweenInfo.new(duration,Enum.EasingStyle.Linear)
		local tweenCenterData = {CFrame = CFrame.new(location)}
		local tweenCenter = TS:Create(barrier.Center,tweenCenterInfo,tweenCenterData)
		tweenCenter:Play()
	end
end)

local myData = nil
repeat
	wait()
	myData = getData.getDataFromPlayer(game.Players.LocalPlayer)
until myData ~= nil and myData:FindFirstChild("inBarrier")

myData.inBarrier.Changed:Connect(function(newVal)
	if newVal == false then
		game.Players.LocalPlayer.PlayerScripts.SoundPlayer.PlaySound:Fire("Play","EnterBarrier", true)
		game.Lighting.ColorCorrection.TintColor = Color3.fromRGB(255,0,100)
		game.Lighting.ColorCorrection.Brightness = .22
	else
		game.Lighting.ColorCorrection.TintColor = Color3.fromRGB(255,255,255)
		game.Lighting.ColorCorrection.Brightness = .03
	end
end)
