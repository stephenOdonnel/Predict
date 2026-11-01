//
//  CalendrierOfficiel.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Calendrier officiel des journées, saison par saison. Les CSV de
//  football-data.co.uk ne donnent ni numéro de journée ni les dates au-delà de
//  la semaine à venir : sans cette table, `Calendrier.journees` répartit les
//  matchs sans date au hasard (conflit-libre, mais pas le vrai calendrier).
//  Quand la saison est ici et couvre tous les matchs, ces numéros priment ;
//  un match reporté garde sa journée d'origine.
//
//  Ajouter une saison : une ligne « journée|domicile|extérieur » par match,
//  avec les noms affichés dans l'appli, puis l'inscrire dans `tables`.
//
import Foundation

enum CalendrierOfficiel {
    /// « domicile|exterieur » → numéro de journée, ou nil si la saison n'est pas connue.
    /// Les noms sont ramenés à ceux de `equipes` (ceux de la saison en cours dans l'appli) : une
    /// sauvegarde créée avec « Le Mans » trouve ainsi « Le Mans FC ». Un club de l'appli que le
    /// tableau ne reconnaît pas laisse ses matchs sans journée (l'appelant décide alors).
    static func journees(saison: String, equipes: [String]) -> [String: Int]? {
        guard let brut = lire(saison: saison) else { return nil }
        let officiels = Set(brut.keys.flatMap { $0.split(separator: "|").map(String.init) })
        var traduction: [String: String] = [:]   // nom officiel → nom dans l'appli
        for e in equipes {
            if officiels.contains(e) {
                traduction[e] = e
            } else if let o = CotesEnLigne.equipe(e, parmi: officiels.sorted()), traduction[o] == nil {
                traduction[o] = e
            }
        }
        var resultat: [String: Int] = [:]
        for (cle, j) in brut {
            let p = cle.split(separator: "|").map(String.init)
            guard p.count == 2, let h = traduction[p[0]], let a = traduction[p[1]] else { continue }
            resultat["\(h)|\(a)"] = j
        }
        return resultat
    }

    private static func lire(saison: String) -> [String: Int]? {
        guard saison == "2026-27" else { return nil }
        let texte: String
        switch Championnat.actif {
        case .ligue1:        texte = calendrier2627
        case .bundesliga:    texte = bundesliga2627
        case .premierLeague: texte = premierLeague2627
        case .serieA:        texte = serieA2627
        case .laLiga:        texte = laLiga2627
        }
        var resultat: [String: Int] = [:]
        for ligne in texte.split(separator: "\n") {
            let p = ligne.split(separator: "|", omittingEmptySubsequences: false)
            guard p.count == 3, let j = Int(p[0].trimmingCharacters(in: .whitespaces)) else { continue }
            resultat["\(p[1])|\(p[2])"] = j
        }
        return resultat
    }

