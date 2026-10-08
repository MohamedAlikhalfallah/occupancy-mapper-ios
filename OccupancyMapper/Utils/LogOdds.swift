import Foundation


enum LogOdds {
    
    
    static let scale: Float = 27.0
    
    static let minValue: Int8 = -124
    static let maxValue: Int8 =  124
    
    static let unknown: Int8 = 0
    

    static func fromProbability(_ p: Float) -> Int8 {
        let clamped = min(max(p, Constants.probMin), Constants.probMax)
        let l = log(clamped / (1.0 - clamped))
        let scaled = l * scale
        return Int8(min(max(scaled, Float(minValue)), Float(maxValue)))
    }
    
    static func toProbability(_ value: Int8) -> Float {
        let l = Float(value) / scale
        return 1.0 - (1.0 / (1.0 + exp(l)))
    }
    

    static let freeDelta: Int8 = {
        let l = log(Constants.probFree / (1.0 - Constants.probFree))
        return Int8(min(max(l * scale, Float(minValue)), Float(maxValue)))
    }()
    
    static let occupiedDelta: Int8 = {
        let l = log(Constants.probOccupied / (1.0 - Constants.probOccupied))
        return Int8(min(max(l * scale, Float(minValue)), Float(maxValue)))
    }()
    

    @inline(__always)
    static func update(_ current: Int8, delta: Int8) -> Int8 {
        let sum = Int(current) + Int(delta)
        return Int8(min(max(sum, Int(minValue)), Int(maxValue)))
    }
    

    static let occupiedThreshold: Int8 = fromProbability(0.7)
    
    static let freeThreshold: Int8 = fromProbability(0.3)
    
    @inline(__always)
    static func isOccupied(_ value: Int8) -> Bool { value > occupiedThreshold }
    
    @inline(__always)
    static func isFree(_ value: Int8) -> Bool { value < freeThreshold }
    
    @inline(__always)
    static func isUnknown(_ value: Int8) -> Bool {
        value >= freeThreshold && value <= occupiedThreshold
    }
}
