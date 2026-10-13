import UIKit
import Foundation

private enum MathError: LocalizedError {
    case invalidExpression
    case unexpectedCharacter(Character)
    case divisionByZero
    case unknownFunction(String)
    case domainError

    var errorDescription: String? {
        switch self {
        case .invalidExpression: return "expressão inválida"
        case .unexpectedCharacter(let c): return "caractere inesperado: \(c)"
        case .divisionByZero: return "divisão por zero"
        case .unknownFunction(let name): return "função desconhecida: \(name)"
        case .domainError: return "valor fora do domínio"
        }
    }
}

private final class ExpressionParser {
    private let input: [Character]
    private var index = 0

    init(_ text: String) { input = Array(text.replacingOccurrences(of: " ", with: "")) }

    func evaluate() throws -> Double {
        guard !input.isEmpty else { throw MathError.invalidExpression }
        let value = try parseExpression()
        skipWhitespace()
        guard index == input.count else { throw MathError.unexpectedCharacter(input[index]) }
        guard value.isFinite else { throw MathError.domainError }
        return value
    }

    private func skipWhitespace() { while index < input.count && input[index].isWhitespace { index += 1 } }
    private func peek(_ c: Character) -> Bool { skipWhitespace(); return index < input.count && input[index] == c }
    private func consume(_ c: Character) -> Bool { if peek(c) { index += 1; return true }; return false }

    private func parseExpression() throws -> Double {
        var value = try parseTerm()
        while true {
            if consume("+") { value += try parseTerm() }
            else if consume("-") { value -= try parseTerm() }
            else { return value }
        }
    }

    private func parseTerm() throws -> Double {
        var value = try parsePower()
        while true {
            if consume("*") { value *= try parsePower() }
            else if consume("/") {
                let divisor = try parsePower()
                if divisor == 0 { throw MathError.divisionByZero }
                value /= divisor
            } else { return value }
        }
    }

    private func parsePower() throws -> Double {
        let base = try parseUnary()
        if consume("^") { return pow(base, try parsePower()) }
        return base
    }

    private func parseUnary() throws -> Double {
        if consume("+") { return try parseUnary() }
        if consume("-") { return -(try parseUnary()) }
        return try parsePrimary()
    }

    private func parsePrimary() throws -> Double {
        if consume("(") {
            let value = try parseExpression()
            guard consume(")") else { throw MathError.invalidExpression }
            return value
        }
        if let number = parseNumber() { return number }
        let name = parseName()
        if !name.isEmpty {
            if name == "pi" { return Double.pi }
            if name == "e" { return exp(1) }
            guard consume("(") else { throw MathError.unknownFunction(name) }
            let argument = try parseExpression()
            guard consume(")") else { throw MathError.invalidExpression }
            switch name.lowercased() {
            case "sqrt": guard argument >= 0 else { throw MathError.domainError }; return sqrt(argument)
            case "abs": return abs(argument)
            case "sin": return sin(argument)
            case "cos": return cos(argument)
            case "tan": return tan(argument)
            case "log": guard argument > 0 else { throw MathError.domainError }; return log10(argument)
            case "ln": guard argument > 0 else { throw MathError.domainError }; return log(argument)
            default: throw MathError.unknownFunction(name)
            }
        }
        if index < input.count { throw MathError.unexpectedCharacter(input[index]) }
        throw MathError.invalidExpression
    }

    private func parseNumber() -> Double? {
        skipWhitespace()
        let start = index
        var hasDigit = false
        while index < input.count && input[index].isNumber { hasDigit = true; index += 1 }
        if index < input.count && input[index] == "." {
            index += 1
            while index < input.count && input[index].isNumber { hasDigit = true; index += 1 }
        }
        guard hasDigit else { index = start; return nil }
        return Double(String(input[start..<index]))
    }

    private func parseName() -> String {
        skipWhitespace()
        let start = index
        while index < input.count && (input[index].isLetter || input[index].isNumber || input[index] == "_") { index += 1 }
        return String(input[start..<index])
    }
}

final class MathToolsViewController: UIViewController {
    private let expressionField = UITextField()
    private let resultLabel = UILabel()
    private let latexLabel = UILabel()
    private let historyView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Resolver"; navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Estudar", style: .plain, target: self, action: #selector(openStudy)); view.backgroundColor = UIColor(red: 0.055, green: 0.06, blue: 0.11, alpha: 1)
        buildInterface()
    }

    private func buildInterface() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        let title = UILabel()
        title.text = "MathTools Offline"
        title.textColor = .white
        title.font = .systemFont(ofSize: 28, weight: .bold)
        content.addArrangedSubview(title)

        let subtitle = UILabel()
        subtitle.text = "Calculadora nativa • Swift • offline"
        subtitle.textColor = .systemIndigo
        subtitle.font = .systemFont(ofSize: 15, weight: .medium)
        content.addArrangedSubview(subtitle)

        expressionField.placeholder = "Ex.: (2 + 3) * 4^2"
        expressionField.textColor = .white
        expressionField.tintColor = .systemIndigo
        expressionField.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        expressionField.layer.cornerRadius = 12
        expressionField.font = .systemFont(ofSize: 19, weight: .regular)
        expressionField.autocorrectionType = .no
        expressionField.autocapitalizationType = .none
        expressionField.keyboardType = .numbersAndPunctuation
        expressionField.returnKeyType = .done
        expressionField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        expressionField.leftViewMode = .always
        expressionField.heightAnchor.constraint(equalToConstant: 52).isActive = true
        expressionField.delegate = self
        content.addArrangedSubview(expressionField)

        let button = UIButton(type: .system)
        button.setTitle("Resolver", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemIndigo
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: #selector(resolve), for: .touchUpInside)
        content.addArrangedSubview(button)

        let resultTitle = label("Resultado", color: .lightGray, size: 14, weight: .semibold)
        content.addArrangedSubview(resultTitle)
        resultLabel.text = "—"
        resultLabel.textColor = .white
        resultLabel.font = .monospacedDigitSystemFont(ofSize: 30, weight: .medium)
        resultLabel.numberOfLines = 0
        content.addArrangedSubview(resultLabel)

        latexLabel.text = "LaTeX: —"
        latexLabel.textColor = .systemPink
        latexLabel.font = .systemFont(ofSize: 15)
        latexLabel.numberOfLines = 0
        content.addArrangedSubview(latexLabel)

        content.addArrangedSubview(label("Histórico", color: .lightGray, size: 14, weight: .semibold))
        historyView.isEditable = false
        historyView.isScrollEnabled = false
        historyView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        historyView.textColor = .lightText
        historyView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        historyView.layer.cornerRadius = 12
        historyView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        content.addArrangedSubview(historyView)
    }

    private func label(_ text: String, color: UIColor, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .systemFont(ofSize: size, weight: weight)
        return label
    }

    @objc private func openStudy() { let study = StudyViewController(); let navigation = UINavigationController(rootViewController: study); navigation.modalPresentationStyle = .fullScreen; present(navigation, animated: true) }

    @objc private func resolve() {
        view.endEditing(true)
        let text = expressionField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { resultLabel.text = "Digite uma expressão"; return }
        do {
            let value = try ExpressionParser(text).evaluate()
            let formatted = String(format: "%.12g", value)
            resultLabel.text = formatted
            latexLabel.text = "LaTeX: " + text
            historyView.text = "\(text) = \(formatted)\n" + historyView.text
        } catch {
            resultLabel.text = "Erro: \(error.localizedDescription)"
        }
    }
}

extension MathToolsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { resolve(); return true }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let navigation = UINavigationController(rootViewController: MathToolsViewController()); window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
