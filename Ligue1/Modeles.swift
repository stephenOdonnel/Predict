//
//  Modeles.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Données de la saison : équipes, matchs (date, score, cotes de référence,
//  xG, cotes saisies, probabilités figées, minutes de but, forfait),
//  historique des saisons passées, réglages de la simulation de paris,
//  dépôts/retraits, paris manuels et exclus. Chaque fichier est scellé (voir
//  FichierDonnees).
//  Seule source extérieure : les CSV de football-data.co.uk, téléchargés par
//  l'utilisateur (saison en cours, saisons passées, fixtures.csv).
//
import Foundation

// MARK: - Fichiers de données

/// Un fichier par type de donnée : une altération n'en bloque qu'un seul.
enum FichierDonnees: String, CaseIterable, Identifiable {
    case ligue, historique, reglages, mouvements, parisManuels, parisExclus

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .ligue:            return "league_data.json"
        case .reglages:         return "app_state.json"
        case .mouvements:       return "bankroll_events.json"
        case .parisManuels:     return "manual_bets.json"
        case .parisExclus:      return "excluded_bets.json"
        case .historique:       return "history.json"
        }
    }

    var titre: String {
        switch self {
        case .ligue:            return "Saison en cours"
        case .reglages:         return "Réglages des paris"
        case .mouvements:       return "Dépôts et retraits"
        case .parisManuels:     return "Paris manuels"
        case .parisExclus:      return "Paris exclus"
        case .historique:       return "Historique"
        }
    }

    init?(nom: String) {
        guard let f = Self.allCases.first(where: { $0.nom == nom }) else { return nil }
        self = f
    }
}

/// Bornes communes de validation des saisies.
enum Limites {
    static let texte = 100
    static let buts = 99
    static let xg: Double = 15
    static let cote: Double = 1_000
    static let montant: Double = 10_000_000

    static func texteValide(_ s: String, obligatoire: Bool = true) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!obligatoire || !t.isEmpty) && t.count <= texte
    }
}

/// Fichier scellé : ses enregistrements, avec une clé stable (celle par laquelle
/// la revue d'intégrité accepte ou rejette une modification) et un résumé lisible.
protocol DocumentScelle: Codable {
    static var fichier: FichierDonnees { get }
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, Self> { get }
    /// Contenu d'un fichier absent.
    init()
    /// Enregistrements dans l'ordre du fichier.
    var lignes: [(cle: String, resume: String)] { get }
    /// `self` est l'état d'avant : pour chaque clé, `garder` dit si l'on retient
    /// la version du disque ou si l'on rétablit celle d'avant.
    func fusion(disque: Self, garder: [String: Bool]) -> Self
    /// Message d'erreur, ou nil si le contenu peut être écrit.
    func valider() -> String?
}

/// Élément d'un fichier qui n'est qu'une liste (mouvements, paris manuels, exclus).
protocol ElementListe: Codable, Equatable {
    static var fichier: FichierDonnees { get }
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, [Self]> { get }
    var resume: String { get }
}

extension Array: DocumentScelle where Element: ElementListe {
    static var fichier: FichierDonnees { Element.fichier }
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, [Element]> { Element.chemin }

    var lignes: [(cle: String, resume: String)] {
        let cles = Fusion.clesUniques(map(\.resume))
        return zip(cles, map(\.resume)).map { ($0, $1) }
    }

    func fusion(disque: [Element], garder: [String: Bool]) -> [Element] {
        Fusion.listes(avant: self, disque: disque, cle: \.resume, garder: garder)
    }

    func valider() -> String? { nil }
}

/// Fusion ligne par ligne, commune à tous les fichiers.
enum Fusion {
    /// Deux éléments identiques reçoivent des clés distinctes (« … #2 »).
    static func clesUniques(_ bases: [String]) -> [String] {
        var vus: [String: Int] = [:]
        return bases.map { base in
            vus[base, default: 0] += 1
            let n = vus[base] ?? 1
            return n == 1 ? base : "\(base) #\(n)"
        }
    }

    /// Ligne retenue : la version du disque. Ligne rejetée : celle d'avant, ou
    /// rien si elle n'existait pas encore. L'ordre du fichier est conservé, les
    /// lignes rétablies sont ajoutées ensuite.
    static func listes<T>(avant: [T], disque: [T], cle: (T) -> String, garder: [String: Bool]) -> [T] {
        let clesAvant = clesUniques(avant.map(cle))
        let clesDisque = clesUniques(disque.map(cle))
        var parCleAvant: [String: T] = [:]
        for (k, e) in zip(clesAvant, avant) { parCleAvant[k] = e }

        var resultat: [T] = []
        var vus = Set<String>()
        for (k, e) in zip(clesDisque, disque) {
            vus.insert(k)
            if garder[k] ?? true { resultat.append(e) }
            else if let precedent = parCleAvant[k] { resultat.append(precedent) }
        }
        for (k, e) in zip(clesAvant, avant) where !vus.contains(k) {
            if !(garder[k] ?? true) { resultat.append(e) }
        }
        return resultat
    }
}

// MARK: - Bookmakers et marchés

enum Bookmaker: String, CaseIterable, Identifiable, Codable {
    case winamax, unibet, bwin, betclic

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .winamax: return "Winamax"
        case .unibet:  return "Unibet"
        case .bwin:    return "Bwin"
        case .betclic: return "Betclic"
        }
    }

    var cleJSON: String { "odds_\(rawValue)" }
}

/// Résultat d'un match, du point de vue des marchés simples.
enum Issue: String, Codable, CaseIterable {
    case domicile = "1", nul = "N", exterieur = "2"
}

enum Marche: String, Codable, CaseIterable, Identifiable {
    case un = "1", nul = "N", deux = "2", unNul = "1N", unDeux = "12", nulDeux = "N2"

    static let simples: [Marche] = [.un, .nul, .deux]
    static let doublesChances: [Marche] = [.unNul, .unDeux, .nulDeux]

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .un:   return "1 (domicile)"
        case .nul:  return "N (nul)"
        case .deux: return "2 (extérieur)"
        default:    return rawValue
        }
    }

    var estDoubleChance: Bool { Marche.doublesChances.contains(self) }

    /// Les deux jambes d'une double chance (« 1N » = « 1 » + « N »).
    var jambes: (Marche, Marche)? {
        switch self {
        case .unNul:   return (.un, .nul)
        case .unDeux:  return (.un, .deux)
        case .nulDeux: return (.nul, .deux)
        default:       return nil
        }
    }
}

// MARK: - Saison en cours

struct Equipe: Codable, Equatable {
    var name: String
}

