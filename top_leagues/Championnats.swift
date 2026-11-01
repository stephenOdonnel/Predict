//
//  Championnats.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Les cinq championnats gérés et tout ce qui les distingue : code football-data,
//  adresses (football-data, Understat, The Odds API), table des noms de clubs,
//  dossier de données. Le reste du code est le même pour tous.
//
//  `Championnat.actif` est le championnat affiché ; seul le ViewModel le change
//  (`changerChampionnat`), sur le fil principal. Les fonctions de lecture
//  (FootballData, XgEnLigne, CotesEnLigne, CalendrierOfficiel) s'y réfèrent.
//
import Foundation

enum Championnat: String, CaseIterable, Identifiable, Codable {
    case ligue1, bundesliga, premierLeague, serieA, laLiga

    static var actif: Championnat = .ligue1

    var id: String { rawValue }

    /// Nom affiché.
    var nom: String {
        switch self {
        case .ligue1:        return "Ligue 1"
        case .bundesliga:    return "Bundesliga"
        case .premierLeague: return "Premier League"
        case .serieA:        return "Serie A"
        case .laLiga:        return "Liga"
        }
    }

    /// Pastille d'identification dans les menus.
    var drapeau: String {
        switch self {
        case .ligue1:        return "🇫🇷"
        case .bundesliga:    return "🇩🇪"
        case .premierLeague: return "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
        case .serieA:        return "🇮🇹"
        case .laLiga:        return "🇪🇸"
        }
    }

    /// Sous-dossier de ~/Documents/Predict.
    var dossier: String { rawValue }

    /// Colonne « Div » des CSV football-data, et nom des fichiers (F1.csv, D1.csv…).
    var codeCSV: String {
        switch self {
        case .ligue1:        return "F1"
        case .bundesliga:    return "D1"
        case .premierLeague: return "E0"
        case .serieA:        return "I1"
        case .laLiga:        return "SP1"
        }
    }

    /// Page « saisons passées » de football-data.co.uk.
    var pageFootballData: URL {
        let page: String
        switch self {
        case .ligue1:        page = "francem"
        case .bundesliga:    page = "germanym"
        case .premierLeague: page = "englandm"
        case .serieA:        page = "italym"
        case .laLiga:        page = "spainm"
        }
        return URL(string: "https://www.football-data.co.uk/\(page).php")!
    }

    /// Identifiant du championnat dans l'adresse Understat.
    var codeUnderstat: String {
        switch self {
        case .ligue1:        return "Ligue_1"
        case .bundesliga:    return "Bundesliga"
        case .premierLeague: return "EPL"
        case .serieA:        return "Serie_A"
        case .laLiga:        return "La_liga"
        }
    }

    /// Identifiant du championnat chez The Odds API.
    var cleCotes: String {
        switch self {
        case .ligue1:        return "soccer_france_ligue_one"
        case .bundesliga:    return "soccer_germany_bundesliga"
        case .premierLeague: return "soccer_epl"
        case .serieA:        return "soccer_italy_serie_a"
        case .laLiga:        return "soccer_spain_la_liga"
        }
    }

    /// Noms football-data (et variantes Understat / The Odds API) → noms affichés,
    /// qui sont ceux du calendrier officiel. Un club absent de la table garde son
    /// nom d'origine ; le rapprochement par mots (`FootballData.nomClub`) fait le reste.
    var clubs: [String: String] { Self.tablesClubs[self] ?? [:] }

