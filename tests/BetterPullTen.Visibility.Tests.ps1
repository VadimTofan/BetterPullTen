$sourcePath = Join-Path $PSScriptRoot '..\BetterPullTen.lua'
$source = Get-Content -Raw $sourcePath
$tocPath = Join-Path $PSScriptRoot '..\BetterPullTen.toc'
$tocSource = Get-Content -Raw $tocPath

Describe 'BetterPullTen addon icon' {
    It 'declares an addon-list icon backed by a project texture' {
        # Given
        $iconPath = Join-Path $PSScriptRoot '..\Media\Icon.png'

        # When
        $iconMetadataPattern = '(?m)^## IconTexture: ' +
            'Interface\\AddOns\\BetterPullTen\\Media\\Icon\.png$'

        # Then
        $tocSource | Should Match $iconMetadataPattern
        Test-Path -LiteralPath $iconPath | Should Be $true
    }
}

Describe 'BetterPullTen combat visibility' {
    It 'tracks combat state outside direct InCombatLockdown checks' {
        $source | Should Match 'local isPlayerInCombat = false'
    }

    It 'does not keep a persisted hidden state in defaults' {
        $source | Should Not Match 'hidden\s*='
    }

    It 'uses tracked combat state in the shared addon visibility helper' {
        $source | Should Match 'if BetterPullTenDB\.hideInCombat and isPlayerInCombat then\s+return false'
    }

    It 'uses a shared addon visibility helper' {
        $source | Should Match 'local function applyMainFrameVisibility\(mainFrame\)'
    }

    It 'keeps settings visibility separate from main frame visibility' {
        $source | Should Match 'local function applySettingsFrameVisibility\(settingsFrame\)'
    }

    It 'lets the settings button toggle only the settings frame visibility' {
        $source | Should Match 'settingsButton:SetScript\("OnClick", function\(\)\s+settingsFrame\.wantsOpen = not settingsFrame\.wantsOpen\s+applySettingsFrameVisibility\(settingsFrame\)'
    }

    It 'lets slash toggle only the settings frame visibility' {
        $source | Should Match 'if command == "" or command == nil then\s+settingsFrame\.wantsOpen = not settingsFrame\.wantsOpen\s+applySettingsFrameVisibility\(settingsFrame\)'
    }

    It 'does not expose a slash hide command anymore' {
        $source | Should Not Match 'if command == "hide" then'
    }

    It 'does not expose a slash show command anymore' {
        $source | Should Not Match 'if command == "show" then'
    }

    It 'keeps the settings frame open state independent from main frame visibility updates' {
        $source | Should Match 'eventFrame\.applyVisibility = function\(\)\s+applyMainFrameVisibility\(mainFrame\)\s+applySettingsFrameVisibility\(settingsFrame\)'
    }

    It 'documents only the remaining slash commands' {
        $source | Should Match 'Commands: /bpt, /bpt lock, /bpt unlock, /bpt pull <seconds>'
    }

    It 'sets tracked combat state on PLAYER_REGEN_DISABLED before applying visibility' {
        $source | Should Match 'if event == "PLAYER_REGEN_DISABLED" then\s+isPlayerInCombat = true'
    }

    It 'clears tracked combat state on PLAYER_REGEN_ENABLED before applying visibility' {
        $source | Should Match 'elseif event == "PLAYER_REGEN_ENABLED" then\s+isPlayerInCombat = false'
    }

    It 'does not parse slash commands with strsplit that truncates the remainder' {
        $source | Should Not Match 'local command, value = strsplit\(" ", string\.lower\(message or ""\), 2\)'
    }

    It 'parses slash commands by preserving the full value remainder' {
        $source | Should Match 'local normalizedMessage = tostring\(message or ""\)\s+local command, value = normalizedMessage:match\('
    }

    It 'lowercases only the slash subcommand token' {
        $source | Should Match 'command = command and string\.lower\(command\) or command'
    }
}

