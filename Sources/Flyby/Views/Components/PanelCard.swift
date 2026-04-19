import SwiftUI

struct PanelCard<Content: View>: View {
    let content: Content
    private let cornerRadius: CGFloat = 18

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26, *) {
            content
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        }
    }
}
