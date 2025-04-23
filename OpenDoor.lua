local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OpenDoorEvent = ReplicatedStorage.RemoteEvents:WaitForChild("OpenDoor")

OpenDoorEvent.OnServerEvent:Connect(function(player, door)
	if door:IsA("Model") and door.PrimaryPart then
		-- Rotate the entire model 90 degrees around its pivot (which is already set to the hinge)
		local currentPivot = door:GetPivot()
		local targetCFrame = currentPivot * CFrame.Angles(0, math.rad(-90), 0)

		door:PivotTo(targetCFrame)

		print("Door rotated from the hinge:", door.Name)
	else
		warn("Invalid door model or missing PrimaryPart.")
	end
end)
