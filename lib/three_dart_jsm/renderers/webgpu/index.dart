library three_webgpu;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter_gl/native-array/index.dart';
// import 'package:flutter_webgpu/flutter_webgpu.dart';
import 'package:three_dart/extra/console.dart';
import 'package:three_dart/three3d/core/index.dart';
import 'package:three_dart/three3d/three.dart';
import 'package:three_dart/three_dart.dart';

import '../nodes/index.dart';



part './extension_helper.dart';
part './constants.dart';
part './WebGPURenderer.dart';
part 'web_gpu_info.dart';
part 'web_gpu_properties.dart';

part './WebGPUAttributes.dart';
part 'web_gpu_geometries.dart';
part './WebGPUTextures.dart';
part 'web_gpu_objects.dart';
part './WebGPUComputePipelines.dart';

part './WebGPUProgrammableStage.dart';
part './WebGPURenderPipeline.dart';
part './WebGPURenderPipelines.dart';
part 'web_gpu_binding.dart';
part './WebGPUBindings.dart';
part './WebGPUBackground.dart';
part 'web_gpu_render_lists.dart';

part './nodes/WebGPUNodes.dart';
part './nodes/WebGPUNodeBuilder.dart';

part './WebGPUTextureUtils.dart';
part './WebGPUSampler.dart';
part './nodes/WebGPUNodeSampler.dart';
part './WebGPUSampledTexture.dart';
part './WebGPUStorageBuffer.dart';
part './nodes/WebGPUNodeSampledTexture.dart';
part './WebGPUUniformBuffer.dart';
part './WebGPUUniformsGroup.dart';
part 'web_gpu_buffer_utils.dart';
part './nodes/WebGPUNodeUniformsGroup.dart';
part './nodes/WebGPUNodeUniform.dart';
part 'web_gpu_texture_renderer.dart';
part 'web_gpu_uniform.dart';
