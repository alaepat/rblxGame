--!strict
-- Day / night lighting that follows the shift clock (TASKS #19). Pure: the
-- client (DayClock) applies the result to its own Lighting, so every player
-- sees their own restaurant's time of day.
--
-- `minute` is minutes since midnight on the shift clock (DayCycle.minuteAt);
-- nil means no shift is running, which keeps the normal afternoon look.

local Sky = {}

Sky.IDLE_CLOCK = 14.5 -- ClockTime while the restaurant is closed between days
Sky.DUSK_FROM = 18.0 -- night starts creeping in here (hour)
Sky.NIGHT_AT = 20.5 -- fully night from here

-- Returns ClockTime (hours) and a night factor 0 (day) .. 1 (night).
function Sky.at(minute: number?): (number, number)
	if not minute then
		return Sky.IDLE_CLOCK, 0
	end
	local hour = math.clamp(minute / 60, 0, 24)
	local night = math.clamp((hour - Sky.DUSK_FROM) / (Sky.NIGHT_AT - Sky.DUSK_FROM), 0, 1)
	return hour, night
end

return Sky
