import 'package:three_dart/three_dart.dart';
import "pass.dart";

class ShaderPass extends Pass {
  late dynamic textureID;
  late Map<String, dynamic> uniforms;
  late Material material;
  late FullScreenQuad fsQuad;

  ShaderPass([ShaderMaterial? shader, String? textureID]) : super() {
    this.textureID = (textureID != null) ? textureID : 'tDiffuse';

    if (shader != null) {
      this.uniforms = shader.uniforms;
      this.material = shader;
    } 

    this.fsQuad = FullScreenQuad(this.material);
  }

  ShaderPass.fromJson(Map? shader):super(){
    this.uniforms = UniformsUtils.clone(shader?["uniforms"]);
    Map<String, dynamic> _defines = {};
    _defines.addAll(shader?["defines"] ?? {});
    this.material = ShaderMaterial({
      "defines": _defines,
      "uniforms": this.uniforms,
      "vertexShader": shader?["vertexShader"],
      "fragmentShader": shader?["fragmentShader"]
    });
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    if (this.uniforms[this.textureID] != null) {
      this.uniforms[this.textureID]["value"] = readBuffer.texture;
    }

    this.fsQuad.material = this.material;

    if (this.renderToScreen) {
      renderer.setRenderTarget(null);
      this.fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);
      // TODO: Avoid using autoClear properties, see https://github.com/mrdoob/three.js/pull/15571#issuecomment-465669600
      if (this.clear)
        renderer.clear(renderer.autoClearColor, renderer.autoClearDepth,
            renderer.autoClearStencil);
      this.fsQuad.render(renderer);
    }
  }
}
