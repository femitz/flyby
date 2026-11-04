import SwiftUI

struct AppVolumeView: View {
    @ObservedObject var service: AppVolumeService

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("App Volume", systemImage: "speaker.wave.2")
                    .font(.headline)

                if !service.isSupported {
                    note("Per-app volume requires macOS 14.2 or later.")
                } else if service.apps.isEmpty {
                    note("Play audio in an app and it will show up here.")
                } else {
                    ForEach(service.apps) { app in
                        row(for: app)
                    }
                }

                if let error = service.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func row(for app: AudioApp) -> some View {
        let binding = Binding<Double>(
            get: { service.volume(for: app.id) },
            set: { service.setVolume($0, for: app.id) }
        )

        return HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            }

            Text(app.name)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
                .foregroundStyle(app.isPlaying ? .primary : .secondary)

            Slider(value: binding, in: 0...AppVolumeService.maxVolume)

            Text("\(Int(binding.wrappedValue * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
