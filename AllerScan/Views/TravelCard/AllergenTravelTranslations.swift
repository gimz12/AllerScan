import Foundation

enum AllergenTravelTranslations {
    static func translate(_ allergen: Allergen, to language: TravelCardLanguage) -> String {
        table[allergen.id]?[language] ?? allergen.name
    }

    private static let table: [String: [TravelCardLanguage: String]] = [
        "milk": [
            .spanish: "Lácteos", .french: "Produits laitiers", .german: "Milch",
            .italian: "Latticini", .portuguese: "Lacticínios", .vietnamese: "Sữa",
            .russian: "Молоко", .ukrainian: "Молоко", .japanese: "乳製品",
            .korean: "유제품", .chineseSimplified: "乳制品", .chineseTraditional: "乳製品",
            .thai: "นม", .arabic: "منتجات الألبان"
        ],
        "egg": [
            .spanish: "Huevo", .french: "Œuf", .german: "Ei",
            .italian: "Uovo", .portuguese: "Ovo", .vietnamese: "Trứng",
            .russian: "Яйца", .ukrainian: "Яйця", .japanese: "卵",
            .korean: "달걀", .chineseSimplified: "鸡蛋", .chineseTraditional: "雞蛋",
            .thai: "ไข่", .arabic: "بيض"
        ],
        "peanut": [
            .spanish: "Cacahuetes", .french: "Arachides", .german: "Erdnüsse",
            .italian: "Arachidi", .portuguese: "Amendoins", .vietnamese: "Đậu phộng",
            .russian: "Арахис", .ukrainian: "Арахіс", .japanese: "ピーナッツ",
            .korean: "땅콩", .chineseSimplified: "花生", .chineseTraditional: "花生",
            .thai: "ถั่วลิสง", .arabic: "فول سوداني"
        ],
        "tree_nut": [
            .spanish: "Frutos secos", .french: "Fruits à coque", .german: "Nüsse",
            .italian: "Frutta a guscio", .portuguese: "Frutos secos", .vietnamese: "Các loại hạt",
            .russian: "Орехи", .ukrainian: "Горіхи", .japanese: "ナッツ類",
            .korean: "견과류", .chineseSimplified: "坚果", .chineseTraditional: "堅果",
            .thai: "ถั่วเปลือกแข็ง", .arabic: "المكسرات"
        ],
        "soy": [
            .spanish: "Soja", .french: "Soja", .german: "Soja",
            .italian: "Soia", .portuguese: "Soja", .vietnamese: "Đậu nành",
            .russian: "Соя", .ukrainian: "Соя", .japanese: "大豆",
            .korean: "콩", .chineseSimplified: "大豆", .chineseTraditional: "大豆",
            .thai: "ถั่วเหลือง", .arabic: "فول الصويا"
        ],
        "wheat": [
            .spanish: "Trigo / Gluten", .french: "Blé / Gluten", .german: "Weizen / Gluten",
            .italian: "Grano / Glutine", .portuguese: "Trigo / Glúten", .vietnamese: "Lúa mì / Gluten",
            .russian: "Пшеница / Глютен", .ukrainian: "Пшениця / Глютен", .japanese: "小麦 / グルテン",
            .korean: "밀 / 글루텐", .chineseSimplified: "小麦 / 麸质", .chineseTraditional: "小麥 / 麩質",
            .thai: "ข้าวสาลี / กลูเตน", .arabic: "القمح / الغلوتين"
        ],
        "fish": [
            .spanish: "Pescado", .french: "Poisson", .german: "Fisch",
            .italian: "Pesce", .portuguese: "Peixe", .vietnamese: "Cá",
            .russian: "Рыба", .ukrainian: "Риба", .japanese: "魚",
            .korean: "생선", .chineseSimplified: "鱼", .chineseTraditional: "魚",
            .thai: "ปลา", .arabic: "السمك"
        ],
        "shellfish": [
            .spanish: "Mariscos", .french: "Crustacés", .german: "Schalentiere",
            .italian: "Crostacei", .portuguese: "Mariscos", .vietnamese: "Hải sản có vỏ",
            .russian: "Ракообразные", .ukrainian: "Ракоподібні", .japanese: "甲殻類",
            .korean: "갑각류", .chineseSimplified: "贝类", .chineseTraditional: "貝類",
            .thai: "หอย / กุ้ง / ปู", .arabic: "المحار والقشريات"
        ],
        "sesame": [
            .spanish: "Sésamo", .french: "Sésame", .german: "Sesam",
            .italian: "Sesamo", .portuguese: "Gergelim", .vietnamese: "Vừng",
            .russian: "Кунжут", .ukrainian: "Кунжут", .japanese: "ごま",
            .korean: "참깨", .chineseSimplified: "芝麻", .chineseTraditional: "芝麻",
            .thai: "งา", .arabic: "السمسم"
        ],
        "mustard": [
            .spanish: "Mostaza", .french: "Moutarde", .german: "Senf",
            .italian: "Senape", .portuguese: "Mostarda", .vietnamese: "Mù tạt",
            .russian: "Горчица", .ukrainian: "Гірчиця", .japanese: "マスタード",
            .korean: "겨자", .chineseSimplified: "芥末", .chineseTraditional: "芥末",
            .thai: "มัสตาร์ด", .arabic: "الخردل"
        ],
        "celery": [
            .spanish: "Apio", .french: "Céleri", .german: "Sellerie",
            .italian: "Sedano", .portuguese: "Aipo", .vietnamese: "Cần tây",
            .russian: "Сельдерей", .ukrainian: "Селера", .japanese: "セロリ",
            .korean: "셀러리", .chineseSimplified: "芹菜", .chineseTraditional: "芹菜",
            .thai: "ขึ้นฉ่าย", .arabic: "الكرفس"
        ],
        "lupin": [
            .spanish: "Altramuz", .french: "Lupin", .german: "Lupinen",
            .italian: "Lupini", .portuguese: "Tremoço", .vietnamese: "Đậu lupin",
            .russian: "Люпин", .ukrainian: "Люпин", .japanese: "ルピナス",
            .korean: "루핀", .chineseSimplified: "羽扇豆", .chineseTraditional: "羽扇豆",
            .thai: "ลูพิน", .arabic: "الترمس"
        ],
        "mollusc": [
            .spanish: "Moluscos", .french: "Mollusques", .german: "Weichtiere",
            .italian: "Molluschi", .portuguese: "Moluscos", .vietnamese: "Động vật thân mềm",
            .russian: "Моллюски", .ukrainian: "Молюски", .japanese: "軟体動物",
            .korean: "연체동물", .chineseSimplified: "软体动物", .chineseTraditional: "軟體動物",
            .thai: "หอย", .arabic: "الرخويات"
        ],
        "sulfite": [
            .spanish: "Sulfitos", .french: "Sulfites", .german: "Sulfite",
            .italian: "Solfiti", .portuguese: "Sulfitos", .vietnamese: "Sulfit",
            .russian: "Сульфиты", .ukrainian: "Сульфіти", .japanese: "亜硫酸塩",
            .korean: "아황산염", .chineseSimplified: "亚硫酸盐", .chineseTraditional: "亞硫酸鹽",
            .thai: "ซัลไฟต์", .arabic: "الكبريตات"
        ],
        "corn": [
            .spanish: "Maíz", .french: "Maïs", .german: "Mais",
            .italian: "Mais", .portuguese: "Milho", .vietnamese: "Ngô",
            .russian: "Кукуруза", .ukrainian: "Кукурудза", .japanese: "とうもろこし",
            .korean: "옥수수", .chineseSimplified: "玉米", .chineseTraditional: "玉米",
            .thai: "ข้าวโพด", .arabic: "الذرة"
        ],
        "coconut": [
            .spanish: "Coco", .french: "Noix de coco", .german: "Kokosnuss",
            .italian: "Cocco", .portuguese: "Coco", .vietnamese: "Dừa",
            .russian: "Кокос", .ukrainian: "Кокос", .japanese: "ココナッツ",
            .korean: "코코넛", .chineseSimplified: "椰子", .chineseTraditional: "椰子",
            .thai: "มะพร้าว", .arabic: "جوز الهند"
        ]
    ]

    static func icon(for allergenID: String) -> String {
        switch allergenID {
        case "milk": return "drop.fill"
        case "egg": return "circle.fill"
        case "fish", "shellfish", "mollusc": return "fish.fill"
        case "sesame": return "circle.grid.2x2.fill"
        case "mustard": return "drop.fill"
        case "sulfite": return "drop.triangle.fill"
        case "peanut", "tree_nut", "soy", "wheat", "lupin", "celery", "corn", "coconut": return "leaf.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
}
