import type { Calculator, IndicatorName } from "../types";
import { sma } from "./sma";
import { ema } from "./ema";
import { rsi } from "./rsi";
import { atr } from "./atr";
import { macd } from "./macd";
import { vwap } from "./vwap";
import { roc } from "./roc";
import { obv } from "./obv";
import { volume } from "./volume";
import { momentum } from "./momentum";
import { relativeStrength } from "./relative-strength";
import { movingAverageEnvelope } from "./moving-average-envelope";
import { bollingerBands } from "./bollinger-bands";
import { superTrend } from "./super-trend";
import { averageVolume } from "./average-volume";
import { week52HighLow } from "./52-week-high-low";
import { adx } from "./adx";

export const calculators: Record<IndicatorName, Calculator> = {
  sma,
  ema,
  rsi,
  adx,
  atr,
  macd,
  vwap,
  roc,
  obv,
  volume,
  momentum,
  relative_strength: relativeStrength,
  moving_average_envelope: movingAverageEnvelope,
  bollinger_bands: bollingerBands,
  super_trend: superTrend,
  average_volume: averageVolume,
  week52_high_low: week52HighLow,
};

export { calculators as default };
