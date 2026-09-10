import * as THREE from 'three';
import { clone } from 'three/addons/utils/SkeletonUtils.js';

/** Evaluate the bind pose before measuring a skinned clone. Keep normalization
 * outside the animated hierarchy so animation tracks cannot overwrite it. */
export function createActor(
  source: THREE.Object3D,
  clips: THREE.AnimationClip[],
) {
  const actor = clone(source);
  const wrapper = new THREE.Group();
  wrapper.add(actor);
  const mixer = new THREE.AnimationMixer(actor);
  const actions: Record<string, THREE.AnimationAction> = {};
  for (const clip of clips)
    actions[clip.name.toLowerCase()] = mixer.clipAction(clip);
  const initial = actions.idle || Object.values(actions)[0];
  initial?.play();
  mixer.update(0);
  actor.updateMatrixWorld(true);
  actor.traverse((object) => {
    if (object instanceof THREE.SkinnedMesh) object.skeleton.update();
  });
  const bounds = new THREE.Box3().setFromObject(actor, true);
  const height = bounds.max.y - bounds.min.y;
  if (!Number.isFinite(height) || height < 0.01)
    throw new Error('Invalid character bounds');
  const center = bounds.getCenter(new THREE.Vector3());
  actor.position.add(new THREE.Vector3(-center.x, -bounds.min.y, -center.z));
  wrapper.scale.setScalar(1.82 / height);
  wrapper.rotation.y = Math.PI;
  wrapper.updateMatrixWorld(true);
  actor.traverse((object) => {
    if (object instanceof THREE.Mesh) {
      object.castShadow = true;
      object.receiveShadow = true;
      object.frustumCulled = false;
    }
  });
  const bone = (name: string) =>
    actor.getObjectByName('mixamorig' + name) ||
    actor.getObjectByName('mixamorig:' + name);
  const rightArm = bone('RightArm'),
    rightForearm = bone('RightForeArm'),
    rightHand = bone('RightHand');
  const leftArm = bone('LeftArm'),
    leftForearm = bone('LeftForeArm'),
    leftHand = bone('LeftHand');
  const headBone = bone('Head');
  function aimJoint(
    joint: THREE.Object3D | undefined,
    child: THREE.Object3D | undefined,
    target: THREE.Vector3,
  ) {
    if (!joint?.parent || !child || !wrapper.parent) return;
    const worldTarget = wrapper.parent.localToWorld(target);
    const direction = worldTarget
      .sub(joint.getWorldPosition(new THREE.Vector3()))
      .normalize();
    const worldRotation = new THREE.Quaternion().setFromUnitVectors(
      child.position.clone().normalize(),
      direction,
    );
    joint.quaternion.copy(
      joint.parent
        .getWorldQuaternion(new THREE.Quaternion())
        .invert()
        .multiply(worldRotation),
    );
    joint.updateWorldMatrix(false, true);
  }
  function pose() {
    wrapper.updateWorldMatrix(true, true);
    aimJoint(rightArm, rightForearm, new THREE.Vector3(-0.3, 1.18, 0.09));
    aimJoint(rightForearm, rightHand, new THREE.Vector3(-0.1, 1.19, 0.32));
    aimJoint(leftArm, leftForearm, new THREE.Vector3(0.29, 1.17, 0.18));
    aimJoint(leftForearm, leftHand, new THREE.Vector3(-0.1, 1.2, 0.47));
  }
  return { wrapper, actor, mixer, actions, height, pose, headBone };
}
