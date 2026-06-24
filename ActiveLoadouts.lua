local addonName = ...
ActiveLoadoutsDB = ActiveLoadoutsDB or {}

-----------------------------------------------------------
-- Localization (English & German)
-----------------------------------------------------------
local L = {}
if GetLocale() == "deDE" then
  L.Armor = "Rüstung"
  L.Talents = "Talente"
  L.MixedGear = "Gemischte Rüstung"
  L.CustomUnsaved = "Ungespeichert"
  L.NoArmor = "Keine Rüstungssets gefunden."
  L.NoTalents = "Keine gespeicherten Talente gefunden."
  L.CombatError = "Wechseln im Kampf nicht möglich."
  L.OptionsTitle = "Active Loadouts Optionen"
  L.LockFrames = "Fensterpositionen sperren"
  L.HideArmor = "Rüstungs-Indikator ausblenden"
  L.HideTalents = "Talent-Indikator ausblenden"
  L.LinkFrames = "Fenster zusammenheften (Snapping)"
  L.Scale = "Skalierung (Größe)"
  L.ResetPos = "Positionen zurücksetzen"
  L.ResetMsg = "Positionen auf Standard zurückgesetzt."
  L.SlashHelp = "Befehle: /al (öffnet das Menü), show, hide, lock, unlock, reset."
else
  L.Armor = "Armor"
  L.Talents = "Talents"
  L.MixedGear = "Mixed gear"
  L.CustomUnsaved = "Custom / Unsaved"
  L.NoArmor = "No Equipment Manager sets found."
  L.NoTalents = "No saved talent loadouts found."
  L.CombatError = "Cannot change loadouts in combat."
  L.OptionsTitle = "Active Loadouts Options"
  L.LockFrames = "Lock Frame Positions"
  L.HideArmor = "Hide Armor Indicator"
  L.HideTalents = "Hide Talent Indicator"
  L.LinkFrames = "Snap/Link Frames Together"
  L.Scale = "Scale (Size)"
  L.ResetPos = "Reset Positions"
  L.ResetMsg = "Positions reset to default."
  L.SlashHelp = "Commands: /al (opens menu), show, hide, lock, unlock, reset."
end

local function Print(msg)
  print("|cff33ff99Active Loadouts|r: " .. msg)
end

-----------------------------------------------------------
-- UI Template Generator
-----------------------------------------------------------
local function CreateIndicator(name)
  local f = CreateFrame("Button", addonName .. name, UIParent, "BackdropTemplate")
  f:SetHeight(28)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetClampedToScreen(true)

  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  f:SetBackdropColor(0.06, 0.06, 0.06, 0.8)
  f:SetBackdropBorderColor(0, 0, 0, 1)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(24, 24)
  f.icon:SetPoint("LEFT", 2, 0)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetWordWrap(false)

  return f
end

local armorFrame = CreateIndicator("ArmorFrame")
local talentFrame = CreateIndicator("TalentFrame")

-----------------------------------------------------------
-- Layout & Dragging Logic
-----------------------------------------------------------
local function ApplyLayout()
  if ActiveLoadoutsDB.armorHidden then armorFrame:Hide() else armorFrame:Show() end
  if ActiveLoadoutsDB.talentHidden then talentFrame:Hide() else talentFrame:Show() end
  
  armorFrame:SetScale(ActiveLoadoutsDB.scale or 1.0)
  talentFrame:SetScale(ActiveLoadoutsDB.scale or 1.0)
  
  if ActiveLoadoutsDB.linked then
    talentFrame:ClearAllPoints()
    talentFrame:SetPoint("TOPLEFT", armorFrame, "BOTTOMLEFT", 0, -2)
  else
    if ActiveLoadoutsDB.talentPoint then
      local p, rp, x, y = unpack(ActiveLoadoutsDB.talentPoint)
      talentFrame:ClearAllPoints()
      talentFrame:SetPoint(p, UIParent, rp, x, y)
    end
  end
end

local function SavePosition(frame, dbKey)
  local left, top = frame:GetLeft(), frame:GetTop()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  ActiveLoadoutsDB[dbKey] = {"TOPLEFT", "BOTTOMLEFT", left, top}
end

-- Armor Drag
armorFrame:SetScript("OnDragStart", function(self)
  if ActiveLoadoutsDB.locked then return end
  if not InCombatLockdown() then self:StartMoving() end
end)
armorFrame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SavePosition(self, "armorPoint")
  if ActiveLoadoutsDB.linked then ApplyLayout() end -- Keeps talent frame glued
end)

