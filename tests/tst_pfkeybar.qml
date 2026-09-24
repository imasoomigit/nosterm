/*******************************************************************************
* Qt Quick test: the off-side IBM PF / PA legend.
*
* Two contracts are asserted here:
*   1. it prints one TEXT cell per assigned slot with the right identity and
*      function (in screen capitals, like a real PF panel), leaves the
*      unassigned keys off the panel, hides itself when there is nothing to
*      show -- and never draws a single button rectangle (no pfCap_* at all);
*      the print is compact (smaller than the screen, arrow glued to the
*      words) so it never falls out of the frame;
*   2. it is reachable by eye only: no descendant can be clicked or hovered,
*      no descendant holds the keyboard, and clicking on it leaves focus
*      exactly where it was -- except while the HELP cell is deliberately
*      open for typing, which is asserted separately.
*******************************************************************************/
import QtQuick
import QtTest

import "../app/qml" as App
import "../app/qml/logic/pfkeys.js" as PfKeys
import "helpers.js" as Helpers

Rectangle {
    id: host
    width: 640
    height: 200
    color: "black"

    // Stand-in for the widget that owns the keyboard: the legend must never
    // take it away.
    TextInput {
        id: probe
        objectName: "focusProbe"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 30
        focus: true
        color: "white"
        font.family: "monospace"
    }

    App.PfKeyBar {
        id: bar
        objectName: "pfKeyBar"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        model: PfKeys.defaultAssignments()
        fontFamily: "monospace"
        fontPixelSize: 12
    }

    // The HELP cell shouts its topic up the chain when Enter is pressed.
    SignalSpy {
        id: helpSpy
        target: bar
        signalName: "helpSubmitted"
    }

    TestCase {
        name: "PfKeyBarTests"
        when: windowShown

        function init() {
            bar.model = PfKeys.defaultAssignments()
            bar.showLegends = true
            bar.keySoundOn = true
            bar.fontScale = 0.8
            bar.cancelHelpInput()
            // Colours back to the factory print: phosphor text, clear chips.
            bar.textBgColor = "#00000000"
            bar.arrowBgColor = "#00000000"
            bar.arrowColor = Qt.rgba(bar.textColor.r, bar.textColor.g,
                                     bar.textColor.b, 0.6)
            helpSpy.clear()
            probe.forceActiveFocus()
        }

        function test_rendersEveryAssignedSlotAsText() {
            compare(bar.count, 15)                       // 12 PF + 3 PA
            compare(bar.empty, false)
            verify(bar.visible)
            verify(bar.implicitHeight > 0)

            // Twelve PF keys plus PA1 are assigned: thirteen printed cells.
            compare(bar.cells.length, 13)
            for (var i = 0; i < 13; i++) {
                var cell = findChild(bar, "pfCell_" + i)
                verify(cell !== null, "missing text cell " + i)
                var name = findChild(bar, "pfName_" + i)
                verify(name !== null, "missing key identity " + i)
                compare(name.text, PfKeys.defaultLabelFor(i))
            }

            // Unassigned slots are not printed at all.
            compare(findChild(bar, "pfCell_13"), null)   // PA2 passes
            compare(findChild(bar, "pfCell_14"), null)   // PA3 passes
        }

        function test_theyArePlainTextNeverButtons() {
            // The old cap rectangles are gone for good.
            for (var i = 0; i < 13; i++)
                compare(findChild(bar, "pfCap_" + i), null)
            compare(findChild(bar, "pfCapRow"), null)
            // And nothing focusable hides behind the text.
            compare(Helpers.focusedItems(bar), 0)
        }

        function test_stretchesWithTheScreenFontWidth() {
            // The screen stretches its glyphs horizontally by fontWidth;
            // the panel matches that pitch so its characters read as the
            // same face, and the extra width eats into the column count.
            bar.fontWidth = 1.0
            compare(findChild(bar, "pfName_0").font.letterSpacing, 0)
            var flat = bar.fitColumns

            bar.fontWidth = 1.25
            verify(findChild(bar, "pfName_0").font.letterSpacing > 0)
            verify(bar.fitColumns <= flat, "wider cells fit fewer columns")
            bar.fontWidth = 1.0
        }

        function test_cellsCarryTheFactoryPanel() {
            // PF1 is Help, PF4 Next Window, PF5 Previous Window, PF12 New
            // Window: the menu functions the panel promises, printed in
            // screen capitals.
            compare(bar.legendFor(bar.model[0]), "Help")
            compare(findChild(bar, "pfLegend_0").text, "HELP")
            compare(findChild(bar, "pfLegend_3").text, "NEXT WINDOW")
            compare(findChild(bar, "pfLegend_4").text, "PREVIOUS WINDOW")
            compare(findChild(bar, "pfLegend_11").text, "NEW WINDOW")

            // No shell command sits on a factory PF key.
            for (var i = 0; i < 12; i++) {
                var action = bar.model[i].action
                verify(action !== "fileList" && action !== "xedit",
                       "shell command leaked onto PF" + (i + 1))
            }
        }

        function test_attentionSlotKeepsItsLegend() {
            var attention = bar.model[12]
            compare(attention.action, "interrupt")
            compare(bar.legendFor(attention), PfKeys.legend(attention))
            compare(bar.legendFor(attention), "Attention")
            compare(findChild(bar, "pfLegend_12").text, "ATTENTION")
        }

        function test_soundKeyPrintsItsLiveState() {
            // PF7 is the key-click toggle: the panel shows what it will do.
            compare(bar.model[6].action, "toggleKeySound")
            compare(bar.legendFor(bar.model[6]), "Sound On")
            compare(findChild(bar, "pfLegend_6").text, "SOUND ON")

            bar.keySoundOn = false
            compare(bar.legendFor(bar.model[6]), "Sound Off")
            compare(findChild(bar, "pfLegend_6").text, "SOUND OFF")
        }

        function test_legendCanBeTurnedOff() {
            bar.showLegends = false
            compare(bar.legendFor(bar.model[12]), "")
            compare(findChild(bar, "pfLegend_12").text, "")
            compare(findChild(bar, "pfLegend_12").visible, false)
            // The identity stays: the panel still names every key.
            compare(findChild(bar, "pfName_12").text, "PA1")

            bar.showLegends = true
            compare(bar.legendFor(bar.model[12]), "Attention")
            compare(findChild(bar, "pfLegend_12").visible, true)
        }

        function test_emptyModelHidesTheBar() {
            bar.model = []
            compare(bar.count, 0)
            compare(bar.empty, true)
            compare(bar.visible, false)
            compare(bar.implicitHeight, 0)
            compare(Helpers.mouseTargets(bar), 0)
        }

        function test_isUnreachableByCursor() {
            compare(Helpers.mouseTargets(host), 0)
            compare(Helpers.mouseTargets(bar), 0)
            compare(bar.focus, false)
        }

        function test_panelPrintsSmallerWithTheArrowGluedToTheWords() {
            // Legend, not output: printed below the screen's own size,
            // in tight rows and columns, so it stays a footnote.
            verify(bar.cellPixelSize < bar.fontPixelSize,
                   "the panel must print smaller than the screen")
            compare(findChild(bar, "pfName_0").font.pixelSize, bar.cellPixelSize)
            compare(findChild(bar, "pfLegend_0").font.pixelSize, bar.cellPixelSize)
            verify(bar.columnSpacing < 16, "columns tightened up")
            verify(bar.rowSpacing <= 4, "rows tightened up")
            verify(bar.topBottomPadding <= 4, "padding tightened up")

            // "PF4>>NEXT WINDOW": the arrow has no spaces of its own --
            // it is stuck to the words on both sides.
            compare(findChild(bar, "pfArrow_0").text, ">>")
            verify(findChild(bar, "pfArrow_0").text.indexOf(" ") === -1)

            // Measurement follows the same arithmetic: name + ">>" + legend.
            var cell = bar.cells[3]
            verify(bar.widestChars >= cell.name.length + 2 + cell.legend.length)
        }

        function test_theCallSetsTheSizeAsACoefficient() {
            // The caller (the application, from the legend settings)
            // decides how large the panel prints: 1.0 is the screen
            // font's own pixel size, and the bare component default
            // (0.8) keeps the unbound legend the footnote it has been.
            bar.fontPixelSize = 12

            bar.fontScale = 1.0
            compare(bar.cellPixelSize, 12)
            bar.fontScale = 1.5
            compare(bar.cellPixelSize, 18)
            bar.fontScale = 0.8
            compare(bar.cellPixelSize, 10)          // round(9.6)

            // The floor still holds: a tiny coefficient never collapses
            // the print below six pixels.
            bar.fontScale = 0.1
            compare(bar.cellPixelSize, 6)
            bar.fontScale = 0.8
        }

        function test_pf1BecomesAnEditableHelpField() {
            compare(bar.helpSlot, 0, "PF1 carries Help at the factory")
            compare(findChild(bar, "pfHelpInput"), null,
                    "the idle panel holds no field at all")
            compare(Helpers.focusedItems(bar), 0)

            verify(bar.beginHelpInput(), "the legend prints HELP, so it can take the topic")
            compare(bar.helpInputActive, true)

            var input = findChild(bar, "pfHelpInput")
            verify(input !== null, "the PF1 cell did not become a field")
            compare(input.maximumLength, 20, "topics are short")
            verify(input.activeFocus, "the field takes the keyboard")
            // PF1 still reads PF1 while it is being typed into.
            compare(findChild(bar, "pfName_0").text, "PF1")
            compare(findChild(bar, "pfLegend_0").visible, false,
                    "the printed legend makes way for the field")

            // Enter hands the topic up and puts the legend back.
            input.text = "printf"
            keyClick(Qt.Key_Return)
            compare(helpSpy.count, 1)
            compare(helpSpy.signalArguments[0][0], "printf")
            compare(bar.helpInputActive, false)
            compare(findChild(bar, "pfHelpInput"), null)
            compare(findChild(bar, "pfLegend_0").visible, true)
            compare(Helpers.focusedItems(bar), 0, "the field is gone again")
        }

        function test_escapePutsTheHelpFieldBack() {
            verify(bar.beginHelpInput())
            var input = findChild(bar, "pfHelpInput")
            input.text = "half typed"
            keyClick(Qt.Key_Escape)

            compare(bar.helpInputActive, false)
            compare(findChild(bar, "pfHelpInput"), null)
            compare(helpSpy.count, 0, "nothing was submitted")
            compare(findChild(bar, "pfLegend_0").visible, true,
                    "the legend is printed again")
            compare(Helpers.focusedItems(bar), 0)
        }

        function test_helpFieldOnlyExistsWhileHelpIsAssigned() {
            // A panel whose Help slot passes the key through has no cell
            // to type into: the window must fall back to the dialog.
            var model = PfKeys.defaultAssignments()
            model[0].action = "pass"
            bar.model = model
            compare(bar.helpSlot, -1)
            compare(bar.beginHelpInput(), false)
            compare(bar.helpInputActive, false)

            bar.model = []
            compare(bar.beginHelpInput(), false)
        }

        function test_clickingNeverTakesTheKeyboard() {
            var cell = findChild(bar, "pfCell_0")
            verify(cell !== null)
            verify(probe.focus, "the probe should own the keyboard")

            mouseClick(cell)

            compare(bar.focus, false)
            compare(Helpers.focusedItems(bar), 0)
            verify(probe.focus, "clicking the legend must not move focus")
        }

        function test_legendColoursDefaultToTheGlass() {
            // Nothing but the words prints: both chips stay clear.
            verify(bar.textBgColor.a === 0, "text chip clear by default")
            verify(bar.arrowBgColor.a === 0, "arrow chip clear by default")

            // The arrow is the text's colour shaded down to 60% -- what
            // opacity 0.6 used to paint, now baked into the colour so an
            // explicit choice renders exactly as picked.
            var arrow = findChild(bar, "pfArrow_0")
            compare(arrow.color, bar.arrowColor)
            compare(arrow.color.r, bar.textColor.r)
            compare(arrow.color.g, bar.textColor.g)
            compare(arrow.color.b, bar.textColor.b)
            verify(Math.abs(arrow.color.a - 0.6) < 0.001,
                   "the arrow is phosphor at 60%")
        }

        function test_legendColoursPaintChipsOnlyWhenSet() {
            var chip = findChild(bar, "pfNameBg_0")
            verify(chip !== null, "the chip exists but stays clear")
            compare(chip.visible, false)

            bar.textBgColor = "#123456"
            chip = findChild(bar, "pfNameBg_0")
            compare(chip.visible, true)
            compare(chip.color.toString(), "#123456")
            // The identity and the function share the chip; the arrow has
            // a clear one of its own.
            compare(findChild(bar, "pfLegendBg_3").visible, true)
            compare(findChild(bar, "pfArrowBg_0").visible, false)

            bar.arrowBgColor = "#654321"
            compare(findChild(bar, "pfArrowBg_0").visible, true)
            compare(findChild(bar, "pfArrowBg_0").color.toString(), "#654321")

            // Clear again: back to text on bare glass.
            bar.textBgColor = "#00000000"
            bar.arrowBgColor = "#00000000"
            compare(findChild(bar, "pfNameBg_0").visible, false)
            compare(findChild(bar, "pfArrowBg_0").visible, false)
        }

        function test_arrowColourCanBeSetApart() {
            bar.arrowColor = "#00ff00"
            compare(findChild(bar, "pfArrow_0").color.toString(), "#00ff00")
            // Exact: no opacity multiplies the colour the user picked.
            compare(findChild(bar, "pfArrow_0").opacity, 1)
            // The words themselves are untouched by an arrow colour.
            compare(findChild(bar, "pfName_0").color, bar.textColor)
        }

        function test_chipsFollowThePartTheyHide() {
            // While the HELP cell is open the legend makes way for the
            // field -- chip included: only the identity keeps printing.
            bar.textBgColor = "#123456"
            verify(bar.beginHelpInput())
            compare(findChild(bar, "pfLegendBg_0").visible, false)
            compare(findChild(bar, "pfNameBg_0").visible, true)
            bar.cancelHelpInput()
            compare(findChild(bar, "pfLegendBg_0").visible, true)
            bar.textBgColor = "#00000000"
        }
    }
}
