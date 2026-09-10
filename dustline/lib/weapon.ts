import * as THREE from 'three';
export function makeWeapon(pistol = false) {
  const root = new THREE.Group(),
    magazine = new THREE.Group(),
    leftHand = new THREE.Group();
  root.add(magazine, leftHand);
  const steel = new THREE.MeshStandardMaterial({
      color: 0x303734,
      roughness: 0.42,
      metalness: 0.78,
    }),
    edge = new THREE.MeshStandardMaterial({
      color: 0x59615a,
      roughness: 0.4,
      metalness: 0.8,
    }),
    wood = new THREE.MeshStandardMaterial({ color: 0x75442b, roughness: 0.62 }),
    grip = new THREE.MeshStandardMaterial({ color: 0x202923, roughness: 0.9 }),
    sleeve = new THREE.MeshStandardMaterial({ color: 0x777d62, roughness: 1 }),
    glove = new THREE.MeshStandardMaterial({
      color: 0x454b37,
      roughness: 0.95,
    }),
    skin = new THREE.MeshStandardMaterial({ color: 0xb58a62, roughness: 0.95 });
  const box = (
    w: number,
    h: number,
    d: number,
    x: number,
    y: number,
    z: number,
    m: THREE.Material,
    parent: THREE.Object3D = root,
  ) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  };
  const tube = (
    r: number,
    l: number,
    x: number,
    y: number,
    z: number,
    m: THREE.Material,
    parent: THREE.Object3D = root,
  ) => {
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(r, r, l, 12), m);
    mesh.rotation.x = Math.PI / 2;
    mesh.position.set(x, y, z);
    parent.add(mesh);
    return mesh;
  };
  function limb(
    a: THREE.Vector3,
    b: THREE.Vector3,
    r1: number,
    r2: number,
    m: THREE.Material,
    parent: THREE.Object3D = root,
  ) {
    const v = b.clone().sub(a);
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(r2, r1, v.length(), 10),
      m,
    );
    mesh.position.copy(a).add(b).multiplyScalar(0.5);
    mesh.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      v.normalize(),
    );
    parent.add(mesh);
    return mesh;
  }
  if (!pistol) {
    box(0.12, 0.145, 0.6, 0, 0, -0.46, steel);
    tube(0.057, 0.56, 0, 0.075, -0.47, steel);
    box(0.128, 0.018, 0.37, 0, 0.114, -0.4, edge);
    box(0.105, 0.17, 0.29, 0, -0.015, 0.006, wood).rotation.x = -0.12;
    box(0.108, 0.18, 0.025, 0, -0.028, 0.158, grip);
    box(0.13, 0.1, 0.32, 0, -0.014, -0.89, wood);
    tube(0.038, 0.29, 0, 0.072, -0.86, wood);
    tube(0.022, 0.52, 0, 0.049, -1.17, steel);
    tube(0.034, 0.084, 0, 0.049, -1.45, edge);
    tube(0.018, 0.46, 0, -0.006, -1.12, edge);
    box(0.054, 0.12, 0.052, 0, 0.092, -1.25, steel);
    const sight = new THREE.Mesh(
      new THREE.TorusGeometry(0.029, 0.008, 6, 14),
      steel,
    );
    sight.position.set(0, 0.16, -1.25);
    root.add(sight);
    box(0.009, 0.045, 0.012, 0, 0.139, -1.248, edge);
    box(0.11, 0.042, 0.037, 0, 0.13, -0.42, steel);
    box(0.026, 0.018, 0.038, -0.041, 0.153, -0.42, edge);
    box(0.026, 0.018, 0.038, 0.041, 0.153, -0.42, edge);
    const pistolGrip = box(0.089, 0.22, 0.1, 0, -0.165, -0.275, wood);
    pistolGrip.rotation.x = -0.27;
    const guard = new THREE.Mesh(
      new THREE.TorusGeometry(0.057, 0.01, 5, 12, Math.PI * 1.7),
      steel,
    );
    guard.position.set(0, -0.123, -0.4);
    guard.rotation.y = Math.PI / 2;
    root.add(guard);
    box(0.013, 0.065, 0.023, 0, -0.12, -0.407, edge).rotation.x = -0.32;
    magazine.position.set(0, -0.083, -0.63);
    const shape = new THREE.Shape();
    shape.moveTo(-0.055, 0);
    shape.lineTo(0.072, 0);
    shape.quadraticCurveTo(0.075, -0.26, 0.2, -0.4);
    shape.lineTo(0.074, -0.445);
    shape.quadraticCurveTo(-0.045, -0.27, -0.055, 0);
    const geom = new THREE.ExtrudeGeometry(shape, {
      depth: 0.075,
      bevelEnabled: true,
      bevelThickness: 0.007,
      bevelSize: 0.006,
      bevelSegments: 1,
      steps: 1,
    });
    const mag = new THREE.Mesh(geom, steel);
    mag.rotation.y = Math.PI / 2;
    mag.position.x = -0.0375;
    magazine.add(mag);
    for (let i = 0; i < 5; i++) {
      const rib = box(
        0.081,
        0.018,
        0.095,
        0,
        -0.085 - i * 0.057,
        -0.007 - i * i * 0.004,
        edge,
        magazine,
      );
      rib.rotation.x = -i * 0.065;
    }
    for (let i = 0; i < 6; i++)
      box(0.134, 0.011, 0.018, 0, -0.04, -0.77 - i * 0.038, grip);
    for (let i = 0; i < 5; i++) {
      const rivet = new THREE.Mesh(new THREE.SphereGeometry(0.011, 6, 4), edge);
      rivet.position.set(0.066, -0.015, -0.24 - i * 0.095);
      root.add(rivet);
    }
    box(0.034, 0.04, 0.13, 0.074, 0.023, -0.35, steel);
    tube(0.014, 0.052, 0.108, 0.039, -0.41, edge);
    box(0.007, 0.014, 0.21, 0.065, -0.025, -0.29, edge).rotation.x = 0.16;
  } else {
    box(0.13, 0.12, 0.39, 0, 0.02, -0.46, steel);
    box(0.135, 0.07, 0.26, 0, -0.062, -0.405, grip);
    box(0.103, 0.25, 0.115, 0, -0.19, -0.323, grip).rotation.x = -0.23;
    box(0.104, 0.045, 0.12, 0, -0.324, -0.293, steel, magazine);
    tube(0.027, 0.075, 0, 0.025, -0.685, edge);
    tube(0.017, 0.006, 0, 0.025, -0.726, grip);
    box(0.06, 0.035, 0.028, 0, 0.091, -0.59, steel);
    box(0.12, 0.025, 0.025, 0, 0.094, -0.3, edge);
    for (let i = 0; i < 7; i++)
      box(0.134, 0.075, 0.01, 0, 0.025, -0.3 - i * 0.015, edge);
    const guard = new THREE.Mesh(
      new THREE.TorusGeometry(0.06, 0.012, 6, 12),
      steel,
    );
    guard.rotation.y = Math.PI / 2;
    guard.position.set(0, -0.13, -0.451);
    root.add(guard);
  }
  // Sleeves, fitted gloves, palms and four individual knuckles.
  limb(
    new THREE.Vector3(0.27, -0.56, 0.25),
    new THREE.Vector3(0.06, -0.23, -0.24),
    0.115,
    0.078,
    sleeve,
  );
  limb(
    new THREE.Vector3(0.06, -0.23, -0.24),
    new THREE.Vector3(0.01, -0.14, -0.29),
    0.079,
    0.074,
    glove,
  );
  box(0.128, 0.12, 0.105, 0.009, -0.155, -0.278, glove);
  for (let i = 0; i < 4; i++)
    box(0.018, 0.031, 0.09, 0.061, -0.11 - i * 0.026, -0.289, grip).rotation.z =
      -0.14;
  if (!pistol) {
    limb(
      new THREE.Vector3(-0.33, -0.63, 0.1),
      new THREE.Vector3(-0.08, -0.2, -0.78),
      0.11,
      0.078,
      sleeve,
      leftHand,
    );
    limb(
      new THREE.Vector3(-0.08, -0.2, -0.78),
      new THREE.Vector3(0, -0.07, -0.85),
      0.075,
      0.075,
      glove,
      leftHand,
    );
    box(0.16, 0.068, 0.15, 0, -0.072, -0.86, glove, leftHand);
    for (let i = 0; i < 4; i++)
      box(0.028, 0.078, 0.038, -0.05 + i * 0.031, -0.02, -0.9, grip, leftHand);
  } else {
    limb(
      new THREE.Vector3(-0.25, -0.6, 0.1),
      new THREE.Vector3(-0.075, -0.2, -0.35),
      0.1,
      0.075,
      sleeve,
      leftHand,
    );
    box(0.12, 0.14, 0.1, -0.065, -0.17, -0.35, glove, leftHand);
  }
  const flash = new THREE.Group();
  const fm = new THREE.MeshBasicMaterial({
    color: 0xffdc8a,
    transparent: true,
    opacity: 0.93,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  const cone = new THREE.Mesh(
    new THREE.ConeGeometry(pistol ? 0.044 : 0.065, 0.38, 7),
    fm,
  );
  cone.rotation.x = -Math.PI / 2;
  cone.position.z = -0.15;
  flash.add(cone);
  for (let i = 0; i < 4; i++) {
    const flare = new THREE.Mesh(new THREE.ConeGeometry(0.028, 0.23, 4), fm);
    flare.rotation.x = -Math.PI / 2;
    flare.rotation.z = (i * Math.PI) / 2;
    flare.position.set(
      Math.cos((i * Math.PI) / 2) * 0.05,
      Math.sin((i * Math.PI) / 2) * 0.05,
      -0.045,
    );
    flash.add(flare);
  }
  flash.position.set(0, 0.05, pistol ? -0.74 : -1.5);
  flash.visible = false;
  root.add(flash);
  const light = new THREE.PointLight(0xffb449, 0, 3, 2);
  light.position.copy(flash.position);
  root.add(light);
  root.position.set(pistol ? 0.23 : 0.27, -0.27, -0.25);
  root.rotation.y = 0.028;
  return {
    root,
    magazine,
    leftHand,
    flash,
    light,
    materials: [steel, edge, wood, grip, sleeve, glove, skin, fm],
    bolt: new THREE.Group(),
    magazineBaseY: pistol ? 0 : -0.083,
    modeled: false,
  };
}

export function installWeaponModel(
  weapon: ReturnType<typeof makeWeapon>,
  source: THREE.Group,
) {
  const node = (name: string) => {
    let found: THREE.Object3D | undefined;
    source.traverse((o) => {
      if (o.name.replace(/[._0-9]/g, '') === name) found = o;
    });
    return found;
  };
  const magazine = node('Magazine');
  const support = node('SupportArm');
  const bolt = node('Bolt');
  if (!magazine || !support || !bolt)
    throw new Error('Weapon model is missing animation pivots');
  for (const child of weapon.root.children.slice()) {
    if (child === weapon.flash || child === weapon.light) continue;
    child.traverse((o) => {
      if (o instanceof THREE.Mesh) o.geometry.dispose();
    });
    weapon.root.remove(child);
  }
  // The authored GLB has its own material palette; only the flash keeps its original material.
  weapon.materials.slice(0, -1).forEach((m) => m.dispose());
  weapon.materials.splice(0, weapon.materials.length - 1);
  weapon.root.add(source);
  weapon.magazine = magazine as THREE.Group;
  weapon.leftHand = support as THREE.Group;
  weapon.bolt = bolt as THREE.Group;
  weapon.magazineBaseY = 0;
  weapon.modeled = true;
  source.traverse((o) => {
    if (o instanceof THREE.Mesh) {
      o.frustumCulled = false;
      const materials = Array.isArray(o.material) ? o.material : [o.material];
      for (const m of materials) {
        if (m instanceof THREE.MeshStandardMaterial) m.envMapIntensity = 0.6;
      }
    }
  });
}
