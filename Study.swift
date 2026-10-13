import UIKit
import Foundation

struct StudyCard: Codable, Identifiable {
    let id: UUID
    var question: String
    var answer: String
    var due: Date
    var interval: Int
    var ease: Double
    var repetitions: Int

    init(question: String, answer: String) {
        id = UUID(); self.question = question; self.answer = answer
        due = Date(); interval = 0; ease = 2.5; repetitions = 0
    }
}

final class StudyStore {
    private let key = "MathTools.studyCards.v1"
    private(set) var cards: [StudyCard] = []
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode([StudyCard].self, from: data) { cards = saved }
        if cards.isEmpty {
            cards = [StudyCard(question: "Qual é a derivada de x²?", answer: "2x"), StudyCard(question: "Quanto é 2 + 2 × 3?", answer: "8, pois a multiplicação vem primeiro."), StudyCard(question: "Qual é a fórmula de Bhaskara?", answer: "x = (-b ± √(b² - 4ac)) / 2a")]
            save()
        }
    }
    var dueCards: [StudyCard] { cards.filter { $0.due <= Date() }.sorted { $0.due < $1.due } }
    func add(question: String, answer: String) { cards.append(StudyCard(question: question, answer: answer)); save() }
    func review(_ card: StudyCard, quality: Int) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var item = cards[i]
        if quality < 3 { item.repetitions = 0; item.interval = 1 } else {
            item.repetitions += 1
            if item.repetitions == 1 { item.interval = 1 } else if item.repetitions == 2 { item.interval = 6 } else { item.interval = max(1, Int((Double(item.interval) * item.ease).rounded())) }
            let penalty = Double(5 - quality)
            item.ease = max(1.3, item.ease + 0.1 - penalty * (0.08 + penalty * 0.02))
        }
        item.due = Calendar.current.date(byAdding: .day, value: item.interval, to: Date()) ?? Date()
        cards[i] = item; save()
    }
    private func save() { if let data = try? JSONEncoder().encode(cards) { UserDefaults.standard.set(data, forKey: key) } }
}

final class StudyViewController: UIViewController {
    private let store = StudyStore()
    private var cards: [StudyCard] = []
    private var index = 0
    private let question = UILabel()
    private let answer = UILabel()
    private let status = UILabel()
    private let reveal = UIButton(type: .system)
    private let reviews = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad(); title = "Estudar"; view.backgroundColor = UIColor(red: 0.055, green: 0.06, blue: 0.11, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard)); buildUI(); reload()
    }
    private func buildUI() {
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)])
        status.textColor = .lightGray; status.numberOfLines = 0; stack.addArrangedSubview(status)
        let card = UIView(); card.backgroundColor = UIColor.white.withAlphaComponent(0.08); card.layer.cornerRadius = 16
        let inside = UIStackView(); inside.axis = .vertical; inside.spacing = 18; inside.alignment = .center; inside.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(inside)
        NSLayoutConstraint.activate([inside.topAnchor.constraint(equalTo: card.topAnchor, constant: 24), inside.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16), inside.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16), inside.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)])
        question.textColor = .white; question.font = .systemFont(ofSize: 22, weight: .semibold); question.textAlignment = .center; question.numberOfLines = 0
        answer.textColor = .systemTeal; answer.font = .systemFont(ofSize: 18); answer.textAlignment = .center; answer.numberOfLines = 0
        inside.addArrangedSubview(question); inside.addArrangedSubview(answer); stack.addArrangedSubview(card)
        reveal.setTitle("Mostrar resposta", for: .normal); style(reveal, color: .systemIndigo); reveal.addTarget(self, action: #selector(showAnswer), for: .touchUpInside); stack.addArrangedSubview(reveal)
        reviews.axis = .vertical; reviews.spacing = 8; reviews.isHidden = true
        addReview(0, "Não lembrei", .systemRed); addReview(3, "Lembrei", .systemOrange); addReview(4, "Fácil", .systemGreen); addReview(5, "Muito fácil", .systemTeal)
        stack.addArrangedSubview(reviews)
    }
    private func addReview(_ quality: Int, _ text: String, _ color: UIColor) { let b = UIButton(type: .system); b.tag = quality; b.setTitle(text, for: .normal); style(b, color: color); b.addTarget(self, action: #selector(review(_:)), for: .touchUpInside); reviews.addArrangedSubview(b) }
    private func style(_ button: UIButton, color: UIColor) { button.setTitleColor(.white, for: .normal); button.backgroundColor = color; button.layer.cornerRadius = 12; button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold); button.heightAnchor.constraint(equalToConstant: 46).isActive = true }
    private func reload() {
        cards = store.dueCards; index = 0; reviews.isHidden = true; reveal.isHidden = cards.isEmpty
        if cards.isEmpty { question.text = "Tudo em dia!"; answer.text = "Adicione um cartão ou volte amanhã."; status.text = "Nenhuma revisão pendente." } else { question.text = cards[0].question; answer.text = cards[0].answer; answer.isHidden = true; status.text = "Cartão 1 de \(cards.count)" }
    }
    @objc private func showAnswer() { guard !cards.isEmpty else { return }; answer.isHidden = false; reveal.isHidden = true; reviews.isHidden = false }
    @objc private func review(_ sender: UIButton) {
        guard index < cards.count else { return }; store.review(cards[index], quality: sender.tag); index += 1
        if index < cards.count { question.text = cards[index].question; answer.text = cards[index].answer; answer.isHidden = true; reveal.isHidden = false; reviews.isHidden = true; status.text = "Cartão \(index + 1) de \(cards.count)" } else { reload(); status.text = "Sessão concluída. Bom estudo!" }
    }
    @objc private func addCard() {
        let alert = UIAlertController(title: "Novo cartão", message: nil, preferredStyle: .alert); alert.addTextField { $0.placeholder = "Pergunta" }; alert.addTextField { $0.placeholder = "Resposta" }; alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel)); alert.addAction(UIAlertAction(title: "Salvar", style: .default) { [weak self, weak alert] _ in let q = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; let a = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; if !q.isEmpty && !a.isEmpty { self?.store.add(question: q, answer: a); self?.reload() } }); present(alert, animated: true)
    }
}
