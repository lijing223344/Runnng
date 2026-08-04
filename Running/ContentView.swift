import SwiftUI

struct ContentView: View {
    var body: some View {
        switch AppRuntimeConfiguration.launchDestination() {
        case .home:
            HomeView()
        case .miniHurdle:
            NavigationStack {
                MiniHurdleSpacingView()
            }
        }
    }
}

#Preview { ContentView() }