    private static let tablesClubs: [Championnat: [String: String]] = [
        .ligue1: [
            "Paris SG": "Paris Saint Germain", "Marseille": "Olympique de Marseille", "Lyon": "Olympique Lyonnais",
            "Monaco": "AS Monaco", "Lille": "LOSC", "Nice": "OGC Nice", "Rennes": "Stade Rennais FC", "Lens": "RC Lens",
            "Strasbourg": "RC Strasbourg", "Brest": "Stade Brestois", "Nantes": "FC Nantes", "Toulouse": "Toulouse FC",
            "Lorient": "FC Lorient", "Metz": "FC Metz", "Auxerre": "AJ Auxerre", "Angers": "Angers SCO",
            "Le Havre": "Le Havre", "Le Mans": "Le Mans FC", "Paris FC": "Paris FC", "Reims": "Stade de Reims",
            "Montpellier": "Montpellier HSC", "St Etienne": "AS Saint-Etienne", "Bordeaux": "Girondins de Bordeaux",
            "Nimes": "Nîmes Olympique", "Dijon": "Dijon FCO", "Amiens": "Amiens SC", "Caen": "SM Caen",
            "Guingamp": "EA Guingamp", "Bastia": "SC Bastia", "Nancy": "AS Nancy-Lorraine", "Troyes": "ESTAC Troyes",
            "Clermont": "Clermont Foot", "Ajaccio": "AC Ajaccio", "Ajaccio GFCO": "GFC Ajaccio",
            "Evian Thonon Gaillard": "Évian TG", "Sochaux": "FC Sochaux", "Valenciennes": "Valenciennes FC"
        ],
        .bundesliga: [
            "Bayern Munich": "FC Bayern München", "Dortmund": "Borussia Dortmund", "Leverkusen": "Bayer 04 Leverkusen",
            "Ein Frankfurt": "Eintracht Frankfurt", "M'gladbach": "Borussia Mönchengladbach",
            "Borussia M.Gladbach": "Borussia Mönchengladbach", "Stuttgart": "VfB Stuttgart", "Hoffenheim": "TSG Hoffenheim",
            "Freiburg": "Sport-Club Freiburg", "SC Freiburg": "Sport-Club Freiburg", "Werder Bremen": "SV Werder Bremen",
            "Mainz": "1. FSV Mainz 05", "Augsburg": "FC Augsburg", "Union Berlin": "1. FC Union Berlin",
            "FC Koln": "1. FC Köln", "FC Cologne": "1. FC Köln", "Koln": "1. FC Köln", "Hamburg": "Hamburger SV",
            "Schalke 04": "FC Schalke 04", "Paderborn": "SC Paderborn 07", "Elversberg": "SV Elversberg",
            "RasenBallsport Leipzig": "RB Leipzig", "Leipzig": "RB Leipzig"
        ],
        .premierLeague: [
            "Man City": "Manchester City", "Man United": "Manchester United", "Nott'm Forest": "Nottingham Forest",
            "Newcastle United": "Newcastle", "Hull": "Hull City", "Spurs": "Tottenham", "Leeds United": "Leeds",
            "Ipswich Town": "Ipswich", "Coventry City": "Coventry", "Brighton and Hove Albion": "Brighton"
        ],
        .serieA: [
            "Milan": "AC Milan", "Roma": "AS Roma", "Inter Milan": "Inter", "Internazionale": "Inter",
            "Parma Calcio 1913": "Parma", "Hellas Verona": "Verona"
        ],
        .laLiga: [
            "Ath Madrid": "Atletico Madrid", "Ath Bilbao": "Athletic Club", "Athletic Bilbao": "Athletic Club",
            "Betis": "Real Betis", "Sociedad": "Real Sociedad", "Celta": "Celta Vigo", "Vallecano": "Rayo Vallecano",
            "La Coruna": "Deportivo La Coruna", "Santander": "Racing Santander", "Alavés": "Alaves", "Málaga": "Malaga",
            "Deportivo Alaves": "Alaves",
            "Espanol": "Espanyol"
        ]
    ]
}

/// État d'un championnat en une ligne, gardé entre deux lancements pour la vue
/// d'ensemble (sans avoir à charger les autres championnats).
struct ResumeChampionnat: Codable, Equatable {
    var saison: String
    var matchsJoues: Int
    var matchsTotal: Int
    var bankrollDepart: Double
    var fixe: Double
    var kelly: Double
    var demiKelly: Double
    var quartKelly: Double
    var parisRegles: Int
    var parisEnAttente: Int
    var date: Date

    static let cle = "resumesChampionnats"

    static func lireTous() -> [String: ResumeChampionnat] {
        guard let data = UserDefaults.standard.data(forKey: cle),
              let r = try? JSONDecoder().decode([String: ResumeChampionnat].self, from: data) else { return [:] }
        return r
    }

    static func ecrire(_ tous: [String: ResumeChampionnat]) {
        if let data = try? JSONEncoder().encode(tous) { UserDefaults.standard.set(data, forKey: cle) }
    }
}
