// CairoHinglishMap.js: 18 Custom Angular SVG Paths, Multilingual Normalizer, & Keyword Engine for Carbon // Cairo
// Strictly 0% Unicode Emojis. Native 24x24 EvenOdd SVG Paths.

.pragma library

var GLYPH_PATHS = {
    "ishq_heart": "M12 21.4 C12 21.4 3.0 15.2 3.0 8.8 C3.0 5.4 5.6 3.0 8.6 3.0 C10.4 3.0 11.4 3.9 12 4.9 C12.6 3.9 13.6 3.0 15.4 3.0 C18.4 3.0 21.0 5.4 21.0 8.8 C21.0 15.2 12 21.4 12 21.4 Z M13.2 7.2 L9.2 12.5 L12.2 12.5 L10.8 16.8 L14.8 11.5 L11.8 11.5 Z M20.5 1.2 L21.2 3.0 L23.0 3.7 L21.2 4.4 L20.5 6.2 L19.8 4.4 L18.0 3.7 L19.8 3.0 Z",
    "jaan_sparkle": "M10.0 1.0 Q10.0 10.0 19.0 10.0 Q10.0 10.0 10.0 19.0 Q10.0 10.0 1.0 10.0 Q10.0 10.0 10.0 1.0 Z M10.0 7.5 A2.5 2.5 0 1 0 10.0 12.5 A2.5 2.5 0 1 0 10.0 7.5 Z M18.5 13.0 Q18.5 18.0 23.5 18.0 Q18.5 18.0 18.5 23.0 Q18.5 18.0 13.5 18.0 Q18.5 18.0 18.5 13.0 Z M4.5 17.5 Q4.5 20.0 7.0 20.0 Q4.5 20.0 4.5 22.5 Q4.5 20.0 2.0 20.0 Q4.5 20.0 4.5 17.5 Z",
    "naina_eye": "M1.2 12.0 C4.5 6.0 8.2 4.0 12.0 4.0 C15.8 4.0 19.5 6.0 22.8 12.0 C19.5 18.0 15.8 20.0 12.0 20.0 C8.2 20.0 4.5 18.0 1.2 12.0 Z M12.0 7.0 A5.0 5.0 0 1 0 12.0 17.0 A5.0 5.0 0 1 0 12.0 7.0 Z M13.8 8.8 A1.8 1.8 0 1 0 13.8 12.4 A1.8 1.8 0 1 0 13.8 8.8 Z",
    "raat_moon": "M14.8 2.2 C9.2 2.8 5.0 7.5 5.0 13.2 C5.0 17.2 7.2 20.8 10.6 22.5 C5.4 22.0 1.5 17.6 1.5 12.2 C1.5 6.4 6.2 1.8 12.0 1.8 C13.0 1.8 14.0 1.9 14.8 2.2 Z M18.0 4.5 Q18.0 9.0 22.5 9.0 Q18.0 9.0 18.0 13.5 Q18.0 9.0 13.5 9.0 Q18.0 9.0 18.0 4.5 Z M12.5 17.5 C12.5 16.7 13.2 16.0 14.0 16.0 L20.5 16.0 C21.3 16.0 22.0 16.7 22.0 17.5 C22.0 18.3 21.3 19.0 20.5 19.0 L14.0 19.0 C13.2 19.0 12.5 18.3 12.5 17.5 Z",
    "gaddi_car": "M2.5 13.5 L5.8 6.5 C6.3 5.5 7.3 5 8.5 5 L15.5 5 C16.7 5 17.7 5.5 18.2 6.5 L21.5 13.5 L23 14.5 L22.2 19.5 L19.5 19.5 L19.5 17.5 L4.5 17.5 L4.5 19.5 L1.8 19.5 L1 14.5 Z M6.8 7.2 L5.2 11.2 L18.8 11.2 L17.2 7.2 Z M4.2 13.5 L8.5 14.8 L8.2 16.2 L3.8 15.2 Z M19.8 13.5 L15.5 14.8 L15.8 16.2 L20.2 15.2 Z",
    "aag_fire": "M12.8 1.2 C15.2 4.8 19.8 8.2 19.8 14.0 C19.8 18.8 16.2 22.5 11.8 22.5 C7.2 22.5 4.2 19.0 4.2 14.5 C4.2 11.2 6.2 8.2 7.8 6.8 C7.2 9.2 8.2 11.0 9.6 11.5 C8.8 7.5 10.5 3.8 12.8 1.2 Z M12.0 13.2 C10.2 14.8 9.2 16.5 9.8 18.5 C10.2 19.8 11.5 20.5 13.0 20.0 C14.5 19.4 15.2 17.5 14.2 15.5 C13.6 14.4 12.8 13.8 12.0 13.2 Z M18.5 3.0 A1.5 1.5 0 1 0 18.5 6.0 A1.5 1.5 0 1 0 18.5 3.0 Z",
    "baarish_drop": "M12.0 1.8 C12.0 1.8 19.0 9.8 19.0 14.8 C19.0 18.7 15.9 21.8 12.0 21.8 C8.1 21.8 5.0 18.7 5.0 14.8 C5.0 9.8 12.0 1.8 12.0 1.8 Z M9.2 11.5 C8.2 13.2 8.5 15.8 10.2 17.2 C10.8 17.7 11.6 17.2 11.2 16.5 C10.0 15.2 9.8 13.5 10.6 12.0 C11.0 11.2 9.8 10.6 9.2 11.5 Z M19.5 4.0 A1.4 1.4 0 1 0 19.5 6.8 A1.4 1.4 0 1 0 19.5 4.0 Z",
    "kismat_dice": "M3.5 5.5 L12.5 3.2 L14.8 12.2 L5.8 14.5 Z M7.2 7.2 A1.1 1.1 0 1 0 7.2 9.4 A1.1 1.1 0 1 0 7.2 7.2 Z M11.0 9.8 A1.1 1.1 0 1 0 11.0 12.0 A1.1 1.1 0 1 0 11.0 9.8 Z M11.5 15.5 L15.2 14.5 L16.2 10.8 L20.8 12.2 L18.5 20.8 L10.2 18.5 Z M15.8 15.8 A1.1 1.1 0 1 0 15.8 18.0 A1.1 1.1 0 1 0 15.8 15.8 Z",
    "taj_crown": "M2.5 18.0 L4.2 7.5 Q8.0 13.0 12.0 4.5 Q16.0 13.0 19.8 7.5 L21.5 18.0 C21.5 19.1 20.6 20.0 19.5 20.0 L4.5 20.0 C3.4 20.0 2.5 19.1 2.5 18.0 Z M12.0 11.5 Q12.0 14.0 14.5 14.0 Q12.0 14.0 12.0 16.5 Q12.0 14.0 9.5 14.0 Q12.0 14.0 12.0 11.5 Z M4.0 4.2 A1.3 1.3 0 1 0 4.0 6.8 A1.3 1.3 0 1 0 4.0 4.2 Z M12.0 1.2 A1.4 1.4 0 1 0 12.0 4.0 A1.4 1.4 0 1 0 12.0 1.2 Z M20.0 4.2 A1.3 1.3 0 1 0 20.0 6.8 A1.3 1.3 0 1 0 20.0 4.2 Z",
    "dard_broken": "M11.2 4.5 L9.0 10.5 L13.2 12.2 L9.8 19.8 L3.2 13.0 C0.8 10.5 0.8 6.5 3.2 4.0 C5.4 1.8 8.8 1.8 11.2 4.5 Z M13.8 4.2 C16.0 2.0 19.2 2.2 21.2 4.4 C23.6 6.8 23.4 10.8 21.0 13.2 L12.5 21.8 L15.2 13.8 L11.0 12.0 L13.8 4.2 Z",
    "tanha_solo": "M12 2.5 C14.6 2.5 16.8 4.6 16.8 7.2 C16.8 9.8 14.6 12.0 12 12.0 C9.4 12.0 7.2 9.8 7.2 7.2 C7.2 4.6 9.4 2.5 12 2.5 Z M3.2 21.5 C3.8 16.2 7.2 13.8 12 13.8 C16.8 13.8 20.2 16.2 20.8 21.5 L14.2 21.5 L15.8 16.2 L13.8 16.2 L12.2 21.5 Z",
    "waqt_time": "M4.5 2.0 L19.5 2.0 L18.8 4.2 L13.8 11.5 L18.8 19.8 L19.5 22.0 L4.5 22.0 L5.2 19.8 L10.2 11.5 L5.2 4.2 Z M7.8 4.5 L16.2 4.5 L12.0 10.2 Z M12.0 13.8 L8.5 19.2 L15.5 19.2 Z",
    "khwab_cloud": "M6.5 19.5 C3.7 19.5 1.5 17.3 1.5 14.5 C1.5 12.0 3.3 9.9 5.7 9.6 C6.6 6.2 9.7 3.8 13.4 3.8 C17.6 3.8 21.0 7.1 21.2 11.2 C22.5 12.0 23.2 13.4 23.2 15.0 C23.2 17.5 21.2 19.5 18.7 19.5 Z M14.5 8.5 Q14.5 12.0 18.0 12.0 Q14.5 12.0 14.5 15.5 Q14.5 12.0 11.0 12.0 Q14.5 12.0 14.5 8.5 Z",
    "sona_diamond": "M6.2 3.0 L17.8 3.0 L22.5 9.2 L12.0 21.8 L1.5 9.2 Z M7.5 5.2 L4.5 9.0 L9.2 9.0 Z M12.0 5.2 L10.2 9.0 L13.8 9.0 Z M16.5 5.2 L14.8 9.0 L19.5 9.0 Z M5.2 10.8 L10.8 18.2 L9.5 10.8 Z M13.2 18.2 L18.8 10.8 L14.5 10.8 Z",
    "dhun_play": "M9.0 17.5 A3.2 3.2 0 1 1 5.8 14.3 C6.6 14.3 7.2 14.5 7.6 14.8 L7.6 5.2 L20.2 2.8 L20.2 15.2 A3.2 3.2 0 1 1 17.0 12.0 C17.8 12.0 18.4 12.2 18.8 12.5 L18.8 6.8 L9.0 8.6 Z M3.5 6.0 Q3.5 8.5 6.0 8.5 Q3.5 8.5 3.5 11.0 Q3.5 8.5 1.0 8.5 Q3.5 8.5 3.5 6.0 Z",
    "dhun_music": "M9.0 17.5 A3.2 3.2 0 1 1 5.8 14.3 C6.6 14.3 7.2 14.5 7.6 14.8 L7.6 5.2 L20.2 2.8 L20.2 15.2 A3.2 3.2 0 1 1 17.0 12.0 C17.8 12.0 18.4 12.2 18.8 12.5 L18.8 6.8 L9.0 8.6 Z M3.5 6.0 Q3.5 8.5 6.0 8.5 Q3.5 8.5 3.5 11.0 Q3.5 8.5 1.0 8.5 Q3.5 8.5 3.5 6.0 Z",
    "bass_wave": "M3.0 9.0 C3.8 9.0 4.5 9.7 4.5 10.5 L4.5 14.5 C4.5 15.3 3.8 16.0 3.0 16.0 C2.2 16.0 1.5 15.3 1.5 14.5 L1.5 10.5 C1.5 9.7 2.2 9.0 3.0 9.0 Z M7.5 5.0 C8.3 5.0 9.0 5.7 9.0 6.5 L9.0 18.5 C9.0 19.3 8.3 20.0 7.5 20.0 C6.7 20.0 6.0 19.3 6.0 18.5 L6.0 6.5 C6.0 5.7 6.7 5.0 7.5 5.0 Z M12.0 1.5 C12.8 1.5 13.5 2.2 13.5 3.0 L13.5 21.0 C13.5 21.8 12.8 22.5 12.0 22.5 C11.2 22.5 10.5 21.8 10.5 21.0 L10.5 3.0 C10.5 2.2 11.2 1.5 12.0 1.5 Z M16.5 5.0 C17.3 5.0 18.0 5.7 18.0 6.5 L18.0 18.5 C18.0 19.3 17.3 20.0 16.5 20.0 C15.7 20.0 15.0 19.3 15.0 18.5 L15.0 6.5 C15.0 5.7 15.7 5.0 16.5 5.0 Z M21.0 9.0 C21.8 9.0 22.5 9.7 22.5 10.5 L22.5 14.5 C22.5 15.3 21.8 16.0 21.0 16.0 C20.2 16.0 19.5 15.3 19.5 14.5 L19.5 10.5 C19.5 9.7 20.2 9.0 21.0 9.0 Z",
    "jaam_chalice": "M2.5 3.5 L21.5 3.5 L13.2 13.5 L13.2 19.5 L18.0 19.5 L17.4 21.8 L6.0 21.8 L6.6 19.5 L10.8 19.5 L10.8 13.5 Z M5.8 5.8 L9.8 10.6 L18.2 5.8 Z M16.5 1.2 L17.8 2.5 L16.5 3.8 L15.2 2.5 Z",
    "nasha_vortex": "M12.0 2.0 C17.5 2.0 22.0 6.5 22.0 12.0 C22.0 17.5 17.5 22.0 12.0 22.0 C6.5 22.0 2.0 17.5 2.0 12.0 C2.0 6.5 6.5 2.0 12.0 2.0 Z M12.0 5.0 C8.1 5.0 5.0 8.1 5.0 12.0 C5.0 14.8 7.2 17.0 10.0 17.0 C12.2 17.0 14.0 15.2 14.0 13.0 C14.0 11.3 12.7 10.0 11.0 10.0 C9.9 10.0 9.0 10.9 9.0 12.0 C9.0 12.6 9.4 13.0 10.0 13.0 L10.0 14.5 C8.6 14.5 7.5 13.4 7.5 12.0 C7.5 10.1 9.1 8.5 11.0 8.5 C13.5 8.5 15.5 10.5 15.5 13.0 C15.5 16.0 13.0 18.5 10.0 18.5 C6.4 18.5 3.5 15.6 3.5 12.0 C3.5 7.3 7.3 3.5 12.0 3.5 C16.7 3.5 20.5 7.3 20.5 12.0 L19.0 12.0 C19.0 8.1 15.9 5.0 12.0 5.0 Z",
    "bijli_bolt": "M14.8 1.2 L4.2 13.2 L11.2 13.2 L8.8 22.8 L19.8 10.5 L12.8 10.5 Z",
    "rhythm_accent": "M9.0 2.0 Q9.0 9.0 16.0 9.0 Q9.0 9.0 9.0 16.0 Q9.0 9.0 2.0 9.0 Q9.0 9.0 9.0 2.0 Z M17.5 12.5 Q17.5 17.5 22.5 17.5 Q17.5 17.5 17.5 22.5 Q17.5 17.5 12.5 17.5 Q17.5 17.5 17.5 12.5 Z M6.5 16.5 A2.0 2.0 0 1 0 6.5 20.5 A2.0 2.0 0 1 0 6.5 16.5 Z"
};

