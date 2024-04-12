part of three_webgpu;

class WebGPUGeometries {
  late WebGPUAttributes attributes;
  late WebGPUInfo info;
  late WeakMap geometries;

  WebGPUGeometries(WebGPUAttributes attributes, WebGPUInfo info) {
    this.attributes = attributes;
    this.info = info;

    this.geometries = new WeakMap();
  }

  void update(BufferGeometry geometry) {
    if (this.geometries.has(geometry) == false) {
      // final disposeCallback = onGeometryDispose.bind( this );

      // this.geometries.set( geometry, onGeometryDispose );

      this.info.memory["geometries"]++;

      // geometry.addEventListener( 'dispose', onGeometryDispose );

    }

    final geometryAttributes = geometry.attributes;

    for (final name in geometryAttributes.keys) {
      this.attributes.update(geometryAttributes[name]);
    }

    final index = geometry.index;

    if (index != null) {
      this.attributes.update(index, true);
    }
  }

  // onGeometryDispose( event ) {

  //   final geometry = event.target;
  //   final disposeCallback = this.geometries.get( geometry );

  //   this.geometries.delete( geometry );

  //   this.info.memory["geometries"] --;

  //   geometry.removeEventListener( 'dispose', disposeCallback );

  //   final index = geometry.index;
  //   final geometryAttributes = geometry.attributes;

  //   if ( index != null ) {

  //     this.attributes.remove( index );

  //   }

  //   for ( final name in geometryAttributes ) {

  //     this.attributes.remove( geometryAttributes[ name ] );

  //   }

  // }

}
