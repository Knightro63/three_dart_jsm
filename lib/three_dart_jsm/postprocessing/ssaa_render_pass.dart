import 'dart:convert';
import 'package:three_dart/three_dart.dart';
import 'pass.dart';
import '../shaders/copy_shader.dart';

/**
*
* Supersample Anti-Aliasing Render Pass
*
* This manual approach to SSAA re-renders the scene ones for each sample with camera jitter and accumulates the results.
*
* References: https://en.wikipedia.org/wiki/Supersampling
*
*/

class SSAARenderPass extends Pass {
  int sampleLevel = 4;
  bool unbiased = true;
  Color clearColor = Color.fromHex(0x000000);
  int clearAlpha = 0;
  Color _oldClearColor = Color(0, 0, 0);
  late Map<String, dynamic> copyUniforms;
  late ShaderMaterial copyMaterial;

  WebGLRenderTarget? sampleRenderTarget;

  SSAARenderPass(Scene scene, Camera camera, Color? clearColor, int? clearAlpha) : super() {
    this.scene = scene;
    this.camera = camera;

    this.sampleLevel =
        4; // specified as n, where the number of samples is 2^n, so sampleLevel = 4, is 2^4 samples, 16.
    this.unbiased = true;

    // as we need to clear the buffer in this pass, clearColor must be set to something, defaults to black.
    this.clearColor = clearColor ?? Color.fromHex(0x000000);
    this.clearAlpha = clearAlpha ?? 0;
    this._oldClearColor = Color(0, 0, 0);

    if (copyShader == null){
      print('THREE.SSAARenderPass relies on CopyShader');
    }

    final postCopyShader = copyShader;
    this.copyUniforms = UniformsUtils.clone(postCopyShader["uniforms"]);

    this.copyMaterial = ShaderMaterial({
      "uniforms": this.copyUniforms,
      "vertexShader": postCopyShader["vertexShader"],
      "fragmentShader": postCopyShader["fragmentShader"],
      "premultipliedAlpha": true,
      "transparent": true,
      "blending": AdditiveBlending,
      "depthTest": false,
      "depthWrite": false
    });

    this.fsQuad = FullScreenQuad(this.copyMaterial);
  }

  void dispose() {
    if (this.sampleRenderTarget != null) {
      this.sampleRenderTarget!.dispose();
      this.sampleRenderTarget = null;
    }
  }

