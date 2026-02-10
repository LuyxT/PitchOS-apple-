import SwiftUI
#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let analysisCommandAddMarker = Notification.Name("analysis.command.addMarker")
    static let analysisCommandToggleClip = Notification.Name("analysis.command.toggleClip")
    static let analysisCommandPresentation = Notification.Name("analysis.command.presentation")
    static let analysisCommandCompare = Notification.Name("analysis.command.compare")
    static let analysisCommandPlayPause = Notification.Name("analysis.command.playPause")
    static let analysisCommandStepBackward = Notification.Name("analysis.command.stepBackward")
    static let analysisCommandStepForward = Notification.Name("analysis.command.stepForward")
    static let analysisCommandZoomIn = Notification.Name("analysis.command.zoomIn")
    static let analysisCommandZoomOut = Notification.Name("analysis.command.zoomOut")
    static let trainingCommandCreatePlan = Notification.Name("training.command.createPlan")
    static let trainingCommandStartLive = Notification.Name("training.command.startLive")
    static let trainingCommandCompleteStep = Notification.Name("training.command.completeStep")
    static let adminCommandNewPerson = Notification.Name("admin.command.newPerson")
    static let adminCommandNewGroup = Notification.Name("admin.command.newGroup")
    static let adminCommandNewInvitation = Notification.Name("admin.command.newInvitation")
    static let adminCommandRefresh = Notification.Name("admin.command.refresh")
    static let cashCommandCreateTransaction = Notification.Name("cash.command.createTransaction")
    static let cashCommandRefresh = Notification.Name("cash.command.refresh")
}

struct PitchInsightsCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu("PitchInsights") {
            Button("Über PitchInsights") {
                showAboutPanel()
            }
        }

        CommandMenu("Datei") {
            Button("Neues Fenster") {
                appState.openFloatingWindow(appState.activeModule)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        CommandMenu("Fenster") {
            Button("Schließen") {
                sendWindowActionClose()
            }
            .keyboardShortcut("w", modifiers: [.command])

            Button("Minimieren") {
                sendWindowActionMinimize()
            }
            .keyboardShortcut("m", modifiers: [.command])

            Button("Zoomen") {
                sendWindowActionZoom()
            }
        }

        CommandMenu("Analyse") {
            Button("Marker setzen") {
                postAnalysisCommand(.analysisCommandAddMarker)
            }
            .keyboardShortcut("m", modifiers: [.command])
            .disabled(appState.activeModule != .spielanalyse)

            Button("Clip Start/Ende") {
                postAnalysisCommand(.analysisCommandToggleClip)
            }
            .keyboardShortcut("k", modifiers: [.command])
            .disabled(appState.activeModule != .spielanalyse)

            Divider()

            Button("Play/Pause") {
                postAnalysisCommand(.analysisCommandPlayPause)
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(appState.activeModule != .spielanalyse)

            Button("Frame zurück") {
                postAnalysisCommand(.analysisCommandStepBackward)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(appState.activeModule != .spielanalyse)

            Button("Frame vor") {
                postAnalysisCommand(.analysisCommandStepForward)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(appState.activeModule != .spielanalyse)

            Divider()

            Button("Timeline Zoom rein") {
                postAnalysisCommand(.analysisCommandZoomIn)
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(appState.activeModule != .spielanalyse)

            Button("Timeline Zoom raus") {
                postAnalysisCommand(.analysisCommandZoomOut)
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(appState.activeModule != .spielanalyse)

            Divider()

            Button("Präsentationsmodus") {
                postAnalysisCommand(.analysisCommandPresentation)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(appState.activeModule != .spielanalyse)

            Button("Vergleichsmodus") {
                postAnalysisCommand(.analysisCommandCompare)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(appState.activeModule != .spielanalyse)
        }

        CommandMenu("Training") {
            Button("Neues Training") {
                postTrainingCommand(.trainingCommandCreatePlan)
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(appState.activeModule != .trainingsplanung)

            Button("Live-Modus starten") {
                postTrainingCommand(.trainingCommandStartLive)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(appState.activeModule != .trainingsplanung)

            Button("Nächsten Schritt abschließen") {
                postTrainingCommand(.trainingCommandCompleteStep)
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(appState.activeModule != .trainingsplanung)
        }

        CommandMenu("Verwaltung") {
            Button("Person hinzufügen") {
                postAdminCommand(.adminCommandNewPerson)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(appState.activeModule != .verwaltung)

            Button("Gruppe erstellen") {
                postAdminCommand(.adminCommandNewGroup)
            }
            .keyboardShortcut("g", modifiers: [.command, .option])
            .disabled(appState.activeModule != .verwaltung)

            Button("Einladung senden") {
                postAdminCommand(.adminCommandNewInvitation)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(appState.activeModule != .verwaltung)

            Divider()

            Button("Verwaltung aktualisieren") {
                postAdminCommand(.adminCommandRefresh)
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(appState.activeModule != .verwaltung)
        }

        CommandMenu("Kasse") {
            Button("Neue Buchung") {
                postCashCommand(.cashCommandCreateTransaction)
            }
            .keyboardShortcut("n", modifiers: [.command, .control])
            .disabled(appState.activeModule != .mannschaftskasse)

            Button("Kasse aktualisieren") {
                postCashCommand(.cashCommandRefresh)
            }
            .keyboardShortcut("r", modifiers: [.command, .control])
            .disabled(appState.activeModule != .mannschaftskasse)
        }
    }

    private func postAnalysisCommand(_ name: Notification.Name) {
        guard appState.activeModule == .spielanalyse else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func postTrainingCommand(_ name: Notification.Name) {
        guard appState.activeModule == .trainingsplanung else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func postAdminCommand(_ name: Notification.Name) {
        guard appState.activeModule == .verwaltung else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func postCashCommand(_ name: Notification.Name) {
        guard appState.activeModule == .mannschaftskasse else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func sendWindowActionClose() {
        #if os(macOS)
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
        #endif
    }

    private func sendWindowActionMinimize() {
        #if os(macOS)
        NSApp.sendAction(#selector(NSWindow.performMiniaturize(_:)), to: nil, from: nil)
        #endif
    }

    private func sendWindowActionZoom() {
        #if os(macOS)
        NSApp.sendAction(#selector(NSWindow.performZoom(_:)), to: nil, from: nil)
        #endif
    }

    private func showAboutPanel() {
        #if os(macOS)
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }
}
