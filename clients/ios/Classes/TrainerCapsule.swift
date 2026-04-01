//
//  TrainerCapsule.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-02.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

struct DoubleThumbsDownIcon: View {
    var size: CGFloat = 14
    var color: Color = .white

    var body: some View {
        ZStack {
            Image(systemName: "hand.thumbsdown.fill")
                .font(.system(size: size * 0.75))
                .foregroundColor(color.opacity(0.55))
                .offset(x: -size * 0.18, y: -size * 0.18)
            Image(systemName: "hand.thumbsdown.fill")
                .font(.system(size: size * 0.75))
                .foregroundColor(color)
                .offset(x: size * 0.12, y: size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

struct TrainerCapsule: View {
    var score: Feed.Score

    var header: String

    var image: UIImage?

    var value: String

    var count: Int = 0

    var isRegex: Bool = false

    var showsScope: Bool = false
    @Binding var scope: ClassifierScope
    var isPremiumArchive: Bool = false
    var onScopeChanged: ((ClassifierScope) -> Void)?

    var onDislike: (() -> Void)?
    var onSuperDislike: (() -> Void)?

    init(score: Feed.Score, header: String, image: UIImage? = nil, value: String, count: Int = 0, isRegex: Bool = false, showsScope: Bool = false, scope: Binding<ClassifierScope> = .constant(.feed), isPremiumArchive: Bool = false, onScopeChanged: ((ClassifierScope) -> Void)? = nil, onDislike: (() -> Void)? = nil, onSuperDislike: (() -> Void)? = nil) {
        self.score = score
        self.header = header
        self.image = image
        self.value = value
        self.count = count
        self.isRegex = isRegex
        self.showsScope = showsScope
        self._scope = scope
        self.isPremiumArchive = isPremiumArchive
        self.onScopeChanged = onScopeChanged
        self.onDislike = onDislike
        self.onSuperDislike = onSuperDislike
    }

    var body: some View {
        HStack {
            if isRegex {
                regexBody
            } else {
                normalBody
            }

            if count > 0 {
                Text("x \(count)")
                    .colored(.gray)
                    .padding([.trailing], 10)
            }
        }
    }

    @ViewBuilder
    var scoreIcon: some View {
        if score == .superDislike {
            DoubleThumbsDownIcon(size: 16, color: .white)
        } else {
            Image(systemName: score.imageName)
                .foregroundColor(.white)
        }
    }

    var normalBody: some View {
        HStack(spacing: 0) {
            HStack {
                scoreIcon

                if showsScope {
                    ScopeToggleView(classifierType: header, activeScope: $scope, score: score, isPremiumArchive: isPremiumArchive, onScopeChanged: onScopeChanged)
                }

                content
            }
            .padding([.top, .bottom], 5)
            .padding([.leading], 10)
            .padding([.trailing], onDislike != nil ? 6 : 10)

            if let onDislike, let onSuperDislike {
                trailingButtons(onDislike: onDislike, onSuperDislike: onSuperDislike)
                    .padding(.trailing, 4)
            }
        }
        .background(Capsule().fill(capsuleBackground))
    }

    var dislikeIconColor: Color {
        if score == .dislike { return .white }
        if isActive { return .white.opacity(0.5) }
        return Color.themed([0xA90103, 0xA90103, 0xE87272, 0xE87272])
    }

    var superDislikeIconColor: Color {
        if score == .superDislike { return .white }
        if isActive { return .white.opacity(0.5) }
        return Color.themed([0x6B0001, 0x6B0001, 0xFF6B6B, 0xFF6B6B])
    }

    var dividerColor: Color {
        isActive ? Color.white.opacity(0.25) : Color.themed([0xBBBBBB, 0xB0A090, 0x777777, 0x777777])
    }

    func trailingButtons(onDislike: @escaping () -> Void, onSuperDislike: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            Rectangle()
                .fill(dividerColor)
                .frame(width: 1, height: 18)

            Button(action: onDislike) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(dislikeIconColor)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(score == .dislike ? Color.red : Color.clear)
                    )
            }
            .buttonStyle(BorderlessButtonStyle())

            Button(action: onSuperDislike) {
                DoubleThumbsDownIcon(size: 14, color: superDislikeIconColor)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(score == .superDislike ? Color(red: 0.42, green: 0, blue: 0.004) : Color.clear)
                    )
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    var regexBody: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if score == .superDislike {
                    DoubleThumbsDownIcon(size: 14, color: regexIconColor)
                } else {
                    Image(systemName: score.imageName)
                        .foregroundColor(regexIconColor)
                }

                if showsScope {
                    ScopeToggleView(classifierType: header, activeScope: $scope, score: score, isPremiumArchive: isPremiumArchive, onScopeChanged: onScopeChanged)
                }

                Text(header.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(regexBadgeBackground)
                    .cornerRadius(3)

                Text(value)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(regexValueColor)
            }
            .padding([.top, .bottom], 6)
            .padding([.leading], 10)
            .padding([.trailing], onDislike != nil ? 6 : 12)

            if let onDislike, let onSuperDislike {
                trailingButtons(onDislike: onDislike, onSuperDislike: onSuperDislike)
                    .padding(.trailing, 4)
            }
        }
        .background(Capsule().fill(regexCapsuleBackground))
        .overlay(
            Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(dashedBorderColor)
        )
    }

    var isActive: Bool {
        score == .like || score == .dislike || score == .superDislike
    }

    var capsuleBackground: Color {
        if score == .like {
            return Color(red: 0, green: 0.5, blue: 0.0)
        } else if score == .superDislike {
            return Color(red: 0.42, green: 0, blue: 0.004)
        } else if score == .dislike {
            return Color.red
        } else {
            return Color.themed([0xD8D8D8, 0xD0C4B4, 0x595959, 0x595959])
        }
    }

    var regexCapsuleBackground: Color {
        if score == .like {
            return Color(red: 0, green: 0.5, blue: 0.0)
        } else if score == .superDislike {
            return Color(red: 0.42, green: 0, blue: 0.004)
        } else if score == .dislike {
            return Color.red
        } else {
            return Color.themed([0xE8EAF6, 0xE8DFD0, 0x2A2C3E, 0x2A2C3E])
        }
    }

    var regexBadgeBackground: Color {
        if isActive {
            return Color.white.opacity(0.25)
        } else {
            return Color(red: 0.482, green: 0.408, blue: 0.933) // #7B68EE
        }
    }

    var regexIconColor: Color {
        if isActive {
            return .white
        } else {
            return Color(red: 0.475, green: 0.525, blue: 0.795) // #7986CB
        }
    }

    var regexValueColor: Color {
        if isActive {
            return .white
        } else {
            return Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0])
        }
    }

    var dashedBorderColor: Color {
        if score == .like {
            return Color(red: 0, green: 0.35, blue: 0.0)
        } else if score == .superDislike {
            return Color(red: 0.42, green: 0, blue: 0)
        } else if score == .dislike {
            return Color(red: 0.7, green: 0, blue: 0)
        } else {
            return Color(red: 0.475, green: 0.525, blue: 0.795) // #7986CB
        }
    }

    var content: Text {
        if isActive {
            Text("\(Text("\(header):").colored(.init(white: 0.85))) \(imageText)\(value)")
                .colored(.white)
        } else {
            Text("\(Text("\(header):").colored(.init(white: 0.45))) \(imageText)\(value)")
                .colored(Color.themed([0x333333, 0x3C3226, 0xE0E0E0, 0xE0E0E0]))
        }
    }

    var imageText: Text {
        if let image {
            Text(Image(uiImage: image)).baselineOffset(-3) + Text(" ")
        } else {
            Text("")
        }
    }
}

#Preview {
    TrainerCapsule(score: .none, header: "Tag", value: "None Example")
}

#Preview {
    TrainerCapsule(score: .like, header: "Tag", value: "Liked Example")
}

#Preview {
    TrainerCapsule(score: .dislike, header: "Tag", value: "Disliked Example")
}