Describe 'BetterPullTen mythic plus visibility' {
    It 'limits mythic plus support to Retail clients with the required api' {
        # Given the addon can load on clients without Mythic+
        # When feature support is evaluated
        # Then both the Retail project and challenge mode API are required
        $source | Should Match 'local function supportsMythicPlus\(\)'
        $source | Should Match 'WOW_PROJECT_ID == WOW_PROJECT_MAINLINE'
        $source | Should Match 'C_ChallengeMode\.IsChallengeModeActive'
    }

    It 'registers optional events through a protected helper' {
        # Given client event sets differ
        # When events are registered
        # Then unsupported events cannot abort addon loading
        $source | Should Match 'local function registerEventIfAvailable\(frame, event\)'
        $source | Should Match 'pcall\(frame\.RegisterEvent, frame, event\)'
    }

    It 'defaults mythic plus auto-hide to enabled' {
        $source | Should Match 'hideInMythicPlus\s*=\s*true'
    }

    It 'tracks mythic plus state outside persisted settings' {
        $source | Should Match 'local isMythicPlusActive = false'
    }

    It 'uses mythic plus state in the shared addon visibility helper' {
        $source | Should Match 'if BetterPullTenDB\.hideInMythicPlus and isMythicPlusActive then\s+return false'
    }

    It 'registers challenge mode lifecycle events' {
        $source | Should Match 'registerEventIfAvailable\(eventFrame, "CHALLENGE_MODE_START"\)'
        $source | Should Match 'registerEventIfAvailable\(eventFrame, "CHALLENGE_MODE_COMPLETED"\)'
        $source | Should Match 'registerEventIfAvailable\(eventFrame, "CHALLENGE_MODE_RESET"\)'
    }

    It 'adds a helper to refresh mythic plus state from challenge mode api' {
        $source | Should Match 'local function refreshMythicPlusState\(\)'
    }

    It 'adds a settings toggle for mythic plus auto-hide' {
        $source | Should Match 'Hide In Mythic\+: On'
        $source | Should Match 'Hide In Mythic\+: Off'
        $source | Should Match 'if supportsMythicPlus\(\) then\s+mythicPlusButton = createButton'
    }

    It 'toggles mythic plus visibility from settings and reapplies main visibility' {
        $source | Should Match 'BetterPullTenDB\.hideInMythicPlus = not BetterPullTenDB\.hideInMythicPlus'
        $source | Should Match 'applyMainFrameVisibility\(mainFrame\)'
    }
}

Describe 'BetterPullTen cross-client group tools' {
    It 'guards the ready check api before calling it' {
        # Given a supported client may not expose ready checks
        # When the Ready Check button is used
        # Then the addon reports the unavailable feature without raising an error
        $source | Should Match 'if type\(DoReadyCheck\) ~= "function" then'
        $source | Should Match 'Ready checks are not available in this game version\.'
    }
}

