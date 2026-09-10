import * as THREE from 'three';
import { createBrain } from './ai';
export function makeBot(id: number) {
  const root = new THREE.Group(),
    visual = new THREE.Group(),
    hitboxes: THREE.Mesh[] = [],
    parts: THREE.Group[] = [];
  root.add(visual);
  const cloth = new THREE.MeshStandardMaterial({
      color: 0x465058,
      roughness: 0.97,
    }),
    vest = new THREE.MeshStandardMaterial({ color: 0x494c39, roughness: 1 }),
    black = new THREE.MeshStandardMaterial({
      color: 0x222b29,
      roughness: 0.85,
    }),
    skin = new THREE.MeshStandardMaterial({ color: 0xb19272, roughness: 0.9 }),
    glass = new THREE.MeshStandardMaterial({
      color: 0x415455,
      roughness: 0.2,
      metalness: 0.5,
    }),
    strap = new THREE.MeshStandardMaterial({ color: 0x72765b, roughness: 1 });
  function mesh(
    g: THREE.BufferGeometry,
    m: THREE.Material,
    x: number,
    y: number,
    z: number,
    parent: THREE.Object3D = visual,
    part = 'body',
  ) {
    const o = new THREE.Mesh(g, m);
    o.position.set(x, y, z);
    o.castShadow = true;
    o.receiveShadow = true;
    o.userData = { bot: id, part };
    parent.add(o);
    hitboxes.push(o);
    return o;
  }
  const box = (
    w: number,
    h: number,
    d: number,
    x: number,
    y: number,
    z: number,
    m: THREE.Material,
    p: THREE.Object3D = visual,
  ) => mesh(new THREE.BoxGeometry(w, h, d), m, x, y, z, p);
  mesh(new THREE.CapsuleGeometry(0.2, 0.38, 4, 10), cloth, 0, 1.14, 0);
  box(0.45, 0.48, 0.28, 0, 1.17, 0.035, vest);
  box(0.46, 0.07, 0.27, 0, 0.91, 0.015, black);
  box(0.39, 0.18, 0.15, 0, 1.13, 0.19, strap);
  for (const x of [-0.14, 0, 0.14]) box(0.105, 0.19, 0.07, x, 1.08, 0.27, vest);
  mesh(
    new THREE.SphereGeometry(0.145, 12, 8),
    black,
    0,
    1.67,
    0,
    visual,
    'head',
  );
  mesh(
    new THREE.SphereGeometry(0.167, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.66),
    vest,
    0,
    1.73,
    0,
    visual,
    'head',
  );
  mesh(
    new THREE.BoxGeometry(0.21, 0.055, 0.035),
    glass,
    0,
    1.71,
    0.129,
    visual,
    'head',
  );
  for (const side of [-1, 1]) {
    const leg = new THREE.Group();
    leg.position.set(side * 0.12, 0.91, 0);
    visual.add(leg);
    parts.push(leg);
    mesh(new THREE.CapsuleGeometry(0.105, 0.61, 3, 8), cloth, 0, -0.37, 0, leg);
    box(0.16, 0.18, 0.11, 0, -0.43, 0.095, vest, leg);
    box(0.19, 0.16, 0.3, 0, -0.81, 0.045, black, leg);
    const arm = new THREE.Group();
    arm.position.set(side * 0.26, 1.38, 0);
    visual.add(arm);
    arm.rotation.x = -0.78;
    arm.rotation.z = side * 0.12;
    mesh(new THREE.CapsuleGeometry(0.088, 0.27, 3, 8), cloth, 0, -0.15, 0, arm);
    const lower = box(0.145, 0.28, 0.14, 0, -0.31, 0.13, cloth, arm);
    lower.rotation.x = -0.6;
    box(0.14, 0.12, 0.13, 0, -0.39, 0.245, black, arm);
  }
  const weapon = new THREE.Group();
  root.add(weapon);
  box(0.11, 0.12, 0.63, -0.1, 1.21, 0.36, black, weapon);
  box(0.08, 0.22, 0.16, -0.1, 1.06, 0.36, black, weapon);
  const barrel = mesh(
    new THREE.CylinderGeometry(0.025, 0.025, 0.4, 8),
    black,
    -0.1,
    1.23,
    0.86,
    weapon,
  );
  barrel.rotation.x = Math.PI / 2;
  const light = new THREE.PointLight(0xffad4d, 0, 3);
  light.position.set(-0.1, 1.23, 1.1);
  root.add(light);
  const flashMaterial = new THREE.MeshBasicMaterial({
    color: 0xffd28a,
    transparent: true,
    opacity: 0.85,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  const muzzle = new THREE.Mesh(
    new THREE.ConeGeometry(0.065, 0.19, 5),
    flashMaterial,
  );
  muzzle.rotation.x = Math.PI / 2;
  muzzle.position.set(-0.1, 1.27, 1.16);
  muzzle.visible = false;
  root.add(muzzle);
  // Independent simple hit volumes are retained when the animated mesh loads.
  const proxyMaterial = new THREE.MeshBasicMaterial({ visible: false });
  const proxyBody = new THREE.Mesh(
    new THREE.BoxGeometry(0.53, 1.3, 0.4),
    proxyMaterial,
  );
  proxyBody.position.y = 0.8;
  proxyBody.userData = { bot: id, part: 'body' };
  const proxyHead = new THREE.Mesh(
    new THREE.SphereGeometry(0.19, 10, 8),
    proxyMaterial,
  );
  proxyHead.position.y = 1.66;
  proxyHead.userData = { bot: id, part: 'head' };
  root.add(proxyBody, proxyHead);
  return {
    root,
    visual,
    weapon,
    pose: null as null | (() => void),
    headBone: null as THREE.Object3D | null,
    hitboxes,
    parts,
    light,
    muzzle,
    proxies: [proxyBody, proxyHead],
    mixer: null as THREE.AnimationMixer | null,
    actions: {} as Record<string, THREE.AnimationAction>,
    animation: '',
    hp: 100,
    brain: createBrain(id),
    dead: 0,
    shot: 0,
    reaction: 1.3,
    path: [] as THREE.Vector3[],
    pathTime: 0,
    moving: 0,
    phase: id * 2.3,
    name: ['Viper', 'Nomad', 'Raven', 'Ghost'][id],
    materials: [
      cloth,
      vest,
      black,
      skin,
      glass,
      strap,
      proxyMaterial,
      flashMaterial,
    ],
  };
}
