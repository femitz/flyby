import React from "react";
import { brand, fonts } from "./brand";
import { Glyph } from "./Glyph";
import { strings, type Lang } from "./i18n";

/**
 * The menu bar panel, drawn with the same metrics as PanelView.swift (380 pt wide, 20 pt
 * padding, 20 pt between sections). Everything is absolutely positioned so the video can
 * aim the cursor at exact points; see LOCAL below.
 */
export const PANEL_W = 380;
export const PANEL_H = 605;

/** Panel-local coordinates the cursor aims at. */
export const LOCAL = {
  sliderLeft: 64,
  sliderWidth: 264,
  spotifySliderY: 356 + 34,
  safariMuteX: 350,
  safariMuteY: 406 + 22,
};

const Label: React.FC<{ children: string }> = ({ children }) => (
  <span
    style={{
      fontFamily: fonts.mono,
      fontSize: 11,
      letterSpacing: 1.5,
      textTransform: "uppercase",
      color: brand.poeira,
    }}
  >
    {children}
  </span>
);

const Ring: React.FC<{
  fraction: number;
  value: string;
  label: string;
  detail: string;
}> = ({ fraction, value, label, detail }) => {
  const r = 34;
  const c = 2 * Math.PI * r;
  const f = Math.min(Math.max(fraction, 0.001), 1);
  const a = -Math.PI / 2 + f * 2 * Math.PI;
  return (
    <div style={{ width: 108, display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
      <div style={{ position: "relative", width: 88, height: 88 }}>
        <svg width={88} height={88}>
          <circle cx={44} cy={44} r={r} fill="none" stroke={brand.orbita} strokeWidth={5} />
          <circle
            cx={44}
            cy={44}
            r={r}
            fill="none"
            stroke={brand.lua}
            strokeWidth={5}
            strokeLinecap="round"
            strokeDasharray={`${c * f} ${c}`}
            transform="rotate(-90 44 44)"
          />
          <circle cx={44 + r * Math.cos(a)} cy={44 + r * Math.sin(a)} r={5} fill={brand.ignicao} />
        </svg>
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily: fonts.mono,
            fontWeight: 500,
            fontSize: 17,
            color: brand.lua,
          }}
        >
          {value}
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
        <span style={{ fontFamily: fonts.sans, fontWeight: 500, fontSize: 13, color: brand.lua, lineHeight: "16px" }}>
          {label}
        </span>
        <span style={{ fontFamily: fonts.mono, fontSize: 11, color: brand.poeira, lineHeight: "14px" }}>
          {detail}
        </span>
      </div>
    </div>
  );
};

const Speaker: React.FC<{ muted: boolean }> = ({ muted }) => (
  <svg width={20} height={20} viewBox="0 0 20 20" fill="none" stroke={muted ? brand.poeira : brand.lua} strokeWidth={1.4} strokeLinecap="round" strokeLinejoin="round">
    <path d="M3 7.5h3l4-3.5v12l-4-3.5H3z" />
    {muted ? (
      <path d="M13.5 7.5l4 5m0-5l-4 5" />
    ) : (
      <>
        <path d="M13 7.5c1 1.4 1 3.6 0 5" />
        <path d="M15.5 5.5c2 2.6 2 6.4 0 9" />
      </>
    )}
  </svg>
);

const MixerRow: React.FC<{
  top: number;
  initials: string;
  name: string;
  volume: number;
  muted: boolean;
  mutedLabel: string;
}> = ({ top, initials, name, volume, muted, mutedLabel }) => {
  const v = Math.min(Math.max(volume, 0), 1);
  const w = LOCAL.sliderWidth;
  return (
    <div style={{ position: "absolute", left: 20, top, width: 340, height: 44, opacity: muted ? 0.6 : 1 }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 6,
          width: 32,
          height: 32,
          borderRadius: 8,
          background: brand.orbita,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: fonts.mono,
          fontWeight: 500,
          fontSize: 12,
          color: brand.lua,
        }}
      >
        {initials}
      </div>
      <div style={{ position: "absolute", left: 44, top: 0, width: w, height: 16, display: "flex", justifyContent: "space-between" }}>
        <span style={{ fontFamily: fonts.sans, fontWeight: 500, fontSize: 13, color: brand.lua, lineHeight: "16px" }}>{name}</span>
        <span style={{ fontFamily: fonts.mono, fontSize: 12, color: brand.textSoft, lineHeight: "16px" }}>
          {muted ? mutedLabel : `${Math.round(v * 100)}%`}
        </span>
      </div>
      <div style={{ position: "absolute", left: 44, top: 24, width: w, height: 20 }}>
        <div style={{ position: "absolute", top: 8, left: 0, width: w, height: 4, borderRadius: 2, background: brand.orbita }} />
        <div
          style={{
            position: "absolute",
            top: 8,
            left: 0,
            width: w * v,
            height: 4,
            borderRadius: 2,
            background: muted ? brand.muted : brand.ignicao,
          }}
        />
        <div style={{ position: "absolute", top: 0, left: w * v - 10, width: 20, height: 20, borderRadius: 10, background: brand.casco }} />
        <div style={{ position: "absolute", top: 3, left: w * v - 7, width: 14, height: 14, borderRadius: 7, background: brand.lua }} />
      </div>
      <div style={{ position: "absolute", left: 320, top: 12, width: 20, height: 20 }}>
        <Speaker muted={muted} />
      </div>
    </div>
  );
};

