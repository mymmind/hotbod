export interface CoachRequest {
  message: string;
  context: CoachContextPayload;
}

export interface CoachContextPayload {
  userProfile: {
    goal: string;
    experienceLevel: string;
    proteinGoalGrams: number;
  };
  currentWorkout?: GeneratedWorkoutPayload | null;
  recentWorkouts: Array<{ title: string; completedAt: string; totalVolumeKg: number }>;
  exerciseStats: Array<{ exerciseId: string; lastWeightKg?: number; lastReps?: number }>;
  proteinSummary: { todayGrams: number; goalGrams: number; streakDays: number };
  recovery: Record<string, number>;
  limitations: string[];
  allowedExerciseIds: string[];
  availableEquipment: string[];
  targetDurationMinutes: number;
}

export interface GeneratedWorkoutPayload {
  title: string;
  estimatedDurationMinutes: number;
  focus: string[];
  exercises: PlannedExercisePayload[];
  rationale: string;
  safetyNotes: string[];
}

export interface PlannedExercisePayload {
  exerciseId: string;
  reason?: string;
  restSeconds?: number;
  sets: PlannedSetPayload[];
}

export interface PlannedSetPayload {
  targetRepsMin: number;
  targetRepsMax: number;
  targetWeightKg?: number;
  rpeTarget?: number;
}

export interface CoachResponsePayload {
  intent: string;
  content: string;
  proposedWorkout?: GeneratedWorkoutPayload | null;
  safetyNotes?: string[];
}

export const COACH_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["intent", "content", "proposedWorkout", "safetyNotes"],
  properties: {
    intent: {
      type: "string",
      enum: [
        "explainWorkout",
        "modifyWorkout",
        "generateWorkout",
        "analyzePlateau",
        "proteinHelp",
        "progressPhotoInsight",
        "generalTrainingQuestion",
        "motivation",
        "unknown",
      ],
    },
    content: { type: "string" },
    proposedWorkout: {
      anyOf: [
        { type: "null" },
        {
          type: "object",
          additionalProperties: false,
          required: ["title", "estimatedDurationMinutes", "focus", "exercises", "rationale", "safetyNotes"],
          properties: {
            title: { type: "string" },
            estimatedDurationMinutes: { type: "number" },
            focus: { type: "array", items: { type: "string" } },
            rationale: { type: "string" },
            safetyNotes: { type: "array", items: { type: "string" } },
            exercises: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                required: ["exerciseId", "sets"],
                properties: {
                  exerciseId: { type: "string" },
                  reason: { type: "string" },
                  restSeconds: { type: "number" },
                  sets: {
                    type: "array",
                    items: {
                      type: "object",
                      additionalProperties: false,
                      required: ["targetRepsMin", "targetRepsMax"],
                      properties: {
                        targetRepsMin: { type: "number" },
                        targetRepsMax: { type: "number" },
                        targetWeightKg: { type: "number" },
                        rpeTarget: { type: "number" },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      ],
    },
    safetyNotes: { type: "array", items: { type: "string" } },
  },
} as const;