-- Talent Drag
talentFrame:SetScript("OnDragStart", function(self)
  if ActiveLoadoutsDB.locked or ActiveLoadoutsDB.linked then return end
  if not InCombatLockdown() then self:StartMoving() end
end)
talentFrame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SavePosition(self, "talentPoint")
end)

-----------------------------------------------------------
-- Armor Logic
-----------------------------------------------------------
local cachedSetIDs = {}
local function UpdateArmorIDs()
  if C_EquipmentSet and type(C_EquipmentSet.GetEquipmentSetIDs) == "function" then 
    cachedSetIDs = C_EquipmentSet.GetEquipmentSetIDs() or {}
  elseif type(GetEquipmentSetIDs) == "function" then 
    cachedSetIDs = GetEquipmentSetIDs() or {}
  end
end

local function GetArmorInfo(id)
  if C_EquipmentSet and type(C_EquipmentSet.GetEquipmentSetInfo) == "function" then return C_EquipmentSet.GetEquipmentSetInfo(id) end
  if type(GetEquipmentSetInfo) == "function" then return GetEquipmentSetInfo(id) end
end

local function UpdateArmorVisual()
  local matchedName, matchedIcon
  for _, id in ipairs(cachedSetIDs) do
    local ok, name, icon, _, isEquipped = pcall(GetArmorInfo, id)
    if ok and name and isEquipped then matchedName, matchedIcon = name, icon; break end
  end
  
  if matchedName then
    armorFrame.text:SetText(L.Armor .. ": " .. matchedName)
    armorFrame.icon:SetTexture(matchedIcon)
  else
    armorFrame.text:SetText(L.Armor .. ": " .. L.MixedGear)
    armorFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  armorFrame:SetWidth(40 + armorFrame.text:GetStringWidth())
end

local function OnArmorSelected(id)
  if InCombatLockdown() then Print(L.CombatError) return end
  if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then C_EquipmentSet.UseEquipmentSet(id)
  elseif UseEquipmentSet then UseEquipmentSet(id) end
end

local function ArmorMenuGen(_, root)
  for _, id in ipairs(cachedSetIDs) do
    local name = GetArmorInfo(id)
    if name then root:CreateRadio(name, function() local _,_,_,e = GetArmorInfo(id) return e end, OnArmorSelected, id) end
  end
end

armorFrame:SetScript("OnClick", function(_, btn)
  if btn == "RightButton" then
    if #cachedSetIDs == 0 then Print(L.NoArmor) return end
    MenuUtil.CreateContextMenu(armorFrame, ArmorMenuGen)
  end
end)

-----------------------------------------------------------
-- Talent Logic
-----------------------------------------------------------
local cachedTalentIDs = {}
local function UpdateTalentIDs()
  local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID()
  if specID and C_ClassTalents then cachedTalentIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {} else cachedTalentIDs = {} end
end

local function GetActiveTalent()
  local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID()
  return specID and C_ClassTalents.GetLastSelectedSavedConfigID(specID) or nil
end

local function UpdateTalentVisual()
  local actID = GetActiveTalent()
  local matchedName = nil
  if actID then
    local info = C_Traits.GetConfigInfo(actID)
    if info and info.name then matchedName = info.name end
  end
  
  if matchedName then talentFrame.text:SetText(L.Talents .. ": " .. matchedName)
  else talentFrame.text:SetText(L.Talents .. ": " .. L.CustomUnsaved) end
  
  local spec = GetSpecialization()
  if spec then
    local _, _, _, icon = GetSpecializationInfo(spec)
    talentFrame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  else talentFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
  
  talentFrame:SetWidth(40 + talentFrame.text:GetStringWidth())
end

local function OnTalentSelected(id)
  if InCombatLockdown() then Print(L.CombatError) return end
  local specID = PlayerUtil.GetCurrentSpecID()
  if specID then C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id) end
  C_ClassTalents.LoadConfig(id, true)
end

local function TalentMenuGen(_, root)
  for _, id in ipairs(cachedTalentIDs) do
    local info = C_Traits.GetConfigInfo(id)
    if info and info.name then root:CreateRadio(info.name, function() return id == GetActiveTalent() end, OnTalentSelected, id) end
  end
end

talentFrame:SetScript("OnClick", function(_, btn)
  if btn == "RightButton" then
    if #cachedTalentIDs == 0 then Print(L.NoTalents) return end
    MenuUtil.CreateContextMenu(talentFrame, TalentMenuGen)
  end
end)

