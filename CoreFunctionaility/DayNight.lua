local TS = game:GetService("TweenService")

local dayDuration = 240
game.Lighting.ClockTime = 0

script.start.Event:Connect(function()
	while true do
		local tweenInfo = TweenInfo.new(dayDuration, Enum.EasingStyle.Linear)
		local tweenData = {ClockTime = 23.999}
		local tweenLighting = TS:Create(game.Lighting, tweenInfo, tweenData)
		tweenLighting:Play()
		wait(dayDuration)
		game.Lighting.ClockTime = 0
		wait()
	end
end)