struct Match: Codable, Equatable, Identifiable {
    var journee: Int
    var domicile: String
    var exterieur: String
    /// AAAA-MM-JJ, d'après le CSV ; nil tant que le match n'est pas programmé.
    var date: String?
    var butsDomicile: Int?
    var butsExterieur: Int?
    var xgDomicile: Double?
    var xgExterieur: Double?
    /// [cote 1, cote N, cote 2] par bookmaker renseigné.
    var cotes: [Bookmaker: [Double]] = [:]
    /// Cotes 1/N/2 du CSV (clôture Pinnacle de préférence) : données du modèle
    /// et référence, jamais utilisées pour parier.
    var cotesReference: [Double]?
    /// Cotes 1/N/2 d'ouverture du CSV (Pinnacle de préférence), relevées en
    /// même temps que les cotes de pari : probabilité de marché des paris, sans
    /// connaître la clôture.
    var cotesOuverture: [Double]?
    /// Cote moyenne du marché en ligne (CSV, avant le match) : cote de pari
    /// indicative tant qu'aucun bookmaker n'est saisi.
    var cotesMoyennes: [Double]?
    /// Probabilités figées juste avant la toute première validation du score.
    var figeP1: Double?
    var figePN: Double?
    var figeP2: Double?
    var figeLambdaDomicile: Double?
    var figeLambdaExterieur: Double?
    /// Minutes des buts (« 23 », « 45+4 ») : règle Winamax des 2 buts d'avance.
    var minutesDomicile: [String]?
    var minutesExterieur: [String]?
    /// Forfait administratif : compte au classement, jamais dans le modèle.
    var forfait = false

    init(journee: Int, domicile: String, exterieur: String) {
        self.journee = journee
        self.domicile = domicile
        self.exterieur = exterieur
    }

    var id: String { "\(journee)|\(domicile)|\(exterieur)" }

    var joue: Bool { butsDomicile != nil && butsExterieur != nil }
    var fige: Bool { figeP1 != nil }

    var libelle: String { "\(domicile) – \(exterieur)" }

    /// Bookmakers renseignés (3 cotes), dans l'ordre Winamax, Unibet, Bwin, Betclic.
    var livres: [(livre: Bookmaker, cotes: [Double])] {
        Bookmaker.allCases.compactMap { b in
            guard let c = cotes[b], c.count == 3 else { return nil }
            return (b, c)
        }
    }

    /// Meilleure cote marché par marché, tous bookmakers confondus ; à défaut de
    /// bookmaker saisi, cote moyenne en ligne.
    var meilleuresCotes: [Double]? {
        let l = livres
        guard !l.isEmpty else { return cotesMoyennes }
        return (0..<3).map { i in l.map { $0.cotes[i] }.max() ?? 0 }
    }

    /// Cote médiane entre bookmakers : référence de la jauge cote min/max ; à
    /// défaut de bookmaker saisi, cote moyenne en ligne.
    var cotesMedianes: [Double]? {
        let l = livres
        guard !l.isEmpty else { return cotesMoyennes }
        return (0..<3).map { i in Statistiques.mediane(l.map { $0.cotes[i] }) }
    }

    /// Bookmaker offrant la meilleure cote sur 1, N et 2 (le premier en cas d'égalité).
    var sourcesMeilleuresCotes: [Bookmaker]? {
        let l = livres
        guard !l.isEmpty else { return nil }
        return (0..<3).map { i in
            var meilleur = l[0]
            for e in l.dropFirst() where e.cotes[i] > meilleur.cotes[i] { meilleur = e }
            return meilleur.livre
        }
    }

    var issue: Issue? {
        guard let h = butsDomicile, let a = butsExterieur else { return nil }
        if h > a { return .domicile }
        return h == a ? .nul : .exterieur
    }

    enum CodingKeys: String, CodingKey {
        case journee, home, away, date
        case homeGoals = "home_goals", awayGoals = "away_goals"
        case homeXg = "home_xg", awayXg = "away_xg"
        case oddsWinamax = "odds_winamax", oddsUnibet = "odds_unibet"
        case oddsBwin = "odds_bwin", oddsBetclic = "odds_betclic", oddsRef = "odds_ref", oddsAvg = "odds_avg"
        case oddsOpen = "odds_open"
        case frozenP1 = "frozen_p1", frozenPN = "frozen_pN", frozenP2 = "frozen_p2"
        case frozenLambdaHome = "frozen_lambda_home", frozenLambdaAway = "frozen_lambda_away"
        case homeGoalMinutes = "home_goal_minutes", awayGoalMinutes = "away_goal_minutes"
        case isForfeit = "is_forfeit"
    }

    private static func cleCotes(_ b: Bookmaker) -> CodingKeys {
        switch b {
        case .winamax: return .oddsWinamax
        case .unibet:  return .oddsUnibet
        case .bwin:    return .oddsBwin
        case .betclic: return .oddsBetclic
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        journee = try c.decode(Int.self, forKey: .journee)
        domicile = try c.decode(String.self, forKey: .home)
        exterieur = try c.decode(String.self, forKey: .away)
        date = try c.decodeIfPresent(String.self, forKey: .date)
        butsDomicile = try c.decodeIfPresent(Int.self, forKey: .homeGoals)
        butsExterieur = try c.decodeIfPresent(Int.self, forKey: .awayGoals)
        xgDomicile = try c.decodeIfPresent(Double.self, forKey: .homeXg)
        xgExterieur = try c.decodeIfPresent(Double.self, forKey: .awayXg)
        for b in Bookmaker.allCases {
            if let o = try c.decodeIfPresent([Double].self, forKey: Self.cleCotes(b)), !o.isEmpty {
                cotes[b] = o
            }
        }
        cotesReference = try c.decodeIfPresent([Double].self, forKey: .oddsRef)
        cotesOuverture = try c.decodeIfPresent([Double].self, forKey: .oddsOpen)
        cotesMoyennes = try c.decodeIfPresent([Double].self, forKey: .oddsAvg)
        figeP1 = try c.decodeIfPresent(Double.self, forKey: .frozenP1)
        figePN = try c.decodeIfPresent(Double.self, forKey: .frozenPN)
        figeP2 = try c.decodeIfPresent(Double.self, forKey: .frozenP2)
        figeLambdaDomicile = try c.decodeIfPresent(Double.self, forKey: .frozenLambdaHome)
        figeLambdaExterieur = try c.decodeIfPresent(Double.self, forKey: .frozenLambdaAway)
        minutesDomicile = try c.decodeIfPresent([String].self, forKey: .homeGoalMinutes)
        minutesExterieur = try c.decodeIfPresent([String].self, forKey: .awayGoalMinutes)
        forfait = try c.decodeIfPresent(Bool.self, forKey: .isForfeit) ?? false
    }

    /// Toutes les clés sont écrites, `null` compris.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(journee, forKey: .journee)
        try c.encode(domicile, forKey: .home)
        try c.encode(exterieur, forKey: .away)
        try c.encode(date, forKey: .date)
        try c.encode(butsDomicile, forKey: .homeGoals)
        try c.encode(butsExterieur, forKey: .awayGoals)
        try c.encode(xgDomicile, forKey: .homeXg)
        try c.encode(xgExterieur, forKey: .awayXg)
        for b in Bookmaker.allCases {
            try c.encode(cotes[b], forKey: Self.cleCotes(b))
        }
        try c.encode(cotesReference, forKey: .oddsRef)
        try c.encode(cotesOuverture, forKey: .oddsOpen)
        try c.encode(cotesMoyennes, forKey: .oddsAvg)
        try c.encode(figeP1, forKey: .frozenP1)
        try c.encode(figePN, forKey: .frozenPN)
        try c.encode(figeP2, forKey: .frozenP2)
        try c.encode(figeLambdaDomicile, forKey: .frozenLambdaHome)
        try c.encode(figeLambdaExterieur, forKey: .frozenLambdaAway)
        try c.encode(minutesDomicile, forKey: .homeGoalMinutes)
        try c.encode(minutesExterieur, forKey: .awayGoalMinutes)
        try c.encode(forfait, forKey: .isForfeit)
    }

