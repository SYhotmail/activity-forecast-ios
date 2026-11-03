import SwiftUI
import ForecastKit

/// Renders every `LoadState` case the same way on every screen (contracts/ui.md).
/// `content` is only asked to draw the loaded value.
struct LoadStateView<Value: Sendable, Content: View>: View {
    let state: LoadState<Value>
    var idleMessage = ""
    var emptyMessage = ""
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle:
            ContentUnavailableView(idleMessage, systemImage: "magnifyingglass")
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .loaded(value):
            content(value)
        case .empty:
            ContentUnavailableView(emptyMessage, systemImage: "mappin.slash")
        case let .failed(error):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.message)
            }
        }
    }
}

#if DEBUG
#Preview("Idle") {
    LoadStateView(state: LoadState<String>.idle, idleMessage: "Type at least 2 letters to search") { Text($0) }
}

#Preview("Loading") {
    LoadStateView(state: LoadState<String>.loading) { Text($0) }
}

#Preview("Loaded") {
    LoadStateView(state: LoadState<String>.loaded("Loaded content")) { Text($0) }
}

#Preview("Empty") {
    LoadStateView(state: LoadState<String>.empty, emptyMessage: "No places found for 'zzqxw'") { Text($0) }
}

#Preview("Failed") {
    LoadStateView(state: LoadState<String>.failed(.offline)) { Text($0) }
}
#endif
