import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Edits the Flyby Dock profiles, shown inside the panel like Preferences.
struct DockProfilesView: View {
    let onBack: () -> Void

    @ObservedObject private var dock = DockService.shared
    @State private var dragging: DraggedApp?
    /// The profile whose app picker is open, if any.
    @State private var pickingFor: UUID?

    var body: some View {
        if let id = pickingFor, let profile = dock.profiles.first(where: { $0.id == id }) {
            AppPickerView(profile: profile) { pickingFor = nil }
        } else {
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Label("Voltar", systemImage: "chevron.left")
                }
                .buttonStyle(BrandButtonStyle())
                .padding(.leading, -14)

                Spacer()

                Text("Perfis do Dock")
                    .font(Brand.sans(18, .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Brand.lua)
            }

            Text("Ctrl + scroll em cima do Dock troca de perfil. Arraste um app do Finder para o Dock para incluí-lo no perfil ativo.")
                .font(Brand.sans(12))
                .foregroundStyle(Brand.poeira)
                .fixedSize(horizontal: false, vertical: true)

            // Two cards fit; more scroll, so the panel never grows past the screen.
            if dock.profiles.count > 2 {
                ScrollView { cards }.frame(height: 420)
            } else {
                cards
            }

            Button {
                dock.addProfile()
            } label: {
                Label("Novo perfil", systemImage: "plus")
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.leading, -14)
        }
    }

    private var cards: some View {
        VStack(spacing: 10) {
            ForEach(dock.profiles) { profile in
                ProfileCard(
                    profile: profile,
                    isActive: profile.id == dock.activeProfileID,
                    canRemove: dock.profiles.count > 1,
                    dragging: $dragging,
                    onAdd: { pickingFor = profile.id }
                )
            }
        }
    }
}

struct DraggedApp: Equatable {
    let profileID: UUID
    let bundleID: String
}

private struct ProfileCard: View {
    let profile: DockProfile
    let isActive: Bool
    let canRemove: Bool
    @Binding var dragging: DraggedApp?
    let onAdd: () -> Void

    @ObservedObject private var dock = DockService.shared

    private let columns = [GridItem(.adaptive(minimum: 40, maximum: 40), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // The active profile is where the dock is right now: the one accent mark.
                Circle()
                    .fill(isActive ? Brand.ignicao : Brand.orbita)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                TextField("Nome do perfil", text: Binding(
                    get: { profile.name },
                    set: { dock.renameProfile(profile.id, to: $0) }
                ))
                .textFieldStyle(.plain)
                .font(Brand.sans(13, .medium))
                .foregroundStyle(Brand.lua)

                if !isActive {
                    Button("Usar") { dock.activateProfile(profile.id) }
                        .buttonStyle(.plain)
                        .font(Brand.sans(12, .medium))
                        .foregroundStyle(Brand.lua)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Brand.orbita, lineWidth: 1))
                }

                Button {
                    dock.removeProfile(profile.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(canRemove ? Brand.poeira : Brand.muted)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canRemove)
                .help("Apagar perfil")
                .accessibilityLabel("Apagar \(profile.name)")
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(profile.items, id: \.bundleID) { item in
                    if let entry = dock.entry(for: item) {
                        AppTile(entry: entry) { dock.removeApp(item.bundleID, from: profile.id) }
                            .onDrag {
                                dragging = DraggedApp(profileID: profile.id, bundleID: item.bundleID)
                                return NSItemProvider(object: item.bundleID as NSString)
                            }
                            .onDrop(of: [.text], delegate: ReorderDelegate(
                                target: item.bundleID, profileID: profile.id, dragging: $dragging
                            ))
                    }
                }
                addTile
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.vacuo))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Brand.orbita, lineWidth: 1)
        )
    }

    private var addTile: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Brand.poeira)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Brand.orbita, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Adicionar apps")
        .accessibilityLabel("Adicionar apps a \(profile.name)")
    }
}

/// An app in a profile card. Hover shows a remove badge; right-click offers the same.
private struct AppTile: View {
    let entry: DockEntry
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        Image(nsImage: entry.icon)
            .resizable()
            .interpolation(.high)
            .frame(width: 40, height: 40)
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Brand.lua)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Brand.orbita))
                            .overlay(Circle().strokeBorder(Brand.vacuo, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                    .accessibilityLabel("Remover \(entry.name)")
                }
            }
            .onHover { hovering = $0 }
            .help(entry.name)
            .contextMenu {
                Button("Remover do perfil", action: onRemove)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(entry.name)
    }
}

/// Live reordering: the dragged app takes the place of whichever app it passes over.
/// Only reorders within the profile the drag started in.
private struct ReorderDelegate: DropDelegate {
    let target: String
    let profileID: UUID
    @Binding var dragging: DraggedApp?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.profileID == profileID, dragging.bundleID != target else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            DockService.shared.moveApp(dragging.bundleID, to: target, in: profileID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// Picks a profile's apps from the installed ones, inside the panel. (A system file chooser
/// would open in another window, and Flyby's panel closes on clicks outside of it.)
private struct AppPickerView: View {
    let profile: DockProfile
    let onDone: () -> Void

    @ObservedObject private var dock = DockService.shared
    @State private var apps: [InstalledApp] = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [InstalledApp] {
        let visible = apps.filter { !dock.isFixed(bundleID: $0.bundleID) }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? visible : visible.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    BrandLabel("Apps de")
                    Text(profile.name)
                        .font(Brand.sans(18, .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(Brand.lua)
                        .lineLimit(1)
                }
                Spacer()
                Button("Concluir", action: onDone)
                    .buttonStyle(.plain)
                    .font(Brand.sans(13, .semibold))
                    .foregroundStyle(Brand.vacuo)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.lua))
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.poeira)
                TextField("Buscar app", text: $query)
                    .textFieldStyle(.plain)
                    .font(Brand.sans(13))
                    .foregroundStyle(Brand.lua)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.vacuo))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Brand.orbita, lineWidth: 1))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { app in
                        row(app)
                    }
                }
            }
            .frame(height: 380)
            .overlay {
                if loading {
                    Text("Procurando apps…").font(Brand.mono(11)).foregroundStyle(Brand.poeira)
                } else if filtered.isEmpty {
                    Text("Nenhum app encontrado").font(Brand.mono(11)).foregroundStyle(Brand.poeira)
                }
            }
        }
        .task {
            apps = await InstalledApps.scan()
            loading = false
        }
    }

    private func row(_ app: InstalledApp) -> some View {
        let included = profile.items.contains { $0.bundleID == app.bundleID }
        return Button {
            if included {
                dock.removeApp(app.bundleID, from: profile.id)
            } else {
                dock.addApps([app.url], to: profile.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                Text(app.name)
                    .font(Brand.sans(13, included ? .medium : .regular))
                    .foregroundStyle(included ? Brand.lua : Brand.textSoft)
                    .lineLimit(1)
                Spacer()
                // Checked apps are the ones going into the dock: the accent marks them.
                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(included ? Brand.ignicao : Brand.orbita)
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(PickerRowStyle())
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(included ? .isSelected : [])
    }
}

private struct PickerRowStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering || configuration.isPressed ? Brand.orbita.opacity(0.6) : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}
