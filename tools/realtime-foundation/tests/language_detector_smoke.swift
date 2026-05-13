import Foundation

@main
struct LanguageDetectorSmoke {
    static func main() {
        precondition(LanguageDetector.detect("home Bay gio minh dang noi chuyen tieng Viet") == "vi")
        precondition(LanguageDetector.detect("home Bây giờ mình đang nói chuyện tiếng Việt, em nói chuyện được. chuyện tập không?") == "vi")
        precondition(LanguageDetector.detect("Benim o yüzden kendi yolumu bulmam gerekiyor") == "tr")
        precondition(LanguageDetector.detect("Hola, como estas? Necesito una traduccion rapida.") == "es")
        precondition(LanguageDetector.detect("Hello, can you hear me now?") == "en")
        precondition(LanguageDetector.detect("你好，现在能听到我说话吗？") == "zh")
        print("language detector smoke ok")
    }
}
