# Exercise prescription override schema

HotBod merges `ExercisePrescriptionOverrides.json` over global generation defaults (goal × mechanics matrix). Add one entry per exercise when you have research-backed prescriptions.

## File location

`HotBod/Resources/ExercisePrescriptionOverrides.json`

## Shape

```json
{
  "exercises": {
    "plank": {
      "prescriptionType": "time",
      "defaultDurationSeconds": 45,
      "sets": 3,
      "restSeconds": 30,
      "rpeTarget": 7
    },
    "farmers_carry": {
      "prescriptionType": "distanceOrTime",
      "defaultDistanceMeters": 40,
      "sets": 3,
      "restSeconds": 60,
      "weightDisplaySemantics": "perHand"
    },
    "dumbbell_fly": {
      "repRangeMin": 10,
      "repRangeMax": 12,
      "sets": 3,
      "restSeconds": 75,
      "weightDisplaySemantics": "perHand"
    }
  }
}
```

## Fields (all optional per exercise)

| Field | Type | Description |
|-------|------|-------------|
| `sets` | int | Working set count |
| `repRangeMin` / `repRangeMax` | int | Rep prescription (reps-only exercises) |
| `restSeconds` | int | Rest between working sets |
| `warmupSets` | int | Override warmup count (future) |
| `rpeTarget` | number | Target RPE 6–10 |
| `prescriptionType` | `reps` \| `time` \| `distance` \| `distanceOrTime` | Logging + generation mode |
| `defaultDurationSeconds` | int | Timed exercises (plank, rower) |
| `defaultDistanceMeters` | number | Distance exercises (carry, sled) |
| `weightDisplaySemantics` | `total` \| `perHand` | Session label: KG vs KG EACH |

## Notes

- Exercise `id` must match `ExerciseSeed.json` (never rename ids).
- Omitted fields fall back to global rules in `GenerationConstants`.
- Send any spreadsheet/CSV — we can convert to this JSON format.