var RAW_BUCKETS = {
    // 1. ISHQ_HEART
    "ishq_heart": [
        "love", "loving", "lover", "heart", "hearts", "heartbeat",
        "dil", "dila", "dilda", "pyar", "pyaar", "ishq", "ishqe", "mohabbat",
        "chahat", "dhadkan", "dilbar", "diljaniya", "premi", "aashiq", "ashiq",
        "दिल", "प्यार", "इश्क़", "मोहब्बत", "धड़कन", "चाहत"
    ],

    // 2. JAAN_SPARKLE (Replaces person/baby icon!)
    "jaan_sparkle": [
        "baby", "babe", "darling", "shawty", "honey", "angel", "beautiful", "stunning", "gorgeous",
        "jaan", "jan", "jaanu", "janu", "jana", "piya", "mahiya", "heeriye", "hiriye",
        "sohniye", "sohna", "sajna", "sajan", "sanam", "mehboob", "habibi", "kudi", "kudiye", "billo",
        "हसीन", "जान", "पिया", "सजना", "सनम", "हीरिये"
    ],

    // 3. NAINA_EYE
    "naina_eye": [
        "eye", "eyes", "look", "looking", "see", "stare", "gaze", "mirror", "mirrors", "vision",
        "naina", "nain", "naino", "akh", "akhiyan", "aankh", "aankhein", "ankhen",
        "nazar", "nazrein", "kajal", "surma", "palak", "palkein",
        "नैना", "आँख", "आँखें", "नज़र", "काजल"
    ],

    // 4. RAAT_MOON
    "raat_moon": [
        "night", "nights", "tonight", "midnight", "moon", "moonlight", "dark", "darkest", "darkness", "shadow",
        "raat", "rat", "raataan", "ratan", "raatein", "chand", "chaand", "chandni", "andhera",
        "shaam", "sham", "savera",
        "रात", "चाँद", "चाँदनी", "अंधेरा", "शाम"
    ],

    // 5. GADDI_CAR
    "gaddi_car": [
        "car", "cars", "drive", "driving", "ride", "riding", "road", "highway", "speed", "fast", "whip",
        "gaddi", "gaddiyan", "rasta", "raaste", "safar", "rah", "raah", "manzil",
        "सफ़र", "रास्ता", "गाड़ी", "मंज़िल"
    ],

    // 6. AAG_FIRE
    "aag_fire": [
        "fire", "burn", "burning", "flame", "flames", "smoke", "heat", "hot", "lit", "ashes",
        "aag", "ag", "jal", "jalna", "jale", "dhuan", "dhua", "shola", "angaare", "garmi",
        "आग", "धुआँ", "शोला"
    ],

    // 7. BAARISH_DROP
    "baarish_drop": [
        "rain", "raining", "cry", "crying", "tear", "tears", "water", "ocean", "sea", "drown", "pour",
        "baarish", "barish", "barsaat", "barsat", "saawan", "sawan", "boondein", "bheega", "bhiga",
        "aansu", "ansu", "samandar", "dariya", "paani", "pani",
        "बारिश", "आँसू", "सावन", "समंदर", "दरिया", "पानी"
    ],

    // 8. KISMAT_DICE
    "kismat_dice": [
        "chance", "chances", "luck", "lucky", "dice", "roll", "bet", "gamble", "game", "risk",
        "kismat", "taqdeer", "naseeb", "bazi", "baazi", "khel",
        "क़िस्मत", "नसीब", "बाज़ी"
    ],

    // 9. TAJ_CROWN
    "taj_crown": [
        "king", "queen", "crown", "royal", "throne", "boss", "legend",
        "taj", "badshah", "rani", "shah", "sultan", "gabru", "jatt", "sardar", "nawab",
        "ताज", "बादशाह", "रानी"
    ],

    // 10. DARD_BROKEN
    "dard_broken": [
        "broken", "break", "hurt", "pain", "bleed", "bleeding", "scar", "scars", "shame", "lie", "lies", "fake",
        "dard", "zakham", "tuta", "toota", "bewafa", "dhoka", "judai",
        "जुदाई", "दर्द", "ज़ख़्म", "बेवफ़ा", "टूटा"
    ],

    // 11. TANHA_SOLO (Strictly Solitary/Identity words. NEVER baby/boy/girl/you/me)
    "tanha_solo": [
        "alone", "lonely", "somebody", "nobody", "stranger", "myself", "yourself",
        "tanha", "akela", "akele", "khud", "ajnabi",
        "तन्हा", "अकेला", "अजनबी"
    ],

    // 12. WAQT_TIME
    "waqt_time": [
        "time", "wait", "waiting", "waitin", "forever", "always", "never", "clock", "hour", "hours", "moment", "past", "future",
        "waqt", "lamha", "lamhe", "pal", "sadiyan", "intezaar", "intezar", "hamesha",
        "वक़्त", "लम्हा", "पल", "इंतज़ार", "हमेशा"
    ],

    // 13. KHWAB_CLOUD
    "khwab_cloud": [
        "dream", "dreams", "dreaming", "sky", "skies", "cloud", "clouds", "heaven", "fly", "flying", "high", "float",
        "khwab", "khwaab", "sapna", "sapne", "aasman", "asman", "badal", "baadal", "hawa", "hawaein", "parinde",
        "ख़्वाब", "सपना", "सपने", "आसमान", "बादल", "हवा"
    ],

    // 14. SONA_DIAMOND
    "sona_diamond": [
        "diamond", "diamonds", "gold", "golden", "money", "cash", "rich", "shine", "shining", "miracle", "priceless", "treasure", "finesse",
        "sona", "sone", "heera", "hira", "daulat", "paisa", "noor", "nur", "chamak", "taare", "tare", "sitara",
        "सितारा", "सोना", "हीरा", "नूर"
    ],

    // 15. DHUN_PLAY
    "dhun_play": [
        "start", "play", "music", "song", "beat", "sound", "sing", "voice", "dance", "move",
        "dhun", "geet", "gaana", "gana", "aawaz", "awaz", "sur", "saaz",
        "ताल", "धुन", "गीत", "आवाज़"
    ],

    // 16. JAAM_CHALICE
    "jaam_chalice": [
        "drink", "drinking", "sip", "cup", "glass", "wine", "liquor", "bottle", "poison", "taste",
        "sharab", "sharaab", "jaam", "jam", "maikhana", "daaru", "daru", "peg", "zahar", "zeher",
        "शराब", "जाम", "ज़हर", "पैमाना"
    ],

    // 17. NASHA_VORTEX
    "nasha_vortex": [
        "nasha", "nashe", "madhoshi", "madhosh", "khumar", "fitoor", "fitur", "junoon", "junun",
        "pagal", "deewana", "diwana", "dizzy", "trance", "crazy", "lose", "lost", "mind", "vibe",
        "नशा", "नशे", "मदहोशी", "फ़ितूर", "जुनून", "दीवाना"
    ],

    // 18. BIJLI_BOLT
    "bijli_bolt": [
        "thunder", "lightning", "electric", "electricity", "storm", "shock", "power",
        "switch", "button", "touch", "swish", "bijli", "toofan", "tufan",
        "बिजली", "तूफ़ान"
    ]
};

