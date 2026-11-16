import React from "react";

// FlybyGlyph from Sources/Flyby/Utilities/AppIcon.swift, drawn in a 120x120 box.
const WEIGHTS = {
  regular: { line: 7, head: 11, dot: 6.5 },
  medium: { line: 10, head: 12, dot: 8 },
  heavy: { line: 11, head: 13, dot: 9 },
} as const;

export const Glyph: React.FC<{
  size: number;
  ink: string;
  dot: string;
  weight?: keyof typeof WEIGHTS;
  /** 0..1: how much of the trail is drawn. */
  draw?: number;
  /** 0..1: scale/opacity of the head and the dot. */
  reveal?: number;
}> = ({ size, ink, dot, weight = "regular", draw = 1, reveal = 1 }) => {
  const w = WEIGHTS[weight];
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" style={{ overflow: "visible" }}>
      <circle
        cx={84}
        cy={50}
        r={w.head}
        fill={ink}
        opacity={reveal}
        style={{ transformOrigin: "84px 50px", transform: `scale(${reveal})` }}
      />
      <path
        d="M14 100 C40 92 60 76 84 76 A26 26 0 1 0 61.5 37 C52 52 40 62 26 70"
        fill="none"
        stroke={ink}
        strokeWidth={w.line}
        strokeLinecap="round"
        strokeLinejoin="round"
        pathLength={1}
        strokeDasharray={`${draw} 2`}
        opacity={draw > 0.001 ? 1 : 0}
      />
      <circle
        cx={26}
        cy={70}
        r={w.dot}
        fill={dot}
        opacity={reveal}
        style={{ transformOrigin: "26px 70px", transform: `scale(${reveal})` }}
      />
    </svg>
  );
};
