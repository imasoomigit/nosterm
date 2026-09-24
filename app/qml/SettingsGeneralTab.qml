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
import QtQuick 2.2
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.1
import QtQuick.Dialogs

ColumnLayout {
    GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        title: qsTr("Profile")
        padding: appSettings.defaultMargin
        RowLayout {
            anchors.fill: parent
            ListView {
                id: profilesView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: appSettings.profilesList
                clip: true
                delegate: Rectangle {
                    width: label.width
                    height: label.height
                    color: (index == profilesView.currentIndex) ? palette.highlight : palette.base
                    readonly property string profileName: model.text
                    readonly property bool isDefault: appSettings.defaultProfileName !== ""
                            && appSettings.defaultProfileName === profileName
                    readonly property bool isActive: appSettings.activeProfileName === profileName
                    Label {
                        id: label
                        text: parent.profileName
                                + (parent.isDefault ? qsTr(" (default)") : "")
                                + (parent.isActive ? qsTr(" (active)") : "")
                        MouseArea {
                            anchors.fill: parent
                            onClicked: profilesView.currentIndex = index
                            onDoubleClicked: appSettings.loadProfile(index)
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: false
                Button {
                    Layout.fillWidth: true
                    // Overwrites the active profile (the loaded one, or
                    // the default): no name is ever asked for again.  The
                    // prompt appears only when nothing is active yet --
                    // the very first Save -- and its answer becomes the
                    // active profile, so it too is a one-off.
                    text: qsTr("Save")
                    onClicked: {
                        if (!appSettings.saveActiveProfile()) {
                            insertname.profileName = ""
                            insertname.show()
                        }
                    }
                }
                Button {
                    Layout.fillWidth: true
                    property alias currentIndex: profilesView.currentIndex
                    readonly property string profileName: currentIndex >= 0
                            ? appSettings.profilesList.get(currentIndex).text : ""
                    readonly property bool isDefault: profileName !== ""
                            && appSettings.defaultProfileName === profileName
                    enabled: profileName !== ""
                    // Every future start opens on this profile; pressing
                    // it again on the same profile takes that away.
                    text: isDefault ? qsTr("Unset Default") : qsTr("Set as Default")
                    onClicked: appSettings.setDefaultProfile(isDefault
                                                              ? "" : profileName)
                }
                Button {
                    Layout.fillWidth: true
                    property alias currentIndex: profilesView.currentIndex
                    readonly property string profileName: currentIndex >= 0
                            ? appSettings.profilesList.get(currentIndex).text : ""
                    readonly property bool isBuiltin: profileName !== ""
                            && appSettings.profilesList.get(currentIndex).builtin
                    // Built-ins carry their factory copy: Save may have
                    // overwritten it, Reset puts the shipped values back.
                    enabled: isBuiltin
                    text: qsTr("Reset")
                    onClicked: appSettings.resetProfile(profileName)
                }
                Button {
                    Layout.fillWidth: true
                    property alias currentIndex: profilesView.currentIndex
                    enabled: currentIndex >= 0
                    text: qsTr("Load")
                    onClicked: {
                        var index = currentIndex
                        if (index >= 0)
                            appSettings.loadProfile(index)
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Remove")
                    property alias currentIndex: profilesView.currentIndex

                    enabled: currentIndex >= 0 && !appSettings.profilesList.get(
                                 currentIndex).builtin
                    onClicked: {
                        // Releases the active/default markers it carries.
                        appSettings.removeProfile(currentIndex)
                        profilesView.selection.clear()

                        // TODO This is a very ugly workaround. The view didn't update on Qt 5.3.2.
                        profilesView.model = 0
                        profilesView.model = appSettings.profilesList
                    }
                }
                Item {
                    // Spacing
                    Layout.fillHeight: true
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Import")
                    onClicked: {
                        fileDialog.selectExisting = true
                        fileDialog.callBack = function (url) {
                            loadFile(url)
                        }
                        fileDialog.open()
                    }
                    function loadFile(url) {
                        try {
                            if (appSettings.verbose)
                                console.log("Loading file: " + url)

                            var profileObject = JSON.parse(fileIO.read(url))
                            var name = profileObject.name

                            if (!name)
                                throw "Profile doesn't have a name"

                            var version = profileObject.version
                                    !== undefined ? profileObject.version : 1
                            if (version !== appSettings.profileVersion)
                                throw "This profile is not supported on this version of CRT."

                            delete profileObject.name

                            appSettings.appendCustomProfile(name,
                                                            JSON.stringify(
                                                                profileObject))
                        } catch (err) {
                            messageDialog.text = qsTr(err)
                            messageDialog.open()
                        }
                    }
                }
                Button {
                    property alias currentIndex: profilesView.currentIndex

                    Layout.fillWidth: true

                    text: qsTr("Export")
                    enabled: currentIndex >= 0 && !appSettings.profilesList.get(
                                 currentIndex).builtin
                    onClicked: {
                        fileDialog.selectExisting = false
                        fileDialog.callBack = function (url) {
                            storeFile(url)
                        }
                        fileDialog.open()
                    }
                    function storeFile(url) {
                        try {
                            var urlString = url.toString()

                            // Fix the extension if it's missing.
                            var extension = urlString.substring(
                                        urlString.length - 5, urlString.length)
                            var urlTail = (extension === ".json" ? "" : ".json")
                            url += urlTail

                            if (true)
                                console.log("Storing file: " + url)

                            var profileObject = appSettings.profilesList.get(
                                        currentIndex)
                            var profileSettings = JSON.parse(
                                        profileObject.obj_string)
                            profileSettings["name"] = profileObject.text
                            profileSettings["version"] = appSettings.profileVersion

                            var result = fileIO.write(url, JSON.stringify(
                                                          profileSettings,
                                                          undefined, 2))
                            if (!result)
                                throw "The file could not be written."
                        } catch (err) {
                            console.log(err)
                            messageDialog.text = qsTr(
                                        "There has been an error storing the file.")
                            messageDialog.open()
                        }
                    }
                }
            }
        }
    }

    GroupBox {
        title: qsTr("Screen")
        Layout.fillWidth: true
        padding: appSettings.defaultMargin
        GridLayout {
            anchors.fill: parent
            columns: 2
            Label {
                text: qsTr("Brightness")
            }
            SimpleSlider {
                onValueChanged: appSettings.brightness = value
                value: appSettings.brightness
            }
            Label {
                text: qsTr("Contrast")
            }
            SimpleSlider {
                onValueChanged: appSettings.contrast = value
                value: appSettings.contrast
            }
            Label {
                text: qsTr("Margin")
            }
            SimpleSlider {
                onValueChanged: appSettings._margin = value
                value: appSettings._margin
            }
            Label {
                text: qsTr("Radius")
            }
            SimpleSlider {
                onValueChanged: appSettings._screenRadius = value
                value: appSettings._screenRadius
            }
            Label {
                text: qsTr("Frame size")
            }
            SimpleSlider {
                onValueChanged: appSettings._frameSize = value
                value: appSettings._frameSize
            }
            Label {
                text: qsTr("Opacity")
                visible: !appSettings.isMacOS
            }
            SimpleSlider {
                onValueChanged: appSettings.windowOpacity = value
                value: appSettings.windowOpacity
                visible: !appSettings.isMacOS
            }
        }
    }

    // SOUND ////////////////////////////////////////////////////////////////
    // Feedback, not looks: which tick the keyboard makes, and how loud the
    // two switches are.  Moved here from the retro (look) tab so every
    // audible choice sits with the other general options.
    GroupBox {
        title: qsTr("Sound")
        Layout.fillWidth: true
        padding: appSettings.defaultMargin

        GridLayout {
            anchors.fill: parent
            columns: 3
            columnSpacing: 8
            rowSpacing: 6

            CheckBox {
                objectName: "audioEnabledCheckBox"
                Layout.columnSpan: 3
                text: qsTr("Enable audible feedback")
                checked: appSettings.audioEnabled
                onCheckedChanged: appSettings.audioEnabled = checked
            }

            Label {
                text: qsTr("Keyboard tick sound")
            }
            ComboBox {
                objectName: "keyClickSoundComboBox"
                Layout.columnSpan: 2
                Layout.fillWidth: true
                textRole: "label"
                valueRole: "value"
                // Disabled is the click switch off; the three samples are
                // the bundled depths of one dry thunk (logic/sound.js).
                model: [
                    { label: qsTr("Disabled"), value: "off" },
                    { label: qsTr("Tick"), value: "tick" },
                    { label: qsTr("Deep"), value: "deep" },
                    { label: qsTr("Deeper"), value: "deeper" }
                ]
                currentIndex: tickSoundIndex()
                onActivated: function(index) {
                    var value = model[index].value
                    if (value === "off") {
                        appSettings.keyClick = false
                    } else {
                        // Picking a sample is how you audition it: arm the
                        // click and open the master gate, exactly as the
                        // View menu's toggle does, so the pick is audible.
                        appSettings.keyClickSound = value
                        appSettings.keyClick = true
                        appSettings.audioEnabled = true
                    }
                    // The interaction replaced the binding; put it back.
                    currentIndex = Qt.binding(function() { return tickSoundIndex() })
                }

                function tickSoundIndex() {
                    if (!appSettings.keyClick)
                        return 0
                    if (appSettings.keyClickSound === "deep")
                        return 2
                    if (appSettings.keyClickSound === "deeper")
                        return 3
                    return 1
                }
            }

            CheckBox {
                objectName: "keyClickCheckBox"
                text: qsTr("Key click")
                enabled: appSettings.audioEnabled
                checked: appSettings.keyClick
                onCheckedChanged: appSettings.keyClick = checked
            }
            Slider {
                id: keyClickVolume
                Layout.fillWidth: true
                Layout.columnSpan: 2
                enabled: appSettings.audioEnabled && appSettings.keyClick
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: appSettings.keyClickVolume
                onValueChanged: appSettings.keyClickVolume = value
            }

            CheckBox {
                objectName: "bellCheckBox"
                text: qsTr("Terminal bell")
                enabled: appSettings.audioEnabled
                checked: appSettings.bell
                onCheckedChanged: appSettings.bell = checked
            }
            Slider {
                id: bellVolume
                Layout.fillWidth: true
                Layout.columnSpan: 2
                enabled: appSettings.audioEnabled && appSettings.bell
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: appSettings.bellVolume
                onValueChanged: appSettings.bellVolume = value
            }
        }
    }

    // DIALOGS ////////////////////////////////////////////////////////////////
    InsertNameDialog {
        id: insertname
        // Only reached when no profile is active at all (first Save):
        // the name collected here becomes the active profile, so every
        // Save after it silently overwrites that profile instead.
        onNameSelected: appSettings.saveAsNewProfile(name)
    }
    MessageDialog {
        id: messageDialog
        title: qsTr("File Error")
        buttons: MessageDialog.Ok
        onAccepted: {
            messageDialog.close()
        }
    }
    Loader {
        property var callBack
        property bool selectExisting: false
        id: fileDialog

        sourceComponent: FileDialog {
            nameFilters: ["Json files (*.json)"]
            fileMode: fileDialog.selectExisting ? FileDialog.OpenFile : FileDialog.SaveFile
            onAccepted: callBack(selectedFile)
        }

        onSelectExistingChanged: reload()

        function open() {
            item.open()
        }

        function reload() {
            active = false
            active = true
        }
    }
}
