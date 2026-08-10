import { PHYSIQUE_FOCUS_MUSCLES } from "./physiqueSchemas.ts";

export type PhysiqueIllustrateRequest = {
  assessmentId: string;
  imageBase64: string;
  priorityMuscles: string[];
  directionGenericLabels: string[];
};

export type PhysiqueIllustrateResponse = {
  imageBase64: string;
  contentType: "image/jpeg" | "image/png";
};

const ALLOWLISTED_MUSCLES = new Set<string>(PHYSIQUE_FOCUS_MUSCLES);

const MUSCLE_DISPLAY_NAMES: Record<(typeof PHYSIQUE_FOCUS_MUSCLES)[number], string> = {
  lateralDelts: "Lateral Delts",
  rearDelts: "Rear Delts",
  lats: "Lats",
  upperChest: "Upper Chest",
  traps: "Traps",
  chest: "Chest",
  shoulders: "Shoulders",
  biceps: "Biceps",
  triceps: "Triceps",
  abs: "Abs",
  glutes: "Glutes",
  quads: "Quads",
  hamstrings: "Hamstrings",
  calves: "Calves",
};

const BANNED_DIRECTION_SUBSTRINGS = [
  "brad",
  "pitt",
  "bruce lee",
  "van damme",
  "you look like",
  "celebrity",
];

const MAX_IMAGE_BYTES = 1_500_000;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function allowlistedMuscleDisplayNames(ids: string[]): string[] {
  return ids
    .filter((id) => ALLOWLISTED_MUSCLES.has(id))
    .slice(0, 3)
    .map((id) => MUSCLE_DISPLAY_NAMES[id as (typeof PHYSIQUE_FOCUS_MUSCLES)[number]]);
}

export function normalizedDirectionLabels(labels: string[]): string[] {
  return labels
    .map((label) => label.trim())
    .filter((label) => label.length > 0)
    .slice(0, 3);
}

function containsBannedDirectionContent(label: string): boolean {
  const lower = label.toLowerCase();
  return BANNED_DIRECTION_SUBSTRINGS.some((term) => lower.includes(term));
}

function decodeBase64Image(base64: string): Uint8Array | null {
  try {
    const stripped = base64.replace(/^data:image\/\w+;base64,/, "");
    const binary = atob(stripped);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  } catch {
    return null;
  }
}

export function buildPhysiqueIllustratePrompt(input: {
  priorityMuscles: string[];
  directionGenericLabels: string[];
}): string {
  const muscles = allowlistedMuscleDisplayNames(input.priorityMuscles);
  const directions = normalizedDirectionLabels(input.directionGenericLabels);
  const muscleLine = muscles.length > 0
    ? `Subtly emphasize these muscle areas: ${muscles.join(", ")}.`
    : "";
  const directionLine = directions.length > 0
    ? `Generic silhouette direction (proportions only, not identity): ${directions.join(", ")}.`
    : "";

  return [
    "Create a subtle illustrative edit of this fitness progress photo for HotBod.",
    "This is an illustration for training motivation — not a prediction of future results.",
    muscleLine,
    directionLine,
    "Keep the exact same person, face, pose, framing, lighting, and clothing.",
    "Apply only very subtle muscular emphasis — no dramatic bulk or physique transformation.",
    "Hard forbids:",
    "- No medical advice, diagnoses, or health claims.",
    "- No body-fat percentages or numeric body-fat estimates.",
    "- No timelines, guarantees, or outcome promises.",
    "- No celebrity likeness, resemblance, or identity comparisons.",
    "- Do not depict a different person or alter facial identity.",
    "- No lookalike, twin, or \"you look like\" language in the visual result.",
  ].filter((line) => line.length > 0).join("\n");
}

export function validatePhysiqueIllustrateRequest(body: PhysiqueIllustrateRequest): string | null {
  const assessmentId = body.assessmentId?.trim();
  if (!assessmentId || !UUID_PATTERN.test(assessmentId)) {
    return "assessmentId must be a valid UUID.";
  }

  const imageBase64 = body.imageBase64?.trim();
  if (!imageBase64) {
    return "imageBase64 is required.";
  }

  const decoded = decodeBase64Image(imageBase64);
  if (!decoded) {
    return "imageBase64 must be valid base64.";
  }
  if (decoded.byteLength > MAX_IMAGE_BYTES) {
    return "imageBase64 exceeds maximum size of 1.5MB.";
  }

  if (!Array.isArray(body.priorityMuscles)) {
    return "priorityMuscles must be an array.";
  }
  const filteredMuscles = body.priorityMuscles.filter((id) => ALLOWLISTED_MUSCLES.has(id)).slice(0, 3);
  if (filteredMuscles.length === 0) {
    return "priorityMuscles must include at least one allowlisted muscle.";
  }

  if (!Array.isArray(body.directionGenericLabels)) {
    return "directionGenericLabels must be an array.";
  }
  const labels = normalizedDirectionLabels(body.directionGenericLabels);
  for (const label of labels) {
    if (containsBannedDirectionContent(label)) {
      return "directionGenericLabels contains disallowed content.";
    }
  }

  return null;
}

export function decodeIllustrateImage(base64: string): ArrayBuffer {
  const decoded = decodeBase64Image(base64);
  if (!decoded) {
    throw new Error("Invalid base64 image.");
  }
  const copy = new Uint8Array(decoded.byteLength);
  copy.set(decoded);
  return copy.buffer;
}

export function sanitizedIllustrateInput(body: PhysiqueIllustrateRequest): {
  priorityMuscles: string[];
  directionGenericLabels: string[];
} {
  return {
    priorityMuscles: body.priorityMuscles.filter((id) => ALLOWLISTED_MUSCLES.has(id)).slice(0, 3),
    directionGenericLabels: normalizedDirectionLabels(body.directionGenericLabels),
  };
}
