part of three_webgpu;

class WebGPUTextureRenderer {
  late dynamic renderer;
  late WebGLRenderTarget renderTarget;

  WebGPUTextureRenderer(renderer, [options]) {
    options ??= {};

    this.renderer = renderer;

    // @TODO: Consider to introduce WebGPURenderTarget or rename WebGLRenderTarget to just RenderTarget

    this.renderTarget = new WebGLRenderTarget(1, 1, options);
  }

  getTexture() {
    return this.renderTarget.texture;
  }

  void setSize(int width, int height) {
    this.renderTarget.setSize(width, height);
  }

  void render(Scene scene, Camera camera) {
    final renderer = this.renderer;
    final renderTarget = this.renderTarget;

    renderer.setRenderTarget(renderTarget);
    renderer.render(scene, camera);
    renderer.setRenderTarget(null);
  }
}
