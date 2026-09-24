/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "Components"
import "logic/pfkeys.js" as PfKeys
import "logic/platform.js" as Platform

ScrollView {
    id: retroTab
    clip: true

    readonly property int slotCount: appSettings.pfAssignments.length
    readonly property var keyMap: Platform.sequences(Qt.platform.os)
    readonly property int collisionCount: PfKeys.collisions(appSettings.pfAssignments).length

    function setSlot(index, patch) {
        appSettings.patchPfAssignment(index, patch)
    }

    /** Index into the action catalogue of the function bound to a slot. */
    function actionIndexOf(assignment) {
        if (!assignment)
            return 0
        for (var i = 0; i < PfKeys.ACTIONS.length; i++) {
            if (PfKeys.ACTIONS[i].id === assignment.action)
                return i
        }
        return 0
    }

    /** The legend text as it prints: the phosphor, unless coloured. */
    readonly property color legendText: appSettings.legendTextColor !== ""
            ? appSettings.legendTextColor : appSettings.fontColor
    /** The arrow as it prints: the text's colour, shaded to 60%. */
    readonly property color legendArrow: appSettings.legendArrowColor !== ""
            ? appSettings.legendArrowColor
            : Qt.rgba(legendText.r, legendText.g, legendText.b, 0.6)

    /**
     * The legend's font choices: the screen's own face first (family ""),
     * then every face the machine offers.  Built as plain objects so one
     * ComboBox can show a label but store the family.
     */
    function legendFontEntries() {
        var entries = [{ text: qsTr("(same as the screen)"), name: "" }]
        var list = appSettings.filteredFontList
        for (var i = 0; i < list.count; i++)
            entries.push({ text: list.get(i).text, name: list.get(i).name })
        return entries
    }

    /** Index of the family the legend is set to, "" included. */
    function legendFontIndexOf() {
        var entries = legendFontEntries()
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].name === appSettings.legendFontFamily)
                return i
        }
        return 0
    }

    ColumnLayout {
        width: retroTab.availableWidth
        spacing: 12

        // INTERFACE //////////////////////////////////////////////////////////
        GroupBox {
            title: qsTr("Interface")
            Layout.fillWidth: true
            padding: appSettings.defaultMargin

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                CheckBox {
                    objectName: "nostalgicModeCheckBox"
                    text: qsTr("Nostalgic mode: full screen shows nothing; menu and right-click when windowed")
                    checked: appSettings.nostalgicMode
                    onCheckedChanged: appSettings.nostalgicMode = checked
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("Nothing on screen suggests a graphical interface. "
                               + "Everything is driven from the keyboard: "
                               + "settings %1, new window %2, next window %3, "
                               + "close window %4, fullscreen %5, quit %6. "
                               + "Outside full screen the menu bar and the "
                               + "right-click menu are there for the mouse; "
                               + "in full screen touch the top edge to peek "
                               + "at the menu.")
                        .arg(retroTab.keyMap.settings)
                        .arg(retroTab.keyMap.newWindow)
                        .arg(retroTab.keyMap.nextWindow)
                        .arg(retroTab.keyMap.closeWindow)
                        .arg("F11")
                        .arg(retroTab.keyMap.quit)
                }

                CheckBox {
                    objectName: "showPfKeysCheckBox"
                    text: qsTr("Show the IBM PF/PA key legend on the screen")
                    checked: appSettings.showPfKeys
                    onCheckedChanged: appSettings.showPfKeys = checked
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("The legend is part of the display, not a widget: "
                               + "it cannot be clicked or focused, only read.")
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("Profiles carry the mainframe setup as well as "
                               + "colors and effects: the legend, the PF/PA "
                               + "assignments, the key click and bell, the "
                               + "cursor and the line highlight. The built-in "
                               + "\"IUT-MarkazMohasebat\" profile switches all "
                               + "of them on at once.")
                }

                CheckBox {
                    objectName: "shellAliasesCheckBox"
                    text: qsTr("CMS command aliases in the shell profile (FILEL, COPYFILE, ...)")
                    checked: appSettings.shellAliases
                    onCheckedChanged: appSettings.shellAliases = checked
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("One marked block is written to ~/.bashrc "
                               + "(plus ~/.zshrc and the profile files that "
                               + "already exist; on Windows that same file is "
                               + "the Git Bash profile), so FILEL, LISTFILE, "
                               + "COPYFILE, ERASE, RENAME, TYPE, ACCESS, "
                               + "RELEASE and FORMAT work as typed commands. "
                               + "Untick to remove the block.")
                }
            }
        }

        // LEGEND ////////////////////////////////////////////////////////////
        GroupBox {
            title: qsTr("Legend")
            Layout.fillWidth: true
            padding: appSettings.defaultMargin

            GridLayout {
                anchors.fill: parent
                columns: 4
                columnSpacing: 8
                rowSpacing: 6

                // The type first (the face, then the size), colours below.
                Label { text: qsTr("Font"); font.bold: true }
                ComboBox {
                    objectName: "legendFontComboBox"
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    textRole: "text"
                    model: retroTab.legendFontEntries()
                    currentIndex: retroTab.legendFontIndexOf()
                    onActivated: function(index) {
                        appSettings.legendFontFamily =
                                retroTab.legendFontEntries()[index].name
                        // The pick replaced the binding; put it back.
                        currentIndex = Qt.binding(function() {
                            return retroTab.legendFontIndexOf()
                        })
                    }
                }

                Label { text: qsTr("Size"); font.bold: true }
                Slider {
                    objectName: "legendFontScaleSlider"
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    from: 0.4
                    to: 3.0
                    stepSize: 0.05
                    value: appSettings.legendFontScale
                    onValueChanged: {
                        // A drag writes imperatively and replaces the
                        // declared binding; restore it so presets and the
                        // reset button still move this slider.  Changes
                        // that came from the binding itself need neither.
                        if (value === appSettings.legendFontScale)
                            return
                        appSettings.legendFontScale = value
                        value = Qt.binding(function() {
                            return appSettings.legendFontScale
                        })
                    }
                }
                Label {
                    objectName: "legendFontScaleLabel"
                    text: "×" + appSettings.legendFontScale.toFixed(2)
                            + "  (" + Math.round(appSettings.terminalFontPixelSize
                                                 * appSettings.legendFontScale)
                            + " px)"
                }

                Label { text: qsTr("Text"); font.bold: true }
                Label { text: qsTr("Background"); font.bold: true }
                Label { text: qsTr("Arrow  >>"); font.bold: true }
                Label { text: qsTr("Arrow background"); font.bold: true }

                ColorButton {
                    objectName: "legendTextColorButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    name: qsTr("Text")
                    color: retroTab.legendText
                    onColorSelected: function(c) { appSettings.legendTextColor = c }
                }
                ColorButton {
                    objectName: "legendTextBgColorButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    name: qsTr("Background")
                    color: appSettings.legendTextBgColor
                    onColorSelected: function(c) { appSettings.legendTextBgColor = c }
                }
                ColorButton {
                    objectName: "legendArrowColorButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    name: qsTr("Arrow  >>")
                    color: retroTab.legendArrow
                    onColorSelected: function(c) { appSettings.legendArrowColor = c }
                }
                ColorButton {
                    objectName: "legendArrowBgColorButton"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    name: qsTr("Arrow background")
                    color: appSettings.legendArrowBgColor
                    onColorSelected: function(c) { appSettings.legendArrowBgColor = c }
                }

                Label {
                    Layout.columnSpan: 4
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("The on-glass PF/PA legend: its face and "
                               + "size (the screen's own until changed, "
                               + "the size a coefficient of the screen "
                               + "font), and the colours of the key "
                               + "identity, its function and the >> "
                               + "between them. Text colours follow the "
                               + "screen's phosphor until set; the "
                               + "backgrounds are clear until set, so "
                               + "nothing but the words prints.")
                }

                Button {
                    objectName: "resetLegendButton"
                    Layout.columnSpan: 4
                    text: qsTr("Reset the legend to the defaults")
                    onClicked: {
                        appSettings.legendFontFamily = ""
                        appSettings.legendFontScale = 1.0
                        appSettings.legendTextColor = ""
                        appSettings.legendTextBgColor = "#00000000"
                        appSettings.legendArrowColor = ""
                        appSettings.legendArrowBgColor = "#00000000"
                    }
                }
            }
        }

        // PF / PA KEYS ///////////////////////////////////////////////////////
        GroupBox {
            title: qsTr("PF / PA Keys")
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: appSettings.defaultMargin

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: qsTr("Twelve PF keys and three PA keys, as on an IBM "
                               + "3270. A function of \"Off\" hands the key back "
                               + "to the shell untouched. Use %1 and %2 for the "
                               + "window actions the desktop does not already own.")
                        .arg(retroTab.keyMap.nextWindow)
                        .arg(retroTab.keyMap.newWindow)
                }

                Label {
                    objectName: "pfCollisionWarning"
                    visible: retroTab.collisionCount > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: "#e0a030"
                    text: qsTr("%1 key(s) claim the same sequence; only one of "
                               + "them can be recognised.").arg(retroTab.collisionCount)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label { text: qsTr("Key"); font.bold: true; Layout.preferredWidth: 44 }
                    Label { text: qsTr("Sequence"); font.bold: true; Layout.preferredWidth: 110 }
                    Label { text: qsTr("Function"); font.bold: true; Layout.fillWidth: true }
                    Label { text: qsTr("Text"); font.bold: true; Layout.preferredWidth: 150 }
                }

                Repeater {
                    model: retroTab.slotCount

                    delegate: RowLayout {
                        id: slotRow
                        objectName: "pfSlot_" + index

                        Layout.columnSpan: 4
                        Layout.fillWidth: true
                        spacing: 8

                        required property int index

                        readonly property var assignment: index < appSettings.pfAssignments.length
                                ? appSettings.pfAssignments[index] : null
                        readonly property int actionIndex: retroTab.actionIndexOf(assignment)

                        Label {
                            objectName: "pfName_" + slotRow.index
                            text: PfKeys.slotName(slotRow.index)
                            Layout.preferredWidth: 44
                            font.family: "monospace"
                        }

                        TextField {
                            objectName: "pfKey_" + slotRow.index
                            Layout.preferredWidth: 110
                            text: slotRow.assignment ? slotRow.assignment.key : ""
                            onEditingFinished: {
                                var value = text.trim()
                                if (value.length > 0)
                                    retroTab.setSlot(slotRow.index, { key: value })
                                else
                                    text = slotRow.assignment ? slotRow.assignment.key : ""
                            }
                        }

                        ComboBox {
                            objectName: "pfAction_" + slotRow.index
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "id"
                            model: PfKeys.ACTIONS
                            currentIndex: slotRow.actionIndex
                            onActivated: {
                                retroTab.setSlot(slotRow.index, { action: currentValue })
                                // Interacting with a ComboBox writes its index
                                // imperatively and would otherwise drop the
                                // binding, leaving the row stale after a reset.
                                currentIndex = Qt.binding(function() {
                                    return slotRow.actionIndex
                                })
                            }
                        }

                        TextField {
                            objectName: "pfPayload_" + slotRow.index
                            Layout.preferredWidth: 150
                            visible: slotRow.assignment && slotRow.assignment.action === "sendText"
                            placeholderText: qsTr("e.g. ls -la\\n")
                            text: slotRow.assignment ? slotRow.assignment.payload : ""
                            onEditingFinished: retroTab.setSlot(slotRow.index, { payload: text })
                        }
                    }
                }

                Button {
                    objectName: "resetPfKeysButton"
                    text: qsTr("Reset PF/PA keys to defaults")
                    onClicked: appSettings.resetPfAssignments()
                }
            }
        }

        // SOUND now lives with the general options: it is a keyboard /
        // feedback choice, not part of the look (SettingsGeneralTab).

        // CURSOR AND ACTIVE LINE /////////////////////////////////////////////
        GroupBox {
            title: qsTr("Cursor and active line")
            Layout.fillWidth: true
            padding: appSettings.defaultMargin

            GridLayout {
                anchors.fill: parent
                columns: 3
                columnSpacing: 8
                rowSpacing: 6

                CheckBox {
                    objectName: "highlightActiveLineCheckBox"
                    Layout.columnSpan: 3
                    text: qsTr("Highlight the active line (the row the cursor is on)")
                    checked: appSettings.highlightActiveLine
                    onCheckedChanged: appSettings.highlightActiveLine = checked
                }

                Label { text: qsTr("Highlight strength") }
                Slider {
                    id: activeLineOpacity
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    enabled: appSettings.highlightActiveLine
                    from: 0.0
                    to: 1.0
                    stepSize: 0.01
                    value: appSettings.activeLineOpacity
                    onValueChanged: appSettings.activeLineOpacity = value
                }

                Label { text: qsTr("Cursor shape") }
                ComboBox {
                    objectName: "cursorStyleComboBox"
                    Layout.columnSpan: 2
                    Layout.preferredWidth: 180
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { label: qsTr("Block (3270 / PC BIOS)"), value: "block" },
                        { label: qsTr("Half block"), value: "half" }
                    ]
                    currentIndex: appSettings.cursorStyle === "half" ? 1 : 0
                    onActivated: appSettings.cursorStyle = currentValue
                }
            }
        }
    }
}
