//import 'package:flutter/services.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

class SkeletonUtils {
  void retarget(Object3D? target, source, [options]) {
    final pos = Vector3(),
        quat = Quaternion(),
        scale = Vector3(),
        bindBoneMatrix = Matrix4(),
        relativeMatrix = Matrix4(),
        globalMatrix = Matrix4();

    options = options ?? {};

    options.preserveMatrix = options.preserveMatrix != null ? options.preserveMatrix : true;
    options.preservePosition = options.preservePosition != null ? options.preservePosition : true;
    options.preserveHipPosition = options.preserveHipPosition != null ? options.preserveHipPosition : false;
    options.useTargetMatrix = options.useTargetMatrix != null ? options.useTargetMatrix : false;
    options.hip = options.hip != null ? options.hip : 'hip';
    options.names = options.names ?? {};

    final sourceBones = source.isObject3D ? source.skeleton.bones : getBones(source);
    final List<Bone>? bones = target?.skeleton?.bones;//target is Object3D ? target.skeleton?.bones : getBones(target.skeleton);

    List<Matrix4>? bindBones;
    Bone bone;
    String name;
    Bone? boneTo;
    List<Vector3> bonesPosition = [];

    // reset bones

    if (target is Object3D) {
      target.skeleton?.pose();
    } 
    else {
      options.useTargetMatrix = true;
      options.preserveMatrix = false;
    }

    if (options.preservePosition) {
      bonesPosition = [];

      for (int i = 0; i < (bones?.length ?? 0); i++) {
        bonesPosition.add(bones![i].position.clone());
      }
    }

    if (options.preserveMatrix) {
      // reset matrix

      target?.updateMatrixWorld();

      target?.matrixWorld.identity();

      // reset children matrix

      for (int i = 0; i < (target?.children.length ?? 0); ++i) {
        target?.children[i].updateMatrixWorld(true);
      }
    }

    if (options.offsets) {
      bindBones = [];

      for (int i = 0; i < (bones?.length ?? 0); ++i) {
        bone = bones![i];
        name = options.names[bone.name] ?? bone.name;

        if (options.offsets && options.offsets[name]) {
          bone.matrix.multiply(options.offsets[name]);

          bone.matrix.decompose(bone.position, bone.quaternion, bone.scale);

          bone.updateMatrixWorld();
        }

        bindBones.add(bone.matrixWorld.clone());
      }
    }

    for (int i = 0; i < (bones?.length??0); ++i) {
      bone = bones![i];
      name = options.names[bone.name] ?? bone.name;

      boneTo = getBoneByName(name, sourceBones);

      globalMatrix.copy(bone.matrixWorld);

      if (boneTo != null) {
        boneTo.updateMatrixWorld();

        if (options.useTargetMatrix) {
          relativeMatrix.copy(boneTo.matrixWorld);
        } else {
          relativeMatrix.copy(target!.matrixWorld).invert();
          relativeMatrix.multiply(boneTo.matrixWorld);
        }

        // ignore scale to extract rotation

        scale.setFromMatrixScale(relativeMatrix);
        relativeMatrix.scale(scale.set(1 / scale.x, 1 / scale.y, 1 / scale.z));

        // apply to global matrix

        globalMatrix.makeRotationFromQuaternion(quat.setFromRotationMatrix(relativeMatrix));

        if (target is Object3D) {
          final boneIndex = bones.indexOf(bone),
              wBindMatrix = bindBones != null? bindBones[boneIndex]
              : bindBoneMatrix.copy(target.skeleton!.boneInverses[boneIndex]).invert();

          globalMatrix.multiply(wBindMatrix);
        }

        globalMatrix.copyPosition(relativeMatrix);
      }

      if (bone.parent != null && bone.parent is Bone) {
        bone.matrix.copy(bone.parent!.matrixWorld).invert();
        bone.matrix.multiply(globalMatrix);
      } else {
        bone.matrix.copy(globalMatrix);
      }

      if (options.preserveHipPosition && name == options.hip) {
        pos.set(0, bone.position.y, 0);
        bone.matrix.setPosition(pos.x,pos.y,pos.z);
      }

      bone.matrix.decompose(bone.position, bone.quaternion, bone.scale);

      bone.updateMatrixWorld();
    }

    if (options.preservePosition) {
      for (int i = 0; i < (bones?.length ?? 0); ++i) {
        bone = bones![i];
        name = options.names[bone.name] ?? bone.name;

        if (name != options.hip) {
          bone.position.copy(bonesPosition[i]);
        }
      }
    }

    if (options.preserveMatrix) {
      // restore matrix
      target?.updateMatrixWorld(true);
    }
  }

