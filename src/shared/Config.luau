--!strict
-- Every number you might want to tune, in one place.

-- Continue prices double each continue in a run and reset to 25 on Restart.
-- Roblox products have fixed prices, so each price step is its own Developer Product.
-- Create them in Creator Hub (your experience > Monetization > Developer Products),
-- named "Continue 1" … "Continue 15" with the prices below, and paste each ID here.
-- While an ID is 0, that Continue is free in Studio (for testing) and unavailable live.
local CONTINUE_PRODUCTS: { { price: number, productId: number } } = {}
for step = 1, 15 do
	table.insert(CONTINUE_PRODUCTS, { price = 25 * 2 ^ (step - 1), productId = 0 })
end

export type Distraction = {
	at: number?, -- seconds into the run; nil = random
	kind: "note" | "fly" | "button" | "lights" | "cat" | "sound" | "banner",
	text: string?,
	soundId: string?, -- "rbxassetid://..." (leave empty to skip the sound)
	duration: number,
}

-- Distractions while a player is doing nothing. They are tricks inside the game's own
-- style: never a copy of Roblox's interface, never about Robux, never on the lost screen.
local DISTRACTIONS: { Distraction } = {
	{ at = 30, kind = "note", text = "PRESS SPACE TO KEEP YOUR TIMER", duration = 12 },
	{ at = 60, kind = "fly", duration = 15 },
	{ at = 120, kind = "sound", text = "*phone ringing*", soundId = "", duration = 8 },
	{ at = 300, kind = "note", text = "Your mouse fell asleep. Wiggle it to wake it up.", duration = 15 },
	{ at = 600, kind = "lights", duration = 10 },
	{ at = 900, kind = "cat", duration = 20 },
	{ at = 1800, kind = "button", text = "DO NOT PRESS", duration = 60 },
	{ at = 3600, kind = "banner", text = "ONE HOUR. NOBODY IS PROUD OF YOU.", duration = 15 },
	{ kind = "sound", text = "*knock knock*", soundId = "", duration = 6 },
	{ kind = "note", text = "Click here to claim your trophy", duration = 12 },
	{ kind = "banner", text = "Hey! HEY! Are you still there?", duration = 8 },
	{ kind = "fly", duration = 12 },
}

return {
	continueProducts = CONTINUE_PRODUCTS,

	booths = 20, -- set Max Players in Game Settings to match
	countdownSeconds = 3, -- "Hands off!" countdown after sitting; not counted

	-- Roblox disconnects players after about 20 minutes with no input. Just before
	-- that, the server re-joins the player to this place and the run carries on.
	idleRefreshSeconds = 18 * 60,
	resumeWindowSeconds = 5 * 60, -- how long a saved run waits for the player to arrive

	boardSize = 10,
	boardRefreshSeconds = 60, -- all-time rankings (DataStore limits)
	liveRefreshSeconds = 5, -- live sitters shared across servers

	-- Ignore tiny gamepad stick drift; any mouse, key, click or touch always counts.
	gamepadDeadzone = 0.2,

	distractions = DISTRACTIONS,
	randomDistractionEvery = { 90, 240 }, -- seconds between random distractions
}
