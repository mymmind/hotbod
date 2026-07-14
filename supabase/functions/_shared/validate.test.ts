import {
  assert,
  assertEquals,
  assertFalse,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildSystemPrompt,
  validateWorkout,
  type ValidationResult,
} from "./validate.ts";
import type { CoachContextPayload, GeneratedWorkoutPayload } from "./schemas.ts";

function sampleContext(overrides: Partial<CoachContextPayload> = {}): CoachContextPayload {
  return {
    userProfile: {
      goal: "buildMuscle",
      experienceLevel: "intermediate",
      proteinGoalGrams: 160,
    },
    recentWorkouts: [],
    exerciseStats: [],
    proteinSummary: { todayGrams: 80, goalGrams: 160, streakDays: 2 },
    recovery: { chest: 85, shoulders: 70 },
    limitations: [],
    allowedExerciseIds: ["bench_press", "dumbbell_press", "push_up", "cable_fly"],
    availableEquipment: ["barbell", "dumbbell", "cable"],
    targetDurationMinutes: 45,
    ...overrides,
  };
}

function sampleWorkout(overrides: Partial<GeneratedWorkoutPayload> = {}): GeneratedWorkoutPayload {
  return {
    title: "Upper Push",
    estimatedDurationMinutes: 45,
    focus: ["chest", "shoulders"],
    rationale: "Balanced push session.",
    safetyNotes: [],
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 6, targetRepsMax: 8 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 10, targetRepsMax: 12 }] },
      { exerciseId: "cable_fly", sets: [{ targetRepsMin: 12, targetRepsMax: 15 }] },
    ],
    ...overrides,
  };
}

function assertValid(result: ValidationResult) {
  assert(result.isValid, result.errors.join("; "));
}

Deno.test("validateWorkout accepts a well-formed workout", () => {
  const result = validateWorkout(sampleWorkout(), sampleContext());
  assertValid(result);
});

Deno.test("validateWorkout rejects fewer than four exercises", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
  assertMatch(result.errors.join(" "), /fewer than 4 exercises/i);
});

Deno.test("validateWorkout rejects duplicate exercise ids", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "cable_fly", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
  assertMatch(result.errors.join(" "), /Duplicate exercise/i);
});

Deno.test("validateWorkout rejects disallowed exercise ids", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "unknown_exercise", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
  assertMatch(result.errors.join(" "), /disallowed exercise/i);
});

Deno.test("validateWorkout rejects invalid rep ranges", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 0, targetRepsMax: 8 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "cable_fly", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
  assertMatch(result.errors.join(" "), /Invalid rep range/i);
});

Deno.test("validateWorkout rejects inverted rep ranges", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 12, targetRepsMax: 8 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "cable_fly", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
});

Deno.test("validateWorkout warns on high total set count", () => {
  const manySets = Array.from({ length: 8 }, () => ({ targetRepsMin: 8, targetRepsMax: 10 }));
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: manySets },
      { exerciseId: "dumbbell_press", sets: manySets },
      { exerciseId: "push_up", sets: manySets },
      { exerciseId: "cable_fly", sets: manySets },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assert(result.isValid);
  assert(result.warnings.some((w) => /High total set count/i.test(w)));
});

Deno.test("validateWorkout warns when duration exceeds target", () => {
  const workout = sampleWorkout({ estimatedDurationMinutes: 90 });
  const result = validateWorkout(workout, sampleContext({ targetDurationMinutes: 45 }));
  assert(result.isValid);
  assert(result.warnings.some((w) => /target duration/i.test(w)));
});

Deno.test("validateWorkout warns on severe soreness context", () => {
  const result = validateWorkout(
    sampleWorkout(),
    sampleContext({ limitations: ["severe"] }),
  );
  assert(result.isValid);
  assert(result.warnings.some((w) => /Severe soreness/i.test(w)));
});

Deno.test("buildSystemPrompt includes allowed exercises", () => {
  const prompt = buildSystemPrompt(sampleContext());
  assertMatch(prompt, /bench_press/);
  assertMatch(prompt, /ALLOWED_EXERCISES/);
});

Deno.test("buildSystemPrompt includes equipment and goal", () => {
  const prompt = buildSystemPrompt(sampleContext());
  assertMatch(prompt, /barbell/);
  assertMatch(prompt, /buildMuscle/i);
  assertMatch(prompt, /TARGET_DURATION_MINUTES: 45/);
});

Deno.test("buildSystemPrompt states limitations or none", () => {
  const withLimits = buildSystemPrompt(sampleContext({ limitations: ["shoulder"] }));
  assertMatch(withLimits, /shoulder/);

  const without = buildSystemPrompt(sampleContext({ limitations: [] }));
  assertMatch(without, /LIMITATIONS: none/);
});

Deno.test("buildSystemPrompt forbids medical claims", () => {
  const prompt = buildSystemPrompt(sampleContext());
  assertMatch(prompt, /Never diagnose injuries/i);
  assertMatch(prompt, /Never claim exact body fat/i);
});

Deno.test("validateWorkout handles missing exercises array", () => {
  const workout = sampleWorkout({ exercises: undefined as unknown as GeneratedWorkoutPayload["exercises"] });
  const result = validateWorkout(workout, sampleContext());
  assertFalse(result.isValid);
});

Deno.test("validateWorkout accepts reps at upper bound", () => {
  const workout = sampleWorkout({
    exercises: [
      { exerciseId: "bench_press", sets: [{ targetRepsMin: 20, targetRepsMax: 30 }] },
      { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "push_up", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      { exerciseId: "cable_fly", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
    ],
  });
  const result = validateWorkout(workout, sampleContext());
  assertValid(result);
});