    /// Une ligne lisible, pour la revue d'intégrité.
    var resume: String {
        var parties = ["J\(journee)"]
        if let date { parties.append(date) }
        if let h = butsDomicile, let a = butsExterieur {
            parties.append("\(domicile) \(h)-\(a) \(exterieur)")
        } else {
            parties.append("\(libelle) (à jouer)")
        }
        if let h = xgDomicile, let a = xgExterieur {
            parties.append("xG \(Format.nombre(h))-\(Format.nombre(a))")
        }
        if let r = cotesReference {
            parties.append("réf. " + r.map { Format.nombre($0) }.joined(separator: "/"))
        }
        if let r = cotesMoyennes {
            parties.append("moy. " + r.map { Format.nombre($0) }.joined(separator: "/"))
        }
        for (b, o) in livres {
            parties.append("\(b.titre) " + o.map { Format.nombre($0) }.joined(separator: "/"))
        }
        if let p1 = figeP1, let pN = figePN, let p2 = figeP2 {
            parties.append("figé " + [p1, pN, p2].map { Format.nombre($0 * 100, decimales: 1) }.joined(separator: "/") + " %")
        }
        if minutesDomicile != nil || minutesExterieur != nil {
            parties.append("buts " + (minutesDomicile ?? []).joined(separator: ",") + " / "
                           + (minutesExterieur ?? []).joined(separator: ","))
        }
        if forfait { parties.append("forfait") }
        return parties.joined(separator: " · ")
    }
}

struct Ligue: DocumentScelle, Equatable {
    static let fichier = FichierDonnees.ligue
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, Ligue> { \.ligue }

    /// « 2025-26 » ; nil pour une saison qui ne vient pas des CSV (ignorée).
    var season: String?
    var teams: [Equipe] = []
    var matches: [Match] = []

    var equipes: [String] { teams.map(\.name) }

    var nJournees: Int { matches.map(\.journee).max() ?? 0 }

    var matchsJoues: [Match] { matches.filter(\.joue) }
    var matchsAJouer: [Match] { matches.filter { !$0.joue } }

    func matchs(journee j: Int) -> [Match] { matches.filter { $0.journee == j } }

    func indexMatch(_ id: Match.ID) -> Int? { matches.firstIndex { $0.id == id } }

    var lignes: [(cle: String, resume: String)] {
        [("Saison", "Saison \(season ?? "—")")]
            + teams.map { ("Équipe · \($0.name)", "Équipe · \($0.name)") }
            + matches.map { ("J\($0.journee) · \($0.libelle)", $0.resume) }
    }

    func fusion(disque: Ligue, garder: [String: Bool]) -> Ligue {
        Ligue(season: (garder["Saison"] ?? true) ? disque.season : season,
              teams: Fusion.listes(avant: teams, disque: disque.teams, cle: { "Équipe · \($0.name)" }, garder: garder),
              matches: Fusion.listes(avant: matches, disque: disque.matches,
                                     cle: { "J\($0.journee) · \($0.libelle)" }, garder: garder))
    }

    /// Cohérence minimale avant toute écriture : chaque match oppose deux équipes de la saison.
    func valider() -> String? {
        let noms = Set(equipes)
        guard noms.count == teams.count else { return "Une équipe apparaît deux fois." }
        for m in matches {
            guard noms.contains(m.domicile), noms.contains(m.exterieur), m.domicile != m.exterieur else {
                return "J\(m.journee) : \(m.libelle) ne correspond pas aux équipes de la saison."
            }
            guard m.journee >= 1 else { return "Numéro de journée invalide (\(m.journee))." }
            if let d = m.date, Jour.depuisISO(d) == nil { return "J\(m.journee) : date invalide (« \(d) »)." }
            for c in [m.cotesReference, m.cotesMoyennes].compactMap({ $0 })
            where !(c.count == 3 && c.allSatisfy({ $0.isFinite && $0 > 1 && $0 < Limites.cote })) {
                return "J\(m.journee) : \(m.libelle), cotes du CSV invalides."
            }
        }
        return nil
    }
}

// MARK: - Historique (saisons passées, football-data.co.uk)

/// Match d'une saison passée, lu dans un CSV de football-data.co.uk.
struct MatchHistorique: Codable, Equatable {
    /// « 2015-16 ».
    var season: String
    var date: String
    var home: String
    var away: String
    var homeGoals: Int
    var awayGoals: Int
    /// Cotes 1/N/2 de clôture (Pinnacle, sinon moyenne du marché), à défaut d'ouverture.
    var odds: [Double]?
    /// Cote moyenne du marché avant le match : cote de pari de la mesure de précision.
    var oddsAvg: [Double]?
    /// Cotes d'ouverture (Pinnacle de préférence), relevées avec `oddsAvg` :
    /// probabilité de marché des paris de la mesure de précision.
    var oddsOpen: [Double]? = nil

    enum CodingKeys: String, CodingKey {
        case season, date, home, away, odds
        case homeGoals = "home_goals", awayGoals = "away_goals", oddsAvg = "odds_avg", oddsOpen = "odds_open"
    }

    var jour: Int? { Jour.depuisISO(date) }
    var cle: String { "\(date) · \(home) – \(away)" }

    var resume: String {
        "\(date) · \(home) \(homeGoals)-\(awayGoals) \(away)"
            + (odds.map { " · cotes " + $0.map { Format.nombre($0) }.joined(separator: " / ") } ?? "")
    }
}

/// Saisons passées : nourrissent le modèle (pondérées par ancienneté) et sa calibration.
struct Historique: DocumentScelle, Equatable {
    static let fichier = FichierDonnees.historique
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, Historique> { \.historique }