-----------------------------------------------------------
-- Core Event Handler
-----------------------------------------------------------
local core = CreateFrame("Frame")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("EQUIPMENT_SETS_CHANGED")
core:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("TRAIT_CONFIG_UPDATED")
core:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

core:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ActiveLoadoutsDB = ActiveLoadoutsDB or {}
    if ActiveLoadoutsDB.linked == nil then ActiveLoadoutsDB.linked = true end
    
    if ActiveLoadoutsDB.armorPoint then
      local p, rp, x, y = unpack(ActiveLoadoutsDB.armorPoint)
      armorFrame:ClearAllPoints(); armorFrame:SetPoint(p, UIParent, rp, x, y)
    else
      armorFrame:SetPoint("TOPLEFT", UIParent, "CENTER", -85, -180)
    end
    
    UpdateArmorIDs()
    UpdateTalentIDs()
    ApplyLayout()
  elseif event == "EQUIPMENT_SETS_CHANGED" then UpdateArmorIDs()
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then UpdateTalentIDs() end
  
  C_Timer.After(0.4, function()
    UpdateArmorVisual()
    UpdateTalentVisual()
  end)
end)

-----------------------------------------------------------
-- Settings Menu
-----------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "Active Loadouts"
local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L.OptionsTitle)

local function MakeCheck(name, label, offset, dbKey, extraCode)
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", offset, "BOTTOMLEFT", 0, -10)
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  cb.text:SetText(label)
  cb:SetScript("OnClick", function(self)
    ActiveLoadoutsDB[dbKey] = self:GetChecked()
    if extraCode then extraCode() end
  end)
  return cb
end

local lockCheck = MakeCheck("Lock", L.LockFrames, title, "locked")
lockCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
local hideArmorCheck = MakeCheck("HideArmor", L.HideArmor, lockCheck, "armorHidden", ApplyLayout)
local hideTalentCheck = MakeCheck("HideTalents", L.HideTalents, hideArmorCheck, "talentHidden", ApplyLayout)
local linkCheck = MakeCheck("Link", L.LinkFrames, hideTalentCheck, "linked", ApplyLayout)

local scaleSlider = CreateFrame("Slider", "ActiveLoadoutsScaleSlider", panel, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", linkCheck, "BOTTOMLEFT", 4, -30)
scaleSlider:SetMinMaxValues(0.5, 2.0)
scaleSlider:SetValueStep(0.1)
_G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
_G[scaleSlider:GetName() .. "High"]:SetText("2.0")
_G[scaleSlider:GetName() .. "Text"]:SetText(L.Scale)

scaleSlider:SetScript("OnValueChanged", function(self, value)
  value = math.floor(value * 10 + 0.5) / 10
  ActiveLoadoutsDB.scale = value
  ApplyLayout()
end)

local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetSize(180, 26)
resetBtn:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -4, -30)
resetBtn:SetText(L.ResetPos)
resetBtn:SetScript("OnClick", function()
  ActiveLoadoutsDB.armorPoint = nil
  ActiveLoadoutsDB.talentPoint = nil
  armorFrame:ClearAllPoints(); armorFrame:SetPoint("TOPLEFT", UIParent, "CENTER", -85, -180)
  talentFrame:ClearAllPoints(); talentFrame:SetPoint("TOPLEFT", UIParent, "CENTER", -85, -220)
  ApplyLayout()
  Print(L.ResetMsg)
end)

panel:SetScript("OnShow", function()
  lockCheck:SetChecked(ActiveLoadoutsDB.locked)
  hideArmorCheck:SetChecked(ActiveLoadoutsDB.armorHidden)
  hideTalentCheck:SetChecked(ActiveLoadoutsDB.talentHidden)
  linkCheck:SetChecked(ActiveLoadoutsDB.linked)
  scaleSlider:SetValue(ActiveLoadoutsDB.scale or 1.0)
end)

-----------------------------------------------------------
-- Slash Commands
-----------------------------------------------------------
SLASH_ACTIVELOADOUTS1 = "/al"
SLASH_ACTIVELOADOUTS2 = "/loadouts"
SlashCmdList.ACTIVELOADOUTS = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" or msg == "options" or msg == "menu" then Settings.OpenToCategory(category.ID)
  elseif msg == "reset" then resetBtn:Click()
  elseif msg == "lock" then lockCheck:SetChecked(true); ActiveLoadoutsDB.locked = true; Print("Locked.")
  elseif msg == "unlock" then lockCheck:SetChecked(false); ActiveLoadoutsDB.locked = false; Print("Unlocked.")
  else Print(L.SlashHelp) end
end