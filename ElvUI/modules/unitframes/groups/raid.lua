local E, L, V, P, G = unpack(select(2, ...));
local UF = E:GetModule("UnitFrames");

local pairs = pairs;
local tinsert = table.insert;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local IsInInstance = IsInInstance;
local GetInstanceInfo = GetInstanceInfo;
local UnregisterStateDriver = UnregisterStateDriver;
local RegisterStateDriver = RegisterStateDriver;

local _, ns = ...;
local ElvUF = ns.oUF;
assert(ElvUF, "ElvUI was unable to locate oUF.");

function UF:Construct_RaidFrames(unitGroup)
	self:SetScript("OnEnter", UnitFrame_OnEnter);
	self:SetScript("OnLeave", UnitFrame_OnLeave);
	
	self.RaisedElementParent = CreateFrame("Frame", nil, self);
	self.RaisedElementParent:SetFrameStrata("MEDIUM");
	self.RaisedElementParent:SetFrameLevel(self:GetFrameLevel() + 10);
	
	self:SetAttribute("initial-height", UF.db["units"]["raid"].height);
	self:SetAttribute("initial-width", UF.db["units"]["raid"].width);
	
	self.Health = UF:Construct_HealthBar(self, true, true, "RIGHT");
	self.Power = UF:Construct_PowerBar(self, true, true, "LEFT", false);
	self.Power.frequentUpdates = false;
	self.Name = UF:Construct_NameText(self);
	self.Buffs = UF:Construct_Buffs(self);
	self.Debuffs = UF:Construct_Debuffs(self);
	self.AuraWatch = UF:Construct_AuraWatch(self);
	self.RaidDebuffs = UF:Construct_RaidDebuffs(self);
	self.DebuffHighlight = UF:Construct_DebuffHighlight(self);
	self.RaidRoleFramesAnchor = UF:Construct_RaidRoleFrames(self);
	self.TargetGlow = UF:Construct_TargetGlow(self);
	tinsert(self.__elements, UF.UpdateTargetGlow);
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UF.UpdateTargetGlow);
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UF.UpdateTargetGlow);		
	
	self.Threat = UF:Construct_Threat(self);
	self.RaidIcon = UF:Construct_RaidIcon(self);
	self.ReadyCheck = UF:Construct_ReadyCheckIcon(self);
	self.Range = UF:Construct_Range(self);
	self.HealCommBar = UF:Construct_HealComm(self);
	self.GPS = UF:Construct_GPS(self);
	
	self.customTexts = {};
	UF:Update_StatusBars();
	UF:Update_FontStrings();
	UF:Update_RaidFrames(self, UF.db["units"]["raid"]);
	return self;
end


function UF:RaidSmartVisibility(event)
	if(not self.db or (self.db and not self.db.enable) or (UF.db and not UF.db.smartRaidFilter) or self.isForced) then
		self.blockVisibilityChanges = false;
		return;
	end
	
	if(event == "PLAYER_REGEN_ENABLED") then self:UnregisterEvent("PLAYER_REGEN_ENABLED"); end
	
	if(not InCombatLockdown()) then
		self.isInstanceForced = nil;
		local inInstance, instanceType = IsInInstance();
		if(inInstance and (instanceType == "raid" or instanceType == "pvp")) then
			local _, _, _, _, maxPlayers = GetInstanceInfo();
			local mapID = GetCurrentMapAreaID();
			if(UF.mapIDs[mapID]) then
				maxPlayers = UF.mapIDs[mapID];
			end
			
			UnregisterStateDriver(self, "visibility");
			
			if(maxPlayers < 40) then
				self:Show();
				self.isInstanceForced = true;
				self.blockVisibilityChanges = false;
				if(ElvUF_Raid.numGroups ~= E:Round(maxPlayers/5) and event) then
					UF:CreateAndUpdateHeaderGroup("raid");
				end
			else
				self:Hide();
				self.blockVisibilityChanges = true;
			end
		elseif(self.db.visibility) then
			RegisterStateDriver(self, "visibility", self.db.visibility);
			self.blockVisibilityChanges = false;
			if(ElvUF_Raid.numGroups ~= self.db.numGroups) then
				UF:CreateAndUpdateHeaderGroup("raid");
			end
		end
	else
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		return;
	end
end

