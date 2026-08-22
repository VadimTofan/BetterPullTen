local addonName = ...

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -140,
    lockButtons = false,
    pullSeconds = 10,
    hideInCombat = false,
    onlyShowForLead = false,
    hideInMythicPlus = true,
}

local colors = {
    panel = { 0.07, 0.08, 0.10, 0.96 },
    panelAlt = { 0.10, 0.11, 0.14, 0.96 },
    border = { 0.18, 0.20, 0.25, 1.00 },
    accent = { 0.24, 0.66, 0.74, 1.00 },
    accentHover = { 0.32, 0.78, 0.86, 1.00 },
    text = { 0.92, 0.94, 0.97, 1.00 },
    muted = { 0.58, 0.63, 0.70, 1.00 },
}

local MRT_CHAT_SECONDS = {
    [7] = true,
    [5] = true,
    [4] = true,
    [3] = true,
    [2] = true,
    [1] = true,
}
local SPAM_PROTECTION_SECONDS = 10

local isPlayerInCombat = false
local isMythicPlusActive = false
local activePullTimer = nil
local spamProtectionEndsAt = nil
local displayedSpamProtectionSeconds = nil
local pullTimerButton = nil

local function normalizePullSeconds(value)
    local seconds = tonumber(value)

    if not seconds or seconds < 1 then
        return nil
    end

    return math.floor(seconds)
end

local function ensureDatabase()
    BetterPullTenDB = BetterPullTenDB or {}

    if BetterPullTenDB.pullSeconds == nil
        and type(BetterPullTenDB.pullCommand) == "string" then
        local legacySeconds = BetterPullTenDB.pullCommand:match("(%d+)%s*$")
        BetterPullTenDB.pullSeconds = normalizePullSeconds(legacySeconds)
    end

    BetterPullTenDB.pullCommand = nil

    for key, value in pairs(defaults) do
        if BetterPullTenDB[key] == nil then
            BetterPullTenDB[key] = value
        end
    end

    BetterPullTenDB.pullSeconds =
        normalizePullSeconds(BetterPullTenDB.pullSeconds)
        or defaults.pullSeconds
end

local function getPullSeconds()
    return normalizePullSeconds(BetterPullTenDB.pullSeconds)
        or defaults.pullSeconds
end

local function savePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    BetterPullTenDB.point = point
    BetterPullTenDB.relativePoint = relativePoint
    BetterPullTenDB.x = x
    BetterPullTenDB.y = y
end

local function printMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff41c7d9BetterPullTen:|r " .. message)
end

local function setPanelVisuals(frame, backgroundColor, borderColor)
    frame:SetBackdropColor(unpack(backgroundColor))
    frame:SetBackdropBorderColor(unpack(borderColor))
end

local function canControlGroupTools()
    return IsInGroup() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end

local function refreshMythicPlusState()
    local active = false

    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
        active = C_ChallengeMode.IsChallengeModeActive() and true or false
    end

    isMythicPlusActive = active
end

local function shouldShowMainUI()
    if BetterPullTenDB.hideInCombat and isPlayerInCombat then
        return false
    end

    if BetterPullTenDB.hideInMythicPlus and isMythicPlusActive then
        return false
    end

    if BetterPullTenDB.onlyShowForLead and not canControlGroupTools() then
        return false
    end

    return true
end

local function applyMainFrameVisibility(mainFrame)
    if not mainFrame then
        return false
    end

    if not shouldShowMainUI() then
        mainFrame:Hide()
        return false
    end

    mainFrame:Show()
    return true
end

local function applySettingsFrameVisibility(settingsFrame)
    if not settingsFrame then
        return false
    end

    if settingsFrame.wantsOpen then
        settingsFrame:Show()
        return true
    end

    settingsFrame:Hide()
    return false
end

local function startReadyCheck()
    if not IsInGroup() then
        printMessage("You must be in a group to start a ready check.")
        return
    end

    if not canControlGroupTools() then
        printMessage("Only the group leader or an assistant can start a ready check.")
        return
    end

    DoReadyCheck()
end

local function getGroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    return "PARTY"
end

local function canSendGroupMessages()
    if not C_ChatInfo then
        return false
    end

    if C_ChatInfo.InChatMessagingLockdown then
        return not C_ChatInfo.InChatMessagingLockdown()
    end

    return true
end

