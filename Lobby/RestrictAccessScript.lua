local ACCESS_RESTRICTED = true

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local blackScreen = playerGui:WaitForChild("BlackScreen")
local kickAudio = blackScreen.kickSound

if (ACCESS_RESTRICTED) then
	if player:GetRankInGroup(35534503) < 4 then
		blackScreen.Enabled = true
		blackScreen.Frame.Visible = true
		wait(1)
		kickAudio:Play()
		player:Kick("Access limited to group testers only")
	end
	
end