import Foundation

struct Question: Identifiable {
    let id: Int
    let text: String
    let scaleLabels: [String]
    let summary: String
}

struct QuestionBank {
    static let questions: [Question] = [
        Question(
            id: 1,
            text: "How caffeinated are you right now?",
            scaleLabels: ["Decaf", "Slightly Buzzed", "Very Buzzed", "Vibrating"],
            summary: "Caffeine"
        ),
        Question(
            id: 2,
            text: "How strong is your urge to take a nap?",
            scaleLabels: ["Wide Awake", "Could Sleep", "Should Sleep", "Already Asleep"],
            summary: "Sleepiness"
        ),
        Question(
            id: 3,
            text: "How much do you understand your cat's thoughts?",
            scaleLabels: ["No Cat", "Mysterious", "Getting There", "Telepathic"],
            summary: "Cat"
        ),
        Question(
            id: 4,
            text: "How confident are you that you locked the door?",
            scaleLabels: ["100% Sure", "Pretty Sure", "Should Check", "Panicking"],
            summary: "Door"
        ),
        Question(
            id: 5,
            text: "How many tabs do you have open right now?",
            scaleLabels: ["Under 10", "10-30", "30-100", "Lost Count"],
            summary: "Tabs"
        ),
        Question(
            id: 6,
            text: "How badly do you need to stretch?",
            scaleLabels: ["Limber", "A Little Stiff", "Very Stiff", "Fossilizing"],
            summary: "Stretch"
        ),
        Question(
            id: 7,
            text: "How hungry are you?",
            scaleLabels: ["Just Ate", "Peckish", "Hungry", "Hangry"],
            summary: "Hunger"
        ),
        Question(
            id: 8,
            text: "How much do you regret your last text message?",
            scaleLabels: ["No Regrets", "Minor Regret", "Major Regret", "Deleting App"],
            summary: "Regret"
        ),
        Question(
            id: 9,
            text: "How organized is your workspace?",
            scaleLabels: ["Marie Kondo", "Lived In", "Chaotic", "Crime Scene"],
            summary: "Workspace"
        ),
        Question(
            id: 10,
            text: "How likely are you to start a new hobby today?",
            scaleLabels: ["Not Likely", "Maybe", "Probably", "Already Shopping"],
            summary: "Hobby"
        )
    ]
}