local function sendPullChatMessage(message)
    if not canSendGroupMessages()
        or not C_ChatInfo.SendChatMessage then
        return false
    end

    local chatType = getGroupChannel()

    if chatType == "RAID" then
        chatType = "RAID_WARNING"
    end

    C_ChatInfo.SendChatMessage(message, chatType)
    return true
end

local function broadcastPullTimer(seconds)
    seconds = tonumber(seconds)

    if not seconds or seconds < 0 then
        printMessage("Pull timer seconds must be zero or a positive whole number.")
        return false
    end

    seconds = math.floor(seconds)

    if not IsInGroup() then
        printMessage("You must be in a group to start a pull timer.")
        return false
    end

    if not canControlGroupTools() then
        printMessage("Only the group leader or an assistant can start a pull timer.")
        return false
    end

    if not C_PartyInfo or not C_PartyInfo.DoCountdown then
        printMessage("Built-in countdown is not available in this game version.")
        return false
    end

    local countdownStarted = C_PartyInfo.DoCountdown(seconds)

    if countdownStarted == false then
        printMessage("WoW could not start the pull timer.")
        return false
    end

    if canSendGroupMessages() and C_ChatInfo.SendAddonMessage then
        local channel = getGroupChannel()
        local playerName = UnitName("player") or ""
        local realmName = GetRealmName() or ""
        local normalizedRealm = realmName:gsub("[%s-]+", "")
        local playerPrefix = playerName .. "-" .. normalizedRealm .. "\t"
        local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
        local dbmMessage = (playerPrefix .. "1\tPT\t%d\t%d"):format(
            seconds,
            mapID or 0
        )

        C_ChatInfo.SendAddonMessage(
            "BigWigs",
            "P^Pull^" .. seconds,
            channel
        )
        C_ChatInfo.SendAddonMessage("D5", dbmMessage, channel)
    end

    return true
end

local function getSpamProtectionSeconds()
    if not spamProtectionEndsAt then
        return nil
    end

    local seconds = math.ceil(spamProtectionEndsAt - GetTime())

    if seconds > 0 then
        return seconds
    end

    spamProtectionEndsAt = nil
    return nil
end

local function updatePullButton(seconds)
    if not pullTimerButton then
        return
    end

    local protectionSeconds = getSpamProtectionSeconds()

    if protectionSeconds then
        if protectionSeconds == displayedSpamProtectionSeconds then
            return
        end

        displayedSpamProtectionSeconds = protectionSeconds
        pullTimerButton.label:SetText(
            "Spam lock (" .. protectionSeconds .. "s)"
        )
        return
    end

    displayedSpamProtectionSeconds = nil

    if seconds then
        pullTimerButton.label:SetText("Cancel (" .. seconds .. ")")
        return
    end

    pullTimerButton.label:SetText("Pull Timer")
end

local function resetPullTimer()
    activePullTimer = nil
    updatePullButton()
end

local function cancelPullTimer()
    if not activePullTimer then
        return false
    end

    resetPullTimer()
    broadcastPullTimer(0)
    sendPullChatMessage(">>> Pull timer cancelled <<<")
    return true
end

local function startTrackedPullTimer(seconds)
    if not broadcastPullTimer(seconds) then
        return false
    end

    activePullTimer = {
        endsAt = GetTime() + seconds,
        displayedSeconds = seconds,
    }

    updatePullButton(seconds)
    sendPullChatMessage("Pull in " .. seconds .. " seconds")
    return true
end

local function togglePullTimer(seconds)
    local now = GetTime()

    if getSpamProtectionSeconds() then
        return false
    end

    local actionSucceeded
    local wasCancel = activePullTimer ~= nil

    if activePullTimer then
        actionSucceeded = cancelPullTimer()
    else
        actionSucceeded = startTrackedPullTimer(seconds)
    end

    if actionSucceeded and wasCancel then
        spamProtectionEndsAt = now + SPAM_PROTECTION_SECONDS
        updatePullButton()
    end

    return actionSucceeded
end

local function updatePullTimer()
    if not activePullTimer then
        return
    end

    local seconds = math.max(
        0,
        math.ceil(activePullTimer.endsAt - GetTime())
    )

    if seconds == activePullTimer.displayedSeconds then
        return
    end

    activePullTimer.displayedSeconds = seconds

    if seconds == 0 then
        resetPullTimer()
        sendPullChatMessage(">>> PULL <<<")
        return
    end

    updatePullButton(seconds)

    if MRT_CHAT_SECONDS[seconds] then
        sendPullChatMessage("Pull in " .. seconds .. " seconds")
    end
