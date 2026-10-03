// main.swift audits live API snapshots with the same selector used by onboarding.
import Foundation
import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: onboarding-catalog-audit input.json output-prefix\n", stderr)
    exit(2)
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let prefix = CommandLine.arguments[2]
let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [String: [[String: Any]]]
func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
}
var reports: [[String: Any]] = []
var sections: [String] = []
var failed = 0
let contactSheet = NSImage(size: NSSize(width: 1200, height: 3100))
contactSheet.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1200, height: 3100).fill()
for category in OnboardingCatalogSelector.canonicalInterests(Array(catalog.keys)) {
    let labels = OnboardingCatalogSelector.categoryAliases(for: category)
    let entries = labels.flatMap { catalog[$0] ?? [] }
    let selected = OnboardingCatalogSelector.select(entries, interest: category)
    let passed = selected.icons.count >= 5 && selected.feeds.count >= 5
    let column = reports.count % 2
    let row = reports.count / 2
    let x = CGFloat(column * 600 + 24)
    let y = CGFloat(3100 - row * 124 - 34)
    (category.capitalized as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.boldSystemFont(ofSize: 19), .foregroundColor: NSColor.black
    ])
    for (index, entry) in selected.icons.enumerated() {
        if let encoded = OnboardingCatalogSelector.favicon(entry),
           let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
           let icon = NSImage(data: data) {
            icon.draw(in: NSRect(x: x + CGFloat(index * 100), y: y - 58, width: 42, height: 42))
        }
    }
    if !passed { failed += 1 }
    let feeds = selected.feeds.map { row -> [String: Any] in
        ["title": row["title"] as? String ?? "", "url": OnboardingCatalogSelector.address(row),
         "source": row["feed_type"] as? String ?? "", "feed_id": row["feed_id"] ?? NSNull(),
         "last_story_date": (row["feed"] as? [String: Any])?["last_story_date"] ?? NSNull(),
         "story_titles": (row["stories"] as? [[String: Any]] ?? []).compactMap { $0["story_title"] as? String }]
    }
    reports.append(["category": category, "aliases": labels, "candidates": entries.count,
                    "selected": feeds, "icon_count": selected.icons.count,
                    "rejected": selected.rejected, "passed": passed])
    let icons = selected.icons.map { row -> String in
        let title = row["title"] as? String ?? ""
        let data = OnboardingCatalogSelector.favicon(row) ?? ""
        return "<figure><img src=\"data:image/png;base64,\(escape(data))\"><figcaption>\(escape(title))</figcaption></figure>"
    }.joined()
    let rows = feeds.map { row -> String in
        let stories = (row["story_titles"] as? [String] ?? []).prefix(3).map { "<li>\(escape($0))</li>" }.joined()
        return "<tr><td><a href=\"\(escape(row["url"] as! String))\">\(escape(row["title"] as! String))</a><br><small>\(escape(row["source"] as! String))</small></td><td><ul>\(stories)</ul></td></tr>"
    }.joined()
    sections.append("<section><h2>\(escape(category.capitalized)) <small>\(passed ? "PASS" : "GAP")</small></h2><p>\(entries.count) candidates · \(selected.feeds.count) selected · \(selected.icons.count) distinct validated icons</p><p>Catalog labels: \(escape(labels.joined(separator: ", ")))</p><div class=\"icons\">\(icons)</div><details><summary>Selected feeds and English story samples</summary><table>\(rows)</table></details></section>")
    print("\(passed ? "PASS" : "GAP") \(category): \(selected.feeds.count) feeds, \(selected.icons.count) icons; rejected \(selected.rejected)")
}
contactSheet.unlockFocus()
if let tiff = contactSheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: prefix + ".png"))
}
let report: [String: Any] = ["audited_at": ISO8601DateFormatter().string(from: Date()), "input_labels": catalog.count,
                            "interests": reports.count, "gaps": failed, "categories": reports]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: prefix + ".json"))
let html = """
<!doctype html><meta charset="utf-8"><title>NewsBlur onboarding category audit</title>
<style>body{font:16px system-ui;background:#f5f1e9;color:#393b36;margin:40px auto;max-width:1100px;padding:0 24px}h1{font-size:32px}section{padding:24px;background:white;border-radius:16px;margin:20px 0}h2{margin-top:0}small,p,summary{color:#687168}.icons{display:flex;gap:24px;margin:24px 0}figure{margin:0;flex:1}img{width:44px;height:44px;object-fit:contain}figcaption{font-size:14px;margin-top:8px}table{border-collapse:collapse;width:100%;margin-top:16px}td{border-top:1px solid #ddd;padding:12px;vertical-align:top}td:first-child{width:30%}ul{margin:0;padding-left:20px}a{color:#346763}</style>
<h1>NewsBlur onboarding category audit</h1><p>\(catalog.count) input labels → \(reports.count) interests · \(failed) gaps · \(ISO8601DateFormatter().string(from: Date()))</p>
<p>Checks use decoded image pixels, distinct icons, working feed metadata, and English language detection on recent story titles. Samples do not establish the language of every historical or future story.</p>
\(sections.joined(separator: "\n"))
"""
try html.write(toFile: prefix + ".html", atomically: true, encoding: .utf8)
exit(failed == 0 ? 0 : 1)
