import SwiftUI

enum PresenceThemeKind: String, CaseIterable, Identifiable {
    case sunlit
    case editorial
    case signal

    var id: String { rawValue }
}

struct PresenceTheme: Identifiable {
    let kind: PresenceThemeKind
    let name: String
    let summary: String
    let displayDesign: Font.Design
    let bodyDesign: Font.Design
    let backgroundTop: Color
    let backgroundBottom: Color
    let cardBackground: Color
    let elevatedCardBackground: Color
    let heroStart: Color
    let heroEnd: Color
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let inverseText: Color
    let chipBackground: Color
    let chipText: Color
    let chipSelectedBackground: Color
    let chipSelectedText: Color
    let primaryButtonBackground: Color
    let primaryButtonText: Color
    let secondaryButtonBackground: Color
    let accentWarm: Color
    let accentCool: Color
    let accentStrong: Color
    let accentSuccess: Color
    let accentDanger: Color
    let transcriptYou: Color
    let transcriptThem: Color
    let border: Color

    var id: PresenceThemeKind { kind }

    static func forKind(_ kind: PresenceThemeKind) -> PresenceTheme {
        switch kind {
        case .sunlit:
            return PresenceTheme(
                kind: .sunlit,
                name: "Sunlit",
                summary: "Warm, tactile, and optimistic.",
                displayDesign: .rounded,
                bodyDesign: .rounded,
                backgroundTop: Color(red: 0.99, green: 0.93, blue: 0.85),
                backgroundBottom: Color(red: 0.97, green: 0.85, blue: 0.76),
                cardBackground: Color.white.opacity(0.72),
                elevatedCardBackground: Color.white.opacity(0.86),
                heroStart: Color(red: 0.2, green: 0.37, blue: 0.41),
                heroEnd: Color(red: 0.79, green: 0.41, blue: 0.35),
                primaryText: Color(red: 0.14, green: 0.18, blue: 0.21),
                secondaryText: Color(red: 0.31, green: 0.37, blue: 0.41),
                mutedText: Color(red: 0.52, green: 0.56, blue: 0.6),
                inverseText: .white,
                chipBackground: Color.white.opacity(0.58),
                chipText: Color(red: 0.2, green: 0.24, blue: 0.28),
                chipSelectedBackground: Color(red: 0.34, green: 0.51, blue: 0.58),
                chipSelectedText: .white,
                primaryButtonBackground: Color(red: 0.19, green: 0.31, blue: 0.37),
                primaryButtonText: .white,
                secondaryButtonBackground: Color(red: 0.99, green: 0.88, blue: 0.62),
                accentWarm: Color(red: 0.95, green: 0.69, blue: 0.39),
                accentCool: Color(red: 0.48, green: 0.63, blue: 0.72),
                accentStrong: Color(red: 0.69, green: 0.34, blue: 0.28),
                accentSuccess: Color(red: 0.47, green: 0.66, blue: 0.57),
                accentDanger: Color(red: 0.74, green: 0.21, blue: 0.21),
                transcriptYou: Color(red: 0.95, green: 0.82, blue: 0.72),
                transcriptThem: Color(red: 0.98, green: 0.9, blue: 0.82),
                border: Color.white.opacity(0.36)
            )
        case .editorial:
            return PresenceTheme(
                kind: .editorial,
                name: "Editorial",
                summary: "Premium, sharp, and reflective.",
                displayDesign: .serif,
                bodyDesign: .default,
                backgroundTop: Color(red: 0.97, green: 0.95, blue: 0.9),
                backgroundBottom: Color(red: 0.92, green: 0.9, blue: 0.86),
                cardBackground: Color(red: 0.99, green: 0.98, blue: 0.96),
                elevatedCardBackground: Color(red: 0.99, green: 0.98, blue: 0.96),
                heroStart: Color(red: 0.2, green: 0.12, blue: 0.14),
                heroEnd: Color(red: 0.58, green: 0.34, blue: 0.24),
                primaryText: Color(red: 0.13, green: 0.11, blue: 0.1),
                secondaryText: Color(red: 0.35, green: 0.3, blue: 0.27),
                mutedText: Color(red: 0.49, green: 0.44, blue: 0.4),
                inverseText: Color(red: 0.98, green: 0.97, blue: 0.95),
                chipBackground: Color(red: 0.93, green: 0.9, blue: 0.85),
                chipText: Color(red: 0.24, green: 0.18, blue: 0.16),
                chipSelectedBackground: Color(red: 0.44, green: 0.18, blue: 0.16),
                chipSelectedText: Color(red: 0.99, green: 0.97, blue: 0.95),
                primaryButtonBackground: Color(red: 0.24, green: 0.13, blue: 0.14),
                primaryButtonText: Color(red: 0.99, green: 0.97, blue: 0.95),
                secondaryButtonBackground: Color(red: 0.82, green: 0.67, blue: 0.44),
                accentWarm: Color(red: 0.82, green: 0.67, blue: 0.44),
                accentCool: Color(red: 0.36, green: 0.46, blue: 0.53),
                accentStrong: Color(red: 0.61, green: 0.24, blue: 0.16),
                accentSuccess: Color(red: 0.43, green: 0.57, blue: 0.44),
                accentDanger: Color(red: 0.62, green: 0.18, blue: 0.16),
                transcriptYou: Color(red: 0.95, green: 0.91, blue: 0.84),
                transcriptThem: Color(red: 0.9, green: 0.88, blue: 0.92),
                border: Color.black.opacity(0.08)
            )
        case .signal:
            return PresenceTheme(
                kind: .signal,
                name: "Signal",
                summary: "Focused, live, and quietly technical.",
                displayDesign: .monospaced,
                bodyDesign: .rounded,
                backgroundTop: Color(red: 0.08, green: 0.1, blue: 0.12),
                backgroundBottom: Color(red: 0.13, green: 0.16, blue: 0.18),
                cardBackground: Color(red: 0.12, green: 0.15, blue: 0.18),
                elevatedCardBackground: Color(red: 0.14, green: 0.18, blue: 0.21),
                heroStart: Color(red: 0.06, green: 0.21, blue: 0.28),
                heroEnd: Color(red: 0.21, green: 0.48, blue: 0.45),
                primaryText: Color(red: 0.94, green: 0.96, blue: 0.97),
                secondaryText: Color(red: 0.73, green: 0.79, blue: 0.82),
                mutedText: Color(red: 0.57, green: 0.64, blue: 0.68),
                inverseText: Color(red: 0.06, green: 0.08, blue: 0.1),
                chipBackground: Color(red: 0.18, green: 0.22, blue: 0.25),
                chipText: Color(red: 0.84, green: 0.89, blue: 0.91),
                chipSelectedBackground: Color(red: 0.31, green: 0.78, blue: 0.67),
                chipSelectedText: Color(red: 0.06, green: 0.08, blue: 0.1),
                primaryButtonBackground: Color(red: 0.31, green: 0.78, blue: 0.67),
                primaryButtonText: Color(red: 0.06, green: 0.08, blue: 0.1),
                secondaryButtonBackground: Color(red: 0.24, green: 0.65, blue: 0.91),
                accentWarm: Color(red: 0.98, green: 0.72, blue: 0.42),
                accentCool: Color(red: 0.24, green: 0.65, blue: 0.91),
                accentStrong: Color(red: 0.31, green: 0.78, blue: 0.67),
                accentSuccess: Color(red: 0.49, green: 0.83, blue: 0.53),
                accentDanger: Color(red: 1.0, green: 0.45, blue: 0.38),
                transcriptYou: Color(red: 0.15, green: 0.28, blue: 0.24),
                transcriptThem: Color(red: 0.18, green: 0.2, blue: 0.29),
                border: Color.white.opacity(0.08)
            )
        }
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    @Published var selectedKind: PresenceThemeKind = .sunlit

    var current: PresenceTheme {
        PresenceTheme.forKind(selectedKind)
    }
}

struct PresenceBackdrop: View {
    let theme: PresenceTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(theme.accentWarm.opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 20)
                .offset(x: -120, y: -220)