end

local function updateSpamProtection()
    if not spamProtectionEndsAt then
        return
    end

    local protectionSeconds = getSpamProtectionSeconds()

    if protectionSeconds then
        updatePullButton()
        return
    end

    updatePullButton(
        activePullTimer and activePullTimer.displayedSeconds
    )
end

local function updateTimers()
    updateSpamProtection()
    updatePullTimer()
end

local function startPullTimer()
    return togglePullTimer(getPullSeconds())
end

local function stylePanel(frame, backgroundColor)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(backgroundColor or colors.panel))
    frame:SetBackdropBorderColor(unpack(colors.border))

    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetPoint("TOPLEFT", -6, 6)
    shadow:SetPoint("BOTTOMRIGHT", 6, -6)
    shadow:SetColorTexture(0, 0, 0, 0.22)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(colors.accent))

    frame.shadow = shadow
    frame.accent = accent
end

local function createLabel(parent, layer, template, text, point, relativeTo, relativePoint, x, y, color)
    local label = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    label:SetText(text)

    if color then
        label:SetTextColor(unpack(color))
    end

    return label
end

local function createButton(parent, width, height, label, onClick, template)
    local button = CreateFrame("Button", nil, parent, template or "BackdropTemplate")
    button:SetSize(width, height)
    stylePanel(button, colors.panelAlt)

    button.label = createLabel(button, "OVERLAY", "GameFontNormal", label, "CENTER", button, "CENTER", 0, 0, colors.text)
    button.label:SetJustifyH("CENTER")

    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.12, 0.14, 0.18, 0.98)
    end)

    button:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(unpack(colors.panelAlt))
    end)

    button:SetScript("OnEnter", function(self)
        self.accent:SetColorTexture(unpack(colors.accentHover))
        self.label:SetTextColor(unpack(colors.accentHover))
    end)

    button:SetScript("OnLeave", function(self)
        self.accent:SetColorTexture(unpack(colors.accent))
        self.label:SetTextColor(unpack(colors.text))
        self:SetBackdropColor(unpack(colors.panelAlt))
    end)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end

local function createMainFrame()
    local frame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BackdropTemplate")
    frame:SetSize(140, 112)
    frame:SetPoint(
        BetterPullTenDB.point,
        UIParent,
        BetterPullTenDB.relativePoint,
        BetterPullTenDB.x,
        BetterPullTenDB.y
    )
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)
    stylePanel(frame, colors.panel)

    local dragLabel = createLabel(frame, "OVERLAY", "GameFontNormalSmall", "Drag to move", "TOPLEFT", frame, "TOPLEFT", 12, -14, colors.muted)

    local pullButton = createButton(frame, 108, 28, "Pull Timer", startPullTimer)
    pullButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42)
    pullTimerButton = pullButton

    local readyButton = createButton(frame, 108, 28, "Ready Check", startReadyCheck)
    readyButton:SetPoint("TOPLEFT", pullButton, "BOTTOMLEFT", 0, -8)

    local function applyLockState()
        if BetterPullTenDB.lockButtons then
            frame:SetSize(108, 64)
            pullButton:ClearAllPoints()
            pullButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            readyButton:ClearAllPoints()
            readyButton:SetPoint("TOPLEFT", pullButton, "BOTTOMLEFT", 0, -8)

            if frame.shadow then
                frame.shadow:Hide()
            end

            if frame.accent then
                frame.accent:Hide()
            end

            if frame.settingsButton then
                frame.settingsButton:Hide()
            end

            dragLabel:Hide()
            setPanelVisuals(frame, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            frame:EnableMouse(false)
        else
            frame:SetSize(140, 112)
            pullButton:ClearAllPoints()
            pullButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42)
            readyButton:ClearAllPoints()
            readyButton:SetPoint("TOPLEFT", pullButton, "BOTTOMLEFT", 0, -8)

            if frame.shadow then
                frame.shadow:Show()
            end

            if frame.accent then
                frame.accent:Show()
            end

            if frame.settingsButton then
                frame.settingsButton:Show()
            end

            dragLabel:Show()
            setPanelVisuals(frame, colors.panel, colors.border)
            frame:EnableMouse(true)
        end
    end

    frame.applyLockState = applyLockState
    applyLockState()

    return frame
