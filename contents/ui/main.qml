import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property var entries: []
    property string errorMessage: ""
    property string errorDetail: ""
    property string generatedAt: ""
    property bool loading: false
    property string codexbarCommand: Plasmoid.configuration.codexbarCommand || "codexbar"
    property string selectedProvider: Plasmoid.configuration.provider || "detect"
    property string selectedSource: Plasmoid.configuration.source || "detect"
    property string activeProvider: selectedProvider
    property string activeSource: selectedSource
    property var pendingCandidates: []
    property var failedCandidates: []
    property bool showCreditsInPanel: Plasmoid.configuration.showCreditsInPanel === undefined ? true : Plasmoid.configuration.showCreditsInPanel
    property int refreshSeconds: Math.max(10, Plasmoid.configuration.refreshInterval || 60)

    preferredRepresentation: compactRepresentation
    toolTipMainText: "KodexBar"
    toolTipSubText: errorMessage.length > 0 ? errorMessage : panelText()

    function panelText() {
        if (entries.length === 0) {
            return loading ? i18n("Loading") : i18n("No data")
        }
        var first = null
        for (var i = 0; i < entries.length; i++) {
            if (!entries[i].errorMessage && entries[i].rows.length > 0) {
                first = entries[i]
                break
            }
        }
        if (first === null) {
            first = entries[0]
        }
        var parts = [first.name || "Codex"]
        if (first.errorMessage) {
            parts.push(i18n("Error"))
            return parts.join(" ")
        }
        if (first.primaryPercentLeft !== null && first.primaryPercentLeft !== undefined) {
            parts.push(Math.round(first.primaryPercentLeft) + "%")
        } else if (first.creditsRemaining !== null && first.creditsRemaining !== undefined && showCreditsInPanel) {
            parts.push(formatNumber(first.creditsRemaining))
        }
        return parts.join(" ")
    }

    function formatNumber(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return ""
        }
        if (Math.abs(value) >= 1000) {
            return Number(value).toLocaleString(Qt.locale(), "f", 0)
        }
        return Number(value).toLocaleString(Qt.locale(), "f", 1)
    }

    function usedPercent(percentLeft) {
        if (percentLeft === null || percentLeft === undefined || isNaN(percentLeft)) {
            return null
        }
        return Math.max(0, Math.min(100, 100 - percentLeft))
    }

    function formatUsedPercent(percentLeft) {
        var used = usedPercent(percentLeft)
        if (used === null) {
            return i18n("Unavailable")
        }
        return i18n("%1% used", Math.round(used))
    }

    function formatResetTime(value) {
        if (!value) {
            return ""
        }
        var reset = new Date(value)
        var timestamp = reset.getTime()
        if (isNaN(timestamp)) {
            return ""
        }
        var diff = Math.max(0, timestamp - Date.now())
        var minutes = Math.round(diff / 60000)
        if (minutes < 1) {
            return i18n("Resets now")
        }
        var hours = Math.floor(minutes / 60)
        var days = Math.floor(hours / 24)
        if (days > 0) {
            return i18n("Resets in %1d %2h", days, hours % 24)
        }
        if (hours > 0) {
            return i18n("Resets in %1h %2m", hours, minutes % 60)
        }
        return i18n("Resets in %1m", minutes)
    }

    function resetTimeFromDescription(value) {
        if (!value) {
            return null
        }

        var text = String(value).trim()
        var direct = new Date(text)
        if (!isNaN(direct.getTime())) {
            return direct.toISOString()
        }

        var relative = /(\d+)\s*([dhm])\b/ig
        var match = null
        var minutes = 0
        while ((match = relative.exec(text)) !== null) {
            var amount = parseInt(match[1], 10)
            var unit = match[2].toLowerCase()
            if (unit === "d") {
                minutes += amount * 24 * 60
            } else if (unit === "h") {
                minutes += amount * 60
            } else {
                minutes += amount
            }
        }
        if (minutes > 0) {
            return new Date(Date.now() + minutes * 60000).toISOString()
        }

        var clock = text.match(/(?:resets?\s*)?(\d{1,2}):(\d{2})\s*(AM|PM)?/i)
        if (!clock) {
            return null
        }

        var hour = parseInt(clock[1], 10)
        var minute = parseInt(clock[2], 10)
        var meridiem = clock[3] ? clock[3].toUpperCase() : ""
        if (meridiem === "PM" && hour < 12) {
            hour += 12
        } else if (meridiem === "AM" && hour === 12) {
            hour = 0
        }

        var candidate = new Date()
        candidate.setHours(hour, minute, 0, 0)
        if (candidate.getTime() < Date.now()) {
            candidate.setDate(candidate.getDate() + 1)
        }
        return candidate.toISOString()
    }

    function commandLine(provider, source) {
        return shellQuote(codexbarCommand)
            + " usage --format json --json-only --provider " + shellQuote(provider)
            + " --source " + shellQuote(source)
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function refresh() {
        loading = true
        errorMessage = ""
        errorDetail = ""
        failedCandidates = []
        pendingCandidates = candidateList()
        executable.connectedSources = []
        tryNextCandidate()
    }

    function candidateList() {
        var provider = selectedProvider || "detect"
        var source = selectedSource || "detect"
        var sources = source === "detect" || source === "auto" ? ["cli", "oauth", "api", "auto"] : [source]
        var result = []

        if (provider !== "detect" && provider !== "all") {
            for (var i = 0; i < sources.length; i++) {
                result.push({ provider: provider, source: sources[i] })
            }
            return result
        }

        if (provider === "all" && source !== "detect") {
            return [{ provider: "all", source: source }]
        }

        return [
            { provider: "codex", source: "cli" },
            { provider: "codex", source: "oauth" },
            { provider: "codex", source: "api" },
            { provider: "claude", source: "cli" },
            { provider: "claude", source: "oauth" },
            { provider: "claude", source: "api" },
            { provider: "openai", source: "api" },
            { provider: "gemini", source: "api" },
            { provider: "copilot", source: "api" },
            { provider: "kilo", source: "cli" },
            { provider: "kilo", source: "api" },
            { provider: "openrouter", source: "api" },
            { provider: "ollama", source: "api" }
        ]
    }

    function tryNextCandidate() {
        if (pendingCandidates.length === 0) {
            loading = false
            entries = failedCandidates
            generatedAt = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
            if (entries.length === 0) {
                errorMessage = i18n("No usable CodexBar provider found")
                errorDetail = i18n("Configure a Linux-capable provider or choose a specific provider/source.")
            }
            return
        }

        var candidate = pendingCandidates.shift()
        activeProvider = candidate.provider
        activeSource = candidate.source
        executable.connectedSources = []
        executable.connectSource(commandLine(activeProvider, activeSource))
    }

    function hasUsableEntries(normalized) {
        for (var i = 0; i < normalized.length; i++) {
            if (!normalized[i].errorMessage
                    && ((normalized[i].rows && normalized[i].rows.length > 0)
                        || normalized[i].creditsRemaining !== null
                        || normalized[i].codeReviewRemainingPercent !== null)) {
                return true
            }
        }
        return false
    }

    function appendFailedEntries(normalized) {
        var existing = failedCandidates
        for (var i = 0; i < normalized.length; i++) {
            if (normalized[i].errorMessage) {
                existing.push(normalized[i])
            }
        }
        failedCandidates = existing
    }

    function parsePayload(text) {
        if (!text || text.length === 0) {
            return {
                ok: false,
                error: i18n("No output from CodexBar CLI"),
                detail: ""
            }
        }
        try {
            var raw = JSON.parse(text)
            var rawEntries = raw instanceof Array ? raw : [raw]
            var normalized = []
            for (var i = 0; i < rawEntries.length; i++) {
                if (rawEntries[i] && typeof rawEntries[i] === "object") {
                    normalized.push(normalizeEntry(rawEntries[i]))
                }
            }
            return {
                ok: true,
                entries: normalized,
                usable: hasUsableEntries(normalized)
            }
        } catch (error) {
            return {
                ok: false,
                error: i18n("Invalid CodexBar CLI response"),
                detail: String(error)
            }
        }
    }

    function providerName(raw) {
        var key = String(raw || "").toLowerCase()
        var names = {
            "codex": "Codex",
            "claude": "Claude",
            "openai": "OpenAI API",
            "azureopenai": "Azure OpenAI",
            "opencode": "OpenCode",
            "opencodego": "OpenCode Go",
            "alibabatokenplan": "Alibaba Token Plan",
            "vertexai": "Vertex AI",
            "kimik2": "Kimi K2",
            "t3chat": "T3 Chat",
            "deepseek": "DeepSeek",
            "codebuff": "Codebuff",
            "commandcode": "Command Code",
            "stepfun": "StepFun",
            "openrouter": "OpenRouter",
            "deepgram": "Deepgram",
            "llmproxy": "LLM Proxy",
            "copilot": "Copilot",
            "gemini": "Gemini",
            "kilo": "Kilo Code",
            "ollama": "Ollama"
        }
        return names[key] || (raw ? String(raw).charAt(0).toUpperCase() + String(raw).slice(1) : i18n("Provider"))
    }

    function providerIconSource(raw) {
        var key = String(raw || "").toLowerCase()
        var icons = {
            "codex": "codex",
            "claude": "claude",
            "openai": "openai",
            "azureopenai": "azureopenai",
            "opencode": "opencode",
            "opencodego": "opencodego",
            "alibabatokenplan": "alibabatokenplan",
            "vertexai": "vertexai",
            "kimik2": "kimik2",
            "t3chat": "t3chat",
            "deepseek": "deepseek",
            "codebuff": "codebuff",
            "commandcode": "commandcode",
            "stepfun": "stepfun",
            "openrouter": "openrouter",
            "deepgram": "deepgram",
            "llmproxy": "llmproxy",
            "copilot": "copilot",
            "gemini": "gemini",
            "kilo": "kilo",
            "ollama": "ollama"
        }
        return Qt.resolvedUrl("../icons/providers/" + (icons[key] || "codex") + ".svg")
    }

    function percentLeft(window) {
        if (!window || typeof window !== "object") {
            return null
        }
        if (typeof window.remainingPercent === "number") {
            return Math.max(0, Math.min(100, window.remainingPercent))
        }
        if (typeof window.usedPercent === "number") {
            return Math.max(0, Math.min(100, 100 - window.usedPercent))
        }
        return null
    }

    function resetAt(window) {
        if (!window || typeof window !== "object") {
            return null
        }

        var fields = ["resetsAt", "resetAt", "resetTime", "resetDate"]
        for (var i = 0; i < fields.length; i++) {
            if (window[fields[i]]) {
                return window[fields[i]]
            }
        }

        if (typeof window.resetTimestamp === "number") {
            var timestamp = window.resetTimestamp < 10000000000
                ? window.resetTimestamp * 1000
                : window.resetTimestamp
            return new Date(timestamp).toISOString()
        }

        return resetTimeFromDescription(window.resetDescription || window.resetsIn || "")
    }

    function normalizeEntry(entry) {
        var usage = entry.usage && typeof entry.usage === "object" ? entry.usage : {}
        var identity = usage.identity && typeof usage.identity === "object" ? usage.identity : {}
        var credits = entry.credits && typeof entry.credits === "object" ? entry.credits : null
        var dashboard = entry.openaiDashboard && typeof entry.openaiDashboard === "object" ? entry.openaiDashboard : {}
        var error = entry.error && typeof entry.error === "object" ? entry.error : null
        var primary = usage.primary
        var secondary = usage.secondary
        var tertiary = usage.tertiary
        var rows = []
        var windows = [
            { title: i18n("Session"), data: primary },
            { title: i18n("Weekly"), data: secondary },
            { title: i18n("Extra"), data: tertiary }
        ]
        for (var i = 0; i < windows.length; i++) {
            var left = percentLeft(windows[i].data)
            if (left !== null) {
                rows.push({ title: windows[i].title, percentLeft: left, resetsAt: resetAt(windows[i].data) })
            }
        }
        return {
            provider: entry.provider,
            name: providerName(entry.provider),
            version: entry.version,
            source: entry.source,
            account: entry.account || usage.accountEmail || identity.accountEmail || "",
            plan: usage.loginMethod || identity.loginMethod || "",
            primaryPercentLeft: percentLeft(primary),
            primaryResetsAt: resetAt(primary),
            secondaryPercentLeft: percentLeft(secondary),
            secondaryResetsAt: resetAt(secondary),
            creditsRemaining: credits ? credits.remaining : null,
            codeReviewRemainingPercent: typeof dashboard.codeReviewRemainingPercent === "number" ? dashboard.codeReviewRemainingPercent : null,
            rows: rows,
            updatedAt: usage.updatedAt || entry.updatedAt || "",
            status: entry.status,
            errorMessage: error ? (error.message || i18n("Provider returned an error")) : "",
            errorKind: error ? (error.kind || "") : ""
        }
    }

    function barColor(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return Kirigami.Theme.disabledTextColor
        }
        if (value < 15) {
            return Kirigami.Theme.negativeTextColor
        }
        if (value < 35) {
            return Kirigami.Theme.neutralTextColor
        }
        return Kirigami.Theme.positiveTextColor
    }

    function usageAccent(percentLeft) {
        if (percentLeft === null || percentLeft === undefined || isNaN(percentLeft)) {
            return Kirigami.Theme.disabledTextColor
        }
        if (percentLeft < 15) {
            return Kirigami.Theme.negativeTextColor
        }
        if (percentLeft < 35) {
            return "#d08a5b"
        }
        return "#58b9a8"
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.providerIconSource(root.entries.length > 0 ? root.entries[0].provider : "codex")
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents.Label {
                text: root.panelText()
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 8
            }
        }
    }

    fullRepresentation: Item {
        id: full
        readonly property int popupMargin: Kirigami.Units.largeSpacing * 2
        readonly property int maxPopupHeight: Kirigami.Units.gridUnit * 44

        Layout.minimumWidth: Kirigami.Units.gridUnit * 30
        Layout.minimumHeight: Math.min(Layout.preferredHeight, maxPopupHeight)
        Layout.preferredWidth: Kirigami.Units.gridUnit * 34
        Layout.preferredHeight: Math.min(content.implicitHeight + popupMargin * 2, maxPopupHeight)

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: full.popupMargin
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    Repeater {
                        model: root.entries.length > 0 ? root.entries : [{ name: "KodexBar", provider: "kodexbar", primaryPercentLeft: null }]

                        delegate: Rectangle {
                            readonly property real used: root.usedPercent(modelData.primaryPercentLeft) || 0
                            Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 5, chipLabel.implicitWidth + Kirigami.Units.iconSizes.small + Kirigami.Units.largeSpacing * 2)
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 3.25
                            radius: Kirigami.Units.cornerRadius
                            color: index === 0 ? Kirigami.Theme.highlightColor : "transparent"
                            opacity: modelData.errorMessage ? 0.62 : 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Icon {
                                        source: root.providerIconSource(modelData.provider)
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: Kirigami.Units.iconSizes.small
                                    }

                                    PlasmaComponents.Label {
                                        id: chipLabel
                                        text: modelData.name || modelData.provider
                                        horizontalAlignment: Text.AlignHCenter
                                        font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                        color: index === 0 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 5
                                    radius: height / 2
                                    color: Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.28)
                                    clip: true

                                    Rectangle {
                                        width: parent.width * used / 100
                                        height: parent.height
                                        radius: parent.radius
                                        color: index === 0 ? Kirigami.Theme.highlightedTextColor : root.usageAccent(modelData.primaryPercentLeft)
                                    }
                                }
                            }
                        }
                    }
                }

                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.loading
                    text: i18n("Refresh")
                    onClicked: root.refresh()
                }
            }

            PlasmaComponents.Label {
                visible: root.loading
                text: i18n("Trying %1 / %2", root.activeProvider, root.activeSource)
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: root.errorMessage.length > 0
                text: root.errorDetail.length > 0 ? root.errorMessage + "\n" + root.errorDetail : root.errorMessage
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: root.errorMessage.length === 0 && root.entries.length === 0
                text: root.loading ? i18n("Loading usage...") : i18n("No usage data available")
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            QQC2.ScrollView {
                id: scrollView
                visible: root.entries.length > 0
                clip: true
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentList.implicitHeight, Kirigami.Units.gridUnit * 32)
                Layout.fillHeight: contentList.implicitHeight > Kirigami.Units.gridUnit * 32

                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                QQC2.ScrollBar.vertical.policy: contentList.implicitHeight > scrollView.height
                    ? QQC2.ScrollBar.AsNeeded
                    : QQC2.ScrollBar.AlwaysOff

                ColumnLayout {
                    id: contentList
                    width: scrollView.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        model: root.entries

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            RowLayout {
                                Layout.fillWidth: true

                                Kirigami.Icon {
                                    source: root.providerIconSource(modelData.provider)
                                    implicitWidth: Kirigami.Units.iconSizes.medium
                                    implicitHeight: Kirigami.Units.iconSizes.medium
                                    Layout.alignment: Qt.AlignTop
                                }

                                ColumnLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.fillWidth: true

                                    PlasmaComponents.Label {
                                        text: modelData.name || modelData.provider
                                        font.weight: Font.Bold
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 7
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        text: root.generatedAt.length > 0 ? i18n("Updated %1", root.generatedAt) : ""
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: modelData.source || ""
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                    visible: text.length > 0
                                    Layout.alignment: Qt.AlignBottom
                                }
                            }

                            Kirigami.Separator {
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: modelData.rows || []

                                delegate: ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.smallSpacing

                                        PlasmaComponents.Label {
                                            text: modelData.title
                                            font.weight: Font.Bold
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 5
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        PlasmaComponents.Label {
                                            text: root.formatResetTime(modelData.resetsAt)
                                            color: Kirigami.Theme.disabledTextColor
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                            visible: text.length > 0
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Kirigami.Units.gridUnit * 9
                                        }

                                        PlasmaComponents.Label {
                                            text: root.formatUsedPercent(modelData.percentLeft)
                                            color: root.usageAccent(modelData.percentLeft)
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                        }
                                    }

                                    Rectangle {
                                        readonly property real used: root.usedPercent(modelData.percentLeft) || 0
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 8
                                        radius: height / 2
                                        color: Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.24)
                                        clip: true

                                        Rectangle {
                                            width: Math.max(parent.height, parent.width * parent.used / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.usageAccent(modelData.percentLeft)
                                        }
                                    }

                                }
                            }

                            PlasmaComponents.Label {
                                visible: modelData.errorMessage && modelData.errorMessage.length > 0
                                text: modelData.errorKind && modelData.errorKind.length > 0
                                    ? modelData.errorKind + ": " + modelData.errorMessage
                                    : modelData.errorMessage
                                color: Kirigami.Theme.negativeTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: modelData.creditsRemaining !== null && modelData.creditsRemaining !== undefined

                                ColumnLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.fillWidth: true

                                    PlasmaComponents.Label {
                                        text: i18n("Credits")
                                        font.weight: Font.Bold
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 5
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        visible: modelData.account
                                        text: modelData.account || ""
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: root.formatNumber(modelData.creditsRemaining)
                                    font.weight: Font.DemiBold
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                    Layout.alignment: Qt.AlignTop
                                }
                            }

                            Kirigami.Separator {
                                visible: index < root.entries.length - 1
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: root.entries.length === 0
                text: root.generatedAt.length > 0 ? i18n("Updated %1", root.generatedAt) : ""
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            if (data["exit code"] && data["exit code"] !== 0 && !(data.stdout || "").length) {
                var errorEntry = root.normalizeEntry({
                    provider: root.activeProvider,
                    source: root.activeSource,
                    error: {
                        kind: "runtime",
                        message: data.stderr || i18n("Exit code %1", data["exit code"])
                    }
                })
                root.appendFailedEntries([errorEntry])
                root.tryNextCandidate()
                return
            }
            var result = root.parsePayload(data.stdout || "")
            if (!result.ok) {
                var parseErrorEntry = root.normalizeEntry({
                    provider: root.activeProvider,
                    source: root.activeSource,
                    error: { kind: "runtime", message: result.error + (result.detail ? ": " + result.detail : "") }
                })
                root.appendFailedEntries([parseErrorEntry])
                root.tryNextCandidate()
                return
            }
            if (!result.usable && root.pendingCandidates.length > 0) {
                root.appendFailedEntries(result.entries)
                root.tryNextCandidate()
                return
            }
            root.loading = false
            root.errorMessage = ""
            root.errorDetail = ""
            root.generatedAt = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
            root.entries = result.entries
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshSeconds * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onRefreshSecondsChanged: {
        refreshTimer.restart()
        refresh()
    }

    onCodexbarCommandChanged: refresh()
    onSelectedProviderChanged: refresh()
    onSelectedSourceChanged: refresh()
    onShowCreditsInPanelChanged: panelText()
}
