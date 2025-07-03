import Foundation

enum ObjectType: CaseIterable {
    case human
    case ball
    case unknown
    
    var displayName: String {
        switch self {
        case .human: return "Person"
        case .ball: return "Ball"
        case .unknown: return "Drawing"
        }
    }
    
    var animations: [AnimationType] {
        switch self {
        case .human: return [.walk, .jump, .wave]
        case .ball: return [.bounce, .roll]
        case .unknown: return [.float, .spin, .shake]
        }
    }
    
    var emoji: String {
        switch self {
        case .human: return "🚶"
        case .ball: return "⚽️"
        case .unknown: return "✨"
        }
    }
}