function UF:Update_RaidHeader(header, db, isForced)
	header:GetParent().db = db;
	
	local headerHolder = header:GetParent();
	headerHolder.db = db;
	
	if(not headerHolder.positioned) then
		headerHolder:ClearAllPoints();
		headerHolder:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", 4, 195);
		
		E:CreateMover(headerHolder, headerHolder:GetName().."Mover", L["Raid Frames"], nil, nil, nil, "ALL,RAID");

		headerHolder:RegisterEvent("PLAYER_ENTERING_WORLD");
		headerHolder:RegisterEvent("ZONE_CHANGED_NEW_AREA");
		headerHolder:SetScript("OnEvent", UF["RaidSmartVisibility"]);
		headerHolder.positioned = true;
	end
	
	UF.RaidSmartVisibility(headerHolder);
end

function UF:Update_RaidFrames(frame, db)
	frame.db = db;
	local BORDER = E.Border;
	local SPACING = E.Spacing;
	local SHADOW_SPACING = SPACING+3;
	local UNIT_WIDTH = db.width;
	local UNIT_HEIGHT = db.height;
	
	local USE_POWERBAR = db.power.enable;
	local USE_MINI_POWERBAR = db.power.width == "spaced" and USE_POWERBAR;
	local USE_INSET_POWERBAR = db.power.width == "inset" and USE_POWERBAR;
	local USE_POWERBAR_OFFSET = db.power.offset ~= 0 and USE_POWERBAR;
	local POWERBAR_OFFSET = db.power.offset;
	local POWERBAR_HEIGHT = db.power.height;
	local POWERBAR_WIDTH = db.width - (BORDER*2);
	
	frame.db = db;
	frame.colors = ElvUF.colors;
	frame:RegisterForClicks(self.db.targetOnMouseDown and "AnyDown" or "AnyUp");
	
	frame.Range = {insideAlpha = 1, outsideAlpha = E.db.unitframe.OORAlpha};
	if(not frame:IsElementEnabled("Range")) then
		frame:EnableElement("Range");
	end
	
	do
		if(not USE_POWERBAR) then
			POWERBAR_HEIGHT = 0;
		end
		
		if(USE_MINI_POWERBAR) then
			POWERBAR_WIDTH = POWERBAR_WIDTH / 2;
		end
	end
	
	do
		local health = frame.Health;
		health.Smooth = self.db.smoothbars;
		health.frequentUpdates = db.health.frequentUpdates;
		
		local x, y = self:GetPositionOffset(db.health.position);
		health.value:ClearAllPoints();
		health.value:Point(db.health.position, health, db.health.position, x + db.health.xOffset, y + db.health.yOffset);
		frame:Tag(health.value, db.health.text_format);
		
		health.colorSmooth = nil;
		health.colorHealth = nil;
		health.colorClass = nil;
		health.colorReaction = nil;
		
		if(db.colorOverride == "FORCE_ON") then
			health.colorClass = true;
			health.colorReaction = true;
		elseif(db.colorOverride == "FORCE_OFF") then
			if(self.db["colors"].colorhealthbyvalue == true) then
				health.colorSmooth = true;
			else
				health.colorHealth = true;
			end
		else
			if(self.db["colors"].healthclass ~= true) then
				if(self.db["colors"].colorhealthbyvalue == true) then
					health.colorSmooth = true;
				else
					health.colorHealth = true;
				end
			else
				health.colorClass = (not self.db["colors"].forcehealthreaction);
				health.colorReaction = true;
			end
		end
		
		health:ClearAllPoints();
		health:Point("TOPRIGHT", frame, "TOPRIGHT", -BORDER, -BORDER);
		if(USE_POWERBAR_OFFSET) then
			health:Point("BOTTOMLEFT", frame, "BOTTOMLEFT", BORDER+POWERBAR_OFFSET, BORDER+POWERBAR_OFFSET);
		elseif(USE_MINI_POWERBAR) then
			health:Point("BOTTOMLEFT", frame, "BOTTOMLEFT", BORDER, BORDER + (POWERBAR_HEIGHT/2));
		elseif(USE_INSET_POWERBAR) then
			health:Point("BOTTOMLEFT", frame, "BOTTOMLEFT", BORDER, BORDER);
		else
			health:Point("BOTTOMLEFT", frame, "BOTTOMLEFT", BORDER, (USE_POWERBAR and ((BORDER + SPACING)*2) or BORDER) + POWERBAR_HEIGHT);
		end
		
		health:SetOrientation(db.health.orientation);
	end
	
	UF:UpdateNameSettings(frame);
	
	do
		local power = frame.Power;
		if USE_POWERBAR then
			frame:EnableElement("Power");
			power.Smooth = self.db.smoothbars;
			power:Show();
			
			local x, y = self:GetPositionOffset(db.power.position);
			power.value:ClearAllPoints();
			power.value:Point(db.power.position, frame.Health, db.power.position, x + db.power.xOffset, y + db.power.yOffset);		
			frame:Tag(power.value, db.power.text_format);
			
			power.colorClass = nil;
			power.colorReaction = nil;
			power.colorPower = nil;
			if(self.db["colors"].powerclass) then
				power.colorClass = true;
				power.colorReaction = true;
			else
				power.colorPower = true;
			end
			
			power:ClearAllPoints();
			if(USE_POWERBAR_OFFSET) then
				power:Point("TOPLEFT", frame.Health, "TOPLEFT", -POWERBAR_OFFSET, -POWERBAR_OFFSET);
				power:Point("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", -POWERBAR_OFFSET, -POWERBAR_OFFSET);
				power:SetFrameStrata("LOW");
				power:SetFrameLevel(2);
			elseif(USE_MINI_POWERBAR) then
				power:Width(POWERBAR_WIDTH - BORDER*2);
				power:Height(POWERBAR_HEIGHT);
				power:Point("LEFT", frame, "BOTTOMLEFT", (BORDER*2 + 4), BORDER + (POWERBAR_HEIGHT/2));
				power:SetFrameStrata("MEDIUM");
				power:SetFrameLevel(frame:GetFrameLevel() + 3);
			elseif(USE_INSET_POWERBAR) then
				power:Height(POWERBAR_HEIGHT);
				power:Point("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", BORDER + (BORDER*2), BORDER + (BORDER*2));
				power:Point("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", -(BORDER + (BORDER*2)), BORDER + (BORDER*2));
				power:SetFrameStrata("MEDIUM");
				power:SetFrameLevel(frame:GetFrameLevel() + 3);
			else
				power:Point("TOPLEFT", frame.Health.backdrop, "BOTTOMLEFT", BORDER, -SPACING*3);
				power:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(BORDER), BORDER);
			end
		else
			frame:DisableElement("Power");
			power:Hide();
		end
	end
	
	do
		local threat = frame.Threat;
		if(db.threatStyle ~= "NONE" and db.threatStyle ~= nil) then
			if(not frame:IsElementEnabled("Threat")) then
				frame:EnableElement("Threat");
			end
			
			if(db.threatStyle == "GLOW") then
				threat:SetFrameStrata("BACKGROUND");
				threat.glow:ClearAllPoints();
				threat.glow:SetBackdropBorderColor(0, 0, 0, 0);
				threat.glow:Point("TOPLEFT", frame.Health.backdrop, "TOPLEFT", -SHADOW_SPACING, SHADOW_SPACING);
				threat.glow:Point("TOPRIGHT", frame.Health.backdrop, "TOPRIGHT", SHADOW_SPACING, SHADOW_SPACING);
				threat.glow:Point("BOTTOMLEFT", frame.Power.backdrop, "BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING);
				threat.glow:Point("BOTTOMRIGHT", frame.Power.backdrop, "BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);	
				
				if(USE_MINI_POWERBAR or USE_POWERBAR_OFFSET or USE_INSET_POWERBAR) then
					threat.glow:Point("BOTTOMLEFT", frame.Health.backdrop, "BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING);
					threat.glow:Point("BOTTOMRIGHT", frame.Health.backdrop, "BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
				end
				
				if(USE_PORTRAIT and not USE_PORTRAIT_OVERLAY) then
					threat.glow:Point("TOPRIGHT", frame.Portrait.backdrop, "TOPRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
					threat.glow:Point("BOTTOMRIGHT", frame.Portrait.backdrop, "BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
				end
			elseif(db.threatStyle == "ICONTOPLEFT" or db.threatStyle == "ICONTOPRIGHT" or db.threatStyle == "ICONBOTTOMLEFT" or db.threatStyle == "ICONBOTTOMRIGHT" or db.threatStyle == "ICONTOP" or db.threatStyle == "ICONBOTTOM" or db.threatStyle == "ICONLEFT" or db.threatStyle == "ICONRIGHT") then
				threat:SetFrameStrata("HIGH");
				local point = db.threatStyle;
				point = point:gsub("ICON", "");
				
				threat.texIcon:ClearAllPoints();
				threat.texIcon:SetPoint(point, frame.Health, point);
			end
		elseif(frame:IsElementEnabled("Threat")) then
			frame:DisableElement("Threat");
		end
	end
	
	do
		local tGlow = frame.TargetGlow;
		tGlow:ClearAllPoints();
		tGlow:Point("TOPLEFT", -SHADOW_SPACING, SHADOW_SPACING);
		tGlow:Point("TOPRIGHT", SHADOW_SPACING, SHADOW_SPACING);
		
		if(USE_MINI_POWERBAR) then
			tGlow:Point("BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING + (POWERBAR_HEIGHT/2));
			tGlow:Point("BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING + (POWERBAR_HEIGHT/2));
		else
			tGlow:Point("BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING);
			tGlow:Point("BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
		end
		
		if(USE_POWERBAR_OFFSET) then
			tGlow:Point("TOPLEFT", -SHADOW_SPACING+POWERBAR_OFFSET, SHADOW_SPACING);
			tGlow:Point("TOPRIGHT", SHADOW_SPACING, SHADOW_SPACING);
			tGlow:Point("BOTTOMLEFT", -SHADOW_SPACING+POWERBAR_OFFSET, -SHADOW_SPACING+POWERBAR_OFFSET);
			tGlow:Point("BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING+POWERBAR_OFFSET);
		end
	end
	
	do
		if(db.debuffs.enable or db.buffs.enable) then
			if(not frame:IsElementEnabled("Aura")) then
				frame:EnableElement("Aura");
			end
		else
			if(frame:IsElementEnabled("Aura")) then
				frame:DisableElement("Aura");
			end
		end
		
		frame.Buffs:ClearAllPoints();
		frame.Debuffs:ClearAllPoints();
	end
	
	do
		local buffs = frame.Buffs;
		local rows = db.buffs.numrows;
		
		if(USE_POWERBAR_OFFSET) then
			buffs:SetWidth(UNIT_WIDTH - POWERBAR_OFFSET);
		else
			buffs:SetWidth(UNIT_WIDTH);
		end
		
		buffs.forceShow = frame.forceShowAuras;
		buffs.num = db.buffs.perrow * rows;
		buffs.size = db.buffs.sizeOverride ~= 0 and db.buffs.sizeOverride or ((((buffs:GetWidth() - (buffs.spacing*(buffs.num/rows - 1))) / buffs.num)) * rows);
		
		if(db.buffs.sizeOverride and db.buffs.sizeOverride > 0) then
			buffs:SetWidth(db.buffs.perrow * db.buffs.sizeOverride);
		end
		
		local x, y = E:GetXYOffset(db.buffs.anchorPoint);
		local attachTo = self:GetAuraAnchorFrame(frame, db.buffs.attachTo);
		
		buffs:Point(E.InversePoints[db.buffs.anchorPoint], attachTo, db.buffs.anchorPoint, x + db.buffs.xOffset, y + db.buffs.yOffset + (db.buffs.anchorPoint:find("TOP") and -(-BORDER + SPACING*2) or (-BORDER + SPACING*2)));
		buffs:Height(buffs.size * rows);
		buffs["growth-y"] = db.buffs.anchorPoint:find("TOP") and "UP" or "DOWN"
		buffs["growth-x"] = db.buffs.anchorPoint == "LEFT" and "LEFT" or  db.buffs.anchorPoint == "RIGHT" and "RIGHT" or (db.buffs.anchorPoint:find("LEFT") and "RIGHT" or "LEFT");
		buffs["spacing-x"] = db.buffs.xSpacing;
		buffs["spacing-y"] = db.buffs.ySpacing;
		buffs.initialAnchor = E.InversePoints[db.buffs.anchorPoint];
		
		if(db.buffs.enable) then
			buffs:Show();
			UF:UpdateAuraIconSettings(buffs);
		else
			buffs:Hide();
		end
	end
	
	do
		local debuffs = frame.Debuffs;
		local rows = db.debuffs.numrows;
		
		if(USE_POWERBAR_OFFSET) then
			debuffs:SetWidth(UNIT_WIDTH - POWERBAR_OFFSET);
		else
			debuffs:SetWidth(UNIT_WIDTH);
		end
		
		debuffs.forceShow = frame.forceShowAuras;
		debuffs.num = db.debuffs.perrow * rows;
		debuffs.size = db.debuffs.sizeOverride ~= 0 and db.debuffs.sizeOverride or ((((debuffs:GetWidth() - (debuffs.spacing*(debuffs.num/rows - 1))) / debuffs.num)) * rows);
		
		if(db.debuffs.sizeOverride and db.debuffs.sizeOverride > 0) then
			debuffs:SetWidth(db.debuffs.perrow * db.debuffs.sizeOverride);
		end
		
		local x, y = E:GetXYOffset(db.debuffs.anchorPoint);
		local attachTo = self:GetAuraAnchorFrame(frame, db.debuffs.attachTo, db.debuffs.attachTo == "BUFFS" and db.buffs.attachTo == "DEBUFFS");
		
		debuffs:Point(E.InversePoints[db.debuffs.anchorPoint], attachTo, db.debuffs.anchorPoint, x + db.debuffs.xOffset, y + db.debuffs.yOffset);
		debuffs:Height(debuffs.size * rows);
		debuffs["growth-y"] = db.debuffs.anchorPoint:find("TOP") and "UP" or "DOWN";
		debuffs["growth-x"] = db.debuffs.anchorPoint == "LEFT" and "LEFT" or  db.debuffs.anchorPoint == "RIGHT" and "RIGHT" or (db.debuffs.anchorPoint:find("LEFT") and "RIGHT" or "LEFT");
		debuffs["spacing-x"] = db.debuffs.xSpacing;
		debuffs["spacing-y"] = db.debuffs.ySpacing;
		debuffs.initialAnchor = E.InversePoints[db.debuffs.anchorPoint];
		
		if(db.debuffs.enable) then
			debuffs:Show();
			UF:UpdateAuraIconSettings(debuffs);
		else
			debuffs:Hide();
		end
	end
	
	do
		local rdebuffs = frame.RaidDebuffs;
		if(db.rdebuffs.enable) then
			frame:EnableElement("RaidDebuffs");
			
			rdebuffs:Size(db.rdebuffs.size);
			rdebuffs:Point("BOTTOM", frame, "BOTTOM", db.rdebuffs.xOffset, db.rdebuffs.yOffset);
			rdebuffs.count:FontTemplate(nil, db.rdebuffs.fontSize, "OUTLINE");
			rdebuffs.time:FontTemplate(nil, db.rdebuffs.fontSize, "OUTLINE");
		else
			frame:DisableElement("RaidDebuffs");
			rdebuffs:Hide();
		end
	end
	
	do
		local RI = frame.RaidIcon;
		if(db.raidicon.enable) then
			frame:EnableElement("RaidIcon");
			RI:Show();
			RI:Size(db.raidicon.size);
			
			local x, y = self:GetPositionOffset(db.raidicon.attachTo);
			RI:ClearAllPoints();
			RI:Point(db.raidicon.attachTo, frame, db.raidicon.attachTo, x + db.raidicon.xOffset, y + db.raidicon.yOffset);
		else
			frame:DisableElement("RaidIcon");
			RI:Hide();
		end
	end
	
	do
		local dbh = frame.DebuffHighlight;
		if(E.db.unitframe.debuffHighlighting ~= "NONE") then
			frame:EnableElement("DebuffHighlight");
			frame.DebuffHighlightFilterTable = E.global.unitframe.DebuffHighlightColors;
			if(E.db.unitframe.debuffHighlighting == "GLOW") then
				frame.DebuffHighlightBackdrop = true;
				frame.DBHGlow:SetAllPoints(frame.Threat.glow);
			else
				frame.DebuffHighlightBackdrop = false;
			end
		else
			frame:DisableElement("DebuffHighlight");
		end
	end
	
	do
		local raidRoleFrameAnchor = frame.RaidRoleFramesAnchor
		if(db.raidRoleIcons.enable) then
			raidRoleFrameAnchor:Show();
			frame:EnableElement("Leader");
			frame:EnableElement("MasterLooter");
			
			raidRoleFrameAnchor:ClearAllPoints();
			if(db.raidRoleIcons.position == "TOPLEFT") then
				raidRoleFrameAnchor:Point("LEFT", frame, "TOPLEFT", 2, 0);
			else
				raidRoleFrameAnchor:Point("RIGHT", frame, "TOPRIGHT", -2, 0);
			end
		else
			raidRoleFrameAnchor:Hide();
			frame:DisableElement("Leader");
			frame:DisableElement("MasterLooter");
		end
	end
	
	do
		local range = frame.Range;
		if(db.rangeCheck) then
			if(not frame:IsElementEnabled("Range")) then
				frame:EnableElement("Range");
			end
			
			range.outsideAlpha = E.db.unitframe.OORAlpha;
		else
			if(frame:IsElementEnabled("Range")) then
				frame:DisableElement("Range");
			end
		end
	end
	
	UF:UpdateAuraWatch(frame);
	
	frame:EnableElement("ReadyCheck");
	
	do
		local healCommBar = frame.HealCommBar;
		local c = UF.db.colors.healPrediction;
		if(db.healPrediction) then
			if(not frame:IsElementEnabled("HealComm4")) then
				frame:EnableElement("HealComm4");
			end
			
			healCommBar.myBar:SetOrientation(db.health.orientation);
			healCommBar.otherBar:SetOrientation(db.health.orientation);
			healCommBar.myBar:SetStatusBarColor(c.personal.r, c.personal.g, c.personal.b, c.personal.a);
			healCommBar.otherBar:SetStatusBarColor(c.others.r, c.others.g, c.others.b, c.others.a);
		else
			if(frame:IsElementEnabled("HealComm4")) then
				frame:DisableElement("HealComm4");
			end
		end
	end
	
	do
		local GPS = frame.GPS;
		if(db.GPSArrow.enable) then
			if not frame:IsElementEnabled("GPS") then
				frame:EnableElement("GPS");
			end
			
			GPS:Size(db.GPSArrow.size);
			GPS.onMouseOver = db.GPSArrow.onMouseOver;
			GPS.outOfRange = db.GPSArrow.outOfRange;
			
			GPS:SetPoint("CENTER", frame, "CENTER", db.GPSArrow.xOffset, db.GPSArrow.yOffset);
		else
			if(frame:IsElementEnabled("GPS")) then
				frame:DisableElement("GPS");
			end
		end
	end
	
	for objectName, object in pairs(frame.customTexts) do
		if((not db.customTexts) or (db.customTexts and not db.customTexts[objectName])) then
			object:Hide();
			frame.customTexts[objectName] = nil;
		end
	end
	
	if(db.customTexts) then
		local customFont = UF.LSM:Fetch("font", UF.db.font);
		for objectName, _ in pairs(db.customTexts) do
			if(not frame.customTexts[objectName]) then
				frame.customTexts[objectName] = frame.RaisedElementParent:CreateFontString(nil, "OVERLAY");
			end
			
			local objectDB = db.customTexts[objectName];
			if(objectDB.font) then
				customFont = UF.LSM:Fetch("font", objectDB.font);
			end
			
			frame.customTexts[objectName]:FontTemplate(customFont, objectDB.size or UF.db.fontSize, objectDB.fontOutline or UF.db.fontOutline);
			frame:Tag(frame.customTexts[objectName], objectDB.text_format or "");
			frame.customTexts[objectName]:SetJustifyH(objectDB.justifyH or "CENTER");
			frame.customTexts[objectName]:ClearAllPoints();
			frame.customTexts[objectName]:SetPoint(objectDB.justifyH or "CENTER", frame, objectDB.justifyH or "CENTER", objectDB.xOffset, objectDB.yOffset);
		end
	end
	
	UF:ToggleTransparentStatusBar(UF.db.colors.transparentHealth, frame.Health, frame.Health.bg, true);
	UF:ToggleTransparentStatusBar(UF.db.colors.transparentPower, frame.Power, frame.Power.bg);
	
	frame:UpdateAllElements();
end

UF["headerstoload"]["raid"] = true;