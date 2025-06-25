import Foundation
import UIKit
import SwiftUI

// MARK: - Enhanced Response Models for Detailed Body Analysis
struct DetailedAIAnalysis: Codable {
    let bodyParts: [BodyPart]
    let joints: [Joint]
    let hierarchy: Hierarchy
    
    enum CodingKeys: String, CodingKey {
        case bodyParts = "body_parts"
        case joints, hierarchy
    }
}

struct BodyPart: Codable {
    let id: Int
    let type: BodyPartType
    let startJoint: String
    let endJoint: String
    let isPrimary: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case startJoint = "start_joint"
        case endJoint = "end_joint"
        case isPrimary = "is_primary"
    }
}

enum BodyPartType: String, Codable {
    case torso, head, leftArm = "left_arm", rightArm = "right_arm", leftLeg = "left_leg", rightLeg = "right_leg"
}

struct Joint: Codable {
    let name: String
    let x: Double
    let y: Double
    let connectedParts: [Int]
    
    enum CodingKeys: String, CodingKey {
        case name, x, y
        case connectedParts = "connected_parts"
    }
}

struct Hierarchy: Codable {
    let root: String
    let connections: [String: [String]]
}

// MARK: - OpenAI API Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: [OpenAIContent]
}

struct OpenAIContent: Codable {
    let type: String
    let text: String?
    let imageUrl: OpenAIImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

struct OpenAIImageURL: Codable {
    let url: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIResponseMessage
}

struct OpenAIResponseMessage: Codable {
    let content: String
}

// MARK: - AI Analysis Service
class AIAnalysisService: ObservableObject {
    
    // IMPORTANT: Replace with your actual OpenAI API key
    private let apiKey = "YOUR_OPENAI_API_KEY_HERE"
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    // Enable this to force mock mode for testing
    private let useMockAnalysis = true
    