    var source = "football-data.co.uk"
    var matches: [MatchHistorique] = []

    var saisons: [String] { Array(Set(matches.map(\.season))).sorted() }

    var lignes: [(cle: String, resume: String)] {
        let cles = Fusion.clesUniques(matches.map(\.cle))
        return [("En-tête", "Source \(source)")] + zip(cles, matches).map { ($0, $1.resume) }
    }

    func fusion(disque: Historique, garder: [String: Bool]) -> Historique {
        Historique(source: (garder["En-tête"] ?? true) ? disque.source : source,
                   matches: Fusion.listes(avant: matches, disque: disque.matches, cle: { $0.cle }, garder: garder))
    }

    func valider() -> String? {
        for m in matches {
            guard m.jour != nil else { return "Date invalide dans l'historique : « \(m.date) »." }
            guard (0...Limites.buts).contains(m.homeGoals), (0...Limites.buts).contains(m.awayGoals) else {
                return "Score invalide dans l'historique : \(m.cle)."
            }
            guard m.home != m.away, Limites.texteValide(m.home), Limites.texteValide(m.away),
                  Limites.texteValide(m.season) else { return "Équipes invalides dans l'historique : \(m.cle)." }
            for c in [m.odds, m.oddsAvg].compactMap({ $0 })
            where !(c.count == 3 && c.allSatisfy({ $0.isFinite && $0 > 1 && $0 < Limites.cote })) {
                return "Cotes invalides dans l'historique : \(m.cle)."
            }
        }
        return nil
    }

    /// Les saisons importées remplacent celles du même nom ; les autres sont gardées.
    func remplacant(_ nouveaux: [MatchHistorique]) -> Historique {
        let remplacees = Set(nouveaux.map(\.season))
        let gardes = matches.filter { !remplacees.contains($0.season) }
        return Historique(source: source,
                          matches: (gardes + nouveaux).sorted { ($0.date, $0.home) < ($1.date, $1.home) })
    }
}

/// CSV de football-data.co.uk : F1.csv, D1.csv, E0.csv, I1.csv ou SP1.csv (une saison du championnat actif, matchs joués)
/// et fixtures.csv (matchs de la semaine à venir, toutes divisions), importés
/// par l'utilisateur ou téléchargés à sa demande (« Mettre à jour en ligne »).
enum FootballData {
    static var page: URL { Championnat.actif.pageFootballData }
    static let fixtures = URL(string: "https://www.football-data.co.uk/fixtures.csv")!

