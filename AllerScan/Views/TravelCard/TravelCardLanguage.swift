import Foundation

enum TravelCardLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case vietnamese = "vi"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case thai = "th"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .vietnamese: "Vietnamese"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Chinese (Simplified)"
        case .chineseTraditional: "Chinese (Traditional)"
        case .thai: "Thai"
        case .arabic: "Arabic"
        }
    }

    var nativeName: String {
        switch self {
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .vietnamese: "Tiếng Việt"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .chineseTraditional: "繁體中文"
        case .thai: "ไทย"
        case .arabic: "العربية"
        }
    }

    var allergyPhrase: String {
        switch self {
        case .spanish: "Soy alérgico/a a:"
        case .french: "Je suis allergique à :"
        case .german: "Ich bin allergisch gegen:"
        case .italian: "Sono allergico/a a:"
        case .portuguese: "Sou alérgico/a a:"
        case .vietnamese: "Tôi bị dị ứng với:"
        case .russian: "У меня аллергия на:"
        case .ukrainian: "У мене алергія на:"
        case .japanese: "私は次のものにアレルギーがあります："
        case .korean: "저는 다음에 알레르기가 있습니다:"
        case .chineseSimplified: "我对以下食物过敏："
        case .chineseTraditional: "我對以下食物過敏："
        case .thai: "ฉันแพ้:"
        case .arabic: "أنا أعاني من حساسية تجاه:"
        }
    }

    var safetyPhrase: String {
        switch self {
        case .spanish: "Incluso pequeñas cantidades pueden causar una reacción grave. Por favor, evite cualquier traza o contaminación cruzada. Gracias."
        case .french: "Même de petites quantités peuvent provoquer une réaction grave. Veuillez éviter toute trace ou contamination croisée. Merci."
        case .german: "Schon kleine Mengen können eine schwere Reaktion auslösen. Bitte vermeiden Sie jegliche Spuren oder Kreuzkontamination. Danke."
        case .italian: "Anche piccole quantità possono causare una reazione grave. Si prega di evitare qualsiasi traccia o contaminazione incrociata. Grazie."
        case .portuguese: "Mesmo pequenas quantidades podem causar uma reação grave. Por favor, evite qualquer vestígio ou contaminação cruzada. Obrigado."
        case .vietnamese: "Ngay cả một lượng nhỏ cũng có thể gây phản ứng nghiêm trọng. Vui lòng tránh bất kỳ dấu vết hoặc lây nhiễm chéo nào. Cảm ơn."
        case .russian: "Даже малые количества могут вызвать серьёзную реакцию. Пожалуйста, избегайте любых следов или перекрёстного загрязнения. Спасибо."
        case .ukrainian: "Навіть малі кількості можуть викликати серйозну реакцію. Будь ласка, уникайте будь-яких слідів чи перехресного забруднення. Дякую."
        case .japanese: "少量でも重い反応を引き起こすことがあります。微量混入や交差汚染にもご注意ください。ありがとうございます。"
        case .korean: "소량이라도 심각한 반응을 일으킬 수 있습니다. 어떠한 흔적이나 교차 오염도 피해 주십시오. 감사합니다."
        case .chineseSimplified: "即使少量也可能引起严重反应。请避免任何残留或交叉污染。谢谢。"
        case .chineseTraditional: "即使少量也可能引起嚴重反應。請避免任何殘留或交叉污染。謝謝。"
        case .thai: "แม้ปริมาณเล็กน้อยก็อาจทำให้เกิดอาการรุนแรงได้ กรุณาหลีกเลี่ยงร่องรอยหรือการปนเปื้อนข้าม ขอบคุณค่ะ/ครับ"
        case .arabic: "حتى الكميات الصغيرة قد تسبب تفاعلاً خطيراً. يرجى تجنب أي آثار أو تلوث متبادل. شكراً."
        }
    }

    var isRTL: Bool { self == .arabic }
}
