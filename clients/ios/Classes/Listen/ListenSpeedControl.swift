//
//  ListenSpeedControl.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// The playback speed scale shared with the web and Android (listen-spec "Speed control"): 0.5–3×, typed to two
/// decimals, a slider over 83 stops that gives the band around 1× about half the track, and ten presets.
enum ListenSpeed {
    static let minimum = 0.5
    static let maximum = 3.0

    /// 0.50–0.80 by 0.05, 0.81–1.20 by 0.01, then 1.25–3.00 by 0.05.
    static let stops: [Double] = {
        var stops: [Double] = []
        for step in 0...6 { stops.append(rounded(0.5 + 0.05 * Double(step))) }
        for step in 1...40 { stops.append(rounded(0.8 + 0.01 * Double(step))) }
        for step in 1...36 { stops.append(rounded(1.2 + 0.05 * Double(step))) }
        return stops
    }()

    static let presets: [Double] = [0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    static var oneIndex: Int { nearestStopIndex(to: 1) }

    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    static func clamped(_ value: Double) -> Double {
        rounded(min(maximum, max(minimum, value)))
    }

    /// A typed value that isn't a stop puts the thumb at the nearest one.
    static func nearestStopIndex(to value: Double) -> Int {
        stops.indices.min { abs(stops[$0] - value) < abs(stops[$1] - value) } ?? 0
    }

    static func isSame(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 0.001
    }

    /// Reads "1.05", "1,05", "1.05×" or "1.05x".
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "")
            .replacingOccurrences(of: "x", with: "")
            .replacingOccurrences(of: "X", with: "")
        return Double(cleaned)
    }

    /// The rate to show: what's playing, else the saved preference.
    static var current: Double {
        ListenPlayer.shared.isActive ? ListenPlayer.shared.speed : ListenPreferences.speed
    }
}

/// The exact-value field, the slider with its 1× tick, and the presets, kept in sync (ListenSpeedControl.swift).
/// A change applies to the playing audio at once; the preference is saved after a short pause.
struct ListenSpeedControl: View {
    @ObservedObject private var player = ListenPlayer.shared
    @ObservedObject private var theme = ListenThemeObserver.shared
    @State private var speed = ListenSpeed.current
    @State private var text = ListenPreferences.numberString(ListenSpeed.current)
    @FocusState private var fieldFocused: Bool

    private static let presetColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        let _ = theme.version
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                valueField
                slider
            }
            LazyVGrid(columns: Self.presetColumns, spacing: 6) {
                ForEach(ListenSpeed.presets, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused {
                commitText()
            }
        }
        .toolbar {
            // ListenSpeedControl.swift: the decimal pad has no return key, so the keyboard gets a Done button.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(NBLocalization.text("Done")) {
                    fieldFocused = false
                }
            }
        }
        .onReceive(player.$speed) { playing in
            // ListenSpeedControl.swift follows the lock screen or another control changing the rate.
            guard player.isActive, !fieldFocused, !ListenSpeed.isSame(playing, speed) else { return }
            speed = playing
            text = ListenPreferences.numberString(playing)
        }
    }

    private var valueField: some View {
        HStack(spacing: 1) {
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundColor(ListenColors.textPrimary)
                .focused($fieldFocused)
                .onSubmit(commitText)
                .frame(width: 44)
                .accessibilityLabel(NBLocalization.text("Playback speed"))
                .accessibilityIdentifier("listen-speed-field")
            Text("×")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ListenColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ListenColors.sheetBackground))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(fieldFocused ? ListenColors.textSecondary : ListenColors.border, lineWidth: fieldFocused ? 1 : 0.5))
        .onTapGesture { fieldFocused = true }
    }

    private var slider: some View {
        Slider(value: Binding(get: { Double(ListenSpeed.nearestStopIndex(to: speed)) }, set: { index in
            let stop = ListenSpeed.stops[min(ListenSpeed.stops.count - 1, max(0, Int(index.rounded())))]
            if !ListenSpeed.isSame(stop, speed) {
                fieldFocused = false
                apply(stop)
            }
        }), in: 0...Double(ListenSpeed.stops.count - 1), step: 1)
        .accessibilityLabel(NBLocalization.text("Playback speed"))
        .accessibilityValue(ListenFormat.speed(speed))
        .background(alignment: .bottom) {
            // ListenSpeedControl.swift marks 1× under the track; the system slider's thumb insets each end.
            GeometryReader { geometry in
                let inset: CGFloat = 13
                let fraction = CGFloat(ListenSpeed.oneIndex) / CGFloat(ListenSpeed.stops.count - 1)
                Capsule()
                    .fill(ListenColors.textSecondary.opacity(0.7))
                    .frame(width: 1.5, height: 6)
                    .position(x: inset + (geometry.size.width - inset * 2) * fraction, y: geometry.size.height + 4)
            }
            .accessibilityHidden(true)
        }
        .padding(.bottom, 4)
    }

    private func presetButton(_ preset: Double) -> some View {
        let selected = ListenSpeed.isSame(preset, speed)
        return Button {
            fieldFocused = false
            apply(preset)
        } label: {
            Text(preset == 1 ? "1×" : ListenPreferences.numberString(preset))
                .font(.system(size: 13, weight: selected ? .semibold : .regular).monospacedDigit())
                .foregroundColor(ListenColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? ListenColors.track : ListenColors.sheetBackground))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? ListenColors.textSecondary.opacity(0.7) : ListenColors.border.opacity(0.6),
                            lineWidth: selected ? 1 : 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ListenFormat.speed(preset))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func commitText() {
        guard let value = ListenSpeed.parse(text) else {
            text = ListenPreferences.numberString(speed)
            return
        }
        apply(value)
    }

    private func apply(_ value: Double) {
        let value = ListenSpeed.clamped(value)
        speed = value
        text = ListenPreferences.numberString(value)
        ListenPlayer.shared.setSpeed(value)
    }
}

/// Now Playing's speed button opens this: the same control in a compact sheet or popover (ListenSpeedControl.swift).
struct ListenSpeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ListenThemeObserver.shared

    var body: some View {
        let _ = theme.version
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(NBLocalization.text("Pitch stays natural at every speed."))
                    .font(.system(size: 12))
                    .foregroundColor(ListenColors.textSecondary)
                ListenSpeedControl()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .background(ListenColors.card.ignoresSafeArea())
            .navigationTitle(NBLocalization.text("Speed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NBLocalization.text("Done")) {
                        dismiss()
                    }
                }
            }
        }
        .tint(ListenColors.textPrimary)
        .environment(\.colorScheme, ListenColors.colorScheme)
        .environment(\.layoutDirection, NBLocalization.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
