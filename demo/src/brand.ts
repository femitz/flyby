// Flyby palette ("direção Órbita"), mirrored from Sources/Flyby/Design/Brand.swift.
import { loadFont as loadSans } from "@remotion/google-fonts/Geist";
import { loadFont as loadMono } from "@remotion/google-fonts/GeistMono";

export const brand = {
  vacuo: "#0B0E14",
  casco: "#151A24",
  orbita: "#2A3142",
  poeira: "#8A93A6",
  lua: "#E6E8EE",
  ignicao: "#FF6B2C",
  textSoft: "#A9B0BF",
  muted: "#4A5266",
} as const;

const sans = loadSans("normal", { weights: ["400", "500", "600"] });
const mono = loadMono("normal", { weights: ["400", "500"] });

export const fonts = {
  sans: sans.fontFamily,
  mono: mono.fontFamily,
};
