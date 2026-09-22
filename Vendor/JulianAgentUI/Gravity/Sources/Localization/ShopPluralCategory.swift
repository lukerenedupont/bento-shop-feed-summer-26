import Foundation

/// The CLDR cardinal-plural category for an integer quantity.
public enum ShopPluralCategory: String, Sendable {
    case one = "One"
    case few = "Few"
    case many = "Many"
    case other = "Other"

    public static func category(
        for quantity: Int,
        localizationBundle bundle: Bundle,
        fallbackLocale: Locale = .current
    ) -> Self {
        category(
            for: quantity,
            preferredLocalizationIdentifier: bundle.preferredLocalizations.first,
            fallbackLocale: fallbackLocale
        )
    }

    static func category(
        for quantity: Int,
        preferredLocalizationIdentifier: String?,
        fallbackLocale: Locale
    ) -> Self {
        let localizationLocale = preferredLocalizationIdentifier
            .map(Locale.init(identifier:)) ?? fallbackLocale
        return category(for: quantity, locale: localizationLocale)
    }

    public static func category(for quantity: Int, locale: Locale = .current) -> Self {
        let languageCode = (locale.language.languageCode?.identifier ?? locale.identifier).lowercased()
        let quantity = quantity.magnitude

        switch languageCode {
        case "cs":
            if quantity == 1 { return .one }
            if (2...4).contains(quantity) { return .few }
            return .other

        case "da", "de", "fi", "nb", "nl", "sv":
            return quantity == 1 ? .one : .other

        case "es", "it":
            if quantity == 1 { return .one }
            return isNonzeroMultipleOfMillion(quantity) ? .many : .other

        case "fr":
            if quantity == 0 || quantity == 1 { return .one }
            return isNonzeroMultipleOfMillion(quantity) ? .many : .other

        case "ja":
            return .other

        case "lt":
            let lastDigit = quantity % 10
            let lastTwoDigits = quantity % 100
            if lastDigit == 1, !(11...19).contains(lastTwoDigits) { return .one }
            if (2...9).contains(lastDigit), !(11...19).contains(lastTwoDigits) { return .few }
            return .other

        case "pl":
            if quantity == 1 { return .one }

            let lastDigit = quantity % 10
            let lastTwoDigits = quantity % 100
            if (2...4).contains(lastDigit), !(12...14).contains(lastTwoDigits) { return .few }
            return .many

        case "pt":
            let usesPortugalRules = locale.region?.identifier.uppercased() == "PT"
            if quantity == 1 || (!usesPortugalRules && quantity == 0) { return .one }
            return isNonzeroMultipleOfMillion(quantity) ? .many : .other

        case "ro":
            if quantity == 1 { return .one }
            if quantity == 0 || (1...19).contains(quantity % 100) { return .few }
            return .other

        default:
            return quantity == 1 ? .one : .other
        }
    }

    private static func isNonzeroMultipleOfMillion(_ quantity: UInt) -> Bool {
        quantity != 0 && quantity.isMultiple(of: 1_000_000)
    }
}
