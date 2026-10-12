--!strict
-- Small display helpers shared by server messages and the HUD.

local Format = {}

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign = "-"
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- 125 -> "2:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
