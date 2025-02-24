-- Plane Crash Cutscene
-- @RyanRodrii (tile127)
-- 02/23/2025

print("Plane crash")

wait(2)

-- VARS
local plane = workspace:FindFirstChild("CutsceneTestingPlane")

-- REFS
local camera = workspace.CurrentCamera
local player = game.Players.LocalPlayer
local character = player.Character
local TextChatService = game:GetService("TextChatService")

-- POINTS
local wingA = plane:FindFirstChild("wingA", true)
local tail = plane:FindFirstChild("tail", true)
local pilot = plane:FindFirstChild("pilot", true)
local interiorA = plane:FindFirstChild("interiorA", true)

-- TEMPORARY TESTING SCRIPTS
local function testScript1 ()
	print("Test Script 1")
	camera.CameraType = Enum.CameraType.Scriptable
	
	camera.CFrame = wingA.CFrame
	wait(5)
	camera.CFrame = tail.CFrame + tail.CFrame.LookVector * 10
	wait(5)
	camera.CFrame = pilot.CFrame + pilot.CFrame.LookVector * 10
	wait(5)
	camera.CFrame = interiorA.CFrame + interiorA.CFrame.LookVector * 10
	wait(5)
	camera.CameraType = Enum.CameraType.Custom
end

-- TEMPORARY CHAT SCRIPT
local TextChatService = game:GetService("TextChatService")

TextChatService.OnIncomingMessage = function(message)
	if message.Status == Enum.TextChatMessageStatus.Success then
		print("Chatted")
		if message.Text:sub(1, #";cs1") == ";cs1" then
			testScript1()
		end
	end
end

--[[ Samson's code

local TS = game:GetService("TweenService")
wait(5)
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
wait(.1)
workspace.CurrentCamera.CFrame = workspace.CamSpot.CFrame
local tweenMoveInfo = TweenInfo.new(10, Enum.EasingStyle.Linear)
local tweenMoveData = {CFrame = workspace.CamSpot2.CFrame}
local tweenMove = TS:Create(workspace.CurrentCamera,tweenMoveInfo,tweenMoveData)
tweenMove:Play()
]]