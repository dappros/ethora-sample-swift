//
//  HeadlessTabView.swift
//  SDKPlayground
//
//  Manual smoke-test surface for `ChatHeadlessSession` + `UnreadStateBridge`:
//  starts the headless pipeline (auth → XMPP → rooms sync → MUC presence →
//  unread recompute) without mounting `ChatWrapperView`, and shows the
//  resulting `totalUnreadCount` plus per-room badges live as messages
//  arrive from another client.
//

import SwiftUI
import Combine
import XMPPChatCore

@MainActor
final class HeadlessUnreadObserver: ObservableObject {
    @Published private(set) var totalUnread: Int = 0
    @Published private(set) var unreadByRoom: [String: Int] = [:]
    @Published private(set) var statusText: String = "idle"

    private let bridge = UnreadStateBridge()
    private var cancellables = Set<AnyCancellable>()

    init() {
        bridge.$totalUnreadCount
            .receive(on: RunLoop.main)
            .assign(to: &$totalUnread)

        bridge.$unreadByRoom
            .receive(on: RunLoop.main)
            .assign(to: &$unreadByRoom)

        ChatHeadlessSession.shared.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.statusText = Self.describe(status)
            }
            .store(in: &cancellables)
    }

    private static func describe(_ status: ChatHeadlessSession.Status) -> String {
        switch status {
        case .idle: return "idle"
        case .authenticating: return "authenticating…"
        case .connecting: return "connecting XMPP…"
        case .syncingRooms: return "syncing rooms…"
        case .ready: return "ready (live)"
        case .failed(let msg): return "failed: \(msg)"
        }
    }
}

struct HeadlessTabView: View {
    @EnvironmentObject private var session: PlaygroundSession
    @EnvironmentObject private var log: PlaygroundLogStore
    @StateObject private var observer = HeadlessUnreadObserver()

    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    HStack {
                        Text("Session")
                        Spacer()
                        Text(observer.statusText)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Total unread")
                        Spacer()
                        Text("\(observer.totalUnread)")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        startHeadless()
                    } label: {
                        Label("Start headless session", systemImage: "play.fill")
                    }
                    Button(role: .destructive) {
                        stopHeadless()
                    } label: {
                        Label("Stop headless session", systemImage: "stop.fill")
                    }
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Uses values from Setup tab (auth + base URL + XMPP). Does not mount ChatWrapperView. The XMPP client is registered globally, so opening the Chat tab afterwards reuses the same socket.")
                }

                Section("Rooms (live unread)") {
                    if observer.unreadByRoom.isEmpty {
                        Text("No rooms yet — start the session.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sortedRoomEntries(), id: \.0) { jid, count in
                            HStack {
                                Text(roomLocal(jid))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(count)")
                                    .monospacedDigit()
                                    .foregroundColor(count > 0 ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Headless")
        }
    }

    private func sortedRoomEntries() -> [(String, Int)] {
        observer.unreadByRoom
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
    }

    private func roomLocal(_ jid: String) -> String {
        jid.components(separatedBy: "@").first ?? jid
    }

    private func startHeadless() {
        log.append("Headless: starting session…", level: .info)
        let config = session.buildChatConfig()
        ChatHeadlessSession.shared.start(config: config)
    }

    private func stopHeadless() {
        log.append("Headless: stopping session…", level: .info)
        Task {
            await ChatHeadlessSession.shared.stop()
            log.append("Headless: stopped.", level: .info)
        }
    }
}
