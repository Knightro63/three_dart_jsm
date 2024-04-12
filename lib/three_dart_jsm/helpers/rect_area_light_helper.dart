import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

/**
 *  This helper must be added as a child of the light
 */

class RectAreaLightHelper extends Line {
  late RectAreaLight light;
  Color? color;

  RectAreaLightHelper.create(light, color) : super(light, color);

	factory RectAreaLightHelper( light, color ) {

		List<double> positions = [ 1, 1, 0, - 1, 1, 0, - 1, - 1, 0, 1, - 1, 0, 1, 1, 0 ];

		final geometry = BufferGeometry();
		geometry.setAttribute( 'position', Float32BufferAttribute( Float32Array.fromList(positions), 3 ) );
		geometry.computeBoundingSphere();

		final material = LineBasicMaterial( { 'fog': false } );

		final instance =  RectAreaLightHelper.create( geometry, material );

		instance.light = light;
		instance.color = color; // optional hardwired color for the helper
		instance.type = 'RectAreaLightHelper';

		//

		List<double> positions2 = [ 1, 1, 0, - 1, 1, 0, - 1, - 1, 0, 1, 1, 0, - 1, - 1, 0, 1, - 1, 0 ];

		final geometry2 = BufferGeometry();
		geometry2.setAttribute( 'position', Float32BufferAttribute(  Float32Array.fromList(positions2), 3 ) );
		geometry2.computeBoundingSphere();

		instance.add( Mesh( geometry2, MeshBasicMaterial( { 'side': BackSide, 'fog': false } ) ) );

    return instance;
	}

	void updateMatrixWorld([bool force = false]) {

		this.scale.set( 0.5 * this.light.width!, 0.5 * this.light.height!, 1 );

		if ( this.color != null ) {

			this.material.color.set( this.color );
			this.children[ 0 ].material.color.set( this.color );

		} else {

			this.material.color.copy( this.light.color ).multiplyScalar( this.light.intensity );

			// prevent hue shift
			final c = this.material.color;
			final max = Math.max3( c.r, c.g, c.b );
			if ( max > 1 ) c.multiplyScalar( 1 / max );

			this.children[ 0 ].material.color.copy( this.material.color );

		}

		// ignore world scale on light
		this.matrixWorld.extractRotation( this.light.matrixWorld ).scale( this.scale ).copyPosition( this.light.matrixWorld );

		this.children[ 0 ].matrixWorld.copy( this.matrixWorld );

	}

  final _meshinverseMatrix = Matrix4();
  final _meshray = Ray(null, null);
  final _meshsphere = Sphere(null, null);

