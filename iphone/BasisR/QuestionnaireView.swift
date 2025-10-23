import SwiftUI

struct QuestionnaireView: View {
    @State private var currentQuestionIndex = 0
    @State private var responses: [Int: Int] = [:]
    @State private var isRevising = false
    @State private var isComplete = false
    @State private var showSettings = false
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("lastCompletionDate") private var lastCompletionTimestamp: Double = 0
    @Environment(\.scenePhase) private var scenePhase

    private var lastCompletionDate: Date? {
        lastCompletionTimestamp > 0 ? Date(timeIntervalSince1970: lastCompletionTimestamp) : nil
    }

    private var currentQuestion: Question? {
        guard currentQuestionIndex < QuestionBank.questions.count else {
            return nil
        }
        return QuestionBank.questions[currentQuestionIndex]
    }

    var body: some View {
        ZStack {
            if isComplete {
                ThankYouView()
            } else if let question = currentQuestion {
                HorizontalButtonsView(
                    question: question,
                    onAnswer: handleAnswer
                )
            } else {
                CompletionView(
                    responses: responses,
                    onRevise: reviseQuestion,
                    onDone: handleDone
                )
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            checkAndResetIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkAndResetIfNeeded()
            }
        }
    }

    private func handleDone() {
        print("=== Final Responses ===")
        for question in QuestionBank.questions {
            if let answer = responses[question.id] {
                print("\(question.summary): \(question.scaleLabels[answer - 1])")
            }
        }
        lastCompletionTimestamp = Date().timeIntervalSince1970
        isComplete = true
    }

    private func checkAndResetIfNeeded() {
        if notificationManager.shouldResetQuestionnaire(lastCompletionDate: lastCompletionDate) {
            print("Resetting questionnaire for new day")
            isComplete = false
            currentQuestionIndex = 0
            responses = [:]
        }
    }

    private func reviseQuestion(_ questionId: Int) {
        if let index = QuestionBank.questions.firstIndex(where: { $0.id == questionId }) {
            currentQuestionIndex = index
            isRevising = true
            print("Revising question \(questionId)")
        }
    }

    private func handleAnswer(_ answer: Int) {
        guard let question = currentQuestion else { return }

        responses[question.id] = answer
        print("Question \(question.id): '\(question.text)' - Answer: \(answer) (\(question.scaleLabels[answer - 1]))")

        if isRevising {
            isRevising = false
            currentQuestionIndex = QuestionBank.questions.count
        } else if currentQuestionIndex < QuestionBank.questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            currentQuestionIndex += 1
            print("=== Questionnaire Complete ===")
            print("All responses: \(responses)")
        }
    }
}

struct HorizontalButtonsView: View {
    let question: Question
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 10) {
                Text("Question \(question.id) of \(QuestionBank.questions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(question.text)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(height: 120)

            Spacer()

            VStack(spacing: 15) {
                ForEach(0..<4) { index in
                    Button(action: {
                        onAnswer(index + 1)
                    }) {
                        Text(question.scaleLabels[index])
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct CompletionView: View {
    let responses: [Int: Int]
    let onRevise: (Int) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Review Your Answers")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 40)

            Text("Tap any answer to revise")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(QuestionBank.questions) { question in
                        if let answerValue = responses[question.id] {
                            Button(action: {
                                onRevise(question.id)
                            }) {
                                HStack {
                                    Text(question.summary)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text(question.scaleLabels[answerValue - 1])
                                        .font(.body)
                                        .foregroundColor(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button(action: {
                onDone()
            }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

struct ThankYouView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Thank You!")
                .font(.title)
                .fontWeight(.bold)

            Text("Your responses have been recorded.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    QuestionnaireView()
}
