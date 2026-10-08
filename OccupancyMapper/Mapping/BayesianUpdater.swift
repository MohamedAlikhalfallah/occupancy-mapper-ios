import Foundation

class BayesianUpdater {
    
    func updateProbability(old: Float, measurement: Float) -> Float {
        let updatedLogOdds = logOdds(old) + logOdds(measurement) - logOdds(Constants.probUnknown)
        let updated = probability(fromLogOdds: updatedLogOdds)
        return min(max(updated, Constants.probMin), Constants.probMax)
    }
    
    func logOdds(_ p: Float) -> Float {
        let clamped = min(max(p, Constants.probMin), Constants.probMax)
        return log(clamped / (1.0 - clamped))
    }
    
    func probability(fromLogOdds l: Float) -> Float {
        1.0 - (1.0 / (1.0 + exp(l)))
    }
    
    func batchUpdate(values: [Float], measurement: Float) -> [Float] {
        values.map { updateProbability(old: $0, measurement: measurement) }
    }
}
