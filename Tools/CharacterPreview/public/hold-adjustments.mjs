export const adjustmentKey = (weaponId, moduleId, hand) => `${weaponId}:${moduleId}:${hand}`;
const zero = Object.freeze([0, 0, 0]);
// Missing optional rows explicitly inherit the module's authored orientation.
export const rotationOffsetFor = (adjustments, weapon, moduleId) => adjustments.get(adjustmentKey(weapon.itemId, moduleId, weapon.slot))?.rotationOffset ?? zero;
