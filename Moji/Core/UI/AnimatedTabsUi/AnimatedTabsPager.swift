import SwiftUI

struct AnimatedTabsPager<ID: Hashable, Page: View>: View {
    let ids: [ID]
    @Binding var selection: ID
    let liveState: AnimatedTabsLiveState
    @ViewBuilder let page: (ID) -> Page

    @State private var scrolledID: ID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(ids, id: \.self) { id in
                    page(id)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledID)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            let width = geometry.containerSize.width
            guard width > 0 else { return 0 }
            return geometry.contentOffset.x / width
        } action: { _, newValue in
            liveState.position = newValue
        }
        .onChange(of: scrolledID) { _, newValue in
            guard let newValue, newValue != selection else { return }
            selection = newValue
        }
        .onChange(of: selection) { _, newValue in
            guard scrolledID != newValue else { return }
            withAnimation(AnimatedTabsMetrics.releaseAnimation) {
                scrolledID = newValue
            }
        }
        .onAppear {
            guard scrolledID == nil else { return }
            scrolledID = selection
            liveState.position = CGFloat(ids.firstIndex(of: selection) ?? 0)
        }
    }
}