  AnimationClip retargetClip(target, source, clip, [options]) {
    options = options ?? {};

    options.useFirstFramePosition = options.useFirstFramePosition != null ? options.useFirstFramePosition : false;
    options.fps = options.fps != null ? options.fps : 30;
    options.names = options.names ?? [];

    if (!source.isObject3D) {
      source = getHelperFromSkeleton(source);
    }

    final numFrames = Math.round(clip.duration * (options.fps / 1000) * 1000),
        delta = 1 / options.fps,
        convertedTracks = <KeyframeTrack>[],
        mixer = AnimationMixer(source),
        bones = getBones(target.skeleton),
        boneDatas = [];
    Vector3 positionOffset = Vector3();
    Bone bone;
    Bone? boneTo;
    dynamic boneData;
    String name;

    mixer.clipAction(clip)?.play();
    mixer.update(0);

    source.updateMatrixWorld();

    for (int i = 0; i < numFrames; ++i) {
      final time = i * delta;

      retarget(target, source, options);

      for (int j = 0; j < bones.length; ++j) {
        name = options.names[bones[j].name] ?? bones[j].name;

        boneTo = getBoneByName(name, source.skeleton);

        if (boneTo != null) {
          bone = bones[j];
          boneData = boneDatas[j] = boneDatas[j] ?? {"bone": bone};

          if (options.hip == name) {
            if (!boneData.pos) {
              boneData.pos = {"times": Float32Array(numFrames), "values": Float32Array(numFrames * 3)};
            }

            if (options.useFirstFramePosition) {
              if (i == 0) {
                positionOffset = bone.position.clone();
              }

              bone.position.sub(positionOffset);
            }

            boneData.pos.times[i] = time;

            bone.position.toArray(boneData.pos.values, i * 3);
          }

          if (!boneData.quat) {
            boneData.quat = {"times": Float32Array(numFrames), "values": Float32Array(numFrames * 4)};
          }

          boneData.quat.times[i] = time;

          bone.quaternion.toArray(boneData.quat.values, i * 4);
        }
      }

      mixer.update(delta);

      source.updateMatrixWorld();
    }

    for (int i = 0; i < boneDatas.length; ++i) {
      boneData = boneDatas[i];

      if (boneData != null) {
        if (boneData.pos) {
          convertedTracks.add(VectorKeyframeTrack(
              '.bones[' + boneData.bone.name + '].position', boneData.pos.times, boneData.pos.values, null));
        }

        convertedTracks.add(QuaternionKeyframeTrack(
            '.bones[' + boneData.bone.name + '].quaternion', boneData.quat.times, boneData.quat.values, null));
      }
    }

    mixer.uncacheAction(clip);

    return AnimationClip(clip.name, -1, convertedTracks);
  }

  SkeletonHelper getHelperFromSkeleton(Skeleton skeleton) {
    final source = SkeletonHelper(skeleton.bones[0]);
    source.skeleton = skeleton;
    return source;
  }

  List<Matrix4> getSkeletonOffsets(target, source, [options]) {
    options = options ?? {};

    final targetParentPos = Vector3(),
        targetPos = Vector3(),
        sourceParentPos = Vector3(),
        sourcePos = Vector3(),
        targetDir = Vector2(),
        sourceDir = Vector2();

    options.hip = options.hip != null ? options.hip : 'hip';
    options.names = options.names ?? {};

    if(source !is Object3D) {
      source = getHelperFromSkeleton(source);
    }

    final nameKeys = options.names.keys,
        nameValues = options.names.values,
        sourceBones = source.isObject3D ? source.skeleton.bones : getBones(source);
    final List<Bone> bones = target is Object3D ? target.skeleton!.bones : getBones(target);
    List<Matrix4> offsets = [];

    target.skeleton?.pose();

    for (int i = 0; i < bones.length; ++i) {
      final bone = bones[i];
      final name = options.names[bone.name] ?? bone.name;

      final boneTo = getBoneByName(name, sourceBones);

      if (boneTo != null && name != options.hip) {
        final boneParent = getNearestBone(bone.parent, nameKeys),
            boneToParent = getNearestBone(boneTo.parent, nameValues);

        boneParent?.updateMatrixWorld();
        boneToParent?.updateMatrixWorld();

        targetParentPos.setFromMatrixPosition(boneParent?.matrixWorld);
        targetPos.setFromMatrixPosition(bone.matrixWorld);

        sourceParentPos.setFromMatrixPosition(boneToParent?.matrixWorld);
        sourcePos.setFromMatrixPosition(boneTo.matrixWorld);

        targetDir.subVectors(Vector2(targetPos.x, targetPos.y), Vector2(targetParentPos.x, targetParentPos.y))
            .normalize();

        sourceDir.subVectors(Vector2(sourcePos.x, sourcePos.y), Vector2(sourceParentPos.x, sourceParentPos.y))
            .normalize();

        final laterialAngle = targetDir.angle() - sourceDir.angle();
        final offset = Matrix4().makeRotationFromEuler(Euler(0, 0, laterialAngle));

        bone.matrix.multiply(offset);
        bone.matrix.decompose(bone.position, bone.quaternion, bone.scale);
        bone.updateMatrixWorld();

        offsets[name] = offset;
      }
    }

    return offsets;
  }

