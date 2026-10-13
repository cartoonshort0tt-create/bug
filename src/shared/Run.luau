--!strict
-- The rules of a run, as pure functions (no Roblox APIs), so they can be tested.
--
--   idle ──sit──▶ countdown ──(3 s)──▶ running ──any input / stood up──▶ lost
--                   │ input: countdown restarts                          │
--                   └ stood up: back to idle            Restart (0:00) ◀─┤
--                                       Continue (from the lost time) ◀──┘
--
-- Sitting back down while lost, without choosing, counts as Restart.
-- `continues` is how many Continues this run has used; the next one costs step continues+1.

export type Phase = "idle" | "countdown" | "running" | "lost"

export type State = {
	phase: Phase,
	offset: number, -- seconds already banked (from a Continue or a resumed run)
	startedAt: number?, -- when the current running stretch began
	countdownEndsAt: number?,
	lostTime: number?, -- the time on the clock when the player lost
	continueReady: boolean, -- a paid Continue waiting for the player to sit back down
	continues: number,
}

local Run = {}

function Run.new(): State
	return {
		phase = "idle",
		offset = 0,
		startedAt = nil,
		countdownEndsAt = nil,
		lostTime = nil,
		continueReady = false,
		continues = 0,
	}
end

function Run.elapsed(s: State, now: number): number
	if s.phase == "running" then
		return s.offset + math.max(0, now - (s.startedAt :: number))
	elseif s.phase == "lost" then
		return s.lostTime or 0
	end
	return s.offset
end

local function countdown(offset: number, continues: number, now: number, seconds: number): State
	return {
		phase = "countdown",
		offset = offset,
		startedAt = nil,
		countdownEndsAt = now + seconds,
		lostTime = nil,
		continueReady = false,
		continues = continues,
	}
end

local function lose(s: State, now: number): State
	return {
		phase = "lost",
		offset = 0,
		startedAt = nil,
		countdownEndsAt = nil,
		lostTime = Run.elapsed(s, now),
		continueReady = false,
		continues = s.continues,
	}
end

-- Transitions that can end a run also return the finished time (for best-time records).

function Run.sit(s: State, now: number, seconds: number): State
	if s.phase == "idle" then
		return countdown(0, 0, now, seconds)
	elseif s.phase == "lost" then
		if s.continueReady then
			return countdown(s.lostTime or 0, s.continues, now, seconds)
		end
		return countdown(0, 0, now, seconds) -- sitting down without choosing = Restart
	end
	return s
end

function Run.stand(s: State, now: number): (State, number?)
	if s.phase == "countdown" then
		if s.offset > 0 then
			-- Standing during a Continue's countdown keeps the paid time waiting.
			local waiting = lose(s, now)
			waiting.continueReady = true
			return waiting, nil
		end
		return Run.new(), nil
	elseif s.phase == "running" then
		local lost = lose(s, now)
		return lost, lost.lostTime
	end
	return s, nil
end

function Run.moved(s: State, now: number, seconds: number): (State, number?)
	if s.phase == "running" then
		local lost = lose(s, now)
		return lost, lost.lostTime
	elseif s.phase == "countdown" then
		return countdown(s.offset, s.continues, now, seconds), nil
	end
	return s, nil
end

function Run.tick(s: State, now: number): State
	if s.phase == "countdown" and now >= (s.countdownEndsAt :: number) then
		return {
			phase = "running",
			offset = s.offset,
			startedAt = s.countdownEndsAt,
			countdownEndsAt = nil,
			lostTime = nil,
			continueReady = false,
			continues = s.continues,
		}
	end
	return s
end

function Run.restart(s: State, now: number, seated: boolean, seconds: number): State
	if s.phase ~= "lost" then
		return s
	end
	return if seated then countdown(0, 0, now, seconds) else Run.new()
end

-- Only call after a Continue was paid for.
function Run.continue(s: State, now: number, seated: boolean, seconds: number): State
	if s.phase ~= "lost" or s.continueReady then
		return s
	end
	if seated then
		return countdown(s.lostTime or 0, s.continues + 1, now, seconds)
	end
	local waiting = table.clone(s)
	waiting.continueReady = true
	waiting.continues = s.continues + 1
	return waiting
end

-- Which price step the next Continue costs (1 = the first, 25 Robux).
function Run.nextContinueStep(s: State): number
	return s.continues + 1
end

-- A run carried over from another server (the idle refresh): it resumes with a
-- countdown, banking the time so far plus the time spent re-joining.
function Run.resume(banked: number, continues: number, now: number, seconds: number): State
	return countdown(banked, continues, now, seconds)
end

return Run
