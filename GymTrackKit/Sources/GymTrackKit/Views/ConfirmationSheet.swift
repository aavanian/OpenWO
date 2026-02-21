import SwiftUI

struct ConfirmationSheet: View {
    let sessionType: SessionType
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Start \(sessionType.displayName)?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Ready to work out? Let's go!")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Not now") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Let's go") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }
}