  void renameBones(Skeleton skeleton, names) {
    final bones = getBones(skeleton);

    for (int i = 0; i < bones.length; ++i) {
      final bone = bones[i];

      if (names[bone.name]) {
        bone.name = names[bone.name];
      }
    }

    // TODO how return this;
    print("SkeletonUtils.renameBones need confirm how return this  ");
  }

  List<Bone> getBones(Skeleton skeleton) {
    return skeleton.bones;
  }

  Bone? getBoneByName(String name, Skeleton skeleton) {
    List<Bone> bones = getBones(skeleton);
    for (int i = 0; i < bones.length; i++) {
      if (name == bones[i].name) return bones[i];
    }
    return null;
  }

  Object3D? getNearestBone(Object3D? bone, String names) {
    while (bone != null) {
      if (names.indexOf(bone.name) != -1) {
        return bone;
      }
      bone = bone.parent;
    }
    return null;
  }

  Map<String, String> findBoneTrackData(String name, List<KeyframeTrack> tracks) {
    final regexp = RegExp(r"\[(.*)\]\.(.*)");

    final result = {"name": name};

    for (int i = 0; i < tracks.length; ++i) {
      // 1 is track name
      // 2 is track type
      final trackData = regexp.firstMatch(tracks[i].name);

      if (trackData != null && name == trackData.group(1)) {
        result[trackData.group(2)!] = i.toString();
      }
    }

    return result;
  }

  List<String> getEqualsBonesNames(Skeleton skeleton, targetSkeleton) {
    final sourceBones = getBones(skeleton), targetBones = getBones(targetSkeleton);
    final List<String> bones = [];

    search:
    for (int i = 0; i < sourceBones.length; i++) {
      final boneName = sourceBones[i].name;

      for (int j = 0; j < targetBones.length; j++) {
        if (boneName == targetBones[j].name) {
          bones.add(boneName);

          continue search;
        }
      }
    }

    return bones;
  }

  static Object3D clone(Object3D source) {
    final sourceLookup = Map();
    final cloneLookup = Map();

    final clone = source.clone();

    parallelTraverse(source, clone, (sourceNode, clonedNode) {
      // sourceLookup.set( clonedNode, sourceNode );
      // cloneLookup.set( sourceNode, clonedNode );

      sourceLookup[clonedNode] = sourceNode;
      cloneLookup[sourceNode] = clonedNode;
    });

    clone.traverse((node) {
      if (!node.runtimeType.toString().contains("SkinnedMesh")) return;

      final clonedMesh = node;
      final sourceMesh = sourceLookup[node];
      final sourceBones = sourceMesh.skeleton.bones;

      clonedMesh.skeleton = sourceMesh.skeleton.clone();
      clonedMesh.bindMatrix?.copy(sourceMesh.bindMatrix);

      clonedMesh.skeleton?.bones = List<Bone>.from(sourceBones.map((bone) {
        return cloneLookup[bone];
      }).toList());

      //clonedMesh.bind(clonedMesh.skeleton, clonedMesh.bindMatrix);
    });

    return clone;
  }

  static void parallelTraverse(Object3D a,Object3D? b, Function(Object3D,Object3D?) callback) {
    callback(a, b);

    for (int i = 0; i < a.children.length; i++) {
      Object3D? _bc = null;

      if (b != null && i < b.children.length) {
        _bc = b.children[i];
      }

      parallelTraverse(a.children[i], _bc, callback);
    }
  }
}
