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
import QtQml.Models

import "logic/chrome.js" as Chrome

Item {
    id: tabsRoot

    readonly property int innerPadding: 6
    readonly property string currentTitle: tabsModel.get(currentIndex).title ?? "nostalgic-terminal"
    property alias currentIndex: tabBar.currentIndex
    readonly property int count: tabsModel.count
    property size terminalSize: Qt.size(0, 0)

    // The tab strip is chrome: nostalgic mode never shows it, however many
    // tabs are open.  The PF legend is NOT chrome -- it is printed on the
    // glass of every pane (see PreprocessedTerminal.qml) and follows
    // showPfKeys alone, in every mode.
    readonly property var chrome: Chrome.visibility({
        nostalgicMode: appSettings.nostalgicMode,
        tabCount: tabsModel.count
    })

    /**
     * Hand `text` to whichever terminal is showing.  Returns true when it
     * was delivered; used by the IBM PA keys, by PF macros and by the
     * HELP box.
     */
    function sendTextToCurrent(text) {
        if (!text)
            return false

        for (var i = 0; i < stack.children.length; i++) {
            var child = stack.children[i]
            if (child && child.isActive && typeof child.sendText === "function")
                return child.sendText(text)
        }
        return false
    }

    /** A pane typed a HELP topic into its PF panel: carry it to the window. */
    signal helpSubmitted(string topic)

    /**
     * Ask the tab that is showing to make its PF HELP cell editable.
     * Returns false when nothing took it (legend not printed), so the
     * caller can open the dialog instead.
     */
    function requestHelpInput() {
        for (var i = 0; i < stack.children.length; i++) {
            var child = stack.children[i]
            if (child && child.isActive
                    && typeof child.requestHelpInput === "function")
                return child.requestHelpInput()
        }
        return false
    }

    function normalizeTitle(rawTitle) {
        if (rawTitle === undefined || rawTitle === null) {
            return ""
        }
        return String(rawTitle).trim()
    }

    function addTab() {
        tabsModel.append({ title: "", split: 0 })
        tabBar.currentIndex = tabsModel.count - 1
    }

    function closeTab(index) {
        if (tabsModel.count <= 1) {
            terminalWindow.close()
            return
        }

        tabsModel.remove(index)
        tabBar.currentIndex = Math.min(tabBar.currentIndex, tabsModel.count - 1)
    }

    /**
     * Toggle a split of the current tab, the way ISPF's F2 SPLIT did:
     * `orientation` 1 puts the panes side by side (vertical rule), 2 stacks
     * them (horizontal rule).  Asking again for the split already showing
     * folds the second pane away.
     */
    function split(orientation) {
        if (tabsModel.count <= 0 || currentIndex < 0)
            return
        var current = tabsModel.get(currentIndex).split
        tabsModel.setProperty(currentIndex, "split",
                              current === orientation ? 0 : orientation)
    }

    ListModel {
        id: tabsModel
    }

    Component.onCompleted: {
        // Fires terminalFontChanged right away, so the mirrored screen font
        // (and with it the PF panel) is correct from the very first frame.
        appSettings.fontManager.refresh()
        addTab()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: tabRow
            Layout.fillWidth: true
            height: rowLayout.implicitHeight
            color: palette.window
            visible: chrome.tabBar

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                spacing: 0

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focusPolicy: Qt.NoFocus

                    Repeater {
                        model: tabsModel
                        TabButton {
                            id: tabButton
                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors { leftMargin: innerPadding; rightMargin: innerPadding }
                                spacing: innerPadding

                                Label {
                                    text: model.title
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ToolButton {
                                    text: "\u00d7"
                                    focusPolicy: Qt.NoFocus
                                    padding: innerPadding
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: tabsRoot.closeTab(index)
                                }
                            }
                        }
                    }
                }

                ToolButton {
                    id: addTabButton
                    text: "+"
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: tabsRoot.addTab()
                }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Repeater {
                model: tabsModel

                // One tab: one CRT unit, optionally divided into panes.
                Item {
                    id: group

                    /** 0 = one pane, 1 = side by side, 2 = stacked. */
                    property int split: model.split
                    /** The pane that owns the keyboard in this tab. */
                    property int activePane: 0
                    readonly property int paneCount: split > 0 ? 2 : 1
                    readonly property bool isCurrentItem: StackLayout.isCurrentItem
                    /** What TerminalTabs.sendTextToCurrent() looks for. */
                    readonly property bool isActive: isCurrentItem
                    readonly property int ruleOrientation:
                        split === 2 ? Qt.Vertical : Qt.Horizontal
                    property string title: ""

                    /** The active shell ended: the tab goes with it. */
                    signal tabSessionFinished()

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    onTabSessionFinished: tabsRoot.closeTab(index)
                    onSplitChanged: {
                        if (activePane >= paneCount)
                            activePane = 0
                    }
                    onActivePaneChanged: {
                        report()
                        refreshTitle()
                    }
                    onIsCurrentItemChanged: report()
                    onTitleChanged: tabsModel.setProperty(index, "title", title)
                    Component.onCompleted: refreshTitle()

                    /** Which pane does this focus item belong to? */
                    function paneOf(item) {
                        while (item) {
                            if (item === paneRepeater.itemAt(0))
                                return 0
                            if (paneCount > 1 && item === paneRepeater.itemAt(1))
                                return 1
                            item = item.parent
                        }
                        return -1
                    }

                    /** Clicking or focusing a pane makes it the active one. */
                    function syncActivePane() {
                        var p = paneOf(terminalWindow.activeFocusItem)
                        if (p >= 0 && p < paneCount && p !== activePane)
                            activePane = p
                    }

                    Connections {
                        target: terminalWindow
                        function onActiveFocusItemChanged() {
                            group.syncActivePane()
                        }
                    }

                    function activeContainer() {
                        return paneRepeater.itemAt(activePane)
                    }

                    function report() {
                        if (!isCurrentItem)
                            return
                        var c = activeContainer()
                        if (c)
                            tabsRoot.terminalSize = c.terminalSize
                    }

                    function refreshTitle() {
                        var c = activeContainer()
                        title = c ? normalizeTitle(c.title) : ""
                    }

                    /** Text goes to whichever pane is active. */
                    function sendText(t) {
                        var c = activeContainer()
                        return c ? c.sendText(t) : false
                    }

                    /** Open the active pane's PF HELP cell for typing. */
                    function requestHelpInput() {
                        var c = activeContainer()
                        return c ? c.requestHelpInput() : false
                    }

                    /**
                     * The picture this tab shows: the panes and their
                     * dividing rule.  It is not displayed directly -- the
                     * CRT unit below samples it as one texture, so the
                     * curved frame around the terminal never splits with
                     * the panes (see CrtUnit.qml).
                     */
                    Item {
                        id: stage
                        anchors.fill: parent

                        GridLayout {
                            anchors.fill: parent
                            // GridLayout is the one that can switch axis: side
                            // by side (vertical rule) or stacked (horizontal
                            // rule).  One column per pane when horizontal, a
                            // single column -- and a single pane gets the whole
                            // unit -- when it is not divided at all.
                            flow: group.split === 2 ? GridLayout.TopToBottom
                                                    : GridLayout.LeftToRight
                            columns: group.split === 2 ? 1 : group.paneCount
                            columnSpacing: 0
                            rowSpacing: 0

                            Repeater {
                                id: paneRepeater
                                model: group.paneCount

                                TerminalPane {
                                    property bool shouldHaveFocus: terminalWindow.active
                                            && group.isCurrentItem
                                            && group.activePane === index
                                    isActive: group.isCurrentItem && group.activePane === index
                                    // The unit's shader curves the whole
                                    // stage at once: the pane needs its
                                    // geometry to map clicks correctly.
                                    warpSurface: stage
                                    warpVirtualSize: crt.contentVirtualResolution
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    onHelpSubmitted: function(topic) {
                                        tabsRoot.helpSubmitted(topic)
                                    }
                                    onShouldHaveFocusChanged: {
                                        if (shouldHaveFocus) {
                                            activate()
                                        }
                                    }

                                    onImagePainted: crt.notePaint()
                                    onTitleChanged: group.refreshTitle()
                                    onTerminalSizeChanged: group.report()
                                    onSessionFinished: {
                                        // The primary shell gone takes the tab
                                        // with it (exactly as it always did); a
                                        // secondary pane simply folds back.
                                        if (index === 0 || group.paneCount === 1)
                                            group.tabSessionFinished()
                                        else
                                            group.split = 0
                                    }
                                }
                            }
                        }

                        /** The rule dividing the panes, drawn on the seam. */
                        Rectangle {
                            visible: group.split > 0
                            z: 1
                            color: appSettings.fontColor
                            opacity: 0.5
                            width: group.ruleOrientation === Qt.Horizontal ? 1 : group.width
                            height: group.ruleOrientation === Qt.Vertical ? 1 : group.height
                            x: group.ruleOrientation === Qt.Horizontal ? (group.width - 1) / 2 : 0
                            y: group.ruleOrientation === Qt.Vertical ? (group.height - 1) / 2 : 0
                        }
                    }

                    /**
                     * The one monitor this tab is displayed through: one
                     * curvature, one bezel, one set of screen effects --
                     * whole even when the picture inside is divided.
                     */
                    CrtUnit {
                        id: crt
                        anchors.fill: parent
                        contentStage: stage

                        // The panes tile the stage, so the virtual picture
                        // is the panes summed along the split axis.
                        //
                        // paneRepeater.count is read FIRST, deliberately:
                        // on the initial evaluation no delegate exists yet,
                        // and a binding that early-returns having touched
                        // only locals subscribes to nothing -- it would stay
                        // pinned to the 1x1 placeholder forever and the
                        // screen would stay black.  count changes exactly
                        // when delegates appear, so reading it guarantees a
                        // re-evaluation once itemAt() can work.
                        contentVirtualResolution: {
                            var n = paneRepeater.count
                            var p0 = paneRepeater.itemAt(0)
                            if (!p0)
                                return Qt.size(1, 1)
                            var v0 = p0.virtualResolution
                            if (n < 2)
                                return v0
                            var p1 = paneRepeater.itemAt(1)
                            if (!p1)
                                return v0
                            var v1 = p1.virtualResolution
                            return group.split === 2
                                    ? Qt.size(Math.max(v0.width, v1.width),
                                              v0.height + v1.height)
                                    : Qt.size(v0.width + v1.width,
                                              Math.max(v0.height, v1.height))
                        }
                        contentScale: {
                            var n = paneRepeater.count
                            var p0 = paneRepeater.itemAt(0)
                            if (!p0)
                                return 1
                            if (n < 2)
                                return p0.scaleTexture
                            var p1 = paneRepeater.itemAt(1)
                            return p1 ? Math.max(p0.scaleTexture, p1.scaleTexture)
                                      : p0.scaleTexture
                        }
                    }
                }
            }
        }

    }
}
