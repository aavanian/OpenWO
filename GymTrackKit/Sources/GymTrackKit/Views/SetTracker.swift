import SwiftUI

struct SetTracker: View {
    let totalSets: Int
    let onAllCompleted: () -> Void

    @State private var completedSets: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSets, id: \.self) { index in
                Circle()
                    .fill(index < completedSets ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay {
                        if index < completedSets {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }

            Text("\(completedSets)/\(totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if completedSets < totalSets {
                completedSets += 1
                Haptics.light()
                if completedSets == totalSets {
                    onAllCompleted()
                }
            }
        }
    }
}
