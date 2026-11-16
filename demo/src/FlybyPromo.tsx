import React from "react";
import { AbsoluteFill, Audio, Easing, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { brand, fonts } from "./brand";
import { Cursor } from "./Cursor";
import { DockScene } from "./DockScene";
import { Glyph } from "./Glyph";
import { strings, type Lang } from "./i18n";
import { LOCAL, PANEL_H, PANEL_W, Panel } from "./Panel";

export type PromoProps = { lang: Lang };

const W = 1080;
const H = 1350;
const SCALE = 1.85; // panel scale on the canvas
const PANEL_LEFT = (W - PANEL_W * SCALE) / 2;
const PANEL_TOP = 110;

/** Panel-local point -> canvas point. */
const toCanvas = (x: number, y: number): [number, number] => [PANEL_LEFT + x * SCALE, PANEL_TOP + y * SCALE];

const ease = Easing.inOut(Easing.cubic);
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Interpolate one value through [frame, value] keyframes with easing between them. */
const keys = (frame: number, pts: [number, number][]) =>
  interpolate(frame, pts.map((p) => p[0]), pts.map((p) => p[1]), { ...clamp, easing: ease });

// ---- Timeline (30 fps, 15 s) ------------------------------------------------
const CLICK_OPEN = 28;
const CLICK_MUTE = 324;
const DRAG_START = 258;
const DRAG_END = 296;
export const DOCK_START = 400;
export const DOCK_LEN = 240;
const END = DOCK_LEN; // the end card starts this many frames later than it did without the Dock scene

// Camera: scale s, canvas point (fx, fy) that lands at screen (540, sy).
const camera = (f: number) => {
  const pts = (i: number): [number, number][] =>
    [
      [0, 1, 540, 675, 675],
      [48, 1, 540, 675, 675],
      [88, 1.28, 540, 400, 520],
      [205, 1.28, 540, 400, 520],
      [240, 1.28, 540, 830, 640],
      [372, 1.28, 540, 830, 640],
      [400, 1, 540, 675, 675],
    ].map((k) => [k[0], k[i + 1]] as [number, number]);
  const s = keys(f, pts(0));
  const fx = keys(f, pts(1));
  const fy = keys(f, pts(2));
  const sy = keys(f, pts(3));
  return { s, tx: 540 - s * fx, ty: sy - s * fy };
};

const [SLIDER_X0, SLIDER_Y] = toCanvas(LOCAL.sliderLeft + LOCAL.sliderWidth, LOCAL.spotifySliderY);
const [SLIDER_X1] = toCanvas(LOCAL.sliderLeft + LOCAL.sliderWidth * 0.35, 0);
const [MUTE_X, MUTE_Y] = toCanvas(LOCAL.safariMuteX, LOCAL.safariMuteY);

const cursorPath: [number, number, number][] = [
  [0, 760, 620],
  [24, 862, 36],
  [60, 862, 36],
  [95, 700, 330],
  [205, 700, 330],
  [250, SLIDER_X0, SLIDER_Y],
  [DRAG_START, SLIDER_X0, SLIDER_Y],
  [DRAG_END, SLIDER_X1, SLIDER_Y],
  [322, MUTE_X, MUTE_Y],
  [360, MUTE_X, MUTE_Y],
  [390, 640, 1020],
];
const cursorAt = (f: number): [number, number] => [
  keys(f, cursorPath.map((p) => [p[0], p[1]])),
  keys(f, cursorPath.map((p) => [p[0], p[2]])),
];

// Deterministic star field.
const stars = (() => {
  let seed = 7;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  return Array.from({ length: 70 }, () => ({
    x: rnd() * W,
    y: rnd() * H,
    r: 0.8 + rnd() * 1.4,
    phase: rnd() * Math.PI * 2,
    base: 0.15 + rnd() * 0.35,
  }));
})();

const Stars: React.FC<{ frame: number }> = ({ frame }) => (
  <svg width={W} height={H} style={{ position: "absolute", inset: 0 }}>
    {stars.map((s, i) => (
      <circle key={i} cx={s.x} cy={s.y} r={s.r} fill={brand.lua} opacity={s.base * (0.65 + 0.35 * Math.sin(frame / 18 + s.phase))} />
    ))}
  </svg>
);

const Ripple: React.FC<{ frame: number; at: number; x: number; y: number }> = ({ frame, at, x, y }) => {
  const p = interpolate(frame, [at, at + 14], [0, 1], clamp);
  if (frame < at || p >= 1) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: x - 36,
        top: y - 36,
        width: 72,
        height: 72,
        borderRadius: 36,
        border: `3px solid ${brand.lua}`,
        opacity: 0.7 * (1 - p),
        transform: `scale(${0.3 + 0.7 * p})`,
      }}
    />
  );
};