  void setSize(int width, int height) {
    if (this.sampleRenderTarget != null)
      this.sampleRenderTarget!.setSize(width, height);
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    if (this.sampleRenderTarget == null) {
      this.sampleRenderTarget = WebGLRenderTarget(
          readBuffer.width,
          readBuffer.height,
          WebGLRenderTargetOptions({
            "minFilter": LinearFilter,
            "magFilter": LinearFilter,
            "format": RGBAFormat
          }));
      this.sampleRenderTarget!.texture.name = 'SSAARenderPass.sample';
    }

    final jitterOffsets = _JitterVectors[Math.max(0, Math.min(this.sampleLevel, 5))];

    final autoClear = renderer.autoClear;
    renderer.autoClear = false;

    renderer.getClearColor(this._oldClearColor);
    final oldClearAlpha = renderer.getClearAlpha();

    final baseSampleWeight = 1.0 / jitterOffsets.length;
    final roundingRange = 1 / 32;
    this.copyUniforms['tDiffuse']["value"] = this.sampleRenderTarget!.texture;

    final viewOffset = {
      "fullWidth": readBuffer.width,
      "fullHeight": readBuffer.height,
      "offsetX": 0,
      "offsetY": 0,
      "width": readBuffer.width,
      "height": readBuffer.height
    };

    Map<String, dynamic> originalViewOffset =
        jsonDecode(jsonEncode(this.camera.view ?? {}));

    if (originalViewOffset["enabled"] == true)
      viewOffset.addAll(originalViewOffset);

    // render the scene multiple times, each slightly jitter offset from the last and accumulate the results.
    for (int i = 0; i < jitterOffsets.length; i++) {
      final jitterOffset = jitterOffsets[i];

      if (this.camera.type == "PerspectiveCamera") {
        (this.camera as PerspectiveCamera).setViewOffset(
            viewOffset["fullWidth"],
            viewOffset["fullHeight"],
            viewOffset["offsetX"] + jitterOffset[0] * 0.0625,
            viewOffset["offsetY"] + jitterOffset[1] * 0.0625, // 0.0625 = 1 / 16

            viewOffset["width"],
            viewOffset["height"]);
      } else if (this.camera.type == "OrthographicCamera") {
        (this.camera as OrthographicCamera).setViewOffset(
            viewOffset["fullWidth"],
            viewOffset["fullHeight"],
            viewOffset["offsetX"] + jitterOffset[0] * 0.0625,
            viewOffset["offsetY"] + jitterOffset[1] * 0.0625, // 0.0625 = 1 / 16

            viewOffset["width"],
            viewOffset["height"]);
      }

      double sampleWeight = baseSampleWeight;

      if (this.unbiased) {
        // the theory is that equal weights for each sample lead to an accumulation of rounding errors.
        // The following equation varies the sampleWeight per sample so that it is uniformly distributed
        // across a range of values whose rounding errors cancel each other out.

        final uniformCenteredDistribution = (-0.5 + (i + 0.5) / jitterOffsets.length);
        sampleWeight += roundingRange * uniformCenteredDistribution;
      }

      this.copyUniforms['opacity']["value"] = sampleWeight;
      renderer.setClearColor(this.clearColor, alpha: this.clearAlpha);
      renderer.setRenderTarget(this.sampleRenderTarget);
      renderer.clear(true, true, true);
      renderer.render(this.scene, this.camera);

      renderer.setRenderTarget(this.renderToScreen ? null : writeBuffer);

      if (i == 0) {
        renderer.setClearColor(Color.fromHex(0x000000), alpha: 0.0);
        renderer.clear(true, true, true);
      }

      this.fsQuad.render(renderer);
    }

    if (this.camera.type == "OrthographicCamera" &&
        originalViewOffset["enabled"] == true) {
      (this.camera as OrthographicCamera).setViewOffset(
          originalViewOffset["fullWidth"],
          originalViewOffset["fullHeight"],
          originalViewOffset["offsetX"],
          originalViewOffset["offsetY"],
          originalViewOffset["width"],
          originalViewOffset["height"]);
    } else if (this.camera.type == "PerspectiveCamera" &&
        originalViewOffset["enabled"] == true) {
      (this.camera as PerspectiveCamera).setViewOffset(
          originalViewOffset["fullWidth"],
          originalViewOffset["fullHeight"],
          originalViewOffset["offsetX"],
          originalViewOffset["offsetY"],
          originalViewOffset["width"],
          originalViewOffset["height"]);
    } else if (this.camera.type == "PerspectiveCamera") {
      (this.camera as PerspectiveCamera).clearViewOffset();
    } else if (this.camera.type == "OrthographicCamera") {
      (this.camera as OrthographicCamera).clearViewOffset();
    }

    renderer.autoClear = autoClear;
    renderer.setClearColor(this._oldClearColor, alpha: oldClearAlpha);
  }
}

// These jitter vectors are specified in integers because it is easier.
// I am assuming a [-8,8) integer grid, but it needs to be mapped onto [-0.5,0.5)
// before being used, thus these integers need to be scaled by 1/16.
//
// Sample patterns reference: https://msdn.microsoft.com/en-us/library/windows/desktop/ff476218%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
final _JitterVectors = [
  [
    [0, 0]
  ],
  [
    [4, 4],
    [-4, -4]
  ],
  [
    [-2, -6],
    [6, -2],
    [-6, 2],
    [2, 6]
  ],
  [
    [1, -3],
    [-1, 3],
    [5, 1],
    [-3, -5],
    [-5, 5],
    [-7, -1],
    [3, 7],
    [7, -7]
  ],
  [
    [1, 1],
    [-1, -3],
    [-3, 2],
    [4, -1],
    [-5, -2],
    [2, 5],
    [5, 3],
    [3, -5],
    [-2, 6],
    [0, -7],
    [-4, -6],
    [-6, 4],
    [-8, 0],
    [7, -4],
    [6, 7],
    [-7, -8]
  ],
  [
    [-4, -7],
    [-7, -5],
    [-3, -5],
    [-5, -4],
    [-1, -4],
    [-2, -2],
    [-6, -1],
    [-4, 0],
    [-7, 1],
    [-1, 2],
    [-6, 3],
    [-3, 3],
    [-7, 6],
    [-3, 6],
    [-5, 7],
    [-1, 7],
    [5, -7],
    [1, -6],
    [6, -5],
    [4, -4],
    [2, -3],
    [7, -2],
    [1, -1],
    [4, -1],
    [2, 1],
    [6, 2],
    [0, 4],
    [4, 4],
    [2, 5],
    [7, 5],
    [5, 6],
    [3, 7]
  ]
];
