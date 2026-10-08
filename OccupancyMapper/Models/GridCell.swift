import Foundation


struct GridCell {
    
    let logOdds: Int8
    
    let isObserved: Bool
    
    init(logOdds: Int8, isObserved: Bool = true) {
        self.logOdds    = logOdds
        self.isObserved = isObserved
    }
    
    init() {
        self.logOdds    = LogOdds.unknown
        self.isObserved = false
    }
    
    
    var occupancyProbability: Float {
        LogOdds.toProbability(logOdds)
    }
    
    var isOccupied: Bool { isObserved && LogOdds.isOccupied(logOdds) }
    var isFree: Bool     { isObserved && LogOdds.isFree(logOdds) }
    var isUnknown: Bool  { !isObserved || LogOdds.isUnknown(logOdds) }
}
