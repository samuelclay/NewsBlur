//
//  WidgetDebugTimer.swift
//  Widget Extension
//
//  Created by David Sinclair on 2022-01-31.
//  Based on Dejal code.
//

import Foundation

/// Timer for debugging performance.
class WidgetDebugTimer {
    /// Private singleton shared instance.  Access via the class functions.
    private static let shared = WidgetDebugTimer()
    
    /// Private initializer to prevent others constructing a new instance.
    private init() {
        formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 6
        formatter.maximumFractionDigits = 6
    }
    
    /// Information about each timer operation.
    private struct Info {
        /// The date the operation was started.
        var start: Date
        
        /// The date this step was started.
        var step: Date
        
        /// The indentation level.
        var level: Int
        
        // If I ever add the closure-based long-running timers, add those properties.
    }
    
    /// A dictionary of operation info, keyed on the operation string.
    private typealias InfoDictionary = [String : Info]
    
    /// A dictionary of operation info, keyed on the operation string.
    private var info = InfoDictionary()
    
    /// A number formatter for the number of seconds.
    private var formatter: NumberFormatter
    
    /// Given an operation name, starts a debug timer.  Use `print(_:step:)` after the code to time.
    ///
    /// - Parameter operation: The name of the operation to time (used as both a key to group timers, and a debug label).
    /// - Parameter level: How much to indent the operation, for nested timers.  Defaults to zero (no indentation).
    /// - Returns: The operation name, so it can be assigned to a variable instead of typing it again.  Discardable.
    @discardableResult
    class func start(_ operation: String, level: Int = 0) -> String {
        let date = Date()
        
        shared.info[operation] = Info(start: date, step: date, level: level)
        
        return operation
    }
    
    /// Given an operation name, that must have been previously started via `start(_:)`, prints the total time so far and (if a step is provided) the time since that this step took, i.e. since the start or the previous step.
    ///
    /// - Parameter operation: The name of the operation to time.
    /// - Parameter step: The name of the step of the operation.  May be omitted if there's only one interesting step.
    class func print(_ operation: String, step: String? = nil) {
        let date = Date()
        
        guard let currentInfo = shared.info[operation] else {
            NSLog("\(operation): forgot to call start(_:) first!")
            return
        }
        
        let totalDuration = date.timeIntervalSince(currentInfo.start)
        
        guard let step else {
            NSLog("\(String(repeating: " ", count: currentInfo.level * 2))\(operation) took \(shared.formatter.string(from: NSNumber(value: totalDuration)) ?? "?") seconds")
            return
        }
        
        let stepDuration = date.timeIntervalSince(currentInfo.step)
        var newInfo = currentInfo
        let alert = stepDuration < 0.001 ? "" : stepDuration < 0.01 ? " 🚨" : stepDuration < 0.1 ? " 🚨🚨" : stepDuration < 1.0 ? " 🚨🚨🚨" : " 🚨🚨🚨🚨"
        
        NSLog("\(String(repeating: " ", count: currentInfo.level * 2))\(operation): \(step) took \(shared.formatter.string(from: NSNumber(value: stepDuration)) ?? "?") seconds (total \(shared.formatter.string(from: NSNumber(value: totalDuration)) ?? "?") seconds)\(alert)")
        
        newInfo.step = date
        
        shared.info[operation] = newInfo
    }
}

/// Convenience timer for debugging performance of a code scope; automatically prints the info when exiting the scope.
class DebugScopeTimer {
    /// The current operation.
    let operation: String
    
    /// Initializer.  Assign this to a variable to establish the scope, e.g. `let debug = DebugScopeTimer("Thing")` (this will result in a warning, but that can be useful to remind me to remove the timer; can't assign to underscore, as that is immediately released).
    ///
    /// - Parameter operation: The name of the operation to time.
    init(_ operation: String) {
        self.operation = operation
        
        WidgetDebugTimer.start(operation)
    }
    
    /// Deinitializer.  Prints the info when exiting the scope.
    deinit {
        WidgetDebugTimer.print(operation)
    }
}
