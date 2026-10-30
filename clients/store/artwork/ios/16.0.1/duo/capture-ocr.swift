// capture-ocr.swift reads screenshot content for capture readiness without modifying native pixels.
import Foundation
import Vision
import AppKit
let url=URL(fileURLWithPath:CommandLine.arguments[1])
let request=VNRecognizeTextRequest()
request.recognitionLevel = .fast
request.recognitionLanguages=["en-US"]
try VNImageRequestHandler(url:url).perform([request])
print((request.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n"))
