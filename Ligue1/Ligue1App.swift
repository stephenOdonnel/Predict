//
//  Ligue1App.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
import SwiftUI
import AppKit

@main
struct Ligue1App: App {
    @StateObject private var vm = Ligue1ViewModel()
    @AppStorage(Apparence.cle) private var apparence: Apparence = .systeme

    // Pas de mot de passe : l'application s'ouvre directement.

    var body: some Scene {
        WindowGroup("Ligue 1") {
            MenuView()
                .frame(minWidth: 1080, minHeight: 700)
                .environmentObject(vm)
                .environment(\.locale, Format.fr)
                .preferredColorScheme(apparence.colorScheme)
                // Le catalogue d'assets n'est pas compilé : la teinte de l'app vient du jeton.
                .tint(Theme.accent)
                .onAppear { apparence.appliquerAAppKit() }
                .onChange(of: apparence) { _, nouvelle in nouvelle.appliquerAAppKit() }
        }
        // Barre de titre standard : avec NavigationSplitView elle fusionne avec la
        // barre d'outils (verre liquide sur macOS 26) et porte le titre de la section.
        .windowStyle(.automatic)
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {}
            CommandGroup(after: .toolbar) {
                Picker("Apparence", selection: $apparence) {
                    ForEach(Apparence.allCases) { a in
                        Label(a.titre, systemImage: a.icone).tag(a)
                    }
                }
            }
        }

        Settings {
            // Le TabView reste la racine de la scène (barre d'icônes).
            ParametresView()
                .environmentObject(vm)
                .environment(\.locale, Format.fr)
                .preferredColorScheme(apparence.colorScheme)
                .tint(Theme.accent)
        }
    }
}