    enum AIError: Error, LocalizedError {
        case noAPIKey
        case imageConversionFailed
        case networkError(String)
        case parsingError(String)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenAI API key not configured"
            case .imageConversionFailed:
                return "Failed to convert drawing to image"
            case .networkError(let message):
                return "Network error: \(message)"
            case .parsingError(let message):
                return "Failed to parse response: \(message)"
            case .invalidResponse:
                return "Invalid response from AI service"
            }
        }
    }
    
    func analyzeDrawingDetailed(_ drawingPaths: [DrawingPath]) async throws -> DetailedAIAnalysis? {
        // Check API key
        guard apiKey != "YOUR_OPENAI_API_KEY_HERE" && !apiKey.isEmpty else {
            print("⚠️ No API key configured, cannot perform detailed analysis")
            return nil
        }
        
        // Convert drawing to image
        let image = try await convertDrawingToImage(drawingPaths)
        
        // Send to OpenAI Vision API for detailed analysis
        let detailedAnalysis = try await sendToOpenAIForDetailedAnalysis(image: image)
        
        return detailedAnalysis
    }
    
    private func sendToOpenAIForDetailedAnalysis(image: UIImage) async throws -> DetailedAIAnalysis {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64Image)"
        
        // Create request with detailed analysis prompt
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": createAnalysisPrompt()
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURL
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 800
        ]
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: apiURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIError.parsingError("Failed to create request body: \(error)")
        }
        
        // Make API call
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 OpenAI API response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ API Error Response: \(errorString)")
                    }
                    throw AIError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse response
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                
                print("❌ Failed to parse OpenAI response structure")
                throw AIError.invalidResponse
            }
            
            print("🤖 OpenAI detailed response: \(content)")
            
            // Parse the detailed JSON response
            return try parseDetailedAIResponse(content)
            
        } catch let error as AIError {
            throw error
        } catch {
            print("❌ Network error details: \(error)")
            throw AIError.networkError(error.localizedDescription)
        }
    }
    
    private func parseDetailedAIResponse(_ content: String) throws -> DetailedAIAnalysis {
        let cleanedContent = extractJSONFromResponse(content)
        
        do {
            let data = cleanedContent.data(using: .utf8) ?? Data()
            return try JSONDecoder().decode(DetailedAIAnalysis.self, from: data)
        } catch {
            print("❌ Failed to parse detailed AI response: \(error)")
            print("Raw content: \(cleanedContent)")
            throw AIError.parsingError("Failed to parse detailed AI response: \(error)")
        }
    }
    
    // MARK: - Image Conversion
    
    private func convertDrawingToImage(_ paths: [DrawingPath]) async throws -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let size = CGSize(width: 512, height: 512)
                let renderer = UIGraphicsImageRenderer(size: size)
                
                let image = renderer.image { context in
                    // White background
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    
                    // Draw paths
                    UIColor.black.setStroke()
                    context.cgContext.setLineWidth(3.0)
                    context.cgContext.setLineCap(.round)
                    context.cgContext.setLineJoin(.round)
                    
                    for path in paths {
                        guard !path.points.isEmpty else { continue }
                        
                        context.cgContext.beginPath()
                        context.cgContext.move(to: path.points[0])
                        
                        for i in 1..<path.points.count {
                            context.cgContext.addLine(to: path.points[i])
                        }
                        
                        context.cgContext.strokePath()
                    }
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - OpenAI API Integration
    
    private func sendToOpenAI(image: UIImage) async throws -> AIAnalysisResponse {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64Image)"
        
        // Create request with correct OpenAI format
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Updated model name
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": createAnalysisPrompt()
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURL
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 300
        ]
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: apiURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIError.parsingError("Failed to create request body: \(error)")
        }
        
        // Make API call with better error handling
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 OpenAI API response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ API Error Response: \(errorString)")
                    }
                    throw AIError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Parse response
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                
                print("❌ Failed to parse OpenAI response structure")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                throw AIError.invalidResponse
            }
            
            print("🤖 OpenAI response: \(content)")
            
            // Parse the JSON response from the AI
            return try parseAIResponse(content)
            
        } catch let error as AIError {
            throw error
        } catch {
            print("❌ Network error details: \(error)")
            throw AIError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Prompt Creation
    
    private func createAnalysisPrompt() -> String {
        return """
        Analyze this stick figure drawing and identify each body part and joint connection.
        
        For each stroke/line in the drawing, identify:
        1. What body part it represents (head, torso, left_arm, right_arm, left_leg, right_leg)
        2. Where it connects to other body parts (joint positions)
        3. The hierarchical structure (what connects to what)
        
        Respond with ONLY a JSON object in this exact format:
        {
            "body_parts": [
                {
                    "id": 0,
                    "type": "torso|head|left_arm|right_arm|left_leg|right_leg",
                    "start_joint": "hip|shoulder_left|shoulder_right|neck|etc",
                    "end_joint": "neck|hand_left|hand_right|foot_left|foot_right|etc",
                    "is_primary": true
                }
            ],
            "joints": [
                {
                    "name": "hip|neck|shoulder_left|shoulder_right|etc",
                    "x": 250,
                    "y": 300,
                    "connected_parts": [0, 1, 2]
                }
            ],
            "hierarchy": {
                "root": "torso",
                "connections": {
                    "torso": ["head", "left_arm", "right_arm", "left_leg", "right_leg"]
                }
            }
        }
        
        Be precise about joint positions and connections. The root should always be the torso/body.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(_ content: String) throws -> AIAnalysisResponse {
        // Clean up the response - sometimes AI adds extra text
        let cleanedContent = extractJSONFromResponse(content)
        
        do {
            let data = cleanedContent.data(using: .utf8) ?? Data()
            return try JSONDecoder().decode(AIAnalysisResponse.self, from: data)
        } catch {
            throw AIError.parsingError("Failed to parse AI response: \(error)")
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Look for JSON object in the response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            return String(response[startIndex...endIndex])
        }
        
        // If no JSON found, return original
        return response
    }
    
    private func parseObjectType(from response: AIAnalysisResponse) -> ObjectType {
        print("🎯 AI Analysis:")
        print("- Object: \(response.objectType)")
        print("- Confidence: \(response.confidence)")
        print("- Description: \(response.description)")
        print("- Reasoning: \(response.reasoning)")
        
        switch response.objectType.lowercased() {
        case "human", "person", "stick figure":
            return .human
        case "ball", "circle":
            return .ball
        case "box", "rectangle", "square":
            return .box
        case "animal", "dog", "cat", "pet":
            return .animal
        default:
            return .unknown
        }
    }
    
    // MARK: - Enhanced Mock Analysis (for testing without API key)
    
    private func enhancedMockAnalysis(_ paths: [DrawingPath]) async -> ObjectType {
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        print("🤖 Enhanced Mock AI Analysis")
        
        // More sophisticated analysis
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        let totalPoints = paths.reduce(0) { $0 + $1.points.count }
        
        print("📊 Analysis data:")
        print("- Paths: \(paths.count)")
        print("- Total points: \(totalPoints)")
        print("- Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("- Bounds: \(Int(bounds.width))x\(Int(bounds.height))")
        
        // Enhanced detection logic
        
        // Check for stick figure (vertical + horizontal elements)
        let hasVerticalElement = paths.contains { path in
            let pathBounds = path.boundingBox
            return pathBounds.height > pathBounds.width && pathBounds.height > 40
        }
        
        let horizontalElements = paths.filter { path in
            let pathBounds = path.boundingBox
            return pathBounds.width > pathBounds.height && pathBounds.width > 20
        }.count
        
        if hasVerticalElement && horizontalElements >= 2 && paths.count >= 3 {
            print("🎯 Mock detected: Human (vertical body + \(horizontalElements) horizontal limbs)")
            return .human
        }
        
        // Check for circular/ball (simple shapes, roughly square bounds)
        if paths.count <= 3 && aspectRatio > 0.6 && aspectRatio < 1.6 {
            let hasCircularPath = paths.contains { path in
                return isPathCircular(path)
            }
            
            if hasCircularPath {
                print("🎯 Mock detected: Ball (circular shape)")
                return .ball
            }
        }
        
        // Check for box (multiple straight lines, rectangular bounds)
        if paths.count >= 3 && paths.count <= 8 {
            let straightLines = paths.filter { path in
                return isPathStraight(path)
            }.count
            
            if straightLines >= 3 && (aspectRatio > 1.2 || aspectRatio < 0.8) {
                print("🎯 Mock detected: Box (\(straightLines) straight lines)")
                return .box
            }
        }
        
        // Check for animal (wide, multiple elements)
        if aspectRatio > 1.4 && paths.count >= 4 && paths.count <= 10 {
            print("🎯 Mock detected: Animal (wide shape with multiple elements)")
            return .animal
        }
        
        print("🎯 Mock detected: Unknown drawing")
        return .unknown
    }
    
    private func calculateDrawingBounds(_ paths: [DrawingPath]) -> CGRect {
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
    
    private func isPathCircular(_ path: DrawingPath) -> Bool {
        guard path.points.count > 8 else { return false }
        
        // Calculate center
        let centerX = path.points.map { $0.x }.reduce(0, +) / CGFloat(path.points.count)
        let centerY = path.points.map { $0.y }.reduce(0, +) / CGFloat(path.points.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        // Check if points are roughly equidistant from center
        let distances = path.points.map { point in
            sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
        }
        
        let avgDistance = distances.reduce(0, +) / CGFloat(distances.count)
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / CGFloat(distances.count)
        
        return variance < pow(avgDistance * 0.4, 2) && avgDistance > 15
    }
    
    private func isPathStraight(_ path: DrawingPath) -> Bool {
        guard path.points.count >= 2 else { return false }
        
        let first = path.points.first!
        let last = path.points.last!
        let dx = abs(last.x - first.x)
        let dy = abs(last.y - first.y)
        
        // Consider it straight if it's predominantly in one direction
        return (dx > dy * 2 && dx > 20) || (dy > dx * 2 && dy > 20)
    }
    
    // MARK: - Original Mock Analysis (simpler version)
    
    private func mockAnalysis(_ paths: [DrawingPath]) async -> ObjectType {
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        print("🤖 Basic Mock AI Analysis")
        
        // Simple mock logic
        if paths.count >= 3 && paths.count <= 7 {
            let hasLongPath = paths.contains { path in
                let bounds = path.boundingBox
                return bounds.height > 50 || bounds.width > 50
            }
            
            if hasLongPath {
                print("- Mock detected: Human (stick figure)")
                return .human
            }
        }
        
        if paths.count <= 2 {
            print("- Mock detected: Ball (simple shape)")
            return .ball
        }
        
        print("- Mock detected: Unknown")
        return .unknown
    }
}