end

local function createSettingsFrame(mainFrame)
    local frame = CreateFrame("Frame", addonName .. "SettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(305, 359)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    tinsert(UISpecialFrames, frame:GetName())
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.wantsOpen = false
    frame:Hide()
    stylePanel(frame, colors.panel)

    local closeButton = createButton(frame, 24, 24, "X", function()
        frame.wantsOpen = false
        frame:Hide()
    end)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -18)

    local secondsLabel = createLabel(frame, "OVERLAY", "GameFontNormal", "Pull Timer Seconds", "TOPLEFT", frame, "TOPLEFT", 24, -32, colors.text)
    local secondsHelp = createLabel(frame, "OVERLAY", "GameFontNormalSmall", "Used for Blizzard, BigWigs, and DBM timers", "TOPLEFT", secondsLabel, "BOTTOMLEFT", 0, -10, colors.accent)

    local secondsInputLabel = createLabel(frame, "OVERLAY", "GameFontNormalSmall", "Saved duration", "TOPLEFT", secondsHelp, "BOTTOMLEFT", 0, -20, colors.muted)
    local secondsInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    secondsInput:SetSize(155, 28)
    secondsInput:SetPoint("TOPLEFT", secondsInputLabel, "BOTTOMLEFT", 0, -8)
    secondsInput:SetAutoFocus(false)
    secondsInput:SetNumeric(true)
    secondsInput:SetMaxLetters(3)
    local secondsButton
    secondsInput:SetScript("OnEnterPressed", function()
        secondsButton:Click()
    end)
    secondsInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    secondsButton = createButton(frame, 90, 28, "Save", function()
        local seconds = normalizePullSeconds(secondsInput:GetText())

        if not seconds then
            printMessage("Pull timer seconds must be a positive whole number.")
            secondsInput:SetText(getPullSeconds())
            return
        end

        BetterPullTenDB.pullSeconds = seconds
        secondsInput:SetText(seconds)
        printMessage("Pull timer set to " .. seconds .. " seconds.")
    end)
    secondsButton:SetPoint("LEFT", secondsInput, "RIGHT", 12, 0)

    local lockButton = createButton(frame, 260, 32, "", function()
        BetterPullTenDB.lockButtons = not BetterPullTenDB.lockButtons
        mainFrame.applyLockState()
        if BetterPullTenDB.lockButtons then
            printMessage("Action bar locked. Card hidden.")
        else
            printMessage("Action bar unlocked.")
        end
        frame:GetScript("OnShow")()
    end)
    lockButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -180)

    local hideCombatButton = createButton(frame, 260, 32, "", function()
        BetterPullTenDB.hideInCombat = not BetterPullTenDB.hideInCombat
        applyMainFrameVisibility(mainFrame)
        frame:GetScript("OnShow")()
    end)
    hideCombatButton:SetPoint("TOPLEFT", lockButton, "BOTTOMLEFT", 0, -12)

    local leadOnlyButton = createButton(frame, 260, 32, "", function()
        BetterPullTenDB.onlyShowForLead = not BetterPullTenDB.onlyShowForLead
        applyMainFrameVisibility(mainFrame)
        frame:GetScript("OnShow")()
    end)
    leadOnlyButton:SetPoint("TOPLEFT", hideCombatButton, "BOTTOMLEFT", 0, -12)

    local mythicPlusButton = createButton(frame, 260, 32, "", function()
        BetterPullTenDB.hideInMythicPlus = not BetterPullTenDB.hideInMythicPlus
        applyMainFrameVisibility(mainFrame)
        frame:GetScript("OnShow")()
    end)
    mythicPlusButton:SetPoint("TOPLEFT", leadOnlyButton, "BOTTOMLEFT", 0, -12)

    frame:SetScript("OnShow", function()
        secondsInput:SetText(getPullSeconds())
        if BetterPullTenDB.lockButtons then
            lockButton.label:SetText("Lock Buttons: On")
            lockButton.label:SetTextColor(unpack(colors.accent))
        else
            lockButton.label:SetText("Lock Buttons: Off")
            lockButton.label:SetTextColor(unpack(colors.text))
        end

        if BetterPullTenDB.hideInCombat then
            hideCombatButton.label:SetText("Hide In Combat: On")
            hideCombatButton.label:SetTextColor(unpack(colors.accent))
        else
            hideCombatButton.label:SetText("Hide In Combat: Off")
            hideCombatButton.label:SetTextColor(unpack(colors.text))
        end

        if BetterPullTenDB.onlyShowForLead then
            leadOnlyButton.label:SetText("Show When Leader Or Assist: On")
            leadOnlyButton.label:SetTextColor(unpack(colors.accent))
        else
            leadOnlyButton.label:SetText("Show When Leader Or Assist: Off")
            leadOnlyButton.label:SetTextColor(unpack(colors.text))
        end

        if BetterPullTenDB.hideInMythicPlus then
            mythicPlusButton.label:SetText("Hide In Mythic+: On")
            mythicPlusButton.label:SetTextColor(unpack(colors.accent))
        else
            mythicPlusButton.label:SetText("Hide In Mythic+: Off")
            mythicPlusButton.label:SetTextColor(unpack(colors.text))
        end
    end)
    frame:SetScript("OnHide", function(self)
        if not self.suspendOpenState then
            self.wantsOpen = false
        end
    end)

    return frame
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:SetScript("OnUpdate", updateTimers)
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "PLAYER_REGEN_DISABLED" then
        isPlayerInCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        isPlayerInCombat = false
    end

    if event == "ADDON_LOADED" and loadedAddonName ~= addonName then
        return
    end

    if event == "ADDON_LOADED" then
        ensureDatabase()
        isPlayerInCombat = UnitAffectingCombat("player") or InCombatLockdown()
        refreshMythicPlusState()

        local mainFrame = createMainFrame()
        local settingsFrame = createSettingsFrame(mainFrame)
        local settingsButton = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
        settingsButton:SetSize(24, 24)
        settingsButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -8)
        stylePanel(settingsButton, colors.panelAlt)
        settingsButton:SetScript("OnClick", function()
            settingsFrame.wantsOpen = not settingsFrame.wantsOpen
            applySettingsFrameVisibility(settingsFrame)
        end)
        settingsButton:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.14, 0.16, 0.20, 0.98)
            self.accent:SetColorTexture(unpack(colors.accentHover))
            self.icon:SetVertexColor(unpack(colors.accentHover))
        end)
        settingsButton:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(colors.panelAlt))
            self.accent:SetColorTexture(unpack(colors.accent))
            self.icon:SetVertexColor(unpack(colors.muted))
        end)
        local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
        settingsIcon:SetPoint("TOPLEFT", 4, -4)
        settingsIcon:SetPoint("BOTTOMRIGHT", -4, 4)
        settingsIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        settingsIcon:SetVertexColor(unpack(colors.text))
        settingsButton.icon = settingsIcon
        mainFrame.settingsButton = settingsButton
        mainFrame.applyLockState()
        eventFrame.mainFrame = mainFrame
        eventFrame.settingsFrame = settingsFrame
        eventFrame.applyVisibility = function()
            applyMainFrameVisibility(mainFrame)
            applySettingsFrameVisibility(settingsFrame)
        end
        eventFrame.applyVisibility()

        SLASH_BETTERPULLTEN1 = "/bpt"
        SlashCmdList.BETTERPULLTEN = function(message)
            local normalizedMessage = tostring(message or "")
            local command, value = normalizedMessage:match("^(%S+)%s*(.-)%s*$")
            command = command and string.lower(command) or command

            if command == "" or command == nil then
                settingsFrame.wantsOpen = not settingsFrame.wantsOpen
                applySettingsFrameVisibility(settingsFrame)
                return
            end

            if command == "lock" then
                BetterPullTenDB.lockButtons = true
                mainFrame.applyLockState()
                printMessage("Action bar locked. Only the buttons remain visible.")
                return
            end

            if command == "unlock" then
                BetterPullTenDB.lockButtons = false
                mainFrame.applyLockState()
                printMessage("Action bar unlocked.")
                return
            end

            if command == "pull" then
                local pullSeconds = normalizePullSeconds(value)

                if not pullSeconds then
                    printMessage("Usage: /bpt pull <seconds>")
                    return
                end

                togglePullTimer(pullSeconds)
                return
            end

            printMessage("Commands: /bpt, /bpt lock, /bpt unlock, /bpt pull <seconds>")
        end

        return
    end

    refreshMythicPlusState()

    if eventFrame.applyVisibility then
        eventFrame.applyVisibility()
    end
end)
