import * as THREE from './vendor/three.module.min.js';
import { rotationOffsetFor } from './hold-adjustments.mjs';

const rad = Math.PI / 180;
export const unityPosition = a => new THREE.Vector3(a[0], a[1], -a[2]);
export function unityRotation(a) {
  // Unity Quaternion.Euler applies Z, X, Y; reflect Z into the browser coordinate system.
  const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(a[0] * rad, a[1] * rad, a[2] * rad, 'YXZ'));
  return q.set(-q.x, -q.y, q.z, q.w);
}
export function toUnityRotation(q) {
  const e = new THREE.Euler().setFromQuaternion(new THREE.Quaternion(-q.x, -q.y, q.z, q.w), 'YXZ');
  return [e.x / rad, e.y / rad, e.z / rad];
}
const v = a => new THREE.Vector3().fromArray(a);
const q = a => new THREE.Quaternion().fromArray(a);
const scaledGrip = (row, key, scale) => unityPosition(row[key]).multiply(v(scale));
const mountPoint = (hand, arm) => v(arm.mountPosition).applyQuaternion(hand.quaternion).add(hand.position);
export function weaponRoot(hand, arm, row, scale) {
  const rotation = hand.quaternion.clone().multiply(q(arm.mountRotation)).multiply(unityRotation(row.mainRotation).invert());
  const position = mountPoint(hand, arm).sub(scaledGrip(row, 'mainPosition', scale).applyQuaternion(rotation));
  return new THREE.Matrix4().compose(position, rotation, v(scale));
}
function rootRotation(matrix) { return new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().extractRotation(matrix)); }

// Same two-bone geometry as PawnAnimationView.SolveArm, operating on exported world-space bones.
export function solveArm(bones, arm, goal, rotation) {
  const [upper, lower, hand] = arm.bones.map(i => bones[i]);
  const shoulder = upper.position, oldLower = lower.position.clone(), oldHand = hand.position.clone();
  const a = shoulder.distanceTo(oldLower), b = oldLower.distanceTo(oldHand);
  const delta = goal.clone().sub(shoulder), distance = THREE.MathUtils.clamp(delta.length(), Math.abs(a - b) + .0001, a + b - .0001);
  const direction = delta.normalize();
  let bend = v(arm.pole).sub(shoulder).projectOnPlane(direction);
  if (bend.lengthSq() < .000001) bend = oldLower.clone().sub(shoulder).projectOnPlane(direction);
  if (bend.lengthSq() < .000001) bend.crossVectors(direction, new THREE.Vector3(0, 1, 0));
  const along = (a * a - b * b + distance * distance) / (2 * distance);
  const elbow = shoulder.clone().addScaledVector(direction, along).addScaledVector(bend.normalize(), Math.sqrt(Math.max(0, a * a - along * along)));
  const upperDelta = new THREE.Quaternion().setFromUnitVectors(oldLower.clone().sub(shoulder).normalize(), elbow.clone().sub(shoulder).normalize());
  upper.quaternion.premultiply(upperDelta);
  lower.position.copy(elbow);
  const inheritedHand = oldHand.clone().sub(shoulder).applyQuaternion(upperDelta).add(shoulder);
  lower.quaternion.premultiply(upperDelta);
  const lowerDelta = new THREE.Quaternion().setFromUnitVectors(inheritedHand.sub(elbow).normalize(), goal.clone().sub(elbow).normalize());
  lower.quaternion.premultiply(lowerDelta);
  // Preserve bone length even if a goal lies outside the reachable sphere.
  hand.position.copy(elbow).add(goal.clone().sub(elbow).normalize().multiplyScalar(b));
  hand.quaternion.copy(rotation);
}

