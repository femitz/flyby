import { Composition } from "remotion";
import { FlybyPromo, type PromoProps } from "./FlybyPromo";

export const FPS = 30;
export const DURATION = 23 * FPS;

export const Root: React.FC = () => (
  <Composition
    id="FlybyPromo"
    component={FlybyPromo}
    durationInFrames={DURATION}
    fps={FPS}
    width={1080}
    height={1350}
    defaultProps={{ lang: "en" } satisfies PromoProps}
  />
);
