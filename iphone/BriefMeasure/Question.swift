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
            text: "Voices/sounds others don't hear",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Caffeine"
        ),
        Question(
            id: 2,
            text: "Beliefs others find strange",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Sleepiness"
        ),
        Question(
            id: 3,
            text: "Feeling unreal/disconnected",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Cat"
        ),
        Question(
            id: 4,
            text: "Feeling sad/depressed",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Door"
        ),
        Question(
            id: 5,
            text: "Energy level",
            scaleLabels: ["Elevated", "Normal", "Tired", "Exhausted"],
            summary: "Tabs"
        ),
        Question(
            id: 6,
            text: "Difficulty concentrating",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Stretch"
        ),
        Question(
            id: 7,
            text: "Problems with daily tasks",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Hunger"
        ),
        Question(
            id: 8,
            text: "Social withdrawal",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Regret"
        ),
        Question(
            id: 9,
            text: "Thoughts of self-harm",
            scaleLabels: ["Not Present", "Noticed", "Impactful", "Debilitating"],
            summary: "Workspace"
        ),
        Question(
            id: 10,
            text: "Sleep quality",
            scaleLabels: ["Good", "Fair", "Degraded", "Terrible"],
            summary: "Hobby"
        )
    ]
}
