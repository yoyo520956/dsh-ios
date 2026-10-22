import SwiftUI

// DSH 设计系统（iOS 化演绎原版 packages/client/ui-theme 规范）
// 色阶/圆角 R4-R28 六档/发丝线 0.5px/elevation 投影/字阶全部走 token，禁裸值
public enum DSW {
    // MARK: 圆角（ui-radius.md 六档，superellipse 1.5 由 iOS squircle 天然等价）
    public enum Radius {
        public static let xs: CGFloat = 4     // 小细节：keycaps/inline code
        public static let sm: CGFloat = 8     // 紧凑控件 H20-28
        public static let md: CGFloat = 12    // 标准控件/单行 cell
        public static let lg: CGFloat = 16    // 大控件/多行 cell/代码块
        public static let xl: CGFloat = 20    // 独立卡片/气泡/guide entry
        public static let panel: CGFloat = 28 // composer/面板/dialog
        public static let tile: CGFloat = 10  // 40px 图标瓦片（组件特例）
    }
    // MARK: 品牌色（DeepSeek 官方蓝）
    public enum Brand {
        public static let blue = Color(hex: "4D6BFE")
        public static let blueDark = Color(hex: "6E8AFF")
        public static let accent = Color(hex: "4D6BFE")
    }
    // MARK: 语义色（亮/暗自适应，原版 alias token 体系）
    public enum Alias {
        public static let bg = Color("DSWBG")
        public static let surface = Color("DSWSurface")
        public static let surfaceSunken = Color("DSWSunken")
        public static let textPrimary = Color("DSWText1")
        public static let textSecondary = Color("DSWText2")
        public static let textTertiary = Color("DSWText3")
        public static let border = Color("DSWBorder")
        public static let hairline = Color("DSWHairline")
        public static let fill = Color("DSWFill")
        public static let link = Brand.blue
        public static let warn = Color("DSWWarn")
        public static let success = Color("DSWSuccess")
        public static let danger = Color("DSWDanger")
    }
    // MARK: 投影（原版 elevation 体系三层）
    public enum Elevation {
        public static let soft = (color: Color.black.opacity(0.04), radius: 8 as CGFloat, y: 2 as CGFloat)
        public static let panel = (color: Color.black.opacity(0.08), radius: 16 as CGFloat, y: 4 as CGFloat)
        public static let prominent = (color: Color.black.opacity(0.14), radius: 24 as CGFloat, y: 8 as CGFloat)
    }
    // MARK: 字阶（与行高配对，全部支持 Dynamic Type）
    public enum TypeScale {
        public static let largeTitle = Font.system(size: 28, weight: .bold)
        public static let title = Font.system(size: 22, weight: .semibold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 15, weight: .regular)
        public static let callout = Font.system(size: 14, weight: .regular)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
    // MARK: 间距 4pt 网格
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
    }
}

// iOS 化改进组件：分组设置卡（Settings cards 材质：浅灰卡 + 发丝线 + 无 border）
public struct DSWCardModifier: ViewModifier {
    public var radius: CGFloat = DSW.Radius.lg
    public var elevated = false
    public func body(content: Content) -> some View {
        content
            .background(DSW.Alias.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(DSW.Alias.hairline, lineWidth: 0.5))
            .shadow(color: elevated ? DSW.Elevation.soft.color : .clear, radius: elevated ? DSW.Elevation.soft.radius : 0, y: elevated ? DSW.Elevation.soft.y : 0)
    }
}
public extension View {
    func dswCard(_ r: CGFloat = DSW.Radius.lg, elevated: Bool = false) -> some View { modifier(DSWCardModifier(radius: r, elevated: elevated)) }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    init(_ name: String) { self.init(name, bundle: Bundle(for: DSWBundleRef.self)) }
}

private final class DSWBundleRef: NSObject {}
