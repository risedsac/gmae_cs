import * as THREE from 'three';
export type Solid = {
  x: number;
  z: number;
  w: number;
  d: number;
  h: number;
  y: number;
};
export type World = {
  solids: Solid[];
  targets: THREE.Mesh[];
  materials: THREE.Material[];
  textures: THREE.Texture[];
  dispose: () => void;
};
export const MAP_SOLIDS: Solid[] = [
  { x: -18, z: 21, w: 12, d: 20, h: 7, y: 0 },
  { x: 19, z: 20, w: 10, d: 22, h: 8, y: 0 },
  { x: -18, z: -2, w: 12, d: 25, h: 8.5, y: 0 },
  { x: 20, z: -7, w: 8, d: 29, h: 7, y: 0 },
  { x: -7.5, z: -1, w: 7, d: 12, h: 5.8, y: 0 },
  { x: 10.5, z: -11, w: 7, d: 9, h: 6.2, y: 0 },
  { x: -14, z: -23, w: 14, d: 8, h: 8, y: 0 },
  { x: 15, z: -26, w: 12, d: 8, h: 6.8, y: 0 },
  { x: 0, z: 32, w: 50, d: 2, h: 8, y: 0 },
  { x: 0, z: -33, w: 50, d: 2, h: 8, y: 0 },
  { x: -25, z: 0, w: 2, d: 68, h: 12, y: 0 },
  { x: 25, z: 0, w: 2, d: 68, h: 12, y: 0 },
  { x: 5, z: 13, w: 2.5, d: 2.5, h: 2, y: 0 },
  { x: 7.4, z: 13, w: 2, d: 2.4, h: 1.6, y: 0 },
  { x: -7, z: 10, w: 2.3, d: 2.3, h: 1.8, y: 0 },
  { x: -6.8, z: 10, w: 1.5, d: 1.6, h: 1.3, y: 1.8 },
  { x: 2, z: -6, w: 2.4, d: 2.4, h: 1.6, y: 0 },
  { x: -1, z: -25, w: 2.5, d: 2, h: 1.8, y: 0 },
  { x: -3.5, z: -18, w: 7, d: 2, h: 6.6, y: 0 },
  { x: 9, z: -18, w: 8, d: 2, h: 6.6, y: 0 },
];
export function canOccupy(
  x: number,
  z: number,
  y: number,
  height: number,
  solids: Solid[],
  radius = 0.32,
) {
  return !solids.some(
    (s) =>
      y < s.y + s.h - 0.035 &&
      y + height > s.y + 0.04 &&
      x + radius > s.x - s.w / 2 &&
      x - radius < s.x + s.w / 2 &&
      z + radius > s.z - s.d / 2 &&
      z - radius < s.z + s.d / 2,
  );
}
export function supportHeight(
  x: number,
  z: number,
  feet: number,
  solids: Solid[],
) {
  let top = 0;
  for (const s of solids)
    if (
      Math.abs(x - s.x) < s.w / 2 + 0.22 &&
      Math.abs(z - s.z) < s.d / 2 + 0.22 &&
      s.y + s.h <= feet + 0.12
    )
      top = Math.max(top, s.y + s.h);
  return top;
}
let seed = 7845;
const rand = () => {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 4294967296;
};
export function buildWorld(scene: THREE.Scene): World {
  const solids = MAP_SOLIDS.map((s) => ({ ...s })),
    targets: THREE.Mesh[] = [],
    materials: THREE.Material[] = [],
    textures: THREE.Texture[] = [];
  const material = (color: number, roughness = 0.9, metalness = 0) => {
    const m = new THREE.MeshStandardMaterial({ color, roughness, metalness });
    materials.push(m);
    return m;
  };
  const plaster = material(0xd1ad75),
    pale = material(0xe4d3ad),
    sand = material(0xdac49a),
    stone = material(0xc5b189),
    wood = material(0x8b6743),
    blue = material(0x4b6870),
    metal = material(0x5c5e50, 0.75, 0.3),
    dark = material(0x272f29),
    trim = material(0xb89e72),
    white = material(0xded5bb),
    terracotta = material(0x9c6946),
    olive = material(0x4f5940);
  let disposed = false;
  new THREE.TextureLoader().load(
    '/assets/desert-material-atlas.png',
    (texture) => {
      if (disposed) {
        texture.dispose();
        return;
      }
      const im = texture.image as HTMLImageElement;
      const n = Math.floor(im.width / 2);
      const crop = (index: number, repeat: number) => {
        const c = document.createElement('canvas');
        c.width = c.height = n;
        const ctx = c.getContext('2d')!;
        ctx.drawImage(
          im,
          (index % 2) * n,
          Math.floor(index / 2) * n,
          n,
          n,
          0,
          0,
          n,
          n,
        );
        const t = new THREE.CanvasTexture(c);
        t.colorSpace = THREE.SRGBColorSpace;
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
        t.repeat.set(repeat, repeat);
        t.anisotropy = 8;
        textures.push(t);
        return t;
      };
      for (const [m, i, r] of [
        [plaster, 0, 1],
        [pale, 0, 1],
        [sand, 1, 1],
        [stone, 3, 1],
        [wood, 2, 1],
      ] as [THREE.MeshStandardMaterial, number, number][]) {
        m.map = crop(i, r);
        m.bumpMap = m.map;
        m.bumpScale = i === 3 ? 0.1 : 0.035;
        m.color.set(i === 0 ? 0xdedbcd : i === 1 ? 0xd1cfbd : 0xe5e3d9);
        m.needsUpdate = true;
      }
      texture.dispose();
    },
  );
  function box(
    x: number,
    y: number,
    z: number,
    w: number,
    h: number,
    d: number,
    m: THREE.Material,
    hit = false,
    parent: THREE.Object3D = scene,
  ) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    mesh.position.set(x, y, z);
    if (m === plaster || m === pale || m === stone || m === sand) {
      const tile = m === stone ? 1.8 : m === sand ? 3.5 : 3;
      const positions = mesh.geometry.attributes.position;
      const normals = mesh.geometry.attributes.normal;
      const uv = mesh.geometry.attributes.uv;
      for (let i = 0; i < positions.count; i++) {
        const px = positions.getX(i) + x,
          py = positions.getY(i) + y,
          pz = positions.getZ(i) + z;
        if (Math.abs(normals.getY(i)) > 0.5) uv.setXY(i, px / tile, pz / tile);
        else if (Math.abs(normals.getX(i)) > 0.5)
          uv.setXY(i, pz / tile, py / tile);
        else uv.setXY(i, px / tile, py / tile);
      }
      uv.needsUpdate = true;
    }
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    parent.add(mesh);
    if (hit) targets.push(mesh);
    return mesh;
  }
  function cyl(
    x: number,
    y: number,
    z: number,
    r: number,
    h: number,
    m: THREE.Material,
    rt = r,
  ) {
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(rt, r, h, 12), m);
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    scene.add(mesh);
    return mesh;
  }
  const ground = box(0, -0.2, 0, 250, 0.4, 250, sand, true);
  ground.castShadow = false;
  // Main solids remain axis-aligned, making map collision and the radar agree.
  for (let i = 0; i < solids.length; i++) {
    const s = solids[i];
    if (i >= 12 && i <= 17) {
      crate(s);
      continue;
    }
    const m = i % 3 === 0 ? pale : plaster;
    box(s.x, s.y + s.h / 2, s.z, s.w, s.h, s.d, m, true);
    box(s.x, s.h + 0.08, s.z, s.w + 0.32, 0.22, s.d + 0.32, trim);
    if (i < 8) {
      box(s.x, 0.36, s.z, s.w + 0.06, 0.72, s.d + 0.06, stone);
      box(s.x, s.h + 0.38, s.z - s.d / 2, 0.18, 0.65, s.d, pale);
      facade(s);
    }
  }
  function crate(s: Solid) {
    box(s.x, s.y + s.h / 2, s.z, s.w, s.h, s.d, wood, true);
    const frame = 0.12;
    for (const x of [-1, 1])
      for (const z of [-1, 1])
        box(
          s.x + x * (s.w / 2 - 0.055),
          s.y + s.h / 2,
          s.z + z * (s.d / 2 - 0.055),
          frame,
          s.h + 0.03,
          frame,
          trim,
        );
    for (const y of [0.1, s.h - 0.1]) {
      box(s.x, s.y + y, s.z, s.w + 0.04, 0.12, s.d + 0.04, wood);
      for (const z of [-1, 1])
        box(s.x, s.y + y, s.z + (z * s.d) / 2, s.w, 0.09, 0.025, metal);
    }
    for (const z of [-1, 1]) {
      const brace = box(
        s.x,
        s.y + s.h / 2,
        s.z + z * (s.d / 2 + 0.012),
        0.1,
        Math.sqrt(s.w * s.w + s.h * s.h) * 0.85,
        0.05,
        trim,
      );
      brace.rotation.z = Math.atan2(s.w, s.h);
    }
  }
  function facade(s: Solid) {
    // Doors and shuttered windows on inward street facades.
    const side = s.x < 0 ? 1 : -1,
      fx = s.x + side * (s.w / 2 + 0.055);
    for (let z = s.z - s.d / 2 + 2.3; z < s.z + s.d / 2 - 1; z += 4.6) {
      box(fx, 4.25, z, 0.1, 1.8, 1.15, dark);
      box(fx + side * 0.08, 4.25, z, 0.1, 1.65, 1.04, blue);
      box(fx + side * 0.12, 3.3, z, 0.38, 0.18, 1.4, trim);
      box(fx + side * 0.1, 5.19, z, 0.23, 0.18, 1.35, pale);
      for (let y = 3.57; y < 5.05; y += 0.18)
        box(fx + side * 0.145, y, z, 0.02, 0.035, 1.04, dark);
      box(fx + side * 0.13, 4.23, z, 0.035, 1.7, 0.06, metal);
    }
    const dz = s.z + 1;
    box(fx + side * 0.03, 1.23, dz, 0.12, 2.45, 1.45, blue);
    for (const off of [-0.79, 0.79])
      box(fx + side * 0.04, 1.3, dz + off, 0.26, 2.65, 0.18, trim);
    box(fx + side * 0.05, 2.64, dz, 0.28, 0.22, 1.8, trim);
    box(fx + side * 0.115, 1.14, dz + 0.34, 0.05, 0.1, 0.11, metal);
    const awning = box(fx + side * 0.82, 2.91, dz, 1.9, 0.06, 2.05, olive);
    awning.rotation.z = side * 0.11;
    box(fx + side * 0.18, 5.95, s.z - 2, 0.48, 0.66, 1.1, white);
    for (let k = 0; k < 6; k++)
      box(
        fx + side * 0.435,
        5.73 + k * 0.085,
        s.z - 2,
        0.012,
        0.025,
        0.88,
        metal,
      );
    const pipe = cyl(fx + side * 0.22, 3, s.z + s.d / 2 - 0.6, 0.055, 6, metal);
    pipe.castShadow = false;
  }
  // The center passage is a true arched opening, with individual voussoirs.
  const archX = 2.5,
    archZ = -18,
    r = 2.5,
    spring = 2.75;
  for (let i = 0; i < 18; i++) {
    const a = (i / 18) * Math.PI,
      b = ((i + 1) / 18) * Math.PI;
    const shape = new THREE.Shape();
    shape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    shape.lineTo(Math.cos(b) * r, Math.sin(b) * r);
    shape.lineTo(Math.cos(b) * (r + 0.52), Math.sin(b) * (r + 0.52));
    shape.lineTo(Math.cos(a) * (r + 0.52), Math.sin(a) * (r + 0.52));
    shape.closePath();
    const mesh = new THREE.Mesh(
      new THREE.ExtrudeGeometry(shape, { depth: 2.16, bevelEnabled: false }),
      i % 3 ? stone : trim,
    );
    mesh.position.set(archX, spring, archZ - 1.08);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    scene.add(mesh);
    targets.push(mesh);
  }
  box(archX, 6.06, archZ, 5, 1.1, 2, plaster, true);
  for (const dx of [-r - 0.23, r + 0.23])
    for (let y = 0.25; y < spring; y += 0.52)
      box(archX + dx, y, archZ, 0.49, 0.49, 2.2, stone);
  // A barrel cluster, low cover, and a pale blue delivery shutter.
  for (const [x, z] of [
    [10, 5],
    [10.8, 5.6],
    [-2, -14],
  ] as number[][]) {
    targets.push(cyl(x, 0.63, z, 0.4, 1.26, blue));
    for (const y of [0.11, 0.5, 1.14]) cyl(x, y, z, 0.414, 0.065, metal);
    solids.push({ x, z, w: 0.8, d: 0.8, h: 1.26, y: 0 });
  }
  const shutter = box(13.93, 1.55, 18, 0.05, 3.1, 4.7, blue);
  shutter.castShadow = false;
  for (let y = 0.2; y < 3.1; y += 0.15)
    box(13.88, y, 18, 0.018, 0.03, 4.68, metal);
  // Rooftop silhouettes continue beyond the playable area.
  for (let i = 0; i < 18; i++) {
    const x = -40 + i * 4.6,
      z = -38 - rand() * 10,
      h = 5 + rand() * 8;
    box(x, h / 2, z, 3.9, h, 4, pale);
    box(x, h + 0.12, z, 4.15, 0.25, 4.2, trim);
    if (i % 3 === 0) {
      const dome = new THREE.Mesh(
        new THREE.SphereGeometry(1.9, 20, 12, 0, Math.PI * 2, 0, Math.PI / 2),
        pale,
      );
      dome.position.set(x, h, z);
      scene.add(dome);
    }
  }
  cyl(-16, 11, -29, 0.7, 6, pale);
  cyl(-16, 14.1, -29, 1.15, 0.35, trim);
  cyl(-16, 15.5, -29, 0.58, 2.5, pale);
  const roof = new THREE.Mesh(new THREE.ConeGeometry(0.75, 1.8, 16), trim);
  roof.position.set(-16, 17.5, -29);
  scene.add(roof);
  for (const [x, z] of [
    [-13, 24],
    [18, -25],
    [-21, -28],
  ]) {
    cyl(x, 8.9, z, 0.67, 2.6, white);
    cyl(x, 10.26, z, 0.74, 0.16, metal);
  }
  // Overhead utility lines cast fine shadows on the sunlit lane.
  const cableMat = new THREE.MeshStandardMaterial({
    color: 0x292b23,
    roughness: 1,
  });
  materials.push(cableMat);
  for (const z of [15, -4, -16])
    for (let i = 0; i < 2; i++) {
      const points = [
        new THREE.Vector3(-12, 7, z + i * 0.23),
        new THREE.Vector3(-3, 5.7, z + 0.9 + i * 0.23),
        new THREE.Vector3(6, 6, z + 0.6 + i * 0.23),
        new THREE.Vector3(16, 7.4, z + i * 0.23),
      ];
      const wire = new THREE.Mesh(
        new THREE.TubeGeometry(
          new THREE.CatmullRomCurve3(points),
          24,
          0.018,
          4,
          false,
        ),
        cableMat,
      );
      scene.add(wire);
    }
  // Canvas is used for in-world readable wayfinding, not a scene backdrop.
  function sign(
    text: string,
    x: number,
    y: number,
    z: number,
    rot: number,
    w: number,
    h: number,
    bg: string,
    fg: string,
  ) {
    const c = document.createElement('canvas');
    c.width = 512;
    c.height = 256;
    const ctx = c.getContext('2d')!;
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, 512, 256);
    ctx.strokeStyle = fg;
    ctx.lineWidth = 4;
    ctx.strokeRect(14, 14, 484, 228);
    ctx.fillStyle = fg;
    ctx.font = 'bold 95px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 256, 133);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    textures.push(t);
    const m = new THREE.MeshStandardMaterial({ map: t, roughness: 1 });
    materials.push(m);
    const plane = new THREE.Mesh(new THREE.PlaneGeometry(w, h), m);
    plane.position.set(x, y, z);
    plane.rotation.y = rot;
    scene.add(plane);
  }
  sign('A  →', -3.94, 2.5, 2, Math.PI / 2, 2.4, 1.1, '#b79561', '#8c392a');
  sign('SECTOR 04', 8.8, 3.9, -16.97, 0, 3, 1.2, '#374e4b', '#ddd1ae');
  sign('B  ←', 15.94, 2.3, 3, -Math.PI / 2, 2, 1, '#d1b07b', '#446b76');
  sign(
    'المدينة',
    -11.93,
    2.9,
    19,
    Math.PI / 2,
    1.8,
    0.72,
    '#386367',
    '#f0dfb6',
  );
  // Planters, palm fronds, and scattered stones break the hard geometry.
  function palm(x: number, z: number, height: number) {
    const trunk = cyl(x, height / 2, z, 0.2, height, terracotta, 0.13);
    trunk.rotation.z = 0.04;
    for (let i = 0; i < 11; i++) {
      const a = (i / 11) * Math.PI * 2;
      const vertices: number[] = [];
      for (let j = 0; j < 7; j++) {
        const t = j / 6,
          len = t * 3;
        const y = height + Math.sin(t * Math.PI) * 0.65 - t * t * 0.8;
        const width = Math.sin(t * Math.PI) * 0.33;
        for (const side of [-1, 1])
          vertices.push(
            x + Math.cos(a) * len - Math.sin(a) * width * side,
            y,
            z + Math.sin(a) * len + Math.cos(a) * width * side,
          );
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
      const idx = [];
      for (let j = 0; j < 6; j++)
        idx.push(j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2);
      g.setIndex(idx);
      g.computeVertexNormals();
      const leafMat = new THREE.MeshStandardMaterial({
        color: i % 2 ? 0x647044 : 0x56683c,
        side: THREE.DoubleSide,
        roughness: 1,
      });
      materials.push(leafMat);
      const leaf = new THREE.Mesh(g, leafMat);
      leaf.castShadow = true;
      scene.add(leaf);
    }
  }
  palm(12, 27, 8);
  palm(-13, -17, 10);
  palm(19, -29, 9);
  for (const [x, z] of [
    [-10.9, 24],
    [13.4, 8],
    [-10.8, -10],
  ]) {
    cyl(x, 0.36, z, 0.43, 0.72, terracotta, 0.5);
    for (let i = 0; i < 7; i++) {
      const leaf = new THREE.Mesh(new THREE.ConeGeometry(0.18, 0.8, 4), olive);
      leaf.position.set(
        x + (rand() - 0.5) * 0.45,
        0.9,
        z + (rand() - 0.5) * 0.45,
      );
      leaf.rotation.z = (rand() - 0.5) * 0.8;
      scene.add(leaf);
    }
  }
  const pebbleGeom = new THREE.DodecahedronGeometry(1, 0);
  for (let i = 0; i < 100; i++) {
    const x = (rand() - 0.5) * 44,
      z = (rand() - 0.5) * 59;
    if (!canOccupy(x, z, 0, 0.2, solids, 0.08)) continue;
    const mesh = new THREE.Mesh(pebbleGeom, stone);
    mesh.position.set(x, 0.03, z);
    mesh.scale.set(
      0.04 + rand() * 0.13,
      0.02 + rand() * 0.05,
      0.05 + rand() * 0.14,
    );
    mesh.rotation.y = rand() * 6;
    scene.add(mesh);
  }
  return {
    solids,
    targets,
    materials,
    textures,
    dispose() {
      disposed = true;
      for (const t of textures) t.dispose();
      for (const m of materials) m.dispose();
    },
  };
}
