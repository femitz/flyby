import React from "react";
import { brand } from "./brand";

export const Cursor: React.FC = () => (
  <svg width={44} height={44} viewBox="0 0 24 24" style={{ filter: "drop-shadow(0 2px 4px rgba(0,0,0,.5))" }}>
    <path d="M5 3l14 8-6 1.6L10.4 19z" fill={brand.lua} stroke={brand.vacuo} strokeWidth={1.2} strokeLinejoin="round" />
  </svg>
);
