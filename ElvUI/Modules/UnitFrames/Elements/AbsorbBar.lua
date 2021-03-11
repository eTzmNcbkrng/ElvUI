local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local LSM = E.Libs.LSM
local LAM = E.Libs.LAM

--Lua functions
--WoW API / Variables

---------------------- EVENTS ----------------------
--[[ function UF:EffectApplied(event, ...)
    local sourceGUID, sourceName, destGUID, destName, spellId, value, quality, duration = ...
    --self:UpdateElement_AbsorbBarByGUID(event, destGUID)
    for unit in pairs(self.units) do
			--print(unit)
            if self[unit] then
                DevTools_Dump(self[unit].AbsorbBar)
            end

	end

    --print(event)
    --print(...)
end
function UF:EffectUpdated(event, ...)
    local guid, spellId, value, duration = ...
    --self:UpdateElement_AbsorbBarByGUID(event, guid)
    print("Updated")
end
function UF:EffectRemoved(event, ...)
    local guid, spellId = ...
    --self:UpdateElement_AbsorbBarByGUID(event, guid)
    print("Removed")
end ]]
----------------------------------------------------

-- Absorb Update
function UF:Update_AbsorbBar(frame, unit)

    local absorbBar = frame.AbsorbBar
    local healthBar = frame.Health

    local _unit
    if unit then -- we pass it only for party 1,2...
        _unit = unit
    else
        _unit = frame.unitframeType
    end
    local guid = UnitGUID(_unit)

    local health = healthBar:GetValue()
	local _, maxHealth = healthBar:GetMinMaxValues()
	local myCurrentHealAbsorb = LAM.Unit_Total(guid)
    --print(_unit.." | "..myCurrentHealAbsorb)
	--
    function CompactUnitFrameUtil_UpdateFillBar(selfFrame, frame, health, myCurrentHealAbsorb)
		local totalWidth, totalHeight = frame:GetSize();
		local amout = (health + myCurrentHealAbsorb) / maxHealth
		local barOffsetX = (health / maxHealth) * totalWidth
		local barOffsetXPercent = frame:GetWidth() * amout

		local barSize = barOffsetXPercent - barOffsetX
		if barSize + barOffsetX > totalWidth then
			barSize = totalWidth - barOffsetX
		end

		selfFrame:SetWidth(barSize)
		selfFrame:Show()
	end
	--

	if ( myCurrentHealAbsorb > 0 and health < maxHealth ) then
		CompactUnitFrameUtil_UpdateFillBar(absorbBar.totalAbsorb,        healthBar, health, myCurrentHealAbsorb)
		CompactUnitFrameUtil_UpdateFillBar(absorbBar.totalAbsorbOverlay, healthBar, health, myCurrentHealAbsorb)
	else
		absorbBar.totalAbsorb:Hide()
		absorbBar.totalAbsorbOverlay:Hide()
	end

	local overAbsorb = false;
	if ( health - myCurrentHealAbsorb  > maxHealth  or  health + myCurrentHealAbsorb > maxHealth ) then
		overAbsorb = true;
		myCurrentHealAbsorb = max(0, maxHealth - health);
	end

	if ( overAbsorb ) then
		absorbBar.overAbsorbGlow:Show();
	else
		absorbBar.overAbsorbGlow:Hide();
	end

end

----------------------------------------------------

function UF:Configure_AbsorbBar(frame)
    local healthBar = frame.Health
	local db = frame.db
    --local _w, _h = healthBar:GetWidth(), healthBar:GetHeight()
    local _w, _h = db.width, db.height
    _w = _w - (frame.BORDER + frame.SPACING + (frame.HAPPINESS_WIDTH or 0)) - (frame.BORDER + frame.SPACING + frame.PORTRAIT_WIDTH)
    _h = _h - (frame.BORDER + frame.SPACING + frame.CLASSBAR_YOFFSET) - (frame.BORDER + frame.SPACING + frame.BOTTOM_OFFSET)

    -- Glowing spark
    frame.AbsorbBar.overAbsorbGlow:SetTexture([[Interface\AddOns\ElvUI\Media\Textures\RaidFrame\Shield-Overshield]])
    frame.AbsorbBar.overAbsorbGlow:SetBlendMode("ADD");
    frame.AbsorbBar.overAbsorbGlow:SetPoint("RIGHT", healthBar, "RIGHT", 6, 0)
    frame.AbsorbBar.overAbsorbGlow:SetSize(12, _h)
    -- Total absorb
    frame.AbsorbBar.totalAbsorb:SetTexture(LSM:Fetch("statusbar", self.db.statusbar)) -- same bar as health bar
    frame.AbsorbBar.totalAbsorb:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorb:SetSize(25, _h)
    -- Total absorb overlay
    frame.AbsorbBar.totalAbsorbOverlay:SetHorizTile(true)
    frame.AbsorbBar.totalAbsorbOverlay:SetTexture([[Interface\AddOns\ElvUI\Media\Textures\RaidFrame\Shield-Overlay]], "MIRROR")
    frame.AbsorbBar.totalAbsorbOverlay:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorbOverlay:SetSize(25, _h)

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