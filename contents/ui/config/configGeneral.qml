import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents

KCM.SimpleKCM {
    id: page

    property alias cfg_codexbarCommand: codexbarCommand.text
    property string cfg_codexbarCommandDefault
    property string cfg_provider
    property string cfg_providerDefault
    property string cfg_source
    property string cfg_sourceDefault
    property alias cfg_refreshInterval: refreshInterval.value
    property int cfg_refreshIntervalDefault
    property alias cfg_showCreditsInPanel: showCreditsInPanel.checked
    property bool cfg_showCreditsInPanelDefault
    property alias cfg_showUsedPercentInPanel: showUsedPercentInPanel.checked
    property bool cfg_showUsedPercentInPanelDefault
    property alias cfg_showProviderInPanel: showProviderInPanel.checked
    property bool cfg_showProviderInPanelDefault
    property alias cfg_showEmailInWidget: showEmailInWidget.checked
    property bool cfg_showEmailInWidgetDefault
    property alias cfg_includeStatus: includeStatus.checked
    property bool cfg_includeStatusDefault
    property alias cfg_showCostSummary: showCostSummary.checked
    property bool cfg_showCostSummaryDefault

    function indexForValue(model, value) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).value === value) {
                return i
            }
        }
        return 0
    }

    Item {
        implicitWidth: content.implicitWidth + Kirigami.Units.largeSpacing * 2
        implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: i18n("CodexBar CLI")
                    level: 3
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: i18n("Choose how the panel widget queries CodexBar usage data.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: codexbarCommand
                    Kirigami.FormData.label: i18n("Command:")
                    placeholderText: "codexbar"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                }

                QQC2.ComboBox {
                    id: provider
                    Kirigami.FormData.label: i18n("Provider:")
                    textRole: "text"
                    valueRole: "value"
                    model: ListModel {
                        ListElement { text: "Best available"; value: "detect" }
                        ListElement { text: "All enabled"; value: "all" }
                        ListElement { text: "Abacus AI"; value: "abacus" }
                        ListElement { text: "Alibaba Coding Plan"; value: "alibaba" }
                        ListElement { text: "Alibaba Token Plan"; value: "alibabatokenplan" }
                        ListElement { text: "Amp"; value: "amp" }
                        ListElement { text: "Antigravity"; value: "antigravity" }
                        ListElement { text: "Augment"; value: "augment" }
                        ListElement { text: "AWS Bedrock"; value: "bedrock" }
                        ListElement { text: "Azure OpenAI"; value: "azureopenai" }
                        ListElement { text: "Codex"; value: "codex" }
                        ListElement { text: "Claude"; value: "claude" }
                        ListElement { text: "Codebuff"; value: "codebuff" }
                        ListElement { text: "Command Code"; value: "commandcode" }
                        ListElement { text: "Copilot"; value: "copilot" }
                        ListElement { text: "Crof"; value: "crof" }
                        ListElement { text: "Cursor"; value: "cursor" }
                        ListElement { text: "Deepgram"; value: "deepgram" }
                        ListElement { text: "DeepSeek"; value: "deepseek" }
                        ListElement { text: "Devin"; value: "devin" }
                        ListElement { text: "Doubao"; value: "doubao" }
                        ListElement { text: "Droid"; value: "factory" }
                        ListElement { text: "ElevenLabs"; value: "elevenlabs" }
                        ListElement { text: "Gemini"; value: "gemini" }
                        ListElement { text: "Grok"; value: "grok" }
                        ListElement { text: "GroqCloud"; value: "groq" }
                        ListElement { text: "JetBrains AI"; value: "jetbrains" }
                        ListElement { text: "Kilo Code"; value: "kilo" }
                        ListElement { text: "Kimi"; value: "kimi" }
                        ListElement { text: "Kimi K2"; value: "kimik2" }
                        ListElement { text: "Kiro"; value: "kiro" }
                        ListElement { text: "LLM Proxy"; value: "llmproxy" }
                        ListElement { text: "Manus"; value: "manus" }
                        ListElement { text: "MiniMax"; value: "minimax" }
                        ListElement { text: "Mistral"; value: "mistral" }
                        ListElement { text: "Moonshot"; value: "moonshot" }
                        ListElement { text: "Ollama"; value: "ollama" }
                        ListElement { text: "OpenAI API"; value: "openai" }
                        ListElement { text: "OpenCode"; value: "opencode" }
                        ListElement { text: "OpenCode Go"; value: "opencodego" }
                        ListElement { text: "OpenRouter"; value: "openrouter" }
                        ListElement { text: "Perplexity"; value: "perplexity" }
                        ListElement { text: "StepFun"; value: "stepfun" }
                        ListElement { text: "Synthetic"; value: "synthetic" }
                        ListElement { text: "T3 Chat"; value: "t3chat" }
                        ListElement { text: "Venice"; value: "venice" }
                        ListElement { text: "Vertex AI"; value: "vertexai" }
                        ListElement { text: "Warp"; value: "warp" }
                        ListElement { text: "Windsurf"; value: "windsurf" }
                        ListElement { text: "Xiaomi MiMo"; value: "mimo" }
                        ListElement { text: "z.ai"; value: "zai" }
                    }
                    currentIndex: page.indexForValue(model, page.cfg_provider || "detect")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    onActivated: function(index) {
                        page.cfg_provider = model.get(index).value
                    }
                }

                QQC2.ComboBox {
                    id: source
                    Kirigami.FormData.label: i18n("Source:")
                    textRole: "text"
                    valueRole: "value"
                    model: ListModel {
                        ListElement { text: "Best available"; value: "detect" }
                        ListElement { text: "Auto"; value: "auto" }
                        ListElement { text: "Web"; value: "web" }
                        ListElement { text: "CLI"; value: "cli" }
                        ListElement { text: "OAuth"; value: "oauth" }
                        ListElement { text: "API"; value: "api" }
                    }
                    currentIndex: page.indexForValue(model, page.cfg_source || "detect")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    onActivated: function(index) {
                        page.cfg_source = model.get(index).value
                    }
                }

                QQC2.SpinBox {
                    id: refreshInterval
                    Kirigami.FormData.label: i18n("Refresh:")
                    from: 10
                    to: 3600
                    stepSize: 10
                    textFromValue: function(value) { return i18np("%1 second", "%1 seconds", value) }
                    valueFromText: function(text) { return Number(text.replace(/\D/g, "")) }
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                }

                QQC2.CheckBox {
                    id: showProviderInPanel
                    text: i18n("Show provider in panel")
                }

                QQC2.CheckBox {
                    id: showEmailInWidget
                    text: i18n("Show email in widget")
                }

                QQC2.CheckBox {
                    id: showUsedPercentInPanel
                    text: i18n("Show used percent in panel")
                }

                QQC2.CheckBox {
                    id: showCreditsInPanel
                    text: i18n("Show credits in panel")
                }

                QQC2.CheckBox {
                    id: includeStatus
                    text: i18n("Fetch provider status")
                }

                QQC2.CheckBox {
                    id: showCostSummary
                    text: i18n("Show local cost summary")
                }
            }
        }
    }
}
