//
//  CalendrierOfficielAutres.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Calendriers officiels 2026-27 de la Bundesliga (DFL), de la Premier League,
//  de la Serie A et de la Liga (matchesio.com) : « journée|domicile|extérieur ».
//  Les noms sont ceux affichés dans l'appli (voir `Championnat.clubs`).
//
import Foundation

extension CalendrierOfficiel {
    static let bundesliga2627 = """
    1|1. FC Köln|TSG Hoffenheim
    1|1. FC Union Berlin|Eintracht Frankfurt
    1|1. FSV Mainz 05|SC Paderborn 07
    1|Borussia Dortmund|Hamburger SV
    1|FC Augsburg|FC Schalke 04
    1|FC Bayern München|VfB Stuttgart
    1|RB Leipzig|Borussia Mönchengladbach
    1|SV Elversberg|Bayer 04 Leverkusen
    1|Sport-Club Freiburg|SV Werder Bremen
    2|Bayer 04 Leverkusen|1. FC Union Berlin
    2|Borussia Mönchengladbach|SV Elversberg
    2|Eintracht Frankfurt|FC Augsburg
    2|FC Schalke 04|FC Bayern München
    2|Hamburger SV|1. FSV Mainz 05
    2|SC Paderborn 07|Sport-Club Freiburg
    2|SV Werder Bremen|RB Leipzig
    2|TSG Hoffenheim|Borussia Dortmund
    2|VfB Stuttgart|1. FC Köln
    3|1. FC Köln|SV Werder Bremen
    3|1. FC Union Berlin|FC Schalke 04
    3|1. FSV Mainz 05|Eintracht Frankfurt
    3|Borussia Dortmund|SC Paderborn 07
    3|FC Augsburg|Bayer 04 Leverkusen
    3|RB Leipzig|Hamburger SV
    3|SV Elversberg|FC Bayern München
    3|Sport-Club Freiburg|Borussia Mönchengladbach
    3|TSG Hoffenheim|VfB Stuttgart
    4|Bayer 04 Leverkusen|RB Leipzig
    4|Borussia Mönchengladbach|1. FSV Mainz 05
    4|Eintracht Frankfurt|Sport-Club Freiburg
    4|FC Bayern München|1. FC Union Berlin
    4|FC Schalke 04|SV Elversberg
    4|Hamburger SV|1. FC Köln
    4|SC Paderborn 07|TSG Hoffenheim
    4|SV Werder Bremen|FC Augsburg
    4|VfB Stuttgart|Borussia Dortmund
    5|1. FC Köln|Borussia Mönchengladbach
    5|1. FC Union Berlin|SV Elversberg
    5|1. FSV Mainz 05|Bayer 04 Leverkusen
    5|Borussia Dortmund|SV Werder Bremen
    5|FC Augsburg|FC Bayern München
    5|RB Leipzig|Eintracht Frankfurt
    5|SC Paderborn 07|VfB Stuttgart
    5|Sport-Club Freiburg|FC Schalke 04
    5|TSG Hoffenheim|Hamburger SV
    6|1. FC Union Berlin|Borussia Dortmund
    6|Bayer 04 Leverkusen|Sport-Club Freiburg
    6|Borussia Mönchengladbach|TSG Hoffenheim
    6|Eintracht Frankfurt|1. FC Köln
    6|FC Bayern München|RB Leipzig
    6|FC Schalke 04|1. FSV Mainz 05
    6|Hamburger SV|VfB Stuttgart
    6|SV Elversberg|FC Augsburg
    6|SV Werder Bremen|SC Paderborn 07
    7|1. FC Köln|FC Schalke 04
    7|1. FSV Mainz 05|SV Werder Bremen
    7|Borussia Dortmund|Eintracht Frankfurt
    7|FC Augsburg|1. FC Union Berlin
    7|RB Leipzig|SV Elversberg
    7|SC Paderborn 07|Hamburger SV
    7|Sport-Club Freiburg|FC Bayern München
    7|TSG Hoffenheim|Bayer 04 Leverkusen
    7|VfB Stuttgart|Borussia Mönchengladbach
    8|1. FC Union Berlin|1. FC Köln
    8|Bayer 04 Leverkusen|VfB Stuttgart
    8|Borussia Mönchengladbach|SC Paderborn 07
    8|Eintracht Frankfurt|Hamburger SV
    8|FC Augsburg|Sport-Club Freiburg
    8|FC Bayern München|Borussia Dortmund
    8|FC Schalke 04|RB Leipzig
    8|SV Elversberg|1. FSV Mainz 05
    8|SV Werder Bremen|TSG Hoffenheim
    9|1. FC Köln|Bayer 04 Leverkusen
    9|1. FSV Mainz 05|FC Bayern München
    9|Borussia Dortmund|SV Elversberg
    9|Hamburger SV|Borussia Mönchengladbach
    9|RB Leipzig|FC Augsburg
    9|SC Paderborn 07|Eintracht Frankfurt
    9|Sport-Club Freiburg|1. FC Union Berlin
    9|TSG Hoffenheim|FC Schalke 04
    9|VfB Stuttgart|SV Werder Bremen
    10|1. FC Union Berlin|RB Leipzig
    10|Bayer 04 Leverkusen|SC Paderborn 07
    10|Borussia Mönchengladbach|Borussia Dortmund
    10|Eintracht Frankfurt|TSG Hoffenheim
    10|FC Augsburg|1. FSV Mainz 05
    10|FC Bayern München|1. FC Köln
    10|FC Schalke 04|VfB Stuttgart
    10|SV Elversberg|Sport-Club Freiburg
    10|SV Werder Bremen|Hamburger SV
    11|1. FC Köln|SV Elversberg
    11|1. FSV Mainz 05|1. FC Union Berlin
    11|Borussia Dortmund|Bayer 04 Leverkusen
    11|Hamburger SV|FC Bayern München
    11|SC Paderborn 07|FC Schalke 04
    11|SV Werder Bremen|Borussia Mönchengladbach
    11|Sport-Club Freiburg|RB Leipzig
    11|TSG Hoffenheim|FC Augsburg
    11|VfB Stuttgart|Eintracht Frankfurt
    12|1. FC Union Berlin|Hamburger SV
    12|Bayer 04 Leverkusen|Borussia Mönchengladbach
    12|Eintracht Frankfurt|SV Werder Bremen
    12|FC Augsburg|1. FC Köln
    12|FC Bayern München|SC Paderborn 07
    12|FC Schalke 04|Borussia Dortmund
    12|RB Leipzig|1. FSV Mainz 05
    12|SV Elversberg|VfB Stuttgart
    12|Sport-Club Freiburg|TSG Hoffenheim
    13|1. FC Köln|RB Leipzig
    13|1. FSV Mainz 05|Sport-Club Freiburg
    13|Borussia Dortmund|FC Augsburg
    13|Borussia Mönchengladbach|Eintracht Frankfurt
    13|Hamburger SV|FC Schalke 04
    13|SC Paderborn 07|SV Elversberg
    13|SV Werder Bremen|Bayer 04 Leverkusen
    13|TSG Hoffenheim|FC Bayern München
    13|VfB Stuttgart|1. FC Union Berlin
    14|1. FC Union Berlin|TSG Hoffenheim
    14|1. FSV Mainz 05|1. FC Köln
    14|Bayer 04 Leverkusen|Eintracht Frankfurt
    14|FC Augsburg|SC Paderborn 07
    14|FC Bayern München|SV Werder Bremen
    14|FC Schalke 04|Borussia Mönchengladbach
    14|RB Leipzig|Borussia Dortmund
    14|SV Elversberg|Hamburger SV
    14|Sport-Club Freiburg|VfB Stuttgart
    15|1. FC Köln|Sport-Club Freiburg
    15|Borussia Dortmund|1. FSV Mainz 05
    15|Borussia Mönchengladbach|FC Bayern München
    15|Eintracht Frankfurt|FC Schalke 04
    15|Hamburger SV|Bayer 04 Leverkusen
    15|SC Paderborn 07|RB Leipzig
    15|SV Werder Bremen|1. FC Union Berlin
    15|TSG Hoffenheim|SV Elversberg
    15|VfB Stuttgart|FC Augsburg
    16|1. FC Köln|Borussia Dortmund
    16|1. FC Union Berlin|SC Paderborn 07
    16|1. FSV Mainz 05|TSG Hoffenheim
    16|FC Augsburg|Borussia Mönchengladbach
    16|FC Bayern München|Bayer 04 Leverkusen
    16|FC Schalke 04|SV Werder Bremen
    16|RB Leipzig|VfB Stuttgart
    16|SV Elversberg|Eintracht Frankfurt
    16|Sport-Club Freiburg|Hamburger SV
    17|Bayer 04 Leverkusen|FC Schalke 04
    17|Borussia Dortmund|Sport-Club Freiburg
    17|Borussia Mönchengladbach|1. FC Union Berlin
    17|Eintracht Frankfurt|FC Bayern München
    17|Hamburger SV|FC Augsburg
    17|SC Paderborn 07|1. FC Köln
    17|SV Werder Bremen|SV Elversberg
    17|TSG Hoffenheim|RB Leipzig
    17|VfB Stuttgart|1. FSV Mainz 05
    18|Bayer 04 Leverkusen|SV Elversberg
    18|Borussia Mönchengladbach|RB Leipzig
    18|Eintracht Frankfurt|1. FC Union Berlin
    18|FC Schalke 04|FC Augsburg
    18|Hamburger SV|Borussia Dortmund
    18|SC Paderborn 07|1. FSV Mainz 05
    18|SV Werder Bremen|Sport-Club Freiburg
    18|TSG Hoffenheim|1. FC Köln
    18|VfB Stuttgart|FC Bayern München
    19|1. FC Köln|VfB Stuttgart
    19|1. FC Union Berlin|Bayer 04 Leverkusen
    19|1. FSV Mainz 05|Hamburger SV
    19|Borussia Dortmund|TSG Hoffenheim
    19|FC Augsburg|Eintracht Frankfurt
    19|FC Bayern München|FC Schalke 04
    19|RB Leipzig|SV Werder Bremen
    19|SV Elversberg|Borussia Mönchengladbach
    19|Sport-Club Freiburg|SC Paderborn 07
    20|Bayer 04 Leverkusen|FC Augsburg
    20|Borussia Mönchengladbach|Sport-Club Freiburg
    20|Eintracht Frankfurt|1. FSV Mainz 05
    20|FC Bayern München|SV Elversberg
    20|FC Schalke 04|1. FC Union Berlin
    20|Hamburger SV|RB Leipzig
    20|SC Paderborn 07|Borussia Dortmund
    20|SV Werder Bremen|1. FC Köln
    20|VfB Stuttgart|TSG Hoffenheim
    21|1. FC Köln|Hamburger SV
    21|1. FC Union Berlin|FC Bayern München
    21|1. FSV Mainz 05|Borussia Mönchengladbach
    21|Borussia Dortmund|VfB Stuttgart
    21|FC Augsburg|SV Werder Bremen
    21|RB Leipzig|Bayer 04 Leverkusen
    21|SV Elversberg|FC Schalke 04
    21|Sport-Club Freiburg|Eintracht Frankfurt
    21|TSG Hoffenheim|SC Paderborn 07
    22|Bayer 04 Leverkusen|1. FSV Mainz 05
    22|Borussia Mönchengladbach|1. FC Köln
    22|Eintracht Frankfurt|RB Leipzig
    22|FC Bayern München|FC Augsburg
    22|FC Schalke 04|Sport-Club Freiburg
    22|Hamburger SV|TSG Hoffenheim
    22|SV Elversberg|1. FC Union Berlin
    22|SV Werder Bremen|Borussia Dortmund
    22|VfB Stuttgart|SC Paderborn 07
    23|1. FC Köln|Eintracht Frankfurt
    23|1. FSV Mainz 05|FC Schalke 04
    23|Borussia Dortmund|1. FC Union Berlin
    23|FC Augsburg|SV Elversberg
    23|RB Leipzig|FC Bayern München
    23|SC Paderborn 07|SV Werder Bremen
    23|Sport-Club Freiburg|Bayer 04 Leverkusen
    23|TSG Hoffenheim|Borussia Mönchengladbach
    23|VfB Stuttgart|Hamburger SV
    24|1. FC Union Berlin|FC Augsburg
    24|Bayer 04 Leverkusen|TSG Hoffenheim
    24|Borussia Mönchengladbach|VfB Stuttgart
    24|Eintracht Frankfurt|Borussia Dortmund
    24|FC Bayern München|Sport-Club Freiburg
    24|FC Schalke 04|1. FC Köln
    24|Hamburger SV|SC Paderborn 07
    24|SV Elversberg|RB Leipzig
    24|SV Werder Bremen|1. FSV Mainz 05
    25|1. FC Köln|1. FC Union Berlin
    25|1. FSV Mainz 05|SV Elversberg
    25|Borussia Dortmund|FC Bayern München
    25|Hamburger SV|Eintracht Frankfurt
    25|RB Leipzig|FC Schalke 04
    25|SC Paderborn 07|Borussia Mönchengladbach
    25|Sport-Club Freiburg|FC Augsburg
    25|TSG Hoffenheim|SV Werder Bremen
    25|VfB Stuttgart|Bayer 04 Leverkusen
    26|1. FC Union Berlin|Sport-Club Freiburg
    26|Bayer 04 Leverkusen|1. FC Köln
    26|Borussia Mönchengladbach|Hamburger SV
    26|Eintracht Frankfurt|SC Paderborn 07
    26|FC Augsburg|RB Leipzig
    26|FC Bayern München|1. FSV Mainz 05
    26|FC Schalke 04|TSG Hoffenheim
    26|SV Elversberg|Borussia Dortmund
    26|SV Werder Bremen|VfB Stuttgart
    27|1. FC Köln|FC Bayern München
    27|1. FSV Mainz 05|FC Augsburg
    27|Borussia Dortmund|Borussia Mönchengladbach
    27|Hamburger SV|SV Werder Bremen
    27|RB Leipzig|1. FC Union Berlin
    27|SC Paderborn 07|Bayer 04 Leverkusen
    27|Sport-Club Freiburg|SV Elversberg
    27|TSG Hoffenheim|Eintracht Frankfurt
    27|VfB Stuttgart|FC Schalke 04
    28|1. FC Union Berlin|1. FSV Mainz 05
    28|Bayer 04 Leverkusen|Borussia Dortmund
    28|Borussia Mönchengladbach|SV Werder Bremen
    28|Eintracht Frankfurt|VfB Stuttgart
    28|FC Augsburg|TSG Hoffenheim
    28|FC Bayern München|Hamburger SV
    28|FC Schalke 04|SC Paderborn 07
    28|RB Leipzig|Sport-Club Freiburg
    28|SV Elversberg|1. FC Köln
    29|1. FC Köln|FC Augsburg
    29|1. FSV Mainz 05|RB Leipzig
    29|Borussia Dortmund|FC Schalke 04
    29|Borussia Mönchengladbach|Bayer 04 Leverkusen
    29|Hamburger SV|1. FC Union Berlin
    29|SC Paderborn 07|FC Bayern München
    29|SV Werder Bremen|Eintracht Frankfurt
    29|TSG Hoffenheim|Sport-Club Freiburg
    29|VfB Stuttgart|SV Elversberg
    30|1. FC Union Berlin|VfB Stuttgart
    30|Bayer 04 Leverkusen|SV Werder Bremen
    30|Eintracht Frankfurt|Borussia Mönchengladbach
    30|FC Augsburg|Borussia Dortmund
    30|FC Bayern München|TSG Hoffenheim
    30|FC Schalke 04|Hamburger SV
    30|RB Leipzig|1. FC Köln
    30|SV Elversberg|SC Paderborn 07
    30|Sport-Club Freiburg|1. FSV Mainz 05
    31|1. FC Köln|1. FSV Mainz 05
    31|Borussia Dortmund|RB Leipzig
    31|Borussia Mönchengladbach|FC Schalke 04
    31|Eintracht Frankfurt|Bayer 04 Leverkusen
    31|Hamburger SV|SV Elversberg
    31|SC Paderborn 07|FC Augsburg
    31|SV Werder Bremen|FC Bayern München
    31|TSG Hoffenheim|1. FC Union Berlin
    31|VfB Stuttgart|Sport-Club Freiburg
    32|1. FC Union Berlin|SV Werder Bremen
    32|1. FSV Mainz 05|Borussia Dortmund
    32|Bayer 04 Leverkusen|Hamburger SV
    32|FC Augsburg|VfB Stuttgart
    32|FC Bayern München|Borussia Mönchengladbach
    32|FC Schalke 04|Eintracht Frankfurt
    32|RB Leipzig|SC Paderborn 07
    32|SV Elversberg|TSG Hoffenheim
    32|Sport-Club Freiburg|1. FC Köln
    33|Bayer 04 Leverkusen|FC Bayern München
    33|Borussia Dortmund|1. FC Köln
    33|Borussia Mönchengladbach|FC Augsburg
    33|Eintracht Frankfurt|SV Elversberg
    33|Hamburger SV|Sport-Club Freiburg
    33|SC Paderborn 07|1. FC Union Berlin
    33|SV Werder Bremen|FC Schalke 04
    33|TSG Hoffenheim|1. FSV Mainz 05
    33|VfB Stuttgart|RB Leipzig
    34|1. FC Köln|SC Paderborn 07
    34|1. FC Union Berlin|Borussia Mönchengladbach
    34|1. FSV Mainz 05|VfB Stuttgart
    34|FC Augsburg|Hamburger SV
    34|FC Bayern München|Eintracht Frankfurt
    34|FC Schalke 04|Bayer 04 Leverkusen
    34|RB Leipzig|TSG Hoffenheim
    34|SV Elversberg|SV Werder Bremen
    34|Sport-Club Freiburg|Borussia Dortmund
    """

