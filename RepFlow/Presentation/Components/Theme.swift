import SwiftUI

// MARK: - Color tokens

enum RFColor {
    static let bg          = Color(red: 11/255,  green: 11/255,  blue: 14/255)
    static let bgElevated  = Color(red: 19/255,  green: 19/255,  blue: 24/255)
    static let bgSubtle    = Color(red: 26/255,  green: 26/255,  blue: 32/255)

    static let border       = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.14)

    static let fg          = Color.white
    static let fgMuted     = Color.white.opacity(0.62)
    static let fgSubtle    = Color.white.opacity(0.42)

    static let accent      = Color(red: 1.0,    green: 0.42,  blue: 0.08)
    static let accentSoft  = Color(red: 1.0,    green: 0.42,  blue: 0.08).opacity(0.12)
    static let success     = Color(red: 0.18,   green: 0.83,  blue: 0.64)
    static let warning     = Color(red: 0.94,   green: 0.71,  blue: 0.16)
    static let danger      = Color(red: 0.90,   green: 0.28,  blue: 0.30)
}

// MARK: - Typography

extension Font {
    static let rfDisplayLg = Font.system(size: 34, weight: .heavy, design: .default)
    static let rfDisplayMd = Font.system(size: 28, weight: .bold, design: .default)
    static let rfTitleLg   = Font.system(size: 22, weight: .bold, design: .default)
    static let rfTitleMd   = Font.system(size: 17, weight: .semibold, design: .default)
    static let rfBody      = Font.system(size: 15, weight: .regular, design: .default)
    static let rfCaption   = Font.system(size: 13, weight: .regular, design: .default)
    static let rfCaptionSm = Font.system(size: 11, weight: .medium, design: .default)

    static let rfMonoLg   = Font.system(size: 28, weight: .bold, design: .default).monospacedDigit()
    static let rfMonoBody = Font.system(size: 14, weight: .medium, design: .default).monospacedDigit()
}

// MARK: - Spacing

enum RFSpace {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Radius

enum RFRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
}

// MARK: - View modifiers

extension View {
    /// Linear-style card — elevated bg + subtle border
    func rfCard(padding: CGFloat = RFSpace.lg) -> some View {
        self
            .padding(padding)
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: RFRadius.md)
                    .stroke(RFColor.border, lineWidth: 1)
            )
    }

    /// Subtle pill / chip
    func rfChip(_ color: Color = RFColor.accent) -> some View {
        self
            .font(.rfCaptionSm.weight(.bold))
            .padding(.horizontal, RFSpace.sm)
            .padding(.vertical, RFSpace.xs)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    /// Section header (small caps muted)
    func rfSectionHeader() -> some View {
        self
            .font(.rfCaptionSm.weight(.semibold))
            .foregroundStyle(RFColor.fgMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: - Buttons

struct RFPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rfTitleMd)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RFColor.accent, in: RoundedRectangle(cornerRadius: RFRadius.sm))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RFSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rfTitleMd)
            .foregroundStyle(RFColor.fg)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RFColor.bgSubtle, in: RoundedRectangle(cornerRadius: RFRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: RFRadius.sm)
                    .stroke(RFColor.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