const Caption: React.FC<{ text: string; frame: number; inAt: number; outAt: number }> = ({ text, frame, inAt, outAt }) => {
  const o = interpolate(frame, [inAt, inAt + 14, outAt, outAt + 12], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        bottom: 62,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        gap: 16,
        opacity: o,
        transform: `translateY(${(1 - o) * 10}px)`,
        fontFamily: fonts.mono,
        fontSize: 30,
        letterSpacing: "0.14em",
        textTransform: "uppercase",
        color: brand.textSoft,
      }}
    >
      <span style={{ width: 10, height: 10, borderRadius: 5, background: brand.ignicao }} />
      {text}
    </div>
  );
};

const MenuBar: React.FC<{ frame: number }> = ({ frame }) => {
  const open = frame >= CLICK_OPEN && frame < 395;
  const cpu = 0.2 + 0.04 * Math.sin(frame / 9);
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: W,
        height: 64,
        background: brand.casco,
        borderBottom: `1px solid ${brand.orbita}`,
        display: "flex",
        alignItems: "center",
        fontFamily: fonts.sans,
        fontSize: 22,
        color: brand.textSoft,
      }}
    >
      <div style={{ display: "flex", gap: 34, marginLeft: 36, fontWeight: 500 }}>
        <span style={{ color: brand.lua, fontWeight: 600 }}>Finder</span>
        <span>File</span>
        <span>Edit</span>
        <span>View</span>
      </div>
      <div
        style={{
          position: "absolute",
          left: 790,
          top: 10,
          width: 144,
          height: 44,
          borderRadius: 10,
          background: open ? brand.orbita : "transparent",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 10,
        }}
      >
        <Glyph size={28} ink={brand.lua} dot={brand.lua} weight="heavy" />
        <span style={{ fontFamily: fonts.mono, color: brand.lua }}>{Math.round(cpu * 100)}%</span>
      </div>
      <span style={{ position: "absolute", left: 960, fontFamily: fonts.mono, fontSize: 21 }}>9:41</span>
    </div>
  );
};