    static let premierLeague2627 = """
    1|Arsenal|Coventry
    1|Brentford|Tottenham
    1|Brighton|Aston Villa
    1|Everton|Crystal Palace
    1|Fulham|Chelsea
    1|Hull City|Manchester United
    1|Ipswich|Sunderland
    1|Manchester City|Bournemouth
    1|Newcastle|Liverpool
    1|Nottingham Forest|Leeds
    2|Aston Villa|Arsenal
    2|Bournemouth|Everton
    2|Chelsea|Brighton
    2|Coventry|Hull City
    2|Crystal Palace|Manchester City
    2|Leeds|Brentford
    2|Liverpool|Nottingham Forest
    2|Manchester United|Ipswich
    2|Sunderland|Fulham
    2|Tottenham|Newcastle
    3|Arsenal|Chelsea
    3|Brentford|Sunderland
    3|Brighton|Leeds
    3|Everton|Manchester United
    3|Fulham|Crystal Palace
    3|Hull City|Aston Villa
    3|Ipswich|Liverpool
    3|Manchester City|Coventry
    3|Newcastle|Bournemouth
    3|Nottingham Forest|Tottenham
    4|Aston Villa|Nottingham Forest
    4|Bournemouth|Brentford
    4|Chelsea|Hull City
    4|Coventry|Brighton
    4|Crystal Palace|Ipswich
    4|Leeds|Newcastle
    4|Liverpool|Fulham
    4|Manchester United|Manchester City
    4|Sunderland|Arsenal
    4|Tottenham|Everton
    5|Bournemouth|Liverpool
    5|Brentford|Chelsea
    5|Brighton|Arsenal
    5|Everton|Ipswich
    5|Fulham|Manchester United
    5|Leeds|Crystal Palace
    5|Manchester City|Sunderland
    5|Newcastle|Hull City
    5|Nottingham Forest|Coventry
    5|Tottenham|Aston Villa
    6|Arsenal|Leeds
    6|Aston Villa|Brentford
    6|Chelsea|Bournemouth
    6|Coventry|Newcastle
    6|Crystal Palace|Nottingham Forest
    6|Hull City|Everton
    6|Ipswich|Fulham
    6|Liverpool|Manchester City
    6|Manchester United|Tottenham
    6|Sunderland|Brighton
    7|Bournemouth|Sunderland
    7|Brentford|Liverpool
    7|Brighton|Crystal Palace
    7|Everton|Chelsea
    7|Fulham|Hull City
    7|Leeds|Manchester United
    7|Manchester City|Ipswich
    7|Newcastle|Aston Villa
    7|Nottingham Forest|Arsenal
    7|Tottenham|Coventry
    8|Arsenal|Everton
    8|Aston Villa|Manchester City
    8|Chelsea|Tottenham
    8|Coventry|Fulham
    8|Crystal Palace|Newcastle
    8|Hull City|Brentford
    8|Ipswich|Nottingham Forest
    8|Liverpool|Brighton
    8|Manchester United|Bournemouth
    8|Sunderland|Leeds
    9|Aston Villa|Fulham
    9|Bournemouth|Leeds
    9|Brentford|Nottingham Forest
    9|Chelsea|Manchester United
    9|Coventry|Sunderland
    9|Hull City|Ipswich
    9|Liverpool|Arsenal
    9|Manchester City|Brighton
    9|Newcastle|Everton
    9|Tottenham|Crystal Palace
    10|Arsenal|Hull City
    10|Brighton|Brentford
    10|Crystal Palace|Liverpool
    10|Everton|Coventry
    10|Fulham|Newcastle
    10|Ipswich|Bournemouth
    10|Leeds|Tottenham
    10|Manchester United|Aston Villa
    10|Nottingham Forest|Manchester City
    10|Sunderland|Chelsea
    11|Aston Villa|Sunderland
    11|Bournemouth|Nottingham Forest
    11|Brentford|Everton
    11|Chelsea|Leeds
    11|Coventry|Crystal Palace
    11|Hull City|Brighton
    11|Liverpool|Manchester United
    11|Manchester City|Fulham
    11|Newcastle|Arsenal
    11|Tottenham|Ipswich
    12|Arsenal|Manchester City
    12|Brighton|Newcastle
    12|Crystal Palace|Hull City
    12|Everton|Liverpool
    12|Fulham|Bournemouth
    12|Ipswich|Aston Villa
    12|Leeds|Coventry
    12|Manchester United|Brentford
    12|Nottingham Forest|Chelsea
    12|Sunderland|Tottenham
    13|Aston Villa|Everton
    13|Bournemouth|Brighton
    13|Brentford|Arsenal
    13|Chelsea|Crystal Palace
    13|Coventry|Ipswich
    13|Hull City|Nottingham Forest
    13|Liverpool|Sunderland
    13|Manchester City|Leeds
    13|Newcastle|Manchester United
    13|Tottenham|Fulham
    14|Aston Villa|Crystal Palace
    14|Bournemouth|Hull City
    14|Brentford|Manchester City
    14|Chelsea|Liverpool
    14|Everton|Fulham
    14|Leeds|Ipswich
    14|Manchester United|Coventry
    14|Newcastle|Sunderland
    14|Nottingham Forest|Brighton
    14|Tottenham|Arsenal
    15|Arsenal|Bournemouth
    15|Brighton|Everton
    15|Coventry|Aston Villa
    15|Crystal Palace|Manchester United
    15|Fulham|Brentford
    15|Hull City|Tottenham
    15|Ipswich|Newcastle
    15|Liverpool|Leeds
    15|Manchester City|Chelsea
    15|Sunderland|Nottingham Forest
    16|Arsenal|Manchester United
    16|Bournemouth|Coventry
    16|Brentford|Newcastle
    16|Brighton|Ipswich
    16|Chelsea|Aston Villa
    16|Leeds|Fulham
    16|Liverpool|Tottenham
    16|Manchester City|Hull City
    16|Nottingham Forest|Everton
    16|Sunderland|Crystal Palace
    17|Aston Villa|Leeds
    17|Coventry|Chelsea
    17|Crystal Palace|Arsenal
    17|Everton|Sunderland
    17|Fulham|Brighton
    17|Hull City|Liverpool
    17|Ipswich|Brentford
    17|Manchester United|Nottingham Forest
    17|Newcastle|Manchester City
    17|Tottenham|Bournemouth
    18|Aston Villa|Liverpool
    18|Coventry|Brentford
    18|Crystal Palace|Bournemouth
    18|Everton|Manchester City
    18|Fulham|Arsenal
    18|Hull City|Leeds
    18|Ipswich|Chelsea
    18|Manchester United|Sunderland
    18|Newcastle|Nottingham Forest
    18|Tottenham|Brighton
    19|Arsenal|Ipswich
    19|Bournemouth|Aston Villa
    19|Brentford|Crystal Palace
    19|Brighton|Manchester United
    19|Chelsea|Newcastle
    19|Leeds|Everton
    19|Liverpool|Coventry
    19|Manchester City|Tottenham
    19|Nottingham Forest|Fulham
    19|Sunderland|Hull City
    20|Arsenal|Brentford
    20|Brighton|Bournemouth
    20|Crystal Palace|Chelsea
    20|Everton|Aston Villa
    20|Fulham|Tottenham
    20|Ipswich|Coventry
    20|Leeds|Manchester City
    20|Manchester United|Newcastle
    20|Nottingham Forest|Hull City
    20|Sunderland|Liverpool
    21|Aston Villa|Manchester United
    21|Bournemouth|Ipswich
    21|Brentford|Brighton
    21|Chelsea|Sunderland
    21|Coventry|Everton
    21|Hull City|Arsenal
    21|Liverpool|Crystal Palace
    21|Manchester City|Nottingham Forest
    21|Newcastle|Fulham
    21|Tottenham|Leeds
    22|Arsenal|Newcastle
    22|Brighton|Manchester City
    22|Crystal Palace|Tottenham
    22|Everton|Brentford
    22|Fulham|Aston Villa
    22|Ipswich|Hull City
    22|Leeds|Chelsea
    22|Manchester United|Liverpool
    22|Nottingham Forest|Bournemouth
    22|Sunderland|Coventry
    23|Aston Villa|Ipswich
    23|Bournemouth|Fulham
    23|Brentford|Manchester United
    23|Chelsea|Nottingham Forest
    23|Coventry|Leeds
    23|Hull City|Crystal Palace
    23|Liverpool|Everton
    23|Manchester City|Arsenal
    23|Newcastle|Brighton
    23|Tottenham|Sunderland
    24|Arsenal|Liverpool
    24|Brighton|Hull City
    24|Crystal Palace|Coventry
    24|Everton|Newcastle
    24|Fulham|Manchester City
    24|Ipswich|Tottenham
    24|Leeds|Bournemouth
    24|Manchester United|Chelsea
    24|Nottingham Forest|Brentford
    24|Sunderland|Aston Villa
    25|Aston Villa|Bournemouth
    25|Coventry|Liverpool
    25|Crystal Palace|Brentford
    25|Everton|Leeds
    25|Fulham|Nottingham Forest
    25|Hull City|Sunderland
    25|Ipswich|Arsenal
    25|Manchester United|Brighton
    25|Newcastle|Chelsea
    25|Tottenham|Manchester City
    26|Arsenal|Fulham
    26|Bournemouth|Crystal Palace
    26|Brentford|Coventry
    26|Brighton|Tottenham
    26|Chelsea|Ipswich
    26|Leeds|Aston Villa
    26|Liverpool|Hull City
    26|Manchester City|Newcastle
    26|Nottingham Forest|Manchester United
    26|Sunderland|Everton
    27|Aston Villa|Chelsea
    27|Coventry|Bournemouth
    27|Crystal Palace|Sunderland
    27|Everton|Nottingham Forest
    27|Fulham|Leeds
    27|Hull City|Manchester City
    27|Ipswich|Brighton
    27|Manchester United|Arsenal
    27|Newcastle|Brentford
    27|Tottenham|Liverpool
    28|Arsenal|Crystal Palace
    28|Bournemouth|Tottenham
    28|Brentford|Ipswich
    28|Brighton|Fulham
    28|Chelsea|Coventry
    28|Leeds|Hull City
    28|Liverpool|Aston Villa
    28|Manchester City|Everton
    28|Nottingham Forest|Newcastle
    28|Sunderland|Manchester United
    29|Aston Villa|Hull City
    29|Bournemouth|Newcastle
    29|Chelsea|Arsenal
    29|Coventry|Manchester City
    29|Crystal Palace|Fulham
    29|Leeds|Brighton
    29|Liverpool|Ipswich
    29|Manchester United|Everton
    29|Sunderland|Brentford
    29|Tottenham|Nottingham Forest
    30|Arsenal|Sunderland
    30|Brentford|Bournemouth
    30|Brighton|Coventry
    30|Everton|Tottenham
    30|Fulham|Liverpool
    30|Hull City|Chelsea
    30|Ipswich|Crystal Palace
    30|Manchester City|Manchester United
    30|Newcastle|Leeds
    30|Nottingham Forest|Aston Villa
    31|Aston Villa|Brighton
    31|Bournemouth|Manchester City
    31|Chelsea|Fulham
    31|Coventry|Arsenal
    31|Crystal Palace|Everton
    31|Leeds|Nottingham Forest
    31|Liverpool|Newcastle
    31|Manchester United|Hull City
    31|Sunderland|Ipswich
    31|Tottenham|Brentford
    32|Arsenal|Aston Villa
    32|Brentford|Leeds
    32|Brighton|Chelsea
    32|Everton|Bournemouth
    32|Fulham|Sunderland
    32|Hull City|Coventry
    32|Ipswich|Manchester United
    32|Manchester City|Crystal Palace
    32|Newcastle|Tottenham
    32|Nottingham Forest|Liverpool
    33|Aston Villa|Coventry
    33|Bournemouth|Arsenal
    33|Brentford|Fulham
    33|Chelsea|Manchester City
    33|Everton|Brighton
    33|Leeds|Liverpool
    33|Manchester United|Crystal Palace
    33|Newcastle|Ipswich
    33|Nottingham Forest|Sunderland
    33|Tottenham|Hull City
    34|Arsenal|Tottenham
    34|Brighton|Nottingham Forest
    34|Coventry|Manchester United
    34|Crystal Palace|Aston Villa
    34|Fulham|Everton
    34|Hull City|Bournemouth
    34|Ipswich|Leeds
    34|Liverpool|Chelsea
    34|Manchester City|Brentford
    34|Sunderland|Newcastle
    35|Bournemouth|Manchester United
    35|Brentford|Aston Villa
    35|Brighton|Sunderland
    35|Everton|Hull City
    35|Fulham|Ipswich
    35|Leeds|Arsenal
    35|Manchester City|Liverpool
    35|Newcastle|Coventry
    35|Nottingham Forest|Crystal Palace
    35|Tottenham|Chelsea
    36|Arsenal|Nottingham Forest
    36|Aston Villa|Newcastle
    36|Chelsea|Everton
    36|Coventry|Tottenham
    36|Crystal Palace|Brighton
    36|Hull City|Fulham
    36|Ipswich|Manchester City
    36|Liverpool|Brentford
    36|Manchester United|Leeds
    36|Sunderland|Bournemouth
    37|Bournemouth|Chelsea
    37|Brentford|Hull City
    37|Brighton|Liverpool
    37|Everton|Arsenal
    37|Fulham|Coventry
    37|Leeds|Sunderland
    37|Manchester City|Aston Villa
    37|Newcastle|Crystal Palace
    37|Nottingham Forest|Ipswich
    37|Tottenham|Manchester United
    38|Arsenal|Brighton
    38|Aston Villa|Tottenham
    38|Chelsea|Brentford
    38|Coventry|Nottingham Forest
    38|Crystal Palace|Leeds
    38|Hull City|Newcastle
    38|Ipswich|Everton
    38|Liverpool|Bournemouth
    38|Manchester United|Fulham
    38|Sunderland|Manchester City
    """

