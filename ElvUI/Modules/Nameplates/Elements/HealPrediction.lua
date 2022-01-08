local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM
local LHC = E.Libs.LHC

---------------------- EVENTS ----------------------
function NP:LHC_Heal_Update(event, casterGUID, spellID, bitType, endTime, ...)
    local listGUID = {...}
    for i=1, #listGUID do
        local destGUID = listGUID[i]
        self:UpdateElement_HealPredictionByGUID(event, destGUID, destName)
    end
end
--
function NP:HealPrediction_HealthValueChangeCallback(frame, health, maxHealth)
    local event = "HealPrediction_HealthValueChangeCallback"
    local guid = frame.guid
    self:UpdateElement_HealPredictionByGUID(event, guid)
end
----------------------------------------------------

-- Find Nameplate
function NP:UpdateElement_HealPredictionByGUID(event, destGUID, name)
    local frame = self:SearchForFrame(destGUID, nil, name)
	if frame then
		self:Update_HealPredictionBar(frame)
	end
end

-- Heal Prediction Update
function NP:Update_HealPredictionBar(frame)
    if frame.UnitType == "ENEMY_PLAYER" or frame.UnitType == "ENEMY_PLAYER_NPC" then return end
	if not self.db.healPrediction then return end
    if not frame.Health:IsShown() then return end

    local healPredictionBar = frame.HealPredictionBar
    local healthBar = frame.Health

    local health = frame.oldHealthBar:GetValue()
	local _, maxHealth = frame.oldHealthBar:GetMinMaxValues()
    local timeFrame = LHC.HealCommTimeframe and GetTime() + LHC.HealCommTimeframe or nil
	local myIncomingHeal  = LHC:GetHealAmount(frame.guid, LHC.ALL_HEALS, timeFrame, UnitGUID("player")) or 0
	local allIncomingHeal = LHC:GetHealAmount(frame.guid, LHC.ALL_HEALS, timeFrame) or 0
    local maxHealOverflowRatio =  1 + self.db.colors.healPrediction.maxOverflow;
    local maxOverflowHP = maxHealth * maxHealOverflowRatio
    local otherIncomingHeal = 0;

	--
    function CompactUnitFrameUtil_UpdateFillBar(self, frame, health, allIncHeal)
		local totalWidth, totalHeight = frame:GetSize();
		local amout = (health + allIncHeal) / maxHealth
		local barOffsetX = (health / maxOverflowHP) * totalWidth
		local barOffsetXPercent = frame:GetWidth() * amout

		local barSize = barOffsetXPercent - barOffsetX
		if barSize + barOffsetX > totalWidth then
			barSize = totalWidth - barOffsetX
		end

		self:SetWidth(barSize)
		self:Show()
	end
	--

    if ( health + allIncomingHeal > maxOverflowHP ) then
        allIncomingHeal = maxOverflowHP - health;
    end

    if ( allIncomingHeal < myIncomingHeal ) then
        myIncomingHeal = allIncomingHeal
    else
        otherIncomingHeal = allIncomingHeal - myIncomingHeal
    end

    if (allIncomingHeal > 0) then
        CompactUnitFrameUtil_UpdateFillBar(healPredictionBar.totalHealPrediction, healthBar, health, allIncomingHeal)
    else
        healPredictionBar.totalHealPrediction:Hide()
    end

end

function NP:Configure_HealPredictionBar(frame)
    if frame.UnitType == "ENEMY_PLAYER" or frame.UnitType == "ENEMY_PLAYER_NPC" then return end
	if not self.db.healPrediction then return end
    if not frame.Health:IsShown() then return end

    local healthBar = frame.Health
    --local _w, _h = healthBar:GetWidth(), healthBar:GetHeight()
	local _w = self.db.units[frame.UnitType].health.width * (frame.currentScale or 1)
	local _h = self.db.units[frame.UnitType].health.height * (frame.currentScale or 1)

    local c = self.db.colors.healPrediction

    -- Total Heal Prediction
    frame.HealPredictionBar.totalHealPrediction:SetTexture(LSM:Fetch("statusbar", self.db.statusbar)) -- same bar as health bar
    frame.HealPredictionBar.totalHealPrediction:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
    frame.HealPredictionBar.totalHealPrediction:SetSize(1, _h)
    frame.HealPredictionBar.totalHealPrediction:SetVertexColor(c.personal.r, c.personal.g, c.personal.b, c.personal.a)

end

function NP:ConstructElement_HealPredictionBar(parent)
	local healthBar = parent.Health

	local healPredictionBar = CreateFrame("Frame", "$parentHealPredictionBar", parent)
	healPredictionBar:SetAllPoints(healthBar)

	-- Total HealPrediction
	healPredictionBar.totalHealPrediction= healPredictionBar:CreateTexture(nil, "BORDER")
    healPredictionBar.totalHealPrediction:Hide()

    NP:RegisterHealthBarCallbacks(parent, NP.HealPrediction_HealthValueChangeCallback)

	return healPredictionBar
end