    /// Fichier d'une saison du championnat actif : « 2025-26 » → …/mmz4281/2526/F1.csv.
    static func urlSaison(_ saison: String) -> URL? {
        let chiffres = saison.split(separator: "-")
        guard chiffres.count == 2, chiffres[0].count == 4, chiffres[1].count == 2,
              chiffres.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return nil }
        return URL(string: "https://www.football-data.co.uk/mmz4281/\(chiffres[0].suffix(2))\(chiffres[1])/\(Championnat.actif.codeCSV).csv")
    }

    /// Un match du CSV : joué (score) ou seulement programmé.
    struct LigneMatch {
        let date: String
        let domicile: String
        let exterieur: String
        let buts: (domicile: Int, exterieur: Int)?
        /// Référence (clôture Pinnacle de préférence).
        let cotes: [Double]?
        /// Moyenne du marché avant le match.
        let cotesMoyennes: [Double]?
        /// Bwin avant le match (à défaut à la clôture) : seul bookmaker proposé
        /// en France que le CSV donne.
        let cotesBwin: [Double]?
        /// Ouverture (Pinnacle, sinon Bet365, sinon moyenne), même relevé que `cotesMoyennes`.
        let cotesOuverture: [Double]?
    }

    struct Fichier {
        let nom: String
        let saison: String
        let matchs: [LigneMatch]

        var joues: Int { matchs.filter { $0.buts != nil }.count }

        var resume: String {
            let aVenir = matchs.count - joues
            return "\(saison) : \(joues) matchs joués" + (aVenir > 0 ? ", \(aVenir) à venir" : "")
                + ", \(matchs.filter { $0.cotes != nil }.count) avec cotes (\(nom))"
        }

        /// Matchs joués, au format de l'historique.
        var historique: [MatchHistorique] {
            matchs.compactMap { m in
                m.buts.map {
                    MatchHistorique(season: saison, date: m.date, home: m.domicile, away: m.exterieur,
                                    homeGoals: $0.domicile, awayGoals: $0.exterieur, odds: m.cotes,
                                    oddsAvg: m.cotesMoyennes, oddsOpen: m.cotesOuverture)
                }
            }
        }
    }

    struct Erreur: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Noms football-data.co.uk → noms affichés, pour le championnat actif.
    static var clubs: [String: String] { Championnat.actif.clubs }

    /// Cotes retenues, de la plus fiable à la moins fiable : clôture Pinnacle,
    /// clôture moyenne, puis ouverture (Pinnacle, moyenne, Bet365).
    private static let colonnesCotes = [("PSCH", "PSCD", "PSCA"), ("AvgCH", "AvgCD", "AvgCA"), ("PSH", "PSD", "PSA"),
                                        ("AvgH", "AvgD", "AvgA"), ("BbAvH", "BbAvD", "BbAvA"), ("B365H", "B365D", "B365A")]
    /// Cote moyenne du marché avant le match (vendredi), à défaut à la clôture.
    private static let colonnesMoyennes = [("AvgH", "AvgD", "AvgA"), ("BbAvH", "BbAvD", "BbAvA"), ("AvgCH", "AvgCD", "AvgCA")]
    /// Cotes Bwin avant le match, à défaut à la clôture.
    private static let colonnesBwin = [("BWH", "BWD", "BWA"), ("BWCH", "BWCD", "BWCA")]
    /// Cotes d'ouverture, relevées en même temps que la moyenne du marché.
    private static let colonnesOuverture = [("PSH", "PSD", "PSA"), ("B365H", "B365D", "B365A"), ("AvgH", "AvgD", "AvgA"),
                                            ("BbAvH", "BbAvD", "BbAvA")]

    /// Lit un CSV ; seules les lignes du championnat actif (F1, D1, E0, I1, SP1) sont gardées et la saison
    /// est déduite des dates (elle commence en juillet).
    static func lire(_ donnees: Data, nom: String, equipesConnues: [String]) throws -> Fichier {
        guard var texte = String(data: donnees, encoding: .utf8) ?? String(data: donnees, encoding: .isoLatin1) else {
            throw Erreur(message: "\(nom) : fichier illisible.")
        }
        if texte.first == "\u{FEFF}" { texte.removeFirst() }
        let lignes = texte.split(whereSeparator: \.isNewline)
        guard let entete = lignes.first else { throw Erreur(message: "\(nom) : fichier vide.") }
        let colonnes = champs(entete)
        func index(_ noms: String...) -> Int? { noms.lazy.compactMap { colonnes.firstIndex(of: $0) }.first }
        guard let iDate = index("Date"), let iDom = index("HomeTeam", "Home"), let iExt = index("AwayTeam", "Away") else {
            throw Erreur(message: "\(nom) n'est pas un CSV de football-data.co.uk (colonnes Date, HomeTeam et "
                         + "AwayTeam attendues).")
        }
        let iDiv = index("Div")
        let iButsDom = index("FTHG", "HG"), iButsExt = index("FTAG", "AG")
        func groupes(_ liste: [(String, String, String)]) -> [[Int]] {
            liste.compactMap { g in
                guard let a = index(g.0), let b = index(g.1), let c = index(g.2) else { return nil }
                return [a, b, c]
            }
        }
        let reference = groupes(colonnesCotes), moyennes = groupes(colonnesMoyennes), bwin = groupes(colonnesBwin)
        let ouverture = groupes(colonnesOuverture)

        var matchs: [LigneMatch] = []
        var debuts: [Int: Int] = [:]
        var autresDivisions = Set<String>()
        for ligne in lignes.dropFirst() {
            let c = champs(ligne)
            func champ(_ i: Int?) -> String { i.flatMap { $0 < c.count ? c[$0] : nil } ?? "" }
            if !champ(iDiv).isEmpty, champ(iDiv) != Championnat.actif.codeCSV {
                autresDivisions.insert(champ(iDiv))
                continue
            }
            guard let date = date(champ(iDate)), !champ(iDom).isEmpty, !champ(iExt).isEmpty else { continue }
            let buts = Int(champ(iButsDom)).flatMap { h in Int(champ(iButsExt)).map { (domicile: h, exterieur: $0) } }
            func premieres(_ g: [[Int]]) -> [Double]? {
                g.lazy.map { $0.compactMap { Double(champ($0)) } }
                    .first { $0.count == 3 && $0.allSatisfy { $0 > 1 && $0 < Limites.cote } }
            }
            let p = date.split(separator: "-").compactMap { Int($0) }
            debuts[p[1] >= 7 ? p[0] : p[0] - 1, default: 0] += 1
            matchs.append(LigneMatch(date: date, domicile: nomClub(champ(iDom), connus: equipesConnues),
                                     exterieur: nomClub(champ(iExt), connus: equipesConnues), buts: buts,
                                     cotes: premieres(reference), cotesMoyennes: premieres(moyennes),
                                     cotesBwin: premieres(bwin), cotesOuverture: premieres(ouverture)))
        }
        guard let debut = debuts.max(by: { ($0.value, $0.key) < ($1.value, $1.key) })?.key else {
            if !autresDivisions.isEmpty {
                throw Erreur(message: "\(nom) : aucun match de \(Championnat.actif.nom) (\(Championnat.actif.codeCSV)), seulement "
                             + "\(autresDivisions.sorted().joined(separator: ", ")).")
            }
            throw Erreur(message: "\(nom) : aucun match.")
        }
        return Fichier(nom: nom, saison: String(format: "%d-%02d", debut, (debut + 1) % 100), matchs: matchs)
    }

    /// Nom affiché d'un club : nom identique, table de correspondance, puis
    /// seul club connu dont le nom contient tous les mots (« Rodez » → « Rodez AF »).
    static func nomClub(_ brut: String, connus: [String]) -> String {
        if connus.contains(brut) { return brut }
        let nom = clubs[brut] ?? brut
        if connus.contains(nom) { return nom }
        let mots = Set(normalise(nom))
        let candidats = connus.filter { mots.isSubset(of: Set(normalise($0))) }
        return candidats.count == 1 ? candidats[0] : nom
    }

    private static func normalise(_ nom: String) -> [String] {
        nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0 == "st" ? "saint" : String($0) }
    }

    /// « 07/08/15 » ou « 07/08/2015 » → « 2015-08-07 ».
    private static func date(_ texte: String) -> String? {
        if Jour.depuisISO(texte) != nil { return texte }
        let p = texte.split(separator: "/").map { Int($0) }
        guard p.count == 3, let j = p[0], let m = p[1], var a = p[2],
              (1...12).contains(m), (1...31).contains(j) else { return nil }
        if a < 100 { a += 2000 }
        return String(format: "%04d-%02d-%02d", a, m, j)
    }

    /// Champs d'une ligne CSV (guillemets tolérés).
    private static func champs(_ ligne: Substring) -> [String] {
        var resultat: [String] = []
        var courant = ""
        var entreGuillemets = false
        for c in ligne {
            if c == "\"" { entreGuillemets.toggle() }
            else if c == ",", !entreGuillemets {
                resultat.append(courant.trimmingCharacters(in: .whitespaces))
                courant = ""
            } else { courant.append(c) }
        }
        resultat.append(courant.trimmingCharacters(in: .whitespaces))
        return resultat
    }
}

// MARK: - Saison en cours d'après les CSV

/// Numéros de journée : les CSV n'en donnent pas.
/// - Matchs datés (joués ou programmés), dans l'ordre chronologique : première
///   journée où aucune des deux équipes n'a encore joué. Un match reporté
///   retrouve ainsi sa journée d'origine.
/// - Matchs sans date : répartis sur les journées libres de chaque équipe par
///   recherche locale (« min-conflicts », graine fixe : résultat reproductible).
///   Faute de solution en 2 × (N − 1) journées, les derniers passent après.
enum Calendrier {
    struct Rencontre {
        let domicile: String
        let exterieur: String
        let date: String?
    }