export type PanelProps = {
  lang: Lang;
  cpu: number;
  ram: number;
  thermal: number;
  seconds: number;
  volumes: { main: number; spotify: number; slack: number; safari: number };
  safariMuted: boolean;
};

export const Panel: React.FC<PanelProps> = ({ lang, cpu, ram, thermal, seconds, volumes, safariMuted }) => {
  const t = strings[lang];
  const ramUsed = (ram * 16).toFixed(1).replace(".", t.decimal);
  const pad = (n: number) => String(n).padStart(2, "0");
  const base = 3 * 86400 + 4 * 3600 + 12 * 60 + 7 + seconds;
  const mission = `${Math.floor(base / 86400)}d ${pad(Math.floor(base / 3600) % 24)}:${pad(Math.floor(base / 60) % 60)}:${pad(base % 60)}`;

  return (
    <div
      style={{
        position: "relative",
        width: PANEL_W,
        height: PANEL_H,
        boxSizing: "border-box",
        background: brand.casco,
        border: `1px solid ${brand.orbita}`,
        borderRadius: 16,
        color: brand.lua,
      }}
    >
      {/* Header */}
      <div style={{ position: "absolute", left: 20, top: 20, width: 340, height: 40, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Glyph size={24} ink={brand.lua} dot={brand.ignicao} weight="medium" />
          <span style={{ fontFamily: fonts.sans, fontWeight: 600, fontSize: 18, letterSpacing: -0.5 }}>flyby</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 2 }}>
          <Label>{t.missionTime}</Label>
          <span style={{ fontFamily: fonts.mono, fontSize: 14, lineHeight: "17px" }}>T+ {mission}</span>
        </div>
      </div>

      {/* Telemetry */}
      <div style={{ position: "absolute", left: 20, top: 80, height: 14 }}>
        <Label>{t.telemetry}</Label>
      </div>
      <div style={{ position: "absolute", left: 20, top: 108, width: 340, display: "flex", gap: 8 }}>
        <Ring fraction={cpu} value={`${Math.round(cpu * 100)}%`} label="CPU" detail={`10 ${t.cores}`} />
        <Ring fraction={ram} value={`${Math.round(ram * 100)}%`} label={t.memory} detail={`${ramUsed} / 16 GB`} />
        <Ring fraction={thermal} value={t.thermalOk} label={t.thermal} detail={t.system} />
      </div>
      <div style={{ position: "absolute", left: 20, top: 257, width: 340, height: 1, background: brand.orbita }} />

      {/* Mixer */}
      <div style={{ position: "absolute", left: 20, top: 278, width: 340, height: 18, display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <Label>Mixer</Label>
        <span style={{ fontFamily: fonts.sans, fontSize: 12, color: brand.poeira }}>MacBook Pro Speakers</span>
      </div>
      <MixerRow top={306} initials="Σ" name={t.mainOutput} volume={volumes.main} muted={false} mutedLabel={t.muted} />
      <MixerRow top={356} initials="Sp" name="Spotify" volume={volumes.spotify} muted={false} mutedLabel={t.muted} />
      <MixerRow top={406} initials="Sa" name="Safari" volume={volumes.safari} muted={safariMuted} mutedLabel={t.muted} />
      <MixerRow top={456} initials="Sl" name="Slack" volume={volumes.slack} muted={false} mutedLabel={t.muted} />
      <div style={{ position: "absolute", left: 20, top: 520, width: 340, height: 1, background: brand.orbita }} />

      {/* Footer */}
      <div style={{ position: "absolute", left: 20, top: 541, width: 340, height: 44, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <span style={{ fontFamily: fonts.mono, fontSize: 11, color: brand.poeira }}>{t.steady}</span>
        <div style={{ display: "flex", fontFamily: fonts.sans, fontWeight: 500, fontSize: 13 }}>
          <span style={{ padding: "0 14px" }}>{t.preferences}</span>
          <span style={{ padding: "0 14px" }}>{t.quit}</span>
        </div>
      </div>
    </div>
  );
};
