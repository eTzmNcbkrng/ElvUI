local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local LSM = E.Libs.LSM
local LAM = E.Libs.LAM

local _effectTrigger = false; -- in case healthBar.PostUpdate trigger to fast the absorb function

--Lua functions
--WoW API / Variables

---------------------- EVENTS ----------------------
function UF:EffectApplied(event, ...)
    local sourceGUID, sourceName, destGUID, destName, spellId, value, quality, duration = ...
    _effectTrigger = true;
end
function UF:EffectUpdated(event, ...)
    local guid, spellId, value, duration = ...
	_effectTrigger = true;
end
function UF:EffectRemoved(event, ...)
    local guid, spellId = ...
	_effectTrigger = true;
end
----------------------------------------------------

-- Absorb Update everytime health change
local function Absorb_PostUpdate(self, unit, curHealth, maxHealth)

	if not _effectTrigger then return end

    local guid = UnitGUID(unit)
    if guid == nil then return end

    local health
    local mxHealth
    local _frame = self:GetParent()
    local absorbBar = _frame.AbsorbBar
    local healthBar = _frame.Health
	if absorbBar == nil then return end -- idk sometimes changing target to new player return nil ?
	if healthBar == nil then return end
	local myCurrentHealAbsorb = LAM.Unit_Total(guid)

    if curHealth then
        health = curHealth
        mxHealth = maxHealth
    else
        health = healthBar:GetValue()
        local _, MH = healthBar:GetMinMaxValues()
        mxHealth = MH
    end

	--print(unit, health, mxHealth, myCurrentHealAbsorb)

	--
    function CompactUnitFrameUtil_UpdateFillBar(selfFrame, frame, _health, _maxHealth, myCurrentHealAbsorb)
		local totalWidth, totalHeight = frame:GetSize();
		local amout = (_health + myCurrentHealAbsorb) / _maxHealth
		local barOffsetX = (_health / _maxHealth) * totalWidth
		local barOffsetXPercent = frame:GetWidth() * amout

		local barSize = barOffsetXPercent - barOffsetX
		if barSize + barOffsetX > totalWidth then
			barSize = totalWidth - barOffsetX
		end

		selfFrame:SetWidth(barSize)
		selfFrame:Show()
	end
	--

	if ( myCurrentHealAbsorb > 0 and health < mxHealth ) then
		CompactUnitFrameUtil_UpdateFillBar(absorbBar.totalAbsorb,        healthBar, health, mxHealth, myCurrentHealAbsorb)
		CompactUnitFrameUtil_UpdateFillBar(absorbBar.totalAbsorbOverlay, healthBar, health, mxHealth, myCurrentHealAbsorb)
	else
		absorbBar.totalAbsorb:Hide()
		absorbBar.totalAbsorbOverlay:Hide()
	end

	local overAbsorb = false;
	if ( health - myCurrentHealAbsorb > mxHealth or health + myCurrentHealAbsorb > mxHealth ) then
		overAbsorb = true;
		myCurrentHealAbsorb = max(0, mxHealth - health);
	end

	if ( overAbsorb ) then
		absorbBar.overAbsorbGlow:Show();
	else
		absorbBar.overAbsorbGlow:Hide();
	end

end
-- Absorb Update everytime new aura is triggered
local function handleNewAura(...)
	local parentFrame, unit, auraIconFrame, _, _, duration, expirationTime, type, _ = ...
	Absorb_PostUpdate(parentFrame, unit)
end
----------------------------------------------------

function UF:Configure_AbsorbBar(frame)
	if not frame.VARIABLES_SET then return end
    local healthBar = frame.Health
    local absorbBar = frame.AbsorbBar
	local db = frame.db

    -- Glowing spark
    frame.AbsorbBar.overAbsorbGlow:SetTexture(LSM:Fetch("background", "AbsorbSpark"))
    frame.AbsorbBar.overAbsorbGlow:SetBlendMode("ADD");
    frame.AbsorbBar.overAbsorbGlow:SetPoint("RIGHT", healthBar, "RIGHT", 6, 0)
    frame.AbsorbBar.overAbsorbGlow:SetSize(12, healthBar.HEIGHT)
    -- Total absorb
    frame.AbsorbBar.totalAbsorb:SetTexture(LSM:Fetch("statusbar", self.db.statusbar)) -- same bar as health bar
    frame.AbsorbBar.totalAbsorb:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorb:SetSize(25, healthBar.HEIGHT)
    -- Total absorb overlay
    frame.AbsorbBar.totalAbsorbOverlay:SetHorizTile(true)
    frame.AbsorbBar.totalAbsorbOverlay:SetTexture(LSM:Fetch("background", "AbsorbOverlay"), "MIRROR")
    frame.AbsorbBar.totalAbsorbOverlay:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorbOverlay:SetSize(25, healthBar.HEIGHT)

    -- EVENT registering
	if( frame.db and frame.db.absorb and frame.db.absorb.enabled ) then
		if healthBar.PostUpdate and not frame.AbsorbBar.hookedHealthBar then
			hooksecurefunc(healthBar, "PostUpdate", Absorb_PostUpdate)
			frame.AbsorbBar.hookedHealthBar = true
		end
		--[[ if frame.Buffs.PostUpdateIcon and not frame.AbsorbBar.hookedAura then
			hooksecurefunc(frame.Buffs, "PostUpdateIcon", handleNewAura)
			frame.AbsorbBar.hookedAura = true
		end ]]
		-- postUpdateIcon doesnt trigger when an aura has been removed, so we fallback with this until I find smth else
		if( not frame.AbsorbBar.hookedAura ) then
				frame.AbsorbBar:SetScript("OnEvent", function(_self, event, unit)
					if event == "UNIT_AURA" then
						local parent = _self:GetParent()
						if parent.unit == unit then
							Absorb_PostUpdate(_self, unit)
						end
					end
				end)
			frame.AbsorbBar:RegisterEvent("UNIT_AURA")
			frame.AbsorbBar.hookedAura = true
		end
	end

end


function UF:Construct_AbsorbBar(parent) -- ConstructElement_CutawayHealth
	local healthBar = parent.Health

	local absorbBar = CreateFrame("Frame", "$parentAbsorbBar", parent) -- cutawayHealth
	absorbBar:SetAllPoints(healthBar)
    absorbBar:SetFrameLevel(11)

    -- Glowing spark
	absorbBar.overAbsorbGlow = absorbBar:CreateTexture(nil, "OVERLAY")
    absorbBar.overAbsorbGlow:Hide()
	-- Total absorb
	absorbBar.totalAbsorb = absorbBar:CreateTexture(nil, "BORDER")
    absorbBar.totalAbsorb:Hide()
	-- Total absorb overlay
	absorbBar.totalAbsorbOverlay = absorbBar:CreateTexture(nil, "ARTWORK")
	absorbBar.totalAbsorbOverlay:Hide()

	return absorbBar
end