import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { brand, fonts } from "./brand";
import { Cursor } from "./Cursor";
import { strings, type Lang } from "./i18n";

// Layout in dock points, mirroring DockView.swift (48 pt icons, 6 pt padding, 2 pt spacing).
const DS = 1.8;
const DW = 541;
const DH = 64;
const DL = (1080 - DW * DS) / 2;
const DT = 760;
const CELL = 52;
const PITCH = 54;
const ICON_Y = 6;
const RISE = 48 * 0.3; // magnify rise
const PROFILE_X = 6;
const RUN_X = [291, 345];
const DL_X = 414;
const TRASH_X = 468;
const DOTS_X = 522;

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.inOut(Easing.cubic);
const toCanvas = (x: number, y: number): [number, number] => [DL + x * DS, DT + y * DS];

// ---- Real app icons (extracted by scripts/extract-icons.swift) --------------
const PROFILE_ICONS = [
  ["terminal", "vscode", "chrome", "claude", "github"],
  ["lightroom", "photos", "preview", "notes", "freeform"],
  ["spotify", "music", "podcasts", "tv", "stremio"],
];
const RUNNING_ICONS = ["mail", "messages"];

const Icon: React.FC<{ name: string }> = ({ name }) => (
  <Img src={staticFile(`icons/${name}.png`)} width={48} height={48} style={{ display: "block" }} />
);

// ---- Timeline (frames relative to the start of the scene) -------------------
const SWITCH_AT = [108, 156];
const SWITCH_LEN = 18;

const cursorKeys: [number, number, number][] = [
  // [t, localX, localY] in dock points; the first and last points sit off the dock.
  [0, 520, 175],
  [26, PROFILE_X + 26, 34],
  [42, PROFILE_X + 26, 34],
  [54, PROFILE_X + PITCH + 26, 34],
  [66, PROFILE_X + PITCH * 2 + 26, 34],
  [76, PROFILE_X + PITCH * 3 + 26, 34],
  [92, PROFILE_X + PITCH * 2 + 26, 34],
  [200, PROFILE_X + PITCH * 2 + 26, 34],
  [232, 520, 175],
];

const keys = (t: number, idx: 1 | 2) =>
  interpolate(t, cursorKeys.map((k) => k[0]), cursorKeys.map((k) => k[idx]), { ...clamp, easing: ease });

const cursorLocal = (t: number): [number, number] => [keys(t, 1), keys(t, 2)];

const hoverId = (t: number): string | null => {
  const [x, y] = cursorLocal(t);
  if (y < -12 || y > DH) return null;
  for (let i = 0; i < 5; i++) if (x >= PROFILE_X + PITCH * i && x < PROFILE_X + PITCH * i + CELL) return `p${i}`;
  return null;
};

/** For each icon: when the pointer entered and left, scanned frame by frame. */
const hoverHistory = (t: number) => {
  const h = new Map<string, { enter: number; leave: number }>();
  let prev: string | null = null;
  for (let f = 0; f <= t; f++) {
    const now = hoverId(f);
    if (now !== prev) {
      if (prev) h.get(prev)!.leave = f;
      if (now) h.set(now, { enter: f, leave: -1 });
      prev = now;
    }
  }
  return h;
};