# Describe BetterPullTen MRT-compatible pull timers.
Describe 'BetterPullTen pull timer compatibility' {
    It 'stores a numeric pull duration instead of an arbitrary command' {
        # Given the addon defaults
        # When the pull timer setting is inspected
        # Then it exposes seconds and no longer defaults to a slash command
        $source | Should Match 'pullSeconds\s*=\s*10'
        $source | Should Not Match 'pullCommand\s*=\s*"/countdown 10"'
    }

    It 'migrates the trailing duration from a legacy saved command' {
        # Given a database containing the former pullCommand setting
        # When database migration runs
        # Then the final numeric argument becomes pullSeconds
        $source | Should Match 'BetterPullTenDB\.pullCommand:match\("\(%d\+\)%s\*\$"\)'
        $source | Should Match 'BetterPullTenDB\.pullCommand\s*=\s*nil'
    }

    It 'validates pull seconds as positive whole numbers' {
        # Given a candidate pull duration
        # When it is normalized for storage or broadcasting
        # Then only a positive integer is returned
        $source | Should Match 'local function normalizePullSeconds\(value\)'
        $source | Should Match 'seconds\s*<\s*1'
        $source | Should Match 'math\.floor\(seconds\)'
    }

    It 'selects instance raid and party addon channels' {
        # Given the player is in a supported group type
        # When the MRT-compatible messages are routed
        # Then instance chat wins before raid and party
        $source | Should Match 'local function getGroupChannel\(\)'
        $source | Should Match 'IsInGroup\(LE_PARTY_CATEGORY_INSTANCE\)'
        $source | Should Match 'return "INSTANCE_CHAT"'
        $source | Should Match 'return "RAID"'
        $source | Should Match 'return "PARTY"'
    }

    It 'builds the BigWigs and DBM pull payloads used by MRT' {
        # Given a valid pull duration and current map
        # When compatibility messages are created
        # Then their prefixes and payload formats match MRT
        $source | Should Match '(?s)SendAddonMessage\(\s*"BigWigs",\s*"P\^Pull\^"\s*\.\.\s*seconds'
        $source | Should Match 'SendAddonMessage\("D5",\s*dbmMessage'
        $source | Should Match '"1\\tPT\\t%d\\t%d"'
    }

    It 'issues one Blizzard countdown without invoking local pull handlers' {
        # Given BigWigs or DBM may register a local pull slash handler
        # When BetterPullTen broadcasts a compatible pull timer
        # Then it does not trigger a second Blizzard countdown through that handler
        $source | Should Not Match 'local function startLocalBossModPullTimer'
        $source | Should Not Match 'startLocalBossModPullTimer\(seconds\)'
        ([regex]::Matches(
            $source,
            'C_PartyInfo\.DoCountdown\(seconds\)'
        )).Count | Should Be 1
    }

    It 'skips outbound compatibility messages during chat messaging lockdown' {
        # Given outgoing chat messaging is restricted
        # When a pull timer is requested
        # Then local and Blizzard timer state can still be updated safely
        $source | Should Match 'local function canSendGroupMessages\(\)'
        $source | Should Match 'return not C_ChatInfo\.InChatMessagingLockdown\(\)'
    }

    It 'starts the built in countdown from the shared broadcaster' {
        # Given a permitted pull timer request
        # When MRT-compatible broadcasting succeeds
        # Then the Blizzard countdown uses the same duration
        $source | Should Match 'local function broadcastPullTimer\(seconds\)'
        $source | Should Match 'C_PartyInfo\.DoCountdown\(seconds\)'
    }

    It 'shows a seconds-only pull timer setting' {
        # Given the settings window
        # When its pull timer controls are created
        # Then the user edits only the numeric duration
        $source | Should Match '"Pull Timer Seconds"'
        $source | Should Match 'SetNumeric\(true\)'
        $source | Should Not Match '"Pull Timer Command"'
    }

    It 'supports a one-time duration through the bpt pull command' {
        # Given a slash message containing pull and a duration
        # When BetterPullTen handles the command
        # Then it broadcasts that duration without replacing the saved value
        $source | Should Match 'if command == "pull" then'
        $source | Should Match 'togglePullTimer\(pullSeconds\)'
        $source | Should Match 'Usage: /bpt pull <seconds>'
    }
}

