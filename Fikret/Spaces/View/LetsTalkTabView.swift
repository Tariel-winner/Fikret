import SwiftUI
/*
struct LetsTalkTabView: View {
    @EnvironmentObject private var conversationManager: ConversationCacheManager
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @Binding var showQueueJoinPill: Bool
    @Binding var isExpandedPill: Bool
    @State private var currentIndex = 0
    let heightOffset: CGFloat
    
    private func handleTalkButtonTap(for card: Space) {
        print("🎯 handleTalkButtonTap triggered with card: \(card.id)")
        print("🎯 Card state: \(card.state)")
        
        // Set selected space first
        spacesViewModel.selectedSpace = card
        print("🎯 Selected space set to: \(card.id)")
        
        // Then update the pill states
        withAnimation(.spring()) {
            showQueueJoinPill = true
            isExpandedPill = true
            print("🎯 Pills updated - showQueueJoinPill: \(showQueueJoinPill), isExpandedPill: \(isExpandedPill)")
        }
    }
    
    var body: some View {
        if spacesViewModel.isLoadingSpaces && spacesViewModel.spaces.isEmpty {
            ProgressView().tint(.white)
        } else {
            GeometryReader { geometry in
                TabView(selection: $currentIndex) {
                    ForEach(Array(spacesViewModel.spaces.enumerated()), id: \.element.id) { index, space in
                        TalkCardView(
                            card: space,
                            onTalkButtonTap: {
                                handleTalkButtonTap(for: space)
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height - heightOffset)
                        .rotationEffect(.degrees(-90))
                        .tag(index)
                    }
                }
                .frame(width: geometry.size.height - heightOffset, height: geometry.size.width)
                .rotationEffect(.degrees(90))
                .offset(
                    x: (geometry.size.width - (geometry.size.height - heightOffset)) / 2,
                    y: ((geometry.size.height - heightOffset) - geometry.size.width) / 2 + heightOffset
                )
                .tabViewStyle(.page(indexDisplayMode: .never))
                .refreshable {
                    // Pull to refresh
                    await spacesViewModel.refreshFeed()
                }
            }
            .onChange(of: currentIndex) { index in
                // Load next page when user reaches near the end
                if index >= spacesViewModel.spaces.count - 2 && spacesViewModel.hasMoreDataSpaces {
                    Task {
                        await spacesViewModel.loadNextPage()
                    }
                }
            }
            .task {
                // Initial load
                if spacesViewModel.spaces.isEmpty {
                    await spacesViewModel.loadSpacesFeed()
                }
            }
        }
    }
}
*/