export function applyGripPreview(meta, rows, bones, meshes, adjustments = new Map()) {
  const baseRoots = meta.weapons.map(w => weaponRoot(bones[meta.arms[w.slot === 'main' ? 0 : 1].bones[2]], meta.arms[w.slot === 'main' ? 0 : 1], w, w.scale));
  const baseFrames = baseRoots.map((root,i) => rootRotation(root).multiply(unityRotation(meta.weapons[i].rotationOffset).invert()));
  const frames = baseFrames.map((frame,i) => frame.clone().multiply(unityRotation(rotationOffsetFor(adjustments, meta.weapons[i], meta.moduleId))));
  const changed = meta.weapons.some(w => ['mainPosition','mainRotation','offPosition','offRotation'].some(k => w[k].some((n, i) => Math.abs(n - rows.get(w.gripId)[k][i]) > 1e-8)) || w.rotationOffset.some((n,i)=>Math.abs(n-rotationOffsetFor(adjustments,w,meta.moduleId)[i])>1e-8));
  if (changed && meta.shared) {
    const weapon = meta.weapons.find(w => w.slot === 'main'), row = rows.get(weapon.gripId);
    const index = meta.weapons.indexOf(weapon), frame = frames[index];
    const [right, left] = meta.arms.map(arm => bones[arm.bones[2]]);
    const rotations = [row.mainRotation, row.offRotation].map((angles, i) => frame.clone().multiply(unityRotation(angles)).multiply(q(meta.arms[i].mountRotation).invert()));
    const offsets = rotations.map((rotation, i) => v(meta.arms[i].mountPosition).applyQuaternion(rotation));
    const main = scaledGrip(row, 'mainPosition', weapon.scale), off = scaledGrip(row, 'offPosition', weapon.scale);
    // Retain the sampled action's extra separation (e.g. bow draw) in addition to authored local grips.
    const oldFrame = rootRotation(baseRoots[index]);
    const extra = mountPoint(left, meta.arms[1]).sub(mountPoint(right, meta.arms[0])).applyQuaternion(oldFrame.invert()).sub(scaledGrip(weapon, 'offPosition', weapon.scale).sub(scaledGrip(weapon, 'mainPosition', weapon.scale))).applyQuaternion(frame);
    const separation = off.sub(main).applyQuaternion(frame).add(extra);
    const grip = v(meta.mainHand).add(main.applyQuaternion(baseFrames[index]));
    const ceiling = bones[meta.head].position.y - meta.clearance;
    grip.y = Math.min(grip.y, ceiling);
    const reaches = meta.arms.map(arm => { const [a,b,c] = arm.bones.map(i => bones[i].position); return (a.distanceTo(b) + b.distanceTo(c)) * .985; });
    const shoulders = meta.arms.map(arm => bones[arm.bones[0]].position);
    for (let i = 0; i < 6; i++) {
      grip.sub(offsets[0]).sub(shoulders[0]).clampLength(0, reaches[0]).add(shoulders[0]).add(offsets[0]);
      grip.add(separation).sub(offsets[1]).sub(shoulders[1]).clampLength(0, reaches[1]).add(shoulders[1]).sub(separation).add(offsets[1]);
      grip.y = Math.min(grip.y, ceiling);
    }
    solveArm(bones, meta.arms[0], grip.clone().sub(offsets[0]), rotations[0]);
    solveArm(bones, meta.arms[1], mountPoint(right, meta.arms[0]).add(separation).sub(offsets[1]), rotations[1]);
  } else if (changed) {
    meta.weapons.forEach((weapon, i) => {
      const arm = meta.arms[weapon.slot === 'main' ? 0 : 1], hand = bones[arm.bones[2]], row = rows.get(weapon.gripId);
      hand.quaternion.copy(frames[i].clone().multiply(unityRotation(row.mainRotation)).multiply(q(arm.mountRotation).invert()));
    });
  }
  return meta.weapons.map((weapon, i) => {
    const arm = meta.arms[weapon.slot === 'main' ? 0 : 1];
    const root = weaponRoot(bones[arm.bones[2]], arm, rows.get(weapon.gripId), weapon.scale);
    if (changed) {
      const correction = root.clone().multiply(baseRoots[i].clone().invert());
      for (const index of weapon.meshes) { const mesh = meshes[index]; mesh.updateMatrix(); mesh.matrix.premultiply(correction).decompose(mesh.position, mesh.quaternion, mesh.scale); }
    }
    return root;
  });
}
