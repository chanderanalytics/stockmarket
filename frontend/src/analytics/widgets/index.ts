/**
 * Analytics widgets barrel export.
 *
 * Widgets represent business concepts and must not import
 * visualization libraries directly. They compose visualization
 * primitives and delegate rendering to adapters.
 */

export * from "./common/KPIWidget";
export * from "./market/VolumeProfileV2Widget";
export * from "./market/PriceTrendV2Widget";
export * from "./market/MarketBreadthWidget";
export * from "./market/IndicesWidget";
export * from "./performance";
