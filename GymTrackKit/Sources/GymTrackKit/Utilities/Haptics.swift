#if canImport(UIKit)
import UIKit

public enum Haptics {
    public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
#else
public enum Haptics {
    public static func light() {}
    public static func medium() {}
    public static func success() {}
}
#endif
