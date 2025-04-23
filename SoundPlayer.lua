local getData = require(game.ReplicatedStorage.GetData)
local playerData = getData.getDataFromPlayer(game.Players.LocalPlayer)
repeat
	wait()
	playerData = getData.getDataFromPlayer(game.Players.LocalPlayer)
until playerData ~= nil

local TS = game:GetService("TweenService")

audios = script:GetChildren()
fadeIns = {}
fadeOuts = {}

for i = 1, #audios do
	if audios[i].ClassName == "Sound" then
		local FadeInInfo = TweenInfo.new(2.8,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
		local FadeInData = {Volume = audios[i].Volume}
		fadeIns[audios[i]] = TS:Create(audios[i],FadeInInfo,FadeInData)
	end
end
for i = 1, #audios do
	if audios[i].ClassName == "Sound" then
		local FadeOutInfo = TweenInfo.new(2.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
		local FadeOutData = {Volume = 0}
		fadeOuts[audios[i]] = TS:Create(audios[i],FadeOutInfo,FadeOutData)
	end
end

function playSound(mode, music, deleteAfter, tp)
	if mode == "Play" then
		if deleteAfter == true then
			local sound = script[music]:Clone()
			sound.Parent = script
			if tp then
				sound.TimePosition = tp
			end
			sound:Play()
			sound.Deleter.Disabled = false
			return
		end
		if tp then
			script[music].TimePosition = tp
		end
		script[music]:Play()
	end

	if mode == "FadeIn" then
		script[music].Volume = 0
		script[music]:Play()
		wait()
		fadeIns[script[music]]:Play()
	end

	if mode == "Stop" then
		script[music]:Stop()
	end

	if mode == "FadeOut" then
		local ogVolume = script[music].Volume
		fadeOuts[script[music]]:Play()
		wait(2.8)
		script[music]:Stop()
		script[music].Volume = ogVolume
	end
end

game.ReplicatedStorage.RemoteEvents.PlaySound.OnClientEvent:Connect(function(mode, music, deleteAfter, tp)
	playSound(mode, music, deleteAfter, tp)
end)

script.PlaySound.Event:Connect(function(mode, music, deleteAfter, tp)
	playSound(mode, music, deleteAfter, tp)
end)
