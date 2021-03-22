local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM
local LAM = E.Libs.LAM


--Lua functions
--WoW API / Variables

---------------------- EVENTS ----------------------
function NP:EffectApplied(event, ...)
    local sourceGUID, sourceName, destGUID, destName, spellId, value, quality, duration = ...
    self:UpdateElement_AbsorbBarByGUID(event, destGUID)
end
function NP:EffectUpdated(event, ...)
    local guid, spellId, value, duration = ...
    self:UpdateElement_AbsorbBarByGUID(event, guid)
end
function NP:EffectRemoved(event, ...)
    local guid, spellId = ...
    self:UpdateElement_AbsorbBarByGUID(event, guid)
end
--
function NP:AbsorbBar_HealthValueChangeCallback(frame, health, maxHealth)
    local event = "AbsorbBar_HealthValueChangeCallback"
    local guid = frame.guid
    self:UpdateElement_AbsorbBarByGUID(event, guid)
end
----------------------------------------------------

-- Find Nameplate
function NP:UpdateElement_AbsorbBarByGUID(event, destGUID)
    local frame = self:SearchForFrame(destGUID)
	if frame then
		if frame.UnitType ~= "ENEMY_NPC" and not self.GUIDList[destGUID] then
			self.GUIDList[destGUID] = {name = destName, unitType = frame.UnitType}
		end
		self:Update_AbsorbBar(frame)
	end
end

-- Absorb Update
function NP:Update_AbsorbBar(frame)
	if not frame.Health:IsShown() then return end
	if not self.db.absorbBars then return end

    local absorbBar = frame.AbsorbBar
    local healthBar = frame.Health

    local health = frame.oldHealthBar:GetValue()
	local _, maxHealth = frame.oldHealthBar:GetMinMaxValues()
	local myCurrentHealAbsorb = LAM.Unit_Total(frame.guid)
	--
    function CompactUnitFrameUtil_UpdateFillBar(self, frame, health, myCurrentHealAbsorb)
		local totalWidth, totalHeight = frame:GetSize();
		local amout = (health + myCurrentHealAbsorb) / maxHealth
		local barOffsetX = (health / maxHealth) * totalWidth
		local barOffsetXPercent = frame:GetWidth() * amout

		local barSize = barOffsetXPercent - barOffsetX
		if barSize + barOffsetX > totalWidth then
			barSize = totalWidth - barOffsetX
		end

		self:SetWidth(barSize)
		self:Show()
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

function NP:Configure_AbsorbBar(frame)
    local healthBar = frame.Health
    --local _w, _h = healthBar:GetWidth(), healthBar:GetHeight()
	local _w = self.db.units[frame.UnitType].health.width * (frame.currentScale or 1)
	local _h = self.db.units[frame.UnitType].health.height * (frame.currentScale or 1)

    -- Glowing spark
    frame.AbsorbBar.overAbsorbGlow:SetTexture(LSM:Fetch("background", "AbsorbSpark"))
    frame.AbsorbBar.overAbsorbGlow:SetBlendMode("ADD");
    frame.AbsorbBar.overAbsorbGlow:SetPoint("RIGHT", healthBar, "RIGHT", 6, 0)
    frame.AbsorbBar.overAbsorbGlow:SetSize(12, _h)
    -- Total absorb
    frame.AbsorbBar.totalAbsorb:SetTexture(LSM:Fetch("statusbar", self.db.statusbar)) -- same bar as health bar
    frame.AbsorbBar.totalAbsorb:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorb:SetSize(1, _h)
    -- Total absorb overlay
    frame.AbsorbBar.totalAbsorbOverlay:SetHorizTile(true)
    frame.AbsorbBar.totalAbsorbOverlay:SetTexture(LSM:Fetch("background", "AbsorbOverlay"), "MIRROR")
    frame.AbsorbBar.totalAbsorbOverlay:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.AbsorbBar.totalAbsorbOverlay:SetSize(1, _h)

end

function NP:ConstructElement_AbsorbBar(parent) -- ConstructElement_CutawayHealth
	local healthBar = parent.Health

	local absorbBar = CreateFrame("Frame", "$parentAbsorbBar", parent) -- cutawayHealth
	absorbBar:SetAllPoints(healthBar)
	--absorbBar:SetFrameLevel(healthBar:GetFrameLevel() - 1)

    -- Glowing spark
	absorbBar.overAbsorbGlow = absorbBar:CreateTexture(nil, "OVERLAY")
    absorbBar.overAbsorbGlow:Hide()
	-- Total absorb
	absorbBar.totalAbsorb = absorbBar:CreateTexture(nil, "BORDER")
    absorbBar.totalAbsorb:Hide()
	-- Total absorb overlay
	absorbBar.totalAbsorbOverlay = absorbBar:CreateTexture(nil, "ARTWORK")
	absorbBar.totalAbsorbOverlay:Hide()

    NP:RegisterHealthBarCallbacks(parent, NP.AbsorbBar_HealthValueChangeCallback)

	return absorbBar
end