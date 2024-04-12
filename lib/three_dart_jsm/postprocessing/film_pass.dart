import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import "pass.dart";

class FilmPass extends Pass {
  FilmPass(num? noiseIntensity, num? scanlinesIntensity, int? scanlinesCount, num? grayscale): super() {
    if (filmShader == null){
      print('THREE.FilmPass relies on FilmShader');
    }

    final shader = filmShader;

    this.uniforms = UniformsUtils.clone(Map<String, dynamic>.from(shader["uniforms"]));

    this.material = new ShaderMaterial({
      "uniforms": this.uniforms,
      "vertexShader": shader["vertexShader"],
      "fragmentShader": shader["fragmentShader"]
    });

    if (grayscale != null) this.uniforms["grayscale"]["value"] = grayscale;
    if (noiseIntensity != null)
      this.uniforms["nIntensity"]["value"] = noiseIntensity;
    if (scanlinesIntensity != null)
      this.uniforms["sIntensity"]["value"] = scanlinesIntensity;
    if (scanlinesCount != null)
      this.uniforms["sCount"]["value"] = scanlinesCount;

    this.fsQuad = FullScreenQuad(this.material);
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    this.uniforms['tDiffuse']["value"] = readBuffer.texture;
    this.uniforms['time']["value"] += deltaTime;

    if (this.renderToScreen) {
      renderer.setRenderTarget(null);
      this.fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);
      if (this.clear) renderer.clear();
      this.fsQuad.render(renderer);
    }
  }
}