export const DockScene: React.FC<{ lang: Lang }> = ({ lang }) => {
  const t = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = strings[lang];

  // Which row is shown: finished slides, plus progress of the one in flight.
  const started = SWITCH_AT.filter((at) => t >= at).length;
  const last = SWITCH_AT[started - 1];
  const slide = started > 0 ? interpolate(t, [last, last + SWITCH_LEN], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) }) : 1;
  const switching = started > 0 && slide < 1;
  const activeProfile = switching ? (slide > 0.5 ? started : started - 1) : started;

  // Hover effect per icon.
  const history = hoverHistory(t);
  const hoverAmount = (id: string) => {
    const st = history.get(id);
    if (!st) return 0;
    const cfg = { damping: 9, stiffness: 170, mass: 0.6 };
    if (st.leave < 0) return spring({ frame: t - st.enter, fps, config: cfg });
    return 1 - spring({ frame: t - st.leave, fps, config: cfg });
  };
  const current = hoverId(t);

  const intro = interpolate(t, [0, 20], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const outro = interpolate(t, [218, 238], [1, 0], clamp);
  const opacity = intro * outro;

  const row = (profile: number, dy: number, rowOpacity: number) => (
    <div style={{ position: "absolute", left: PROFILE_X, top: 0, width: 5 * PITCH, height: DH, transform: `translateY(${dy}px)`, opacity: rowOpacity }}>
      {PROFILE_ICONS[profile].map((icon, i) => {
        const id = `p${i}`;
        const a = profile === activeProfile && !switching ? hoverAmount(id) : 0;
        return (
          <div key={i} style={{ position: "absolute", left: i * PITCH, top: ICON_Y, width: CELL, height: 55 }}>
            <div style={{ position: "absolute", left: 2, top: 0, transformOrigin: "50% 100%", transform: `scale(${1 + 0.3 * a})` }}>
              <Icon name={icon} />
            </div>
          </div>
        );
      })}
    </div>
  );

  // Hover name bubble.
  const labelAmount = current && !switching ? hoverAmount(current) : 0;
  const labelIndex = current ? Number(current.slice(1)) : 0;
  const labelText = s.apps[activeProfile][labelIndex];

  // Profile name (the big headline) slides like the row.
  const nameFor = (profile: number, dy: number, o: number) => (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: fonts.sans,
        fontWeight: 600,
        fontSize: 132,
        letterSpacing: "-0.03em",
        color: brand.lua,
        transform: `translateY(${dy}px)`,
        opacity: o,
      }}
    >
      {s.profiles[profile]}
    </div>
  );
  const nameRows = switching ? (
    <>
      {nameFor(started - 1, -slide * 120, 1 - slide)}
      {nameFor(started, (1 - slide) * 120, slide)}
    </>
  ) : (
    nameFor(started, 0, 1)
  );

  const rowRows = switching ? (
    <>
      {row(started - 1, -slide * DH, 1 - slide)}
      {row(started, (1 - slide) * DH, slide)}
    </>
  ) : (
    row(started, 0, 1)
  );

  // Cursor + scroll cue.
  const [lx, ly] = cursorLocal(t);
  const [cx, cy] = toCanvas(lx, ly);
  const cursorOpacity = interpolate(t, [0, 8, 222, 236], [0, 1, 1, 0], clamp);
  const scrollCue = SWITCH_AT.reduce(
    (acc, at) => Math.max(acc, interpolate(t, [at - 10, at - 4, at + 16, at + 26], [0, 1, 1, 0], clamp)),
    0
  );
  const wheelY = (() => {
    for (const at of SWITCH_AT) if (t >= at - 6 && t <= at + 16) return interpolate(t, [at - 6, at + 14], [-7, 7], clamp);
    return -7;
  })();

  return (
    <AbsoluteFill style={{ opacity }}>
      {/* Headline: the active profile */}
      <div style={{ position: "absolute", left: 0, right: 0, top: 392, textAlign: "center", fontFamily: fonts.mono, fontSize: 26, letterSpacing: "0.14em", textTransform: "uppercase", color: brand.poeira }}>
        {s.profileLabel}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 430, height: 170, overflow: "hidden" }}>{nameRows}</div>

      {/* The dock, scaled from points */}
      <div
        style={{
          position: "absolute",
          left: DL,
          top: DT + (1 - intro) * 60,
          width: DW,
          height: DH,
          transformOrigin: "0 0",
          transform: `scale(${DS})`,
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 18,
            background: "rgba(34,39,50,0.72)",
            backdropFilter: "blur(24px)",
            boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.14), 0 14px 40px rgba(0,0,0,0.5)",
          }}
        />

        {/* Profile row: clipped to the dock while sliding, free to grow otherwise */}
        <div style={{ position: "absolute", inset: 0, clipPath: switching ? "inset(0px -8px 0px -8px)" : "inset(-60px -8px -2px -8px)" }}>{rowRows}</div>

        {/* Divider, running apps, divider, Downloads, Trash */}
        {[276, 399].map((x) => (
          <div key={x} style={{ position: "absolute", left: x + 6, top: 10, width: 1, height: 44, background: "rgba(255,255,255,0.18)" }} />
        ))}
        {RUN_X.map((x, i) => (
          <div key={x} style={{ position: "absolute", left: x, top: ICON_Y, width: CELL, height: 55 }}>
            <div style={{ position: "absolute", left: 2, top: 0 }}>
              <Icon name={RUNNING_ICONS[i]} />
            </div>
            <div style={{ position: "absolute", left: 24, top: 51, width: 4, height: 4, borderRadius: 2, background: brand.ignicao }} />
          </div>
        ))}
        <div style={{ position: "absolute", left: DL_X + 2, top: ICON_Y }}><Icon name="downloads" /></div>
        <div style={{ position: "absolute", left: TRASH_X + 2, top: ICON_Y }}><Icon name="trash" /></div>

        {/* Profile dots, stacked vertically like the scroll */}
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              left: DOTS_X + 6.5 - 2.5,
              top: 32 + (i - 1) * 10 - 2.5,
              width: 5,
              height: 5,
              borderRadius: 3,
              background: i === activeProfile ? brand.lua : "rgba(138,147,166,0.45)",
            }}
          />
        ))}

        {/* Hover bubble */}
        <div
          style={{
            position: "absolute",
            left: PROFILE_X + labelIndex * PITCH + CELL / 2,
            top: ICON_Y - 18 - RISE * labelAmount,
            transform: "translate(-50%, -50%)",
            opacity: Math.min(labelAmount * 1.4, 1),
            padding: "4px 10px",
            borderRadius: 14,
            background: "rgba(21,26,36,0.94)",
            boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.12)",
            fontFamily: fonts.sans,
            fontWeight: 500,
            fontSize: 12,
            color: brand.lua,
            whiteSpace: "nowrap",
          }}
        >
          {labelText}
        </div>
      </div>

      {/* Scroll cue: a wheel next to the pointer */}
      <div style={{ position: "absolute", left: cx - 17, top: DT - 118, opacity: scrollCue * cursorOpacity }}>
        <svg width={34} height={52} viewBox="0 0 34 52" fill="none">
          <rect x={2} y={2} width={30} height={48} rx={15} stroke={brand.lua} strokeWidth={2.5} />
          <circle cx={17} cy={26 + wheelY} r={3.5} fill={brand.lua} />
        </svg>
      </div>

      <div style={{ position: "absolute", left: cx - 8, top: cy - 6, opacity: cursorOpacity }}>
        <Cursor />
      </div>
    </AbsoluteFill>
  );
};
