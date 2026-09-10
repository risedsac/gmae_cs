import * as THREE from 'three';

export const skills = [
  { reaction: 0.85, turn: 2.4, spread: 0.043, burst: 3, pause: 1.05 },
  { reaction: 0.52, turn: 3.2, spread: 0.027, burst: 3, pause: 0.72 },
  { reaction: 0.32, turn: 4.1, spread: 0.017, burst: 4, pause: 0.52 },
];
export type Cover = { hide: THREE.Vector3; peek: THREE.Vector3 };
export function createBrain(id: number) {
  return {
    id,
    state: 'patrol' as 'patrol' | 'search' | 'engage' | 'cover' | 'peek',
    lastKnown: null as THREE.Vector3 | null,
    memory: 0,
    visible: false,
    visibleTime: 0,
    senseClock: id * 0.027,
    goal: null as THREE.Vector3 | null,
    cover: null as Cover | null,
    decision: 0,
    hold: 0,
    patrol: id,
    search: 0,
    blocked: 0,
    callClock: 0,
    ammo: 30,
    reload: 0,
    burst: 0,
    steps: id * 0.13,
    radarUntil: 0,
    radarPosition: null as THREE.Vector3 | null,
  };
}
export function angleDifference(to: number, from: number) {
  return Math.atan2(Math.sin(to - from), Math.cos(to - from));
}
export function seesDirection(
  yaw: number,
  origin: THREE.Vector3,
  target: THREE.Vector3,
  fov = 110,
) {
  const delta = target.clone().sub(origin);
  if (delta.length() > 36) return false;
  return (
    Math.abs(angleDifference(Math.atan2(delta.x, delta.z), yaw)) <=
    THREE.MathUtils.degToRad(fov / 2)
  );
}

// Separate routes create encounters on both lanes without reading the player's position.
export const patrolRoutes = [
  [
    [1, -11],
    [2.5, -21],
    [5, -28],
    [2.5, -17],
    [0, 1],
    [0, 17],
  ],
  [
    [11, 2],
    [12, 8],
    [11, 23],
    [1, 20],
    [0, 8],
  ],
  [
    [-1, 5],
    [-2, 15],
    [-8, 17],
    [-1, 23],
    [1, 2],
  ],
  [
    [5, -26],
    [2.5, -20],
    [3, -12],
    [5, -3],
    [11, 2],
  ],
];

/** Sounds carry their position at the time of the event. They never reveal a
 * continuously updated target through a wall. */
export function rememberSound(
  brain: ReturnType<typeof createBrain>,
  point: THREE.Vector3,
) {
  if (brain.visible) return;
  brain.lastKnown = point.clone();
  brain.memory = 7;
  brain.state = 'search';
  brain.search = 0;
  brain.goal = null;
}
