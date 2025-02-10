local events = game.ReplicatedStorage:WaitForChild("Queue")["BindableEvents - Server"]

events.PlayerJoinedQueue.Event:Connect(function(room, playerNum)
	print('Someone has joined the queue room ' .. room.Name .. ". There are now " .. playerNum .. " players in the queue")
end)

events.PlayerLeftQueue.Event:Connect(function(room, playerNum)
	print('Someone has left the queue room ' .. room.Name  .. ". There are now " .. playerNum .. " players in the queue")
end)

events.QueueFull.Event:Connect(function(room)
	print("Queue Room " .. room.Name  .. " Has reached the maximum capacity")
end)

events.StartedTeleport.Event:Connect(function(room)
	print("Queue room " .. room.Name  .. " Has initiated a teleport to the specified place")
end)

events.TeleportEnded.Event:Connect(function(room)
	print("Queue room " .. room.Name  .. " Has been teleported to the specified place")