# Describe BetterPullTen tracked pull countdowns.
Describe 'BetterPullTen tracked pull countdown' {
    It 'locks pull actions after every successful cancel' {
        # Given every successful cancel starts spam protection
        $source | Should Match 'local SPAM_PROTECTION_SECONDS = 10'
        $source | Should Match 'local spamProtectionEndsAt = nil'
        $source | Should Not Match 'PULL_CANCEL_LIMIT'
        $source | Should Not Match 'PULL_CANCEL_WINDOW_SECONDS'
        $source | Should Not Match 'pullCancelTimes'
        $source | Should Not Match 'recordPullCancel'

        # When cancellation succeeds, protection starts immediately
        $successfulCancel = 'if actionSucceeded and wasCancel then' +
            '\s+spamProtectionEndsAt\s*=\s*' +
            'now \+ SPAM_PROTECTION_SECONDS'
        $source | Should Match $successfulCancel
    }

    It 'blocks shared pull actions only while protection is active' {
        # Given both the button and slash command use togglePullTimer
        $toggleWithProtection = 'local function togglePullTimer\(seconds\)' +
            '(?s:.*?)if getSpamProtectionSeconds\(\) then' +
            '\s+return false\s+end' +
            '(?s:.*?)if activePullTimer then' +
            '\s+actionSucceeded = cancelPullTimer\(\)' +
            '(?s:.*?)if actionSucceeded and wasCancel then' +
            '(?s:.*?)spamProtectionEndsAt\s*=\s*' +
            'now \+ SPAM_PROTECTION_SECONDS'

        # When another action is attempted during protection
        $source | Should Match $toggleWithProtection

        # Then blocked attempts do not reach either timer action
        $source | Should Match 'if activePullTimer then\s+' +
            'actionSucceeded = cancelPullTimer\(\)\s+else\s+' +
            'actionSucceeded = startTrackedPullTimer\(seconds\)'
    }

    It 'shows and clears the spam protection countdown' {
        # Given spam protection has an absolute end time
        $source | Should Match 'local function getSpamProtectionSeconds\(\)'
        $source | Should Match 'local displayedSpamProtectionSeconds = nil'
        $source | Should Match 'math\.ceil\(' +
            'spamProtectionEndsAt - GetTime\(\)'

        # When the pull button is updated during protection
        $source | Should Match 'protectionSeconds == ' +
            'displayedSpamProtectionSeconds'
        $source | Should Match 'displayedSpamProtectionSeconds\s*=\s*' +
            'protectionSeconds'
        $source | Should Match '"Spam lock \("\s*\.\.\s*' +
            'protectionSeconds\s*\.\.\s*"s\)"'

        # Then frame updates expire protection and restore the current label
        $source | Should Match 'local function updateSpamProtection\(\)'
        $source | Should Match 'local function updateTimers\(\)\s+' +
            'updateSpamProtection\(\)\s+updatePullTimer\(\)'
        $source | Should Match 'SetScript\("OnUpdate", updateTimers\)'
    }

    It 'tracks an active pull timer by its absolute end time' {
        # Given a valid pull duration
        # When a tracked timer starts
        # Then its end time is based on the monotonic game clock
        $source | Should Match 'local activePullTimer = nil'
        $source | Should Match 'endsAt\s*=\s*GetTime\(\)\s*\+\s*seconds'
    }

    It 'shows cancel with the current whole second while active' {
        # Given an active tracked pull
        # When the displayed second changes
        # Then the pull button exposes cancellation and the remaining duration
        $source | Should Match 'local function updatePullButton\(seconds\)'
        $source | Should Match '"Cancel \("\s*\.\.\s*seconds\s*\.\.\s*"\)"'
        $source | Should Match 'pullTimerButton\.label:SetText\("Pull Timer"\)'
    }

    It 'uses the MRT chat countdown cadence' {
        # Given the countdown moves between whole seconds
        # When chat announcements are evaluated
        # Then only MRT countdown seconds are announced after the initial value
        foreach ($second in 7, 5, 4, 3, 2, 1) {
            $source | Should Match "\[$second\]\s*=\s*true"
        }
    }

    It 'routes countdown chat through raid warning instance or party chat' {
        # Given the player is grouped
        # When a countdown message is announced
        # Then MRT chat routing is reproduced
        $source | Should Match 'local function sendPullChatMessage\(message\)'
        $source | Should Match 'chatType\s*=\s*"RAID_WARNING"'
        $source | Should Match 'C_ChatInfo\.SendChatMessage\(message,\s*chatType\)'
    }

    It 'updates from the absolute end time and finishes at zero' {
        # Given an active tracked pull
        # When the frame update runs
        # Then whole seconds are derived from the end time and completion resets state
        $source | Should Match 'local function updatePullTimer\(\)'
        $source | Should Match 'math\.ceil\(activePullTimer\.endsAt\s*-\s*GetTime\(\)\)'
        $source | Should Match 'sendPullChatMessage\(">>> PULL <<<"\)'
    }

    It 'broadcasts zero and resets local state when cancelled' {
        # Given a pull is active
        # When cancellation is requested
        # Then every compatibility timer receives zero and the idle label returns
        $source | Should Match 'local function cancelPullTimer\(\)'
        $source | Should Match 'broadcastPullTimer\(0\)'
        $source | Should Match 'sendPullChatMessage\(">>> Pull timer cancelled <<<"\)'
    }

    It 'uses one toggle path for the button and slash command' {
        # Given either user entry point starts or cancels a pull
        # When the request is handled
        # Then both entry points share the tracked timer toggle
        $source | Should Match 'local function togglePullTimer\(seconds\)'
        $source | Should Match 'return togglePullTimer\(getPullSeconds\(\)\)'
        $source | Should Match 'togglePullTimer\(pullSeconds\)'
    }

    It 'updates the tracked timer from the addon event frame' {
        # Given the addon event frame exists
        # When frame updates occur
        # Then the tracked countdown controller advances
        $source | Should Match 'eventFrame:SetScript\("OnUpdate",\s*updateTimers\)'
    }
}
