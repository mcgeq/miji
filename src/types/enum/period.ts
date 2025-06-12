export const ExerciseIntensity = {
  None: 0,
  Light: 1,
  Medium: 2,
  Heavy: 3,
} as const;

export type ExerciseIntensity =
  (typeof ExerciseIntensity)[keyof typeof ExerciseIntensity];

export const FlowLevel = {
  Light: 0,
  Medium: 1,
  Heavy: 2,
} as const;

export type FlowLevel = (typeof FlowLevel)[keyof typeof FlowLevel];

export const Intensity = {
  Light: 0,
  Medium: 1,
  Heavy: 2,
} as const;

export type Intensity = (typeof Intensity)[keyof typeof Intensity];

export const SymptomsType = {
  Pain: 0,
  Fatigue: 1,
  MoodSwing: 2,
} as const;

export type SymptomsType = (typeof SymptomsType)[keyof typeof SymptomsType];