    static let serieA2627 = """
    1|AS Roma|Fiorentina
    1|Atalanta|Sassuolo
    1|Bologna|Lazio
    1|Frosinone|Juventus
    1|Genoa|Napoli
    1|Inter|Monza
    1|Parma|Cagliari
    1|Torino|AC Milan
    1|Udinese|Como
    1|Venezia|Lecce
    2|AC Milan|Venezia
    2|Atalanta|Bologna
    2|Cagliari|Inter
    2|Fiorentina|Frosinone
    2|Juventus|Parma
    2|Lazio|Genoa
    2|Lecce|AS Roma
    2|Monza|Udinese
    2|Napoli|Como
    2|Sassuolo|Torino
    3|AS Roma|Atalanta
    3|Bologna|Sassuolo
    3|Cagliari|Lecce
    3|Fiorentina|Torino
    3|Frosinone|Venezia
    3|Genoa|Como
    3|Inter|Napoli
    3|Juventus|AC Milan
    3|Parma|Monza
    3|Udinese|Lazio
    4|Atalanta|Cagliari
    4|Como|Parma
    4|Genoa|Frosinone
    4|Inter|Udinese
    4|Lazio|AC Milan
    4|Lecce|Monza
    4|Napoli|Bologna
    4|Sassuolo|Juventus
    4|Torino|AS Roma
    4|Venezia|Fiorentina
    5|AC Milan|Lecce
    5|AS Roma|Inter
    5|Bologna|Torino
    5|Fiorentina|Napoli
    5|Frosinone|Como
    5|Juventus|Atalanta
    5|Monza|Sassuolo
    5|Parma|Genoa
    5|Udinese|Cagliari
    5|Venezia|Lazio
    6|Atalanta|Venezia
    6|Cagliari|Juventus
    6|Como|AS Roma
    6|Genoa|Fiorentina
    6|Inter|Parma
    6|Lazio|Monza
    6|Lecce|Bologna
    6|Napoli|Frosinone
    6|Sassuolo|AC Milan
    6|Torino|Udinese
    7|AC Milan|Atalanta
    7|AS Roma|Genoa
    7|Bologna|Inter
    7|Fiorentina|Como
    7|Frosinone|Sassuolo
    7|Juventus|Lazio
    7|Monza|Cagliari
    7|Parma|Torino
    7|Udinese|Lecce
    7|Venezia|Napoli
    8|Atalanta|Frosinone
    8|Cagliari|Bologna
    8|Como|Sassuolo
    8|Genoa|Venezia
    8|Inter|Fiorentina
    8|Lazio|Parma
    8|Lecce|Juventus
    8|Napoli|AS Roma
    8|Torino|Monza
    8|Udinese|AC Milan
    9|AC Milan|Bologna
    9|AS Roma|Cagliari
    9|Fiorentina|Atalanta
    9|Frosinone|Lecce
    9|Genoa|Juventus
    9|Monza|Napoli
    9|Parma|Udinese
    9|Sassuolo|Lazio
    9|Torino|Como
    9|Venezia|Inter
    10|AC Milan|Inter
    10|Atalanta|Parma
    10|Bologna|Monza
    10|Como|Venezia
    10|Frosinone|Torino
    10|Juventus|Napoli
    10|Lazio|Cagliari
    10|Lecce|Genoa
    10|Sassuolo|Fiorentina
    10|Udinese|AS Roma
    11|AS Roma|Sassuolo
    11|Cagliari|Frosinone
    11|Fiorentina|Juventus
    11|Genoa|AC Milan
    11|Inter|Como
    11|Monza|Atalanta
    11|Napoli|Lazio
    11|Parma|Bologna
    11|Torino|Lecce
    11|Venezia|Udinese
    12|AC Milan|Frosinone
    12|Atalanta|Inter
    12|Bologna|Udinese
    12|Como|Cagliari
    12|Juventus|Venezia
    12|Lazio|Lecce
    12|Monza|Fiorentina
    12|Napoli|Torino
    12|Parma|AS Roma
    12|Sassuolo|Genoa
    13|AS Roma|Monza
    13|Cagliari|AC Milan
    13|Como|Juventus
    13|Frosinone|Parma
    13|Inter|Genoa
    13|Lecce|Atalanta
    13|Sassuolo|Napoli
    13|Torino|Lazio
    13|Udinese|Fiorentina
    13|Venezia|Bologna
    14|AC Milan|Parma
    14|Bologna|AS Roma
    14|Fiorentina|Cagliari
    14|Frosinone|Inter
    14|Genoa|Torino
    14|Juventus|Udinese
    14|Lazio|Atalanta
    14|Monza|Como
    14|Napoli|Lecce
    14|Venezia|Sassuolo
    15|Atalanta|Genoa
    15|Cagliari|Venezia
    15|Como|Bologna
    15|Inter|Torino
    15|Juventus|Monza
    15|Lazio|AS Roma
    15|Lecce|Sassuolo
    15|Napoli|AC Milan
    15|Parma|Fiorentina
    15|Udinese|Frosinone
    16|AC Milan|Como
    16|AS Roma|Juventus
    16|Atalanta|Napoli
    16|Fiorentina|Bologna
    16|Frosinone|Lazio
    16|Genoa|Udinese
    16|Lecce|Inter
    16|Sassuolo|Parma
    16|Torino|Cagliari
    16|Venezia|Monza
    17|AS Roma|Frosinone
    17|Bologna|Juventus
    17|Cagliari|Genoa
    17|Como|Lecce
    17|Fiorentina|Lazio
    17|Inter|Sassuolo
    17|Monza|AC Milan
    17|Parma|Napoli
    17|Torino|Venezia
    17|Udinese|Atalanta
    18|AC Milan|Fiorentina
    18|Atalanta|Como
    18|Frosinone|Bologna
    18|Genoa|Monza
    18|Juventus|Torino
    18|Lazio|Inter
    18|Lecce|Parma
    18|Napoli|Cagliari
    18|Sassuolo|Udinese
    18|Venezia|AS Roma
    19|AS Roma|AC Milan
    19|Bologna|Genoa
    19|Cagliari|Sassuolo
    19|Como|Lazio
    19|Fiorentina|Lecce
    19|Inter|Juventus
    19|Monza|Frosinone
    19|Parma|Venezia
    19|Torino|Atalanta
    19|Udinese|Napoli
    20|AC Milan|Torino
    20|Atalanta|AS Roma
    20|Cagliari|Como
    20|Juventus|Genoa
    20|Lazio|Bologna
    20|Lecce|Udinese
    20|Napoli|Fiorentina
    20|Parma|Inter
    20|Sassuolo|Monza
    20|Venezia|Frosinone
    21|AS Roma|Udinese
    21|Bologna|Atalanta
    21|Como|Napoli
    21|Fiorentina|Sassuolo
    21|Frosinone|AC Milan
    21|Genoa|Parma
    21|Inter|Venezia
    21|Juventus|Cagliari
    21|Lecce|Torino
    21|Monza|Lazio
    22|AC Milan|Juventus
    22|Atalanta|Fiorentina
    22|Cagliari|Parma
    22|Genoa|Lecce
    22|Lazio|Venezia
    22|Monza|AS Roma
    22|Napoli|Inter
    22|Sassuolo|Como
    22|Torino|Frosinone
    22|Udinese|Bologna
    23|AS Roma|Torino
    23|Atalanta|Lazio
    23|Bologna|AC Milan
    23|Como|Monza
    23|Fiorentina|Udinese
    23|Inter|Cagliari
    23|Juventus|Sassuolo
    23|Lecce|Napoli
    23|Parma|Frosinone
    23|Venezia|Genoa
    24|AS Roma|Parma
    24|Bologna|Como
    24|Cagliari|Lazio
    24|Frosinone|Fiorentina
    24|Genoa|Atalanta
    24|Inter|AC Milan
    24|Monza|Lecce
    24|Napoli|Juventus
    24|Torino|Sassuolo
    24|Udinese|Venezia
    25|AC Milan|Genoa
    25|Atalanta|Monza
    25|Como|Torino
    25|Fiorentina|Inter
    25|Juventus|Bologna
    25|Lazio|Napoli
    25|Lecce|Frosinone
    25|Sassuolo|AS Roma
    25|Udinese|Parma
    25|Venezia|Cagliari
    26|AS Roma|Venezia
    26|Bologna|Lecce
    26|Cagliari|Udinese
    26|Como|AC Milan
    26|Frosinone|Napoli
    26|Genoa|Lazio
    26|Inter|Atalanta
    26|Monza|Juventus
    26|Parma|Sassuolo
    26|Torino|Fiorentina
    27|AC Milan|Cagliari
    27|Atalanta|Torino
    27|Fiorentina|Venezia
    27|Juventus|AS Roma
    27|Lazio|Frosinone
    27|Lecce|Como
    27|Monza|Genoa
    27|Napoli|Parma
    27|Sassuolo|Bologna
    27|Udinese|Inter
    28|AC Milan|Sassuolo
    28|Bologna|Napoli
    28|Cagliari|Fiorentina
    28|Como|Udinese
    28|Frosinone|Monza
    28|Genoa|AS Roma
    28|Lazio|Juventus
    28|Parma|Lecce
    28|Torino|Inter
    28|Venezia|Atalanta
    29|AS Roma|Lecce
    29|Atalanta|AC Milan
    29|Fiorentina|Genoa
    29|Inter|Frosinone
    29|Juventus|Como
    29|Monza|Bologna
    29|Napoli|Venezia
    29|Parma|Lazio
    29|Sassuolo|Cagliari
    29|Udinese|Torino
    30|AC Milan|Monza
    30|AS Roma|Bologna
    30|Cagliari|Napoli
    30|Como|Fiorentina
    30|Frosinone|Udinese
    30|Genoa|Inter
    30|Lecce|Lazio
    30|Sassuolo|Atalanta
    30|Torino|Juventus
    30|Venezia|Parma
    31|Bologna|Venezia
    31|Cagliari|Atalanta
    31|Fiorentina|AC Milan
    31|Frosinone|Genoa
    31|Inter|AS Roma
    31|Juventus|Lecce
    31|Lazio|Torino
    31|Napoli|Sassuolo
    31|Parma|Como
    31|Udinese|Monza
    32|AC Milan|Napoli
    32|AS Roma|Lazio
    32|Atalanta|Udinese
    32|Bologna|Cagliari
    32|Como|Frosinone
    32|Fiorentina|Parma
    32|Monza|Inter
    32|Sassuolo|Lecce
    32|Torino|Genoa
    32|Venezia|Juventus
    33|Cagliari|Monza
    33|Frosinone|AS Roma
    33|Genoa|Sassuolo
    33|Inter|Bologna
    33|Juventus|Fiorentina
    33|Lazio|Como
    33|Lecce|AC Milan
    33|Napoli|Udinese
    33|Parma|Atalanta
    33|Venezia|Torino
    34|AC Milan|Lazio
    34|AS Roma|Napoli
    34|Atalanta|Juventus
    34|Bologna|Fiorentina
    34|Como|Inter
    34|Lecce|Cagliari
    34|Monza|Venezia
    34|Sassuolo|Frosinone
    34|Torino|Parma
    34|Udinese|Genoa
    35|Fiorentina|AS Roma
    35|Frosinone|Atalanta
    35|Genoa|Cagliari
    35|Inter|Lecce
    35|Lazio|Sassuolo
    35|Napoli|Monza
    35|Parma|AC Milan
    35|Torino|Bologna
    35|Udinese|Juventus
    35|Venezia|Como
    36|AC Milan|AS Roma
    36|Bologna|Frosinone
    36|Cagliari|Torino
    36|Como|Atalanta
    36|Juventus|Inter
    36|Lazio|Udinese
    36|Lecce|Fiorentina
    36|Monza|Parma
    36|Napoli|Genoa
    36|Sassuolo|Venezia
    37|AS Roma|Como
    37|Atalanta|Lecce
    37|Fiorentina|Monza
    37|Frosinone|Cagliari
    37|Genoa|Bologna
    37|Inter|Lazio
    37|Parma|Juventus
    37|Torino|Napoli
    37|Udinese|Sassuolo
    37|Venezia|AC Milan
    38|AC Milan|Udinese
    38|Bologna|Parma
    38|Cagliari|AS Roma
    38|Como|Genoa
    38|Juventus|Frosinone
    38|Lazio|Fiorentina
    38|Lecce|Venezia
    38|Monza|Torino
    38|Napoli|Atalanta
    38|Sassuolo|Inter
    """

