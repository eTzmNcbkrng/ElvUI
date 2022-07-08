local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
--WoW API / Variables

function NP:Update_Number(frame)
	if not self.db.units[frame.UnitType] and self.db.units[frame.UnitType].number or not self.db.units[frame.UnitType].number.enable then return end
	if not frame.unit then return end
	if not UnitIsPlayer(frame.unit) then return end
    if not frame.Health:IsShown() then return end

    local db = self.db.units[frame.UnitType].number
    local number = frame.Number
    local nbrMembers = GetNumGroupMembers()
    local inInstance, instanceType = IsInInstance()

    if (IsInInstance and instanceType == "pvp" and db.disablePVP) then return end
    if (IsInInstance and instanceType == "arena" and db.disableArena) then return end
    if (IsInInstance and instanceType == "party" and db.disableParty) then return end
    if (IsInInstance and instanceType == "raid" and db.disableRaid) then return end

	number:ClearAllPoints()
    number:SetJustifyH(db.textAlign)
    number:SetPoint("LEFT", frame.Health, "RIGHT", db.offsetX, db.offsetY)

    for i=1, nbrMembers do
        if UnitIsUnit(frame.unit, "arena"..i) or UnitIsUnit(frame.unit, "party"..i) or UnitIsUnit(frame.unit, "raid"..i)
        or UnitGUID("arena"..i) == frame.guid or UnitGUID("party"..i) == frame.guid or UnitGUID("raid"..i) == frame.guid then
            number:SetText(i)
            number:SetTextColor(db.unitColor.r, db.unitColor.g, db.unitColor.b)
        end
    end

end

function NP:Configure_Number(frame)
	local db = self.db.units[frame.UnitType].number
	frame.Number:FontTemplate(LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)
end

function NP:Construct_Number(frame)
	return frame:CreateFontString(nil, "OVERLAY")
end