import Foundation

public enum WorkoutPlan {
    public static func exercises(for sessionType: SessionType) -> [Exercise] {
        switch sessionType {
        case .a: return dayA
        case .b: return dayB
        case .c: return dayC
        }
    }

    static let dayA: [Exercise] = [
        Exercise(
            id: "a-warmup",
            name: "Cardio warm-up (cycling)",
            instruction: "Easy pace, joints only",
            reps: "10 min",
            isTimed: true
        ),
        Exercise(
            id: "a-challenge",
            name: "Daily Challenge — squats + push-ups",
            instruction: "Counts toward daily challenge",
            sets: 1,
            reps: "10 + 10 reps",
            isDailyChallenge: true
        ),
        Exercise(
            id: "a-rows",
            name: "Dumbbell rows (pull)",
            instruction: "Elbow back and up, knee on bench. 1 warm-up + 3 working sets.",
            sets: 4,
            reps: "10 reps / side"
        ),
        Exercise(
            id: "a-chest-press",
            name: "Dumbbell chest press (push)",
            instruction: "2–3 sec descent, slow is the work. 1 warm-up + 3 working sets.",
            sets: 4,
            reps: "10 reps"
        ),
        Exercise(
            id: "a-shoulder-press",
            name: "Shoulder press (push)",
            instruction: "Go light — easy to strain when returning",
            sets: 3,
            reps: "10 reps"
        ),
        Exercise(
            id: "a-curls",
            name: "Bicep curls (pull)",
            instruction: "No swinging, controlled",
            sets: 3,
            reps: "10 reps"
        ),
        Exercise(
            id: "a-plank",
            name: "Plank",
            instruction: "Hips level",
            sets: 2,
            reps: "30–45 sec hold",
            isTimed: true
        ),
        Exercise(
            id: "a-dead-bugs",
            name: "Dead bugs",
            instruction: "Lower back pressed into mat",
            sets: 2,
            reps: "10 reps"
        ),
        Exercise(
            id: "a-stretch",
            name: "Stretch",
            instruction: "Chest opener, lat, shoulder cross-body",
            reps: "5 min",
            isTimed: true
        ),
    ]

    static let dayB: [Exercise] = [
        Exercise(
            id: "b-warmup",
            name: "Cardio warm-up (cycling)",
            instruction: "Easy pace",
            reps: "5 min",
            isTimed: true
        ),
        Exercise(
            id: "b-challenge",
            name: "Daily Challenge — squats + push-ups",
            instruction: "Counts toward daily challenge",
            sets: 1,
            reps: "10 + 10 reps",
            isDailyChallenge: true
        ),
        Exercise(
            id: "b-main-cardio",
            name: "Main cardio block (cycling)",
            instruction: "6–7/10 effort, steady pace",
            reps: "20 min",
            isTimed: true
        ),
        Exercise(
            id: "b-plank",
            name: "Plank",
            instruction: "Quality over duration",
            sets: 3,
            reps: "30–45 sec hold",
            isTimed: true
        ),
        Exercise(
            id: "b-dead-bugs",
            name: "Dead bugs",
            instruction: "Deliberate, back flat",
            sets: 3,
            reps: "10 reps / side"
        ),
        Exercise(
            id: "b-leg-raises",
            name: "Leg raises",
            instruction: "Bend knees if lower back lifts",
            sets: 3,
            reps: "10 reps"
        ),
        Exercise(
            id: "b-flexibility",
            name: "Flexibility & mobility",
            instruction: "Hip flexor lunge stretch (2 min/side), seated hamstring stretch (2 min), chest opener on mat (2 min), figure-4 glute stretch (2 min/side)",
            reps: "10 min",
            isTimed: true
        ),
    ]

    static let dayC: [Exercise] = [
        Exercise(
            id: "c-cardio",
            name: "Cardio — cycling or stepper",
            instruction: "Comfortable to moderate effort",
            reps: "15 min",
            isTimed: true
        ),
        Exercise(
            id: "c-challenge",
            name: "Daily Challenge — squats + push-ups",
            instruction: "Counts toward daily challenge",
            sets: 1,
            reps: "10 + 10 reps",
            isDailyChallenge: true
        ),
        Exercise(
            id: "c-rows",
            name: "Dumbbell rows (pull)",
            instruction: "Lighter than Day A, maintenance pace",
            sets: 2,
            reps: "10 reps / side"
        ),
        Exercise(
            id: "c-chest",
            name: "Chest press or push-ups (push)",
            instruction: "Dumbbells or bodyweight",
            sets: 2,
            reps: "10 reps"
        ),
        Exercise(
            id: "c-plank",
            name: "Plank",
            instruction: "",
            sets: 1,
            reps: "30–40 sec",
            isTimed: true
        ),
        Exercise(
            id: "c-dead-bugs",
            name: "Dead bugs",
            instruction: "",
            sets: 1,
            reps: "10 reps / side"
        ),
        Exercise(
            id: "c-stretch",
            name: "Stretch",
            instruction: "Chest opener, hip flexors, hamstrings",
            reps: "7 min",
            isTimed: true
        ),
    ]
}
