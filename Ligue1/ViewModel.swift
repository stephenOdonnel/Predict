//
//  ViewModel.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  SÉCURITÉ (mêmes règles que Finance et MedCompta) :
//  - Fichiers JSON écrits en clair, chacun accompagné d'un sceau HMAC (.hmac).
//  - Aucune écriture si le chargement a échoué : évite d'écraser les données existantes par un contenu vide.
//  - Validation des saisies (scores, xG, cotes et montants finis et bornés, textes bornés).
//  - Export CSV protégé contre l'injection de formules Excel et correctement échappé.
//  - Exports via une fenêtre d'enregistrement (pas de dépôt silencieux).
//  - Limite de taille à la lecture, pas de chemins complets dans les logs.
//
//  Comme l'app Python : chaque modification est enregistrée aussitôt (les
//  cotes, xG et minutes après 0,4 s sans frappe), un score validé réajuste le
//  modèle puis relance le Monte Carlo en arrière-plan.
//
//  Données : CSV de football-data.co.uk (saison en cours, saisons passées,
//  fixtures.csv) que l'utilisateur importe, plus ses saisies. Seul accès
//  réseau : « Mettre à jour en ligne » (et l'écran d'accueil, au premier
//  lancement) télécharge fixtures.csv, le F1.csv de la saison en cours et ceux
//  des saisons passées manquantes (GET sans cookie, rien n'est envoyé) ; avec
//  une clé The Odds API, il télécharge aussi les cotes Winamax, Unibet et
//  Betclic des matchs à venir (seule la clé est envoyée).
//

import SwiftUI
import AppKit
import Foundation
import Combine
import UniformTypeIdentifiers

// MARK: - Revue d'intégrité

/// Une ligne du comparatif présenté avant acceptation.
struct LigneComparaison: Identifiable {
    enum Etat: String {
        case ajoutee = "Ajoutée"
        case supprimee = "Supprimée"
        case modifiee = "Modifiée"
        /// Rien à quoi comparer (altération détectée au démarrage, sans copie de référence).
        case presente = "Dans le fichier"
    }
    /// Clé de l'enregistrement (match, équipe, réglages…), et non de la ligne :
    /// c'est par elle que l'utilisateur accepte ou rejette cette modification-là.
    let id: String
    let etat: Etat
    let avant: String?
    let apres: String?

    var intitule: String {
        switch etat {
        case .modifiee:  return "Garder la nouvelle valeur"
        case .ajoutee:   return "Garder cette ligne ajoutée"
        case .supprimee: return "Garder la suppression"
        case .presente:  return "Garder cette ligne"
        }
    }
}

struct ResultatComparaison {
    let lignes: [LigneComparaison]
    let inchangees: Int
    let erreur: String?
}

/// Un JSON ne correspond plus au sceau produit par l'application : l'utilisateur
/// tranche lui-même entre accepter le contenu et le refuser.
struct AlerteIntegrite: Identifiable {
    let id = UUID()
    let fichier: String
    let url: URL
    /// Vrai quand c'est le sceau qui manque, faux quand le contenu diffère.
    let sceauAbsent: Bool
}

// MARK: - VIEW MODEL

final class Ligue1ViewModel: ObservableObject {
    @Published var ligue = Ligue()
    @Published var reglages = Reglages()
    @Published var mouvements: [Mouvement] = []
    @Published var parisManuels: [PariManuel] = []
    @Published var parisExclus: [PariExclu] = []
    @Published var historique = Historique() {
        didSet { historiquePrepare = MatchHistoriquePrepare.preparer(historique) }
    }
    /// Historique trié, cotes déjà converties en buts attendus.
    private(set) var historiquePrepare: [MatchHistoriquePrepare] = []

    /// Logos déposés dans `logos/`, par équipe ; à défaut, blason généré.
    @Published private(set) var logos: [String: NSImage] = [:]

    /// Modèle de forces ajusté sur tout ce qui est connu ; refait à chaque changement majeur.
    @Published private(set) var modele: ModeleForces?
    /// Incrémenté à chaque rechargement : les cartes de match reprennent alors leurs champs.
    @Published private(set) var versionDonnees = 0

    // Monte Carlo (en arrière-plan)
    @Published private(set) var simulation: ResultatSimulation?
    @Published private(set) var simulationEnCours = false
    @Published private(set) var erreurSimulation: String?
    private var simulationARelancer = false

    // Backtest (en arrière-plan, à la demande)
    @Published private(set) var backtest: ResultatBacktest?
    @Published private(set) var backtestEnCours = false
    /// Vrai après un premier calcul, même sans match évaluable (`backtest` nil).
    @Published private(set) var backtestCalcule = false

    // Calibration sur l'historique (en arrière-plan, à la demande)
    @Published private(set) var calibration: ResultatCalibration?
    @Published private(set) var calibrationEnCours = false
    @Published private(set) var calibrationCalculee = false
    @Published private(set) var progressionCalibration = 0.0
    /// Import de CSV en cours (calibration et probabilités figées comprises).
    @Published private(set) var importEnCours = false
    /// Téléchargement de la mise à jour en ligne en cours.
    @Published private(set) var telechargementEnCours = false
    /// Téléchargement des cotes Winamax, Unibet et Betclic (The Odds API).
    @Published private(set) var cotesEnCours = false
    /// L'écran d'accueil lance la mise à jour en ligne une fois par session.
    var miseAJourAutomatiqueFaite = false

    // Précision des conseils (walk-forward sur l'historique)
    @Published private(set) var precision: ResultatPrecision?
    @Published private(set) var precisionEnCours = false
    private var previsionsEnCache: (parametres: ParametresModele, matchs: Int, debut: Int,
                                    previsions: Calibration.Previsions)?

    @Published var debugLogs: [DebugLog] = []

    /// Dernière erreur à montrer à l'utilisateur : sans cela, un échec de
    /// sauvegarde passerait inaperçu.
    @Published var derniereErreur: String?

    private let maxLogs = 50

    /// Sous-dossier créé dans ~/Documents.
    private let sousDossier = "Ligue1"
    private let dossierLogos = "logos"

    // MARK: - Garde-fous de stockage
    /// Fichiers chargés avec succès (ou absents) depuis le dossier configuré.
    /// Tant qu'un fichier n'y figure pas, il n'est jamais réécrit.
    private var fichiersCharges = Set<FichierDonnees>()

    /// Dernière sauvegarde réussie, conservée entre deux lancements.
    @Published private(set) var derniereSauvegardeLocale: Sauvegarde?

    /// Résultat de la dernière écriture.
    @Published private(set) var dernierResultatLocal: Bool?

    private let cleDerniereLocale = "derniereSauvegardeLocale"

    private let tailleMaxFichier = 50 * 1024 * 1024 // 50 Mo
    private let tailleMaxLogo = 5 * 1024 * 1024     // 5 Mo

    /// Non nil quand une fenêtre doit demander à l'utilisateur quoi faire.
    @Published var alerteIntegrite: AlerteIntegrite?

    /// Reste posé tant que le fichier n'est pas réglé, même après « Refuser ».
    @Published private(set) var blocageIntegrite: AlerteIntegrite?

    /// Un observateur par fichier surveillé (voir `surveillerFichiers`).
    private var surveillants: [DispatchSourceFileSystemObject] = []

    /// Enregistrements différés (frappe dans un champ de cote, jauges).
    private var sauvegardesDifferees: [FichierDonnees: DispatchWorkItem] = [:]
    private var abonnements = Set<AnyCancellable>()

    private enum ErreurStockage: LocalizedError {
        case fichierTropVolumineux, dossierLocalIntrouvable
        case integriteInvalide(String), sceauManquant(String)
        var errorDescription: String? {
            switch self {
            case .fichierTropVolumineux: return "Fichier anormalement volumineux"
            case .dossierLocalIntrouvable: return "Dossier Documents introuvable"
            case .integriteInvalide(let f):
                return "\(f) a été modifié en dehors de l'application : chargement refusé"
            case .sceauManquant(let f):
                return "Sceau d'intégrité absent pour \(f) : chargement refusé"
            }
        }
    }

