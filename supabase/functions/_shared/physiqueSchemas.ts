export const PHYSIQUE_FOCUS_MUSCLES = [
  "lateralDelts",
  "rearDelts",
  "lats",
  "upperChest",
  "traps",
  "chest",
  "shoulders",
  "biceps",
  "triceps",
  "abs",
  "glutes",
  "quads",
  "hamstrings",
  "calves",
] as const;

export const PHYSIQUE_CONFIDENCE_LEVELS = [
  "high",
  "medium",
  "low",
  "uncertain",
] as const;

export const MUSCLE_GROUPS = [
  "chest",
  "back",
  "shoulders",
  "biceps",
  "triceps",
  "forearms",
  "abs",
  "obliques",
  "quads",
  "hamstrings",
  "glutes",
  "calves",
  "lowerBack",
  "traps",
  "adductors",
  "abductors",
] as const;

export interface BodyPhotoAnalysisLike {
  poseConfidence: number;
  lightingScore: number;
  framingScore: number;
  shoulderWidthEstimate?: number | null;
  waistWidthEstimate?: number | null;
  hipWidthEstimate?: number | null;
  shoulderWaistRatio?: number | null;
  postureNotes: string[];
  comparisonSummary?: string | null;
  limitations: string[];
}

export interface AllowedArchetypeLike {
  id: string;
  genericLabel: string;
  tags: string[];
}

export interface PhysiqueDirectionLike {
  archetypeId: string;
  rank: number;
  similarityDimension: string;
  confidence: (typeof PHYSIQUE_CONFIDENCE_LEVELS)[number];
}

export interface PhysiqueAssessRequest {
  metrics: {
    front: BodyPhotoAnalysisLike;
    back?: BodyPhotoAnalysisLike;
    side?: BodyPhotoAnalysisLike;
  };
  anglesAvailable: ("front" | "back" | "side")[];
  profile: {
    goal: string;
    experienceLevel: string;
    limitations: string[];
  };
  allowedArchetypes: AllowedArchetypeLike[];
}

export interface PhysiqueAssessResponsePayload {
  photoQuality: {
    anglesAvailable: string[];
    lightingQuality: string;
    overallConfidence: number;
  };
  physique: {
    overallArchetype: string;
    frameSize: string;
    shoulderToWaist: string;
    waist: string;
    torso: string;
    muscularity: string;
    leanness: string;
  };
  muscleEntries: Array<{
    muscle: string;
    current: string;
    priorityRank?: number | null;
    notes: string;
    confidence: string;
  }>;
  developmentPriorities: Array<{
    muscle: string;
    reason: string;
  }>;
  trainingBias: {
    preferredMuscleGroups: string[];
    rationale: string;
  };
  limitations: string[];
  confidenceBands: {
    high: string[];
    medium: string[];
    low: string[];
  };
  whyTodaySummary: string;
  physiqueDirections: PhysiqueDirectionLike[];
}


