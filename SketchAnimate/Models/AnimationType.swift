//
//  AnimationType.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//

import Foundation

enum AnimationType: CaseIterable {
    case walk
    case jump
    case wave
    case bounce
    case roll
    case open
    case shake
    case wag
    case float
    case spin
    
    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .jump: return "Jump"
        case .wave: return "Wave"
        case .bounce: return "Bounce"
        case .roll: return "Roll"
        case .open: return "Open"
        case .shake: return "Shake"
        case .wag: return "Wag Tail"
        case .float: return "Float"
        case .spin: return "Spin"
        }
    }
    
    var emoji: String {
        switch self {
        case .walk: return "🚶"
        case .jump: return "🦘"
        case .wave: return "👋"
        case .bounce: return "🏀"
        case .roll: return "🎳"
        case .open: return "📂"
        case .shake: return "📳"
        case .wag: return "🐕"
        case .float: return "🌟"
        case .spin: return "🌪️"
        }
    }
    
    var duration: Double {
        switch self {
        case .walk: return 6.0
        case .jump: return 3.0
        case .wave: return 4.0
        case .bounce: return 5.0
        case .roll: return 6.0
        case .open: return 4.0
        case .shake: return 3.0
        case .wag: return 4.0
        case .float: return 6.0
        case .spin: return 4.0
        }
    }
}
