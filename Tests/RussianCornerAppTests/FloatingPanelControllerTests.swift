import CoreGraphics
import XCTest

@testable import RussianCornerUI

final class FloatingPanelControllerTests: XCTestCase {
    func testCollapsedPresentationUsesDedicatedDragSurface() {
        XCTAssertFalse(
            PracticePanelPresentation.collapsed
                .allowsWindowBackgroundDragging
        )
        XCTAssertTrue(
            PracticePanelPresentation.compact
                .allowsWindowBackgroundDragging
        )
        XCTAssertTrue(
            PracticePanelPresentation.details
                .allowsWindowBackgroundDragging
        )
    }

    func testCollapsedCardDragTranslatesWindowFromGestureStart() {
        XCTAssertEqual(
            CollapsedCardDragGeometry.windowOrigin(
                initialMouseLocation: CGPoint(x: 100, y: 200),
                currentMouseLocation: CGPoint(x: 160, y: 175),
                initialWindowOrigin: CGPoint(x: 400, y: 500)
            ),
            CGPoint(x: 460, y: 475)
        )
    }

    func testCollapsedCardDragGeometryHasNoOffsetAtGestureStart() {
        XCTAssertEqual(
            CollapsedCardDragGeometry.windowOrigin(
                initialMouseLocation: CGPoint(x: 100, y: 200),
                currentMouseLocation: CGPoint(x: 100, y: 200),
                initialWindowOrigin: CGPoint(x: 400, y: 500)
            ),
            CGPoint(x: 400, y: 500)
        )
    }

    func testSelectedWordExtendsOnlyWindowHeight() {
        let presentation = PracticePanelPresentation.resolve(
            isCollapsed: false,
            isDetailExpanded: true,
            hasSelectedWord: true
        )

        XCTAssertEqual(presentation, .details)
        XCTAssertEqual(presentation.size, CGSize(width: 360, height: 386))
    }

    func testDetailResizeKeepsTopEdgeFixed() {
        let origin = FloatingPanelController.topAnchoredOrigin(
            currentFrame: CGRect(
                x: 400,
                y: 500,
                width: 360,
                height: 240
            ),
            newPanelSize: CGSize(width: 360, height: 386)
        )

        XCTAssertEqual(origin, CGPoint(x: 400, y: 354))
    }

    func testLearningHistoryEntryIsVisibleAndComfortablyClickable() {
        XCTAssertEqual(PracticeCardMetrics.historyActionTitle, "记录")
        XCTAssertEqual(PracticeCardMetrics.wordCloseActionTitle, "关闭词义")
        XCTAssertGreaterThanOrEqual(
            PracticeCardMetrics.historyActionHitHeight,
            28
        )
    }

    func testNearestCornerUsesPanelCenterAndScreenCoordinates() {
        let screen = CGRect(x: 1200, y: -900, width: 1600, height: 900)
        let panelSize = CGSize(width: 360, height: 240)

        XCTAssertEqual(
            FloatingPanelController.nearestCorner(
                panelFrame: CGRect(
                    origin: CGPoint(x: 1220, y: -260),
                    size: panelSize
                ),
                visibleFrame: screen
            ),
            .topLeft
        )
        XCTAssertEqual(
            FloatingPanelController.nearestCorner(
                panelFrame: CGRect(
                    origin: CGPoint(x: 2400, y: -260),
                    size: panelSize
                ),
                visibleFrame: screen
            ),
            .topRight
        )
        XCTAssertEqual(
            FloatingPanelController.nearestCorner(
                panelFrame: CGRect(
                    origin: CGPoint(x: 1220, y: -880),
                    size: panelSize
                ),
                visibleFrame: screen
            ),
            .bottomLeft
        )
        XCTAssertEqual(
            FloatingPanelController.nearestCorner(
                panelFrame: CGRect(
                    origin: CGPoint(x: 2400, y: -880),
                    size: panelSize
                ),
                visibleFrame: screen
            ),
            .bottomRight
        )
    }

    func testFreeOriginStaysWhereDraggedWhenFullyVisible() {
        let origin = FloatingPanelController.constrainedOrigin(
            CGPoint(x: 410, y: 260),
            panelSize: CGSize(width: 360, height: 240),
            visibleFrame: CGRect(
                x: 0,
                y: 0,
                width: 1_440,
                height: 900
            )
        )

        XCTAssertEqual(origin, CGPoint(x: 410, y: 260))
    }

    func testFreeOriginIsOnlyClampedWhenOutsideVisibleScreen() {
        let origin = FloatingPanelController.constrainedOrigin(
            CGPoint(x: 1_360, y: -80),
            panelSize: CGSize(width: 360, height: 240),
            visibleFrame: CGRect(
                x: 0,
                y: 0,
                width: 1_440,
                height: 900
            )
        )

        XCTAssertEqual(origin, CGPoint(x: 1_080, y: 0))
    }
}
