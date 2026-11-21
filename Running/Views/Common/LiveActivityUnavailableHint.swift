import SwiftUI
import UIKit

/// Slim inline hint shown on training screens while a session runs without
/// Live Activity authorization. iOS asks the user to allow Live Activities on
/// the app's first activity request; if that was declined, the Lock Screen /
/// Dynamic Island card silently never appears — this offers a way back.
struct LiveActivityUnavailableHint: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("live_activity_disabled_title".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("live_activity_disabled_detail".localized)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("live_activity_open_settings".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.Colors.warning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DS.Colors.borderLight))
    }
}
