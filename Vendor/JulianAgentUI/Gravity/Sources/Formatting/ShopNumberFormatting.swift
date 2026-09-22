import Foundation

/// Shared formatter reuse for locale-aware numeric display.
///
/// `NumberFormatter` is expensive to configure. Callers describe the complete output
/// contract and this type reuses an immutable formatter for that configuration.
public enum ShopNumberFormatting {
    public enum Style: Hashable, Sendable {
        case decimal
        case percent
        case currency(String)
    }

    public struct Configuration: Hashable, Sendable {
        let style: Style
        let localeIdentifier: String
        let minimumFractionDigits: Int?
        let maximumFractionDigits: Int?
        let roundingMode: NumberFormatter.RoundingMode
        let usesGroupingSeparator: Bool

        public init(
            style: Style,
            locale: Locale,
            minimumFractionDigits: Int? = nil,
            maximumFractionDigits: Int? = nil,
            roundingMode: NumberFormatter.RoundingMode = .halfEven,
            usesGroupingSeparator: Bool = true
        ) {
            precondition(minimumFractionDigits == nil || minimumFractionDigits! >= 0)
            precondition(maximumFractionDigits == nil || maximumFractionDigits! >= 0)
            precondition(
                minimumFractionDigits == nil ||
                    maximumFractionDigits == nil ||
                    minimumFractionDigits! <= maximumFractionDigits!
            )
            self.style = style
            self.localeIdentifier = locale.identifier
            self.minimumFractionDigits = minimumFractionDigits
            self.maximumFractionDigits = maximumFractionDigits
            self.roundingMode = roundingMode
            self.usesGroupingSeparator = usesGroupingSeparator
        }
    }

    public static func decimal(
        _ number: NSNumber,
        locale: Locale = .current,
        minimumFractionDigits: Int? = nil,
        maximumFractionDigits: Int? = nil,
        roundingMode: NumberFormatter.RoundingMode = .halfEven,
        usesGroupingSeparator: Bool = true
    ) -> String? {
        string(
            from: number,
            configuration: Configuration(
                style: .decimal,
                locale: locale,
                minimumFractionDigits: minimumFractionDigits,
                maximumFractionDigits: maximumFractionDigits,
                roundingMode: roundingMode,
                usesGroupingSeparator: usesGroupingSeparator
            )
        )
    }

    public static func percent(
        _ number: NSNumber,
        locale: Locale = .current,
        minimumFractionDigits: Int? = nil,
        maximumFractionDigits: Int? = nil,
        roundingMode: NumberFormatter.RoundingMode = .halfEven
    ) -> String? {
        string(
            from: number,
            configuration: Configuration(
                style: .percent,
                locale: locale,
                minimumFractionDigits: minimumFractionDigits,
                maximumFractionDigits: maximumFractionDigits,
                roundingMode: roundingMode
            )
        )
    }

    public static func string(from number: NSNumber, configuration: Configuration) -> String? {
        FormatterPool.shared.string(from: number, configuration: configuration)
    }

    /// Locale-aware decimal parsing through the shared pool, so callers never
    /// construct a `NumberFormatter` for input parsing either.
    public static func decimalValue(
        from string: String,
        locale: Locale = .current
    ) -> Decimal? {
        FormatterPool.shared
            .formatter(for: Configuration(style: .decimal, locale: locale))
            .number(from: string)?
            .decimalValue
    }

    public static func currencyFractionDigits(currencyCode: String, locale: Locale) -> Int? {
        let normalizedCode = currencyCode.uppercased()
        let configuration = Configuration(style: .currency(normalizedCode), locale: locale)
        return FormatterPool.shared.formatter(for: configuration).maximumFractionDigits
    }

    public static func currencySymbol(currencyCode: String, locale: Locale) -> String? {
        let normalizedCode = currencyCode.uppercased()
        let configuration = Configuration(
            style: .currency(normalizedCode),
            locale: locale,
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        )
        return FormatterPool.shared.formatter(for: configuration).currencySymbol
    }
}

private extension ShopNumberFormatting {
    /// Formatters are fully configured in `makeFormatter` before being published
    /// under the lock and are never mutated afterwards. `NumberFormatter` is
    /// documented thread-safe on iOS 7+ for non-mutating use (`string(from:)`,
    /// `number(from:)`, property reads), so shared instances may format
    /// concurrently from off-main transform paths.
    final class FormatterPool: @unchecked Sendable {
        static let shared = FormatterPool()

        private let lock = NSLock()
        private var formatters: [Configuration: NumberFormatter] = [:]

        func string(from number: NSNumber, configuration: Configuration) -> String? {
            formatter(for: configuration).string(from: number)
        }

        func formatter(for configuration: Configuration) -> NumberFormatter {
            lock.lock()
            if let formatter = formatters[configuration] {
                lock.unlock()
                return formatter
            }
            lock.unlock()

            let newFormatter = Self.makeFormatter(configuration)

            lock.lock()
            defer { lock.unlock() }
            if let formatter = formatters[configuration] {
                return formatter
            }
            formatters[configuration] = newFormatter
            return newFormatter
        }

        private static func makeFormatter(_ configuration: Configuration) -> NumberFormatter {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: configuration.localeIdentifier)

            // Style first, then options — mirroring every pre-migration call
            // site, so the style setter can never clobber explicit options.
            switch configuration.style {
            case .decimal:
                formatter.numberStyle = .decimal
            case .percent:
                formatter.numberStyle = .percent
            case .currency(let currencyCode):
                formatter.numberStyle = .currency
                formatter.currencyCode = currencyCode
            }

            formatter.roundingMode = configuration.roundingMode
            formatter.usesGroupingSeparator = configuration.usesGroupingSeparator

            let defaultMinimum = formatter.minimumFractionDigits
            let defaultMaximum = formatter.maximumFractionDigits
            var minimum = configuration.minimumFractionDigits ?? defaultMinimum
            var maximum = configuration.maximumFractionDigits ?? defaultMaximum

            if minimum > maximum {
                if configuration.minimumFractionDigits != nil {
                    maximum = minimum
                } else {
                    minimum = maximum
                }
            }

            formatter.maximumFractionDigits = maximum
            formatter.minimumFractionDigits = minimum
            return formatter
        }
    }
}
