import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import "pass.dart";

class BloomPass extends Pass {
  late WebGLRenderTarget renderTargetX;
  late WebGLRenderTarget renderTargetY;
  late Map<String, dynamic> uniforms;
  late ShaderMaterial materialCopy;
  late Map<String, dynamic> convolutionUniforms;
  late ShaderMaterial materialConvolution;

  BloomPass(num? strength, num? kernelSize, double? sigma, int? resolution) : super() {
    strength = (strength != null) ? strength : 1;
    kernelSize = (kernelSize != null) ? kernelSize : 25;
    sigma = (sigma != null) ? sigma : 4.0;
    resolution = (resolution != null) ? resolution : 256;

    // render targets

    final pars = {
      "minFilter": LinearFilter,
      "magFilter": LinearFilter,
      "format": RGBAFormat
    };

    this.renderTargetX = WebGLRenderTarget(
        resolution, resolution, WebGLRenderTargetOptions(pars));
    this.renderTargetX.texture.name = 'BloomPass.x';
    this.renderTargetY = WebGLRenderTarget(
        resolution, resolution, WebGLRenderTargetOptions(pars));
    this.renderTargetY.texture.name = 'BloomPass.y';

    // copy material

    if(copyShader == null){
      print('THREE.BloomPass relies on CopyShader');
    }

    final postCopyShader = copyShader;

    this.uniforms = UniformsUtils.clone(postCopyShader["uniforms"]);

    this.uniforms['opacity']["value"] = strength;

    this.materialCopy = ShaderMaterial({
      "uniforms": this.uniforms,
      "vertexShader": postCopyShader["vertexShader"],
      "fragmentShader": postCopyShader["fragmentShader"],
      "blending": AdditiveBlending,
      "transparent": true
    });

    // convolution material

    if (convolutionShader == null){
      print('THREE.BloomPass relies on ConvolutionShader');
    }

    final postConvolutionShader = convolutionShader;

    this.convolutionUniforms =
        UniformsUtils.clone(postConvolutionShader["uniforms"]);

    this.convolutionUniforms['uImageIncrement']["value"] = BloomPass.blurX;
    this.convolutionUniforms['cKernel']["value"] =
        ConvolutionShader_buildKernel(sigma);

    this.materialConvolution = ShaderMaterial({
      "uniforms": this.convolutionUniforms,
      "vertexShader": postConvolutionShader["vertexShader"],
      "fragmentShader": postConvolutionShader["fragmentShader"],
      "defines": {
        'KERNEL_SIZE_FLOAT': toFixed(kernelSize, 1),
        'KERNEL_SIZE_INT': toFixed(kernelSize, 0)
      }
    });

    this.needsSwap = false;

    this.fsQuad = FullScreenQuad(null);
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    if (maskActive == true) renderer.state.buffers.stencil.setTest(false);

    // Render quad with blured scene into texture (convolution pass 1)

    this.fsQuad.material = this.materialConvolution;

    this.convolutionUniforms['tDiffuse']["value"] = readBuffer.texture;
    this.convolutionUniforms['uImageIncrement']["value"] = BloomPass.blurX;

    renderer.setRenderTarget(this.renderTargetX);
    renderer.clear(null, null, null);
    this.fsQuad.render(renderer);

    // Render quad with blured scene into texture (convolution pass 2)

    this.convolutionUniforms['tDiffuse']["value"] = this.renderTargetX.texture;
    this.convolutionUniforms['uImageIncrement']["value"] = BloomPass.blurY;

    renderer.setRenderTarget(this.renderTargetY);
    renderer.clear(null, null, null);
    this.fsQuad.render(renderer);

    // Render original scene with superimposed blur to texture

    this.fsQuad.material = this.materialCopy;

    this.uniforms['tDiffuse']["value"] = this.renderTargetY.texture;

    if (maskActive == true) renderer.state.buffers.stencil.setTest(true);

    renderer.setRenderTarget(readBuffer);
    if (this.clear) renderer.clear(null, null, null);
    this.fsQuad.render(renderer);
  }

  static Vector2 blurX = Vector2(0.001953125, 0.0);
  static Vector2 blurY = Vector2(0.0, 0.001953125);
}