    static let calendrier2627 = """
    1|Angers SCO|LOSC
    1|ESTAC Troyes|Paris FC
    1|Le Havre|AS Monaco
    1|Le Mans FC|Stade Brestois
    1|OGC Nice|FC Lorient
    1|Olympique de Marseille|RC Strasbourg
    1|Stade Rennais FC|Paris Saint Germain
    1|RC Lens|AJ Auxerre
    1|Toulouse FC|Olympique Lyonnais
    2|AJ Auxerre|Angers SCO
    2|AS Monaco|Olympique de Marseille
    2|FC Lorient|ESTAC Troyes
    2|LOSC|Paris Saint Germain
    2|Olympique Lyonnais|Le Havre
    2|Paris FC|OGC Nice
    2|RC Strasbourg|RC Lens
    2|Stade Brestois|Toulouse FC
    2|Stade Rennais FC|Le Mans FC
    3|Angers SCO|Stade Rennais FC
    3|ESTAC Troyes|RC Strasbourg
    3|Le Havre|Stade Brestois
    3|OGC Nice|Le Mans FC
    3|Olympique Lyonnais|AJ Auxerre
    3|Olympique de Marseille|Paris FC
    3|Paris Saint Germain|AS Monaco
    3|RC Lens|FC Lorient
    3|Toulouse FC|LOSC
    4|AJ Auxerre|OGC Nice
    4|FC Lorient|Toulouse FC
    4|LOSC|ESTAC Troyes
    4|Le Havre|Angers SCO
    4|Le Mans FC|RC Lens
    4|Paris FC|Olympique Lyonnais
    4|RC Strasbourg|AS Monaco
    4|Stade Brestois|Paris Saint Germain
    4|Stade Rennais FC|Olympique de Marseille
    5|AJ Auxerre|Stade Brestois
    5|AS Monaco|RC Lens
    5|Angers SCO|ESTAC Troyes
    5|Le Mans FC|FC Lorient
    5|OGC Nice|LOSC
    5|Olympique Lyonnais|Stade Rennais FC
    5|Olympique de Marseille|Paris Saint Germain
    5|Paris FC|RC Strasbourg
    5|Toulouse FC|Le Havre
    6|AS Monaco|Toulouse FC
    6|ESTAC Troyes|Olympique de Marseille
    6|FC Lorient|Paris FC
    6|LOSC|Le Havre
    6|OGC Nice|RC Strasbourg
    6|Paris Saint Germain|Le Mans FC
    6|RC Lens|Olympique Lyonnais
    6|Stade Brestois|Angers SCO
    6|Stade Rennais FC|AJ Auxerre
    7|Angers SCO|Olympique de Marseille
    7|ESTAC Troyes|RC Lens
    7|FC Lorient|AS Monaco
    7|LOSC|Stade Brestois
    7|Le Havre|AJ Auxerre
    7|Le Mans FC|Toulouse FC
    7|Olympique Lyonnais|OGC Nice
    7|Paris FC|Stade Rennais FC
    7|RC Strasbourg|Paris Saint Germain
    8|AJ Auxerre|Le Mans FC
    8|AS Monaco|LOSC
    8|Angers SCO|FC Lorient
    8|Olympique de Marseille|Le Havre
    8|Paris Saint Germain|Olympique Lyonnais
    8|RC Lens|Paris FC
    8|Stade Brestois|OGC Nice
    8|Stade Rennais FC|RC Strasbourg
    8|Toulouse FC|ESTAC Troyes
    9|ESTAC Troyes|Le Mans FC
    9|FC Lorient|Stade Brestois
    9|LOSC|RC Lens
    9|Le Havre|Paris Saint Germain
    9|OGC Nice|Stade Rennais FC
    9|Olympique Lyonnais|Angers SCO
    9|Olympique de Marseille|Toulouse FC
    9|Paris FC|AS Monaco
    9|RC Strasbourg|AJ Auxerre
    10|AJ Auxerre|Paris FC
    10|Angers SCO|OGC Nice
    10|Le Havre|FC Lorient
    10|Le Mans FC|AS Monaco
    10|Paris Saint Germain|ESTAC Troyes
    10|RC Lens|Olympique de Marseille
    10|Stade Brestois|Olympique Lyonnais
    10|Stade Rennais FC|LOSC
    10|Toulouse FC|RC Strasbourg
    11|AS Monaco|AJ Auxerre
    11|ESTAC Troyes|Le Havre
    11|FC Lorient|Stade Rennais FC
    11|LOSC|Olympique Lyonnais
    11|OGC Nice|Paris Saint Germain
    11|Olympique de Marseille|Le Mans FC
    11|Paris FC|Angers SCO
    11|RC Lens|Toulouse FC
    11|RC Strasbourg|Stade Brestois
    12|AJ Auxerre|Olympique de Marseille
    12|Angers SCO|RC Lens
    12|Le Havre|RC Strasbourg
    12|Le Mans FC|LOSC
    12|OGC Nice|ESTAC Troyes
    12|Olympique Lyonnais|AS Monaco
    12|Paris Saint Germain|FC Lorient
    12|Stade Brestois|Paris FC
    12|Toulouse FC|Stade Rennais FC
    13|AS Monaco|Angers SCO
    13|ESTAC Troyes|Olympique Lyonnais
    13|LOSC|AJ Auxerre
    13|Olympique de Marseille|OGC Nice
    13|Paris FC|Le Mans FC
    13|RC Lens|Le Havre
    13|RC Strasbourg|FC Lorient
    13|Stade Rennais FC|Stade Brestois
    13|Toulouse FC|Paris Saint Germain
    14|AJ Auxerre|Toulouse FC
    14|Angers SCO|RC Strasbourg
    14|FC Lorient|LOSC
    14|Le Havre|Le Mans FC
    14|OGC Nice|RC Lens
    14|Olympique Lyonnais|Olympique de Marseille
    14|Paris Saint Germain|Paris FC
    14|Stade Brestois|ESTAC Troyes
    14|Stade Rennais FC|AS Monaco
    15|AS Monaco|OGC Nice
    15|ESTAC Troyes|Stade Rennais FC
    15|FC Lorient|AJ Auxerre
    15|LOSC|RC Strasbourg
    15|Le Mans FC|Olympique Lyonnais
    15|Paris FC|Le Havre
    15|RC Lens|Paris Saint Germain
    15|Stade Brestois|Olympique de Marseille
    15|Toulouse FC|Angers SCO
    16|AJ Auxerre|ESTAC Troyes
    16|AS Monaco|Stade Brestois
    16|Angers SCO|Paris Saint Germain
    16|OGC Nice|Le Havre
    16|Olympique Lyonnais|FC Lorient
    16|Olympique de Marseille|LOSC
    16|Paris FC|Toulouse FC
    16|RC Strasbourg|Le Mans FC
    16|Stade Rennais FC|RC Lens
    17|ESTAC Troyes|AS Monaco
    17|FC Lorient|Olympique de Marseille
    17|LOSC|Paris FC
    17|Le Havre|Stade Rennais FC
    17|Le Mans FC|Angers SCO
    17|Paris Saint Germain|AJ Auxerre
    17|RC Lens|Stade Brestois
    17|RC Strasbourg|Olympique Lyonnais
    17|Toulouse FC|OGC Nice
    18|AS Monaco|Paris Saint Germain
    18|Angers SCO|Le Havre
    18|Le Mans FC|OGC Nice
    18|Olympique Lyonnais|LOSC
    18|Olympique de Marseille|ESTAC Troyes
    18|Paris FC|AJ Auxerre
    18|Stade Brestois|RC Strasbourg
    18|Stade Rennais FC|FC Lorient
    18|Toulouse FC|RC Lens
    19|AJ Auxerre|AS Monaco
    19|ESTAC Troyes|LOSC
    19|FC Lorient|Le Mans FC
    19|Le Havre|Toulouse FC
    19|OGC Nice|Stade Brestois
    19|Paris Saint Germain|Olympique de Marseille
    19|RC Lens|Angers SCO
    19|RC Strasbourg|Paris FC
    19|Stade Rennais FC|Olympique Lyonnais
    20|AJ Auxerre|RC Strasbourg
    20|FC Lorient|Le Havre
    20|LOSC|OGC Nice
    20|Le Mans FC|Paris Saint Germain
    20|Olympique Lyonnais|RC Lens
    20|Olympique de Marseille|Angers SCO
    20|Paris FC|ESTAC Troyes
    20|Stade Brestois|Stade Rennais FC
    20|Toulouse FC|AS Monaco
    21|AS Monaco|Le Mans FC
    21|Angers SCO|Paris FC
    21|LOSC|FC Lorient
    21|Le Havre|Olympique Lyonnais
    21|OGC Nice|AJ Auxerre
    21|Paris Saint Germain|Stade Brestois
    21|RC Lens|ESTAC Troyes
    21|RC Strasbourg|Olympique de Marseille
    21|Stade Rennais FC|Toulouse FC
    22|AJ Auxerre|LOSC
    22|ESTAC Troyes|OGC Nice
    22|FC Lorient|Angers SCO
    22|Le Mans FC|Paris FC
    22|Olympique Lyonnais|Toulouse FC
    22|Olympique de Marseille|Stade Rennais FC
    22|Paris Saint Germain|RC Lens
    22|RC Strasbourg|Le Havre
    22|Stade Brestois|AS Monaco
    23|AS Monaco|Olympique Lyonnais
    23|Angers SCO|AJ Auxerre
    23|ESTAC Troyes|FC Lorient
    23|LOSC|Olympique de Marseille
    23|Le Havre|OGC Nice
    23|Paris FC|Stade Brestois
    23|RC Lens|RC Strasbourg
    23|Paris Saint Germain|Stade Rennais FC
    23|Toulouse FC|Le Mans FC
    24|AJ Auxerre|Paris Saint Germain
    24|Le Havre|RC Lens
    24|Le Mans FC|Stade Rennais FC
    24|OGC Nice|Toulouse FC
    24|Olympique Lyonnais|ESTAC Troyes
    24|Olympique de Marseille|AS Monaco
    24|Paris FC|FC Lorient
    24|RC Strasbourg|Angers SCO
    24|Stade Brestois|LOSC
    25|AS Monaco|Le Havre
    25|Angers SCO|Le Mans FC
    25|ESTAC Troyes|AJ Auxerre
    25|FC Lorient|OGC Nice
    25|Olympique de Marseille|Olympique Lyonnais
    25|Paris Saint Germain|RC Strasbourg
    25|RC Lens|LOSC
    25|Stade Rennais FC|Paris FC
    25|Toulouse FC|Stade Brestois
    26|AJ Auxerre|RC Lens
    26|Angers SCO|AS Monaco
    26|LOSC|Stade Rennais FC
    26|Le Havre|ESTAC Troyes
    26|Le Mans FC|Olympique de Marseille
    26|OGC Nice|Olympique Lyonnais
    26|Paris FC|Paris Saint Germain
    26|RC Strasbourg|Toulouse FC
    26|Stade Brestois|FC Lorient
    27|AS Monaco|Stade Rennais FC
    27|ESTAC Troyes|Angers SCO
    27|FC Lorient|RC Lens
    27|LOSC|Toulouse FC
    27|Le Mans FC|AJ Auxerre
    27|OGC Nice|Paris FC
    27|Olympique Lyonnais|RC Strasbourg
    27|Olympique de Marseille|Stade Brestois
    27|Paris Saint Germain|Le Havre
    28|AJ Auxerre|FC Lorient
    28|AS Monaco|RC Strasbourg
    28|Angers SCO|Olympique Lyonnais
    28|Le Havre|Olympique de Marseille
    28|Paris Saint Germain|LOSC
    28|RC Lens|OGC Nice
    28|Stade Brestois|Le Mans FC
    28|Stade Rennais FC|ESTAC Troyes
    28|Toulouse FC|Paris FC
    29|ESTAC Troyes|Toulouse FC
    29|FC Lorient|Paris Saint Germain
    29|LOSC|AS Monaco
    29|Le Mans FC|Le Havre
    29|OGC Nice|Angers SCO
    29|Olympique Lyonnais|Stade Brestois
    29|Olympique de Marseille|AJ Auxerre
    29|Paris FC|RC Lens
    29|RC Strasbourg|Stade Rennais FC
    30|AJ Auxerre|Olympique Lyonnais
    30|AS Monaco|FC Lorient
    30|ESTAC Troyes|Stade Brestois
    30|Le Havre|Paris FC
    30|Paris Saint Germain|Angers SCO
    30|RC Lens|Le Mans FC
    30|RC Strasbourg|LOSC
    30|Stade Rennais FC|OGC Nice
    30|Toulouse FC|Olympique de Marseille
    31|Angers SCO|Toulouse FC
    31|FC Lorient|RC Strasbourg
    31|Le Mans FC|ESTAC Troyes
    31|OGC Nice|Olympique de Marseille
    31|Olympique Lyonnais|Paris Saint Germain
    31|Paris FC|LOSC
    31|RC Lens|AS Monaco
    31|Stade Brestois|AJ Auxerre
    31|Stade Rennais FC|Le Havre
    32|AJ Auxerre|Stade Rennais FC
    32|AS Monaco|Paris FC
    32|LOSC|Angers SCO
    32|Olympique Lyonnais|Le Mans FC
    32|Olympique de Marseille|RC Lens
    32|Paris Saint Germain|OGC Nice
    32|RC Strasbourg|ESTAC Troyes
    32|Stade Brestois|Le Havre
    32|Toulouse FC|FC Lorient
    33|Angers SCO|Stade Brestois
    33|ESTAC Troyes|Paris Saint Germain
    33|FC Lorient|Olympique Lyonnais
    33|Le Havre|LOSC
    33|Le Mans FC|RC Strasbourg
    33|OGC Nice|AS Monaco
    33|Paris FC|Olympique de Marseille
    33|RC Lens|Stade Rennais FC
    33|Toulouse FC|AJ Auxerre
    34|AJ Auxerre|Le Havre
    34|AS Monaco|ESTAC Troyes
    34|LOSC|Le Mans FC
    34|Olympique Lyonnais|Paris FC
    34|Olympique de Marseille|FC Lorient
    34|Paris Saint Germain|Toulouse FC
    34|RC Strasbourg|OGC Nice
    34|Stade Brestois|RC Lens
    34|Stade Rennais FC|Angers SCO
    """
}
