import Foundation

class MemoryMonitor {
    
    static let shared = MemoryMonitor()
    
    private(set) var currentMB: Float = 0.0
    private(set) var peakMB: Float    = 0.0
    private(set) var samples: [Float] = []
    
    private let maxSamples = 300
    
    private init() {}
    
    
    @discardableResult
    func sample() -> Float {
        let task  = mach_task_self_
        var info  = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return currentMB }
        
        currentMB = Float(info.phys_footprint) / 1024 / 1024
        peakMB    = max(peakMB, currentMB)
        
        samples.append(currentMB)
        if samples.count > maxSamples {
            samples.removeFirst()
        }
        
        return currentMB
    }
    
    
    var averageMB: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Float(samples.count)
    }
    
    var minMB: Float {
        samples.min() ?? 0
    }
    
    func reset() {
        samples.removeAll()
        peakMB = currentMB
        Logger.info("MemoryMonitor reset")
    }
    
    
    func exportCSV() -> String {
        var csv = "sample_index,memory_mb\n"
        for (index, value) in samples.enumerated() {
            csv += "\(index),\(value)\n"
        }
        return csv
    }
}