  @override
  void raycast(Raycaster raycaster, List<Intersection> intersects) {

    print("==== raycast ${this}  1 ");

    final geometry = this.geometry!;
    final material = this.material;
    final matrixWorld = this.matrixWorld;

    if (material == null) return;

    // Checking boundingSphere distance to ray

    if (geometry.boundingSphere == null) geometry.computeBoundingSphere();

    _meshsphere.copy(geometry.boundingSphere!);
    _meshsphere.applyMatrix4(matrixWorld);

    if (raycaster.ray.intersectsSphere(_meshsphere) == false) return;

    _meshinverseMatrix.copy(matrixWorld).invert();
    _meshray.copy(raycaster.ray).applyMatrix4(_meshinverseMatrix);

    // Check boundingBox before continuing

    if (geometry.boundingBox != null) {
      if (_meshray.intersectsBox(geometry.boundingBox!) == false) return;
    }

    Intersection? intersection;
    final index = geometry.index;
    final position = geometry.attributes["position"];
    final morphPosition = geometry.morphAttributes["position"];
    final morphTargetsRelative = geometry.morphTargetsRelative;
    final uv = geometry.attributes["uv"];
    final uv2 = geometry.attributes["uv2"];
    final groups = geometry.groups;
    final drawRange = geometry.drawRange;

    print("==== raycast ${this}  index: ${index}  ");

    if (index != null) {
      // indexed buffer geometry

      if (material is List) {
        for (int i = 0, il = groups.length; i < il; i++) {
          final group = groups[i];
          final groupMaterial = material[group["materialIndex"]];

          final start = Math.max<int>(group["start"], drawRange["start"]!);
          final end = Math.min<int>((group["start"] + group["count"]),
              (drawRange["start"]! + drawRange["count"]!));

          for (int j = start, jl = end; j < jl; j += 3) {
            int a = index.getX(j)!.toInt();
            int b = index.getX(j + 1)!.toInt();
            int c = index.getX(j + 2)!.toInt();

            intersection = checkBufferGeometryIntersection(
                this,
                groupMaterial,
                raycaster,
                _meshray,
                position,
                morphPosition,
                morphTargetsRelative,
                uv,
                uv2,
                a,
                b,
                c);

            if (intersection != null) {
              intersection.faceIndex = Math.floor(j / 3);
              // triangle number in indexed buffer semantics
              intersection.face?.materialIndex = group["materialIndex"];
              intersects.add(intersection);
            }
          }
        }
      } 
      else {
        final start = Math.max(0, drawRange["start"]!);
        final end = Math.min(index.count, (drawRange["start"]! + drawRange["count"]!));

        for (int i = start, il = end; i < il; i += 3) {
          int a = index.getX(i)!.toInt();
          int b = index.getX(i + 1)!.toInt();
          int c = index.getX(i + 2)!.toInt();

          intersection = checkBufferGeometryIntersection(
              this,
              material,
              raycaster,
              _meshray,
              position,
              morphPosition,
              morphTargetsRelative,
              uv,
              uv2,
              a,
              b,
              c);

          if (intersection != null) {
            intersection.faceIndex = Math.floor(i / 3);
            // triangle number in indexed buffer semantics
            intersects.add(intersection);
          }
        }
      }
    } else if (position != null) {
      // non-indexed buffer geometry

      if (material is List) {
        for (int i = 0, il = groups.length; i < il; i++) {
          final group = groups[i];
          final groupMaterial = material[group["materialIndex"]];

          final start = Math.max<int>(group["start"], drawRange["start"]!);
          final end = Math.min<int>((group["start"] + group["count"]),
              (drawRange["start"]! + drawRange["count"]!));

          for (int j = start, jl = end; j < jl; j += 3) {
            final a = j;
            final b = j + 1;
            final c = j + 2;

            intersection = checkBufferGeometryIntersection(
                this,
                groupMaterial,
                raycaster,
                _meshray,
                position,
                morphPosition,
                morphTargetsRelative,
                uv,
                uv2,
                a,
                b,
                c);

            if (intersection != null) {
              intersection.faceIndex = Math.floor(j / 3);
              // triangle number in non-indexed buffer semantics
              intersection.face?.materialIndex = group["materialIndex"];
              intersects.add(intersection);
            }
          }
        }
      } 
      else {
        final start = Math.max(0, drawRange["start"]!);
        final end = Math.min<int>(position.count, (drawRange["start"]! + drawRange["count"]!));

        for (int i = start, il = end; i < il; i += 3) {
          final a = i;
          final b = i + 1;
          final c = i + 2;

          intersection = checkBufferGeometryIntersection(
              this,
              material,
              raycaster,
              _meshray,
              position,
              morphPosition,
              morphTargetsRelative,
              uv,
              uv2,
              a,
              b,
              c);

          if (intersection != null) {
            intersection.faceIndex = Math.floor(
                i / 3); // triangle number in non-indexed buffer semantics
            intersects.add(intersection);
          }
        }
      }
    }
  }

	void dispose() {
		this.geometry?.dispose();
		this.material.dispose();
		this.children[ 0 ].geometry?.dispose();
		this.children[ 0 ].material.dispose();
	}
}
