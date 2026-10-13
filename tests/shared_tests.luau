-- Tests for the pure shared modules. Run with: python3 tools/run_tests.py
-- `Shared` and `require` are provided by the runner.

local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Run = require(Shared.Run)

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok    " .. name)
	else
		failed += 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", what, tostring(b), tostring(a)), 2)
	end
end

local CD = 3

print("Doing Nothing shared tests")

test("sit starts a countdown; the countdown is not counted", function()
	local s = Run.sit(Run.new(), 100, CD)
	eq(s.phase, "countdown", "phase")
	eq(Run.elapsed(s, 102), 0, "elapsed during countdown")
	s = Run.tick(s, 102.9)
	eq(s.phase, "countdown", "still counting down")
	s = Run.tick(s, 103)
	eq(s.phase, "running", "running")
	eq(Run.elapsed(s, 163), 60, "elapsed after 60 s")
end)

test("any input while running loses and freezes the time", function()
	local s = Run.tick(Run.sit(Run.new(), 0, CD), 3)
	local lost, finished = Run.moved(s, 3603, CD)
	eq(lost.phase, "lost", "phase")
	eq(finished, 3600, "finished time")
	eq(Run.elapsed(lost, 99999), 3600, "frozen")
end)

test("input during the countdown just restarts the countdown", function()
	local s = Run.sit(Run.new(), 0, CD)
	local s2, finished = Run.moved(s, 2, CD)
	eq(s2.phase, "countdown", "phase")
	eq(s2.countdownEndsAt, 5, "new end")
	eq(finished, nil, "no finished time")
end)

test("standing up while running loses; during countdown goes idle", function()
	local running = Run.tick(Run.sit(Run.new(), 0, CD), 3)
	local lost, finished = Run.stand(running, 13)
	eq(lost.phase, "lost", "lost")
	eq(finished, 10, "finished")
	local idle = Run.stand(Run.sit(Run.new(), 0, CD), 1)
	eq(idle.phase, "idle", "idle")
end)

test("continue resumes from the lost time and counts the continue", function()
	local lost = Run.moved(Run.tick(Run.sit(Run.new(), 0, CD), 3), 103, CD)
	eq(Run.nextContinueStep(lost), 1, "first continue is step 1")
	local c = Run.continue(lost, 200, true, CD)
	eq(c.phase, "countdown", "countdown")
	eq(c.continues, 1, "continues")
	c = Run.tick(c, 203)
	eq(Run.elapsed(c, 213), 110, "100 banked + 10")
	local lost2 = Run.moved(c, 213, CD)
	eq(Run.nextContinueStep(lost2), 2, "second continue is step 2")
end)

test("restart resets time and the continue price", function()
	local lost = Run.moved(Run.tick(Run.sit(Run.new(), 0, CD), 3), 103, CD)
	local c = Run.tick(Run.continue(lost, 200, true, CD), 203)
	local lost2 = Run.moved(c, 303, CD)
	local r = Run.restart(lost2, 400, true, CD)
	eq(r.phase, "countdown", "countdown")
	eq(r.offset, 0, "offset")
	eq(r.continues, 0, "continues reset")
end)

test("sitting down while lost without choosing counts as restart", function()
	local lost = Run.moved(Run.tick(Run.sit(Run.new(), 0, CD), 3), 103, CD)
	local standing = Run.stand(lost, 104)
	eq(standing.phase, "lost", "still lost after standing")
	local s = Run.sit(standing, 110, CD)
	eq(s.offset, 0, "restart from 0")
	eq(s.continues, 0, "price reset")
end)

test("a paid continue waits if the player is not seated", function()
	local lost = Run.stand(Run.tick(Run.sit(Run.new(), 0, CD), 3), 53)
	local waiting = Run.continue(lost, 60, false, CD)
	eq(waiting.continueReady, true, "waiting")
	eq(Run.continue(waiting, 61, false, CD).continues, 1, "cannot pay twice")
	local s = Run.sit(waiting, 70, CD)
	eq(s.offset, 50, "resumes from 50")
	eq(s.continues, 1, "keeps continue count")
	-- standing during that countdown keeps the paid time waiting
	local again = Run.stand(s, 71)
	eq(again.continueReady, true, "still waiting")
	eq(again.lostTime, 50, "same time")
end)

test("resume banks time from another server", function()
	local s = Run.tick(Run.resume(1080 + 20, 2, 500, CD), 503)
	eq(Run.elapsed(s, 563), 1160, "banked + 60")
	eq(s.continues, 2, "continues carried over")
end)

test("continue prices double from 25, 15 steps", function()
	local p = Config.continueProducts
	eq(#p, 15, "steps")
	eq(p[1].price, 25, "step 1")
	eq(p[2].price, 50, "step 2")
	eq(p[4].price, 200, "step 4")
	eq(p[7].price, 1600, "step 7")
	eq(p[15].price, 409600, "step 15")
end)

test("distractions never mention Robux", function()
	for _, d in Config.distractions do
		if d.text then
			assert(not string.find(string.lower(d.text), "robux"), d.text)
		end
	end
end)

test("duration format", function()
	eq(Format.duration(0), "0:00", "0")
	eq(Format.duration(75), "1:15", "75")
	eq(Format.duration(3725), "1:02:05", "3725")
	eq(Format.duration(90061), "25:01:01", "25 h")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