    static func journees(_ rencontres: [Rencontre], equipes: [String], iterationsMax: Int = 200_000) -> [Int] {
        let total = max(2 * (equipes.count - 1), 1)
        var occupees: [String: Set<Int>] = [:]
        var resultat = [Int](repeating: 0, count: rencontres.count)

        let datees = rencontres.indices.filter { rencontres[$0].date != nil }
            .sorted { (rencontres[$0].date ?? "", rencontres[$0].domicile) < (rencontres[$1].date ?? "", rencontres[$1].domicile) }
        for k in datees {
            let h = rencontres[k].domicile, a = rencontres[k].exterieur
            var j = 1
            while occupees[h, default: []].contains(j) || occupees[a, default: []].contains(j) { j += 1 }
            occupees[h, default: []].insert(j)
            occupees[a, default: []].insert(j)
            resultat[k] = j
        }

        let libres = rencontres.indices.filter { rencontres[$0].date == nil }
            .sorted { (rencontres[$0].domicile, rencontres[$0].exterieur) < (rencontres[$1].domicile, rencontres[$1].exterieur) }
        guard !libres.isEmpty else { return resultat }

        // Matchs sans date par équipe et par journée.
        var charge: [String: [Int]] = [:]
        func ajouter(_ k: Int, _ d: Int) {
            charge[rencontres[k].domicile, default: [Int](repeating: 0, count: total + 1)][resultat[k]] += d
            charge[rencontres[k].exterieur, default: [Int](repeating: 0, count: total + 1)][resultat[k]] += d
        }
        func cout(_ k: Int, _ j: Int) -> Int {
            let h = rencontres[k].domicile, a = rencontres[k].exterieur
            let pris = (occupees[h, default: []].contains(j) ? 1 : 0) + (occupees[a, default: []].contains(j) ? 1 : 0)
            return (charge[h]?[j] ?? 0) + (charge[a]?[j] ?? 0) + 2 * pris
        }
        func enConflit(_ k: Int) -> Bool {
            let h = rencontres[k].domicile, a = rencontres[k].exterieur, j = resultat[k]
            return (charge[h]?[j] ?? 0) > 1 || (charge[a]?[j] ?? 0) > 1
                || occupees[h, default: []].contains(j) || occupees[a, default: []].contains(j)
        }

        for k in libres {
            resultat[k] = (1...total).min { cout(k, $0) < cout(k, $1) } ?? 1
            ajouter(k, 1)
        }
        var alea = GenerateurAleatoire(graine: 1)
        for _ in 0..<iterationsMax {
            let conflits = libres.filter(enConflit)
            guard !conflits.isEmpty else { return resultat }
            let k = conflits[Int(alea.next() % UInt64(conflits.count))]
            ajouter(k, -1)
            if alea.uniforme() < 0.1 {
                resultat[k] = 1 + Int(alea.next() % UInt64(total))
            } else {
                let couts = (1...total).map { cout(k, $0) }
                let minimum = couts.min() ?? 0
                let meilleures = (1...total).filter { couts[$0 - 1] == minimum }
                resultat[k] = meilleures[Int(alea.next() % UInt64(meilleures.count))]
            }
            ajouter(k, 1)
        }

        // Pas de solution : les matchs en conflit prennent la première journée libre, au-delà s'il le faut.
        let enTrop = libres.filter(enConflit)
        for k in enTrop { ajouter(k, -1) }
        for k in libres where !enTrop.contains(k) {
            occupees[rencontres[k].domicile, default: []].insert(resultat[k])
            occupees[rencontres[k].exterieur, default: []].insert(resultat[k])
        }
        for k in enTrop {
            let h = rencontres[k].domicile, a = rencontres[k].exterieur
            var j = 1
            while occupees[h, default: []].contains(j) || occupees[a, default: []].contains(j) { j += 1 }
            occupees[h, default: []].insert(j)
            occupees[a, default: []].insert(j)
            resultat[k] = j
        }
        return resultat
    }
}

// MARK: - Cotes en ligne (The Odds API)

/// Cotes 1/N/2 de Winamax, Unibet et Betclic (France) des matchs à venir, via
/// The Odds API (clé gratuite : 500 crédits par mois, 1 par téléchargement).
/// Bwin n'y figure pas : sa cote vient du CSV de football-data.co.uk.
enum CotesEnLigne {
    static let site = URL(string: "https://the-odds-api.com/#get-access")!
    static let livres: [String: Bookmaker] = ["winamax_fr": .winamax, "unibet_fr": .unibet, "betclic_fr": .betclic]

