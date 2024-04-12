import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

class Wireframe extends Mesh{
  String type = 'Wireframe';
  bool isWireframe = true;

  Wireframe([BufferGeometry? geometry, Material? material]):super(geometry,material);

  Wireframe computeLineDistances(){
		final start = Vector3();
		final end = Vector3();

    final geometry = this.geometry!;

    final instanceStart = geometry.attributes['instanceStart'];
    final instanceEnd = geometry.attributes['instanceEnd'];
    final lineDistances = Float32Array((2 * instanceStart.data.count).toInt());

    for (int i = 0, j = 0, l = instanceStart.data.count; i < l; i ++, j += 2 ) {
      start.fromBufferAttribute( instanceStart, i );
      end.fromBufferAttribute( instanceEnd, i );

      lineDistances[ j ] = ( j == 0 ) ? 0 : lineDistances[ j - 1 ];
      lineDistances[ j + 1 ] = lineDistances[ j ] + start.distanceTo( end );
    }

    final instanceDistanceBuffer = InstancedInterleavedBuffer( lineDistances, 2, 1 ); // d0, d1

    geometry.setAttribute(
      'instanceDistanceStart', 
      InterleavedBufferAttribute( instanceDistanceBuffer, 1, 0) 
    ); // d0
    geometry.setAttribute(
      'instanceDistanceEnd', 
      InterleavedBufferAttribute( instanceDistanceBuffer, 1, 1) 
    ); // d1

    return this;
  }
}

