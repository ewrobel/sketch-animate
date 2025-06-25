import Foundation
import CoreGraphics

class ObjectDetector {
    
    static func detectObject(from paths: [DrawingPath]) -> ObjectType {
        guard !paths.isEmpty else { return .unknown }
        
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.height > 0 ? bounds.width / bounds.height : 1.0
        
        // Detect human/stick figure
        if detectStickFigure(paths) {
            return .human
        }
        
        // Detect ball/circle
        if paths.count <= 2 && aspectRatio > 0.7 && aspectRatio < 1.3 {
            if detectCircularShape(paths) {
                return .ball
            }
        }
        
        // Detect box/rectangle
        if detectRectangularShape(paths) {
            return .box
        }
        
        // Detect animal (similar to stick figure but with more horizontal elements)
        if detectAnimal(paths) {
            return .animal
        }
        
        // Default
        return .unknown
    }
    
    // MARK: - Detection Methods
    
    private static func detectStickFigure(_ paths: [DrawingPath]) -> Bool {
        var hasVerticalLine = false
        var horizontalLineCount = 0
        
        for path in paths {
            if path.isVertical && path.boundingBox.height > 50 {
                hasVerticalLine = true
            }
            
            if path.isHorizontal && path.boundingBox.width > 20 {
                horizontalLineCount += 1
            }
        }
        
        // Stick figure: 1 main vertical (body) + 2-4 horizontals (arms/legs)
        let validPathCount = paths.count >= 3 && paths.count <= 7
        return hasVerticalLine && horizontalLineCount >= 2 && validPathCount
    }
    
    private static func detectCircularShape(_ paths: [DrawingPath]) -> Bool {
        guard let mainPath = paths.first, mainPath.points.count > 10 else { return false }
        
        let center = CGPoint(
            x: mainPath.points.map { $0.x }.reduce(0, +) / CGFloat(mainPath.points.count),
            y: mainPath.points.map { $0.y }.reduce(0, +) / CGFloat(mainPath.points.count)
        )
        
        let distances = mainPath.points.map { point in
            sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
        }
        
        let avgDistance = distances.reduce(0, +) / CGFloat(distances.count)
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / CGFloat(distances.count)
        
        // Low variance indicates points are roughly equidistant from center (circular)
        return variance < pow(avgDistance * 0.3, 2)
    }
    
    private static func detectRectangularShape(_ paths: [DrawingPath]) -> Bool {
        guard paths.count >= 3 && paths.count <= 6 else { return false }
        
        var verticalLines = 0
        var horizontalLines = 0
        
        for path in paths {
            if path.isVertical {
                verticalLines += 1
            } else if path.isHorizontal {
                horizontalLines += 1
            }
        }
        
        // Box should have at least 2 vertical and 2 horizontal lines
        return verticalLines >= 2 && horizontalLines >= 2
    }
    
    private static func detectAnimal(_ paths: [DrawingPath]) -> Bool {
        // Animal detection: body + multiple limbs + possible tail
        // Similar to stick figure but typically more horizontal elements
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        
        var bodyPaths = 0
        var limbCount = 0
        
        for path in paths {
            if path.boundingBox.width > path.boundingBox.height {
                // Horizontal-ish = potential body or limb
                if path.boundingBox.width > 50 {
                    bodyPaths += 1
                } else {
                    limbCount += 1
                }
            }
        }
        
        // Animal: wider than tall, multiple horizontal elements
        return aspectRatio > 1.2 && bodyPaths >= 1 && limbCount >= 2 && paths.count >= 4
    }
    
    // MARK: - Helper Methods
    
    private static func calculateDrawingBounds(_ paths: [DrawingPath]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for path in paths {
            for point in path.points {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Debug Info
    
    static func getDetectionInfo(from paths: [DrawingPath]) -> String {
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        
        let verticalPaths = paths.filter { $0.isVertical }
        let horizontalPaths = paths.filter { $0.isHorizontal }
        
        var info = "Detection Analysis:\n"
        info += "- Total paths: \(paths.count)\n"
        info += "- Vertical paths: \(verticalPaths.count)\n"
        info += "- Horizontal paths: \(horizontalPaths.count)\n"
        info += "- Aspect ratio: \(String(format: "%.2f", aspectRatio))\n"
        info += "- Bounds: \(Int(bounds.width))x\(Int(bounds.height))"
        
        return info
    }
}