export const FlybyPromo: React.FC<PromoProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const t = strings[lang];
  const cam = camera(frame);
  const transform = `translate(${cam.tx}px, ${cam.ty}px) scale(${cam.s})`;

  // Panel in / out.
  const panelIn = interpolate(frame, [CLICK_OPEN + 2, CLICK_OPEN + 18], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const panelOut = interpolate(frame, [380, 402], [1, 0], clamp);
  const panelOpacity = panelIn * panelOut;
  const panelScale = (0.94 + 0.06 * panelIn) * (0.97 + 0.03 * panelOut);
  const panelShift = (1 - panelIn) * -14;

  // Live telemetry.
  const settle = interpolate(frame, [CLICK_OPEN + 16, CLICK_OPEN + 70], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const cpu = settle * (0.23 + 0.05 * Math.sin(frame / 9) + 0.03 * Math.sin(frame / 4.3));
  const ram = settle * (0.62 + 0.01 * Math.sin(frame / 31));
  const thermal = settle * 0.25;

  // Mixer: the Spotify slider follows the cursor while it is dragged.
  const [cx] = cursorAt(frame);
  const dragged = Math.min(Math.max(((cx - PANEL_LEFT) / SCALE - LOCAL.sliderLeft) / LOCAL.sliderWidth, 0), 1);
  const spotify = frame < DRAG_START ? 1 : dragged;
  const safariMuted = frame >= CLICK_MUTE;

  const [curX, curY] = cursorAt(frame);
  const cursorOpacity = interpolate(frame, [0, 6, 372, 386], [0, 1, 1, 0], clamp);
  const pressed = frame >= DRAG_START && frame < DRAG_END + 2;

  // Menu bar leaves before the end card.
  const barOpacity = interpolate(frame, [396, 410], [1, 0], clamp);

  // End card.
  const e = frame - END;
  const endDraw = interpolate(e, [398, 428], [0, 1], { ...clamp, easing: ease });
  const endReveal = interpolate(e, [418, 434], [0, 1], { ...clamp, easing: Easing.out(Easing.back(1.6)) });
  const wordIn = interpolate(e, [424, 440], [0, 1], clamp);
  const tagIn = interpolate(e, [434, 448], [0, 1], clamp);

  return (
    <AbsoluteFill style={{ background: brand.vacuo, overflow: "hidden" }}>
      {/* Original synthesized track (scripts/make-music.py); the fades are baked into the file */}
      <Audio src={staticFile("music.wav")} volume={0.9} />
      <Stars frame={frame} />

      {/* Camera layer: panel */}
      <AbsoluteFill style={{ transformOrigin: "0 0", transform }}>
        <div
          style={{
            position: "absolute",
            left: PANEL_LEFT,
            top: PANEL_TOP,
            width: PANEL_W,
            height: PANEL_H,
            transformOrigin: "0 0",
            transform: `scale(${SCALE})`,
          }}
        >
          <div
            style={{
              width: PANEL_W,
              height: PANEL_H,
              opacity: panelOpacity,
              transformOrigin: `${(860 - PANEL_LEFT) / SCALE}px 0px`,
              transform: `translateY(${panelShift}px) scale(${panelScale})`,
              boxShadow: "0 16px 48px rgba(0,0,0,.55)",
              borderRadius: 16,
            }}
          >
            <Panel
              lang={lang}
              cpu={cpu}
              ram={ram}
              thermal={thermal}
              seconds={Math.floor(frame / 30)}
              volumes={{ main: 0.7, spotify, slack: 0.64, safari: 1 }}
              safariMuted={safariMuted}
            />
          </div>
        </div>
      </AbsoluteFill>

      {/* Menu bar */}
      <div style={{ opacity: barOpacity }}>
        <MenuBar frame={frame} />
      </div>

      {/* Bottom fade + captions */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 0,
          height: 260,
          background: `linear-gradient(to bottom, rgba(11,14,20,0), ${brand.vacuo} 55%)`,
          opacity: interpolate(frame, [380, 400], [1, 0], clamp),
        }}
      />
      <Caption text={t.captionTelemetry} frame={frame} inAt={72} outAt={196} />
      <Caption text={t.captionMixer} frame={frame} inAt={232} outAt={362} />
      <Caption text={t.captionDock} frame={frame} inAt={DOCK_START + 10} outAt={DOCK_START + 96} />
      <Caption text={t.captionScroll} frame={frame} inAt={DOCK_START + 102} outAt={DOCK_START + 206} />

      {/* Dock scene */}
      <Sequence from={DOCK_START} durationInFrames={DOCK_LEN}>
        <DockScene lang={lang} />
      </Sequence>

      {/* Cursor in the same camera space (above the menu bar) */}
      <AbsoluteFill style={{ transformOrigin: "0 0", transform, opacity: cursorOpacity }}>
        <Ripple frame={frame} at={CLICK_OPEN} x={curX} y={curY} />
        <Ripple frame={frame} at={DRAG_START} x={curX} y={curY} />
        <Ripple frame={frame} at={CLICK_MUTE} x={curX} y={curY} />
        <div style={{ position: "absolute", left: curX - 8, top: curY - 6, transform: `scale(${pressed ? 0.88 : 1})`, transformOrigin: "8px 6px" }}>
          <Cursor />
        </div>
      </AbsoluteFill>

      {/* End card */}
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 28 }}>
        <Glyph size={260} ink={brand.lua} dot={brand.ignicao} weight="regular" draw={endDraw} reveal={e < 398 ? 0 : endReveal} />
        <div
          style={{
            fontFamily: fonts.sans,
            fontWeight: 600,
            fontSize: 132,
            letterSpacing: "-0.03em",
            color: brand.lua,
            opacity: wordIn,
            transform: `translateY(${(1 - wordIn) * 14}px)`,
            lineHeight: 1,
          }}
        >
          flyby
        </div>
        <div
          style={{
            fontFamily: fonts.mono,
            fontSize: 25,
            letterSpacing: "0.12em",
            textTransform: "uppercase",
            color: brand.poeira,
            opacity: tagIn,
            textAlign: "center",
          }}
        >
          {t.tagline}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