// Build inverted fast lookup map
var KEYWORD_MAP = {};

function initMap() {
    for (var motif in RAW_BUCKETS) {
        var words = RAW_BUCKETS[motif];
        for (var i = 0; i < words.length; i++) {
            var raw = words[i].trim().toLowerCase();
            if (raw.length > 0) {
                KEYWORD_MAP[raw] = motif;
            }
        }
    }
}
initMap();

/**
 * 1. Convert to lowercase & strip punctuation (/[.,!?;:'"()\[\]\-]/g)
 */
function normalizeLyricToken(rawWord) {
    if (!rawWord) return "";
    var s = String(rawWord).toLowerCase().trim();
    s = s.replace(/[.,!?;:'"()\[\]\-\/\`~@#$%^&*+=<>_{}]/g, "");
    return s;
}

/**
 * 2. Hinglish Stretched-Vowel Stemmer:
 *    - aa+ -> a
 *    - ee+ -> i
 *    - oo+ -> u
 *    - 3+ identical repeated letter collapse
 */
function stemHinglish(token) {
    if (!token || token.length < 3) return token;
    var s = token;
    s = s.replace(/(.)\1{2,}/g, "$1");
    s = s.replace(/aa+/g, "a");
    s = s.replace(/ee+/g, "i");
    s = s.replace(/oo+/g, "u");
    return s;
}

/**
 * 3. Strip common plural/oblique Hinglish suffixes:
 *    -iyaan, -iyan, -eyan, -aan, -ein, -on, -an
 */
function stripHinglishSuffix(token) {
    if (!token || token.length <= 3) return token;
    var s = token;
    if (s.endsWith("iyaan") && s.length > 5) return s.slice(0, -5);
    if (s.endsWith("iyan") && s.length > 4) return s.slice(0, -4);
    if (s.endsWith("eyan") && s.length > 4) return s.slice(0, -4);
    if (s.endsWith("aan") && s.length > 3) return s.slice(0, -3);
    if (s.endsWith("ein") && s.length > 3) return s.slice(0, -3);
    if (s.endsWith("on") && s.length > 3) return s.slice(0, -2);
    if (s.endsWith("an") && s.length > 3) return s.slice(0, -2);
    return s;
}

var STOP_WORDS = {
    "he": true, "she": true, "was": true, "is": true, "do": true,
    "what": true, "you": true, "you've": true, "youve": true, "been": true,
    "too": true, "out": true, "in": true, "on": true, "to": true,
    "the": true, "a": true, "an": true, "and": true, "or": true,
    "but": true, "it": true, "for": true, "of": true, "te": true,
    "ne": true, "ko": true, "se": true, "hai": true,
    "सी": true, "है": true, "ने": true
};

function isStopWord(word) {
    if (!word) return true;
    var norm = normalizeLyricToken(word);
    if (!norm) return true;
    return !!STOP_WORDS[norm];
}

/**
 * Lookup glyph by word:
 * Direct -> Stemmed -> Suffix-stripped
 * Blocked immediately if token matches STOP_WORDS.
 */
function lookupGlyphSingle(rawWord) {
    if (!rawWord) return "";
    var norm = normalizeLyricToken(rawWord);
    if (!norm || STOP_WORDS[norm]) return "";

    if (KEYWORD_MAP[norm]) return KEYWORD_MAP[norm];

    var stemmed = stemHinglish(norm);
    if (STOP_WORDS[stemmed]) return "";
    if (KEYWORD_MAP[stemmed]) return KEYWORD_MAP[stemmed];

    var suffStripped = stripHinglishSuffix(stemmed);
    if (STOP_WORDS[suffStripped]) return "";
    if (KEYWORD_MAP[suffStripped]) return KEYWORD_MAP[suffStripped];

    var directSuff = stripHinglishSuffix(norm);
    if (STOP_WORDS[directSuff]) return "";
    if (KEYWORD_MAP[directSuff]) return KEYWORD_MAP[directSuff];

    return "";
}

function lookupGlyph(rawWord) {
    if (!rawWord) return "";
    var trimmed = String(rawWord).trim();
    if (/\s+/.test(trimmed)) {
        var parts = trimmed.split(/\s+/);
        for (var i = 0; i < parts.length; i++) {
            var g = lookupGlyphSingle(parts[i]);
            if (g) return g;
        }
        return "";
    }
    return lookupGlyphSingle(trimmed);
}