            Circle()
                .fill(theme.heroEnd.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 24)
                .offset(x: 140, y: -150)

            Circle()
                .fill(theme.accentCool.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: 150, y: 260)
        }
    }
}

struct InsightBackdrop: View {
    let theme: PresenceTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.958, blue: 0.906),
                    Color(red: 0.972, green: 0.936, blue: 0.876)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(theme.accentSuccess.opacity(0.11))
                .frame(width: 320, height: 320)
                .blur(radius: 54)
                .offset(x: -150, y: -250)

            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 52)
                .offset(x: 170, y: -110)

            Circle()
                .fill(theme.accentCool.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 56)
                .offset(x: 110, y: 250)
        }
    }
}

private struct PresencePanelModifier: ViewModifier {
    let theme: PresenceTheme
    let prominence: PresencePanelProminence
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(panelBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 12)
    }

    private var panelBackground: AnyShapeStyle {
        if theme.kind == .sunlit {
            switch prominence {
            case .standard:
                AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.72),
                            theme.backgroundTop.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .elevated:
                AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            theme.secondaryButtonBackground.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .hero:
                AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            theme.heroStart,
                            theme.heroEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        } else {
            switch prominence {
            case .standard:
                AnyShapeStyle(theme.cardBackground)
            case .elevated:
                AnyShapeStyle(theme.elevatedCardBackground)
            case .hero:
                AnyShapeStyle(
                    LinearGradient(
                        colors: [theme.heroStart, theme.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
    }

    private var shadowColor: Color {
        theme.kind == .sunlit ? theme.heroEnd.opacity(0.12) : .black.opacity(0.08)
    }

    private var shadowRadius: CGFloat {
        theme.kind == .sunlit ? 24 : 10
    }
}

enum PresencePanelProminence {
    case standard
    case elevated
    case hero
}

extension View {
    func presencePanel(
        theme: PresenceTheme,
        prominence: PresencePanelProminence = .standard,
        cornerRadius: CGFloat = 24
    ) -> some View {
        modifier(PresencePanelModifier(theme: theme, prominence: prominence, cornerRadius: cornerRadius))
    }
}
