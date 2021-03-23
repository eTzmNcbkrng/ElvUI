local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
--WoW API / Variables

function NP:Update_Number(frame)
	if not self.db.units[frame.UnitType].number or not self.db.units[frame.UnitType].number.enable then return end
	if not frame.unit then return end
	if not UnitIsPlayer(frame.unit) then return end

    local db = self.db.units[frame.UnitType].number
    local number = frame.Number

	number:ClearAllPoints()
    number:SetJustifyH("RIGHT")
    number:SetPoint("BOTTOMRIGHT", frame.Health, "TOPRIGHT", db.offsetX, E.Border*2 + db.offsetY)

    for i=1, 25 do
        if UnitIsUnit(frame.unit, "arena"..i) or UnitIsUnit(frame.unit, "party"..i) or UnitIsUnit(frame.unit, "raid"..i) then
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