    init() {
        derniereSauvegardeLocale = Sauvegarde.lire(cleDerniereLocale)
        // Ne jamais perdre la dernière frappe dans un champ de cote.
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.enregistrerDifferees() }
            .store(in: &abonnements)
    }

    func log(_ message: String, level: DebugLog.LogLevel = .info) {
        DispatchQueue.main.async {
            self.debugLogs.append(DebugLog(message: message, level: level))
            if self.debugLogs.count > self.maxLogs {
                self.debugLogs.removeFirst()
            }
            if level == .error { self.derniereErreur = message }
            #if DEBUG
            print("[\(level.rawValue)] \(message)")
            #endif
        }
    }

    private func noterSauvegarde(_ dossier: URL) {
        let s = Sauvegarde(date: Date(), chemin: dossier.path)
        derniereSauvegardeLocale = s
        s.ecrire(cleDerniereLocale)
    }

    /// Repose la question fermée par « Refuser ».
    func revoirIntegrite() {
        alerteIntegrite = blocageIntegrite
    }

    /// L'alerte naît pendant `chargerDonnees()` : assignée telle quelle, SwiftUI
    /// la perdrait, la modification tombant dans le cycle de mise à jour de la
    /// vue. D'où le report d'un tour de boucle, comme pour `log`.
    private func signaler(_ alerte: AlerteIntegrite) {
        DispatchQueue.main.async {
            self.blocageIntegrite = alerte
            guard self.alerteIntegrite == nil else { return }   // une question à la fois
            self.alerteIntegrite = alerte
        }
    }

    // MARK: - JSON

    private var encodeur: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private var decodeur: JSONDecoder { JSONDecoder() }

    // MARK: - Stockage

    /// Dossier des données sur le disque local.
    var dossierLocal: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sousDossier, isDirectory: true)
    }

    // MARK: - Lecture / écriture

    /// Retourne nil si le fichier n'existe pas encore (situation normale).
    private func lireFichier<T: Decodable>(_ type: T.Type, url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let attributs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let taille = attributs[.size] as? NSNumber, taille.intValue > tailleMaxFichier {
            throw ErreurStockage.fichierTropVolumineux
        }

        let brut = try Data(contentsOf: url)
        try verifierIntegrite(brut, url: url)
        return try decodeur.decode(T.self, from: brut)
    }

    /// Le sceau `<fichier>.hmac` n'est produit que par l'application : toute
    /// retouche du JSON le rend invalide. Un fichier sans sceau est scellé au
    /// premier chargement ; ensuite, un sceau absent est traité comme une altération.
    private func verifierIntegrite(_ brut: Data, url: URL) throws {
        let nom = url.lastPathComponent
        let urlSceau = url.appendingPathExtension("hmac")

        guard let sceau = try? Data(contentsOf: urlSceau) else {
            if IntegriteStockage.estActive(nom) {
                signaler(AlerteIntegrite(fichier: nom, url: url, sceauAbsent: true))
                throw ErreurStockage.sceauManquant(nom)
            }
            try? IntegriteStockage.sceau(brut, nom: nom).write(to: urlSceau, options: .atomic)
            log("Sceau d'intégrité créé pour \(nom)", level: .info)
            return
        }

        guard IntegriteStockage.verifier(brut, nom: nom, sceau: sceau) else {
            signaler(AlerteIntegrite(fichier: nom, url: url, sceauAbsent: false))
            throw ErreurStockage.integriteInvalide(nom)
        }
    }

    private func lire<T: Decodable>(_ type: T.Type, fichier: String) throws -> T? {
        guard let dossier = dossierLocal else { throw ErreurStockage.dossierLocalIntrouvable }
        return try lireFichier(type, url: dossier.appendingPathComponent(fichier))
    }

    private func ecrire(_ clair: Data, fichier: String, dossier: URL, permissionsRestreintes: Bool = false) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appendingPathComponent(fichier)
        try clair.write(to: url, options: .atomic)
        let urlSceau = url.appendingPathExtension("hmac")
        try IntegriteStockage.sceau(clair, nom: fichier).write(to: urlSceau, options: .atomic)
        if permissionsRestreintes {
            // Disque local : lecture/écriture réservées à l'utilisateur
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dossier.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: urlSceau.path)
        }
    }

    @discardableResult
    private func enregistrerLocalement(_ clair: Data, fichier: String) -> Bool {
        var resultatLocal = false
        if let dossier = dossierLocal {
            do {
                try ecrire(clair, fichier: fichier, dossier: dossier, permissionsRestreintes: true)
                noterSauvegarde(dossier)
                resultatLocal = true
            } catch {
                log("Échec de la sauvegarde locale : \(error.localizedDescription)", level: .error)
            }
        } else {
            log("Dossier Documents introuvable", level: .error)
        }

        dernierResultatLocal = resultatLocal
        return resultatLocal
    }

    // MARK: - Sauvegarde / chargement

    func chargerDonnees() {
        enregistrerDifferees()
        blocageIntegrite = nil

        charger(Ligue.self)
        charger(Reglages.self)
        charger([Mouvement].self)
        charger([PariManuel].self)
        charger([PariExclu].self)
        charger(Historique.self)
        chargerLogos()
        surveillerFichiers()

        versionDonnees += 1
        reajusterModele()
    }

    /// Un fichier absent laisse les données en mémoire intactes : elles seront
    /// écrites dans le nouveau dossier à la prochaine sauvegarde.
    private func charger<T: DocumentScelle>(_ type: T.Type) {
        let f = T.fichier
        do {
            if let valeur = try lire(T.self, fichier: f.nom) {
                if let erreur = valeur.valider() {
                    fichiersCharges.remove(f)
                    log("\(f.nom) incohérent (sauvegarde bloquée) : \(erreur)", level: .error)
                    return
                }
                self[keyPath: T.chemin] = valeur
                log("\(f.titre) chargé (\(valeur.lignes.count) ligne\(valeur.lignes.count > 1 ? "s" : ""))", level: .success)
            } else {
                log("\(f.titre) : aucun fichier existant", level: .info)
            }
            fichiersCharges.insert(f)
        } catch {
            fichiersCharges.remove(f)
            log("Erreur chargement \(f.nom) (sauvegarde bloquée) : \(error.localizedDescription)", level: .error)
        }
    }

    @discardableResult
    private func sauvegarder<T: DocumentScelle>(_ type: T.Type) -> Bool {
        let f = T.fichier
        sauvegardesDifferees.removeValue(forKey: f)?.cancel()
        guard fichiersCharges.contains(f) else {
            log("Sauvegarde de \(f.nom) annulée : données existantes non chargées (protection contre l’écrasement)", level: .error)
            return false
        }
        do {
            let donnees = try encodeur.encode(self[keyPath: T.chemin])
            guard enregistrerLocalement(donnees, fichier: f.nom) else {
                log("\(f.titre) non sauvegardé", level: .error)
                return false
            }
            log("\(f.titre) : sauvegardé", level: .success)
            return true
        } catch {
            log("Erreur sauvegarde \(f.nom) : \(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// Enregistre après 0,4 s sans nouvelle modification (frappe dans un champ, jauge).
    private func sauvegarderPlusTard<T: DocumentScelle>(_ type: T.Type) {
        let f = T.fichier
        sauvegardesDifferees[f]?.cancel()
        let tache = DispatchWorkItem { [weak self] in
            self?.sauvegardesDifferees.removeValue(forKey: f)
            self?.sauvegarder(T.self)
        }
        sauvegardesDifferees[f] = tache
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: tache)
    }

    /// Exécute tout de suite les enregistrements encore en attente.
    func enregistrerDifferees() {
        for (f, tache) in sauvegardesDifferees {
            tache.cancel()
            sauvegardesDifferees.removeValue(forKey: f)
            sauvegarder(f)
        }
    }

    @discardableResult
    private func sauvegarder(_ f: FichierDonnees) -> Bool {
        switch f {
        case .ligue:            return sauvegarder(Ligue.self)
        case .reglages:         return sauvegarder(Reglages.self)
        case .mouvements:       return sauvegarder([Mouvement].self)
        case .parisManuels:     return sauvegarder([PariManuel].self)
        case .parisExclus:      return sauvegarder([PariExclu].self)
        case .historique:       return sauvegarder(Historique.self)
        }
    }

    @discardableResult
    func sauvegarderTout() -> Bool {
        !FichierDonnees.allCases.map { sauvegarder($0) }.contains(false)
    }

    /// Réécrit et rescelle tous les fichiers dans ~/Documents/Ligue1.
    @discardableResult
    func sauvegarderLocalement() -> Bool {
        // Ne jamais remplacer une bonne sauvegarde locale par des données vides non chargées
        guard fichiersCharges.count == FichierDonnees.allCases.count else {
            log("Sauvegarde locale annulée : données non chargées", level: .error)
            return false
        }
        guard let dossier = dossierLocal else {
            log("Dossier Documents introuvable", level: .error)
            return false
        }
        do {
            try ecrire(try encodeur.encode(ligue), fichier: Ligue.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            try ecrire(try encodeur.encode(reglages), fichier: Reglages.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            try ecrire(try encodeur.encode(mouvements), fichier: Mouvement.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            try ecrire(try encodeur.encode(parisManuels), fichier: PariManuel.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            try ecrire(try encodeur.encode(parisExclus), fichier: PariExclu.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            try ecrire(try encodeur.encode(historique), fichier: Historique.fichier.nom, dossier: dossier, permissionsRestreintes: true)
            noterSauvegarde(dossier)
            log("Sauvegarde locale effectuée", level: .success)
            return true
        } catch {
            log("Erreur sauvegarde locale: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// Modifie un fichier puis l'enregistre ; en cas d'échec, la modification est
    /// annulée. Retourne un message d'erreur, ou nil.
    @discardableResult
    private func modifier<T: DocumentScelle>(_ type: T.Type, differe: Bool = false,
                                             _ changement: (inout T) -> Void) -> String? {
        guard fichiersCharges.contains(T.fichier) else {
            return "\(T.fichier.titre) : les données n’ont pas pu être chargées, enregistrement bloqué pour ne pas les écraser."
        }
        let avant = self[keyPath: T.chemin]
        var apres = avant
        changement(&apres)
        if let erreur = apres.valider() { return erreur }
        self[keyPath: T.chemin] = apres
        if differe {
            sauvegarderPlusTard(T.self)
            return nil
        }
        guard sauvegarder(T.self) else {
            self[keyPath: T.chemin] = avant
            return "Échec de la sauvegarde : modification annulée."
        }
        return nil
    }

    func peutModifier(_ f: FichierDonnees) -> Bool { fichiersCharges.contains(f) }

    // MARK: - Matchs

    func match(_ id: Match.ID) -> Match? {
        ligue.matches.first { $0.id == id }
    }

    /// Score validé. La toute première fois, la probabilité pré-match du modèle
    /// est figée et ne sera plus jamais recalculée (même si le score est corrigé).
    @discardableResult
    func validerScore(_ id: Match.ID, domicile h: Int, exterieur a: Int) -> String? {
        guard (0...Limites.buts).contains(h), (0...Limites.buts).contains(a) else { return "Score invalide" }
        guard let m = match(id) else { return "Match introuvable" }
        let probas = m.joue ? nil : modele?.probas(m.domicile, m.exterieur)
        let erreur = modifier(Ligue.self) { l in
            guard let i = l.indexMatch(id) else { return }
            let premiereFois = !l.matches[i].joue
            l.matches[i].butsDomicile = h
            l.matches[i].butsExterieur = a
            if premiereFois, !l.matches[i].fige, let p = probas {
                l.matches[i].figeP1 = p.p1
                l.matches[i].figePN = p.pN
                l.matches[i].figeP2 = p.p2
                l.matches[i].figeLambdaDomicile = p.lambdaDomicile
                l.matches[i].figeLambdaExterieur = p.lambdaExterieur
            }
        }
        if erreur == nil { changementMajeur() }
        return erreur
    }

    /// Le match redevient à simuler : sa probabilité figée est effacée (recapturée au
    /// prochain score) et ses paris disparaissent de l'historique.
    @discardableResult
    func effacerScore(_ id: Match.ID) -> String? {
        let erreur = modifier(Ligue.self) { l in
            guard let i = l.indexMatch(id) else { return }
            l.matches[i].butsDomicile = nil
            l.matches[i].butsExterieur = nil
            l.matches[i].figeP1 = nil
            l.matches[i].figePN = nil
            l.matches[i].figeP2 = nil
            l.matches[i].figeLambdaDomicile = nil
            l.matches[i].figeLambdaExterieur = nil
        }
        if erreur == nil { changementMajeur() }
        return erreur
    }

    /// Le classement ne change pas, mais le modèle doit être réajusté sans ce match.
    @discardableResult
    func definirForfait(_ id: Match.ID, _ forfait: Bool) -> String? {
        let erreur = modifier(Ligue.self) { l in
            guard let i = l.indexMatch(id) else { return }
            l.matches[i].forfait = forfait
        }
        if erreur == nil { changementMajeur() }
        return erreur
    }

    @discardableResult
    func definirXg(_ id: Match.ID, _ xg: (Double, Double)?) -> String? {
        if let xg {
            guard xg.0.isFinite, xg.1.isFinite, (0...Limites.xg).contains(xg.0), (0...Limites.xg).contains(xg.1) else {
                return "xG invalides"
            }
        }
        // Le xG nourrit aussi le modèle (mélange buts/xG) : réajusté pour un match joué.
        let joue = match(id)?.joue ?? false
        let erreur = modifier(Ligue.self, differe: true) { l in
            guard let i = l.indexMatch(id) else { return }
            l.matches[i].xgDomicile = xg?.0
            l.matches[i].xgExterieur = xg?.1
        }
        if erreur == nil, joue { reajusterModele() }
        return erreur
    }

    @discardableResult
    func definirMinutes(_ id: Match.ID, domicile: [String]?, exterieur: [String]?) -> String? {
        modifier(Ligue.self, differe: true) { l in
            guard let i = l.indexMatch(id) else { return }
            l.matches[i].minutesDomicile = (domicile?.isEmpty ?? true) ? nil : domicile
            l.matches[i].minutesExterieur = (exterieur?.isEmpty ?? true) ? nil : exterieur
        }
    }

    /// Cotes d'un bookmaker (nil efface). Enregistrées après 0,4 s sans frappe.
    @discardableResult
    func definirCotes(_ id: Match.ID, _ livre: Bookmaker, _ cotes: [Double]?) -> String? {
        if let cotes {
            guard cotes.count == 3, cotes.allSatisfy({ $0.isFinite && $0 > 1 && $0 < Limites.cote }) else {
                return "Cotes invalides"
            }
        }
        guard match(id)?.cotes[livre] != cotes else { return nil }
        let joue = match(id)?.joue ?? false
        let erreur = modifier(Ligue.self, differe: true) { l in
            guard let i = l.indexMatch(id) else { return }
            l.matches[i].cotes[livre] = cotes
        }
        // Les cotes d'un match joué nourrissent le modèle (MARKET_ALPHA).
        if erreur == nil, joue { reajusterModele() }
        return erreur
    }

    // MARK: - Réglages, mouvements, paris manuels et exclus

    /// Jauges : un déplacement rejoue tout l'historique ; enregistré après 0,4 s.
    func modifierReglages(_ changement: (inout Reglages) -> Void) {
        if let erreur = modifier(Reglages.self, differe: true, changement) {
            log(erreur, level: .error)
        }
    }

    @discardableResult
    func ajouterMouvement(_ m: Mouvement) -> String? {
        guard m.amount.isFinite, m.amount != 0, abs(m.amount) < Limites.montant else { return "Montant invalide" }
        guard m.journee >= 1, m.journee <= max(ligue.nJournees, 1) else { return "Journée invalide" }
        guard Limites.texteValide(m.note, obligatoire: false) else { return "Note trop longue." }
        return modifier([Mouvement].self) { $0.append(m) }
    }

    @discardableResult
    func supprimerMouvement(at index: Int) -> String? {
        modifier([Mouvement].self) { l in
            if l.indices.contains(index) { l.remove(at: index) }
        }
    }

    @discardableResult
    func ajouterPariManuel(_ p: PariManuel) -> String? {
        guard !parisManuels.contains(p) else { return "Ce pari est déjà forcé." }
        return modifier([PariManuel].self) { $0.append(p) }
    }

    @discardableResult
    func supprimerPariManuel(_ p: PariManuel) -> String? {
        modifier([PariManuel].self) { l in
            if let i = l.firstIndex(of: p) { l.remove(at: i) }
        }
    }

    @discardableResult
    func exclure(_ p: PariExclu) -> String? {
        guard !parisExclus.contains(p) else { return "Ce pari est déjà exclu." }
        return modifier([PariExclu].self) { $0.append(p) }
    }

    @discardableResult
    func supprimerExclusion(_ p: PariExclu) -> String? {
        modifier([PariExclu].self) { l in
            if let i = l.firstIndex(of: p) { l.remove(at: i) }
        }
    }

    /// Historique complet des paris avec les réglages actuels (≈ 1 ms).
    var resultatParis: ResultatParis {
        Paris.historique(ligue: ligue, reglages: reglages, mouvements: mouvements,
                         manuels: parisManuels, exclus: parisExclus, modele: modele)
    }

    // MARK: - Modèle et Monte Carlo

    /// Saison venue des CSV : une saison sans origine (ancien format) n'est ni
    /// affichée ni utilisée.
    var saisonDisponible: Bool { ligue.season != nil && !ligue.teams.isEmpty }

    /// Score, forfait ou début de saison modifié : modèle, classement, saison simulée.
    private func changementMajeur() {
        reajusterModele()
    }

    private func reajusterModele() {
        guard saisonDisponible else {
            modele = nil
            simulation = nil
            return
        }
        modele = Modele.construire(ligue: ligue, historique: historiquePrepare,
                                   debutSaison: reglages.jourDebutSaison, parametres: reglages.parametresEnService)
        lancerSimulation()
    }

    /// Monte Carlo en arrière-plan ; une demande pendant un calcul le relance à la fin.
    func lancerSimulation() {
        guard let modele, !ligue.teams.isEmpty else { return }
        if simulationEnCours {
            simulationARelancer = true
            return
        }
        simulationEnCours = true
        erreurSimulation = nil
        let ligue = self.ligue
        let n = reglages.simulations
        DispatchQueue.global(qos: .userInitiated).async {
            let resultat = MonteCarlo.simuler(ligue: ligue, modele: modele, simulations: n)
            DispatchQueue.main.async {
                self.simulationEnCours = false
                if let resultat {
                    self.simulation = resultat
                } else {
                    self.erreurSimulation = "Simulation interrompue"
                }
                if self.simulationARelancer {
                    self.simulationARelancer = false
                    self.lancerSimulation()
                }
            }
        }
    }

    /// Backtest walk-forward sur une copie : un score peut changer pendant le calcul.
    func lancerBacktest() {
        guard !backtestEnCours, saisonDisponible else { return }
        backtestEnCours = true
        let ligue = self.ligue
        let historique = historiquePrepare
        let debut = reglages.jourDebutSaison
        let parametres = reglages.parametresEnService
        DispatchQueue.global(qos: .userInitiated).async {
            let resultat = Backtest.walkForward(ligue: ligue, historique: historique,
                                                debutSaison: debut, parametres: parametres)
            DispatchQueue.main.async {
                self.backtest = resultat
                self.backtestCalcule = true
                self.backtestEnCours = false
            }
        }
    }

    // MARK: - Historique et calibration

    /// Saisons passées utilisables : strictement avant la saison en cours.
    var historiqueAnterieur: [MatchHistoriquePrepare] {
        historiquePrepare.filter { $0.jour < reglages.jourDebutSaison }
    }

    /// Recherche des hyperparamètres sur l'historique (≈ 20 passes walk-forward),
    /// mis en service dès qu'elle aboutit.
    func lancerCalibration() {
        guard !calibrationEnCours, !importEnCours else { return }
        calibrationEnCours = true
        progressionCalibration = 0
        let historique = historiqueAnterieur
        DispatchQueue.global(qos: .userInitiated).async {
            let resultat = Calibration.calibrer(historique, progression: { v in
                DispatchQueue.main.async { self.progressionCalibration = v }
            })
            DispatchQueue.main.async {
                self.calibration = resultat
                self.calibrationCalculee = true
                self.calibrationEnCours = false
                if let p = resultat?.parametres, p != self.reglages.parametresModele {
                    self.appliquerParametresModele(p)
                }
            }
        }
    }

    @discardableResult
    private func appliquerParametresModele(_ p: ParametresModele?) -> String? {
        let erreur = modifier(Reglages.self) { $0.parametresModele = p }
        if erreur == nil {
            backtest = nil
            backtestCalcule = false
            reajusterModele()
        } else if let erreur {
            log(erreur, level: .error)
        }
        return erreur
    }

    /// L'historique effacé, les paramètres qui en venaient le sont aussi.
    @discardableResult
    func effacerHistorique() -> String? {
        let erreur = modifier(Historique.self) { $0 = Historique() }
        if erreur == nil {
            historiqueModifie()
            appliquerParametresModele(nil)
        }
        return erreur
    }

    /// Historique ou saison changés : modèle, backtest et calibration à refaire.
    private func historiqueModifie() {
        calibration = nil
        calibrationCalculee = false
        precision = nil
        backtest = nil
        backtestCalcule = false
        reajusterModele()
    }

    /// Fiabilité des probabilités et résultat historique de la règle de paris
    /// actuelle. Les prévisions walk-forward (≈ 0,3 s) sont gardées tant que
    /// l'historique et les paramètres ne changent pas : un réglage de jauge ne
    /// refait que le décompte des paris.
    func lancerPrecision() {
        let parametres = reglages.parametresEnService
        let historique = historiqueAnterieur
        let debut = reglages.jourDebutSaison
        if let c = previsionsEnCache, c.parametres == parametres, c.matchs == historique.count, c.debut == debut {
            precision = Precision.analyser(c.previsions, reglages: reglages)
            return
        }
        guard !precisionEnCours, Set(historique.map(\.saison)).count >= 2 else { return }
        precisionEnCours = true
        DispatchQueue.global(qos: .userInitiated).async {
            let previsions = Calibration.previsions(historique, parametres: parametres)
            DispatchQueue.main.async {
                self.precisionEnCours = false
                guard let previsions else {
                    self.precision = nil
                    return
                }
                self.previsionsEnCache = (parametres, historique.count, debut, previsions)
                self.lancerPrecision()
            }
        }
    }

    // MARK: - Import des CSV football-data.co.uk

    /// CSV lus et répartis, en attente de confirmation.
    struct ImportCSV {
        let fichiers: [FootballData.Fichier]
        let erreurs: [String]
        /// Saison la plus récente des fichiers, si elle devient (ou reste) la saison
        /// en cours ; les autres fichiers vont à l'historique.
        let saisonCourante: String?
        /// La saison en cours actuelle est remplacée : sa saisie est perdue.
        let remplaceSaison: Bool

        var resume: String {
            (fichiers.sorted { ($0.saison, $0.nom) < ($1.saison, $1.nom) }.map(\.resume) + erreurs).joined(separator: "\n")
        }
    }

    /// Fichiers choisis par l'utilisateur : F1.csv (saison en cours et passées)
    /// et fixtures.csv, plusieurs à la fois ; la saison est déduite des dates.
    func lireCSV() -> ImportCSV? {
        let panel = NSOpenPanel()
        panel.title = "Importer des CSV football-data.co.uk"
        panel.prompt = "Importer"
        panel.message = "Sélectionnez les F1.csv téléchargés (saison en cours et saisons passées) et, si vous l'avez, fixtures.csv."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return nil }
        return analyserCSV(panel.urls)
    }

    /// Lit les fichiers et décide de leur rôle : la saison la plus récente devient
    /// la saison en cours si elle n'est pas antérieure à l'actuelle.
    func analyserCSV(_ urls: [URL]) -> ImportCSV {
        var lus: [(nom: String, donnees: Data)] = []
        var erreurs: [String] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let nom = url.lastPathComponent
            do {
                if let taille = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, taille > tailleMaxFichier {
                    throw ErreurStockage.fichierTropVolumineux
                }
                lus.append((nom, try Data(contentsOf: url)))
            } catch {
                erreurs.append("\(nom) : \(error.localizedDescription)")
            }
        }
        return analyserCSV(lus, erreurs: erreurs)
    }

    private func analyserCSV(_ lus: [(nom: String, donnees: Data)], erreurs dejaVues: [String]) -> ImportCSV {
        let connus = saisonDisponible ? ligue.equipes : []
        var fichiers: [FootballData.Fichier] = []
        var erreurs = dejaVues
        for f in lus {
            do {
                fichiers.append(try FootballData.lire(f.donnees, nom: f.nom, equipesConnues: connus))
            } catch let e as FootballData.Erreur {
                erreurs.append(e.message)
            } catch {
                erreurs.append("\(f.nom) : \(error.localizedDescription)")
            }
        }
        let actuelle = saisonDisponible ? ligue.season : nil
        let courante = fichiers.map(\.saison).max().flatMap { s in (actuelle.map { s >= $0 } ?? true) ? s : nil }
        return ImportCSV(fichiers: fichiers, erreurs: erreurs, saisonCourante: courante,
                         remplaceSaison: courante != nil && courante != actuelle && !ligue.teams.isEmpty)
    }

    // MARK: Mise à jour en ligne

    /// Saisons dont le F1.csv est téléchargé : celle de l'application et celle
    /// du calendrier (différente quand une nouvelle saison a commencé).
    private var saisonsAMettreAJour: [String] {
        let annee = Int(Reglages.debutProbable.prefix(4)) ?? 2025
        let duJour = String(format: "%d-%02d", annee, (annee + 1) % 100)
        return Array(Set([saisonDisponible ? ligue.season : nil, duJour].compactMap { $0 })).sorted()
    }

    /// Nombre de saisons d'historique chargées par défaut.
    static let saisonsHistorique = 10

    /// Saisons passées à télécharger : les 11 qui précèdent la saison du
    /// calendrier (10 restent si celle-ci n'est pas encore publiée), sauf celles
    /// déjà dans l'historique avec leurs cotes moyennes et d'ouverture.
    private var saisonsPasseesManquantes: [String] {
        let annee = Int(Reglages.debutProbable.prefix(4)) ?? 2025
        let completes = Set(historique.matches.filter { $0.oddsAvg != nil && $0.oddsOpen != nil }.map(\.season))
        return (1...(Self.saisonsHistorique + 1)).map { k in String(format: "%d-%02d", annee - k, (annee - k + 1) % 100) }
            .filter { !completes.contains($0) && !saisonsAMettreAJour.contains($0) }
    }

    /// Seul accès réseau de l'application, à la demande : fixtures.csv, le
    /// F1.csv de la saison en cours et ceux des saisons passées manquantes,
    /// téléchargés sur football-data.co.uk (GET sans cookie ni cache, rien n'est
    /// envoyé), puis lus comme des fichiers importés. `termine` reçoit le
    /// résultat sur le fil principal.
    func telechargerMiseAJour(termine: @escaping (ImportCSV) -> Void) {
        guard !telechargementEnCours else { return }
        telechargementEnCours = true
        var cibles = [(nom: "fixtures.csv (en ligne)", url: FootballData.fixtures, obligatoire: false)]
        for s in saisonsAMettreAJour {
            guard let url = FootballData.urlSaison(s) else { continue }
            cibles.append(("F1.csv \(s) (en ligne)", url, s == ligue.season))
        }
        for s in saisonsPasseesManquantes {
            guard let url = FootballData.urlSaison(s) else { continue }
            cibles.append(("F1.csv \(s) (en ligne)", url, true))
        }

        let session = URLSession(configuration: .ephemeral)
        let groupe = DispatchGroup()
        let verrou = NSLock()
        var lus: [(nom: String, donnees: Data)] = []
        var erreurs: [String] = []
        let maximum = tailleMaxFichier
        for c in cibles {
            var requete = URLRequest(url: c.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            requete.httpShouldHandleCookies = false
            groupe.enter()
            session.dataTask(with: requete) { donnees, reponse, erreur in
                defer { groupe.leave() }
                let statut = (reponse as? HTTPURLResponse)?.statusCode ?? 0
                verrou.lock()
                defer { verrou.unlock() }
                if let erreur {
                    erreurs.append("\(c.nom) : \(erreur.localizedDescription)")
                } else if statut == 404, !c.obligatoire {
                    erreurs.append("\(c.nom) : pas encore publié.")
                } else if statut != 200 {
                    erreurs.append("\(c.nom) : réponse HTTP \(statut).")
                } else if let donnees, donnees.count <= maximum {
                    lus.append((c.nom, donnees))
                } else {
                    erreurs.append("\(c.nom) : fichier vide ou anormalement volumineux.")
                }
            }.resume()
        }
        groupe.notify(queue: .main) {
            session.finishTasksAndInvalidate()
            self.telechargementEnCours = false
            self.log("Mise à jour en ligne : \(lus.count) fichier(s) téléchargé(s)", level: lus.isEmpty ? .error : .info)
            termine(self.analyserCSV(lus.sorted { $0.nom < $1.nom }, erreurs: erreurs))
        }
    }

    // MARK: - Cotes en ligne (The Odds API)

    private let serviceCleCotes = "com.ligue1.app.oddsapi"

    /// Clé The Odds API, gardée avec la clé des sceaux (Application
    /// Support › Ligue1, lisible par l'utilisateur seul).
    var cleCotesEnLigne: String {
        StockageAuth.read(service: serviceCleCotes, account: nil).data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    var cotesEnLigneConfigurees: Bool { !cleCotesEnLigne.isEmpty }

    /// Enregistre la clé (vide l'efface). Retourne un message d'erreur, ou nil.
    func definirCleCotes(_ cle: String) -> String? {
        let t = cle.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            StockageAuth.delete(service: serviceCleCotes, account: nil)
        } else {
            guard CotesEnLigne.cleValide(t) else { return "Clé invalide : lettres et chiffres seulement." }
            StockageAuth.write(Data(t.utf8), service: serviceCleCotes, account: nil)
        }
        objectWillChange.send()
        return nil
    }

    /// Cotes Winamax, Unibet et Betclic des matchs à venir : la cote téléchargée
    /// remplace celle du bookmaker tant que le match n'est pas joué ; un match
    /// joué garde les siennes. `termine` reçoit le compte rendu sur le fil principal.
    func telechargerCotes(termine: @escaping (_ texte: String, _ ok: Bool) -> Void) {
        guard !cotesEnCours else { return }
        guard let url = CotesEnLigne.url(cle: cleCotesEnLigne) else {
            termine("Cotes en ligne : aucune clé The Odds API (Paramètres › Saison).", false)
            return
        }
        if let b = blocageIntegrite {
            termine("\(b.fichier) a été modifié en dehors de l'application : réglez d'abord la revue d'intégrité.", false)
            return
        }
        guard saisonDisponible else {
            termine("Cotes en ligne : aucune saison en cours.", false)
            return
        }
        cotesEnCours = true
        var requete = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        requete.httpShouldHandleCookies = false
        let session = URLSession(configuration: .ephemeral)
        let maximum = tailleMaxFichier
        session.dataTask(with: requete) { donnees, reponse, erreur in
            let http = reponse as? HTTPURLResponse
            let statut = http?.statusCode ?? 0
            let restants = http?.value(forHTTPHeaderField: "x-requests-remaining")
            DispatchQueue.main.async {
                session.finishTasksAndInvalidate()
                self.cotesEnCours = false
                let r = self.appliquerCotes(donnees.flatMap { $0.count <= maximum ? $0 : nil },
                                            statut: statut, erreur: erreur, restants: restants)
                self.log(r.texte, level: r.ok ? .info : .error)
                termine(r.texte, r.ok)
            }
        }.resume()
    }

    private func appliquerCotes(_ donnees: Data?, statut: Int, erreur: Error?,
                                restants: String?) -> (texte: String, ok: Bool) {
        if let erreur { return ("Cotes en ligne : \(erreur.localizedDescription)", false) }
        switch statut {
        case 200: break
        case 401: return ("Cotes en ligne : clé The Odds API refusée.", false)
        case 429: return ("Cotes en ligne : quota The Odds API épuisé ou trop de requêtes.", false)
        default:  return ("Cotes en ligne : réponse HTTP \(statut).", false)
        }
        guard let donnees, let lu = try? CotesEnLigne.lire(donnees, equipes: ligue.equipes) else {
            return ("Cotes en ligne : réponse vide, illisible ou anormalement volumineuse.", false)
        }
        var misAJour = 0
        if !lu.rencontres.isEmpty, let e = modifier(Ligue.self, { l in
            for r in lu.rencontres {
                guard let i = l.matches.firstIndex(where: {
                    $0.domicile == r.domicile && $0.exterieur == r.exterieur && !$0.joue
                }) else { continue }
                for (b, c) in r.cotes { l.matches[i].cotes[b] = c }
                misAJour += 1
            }
        }) {
            return ("Cotes en ligne : \(e)", false)
        }
        var texte = misAJour == 0 ? "Cotes en ligne : aucune cote Winamax, Unibet ou Betclic publiée pour les matchs à venir."
            : "Cotes en ligne : \(misAJour) match\(misAJour > 1 ? "s" : "") à venir mis à jour (Winamax, Unibet, Betclic)."
        if !lu.inconnus.isEmpty { texte += " Club(s) non reconnu(s) : \(lu.inconnus.joined(separator: ", "))." }
        if let restants { texte += " Crédits restants : \(restants)." }
        return (texte, lu.inconnus.isEmpty)
    }

    /// Historique complété, saison en cours créée ou mise à jour, paramètres
    /// recalibrés si l'historique a changé, probabilités pré-match figées pour les
    /// matchs devenus joués (modèle ajusté sur les journées précédentes) ; tout
    /// cela en arrière-plan, puis enregistré. `termine` reçoit l'erreur, ou nil.
    func importerCSV(_ i: ImportCSV, termine: @escaping (String?) -> Void) {
        if let b = blocageIntegrite {
            termine("\(b.fichier) a été modifié en dehors de l'application : réglez d'abord la revue d'intégrité.")
            return
        }
        guard fichiersCharges.count == FichierDonnees.allCases.count else {
            termine("Des données n'ont pas pu être chargées : import bloqué pour ne pas les écraser.")
            return
        }
        guard !i.fichiers.isEmpty, !importEnCours else {
            termine(i.fichiers.isEmpty ? "Aucun fichier lisible." : nil)
            return
        }
        enregistrerDifferees()

        let ancienne = saisonDisponible ? ligue : nil
        var historique = self.historique
        var ligue = self.ligue
        var reglages = self.reglages

        // Saisons passées ; une saison en cours remplacée par la suivante rejoint l'historique.
        var passes = i.fichiers.filter { $0.saison != i.saisonCourante }.flatMap(\.historique)
        if i.remplaceSaison, let a = ancienne, let s = a.season, !passes.contains(where: { $0.season == s }) {
            passes += a.matches.compactMap { m in
                guard let date = m.date, let h = m.butsDomicile, let b = m.butsExterieur, !m.forfait else { return nil }
                return MatchHistorique(season: s, date: date, home: m.domicile, away: m.exterieur,
                                       homeGoals: h, awayGoals: b, odds: m.cotesReference, oddsAvg: m.cotesMoyennes,
                                       oddsOpen: m.cotesOuverture)
            }
        }
        if !passes.isEmpty { historique = historique.remplacant(passes) }

        if let s = i.saisonCourante {
            do {
                ligue = try Ligue.depuisCSV(saison: s, lignes: i.fichiers.filter { $0.saison == s }.flatMap(\.matchs),
                                            existante: ancienne?.season == s ? ancienne : nil)
            } catch {
                termine(error.localizedDescription)
                return
            }
            if let premier = ligue.matches.compactMap(\.date).min() { reglages.debutSaison = premier }
            if i.remplaceSaison, ancienne == nil {
                // Saison d'un ancien format : réglages des paris remis à zéro.
                var neufs = Reglages()
                neufs.debutSaison = reglages.debutSaison
                neufs.simulations = reglages.simulations
                neufs.parametresModele = reglages.parametresModele
                reglages = neufs
            }
        }
        if let erreur = ligue.valider() ?? historique.valider() ?? reglages.valider() {
            termine(erreur)
            return
        }

        let recalibrer = historique != self.historique || reglages.debutSaison != self.reglages.debutSaison
            || reglages.parametresModele == nil
        importEnCours = true
        calibrationEnCours = recalibrer
        progressionCalibration = 0
        DispatchQueue.global(qos: .userInitiated).async {
            let prepare = MatchHistoriquePrepare.preparer(historique)
            var calibration: ResultatCalibration?
            if recalibrer {
                calibration = Calibration.calibrer(prepare.filter { $0.jour < reglages.jourDebutSaison }, progression: { v in
                    DispatchQueue.main.async { self.progressionCalibration = v }
                })
                reglages.parametresModele = calibration?.parametres
            }
            let parametres = reglages.parametresEnService
            for j in Set(ligue.matches.filter { $0.joue && !$0.fige }.map(\.journee)).sorted() {
                let modele = Modele.construire(ligue: ligue, historique: prepare, debutSaison: reglages.jourDebutSaison,
                                               journeeReference: j, parametres: parametres)
                for k in ligue.matches.indices where ligue.matches[k].journee == j && ligue.matches[k].joue
                    && !ligue.matches[k].fige {
                    let p = modele.probas(ligue.matches[k].domicile, ligue.matches[k].exterieur)
                    ligue.matches[k].figeP1 = p.p1
                    ligue.matches[k].figePN = p.pN
                    ligue.matches[k].figeP2 = p.p2
                    ligue.matches[k].figeLambdaDomicile = p.lambdaDomicile
                    ligue.matches[k].figeLambdaExterieur = p.lambdaExterieur
                }
            }
            DispatchQueue.main.async {
                termine(self.appliquerImport(i, ligue: ligue, historique: historique, reglages: reglages,
                                             calibration: recalibrer ? calibration : self.calibration))
            }
        }
    }

    private func appliquerImport(_ i: ImportCSV, ligue nouvelle: Ligue, historique: Historique, reglages: Reglages,
                                 calibration: ResultatCalibration?) -> String? {
        importEnCours = false
        calibrationEnCours = false
        var modifies: [FichierDonnees] = [.ligue, .historique, .reglages]
        if i.remplaceSaison {
            mouvements = []
            parisManuels = []
            parisExclus = []
            modifies += [.mouvements, .parisManuels, .parisExclus]
        } else {
            // Un match qui change de journée garde ses paris forcés ou exclus.
            var journees: [String: Int] = [:]
            for m in nouvelle.matches { journees["\(m.domicile)|\(m.exterieur)"] = m.journee }
            let manuels = parisManuels.map { p -> PariManuel in
                var q = p
                q.journee = journees["\(p.home)|\(p.away)"] ?? p.journee
                return q
            }
            let exclus = parisExclus.map { p -> PariExclu in
                var q = p
                q.journee = journees["\(p.home)|\(p.away)"] ?? p.journee
                return q
            }
            if manuels != parisManuels { parisManuels = manuels; modifies.append(.parisManuels) }
            if exclus != parisExclus { parisExclus = exclus; modifies.append(.parisExclus) }
        }
        ligue = nouvelle
        self.historique = historique
        self.reglages = reglages
        let ok = !modifies.map { sauvegarder($0) }.contains(false)
        log("Import : " + i.fichiers.map { "\($0.saison) (\($0.nom))" }.joined(separator: ", "), level: ok ? .success : .error)

        historiqueModifie()
        self.calibration = calibration
        calibrationCalculee = calibration != nil
        surveillerFichiers()
        chargerLogos()
        versionDonnees += 1
        return ok ? nil : "Import effectué en mémoire, mais la sauvegarde a échoué : voir le message d'erreur."
    }

    // MARK: - Logos

    private func chargerLogos() {
        var trouves: [String: NSImage] = [:]
        if let d = dossierLocal?.appendingPathComponent(dossierLogos, isDirectory: true) {
            for e in ligue.equipes {
                let url = d.appendingPathComponent(Ecussons.nomFichier(e))
                guard let attributs = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let taille = attributs[.size] as? NSNumber, taille.intValue <= tailleMaxLogo,
                      let image = NSImage(contentsOf: url) else { continue }
                trouves[e] = image
            }
        }
        logos = trouves
    }

    /// Copie les logos d'un dossier (PNG nommés comme les clubs) vers les données.
    private func copierLogos(depuis source: URL) -> Int {
        let fm = FileManager.default
        guard let fichiers = try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        let attendus = Set(ligue.equipes.map(Ecussons.nomFichier))
        let logos = fichiers.filter { attendus.contains($0.lastPathComponent) }
        var copies = 0
        func copier(vers dossier: URL) {
            try? fm.createDirectory(at: dossier, withIntermediateDirectories: true)
            for f in logos {
                guard let taille = try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize, taille <= tailleMaxLogo,
                      NSImage(contentsOf: f) != nil else { continue }
                let cible = dossier.appendingPathComponent(f.lastPathComponent)
                try? fm.removeItem(at: cible)
                if (try? fm.copyItem(at: f, to: cible)) != nil { copies += 1 }
            }
        }
        if let local = dossierLocal { copier(vers: local.appendingPathComponent(dossierLogos, isDirectory: true)) }
        return copies
    }

    /// Dossier des logos sur le disque local, créé au besoin.
    var dossierLogosLocal: URL? {
        guard let d = dossierLocal?.appendingPathComponent(dossierLogos, isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func rechargerLogos() { chargerLogos() }

    /// Choisit un dossier de logos (PNG nommés comme les clubs) et les copie dans les données.
    func importerLogos() {
        let panel = NSOpenPanel()
        panel.title = "Importer des logos"
        panel.prompt = "Importer"
        panel.message = "Fichiers PNG nommés comme les clubs, espaces remplacés par « _ » (ex. Paris_Saint_Germain.png)."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let dossier = panel.url else { return }
        let n = copierLogos(depuis: dossier)
        chargerLogos()
        log(n > 0 ? "\(n) logo(s) importé(s)" : "Aucun logo reconnu dans ce dossier",
            level: n > 0 ? .success : .warning)
    }

    // MARK: - Surveillance des fichiers

    /// Détecte une modification des JSON pendant que l'application tourne : sans
    /// cela, l'altération n'apparaîtrait qu'au lancement suivant.
    func surveillerFichiers() {
        surveillants.forEach { $0.cancel() }
        surveillants.removeAll()
        guard let dossier = dossierLocal else { return }
        for f in FichierDonnees.allCases {
            armerSurveillant(url: dossier.appendingPathComponent(f.nom), nom: f.nom)
        }
    }

    private func armerSurveillant(url: URL, nom: String) {
        // O_EVTONLY : simple observation, le descripteur n'empêche pas l'éjection
        // du volume.
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            source.cancel()
            guard let self else { return }
            // Une écriture atomique remplace le fichier : le descripteur devient
            // caduc, il faut le rouvrir. Le délai laisse passer l'écriture du
            // sceau qui suit nos propres sauvegardes, sinon chacune alerterait.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.controler(url: url, nom: nom)
                self.surveillants.removeAll { $0.isCancelled }
                self.armerSurveillant(url: url, nom: nom)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        surveillants.append(source)
    }

    private func controler(url: URL, nom: String) {
        guard alerteIntegrite == nil else { return }   // une question à la fois
        guard let brut = try? Data(contentsOf: url) else { return }
        let sceau = try? Data(contentsOf: url.appendingPathExtension("hmac"))

        if let sceau {
            guard !IntegriteStockage.verifier(brut, nom: nom, sceau: sceau) else { return }
            signaler(AlerteIntegrite(fichier: nom, url: url, sceauAbsent: false))
        } else if IntegriteStockage.estActive(nom) {
            signaler(AlerteIntegrite(fichier: nom, url: url, sceauAbsent: true))
        } else {
            return
        }
        log("\(nom) a été modifié en dehors de l'application", level: .error)
    }

    // MARK: Comparaison avant acceptation

    /// Confronte le fichier sur le disque aux données en mémoire (ou, au
    /// démarrage, à la copie conservée dans le sceau), pour que l'utilisateur
    /// voie ce qui a changé avant de trancher.
    func differences(_ alerte: AlerteIntegrite) -> ResultatComparaison {
        switch FichierDonnees(nom: alerte.fichier) {
        case .ligue?:            return differences(Ligue.self, alerte)
        case .reglages?:         return differences(Reglages.self, alerte)
        case .mouvements?:       return differences([Mouvement].self, alerte)
        case .parisManuels?:     return differences([PariManuel].self, alerte)
        case .parisExclus?:      return differences([PariExclu].self, alerte)
        case .historique?:       return differences(Historique.self, alerte)
        case nil:                return ResultatComparaison(lignes: [], inchangees: 0, erreur: "Fichier inconnu.")
        }
    }

    private func differences<T: DocumentScelle>(_ type: T.Type, _ alerte: AlerteIntegrite) -> ResultatComparaison {
        guard let brut = try? Data(contentsOf: alerte.url) else {
            return ResultatComparaison(lignes: [], inchangees: 0, erreur: "Fichier illisible.")
        }
        guard let disque = try? decodeur.decode(T.self, from: brut) else {
            return ResultatComparaison(lignes: [], inchangees: 0,
                                       erreur: "Le fichier n'est plus un JSON « \(T.fichier.titre.lowercased()) » valide : il ne peut pas être accepté.")
        }
        let (lignes, inchangees) = comparer(memoire: reference(T.self, alerte).lignes, disque: disque.lignes)
        return ResultatComparaison(lignes: lignes, inchangees: inchangees, erreur: nil)
    }

    /// Données d'avant : celles en mémoire si elles ont été chargées, sinon la
    /// copie conservée dans le sceau.
    private func reference<T: DocumentScelle>(_ type: T.Type, _ alerte: AlerteIntegrite) -> T {
        if fichiersCharges.contains(T.fichier) { return self[keyPath: T.chemin] }
        let sceau = try? Data(contentsOf: alerte.url.appendingPathExtension("hmac"))
        return sceau
            .flatMap { IntegriteStockage.contenuScelle($0, nom: alerte.fichier) }
            .flatMap { try? decodeur.decode(T.self, from: $0) } ?? T()
    }

    private func comparer(memoire: [(cle: String, resume: String)],
                          disque: [(cle: String, resume: String)]) -> ([LigneComparaison], Int) {
        var parCle: [String: (avant: String?, apres: String?)] = [:]
        for e in memoire { parCle[e.cle, default: (nil, nil)].avant = e.resume }
        for e in disque { parCle[e.cle, default: (nil, nil)].apres = e.resume }

        var lignes: [LigneComparaison] = []
        var inchangees = 0

        for (cle, paire) in parCle {
            switch (paire.avant, paire.apres) {
            case let (nil, .some(apres)):
                lignes.append(LigneComparaison(id: cle,
                                               etat: memoire.isEmpty ? .presente : .ajoutee,
                                               avant: nil, apres: apres))
            case let (.some(avant), nil):
                lignes.append(LigneComparaison(id: cle, etat: .supprimee, avant: avant, apres: nil))
            case let (.some(avant), .some(apres)):
                if avant == apres { inchangees += 1 }
                else { lignes.append(LigneComparaison(id: cle, etat: .modifiee, avant: avant, apres: apres)) }
            case (nil, nil):
                break
            }
        }

        return (lignes.sorted { $0.apres ?? $0.avant ?? "" < $1.apres ?? $1.avant ?? "" }, inchangees)
    }

    /// Applique les décisions ligne par ligne : pour chaque enregistrement,
    /// `garder` dit si l'on retient ce que contient le fichier ou si l'on
    /// rétablit l'état d'avant. Le résultat passe par la sauvegarde habituelle,
    /// donc il est réécrit et scellé.
    func appliquer(_ alerte: AlerteIntegrite, garder: [String: Bool]) {
        switch FichierDonnees(nom: alerte.fichier) {
        case .ligue?:            appliquer(Ligue.self, alerte, garder: garder)
        case .reglages?:         appliquer(Reglages.self, alerte, garder: garder)
        case .mouvements?:       appliquer([Mouvement].self, alerte, garder: garder)
        case .parisManuels?:     appliquer([PariManuel].self, alerte, garder: garder)
        case .parisExclus?:      appliquer([PariExclu].self, alerte, garder: garder)
        case .historique?:       appliquer(Historique.self, alerte, garder: garder)
        case nil:                alerteIntegrite = nil
        }
    }

    private func appliquer<T: DocumentScelle>(_ type: T.Type, _ alerte: AlerteIntegrite, garder: [String: Bool]) {
        alerteIntegrite = nil

        guard let brut = try? Data(contentsOf: alerte.url) else {
            log("Fichier illisible : \(alerte.fichier)", level: .error)
            return
        }
        guard let disque = try? decodeur.decode(T.self, from: brut) else {
            log("JSON \(alerte.fichier) invalide : rien n'a été appliqué", level: .error)
            return
        }
        let fusion = reference(T.self, alerte).fusion(disque: disque, garder: garder)
        if let erreur = fusion.valider() {
            log("\(alerte.fichier) : \(erreur) Rien n'a été appliqué.", level: .error)
            return
        }
        self[keyPath: T.chemin] = fusion
        fichiersCharges.insert(T.fichier)

        sauvegarder(T.self)
        derniereErreur = nil
        chargerDonnees()
    }

    /// Vrai quand le sceau contient une copie exploitable de l'état précédent.
    func versionScelleeDisponible(_ alerte: AlerteIntegrite) -> Bool {
        guard let sceau = try? Data(contentsOf: alerte.url.appendingPathExtension("hmac")) else {
            return false
        }
        return IntegriteStockage.contenuScelle(sceau, nom: alerte.fichier) != nil
    }

    /// Réécrit le fichier avec le dernier contenu scellé : l'inverse d'accepter.
    func restaurerVersionScellee(_ alerte: AlerteIntegrite) {
        alerteIntegrite = nil
        if let sceau = try? Data(contentsOf: alerte.url.appendingPathExtension("hmac")),
           let contenu = IntegriteStockage.contenuScelle(sceau, nom: alerte.fichier) {
            do {
                try contenu.write(to: alerte.url, options: .atomic)
                log("\(alerte.fichier) restauré dans sa dernière version scellée", level: .success)
            } catch {
                log("Restauration impossible : \(error.localizedDescription)", level: .error)
            }
        } else {
            log("Aucune version scellée exploitable pour \(alerte.fichier)", level: .error)
        }
        derniereErreur = nil
        chargerDonnees()
    }

    // MARK: - Exports (fichiers lisibles, donc NON chiffrés : l'utilisateur choisit l'emplacement)

    private func demanderEmplacement(nom: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Exporter"
        panel.nameFieldStringValue = nom
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.message = "Attention : ce fichier contiendra vos données (cotes, paris, bankroll) non chiffrées."
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Échappe un champ texte CSV et neutralise l'injection de formules (=, +, -, @…) dans Excel.
    private func champCSV(_ valeur: String) -> String {
        var v = valeur
        if let premier = v.unicodeScalars.first, "=+-@\t\r\n".unicodeScalars.contains(premier) {
            v = "'" + v
        }
        v = v.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(v)\""
    }

    private func nombreCSV(_ v: Double?, decimales: Int = 2) -> String {
        guard let v else { return "" }
        return String(format: "%.\(decimales)f", locale: Locale(identifier: "en_US_POSIX"), v)
    }

    private func entierCSV(_ v: Int?) -> String { v.map(String.init) ?? "" }

    /// Matchs, classement et historique des paris, une section par tableau.
    /// Retourne l'URL, ou nil (annulation / erreur).
    @discardableResult
    func exporterCSV() -> URL? {
        let jour = Jour.versISO(Jour.depuisDate(Date()))
        guard let url = demanderEmplacement(nom: "Ligue1_export_\(jour).csv", type: .commaSeparatedText) else {
            return nil
        }
        var lignes: [String] = []

        lignes.append("Matchs")
        lignes.append((["Journée", "Domicile", "Extérieur", "Buts dom.", "Buts ext.", "xG dom.", "xG ext."]
                       + Bookmaker.allCases.flatMap { b in ["1", "N", "2"].map { "\(b.titre) \($0)" } }
                       + ["p1 figée", "pN figée", "p2 figée", "λ dom. figé", "λ ext. figé", "Minutes dom.", "Minutes ext.", "Forfait"])
                        .joined(separator: ","))
        for m in ligue.matches {
            var champs = ["\(m.journee)", champCSV(m.domicile), champCSV(m.exterieur),
                          entierCSV(m.butsDomicile), entierCSV(m.butsExterieur),
                          nombreCSV(m.xgDomicile), nombreCSV(m.xgExterieur)]
            for b in Bookmaker.allCases {
                let c = m.cotes[b]
                champs += (0..<3).map { nombreCSV(c?.count == 3 ? c?[$0] : nil) }
            }
            champs += [nombreCSV(m.figeP1, decimales: 4), nombreCSV(m.figePN, decimales: 4), nombreCSV(m.figeP2, decimales: 4),
                       nombreCSV(m.figeLambdaDomicile, decimales: 3), nombreCSV(m.figeLambdaExterieur, decimales: 3),
                       champCSV((m.minutesDomicile ?? []).joined(separator: " ")),
                       champCSV((m.minutesExterieur ?? []).joined(separator: " ")), m.forfait ? "Oui" : "Non"]
            lignes.append(champs.joined(separator: ","))
        }

        lignes.append("")
        lignes.append("Classement général")
        lignes.append("Rang,Équipe,J,G,N,P,BP,BC,Diff,Pts")
        for l in Classements.general(ligue) {
            lignes.append(["\(l.rang)", champCSV(l.equipe), "\(l.joues)", "\(l.gagnes)", "\(l.nuls)", "\(l.perdus)",
                           "\(l.butsPour)", "\(l.butsContre)", "\(l.difference)", "\(l.points)"].joined(separator: ","))
        }

        let r = resultatParis
        lignes.append("")
        lignes.append("Paris réglés")
        lignes.append((["Journée", "Domicile", "Extérieur", "Marché", "Manuel", "p modèle", "Cote", "Bookmaker", "EV", "Résultat", "Gagné", "2 buts d'avance"]
                       + MethodeMise.allCases.flatMap { ["\($0.titre) mise", "\($0.titre) gain"] }).joined(separator: ","))
        for p in r.paris {
            lignes.append((["\(p.journee)", champCSV(p.domicile), champCSV(p.exterieur), p.marche.rawValue,
                            p.manuel ? "Oui" : "Non", nombreCSV(p.p, decimales: 4), nombreCSV(p.cote), champCSV(p.source),
                            nombreCSV(p.esperance, decimales: 3), p.resultat?.rawValue ?? "",
                            p.gagne ? "Oui" : "Non", p.gagneParAvance ? "Oui" : "Non"]
                           + MethodeMise.allCases.flatMap { [nombreCSV(p.mises[$0]), nombreCSV(p.gains[$0])] })
                            .joined(separator: ","))
        }

        do {
            try lignes.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            log("CSV exporté", level: .success)
            return url
        } catch {
            log("Erreur export CSV: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
}
