/*******************************************************************************
* The off-side IBM PF / PA key panel: character text, never buttons.
*
* It is rendered the way a mainframe showed its function-key legend: rows
* and columns of monospace text, "PF4>>NEXT WINDOW", the key identity in
* bold against the plain label, with the arrow glued to the words it sits
* between -- no caps beyond the legend itself, no rectangles, no borders --
* in the same face and the same horizontal pitch as the terminal (family,
* size and width arrive from ApplicationSettings' mirror of the computed
* screen font), at a size the caller sets as a coefficient of that font:
* the application binds the screen's own size (1.0) from the legend
* settings, while this component's own default (0.8) keeps the unbound
* panel the footnote of the machine it has always been rather than
* output.
*
* It is part of the monitor but never part of the screen: it prints into
* the strip legendReserve carves off the PTY grid (see
* PreprocessedTerminal.qml), so the cursor cannot reach it and no program
* output can scroll under it.  Deliberately built from Item, Row,
* GridLayout, Text and (only when a colour is set for them) background
* Rectangles: no MouseArea, no focus handling -- reachable by eye, never
* by cursor or keyboard.  The backgrounds are clear by default, so the
* default panel is still nothing but text on the glass.
*
* One exception, and only while it lasts: pressing the Help key makes the
* HELP cell editable (beginHelpInput), so the topic is typed right into
* the PF1 area on the glass, 20 characters at most.  The field itself
* lives behind a Loader, so the idle panel still exposes nothing
* focusable or clickable at all.
*
* Self contained on purpose: it reads no application globals (styling and
* state arrive as properties), which lets the Qt Quick test suite
* instantiate it on its own.
*******************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "logic/pfkeys.js" as PfKeys

Item {
    id: root

    /** Normalized assignment array (see logic/pfkeys.js). */
    property var model: []

    /** Phosphor styling, bound by the caller so this file stays global free. */
    property color textColor: "#ff8100"

    /**
     * Legend colours, on top of the phosphor text.  Both backgrounds are
     * clear by default: a default panel prints exactly the text it always
     * did, straight onto the glass.  Set one and a chip of that colour is
     * painted behind the words (see the delegate below).
     */
    property color textBgColor: "#00000000"
    /** The ">>": its own colour, shading the text's down to 60% by default. */
    property color arrowColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
    property color arrowBgColor: "#00000000"

    /** Background of the inline help field: the glass behind the panel. */
    property color inputBgColor: "#000000"

    /** When false only the key identity (PF1..PA1) is shown. */
    property bool showLegends: true

    /** Live state of the key click: the "Key Sound" legend prints it. */
    property bool keySoundOn: true

    /** The screen's computed font, so every cell is one screen character. */
    property string fontFamily: "monospace"
    property real fontPixelSize: 12
    /** Horizontal glyph stretch of the screen font (1 = unstretched). */
    property real fontWidth: 1.0

    /**
     * How large the panel prints against the screen it belongs to, as a
     * coefficient of the screen font's pixel size: 1.0 is the screen's
     * own size, below that a footnote.  The application binds its legend
     * setting here; the bare default (0.8) keeps the unbound component
     * the smaller legend it has always been.  Everything drawn here uses
     * this scaled size.
     */
    property real fontScale: 0.8
    readonly property real cellPixelSize: Math.max(6,
                                                    Math.round(fontPixelSize * fontScale))

    /** Tabular metrics, kept tight so the panel stays out of the way. */
    property real columnSpacing: 8
    property real rowSpacing: 2
    property real topBottomPadding: 3
    property real sidePadding: 6

    /** True while the HELP cell is the inline topic field. */
    property bool helpInputActive: false

    /**
     * The live topic field, registered by itself as it comes up (an id
     * inside the delegate cannot be seen from out here).  Null whenever
     * the panel is closed.
     */
    property Item helpInputField: null

    /** The topic typed into the HELP cell ("" lists every manual page). */
    signal helpSubmitted(string topic)

    /** The HELP cell was dismissed without sending anything. */
    signal helpCanceled()

    readonly property int count: (model && model.length !== undefined) ? model.length : 0

    /**
     * The slots that actually claim a key: only those belong on the panel,
     * exactly like a real PF display, which never lists an unassigned key.
     */
    readonly property var cells: buildCells()

    /** Nothing assigned -> nothing to print -> the panel disappears. */
    readonly property bool empty: cells.length === 0

    /** The cell printed as HELP: the one that turns into the topic field. */
    readonly property int helpSlot: {
        for (var i = 0; i < cells.length; i++) {
            if (cells[i].action === "help")
                return cells[i].slot
        }
        return -1
    }

    visible: !empty
    implicitHeight: empty ? 0 : grid.implicitHeight + topBottomPadding * 2
    implicitWidth: empty ? 0 : grid.implicitWidth + sidePadding * 2

    /** Widest cell, in characters -- drives how many columns fit. */
    readonly property int widestChars: {
        var w = 1
        for (var i = 0; i < cells.length; i++) {
            var c = cells[i]
            // name + ">>" + legend, the arrow having no spaces of its own.
            var chars = c.name.length + 2 + c.legend.length
            if (chars > w)
                w = chars
        }
        return w
    }

    /** Extra advance per character, matching the screen's glyph stretch. */
    readonly property real advanceExtra: {
        if (fontWidth === 1 || widestChars < 2)
            return 0
        var advance = probe.implicitWidth / widestChars
        return advance * (fontWidth - 1)
    }

    /** One character of the panel, glyph pitch and stretch included. */
    readonly property real charPitch: widestChars > 0
            ? probe.implicitWidth / widestChars + advanceExtra : cellPixelSize

    /** Columns that fit the available width without squeezing a cell. */
    readonly property int fitColumns: Math.max(
        1, Math.min(cells.length,
                     Math.floor(width / Math.max(1, probe.implicitWidth * fontWidth + columnSpacing))))

    function buildCells() {
        var out = []
        if (!model)
            return out
        for (var i = 0; i < model.length; i++) {
            var a = model[i]
            if (!PfKeys.intercepts(a))
                continue
            out.push({
                slot: i,
                name: (a && a.label) ? String(a.label) : PfKeys.slotName(i),
                action: (a && a.action) ? String(a.action) : "pass",
                legend: legendFor(a)
            })
        }
        return out
    }

    /** Legend text for one slot, or "" when nothing may be shown. */
    function legendFor(assignment) {
        if (!showLegends)
            return ""
        // The sound key prints its live state, like a real panel light.
        if (assignment && assignment.action === "toggleKeySound")
            return keySoundOn ? "Sound On" : "Sound Off"
        return PfKeys.legend(assignment)
    }

    /**
     * The Help key (PF1 by factory): swap the HELP cell for a text field
     * and take the keyboard, so the topic is typed on the glass itself.
     * Refuses when the panel is not printed or holds no HELP cell -- the
     * caller then falls back to the dialog.
     */
    function beginHelpInput() {
        if (!visible || empty || helpSlot < 0)
            return false
        if (helpInputActive && helpInputField) {
            helpInputField.forceActiveFocus()
        } else {
            helpInputActive = true
            // The fresh field focuses itself as it comes up.
        }
        return true
    }

    /** Dismiss the field without sending anything; keyboard goes back. */
    function cancelHelpInput() {
        if (!helpInputActive)
            return
        releaseHelpField()
        helpCanceled()
    }

    /** The topic is complete: close the field and hand it up. */
    function finishHelpInput(topic) {
        if (!helpInputActive)
            return
        releaseHelpField()
        helpSubmitted(topic)
    }

    /**
     * Let the keyboard go before the field dies: the Loader is a focus
     * scope, and a focus scope happily keeps claiming the keyboard even
     * after its child is gone -- which would leave the idle panel with a
     * focus claim after the very first use.
     */
    function releaseHelpField() {
        var field = helpInputField
        if (field) {
            field.focus = false
            // The field's parent is the Loader itself: clear the scope.
            if (field.parent)
                field.parent.focus = false
        }
        helpInputActive = false
        helpInputField = null
    }

    /** Off-screen measurer: one monospace glyph count, at the panel size. */
    Text {
        id: probe
        visible: false
        text: new Array(root.widestChars + 1).join("M")
        font.family: root.fontFamily
        font.pixelSize: root.cellPixelSize
    }

    GridLayout {
        id: grid
        objectName: "pfGrid"
        anchors.centerIn: parent
        columns: root.fitColumns
        columnSpacing: root.columnSpacing
        rowSpacing: root.rowSpacing

        Repeater {
            model: root.cells

            delegate: Row {
                id: cell
                objectName: "pfCell_" + modelData.slot
                spacing: 0

                /** This cell is currently the inline topic field. */
                readonly property bool editing: root.helpInputActive
                        && modelData.slot === root.helpSlot

                // The key identity: the highlighted / bold part.  Each of
                // the three parts sits on an item of exactly its own text
                // metrics, so a clear chip changes nothing about the
                // compact, tabular print -- and a painted one stops right
                // at the words.
                Item {
                    width: nameText.implicitWidth
                    height: nameText.implicitHeight

                    Rectangle {
                        objectName: "pfNameBg_" + modelData.slot
                        anchors.fill: parent
                        visible: root.textBgColor.a > 0
                        color: root.textBgColor
                    }
                    Text {
                        id: nameText
                        objectName: "pfName_" + modelData.slot
                        anchors.fill: parent
                        text: modelData.name
                        color: root.textColor
                        font.family: root.fontFamily
                        font.pixelSize: root.cellPixelSize
                        font.letterSpacing: root.advanceExtra
                        font.bold: true
                    }
                }
                // Mainframe panel arrow, glued to the words on both sides.
                Item {
                    id: arrowPart
                    visible: modelData.legend.length > 0 && !cell.editing
                    width: arrowText.implicitWidth
                    height: arrowText.implicitHeight

                    Rectangle {
                        objectName: "pfArrowBg_" + modelData.slot
                        anchors.fill: parent
                        visible: root.arrowBgColor.a > 0
                        color: root.arrowBgColor
                    }
                    Text {
                        id: arrowText
                        objectName: "pfArrow_" + modelData.slot
                        visible: arrowPart.visible
                        anchors.fill: parent
                        text: ">>"
                        color: root.arrowColor
                        font.family: root.fontFamily
                        font.pixelSize: root.cellPixelSize
                        font.letterSpacing: root.advanceExtra
                    }
                }
                // The function itself, in screen capitals.
                Item {
                    id: legendPart
                    visible: modelData.legend.length > 0 && !cell.editing
                    width: legendText.implicitWidth
                    height: legendText.implicitHeight

                    Rectangle {
                        objectName: "pfLegendBg_" + modelData.slot
                        anchors.fill: parent
                        visible: root.textBgColor.a > 0
                        color: root.textBgColor
                    }
                    Text {
                        id: legendText
                        objectName: "pfLegend_" + modelData.slot
                        visible: legendPart.visible
                        anchors.fill: parent
                        text: modelData.legend.toUpperCase()
                        color: root.textColor
                        opacity: 0.9
                        font.family: root.fontFamily
                        font.pixelSize: root.cellPixelSize
                        font.letterSpacing: root.advanceExtra
                    }
                }
                // The HELP cell, opened for business: a field right on
                // the glass.  Behind a Loader, so an idle panel still
                // contains nothing focusable or clickable at all.
                Loader {
                    id: helpInputLoader
                    active: cell.editing
                    visible: active

                    sourceComponent: TextField {
                        id: helpField
                        objectName: "pfHelpInput"
                        width: root.charPitch * 14
                        maximumLength: 20
                        font.family: root.fontFamily
                        font.pixelSize: root.cellPixelSize
                        font.letterSpacing: root.advanceExtra
                        color: root.textColor
                        selectionColor: root.textColor
                        selectedTextColor: root.inputBgColor
                        placeholderText: qsTr("topic")
                        placeholderTextColor: Qt.rgba(0.6, 0.6, 0.6, 0.8)
                        background: Rectangle {
                            color: root.inputBgColor
                            border.color: root.textColor
                            border.width: 1
                            opacity: 0.92
                        }
                        focus: true
                        Component.onCompleted: {
                            root.helpInputField = helpField
                            forceActiveFocus()
                        }
                        Component.onDestruction: {
                            if (root.helpInputField === helpField)
                                root.helpInputField = null
                        }
                        onAccepted: root.finishHelpInput(text)
                        Keys.onEscapePressed: function(event) {
                            root.cancelHelpInput()
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}
