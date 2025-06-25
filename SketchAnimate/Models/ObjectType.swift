import Foundation

enum ObjectType: CaseIterable {
    case human
    case ball
    case box
    case animal
    case unknown
    
    var displayName: String {
        switch self {
        case .human: return "Person"
        case .ball: return "Ball"
        case .box: return "Box"
        case .animal: return "Animal"
        case .unknown: return "Drawing"
        }
    }
    
    var animations: [AnimationType] {
        switch self {
        case .human: return [.walk, .jump, .wave]
        case .ball: return [.bounce, .roll]
        case .box: return [.open, .shake]
        case .animal: return [.walk, .wag, .jump]
        case .unknown: return [.float, .spin]
        }
    }
    
    var emoji: String {
        switch self {
        case .human: return "🚶"
        case .ball: return "⚽️"
        case .box: return "📦"
        case .animal: return "🐕"
        case .unknown: return "✨"
        }
    }
}
