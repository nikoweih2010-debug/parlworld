local L = game:GetService("Lighting")
task.spawn(function()
	local t = 0
	while true do
		t += task.wait(0.5)
		local k = 0.5 - 0.5 * math.cos(t * (math.pi * 2 / 900))
		L.ClockTime = 8.2 + k * 9.6
	end
end)