    /// Une clé est alphanumérique ; rien d'autre n'entre dans l'URL.
    static func cleValide(_ cle: String) -> Bool {
        (1...100).contains(cle.count) && cle.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static func url(cle: String) -> URL? {
        guard cleValide(cle) else { return nil }
        var c = URLComponents(string: "https://api.the-odds-api.com/v4/sports/\(Championnat.actif.cleCotes)/odds/")
        c?.queryItems = [
            URLQueryItem(name: "apiKey", value: cle),
            URLQueryItem(name: "bookmakers", value: livres.keys.sorted().joined(separator: ",")),
            URLQueryItem(name: "markets", value: "h2h"),
            URLQueryItem(name: "oddsFormat", value: "decimal")
        ]
        return c?.url
    }

    /// Une rencontre, avec les cotes de chaque bookmaker trouvé.
    struct Rencontre {
        let domicile: String
        let exterieur: String
        let cotes: [Bookmaker: [Double]]
    }

    private struct Evenement: Decodable {
        let domicile: String
        let exterieur: String
        let bookmakers: [Livre]
        enum CodingKeys: String, CodingKey { case domicile = "home_team", exterieur = "away_team", bookmakers }
    }
    private struct Livre: Decodable {
        let key: String
        let markets: [Marche]
    }
    private struct Marche: Decodable {
        let key: String
        let outcomes: [Issue]
    }
    private struct Issue: Decodable {
        let name: String
        let price: Double
    }

    /// Réponse de l'API → rencontres aux noms de la saison ; `inconnus` : clubs
    /// que la table ne permet pas de reconnaître.
    static func lire(_ donnees: Data, equipes: [String]) throws -> (rencontres: [Rencontre], inconnus: [String]) {
        let evenements = try JSONDecoder().decode([Evenement].self, from: donnees)
        var rencontres: [Rencontre] = []
        var inconnus = Set<String>()
        for e in evenements {
            let h = equipe(e.domicile, parmi: equipes), a = equipe(e.exterieur, parmi: equipes)
            if h == nil { inconnus.insert(e.domicile) }
            if a == nil { inconnus.insert(e.exterieur) }
            guard let h, let a else { continue }
            var cotes: [Bookmaker: [Double]] = [:]
            for l in e.bookmakers {
                guard let b = livres[l.key], let m = l.markets.first(where: { $0.key == "h2h" }) else { continue }
                func prix(_ nom: String) -> Double? { m.outcomes.first { $0.name == nom }?.price }
                guard let c1 = prix(e.domicile), let cn = prix("Draw"), let c2 = prix(e.exterieur) else { continue }
                let c = [c1, cn, c2]
                if c.allSatisfy({ $0.isFinite && $0 > 1 && $0 < Limites.cote }) { cotes[b] = c }
            }
            if !cotes.isEmpty { rencontres.append(Rencontre(domicile: h, exterieur: a, cotes: cotes)) }
        }
        return (rencontres, inconnus.sorted())
    }

    /// Nom de l'API → équipe de la saison : mêmes mots significatifs que son nom
    /// affiché ou que son nom football-data.co.uk, sinon mots inclus dans un seul.
    static func equipe(_ brut: String, parmi equipes: [String]) -> String? {
        let cible = mots(brut)
        guard !cible.isEmpty else { return nil }
        let formes = equipes.map { e in
            // Le nom enregistré peut être l'ancienne graphie football-data (« Espanol ») : son nom
            // affiché actuel (« Espanyol ») compte aussi.
            (e, ([mots(e)] + FootballData.clubs.filter { $0.value == e }.map { mots($0.key) }
                 + (FootballData.clubs[e].map { [mots($0)] } ?? [])).filter { !$0.isEmpty })
        }
        let exacts = formes.filter { $0.1.contains(cible) }.map(\.0)
        if exacts.count == 1 { return exacts[0] }
        let proches = formes.filter { $0.1.contains { $0.isSubset(of: cible) || cible.isSubset(of: $0) } }.map(\.0)
        return proches.count == 1 ? proches[0] : nil
    }

    private static let motsVides: Set<String> = ["fc", "as", "ac", "sc", "rc", "ogc", "aj", "sco", "osc", "sm", "ea",
                                                  "hsc", "fco", "de", "du", "olympique", "stade", "club", "foot"]

    private static func mots(_ nom: String) -> Set<String> {
        Set(nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { $0 == "st" ? "saint" : String($0) })
            .subtracting(motsVides)
    }
}

extension Ligue {
    /// Saison construite, ou mise à jour, d'après les CSV : toutes les
    /// rencontres aller-retour, avec date, score et cotes de référence quand le
    /// CSV les donne. D'une mise à jour à l'autre (`existante` : la même
    /// saison), la saisie est conservée : cotes des bookmakers, xG, minutes,
    /// forfait, probabilités figées, score saisi d'un match que le CSV n'a pas
    /// encore. Un score du CSV remplace le score saisi.
    static func depuisCSV(saison: String, lignes: [FootballData.LigneMatch], existante: Ligue?) throws -> Ligue {
        // Un match joué l'emporte sur sa programmation (fixtures.csv).
        var parPaire: [String: FootballData.LigneMatch] = [:]
        for l in lignes where l.buts == nil { parPaire["\(l.domicile)|\(l.exterieur)"] = l }
        for l in lignes where l.buts != nil { parPaire["\(l.domicile)|\(l.exterieur)"] = l }

        let noms = Set(lignes.flatMap { [$0.domicile, $0.exterieur] })
        if let existante {
            let inconnues = noms.subtracting(existante.equipes)
            guard inconnues.isEmpty else {
                throw FootballData.Erreur(message: "Saison \(saison) : \(inconnues.sorted().joined(separator: ", ")) "
                                          + "absent(s) des équipes de la saison en cours.")
            }
        } else {
            guard noms.count >= 16, noms.count % 2 == 0 else {
                throw FootballData.Erreur(message: "Saison \(saison) incomplète : \(noms.count) équipes seulement. "
                                          + "Importez le CSV de la saison, ou fixtures.csv de sa 1re journée.")
            }
        }
        let equipes = existante?.equipes ?? noms.sorted()
        var anciens: [String: Match] = [:]
        for m in existante?.matches ?? [] { anciens["\(m.domicile)|\(m.exterieur)"] = m }

        var matchs: [Match] = []
        for h in equipes {
            for a in equipes where a != h {
                let cle = "\(h)|\(a)"
                var m = anciens[cle] ?? Match(journee: 1, domicile: h, exterieur: a)
                if let l = parPaire[cle] {
                    m.date = l.date
                    if let c = l.cotes { m.cotesReference = c }
                    if let c = l.cotesMoyennes { m.cotesMoyennes = c }
                    if let c = l.cotesOuverture { m.cotesOuverture = c }
                    // Cote saisie à la main conservée ; sinon celle du CSV.
                    if let c = l.cotesBwin, m.cotes[.bwin] == nil { m.cotes[.bwin] = c }
                    if let b = l.buts {
                        m.butsDomicile = b.domicile
                        m.butsExterieur = b.exterieur
                    }
                }
                matchs.append(m)
            }
        }
        // Calendrier officiel connu et complet : il prime sur le calcul d'après les dates, qui ne
        // peut deviner que les journées déjà datées (les autres seraient réparties au hasard).
        if let officiel = CalendrierOfficiel.journees(saison: saison, equipes: equipes),
           matchs.allSatisfy({ officiel["\($0.domicile)|\($0.exterieur)"] != nil }) {
            for i in matchs.indices { matchs[i].journee = officiel["\(matchs[i].domicile)|\(matchs[i].exterieur)"] ?? 1 }
        } else {
            let journees = Calendrier.journees(matchs.map { .init(domicile: $0.domicile, exterieur: $0.exterieur, date: $0.date) },
                                               equipes: equipes)
            for i in matchs.indices { matchs[i].journee = journees[i] }
        }
        matchs.sort { ($0.journee, $0.date ?? "9999", $0.domicile) < ($1.journee, $1.date ?? "9999", $1.domicile) }
        return Ligue(season: saison, teams: equipes.map { Equipe(name: $0) }, matches: matchs)
    }
}

// MARK: - Réglages de la simulation de paris (app_state.json)

struct Reglages: DocumentScelle, Equatable {
    static let fichier = FichierDonnees.reglages
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, Reglages> { \.reglages }

    static let defaut = Reglages()

    /// Espérance minimale (cote × probabilité) pour jouer un marché.
    var seuil = 1.07
    var coteMinDoubleChance = Paris.coteMinDoubleChanceDefaut
    var coteMin = Paris.coteMinDefaut
    var coteMax = Paris.coteMaxDefaut
    var miseFixe = Paris.miseFixeDefaut
    var bankrollDepart = Paris.bankrollDepartDefaut
    /// Probabilité des paris = poids × modèle + (1 − poids) × marché (cotes de
    /// référence, marge retirée). 1 : modèle seul ; 0 : marché seul, on ne parie
    /// que là où la meilleure cote dépasse la cote juste de Pinnacle.
    var poidsModele = 1.0
    /// Coup d'envoi de la saison (AAAA-MM-JJ) : date du premier match du CSV.
    /// Fixe la cadence des journées du modèle et sépare la saison de l'historique.
    var debutSaison = Reglages.debutProbable
    /// Nombre de saisons simulées par le Monte Carlo.
    var simulations = 8000
    /// Hyperparamètres calibrés sur l'historique ; nil tant qu'ils ne l'ont pas été.
    var parametresModele: ParametresModele?

    static let choixSimulations = [2000, 8000, 20000, 50000]

    /// 1er août de la saison en cours, avant tout CSV.
    static var debutProbable: String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
        let annee = (c.year ?? 2025) - ((c.month ?? 8) >= 7 ? 0 : 1)
        return "\(annee)-08-01"
    }

    /// Paramètres du modèle en service : calibrés, sinon valeurs de départ.
    var parametresEnService: ParametresModele { parametresModele ?? .depart }