export const PHYSIQUE_ASSESS_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "photoQuality",
    "physique",
    "muscleEntries",
    "developmentPriorities",
    "trainingBias",
    "limitations",
    "confidenceBands",
    "whyTodaySummary",
    "physiqueDirections",
  ],
  properties: {
    photoQuality: {
      type: "object",
      additionalProperties: false,
      required: ["anglesAvailable", "lightingQuality", "overallConfidence"],
      properties: {
        anglesAvailable: {
          type: "array",
          items: { type: "string", enum: ["front", "back", "side"] },
        },
        lightingQuality: { type: "string" },
        overallConfidence: { type: "number" },
      },
    },
    physique: {
      type: "object",
      additionalProperties: false,
      required: [
        "overallArchetype",
        "frameSize",
        "shoulderToWaist",
        "waist",
        "torso",
        "muscularity",
        "leanness",
      ],
      properties: {
        overallArchetype: { type: "string" },
        frameSize: { type: "string" },
        shoulderToWaist: { type: "string" },
        waist: { type: "string" },
        torso: { type: "string" },
        muscularity: { type: "string" },
        leanness: { type: "string" },
      },
    },
    muscleEntries: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["muscle", "current", "priorityRank", "notes", "confidence"],
        properties: {
          muscle: { type: "string", enum: [...PHYSIQUE_FOCUS_MUSCLES] },
          current: { type: "string" },
          priorityRank: { type: ["number", "null"] },
          notes: { type: "string" },
          confidence: { type: "string", enum: [...PHYSIQUE_CONFIDENCE_LEVELS] },
        },
      },
    },
    developmentPriorities: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["muscle", "reason"],
        properties: {
          muscle: { type: "string", enum: [...PHYSIQUE_FOCUS_MUSCLES] },
          reason: { type: "string" },
        },
      },
    },
    trainingBias: {
      type: "object",
      additionalProperties: false,
      required: ["preferredMuscleGroups", "rationale"],
      properties: {
        preferredMuscleGroups: {
          type: "array",
          items: { type: "string", enum: [...MUSCLE_GROUPS] },
        },
        rationale: { type: "string" },
      },
    },
    limitations: { type: "array", items: { type: "string" } },
    confidenceBands: {
      type: "object",
      additionalProperties: false,
      required: ["high", "medium", "low"],
      properties: {
        high: { type: "array", items: { type: "string" } },
        medium: { type: "array", items: { type: "string" } },
        low: { type: "array", items: { type: "string" } },
      },
    },
    whyTodaySummary: { type: "string" },
    physiqueDirections: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["archetypeId", "rank", "similarityDimension", "confidence"],
        properties: {
          archetypeId: { type: "string" },
          rank: { type: "number" },
          similarityDimension: { type: "string" },
          confidence: { type: "string", enum: [...PHYSIQUE_CONFIDENCE_LEVELS] },
        },
      },
    },
  },
} as const;

export function buildPhysiqueSystemPrompt(): string {
  return [
    "You are a strength-training physique assessment assistant for HotBod.",
    "Use only the supplied Vision metrics and optional profile context.",
    "Produce a structured physique assessment for training bias — not medical advice.",
    "",
    "Hard rules:",
    "- Never state exact body-fat percentages or numeric body-fat ranges.",
    "- Never provide medical diagnoses, injury diagnoses, or treatment advice.",
    "- Never claim genetic destiny, fixed somatotype fate, or unchangeable genetics.",
    "- Use descriptive, qualitative language for build and leanness.",
    "- Mark observations you cannot support as confidence \"uncertain\" and omit them from developmentPriorities.",
    "- Include confidence on every muscleEntries item.",
    "- Rank developmentPriorities by visual return for this frame (highest first).",
    "- Keep limitations practical (visibility, angle gaps, visual-estimate disclaimer).",
    '- When anglesAvailable lacks "back", do not invent posterior or back-photo musculature metrics or claim back-photo evidence.',
    "- whyTodaySummary: 3-5 lines linking priorities to today's training bias.",
    "",
    "Physique directions (physiqueDirections):",
    "- Rank exactly 1–3 directions from allowedArchetypes only (use archetypeId values).",
    "- Describe proportions or silhouette in similarityDimension — not identity or resemblance.",
    "- Never say \"you look like\", celebrity names, twin/lookalike language, or identity claims.",
    "- Never cite body-fat percentages or genetic destiny in similarityDimension.",
    "- Order by rank 1 (closest proportional match) through 3.",
    "",
    "Allowed muscle ids:",
    PHYSIQUE_FOCUS_MUSCLES.join(", "),
  ].join("\n");
}

export function validatePhysiqueRequest(body: PhysiqueAssessRequest): string | null {
  if (!body.metrics?.front) {
    return "metrics.front is required.";
  }
  if (!Array.isArray(body.anglesAvailable) || body.anglesAvailable.length === 0) {
    return "anglesAvailable is required.";
  }
  if (!body.anglesAvailable.includes("front")) {
    return "anglesAvailable must include front.";
  }
  if (body.anglesAvailable.includes("back") && !body.metrics?.back) {
    return "metrics.back is required when anglesAvailable includes back.";
  }
  if (!body.profile?.goal?.trim() || !body.profile?.experienceLevel?.trim()) {
    return "profile.goal and profile.experienceLevel are required.";
  }
  if (!Array.isArray(body.allowedArchetypes) || body.allowedArchetypes.length === 0) {
    return "allowedArchetypes must be a non-empty array.";
  }
  for (const entry of body.allowedArchetypes) {
    if (!entry?.id?.trim() || !entry?.genericLabel?.trim() || !Array.isArray(entry.tags)) {
      return "Each allowedArchetypes entry requires id, genericLabel, and tags.";
    }
  }
  return null;
}
