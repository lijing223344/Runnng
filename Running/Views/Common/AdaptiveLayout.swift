import SwiftUI

/// Layout rules for the wide canvas a foldable iPhone gives us when unfolded.
/// Below the breakpoint everything stays single column; above it the session
/// splits into the live card on the left and plan context on the right, the way
/// a timing desk sits next to the lanes.
enum DSLayout {
    static let wideBreakpoint: CGFloat = 700
    static func isWide(_ width: CGFloat) -> Bool { width >= wideBreakpoint }
}

/// Two-pane session shell. Each pane scrolls independently so the timer never
/// moves off screen while the coach browses the remaining work.
struct DSTrainingSplit<Leading: View, Trailing: View>: View {
    let width: CGFloat
    /// Optional floor for the content height so a short block sits in the
    /// optical middle of a tall canvas instead of hugging the top edge.
    var fillHeight: CGFloat = 0
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                leading()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: fillHeight, alignment: .center)
            }
            .frame(width: max(340, min(width * 0.54, 560)))

            Rectangle()
                .fill(DS.Colors.borderLight)
                .frame(width: 1)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                trailing()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: fillHeight, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension View {
    /// Keeps long reading columns comfortable on a wide canvas instead of
    /// stretching line length across the whole display.
    func dsReadableColumn(_ maxWidth: CGFloat = 860) -> some View {
        // A single cap is enough: the scroll container proposes its own finite
        // width, so the frame shrinks to the screen on a phone and to the cap on
        // a wide canvas. A second maxWidth: .infinity here would propose
        // infinity and force 720 pt even on a 402 pt phone, clipping the right
        // edge of every card.
        frame(maxWidth: maxWidth)
    }
}
