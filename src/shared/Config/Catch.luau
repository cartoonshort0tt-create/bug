--!strict
-- Timing ring and catch tuning. Ring progress p runs 0 → 1 over `ringDuration`;
-- the player must swing while p is inside the green band.

return {
	ringDuration = 1.2, -- seconds
	green = { 0.55, 0.8 },
	perfect = { 0.64, 0.71 },
	tutorialGreen = { 0.35, 0.9 }, -- wider band for a player's first swings
	tutorialSwings = 10,

	-- Lag tolerance (see CatchService)
	graceSeconds = 0.08, -- added to each edge of the green band
	futureToleranceSeconds = 0.05, -- hitTime may be at most this far in the future
	staleBaseSeconds = 0.25, -- hitTime may be at most ping×2 + this in the past
	reachToleranceStuds = 4,

	baseSwingCooldown = 0.6, -- divided by the net's speed
	ringRequestCooldown = 0.25,
	bugLockSeconds = 2.5, -- how long a ring reserves a bug for one player

	perfectBonus = 0.2,
	variants = {
		{ name = "Shiny", chance = 1 / 500, mult = 5 },
		{ name = "Giant", chance = 1 / 50, mult = 2 },
		{ name = "Tiny", chance = 1 / 50, mult = 1.5 },
	},

	startingBagSize = 15,
	goldenLadybugAfterCatches = 5, -- the scripted first-session surprise

	comboPerfects = 5, -- perfect catches in a row for one combo stack
	comboLuckPerStack = 0.1,
	comboMaxStacks = 3,
	comboSeconds = 60,

	respawnDelay = { 8, 15 },

	-- Anti-cheat signal: flag a player whose perfect rate is above this after `perfectWatchSwings`.
	perfectWatchRate = 0.9,
	perfectWatchSwings = 200,
}