    static let laLiga2627 = """
    1|Alaves|Getafe
    1|Atletico Madrid|Malaga
    1|Barcelona|Athletic Club
    1|Celta Vigo|Osasuna
    1|Deportivo La Coruna|Elche
    1|Espanyol|Levante
    1|Racing Santander|Villarreal
    1|Real Madrid|Real Sociedad
    1|Sevilla|Rayo Vallecano
    1|Valencia|Real Betis
    2|Athletic Club|Sevilla
    2|Atletico Madrid|Villarreal
    2|Elche|Barcelona
    2|Espanyol|Real Madrid
    2|Getafe|Racing Santander
    2|Malaga|Deportivo La Coruna
    2|Osasuna|Levante
    2|Rayo Vallecano|Alaves
    2|Real Betis|Real Sociedad
    2|Valencia|Celta Vigo
    3|Alaves|Villarreal
    3|Barcelona|Rayo Vallecano
    3|Celta Vigo|Athletic Club
    3|Deportivo La Coruna|Valencia
    3|Levante|Real Betis
    3|Osasuna|Getafe
    3|Racing Santander|Elche
    3|Real Madrid|Malaga
    3|Real Sociedad|Espanyol
    3|Sevilla|Atletico Madrid
    4|Alaves|Osasuna
    4|Athletic Club|Atletico Madrid
    4|Elche|Real Sociedad
    4|Espanyol|Sevilla
    4|Getafe|Celta Vigo
    4|Malaga|Levante
    4|Rayo Vallecano|Racing Santander
    4|Real Betis|Real Madrid
    4|Valencia|Barcelona
    4|Villarreal|Deportivo La Coruna
    5|Athletic Club|Elche
    5|Celta Vigo|Malaga
    5|Getafe|Deportivo La Coruna
    5|Levante|Barcelona
    5|Osasuna|Espanyol
    5|Racing Santander|Alaves
    5|Real Madrid|Rayo Vallecano
    5|Real Sociedad|Atletico Madrid
    5|Sevilla|Valencia
    5|Villarreal|Real Betis
    6|Alaves|Valencia
    6|Atletico Madrid|Osasuna
    6|Barcelona|Racing Santander
    6|Deportivo La Coruna|Sevilla
    6|Elche|Real Madrid
    6|Levante|Athletic Club
    6|Malaga|Villarreal
    6|Rayo Vallecano|Espanyol
    6|Real Betis|Getafe
    6|Real Sociedad|Celta Vigo
    7|Athletic Club|Alaves
    7|Atletico Madrid|Real Madrid
    7|Celta Vigo|Racing Santander
    7|Deportivo La Coruna|Real Betis
    7|Espanyol|Elche
    7|Getafe|Malaga
    7|Osasuna|Rayo Vallecano
    7|Sevilla|Barcelona
    7|Valencia|Real Sociedad
    7|Villarreal|Levante
    8|Alaves|Atletico Madrid
    8|Barcelona|Getafe
    8|Elche|Celta Vigo
    8|Levante|Sevilla
    8|Malaga|Espanyol
    8|Racing Santander|Valencia
    8|Rayo Vallecano|Athletic Club
    8|Real Betis|Osasuna
    8|Real Madrid|Villarreal
    8|Real Sociedad|Deportivo La Coruna
    9|Celta Vigo|Alaves
    9|Deportivo La Coruna|Levante
    9|Espanyol|Atletico Madrid
    9|Getafe|Rayo Vallecano
    9|Malaga|Real Sociedad
    9|Osasuna|Racing Santander
    9|Real Betis|Barcelona
    9|Real Madrid|Sevilla
    9|Valencia|Athletic Club
    9|Villarreal|Elche
    10|Alaves|Malaga
    10|Athletic Club|Getafe
    10|Atletico Madrid|Deportivo La Coruna
    10|Barcelona|Real Madrid
    10|Celta Vigo|Real Betis
    10|Racing Santander|Espanyol
    10|Rayo Vallecano|Elche
    10|Real Sociedad|Levante
    10|Sevilla|Osasuna
    10|Valencia|Villarreal
    11|Athletic Club|Real Sociedad
    11|Barcelona|Alaves
    11|Deportivo La Coruna|Osasuna
    11|Elche|Valencia
    11|Getafe|Sevilla
    11|Levante|Atletico Madrid
    11|Racing Santander|Real Madrid
    11|Rayo Vallecano|Celta Vigo
    11|Real Betis|Malaga
    11|Villarreal|Espanyol
    12|Atletico Madrid|Barcelona
    12|Celta Vigo|Levante
    12|Elche|Real Betis
    12|Espanyol|Deportivo La Coruna
    12|Malaga|Racing Santander
    12|Osasuna|Athletic Club
    12|Real Sociedad|Rayo Vallecano
    12|Sevilla|Alaves
    12|Valencia|Real Madrid
    12|Villarreal|Getafe
    13|Alaves|Deportivo La Coruna
    13|Athletic Club|Espanyol
    13|Barcelona|Villarreal
    13|Getafe|Atletico Madrid
    13|Levante|Elche
    13|Osasuna|Malaga
    13|Racing Santander|Real Sociedad
    13|Rayo Vallecano|Valencia
    13|Real Madrid|Celta Vigo
    13|Sevilla|Real Betis
    14|Celta Vigo|Villarreal
    14|Deportivo La Coruna|Barcelona
    14|Elche|Atletico Madrid
    14|Espanyol|Getafe
    14|Levante|Racing Santander
    14|Malaga|Athletic Club
    14|Real Betis|Rayo Vallecano
    14|Real Madrid|Alaves
    14|Real Sociedad|Sevilla
    14|Valencia|Osasuna
    15|Alaves|Espanyol
    15|Athletic Club|Real Madrid
    15|Atletico Madrid|Real Betis
    15|Barcelona|Celta Vigo
    15|Getafe|Valencia
    15|Osasuna|Elche
    15|Racing Santander|Deportivo La Coruna
    15|Rayo Vallecano|Levante
    15|Sevilla|Malaga
    15|Villarreal|Real Sociedad
    16|Atletico Madrid|Valencia
    16|Deportivo La Coruna|Athletic Club
    16|Elche|Sevilla
    16|Espanyol|Celta Vigo
    16|Levante|Alaves
    16|Malaga|Barcelona
    16|Real Betis|Racing Santander
    16|Real Madrid|Osasuna
    16|Real Sociedad|Getafe
    16|Villarreal|Rayo Vallecano
    17|Alaves|Elche
    17|Athletic Club|Real Betis
    17|Barcelona|Real Sociedad
    17|Celta Vigo|Atletico Madrid
    17|Deportivo La Coruna|Real Madrid
    17|Getafe|Levante
    17|Osasuna|Villarreal
    17|Rayo Vallecano|Malaga
    17|Sevilla|Racing Santander
    17|Valencia|Espanyol
    18|Celta Vigo|Deportivo La Coruna
    18|Espanyol|Barcelona
    18|Levante|Valencia
    18|Malaga|Elche
    18|Racing Santander|Athletic Club
    18|Rayo Vallecano|Atletico Madrid
    18|Real Betis|Alaves
    18|Real Madrid|Getafe
    18|Real Sociedad|Osasuna
    18|Villarreal|Sevilla
    19|Alaves|Real Sociedad
    19|Athletic Club|Villarreal
    19|Atletico Madrid|Racing Santander
    19|Deportivo La Coruna|Rayo Vallecano
    19|Elche|Getafe
    19|Espanyol|Real Betis
    19|Osasuna|Barcelona
    19|Real Madrid|Levante
    19|Sevilla|Celta Vigo
    19|Valencia|Malaga
    20|Atletico Madrid|Real Sociedad
    20|Barcelona|Elche
    20|Celta Vigo|Valencia
    20|Getafe|Athletic Club
    20|Levante|Espanyol
    20|Malaga|Real Madrid
    20|Racing Santander|Osasuna
    20|Rayo Vallecano|Sevilla
    20|Real Betis|Deportivo La Coruna
    20|Villarreal|Alaves
    21|Alaves|Barcelona
    21|Athletic Club|Levante
    21|Deportivo La Coruna|Atletico Madrid
    21|Elche|Rayo Vallecano
    21|Espanyol|Villarreal
    21|Getafe|Osasuna
    21|Racing Santander|Celta Vigo
    21|Real Madrid|Real Betis
    21|Real Sociedad|Malaga
    21|Valencia|Sevilla
    22|Atletico Madrid|Espanyol
    22|Barcelona|Valencia
    22|Celta Vigo|Getafe
    22|Levante|Real Sociedad
    22|Malaga|Alaves
    22|Osasuna|Deportivo La Coruna
    22|Rayo Vallecano|Real Madrid
    22|Real Betis|Elche
    22|Sevilla|Athletic Club
    22|Villarreal|Racing Santander
    23|Alaves|Celta Vigo
    23|Athletic Club|Osasuna
    23|Barcelona|Atletico Madrid
    23|Deportivo La Coruna|Malaga
    23|Elche|Levante
    23|Espanyol|Rayo Vallecano
    23|Getafe|Villarreal
    23|Real Betis|Sevilla
    23|Real Sociedad|Real Madrid
    23|Valencia|Racing Santander
    24|Celta Vigo|Rayo Vallecano
    24|Elche|Deportivo La Coruna
    24|Levante|Malaga
    24|Osasuna|Atletico Madrid
    24|Racing Santander|Getafe
    24|Real Madrid|Athletic Club
    24|Real Sociedad|Real Betis
    24|Sevilla|Espanyol
    24|Valencia|Alaves
    24|Villarreal|Barcelona
    25|Alaves|Racing Santander
    25|Athletic Club|Celta Vigo
    25|Atletico Madrid|Elche
    25|Barcelona|Levante
    25|Deportivo La Coruna|Real Sociedad
    25|Espanyol|Osasuna
    25|Malaga|Real Betis
    25|Rayo Vallecano|Getafe
    25|Sevilla|Real Madrid
    25|Villarreal|Valencia
    26|Athletic Club|Barcelona
    26|Celta Vigo|Espanyol
    26|Getafe|Alaves
    26|Levante|Deportivo La Coruna
    26|Malaga|Atletico Madrid
    26|Osasuna|Sevilla
    26|Racing Santander|Rayo Vallecano
    26|Real Betis|Villarreal
    26|Real Madrid|Valencia
    26|Real Sociedad|Elche
    27|Alaves|Athletic Club
    27|Atletico Madrid|Celta Vigo
    27|Barcelona|Real Betis
    27|Deportivo La Coruna|Getafe
    27|Elche|Malaga
    27|Espanyol|Racing Santander
    27|Rayo Vallecano|Osasuna
    27|Sevilla|Real Sociedad
    27|Valencia|Levante
    27|Villarreal|Real Madrid
    28|Alaves|Sevilla
    28|Athletic Club|Valencia
    28|Barcelona|Deportivo La Coruna
    28|Elche|Villarreal
    28|Getafe|Real Sociedad
    28|Malaga|Rayo Vallecano
    28|Osasuna|Celta Vigo
    28|Racing Santander|Atletico Madrid
    28|Real Betis|Levante
    28|Real Madrid|Espanyol
    29|Atletico Madrid|Getafe
    29|Celta Vigo|Real Madrid
    29|Espanyol|Athletic Club
    29|Levante|Osasuna
    29|Racing Santander|Real Betis
    29|Rayo Vallecano|Barcelona
    29|Real Sociedad|Alaves
    29|Sevilla|Elche
    29|Valencia|Deportivo La Coruna
    29|Villarreal|Malaga
    30|Athletic Club|Racing Santander
    30|Barcelona|Sevilla
    30|Deportivo La Coruna|Villarreal
    30|Elche|Alaves
    30|Getafe|Espanyol
    30|Levante|Rayo Vallecano
    30|Malaga|Osasuna
    30|Real Betis|Celta Vigo
    30|Real Madrid|Atletico Madrid
    30|Real Sociedad|Valencia
    31|Alaves|Real Betis
    31|Atletico Madrid|Levante
    31|Celta Vigo|Elche
    31|Espanyol|Malaga
    31|Osasuna|Real Madrid
    31|Racing Santander|Barcelona
    31|Rayo Vallecano|Real Sociedad
    31|Sevilla|Deportivo La Coruna
    31|Valencia|Getafe
    31|Villarreal|Athletic Club
    32|Alaves|Rayo Vallecano
    32|Atletico Madrid|Sevilla
    32|Barcelona|Espanyol
    32|Deportivo La Coruna|Celta Vigo
    32|Elche|Osasuna
    32|Getafe|Real Madrid
    32|Levante|Villarreal
    32|Malaga|Valencia
    32|Real Betis|Athletic Club
    32|Real Sociedad|Racing Santander
    33|Athletic Club|Deportivo La Coruna
    33|Celta Vigo|Barcelona
    33|Espanyol|Real Sociedad
    33|Getafe|Real Betis
    33|Osasuna|Alaves
    33|Racing Santander|Malaga
    33|Real Madrid|Elche
    33|Sevilla|Levante
    33|Valencia|Rayo Vallecano
    33|Villarreal|Atletico Madrid
    34|Atletico Madrid|Alaves
    34|Barcelona|Osasuna
    34|Celta Vigo|Sevilla
    34|Deportivo La Coruna|Racing Santander
    34|Elche|Espanyol
    34|Levante|Real Madrid
    34|Malaga|Getafe
    34|Rayo Vallecano|Villarreal
    34|Real Betis|Valencia
    34|Real Sociedad|Athletic Club
    35|Alaves|Levante
    35|Athletic Club|Malaga
    35|Getafe|Elche
    35|Osasuna|Real Sociedad
    35|Racing Santander|Sevilla
    35|Rayo Vallecano|Deportivo La Coruna
    35|Real Betis|Espanyol
    35|Real Madrid|Barcelona
    35|Valencia|Atletico Madrid
    35|Villarreal|Celta Vigo
    36|Atletico Madrid|Rayo Vallecano
    36|Deportivo La Coruna|Alaves
    36|Elche|Athletic Club
    36|Espanyol|Valencia
    36|Levante|Getafe
    36|Malaga|Celta Vigo
    36|Osasuna|Real Betis
    36|Real Madrid|Racing Santander
    36|Real Sociedad|Barcelona
    36|Sevilla|Villarreal
    37|Alaves|Real Madrid
    37|Atletico Madrid|Athletic Club
    37|Barcelona|Malaga
    37|Celta Vigo|Real Sociedad
    37|Deportivo La Coruna|Espanyol
    37|Racing Santander|Levante
    37|Rayo Vallecano|Real Betis
    37|Sevilla|Getafe
    37|Valencia|Elche
    37|Villarreal|Osasuna
    38|Athletic Club|Rayo Vallecano
    38|Elche|Racing Santander
    38|Espanyol|Alaves
    38|Getafe|Barcelona
    38|Levante|Celta Vigo
    38|Malaga|Sevilla
    38|Osasuna|Valencia
    38|Real Betis|Atletico Madrid
    38|Real Madrid|Deportivo La Coruna
    38|Real Sociedad|Villarreal
    """
}
