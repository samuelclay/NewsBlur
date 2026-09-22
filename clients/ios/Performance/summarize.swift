// summarize.swift reports opt-in ReaderPerformance.swift events inside a recorded gesture session.
import Foundation

struct Session: Decodable {
    let started_at: Double
    let ended_at: Double
}

struct Event: Decodable {
    let metric: String
    let ms: Double
    let at: Double
    let budget_ms: Double?
}

struct Summary: Encodable {
    let metric: String
    let count: Int
    let mean_ms: Double
    let p50_ms: Double
    let p95_ms: Double
    let max_ms: Double
    let frame_gaps: Int?
    let frame_gap_percent: Double?
    let excess_frame_time_ms: Double?
}

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
var results = [String: [Summary]]()

for path in CommandLine.arguments.dropFirst() {
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    let session = try decoder.decode(Session.self, from: Data(contentsOf: directory.appendingPathComponent("session.json")))
    let data = try String(contentsOf: directory.appendingPathComponent("measurements.jsonl"), encoding: .utf8)
    let events = try data.split(separator: "\n").map { try decoder.decode(Event.self, from: Data($0.utf8)) }
        .filter { $0.at >= session.started_at && $0.at <= session.ended_at }
    results[directory.lastPathComponent] = Dictionary(grouping: events, by: \.metric).sorted { $0.key < $1.key }.map { metric, events in
        let durations = events.map(\.ms).sorted()
        func percentile(_ fraction: Double) -> Double {
            durations[max(0, Int(ceil(Double(durations.count) * fraction)) - 1)]
        }
        let frames = events.filter { ($0.budget_ms ?? 0) > 0 }
        let gaps = frames.filter { $0.ms > $0.budget_ms! * 1.5 }
        return Summary(metric: metric, count: events.count,
                       mean_ms: durations.reduce(0, +) / Double(durations.count),
                       p50_ms: percentile(0.5), p95_ms: percentile(0.95), max_ms: durations.last!,
                       frame_gaps: frames.isEmpty ? nil : gaps.count,
                       frame_gap_percent: frames.isEmpty ? nil : Double(gaps.count) / Double(frames.count) * 100,
                       excess_frame_time_ms: frames.isEmpty ? nil : gaps.reduce(0) { $0 + max(0, $1.ms - $1.budget_ms!) })
    }
}

FileHandle.standardOutput.write(try encoder.encode(results))
FileHandle.standardOutput.write(Data([10]))
