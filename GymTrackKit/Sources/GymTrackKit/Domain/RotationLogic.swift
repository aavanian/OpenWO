import Foundation

public enum RotationLogic {
    public static func nextSessionType(after last: SessionType?) -> SessionType {
        guard let last else { return .a }
        switch last {
        case .a: return .b
        case .b: return .c
        case .c: return .a
        }
    }
}
