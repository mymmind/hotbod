import type { CoachContextPayload, GeneratedWorkoutPayload } from "./schemas.ts";

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

const RISKY_LIMITATIONS: Record<string, string[]> = {
  shoulder: ["verticalPush", "horizontalPush"],
  lowerBack: ["hinge", "squat"],
  knee: ["squat", "lunge"],
};

export function validateWorkout(
  workout: GeneratedWorkoutPayload,
  context: CoachContextPayload,
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  const allowed = new Set(context.allowedExerciseIds);
  const equipment = new Set(context.availableEquipment);
  const seen = new Set<string>();

  if (!workout.exercises || workout.exercises.length < 4) {
    errors.push("Workout has fewer than 4 exercises.");
  }

  for (const planned of workout.exercises ?? []) {
    if (seen.has(planned.exerciseId)) {
      errors.push(`Duplicate exercise: ${planned.exerciseId}`);
    }
    seen.add(planned.exerciseId);

    if (!allowed.has(planned.exerciseId)) {
      errors.push(`Unknown or disallowed exercise: ${planned.exerciseId}`);
    }

    for (const set of planned.sets ?? []) {
      if (set.targetRepsMin < 1 || set.targetRepsMax > 30 || set.targetRepsMin > set.targetRepsMax) {
        errors.push(`Invalid rep range for ${planned.exerciseId}.`);
      }
    }
  }

  const totalSets = (workout.exercises ?? []).reduce((sum, ex) => sum + (ex.sets?.length ?? 0), 0);
  if (totalSets > 30) warnings.push(`High total set count (${totalSets}).`);
  if (workout.estimatedDurationMinutes > context.targetDurationMinutes + 20) {
    warnings.push("Workout may exceed target duration.");
  }

  if (context.limitations?.includes("severe")) {
    warnings.push("Severe soreness context — reduce intensity.");
  }

  return { isValid: errors.length === 0, errors, warnings };
}

export function buildSystemPrompt(context: CoachContextPayload): string {
  const exerciseList = context.allowedExerciseIds.slice(0, 120).join(", ");
  return `You are HotBod coach — a premium strength training assistant.

RULES:
- Never diagnose injuries or prescribe medical rehab.
- Never invent exercises. Only use exerciseId values from ALLOWED_EXERCISES.
- Never claim exact body fat from photos.
- No steroid or drug advice.
- Be direct, non-cheesy, brutalist tone. Short paragraphs.
- When modifying or generating workouts, output proposedWorkout JSON matching schema.
- Keep sets/reps sane (1-30 reps). Respect equipment and limitations.
- For explain/protein/plateau questions, set proposedWorkout to null.

ALLOWED_EXERCISES: ${exerciseList}

AVAILABLE_EQUIPMENT: ${context.availableEquipment.join(", ")}
TARGET_DURATION_MINUTES: ${context.targetDurationMinutes}
LIMITATIONS: ${context.limitations.join(", ") || "none"}
GOAL: ${context.userProfile.goal}
EXPERIENCE: ${context.userProfile.experienceLevel}`;
}