    enum CodingKeys: String, CodingKey {
        case seuil = "threshold", coteMinDoubleChance = "dc_min_odds", coteMin = "min_odds"
        case coteMax = "max_odds", miseFixe = "fixed_stake_pct", bankrollDepart = "starting_bankroll"
        case debutSaison = "season_start", simulations = "n_simulations"
        case parametresModele = "model_params", poidsModele = "model_weight"
    }

    init() {}

    /// Une clé absente garde sa valeur par défaut.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Reglages.defaut
        seuil = try c.decodeIfPresent(Double.self, forKey: .seuil) ?? d.seuil
        coteMinDoubleChance = try c.decodeIfPresent(Double.self, forKey: .coteMinDoubleChance) ?? d.coteMinDoubleChance
        coteMin = try c.decodeIfPresent(Double.self, forKey: .coteMin) ?? d.coteMin
        coteMax = try c.decodeIfPresent(Double.self, forKey: .coteMax) ?? d.coteMax
        miseFixe = try c.decodeIfPresent(Double.self, forKey: .miseFixe) ?? d.miseFixe
        bankrollDepart = try c.decodeIfPresent(Double.self, forKey: .bankrollDepart) ?? d.bankrollDepart
        debutSaison = try c.decodeIfPresent(String.self, forKey: .debutSaison) ?? d.debutSaison
        simulations = try c.decodeIfPresent(Int.self, forKey: .simulations) ?? d.simulations
        parametresModele = try c.decodeIfPresent(ParametresModele.self, forKey: .parametresModele)
        poidsModele = try c.decodeIfPresent(Double.self, forKey: .poidsModele) ?? d.poidsModele
    }

    var jourDebutSaison: Int { Jour.depuisISO(debutSaison) ?? Jour.depuisISO(Reglages.defaut.debutSaison) ?? 0 }

    var resume: String {
        "espérance ≥ \(Format.nombre(seuil)) · cote \(Format.nombre(coteMin))–\(Format.nombre(coteMax)) · "
            + "double chance ≥ \(Format.nombre(coteMinDoubleChance)) · mise fixe \(Format.nombre(miseFixe * 100, decimales: 1)) % · "
            + "bankroll \(Format.euro(bankrollDepart)) · poids modèle \(Format.nombre(poidsModele, decimales: 2)) · "
            + "début \(debutSaison) · \(simulations) simulations"
            + (parametresModele.map { " · modèle \($0.resume)" } ?? "")
    }

    var lignes: [(cle: String, resume: String)] { [("Réglages", resume)] }

    func fusion(disque: Reglages, garder: [String: Bool]) -> Reglages {
        (garder["Réglages"] ?? true) ? disque : self
    }

    func valider() -> String? {
        let valeurs = [seuil, coteMinDoubleChance, coteMin, coteMax, miseFixe, bankrollDepart, poidsModele]
        guard valeurs.allSatisfy(\.isFinite) else { return "Réglage non numérique." }
        guard (1...2).contains(seuil), (1...20).contains(coteMin), (1...50).contains(coteMax),
              (1...10).contains(coteMinDoubleChance), (0...1).contains(miseFixe), (0...1).contains(poidsModele),
              bankrollDepart > 0, bankrollDepart < Limites.montant else { return "Réglage hors bornes." }
        guard Jour.depuisISO(debutSaison) != nil else { return "Date de début de saison invalide." }
        guard (100...200_000).contains(simulations) else { return "Nombre de simulations hors bornes." }
        guard parametresModele?.valide ?? true else { return "Paramètres du modèle hors bornes." }
        return nil
    }
}

// MARK: - Dépôts / retraits, paris manuels et exclus

/// Mouvement de trésorerie simulé, appliqué avant les paris de sa journée.
struct Mouvement: ElementListe {
    static let fichier = FichierDonnees.mouvements
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, [Mouvement]> { \.mouvements }

    var journee: Int
    /// Négatif = retrait.
    var amount: Double
    var note: String = ""

    var resume: String {
        "J\(journee) · \(amount >= 0 ? "+" : "")\(Format.euro(amount))" + (note.isEmpty ? "" : " (\(note))")
    }
}

/// Marché forcé sur un match, même s'il n'a pas été retenu par la sélection automatique.
struct PariManuel: ElementListe {
    static let fichier = FichierDonnees.parisManuels
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, [PariManuel]> { \.parisManuels }

    var journee: Int
    var home: String
    var away: String
    var market: Marche

    var cleMatch: String { "\(journee)|\(home)|\(away)" }
    var resume: String { "J\(journee) · \(home) – \(away) · \(market.titre)" }
}

/// Marché écarté par l'utilisateur, même s'il aurait été sélectionné : l'inverse d'un pari manuel.
struct PariExclu: ElementListe {
    static let fichier = FichierDonnees.parisExclus
    static var chemin: ReferenceWritableKeyPath<Ligue1ViewModel, [PariExclu]> { \.parisExclus }

    var journee: Int
    var home: String
    var away: String
    var market: Marche

    var cleMatch: String { "\(journee)|\(home)|\(away)" }
    var resume: String { "J\(journee) · \(home) – \(away) · \(market.titre)" }
}

// MARK: - Dates

/// Jours civils numérotés (0 = 1970-01-01), sans fuseau horaire : les écarts en
/// jours du modèle sont ceux de `datetime.date` en Python.
enum Jour {
    /// Algorithme « days from civil » (calendrier grégorien proleptique).
    static func depuis(annee: Int, mois: Int, jour: Int) -> Int {
        let y = mois <= 2 ? annee - 1 : annee
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (mois + 9) % 12
        let doy = (153 * mp + 2) / 5 + jour - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func depuisISO(_ texte: String) -> Int? {
        let p = texte.split(separator: "-").map { Int($0) }
        guard p.count == 3, let a = p[0], let m = p[1], let j = p[2],
              (1...12).contains(m), (1...31).contains(j) else { return nil }
        return depuis(annee: a, mois: m, jour: j)
    }

    static func versISO(_ n: Int) -> String {
        let z = n + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let j = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let a = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return String(format: "%04d-%02d-%02d", a, m, j)
    }

    static func versDate(_ n: Int) -> Date {
        var c = DateComponents()
        let p = versISO(n).split(separator: "-").compactMap { Int($0) }
        c.year = p[0]; c.month = p[1]; c.day = p[2]; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }

    static func depuisDate(_ d: Date) -> Int {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d)
        return depuis(annee: c.year ?? 1970, mois: c.month ?? 1, jour: c.day ?? 1)
    }
}

enum Statistiques {
    /// Médiane, moyenne des deux valeurs centrales pour un effectif pair (`statistics.median`).
    static func mediane(_ v: [Double]) -> Double {
        let t = v.sorted()
        guard !t.isEmpty else { return 0 }
        let n = t.count
        return n % 2 == 1 ? t[n / 2] : (t[n / 2 - 1] + t[n / 2]) / 2
    }
}
