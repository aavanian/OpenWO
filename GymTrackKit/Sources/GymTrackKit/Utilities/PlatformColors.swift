import SwiftUI

extension Color {
    static var secondaryGroupedBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(.windowBackgroundColor)
        #endif
    }
}
