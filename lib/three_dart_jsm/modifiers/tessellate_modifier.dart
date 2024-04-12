import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

/**
 * Break faces with edges longer than maxEdgeLength
 */

class TessellateModifier {
  num maxEdgeLength = 0.1;
  num maxIterations = 6.0;
  num maxFaces = double.infinity;

  TessellateModifier({double maxEdgeLength = 0.1, int maxIterations = 6, double maxFaces = double.infinity}) {
    this.maxEdgeLength = maxEdgeLength;
    this.maxIterations = maxIterations;
    this.maxFaces = maxFaces;
  }

  modify(BufferGeometry geometry) {
    if (geometry.index != null) {
      geometry = geometry.toNonIndexed();
    }

    //
    final maxIterations = this.maxIterations;
    final maxEdgeLengthSquared = this.maxEdgeLength * this.maxEdgeLength;

    final va = Vector3();
    final vb = Vector3();
    final vc = Vector3();
    final vm = Vector3();
    final vs = [va, vb, vc, vm];

    final na = Vector3();
    final nb = Vector3();
    final nc = Vector3();
    final nm = Vector3();
    final ns = [na, nb, nc, nm];

    final ca = Color(1, 1, 1);
    final cb = Color(1, 1, 1);
    final cc = Color(1, 1, 1);
    final cm = Color(1, 1, 1);
    final cs = [ca, cb, cc, cm];

    final ua = Vector2();
    final ub = Vector2();
    final uc = Vector2();
    final um = Vector2();
    final us = [ua, ub, uc, um];

    final u2a = Vector2();
    final u2b = Vector2();
    final u2c = Vector2();
    final u2m = Vector2();
    final u2s = [u2a, u2b, u2c, u2m];

    final attributes = geometry.attributes;
    final hasNormals = attributes["normal"] != null;
    final hasColors = attributes["color"] != null;
    final hasUVs = attributes["uv"] != null;
    final hasUV2s = attributes["uv2"] != null;

    Float32Array? positions = attributes["position"].array;
    Float32Array? normals = hasNormals ? attributes["normal"].array : null;
    Float32Array? colors = hasColors ? attributes["color"].array : null;
    Float32Array? uvs = hasUVs ? attributes["uv"].array : null;
    Float32Array? uv2s = hasUV2s ? attributes["uv2"].array : null;

    List<double> positions2 = positions?.sublist(0) ?? [];
    List<double> normals2 = normals?.sublist(0) ?? [];
    List<double> colors2 = colors?.sublist(0) ?? [];
    List<double> uvs2 = uvs?.sublist(0) ?? [];
    List<double> uv2s2 = uv2s?.sublist(0) ?? [];

    int iteration = 0;
    bool tessellating = true;

    Function addTriangle = (a, b, c) {
      final v1 = vs[a];
      final v2 = vs[b];
      final v3 = vs[c];

      positions2.addAll([v1.x, v1.y, v1.z]);
      positions2.addAll([v2.x, v2.y, v2.z]);
      positions2.addAll([v3.x, v3.y, v3.z]);

      if (hasNormals) {
        final n1 = ns[a];
        final n2 = ns[b];
        final n3 = ns[c];

        normals2.addAll([n1.x, n1.y, n1.z]);
        normals2.addAll([n2.x, n2.y, n2.z]);
        normals2.addAll([n3.x, n3.y, n3.z]);
      }

      if (hasColors) {
        final c1 = cs[a];
        final c2 = cs[b];
        final c3 = cs[c];

        colors2.addAll([c1.r, c1.g, c1.b]);
        colors2.addAll([c2.r, c2.g, c2.b]);
        colors2.addAll([c3.r, c3.g, c3.b]);
      }

      if (hasUVs) {
        final u1 = us[a];
        final u2 = us[b];
        final u3 = us[c];

        uvs2.addAll([u1.x, u1.y]);
        uvs2.addAll([u2.x, u2.y]);
        uvs2.addAll([u3.x, u3.y]);
      }

      if (hasUV2s) {
        final u21 = u2s[a];
        final u22 = u2s[b];
        final u23 = u2s[c];

        uv2s2.addAll([u21.x, u21.y]);
        uv2s2.addAll([u22.x, u22.y]);
        uv2s2.addAll([u23.x, u23.y]);
      }
    };

    while (tessellating && iteration < maxIterations) {
      iteration++;
      tessellating = false;

      positions = Float32Array.from(positions2);
      positions2 = [];

      if (hasNormals) {
        normals = Float32Array.from(normals2);
        normals2 = [];
      }

      if (hasColors) {
        colors = Float32Array.from(colors2);
        colors2 = [];
      }

      if (hasUVs) {
        uvs = Float32Array.from(uvs2);
        uvs2 = [];
      }

      if (hasUV2s) {
        uv2s = Float32Array.from(uv2s2);
        uv2s2 = [];
      }

      for (int i = 0, i2 = 0, il = positions.length; i < il; i += 9, i2 += 6) {
        va.fromArray(positions, i + 0);
        vb.fromArray(positions, i + 3);
        vc.fromArray(positions, i + 6);

        if (hasNormals) {
          na.fromArray(normals, i + 0);
          nb.fromArray(normals, i + 3);
          nc.fromArray(normals, i + 6);
        }

        if (hasColors) {
          ca.fromArray(colors, i + 0);
          cb.fromArray(colors, i + 3);
          cc.fromArray(colors, i + 6);
        }

        if (hasUVs) {
          ua.fromArray(uvs, i2 + 0);
          ub.fromArray(uvs, i2 + 2);
          uc.fromArray(uvs, i2 + 4);
        }

        if (hasUV2s) {
          u2a.fromArray(uv2s, i2 + 0);
          u2b.fromArray(uv2s, i2 + 2);
          u2c.fromArray(uv2s, i2 + 4);
        }

        final dab = va.distanceToSquared(vb);
        final dbc = vb.distanceToSquared(vc);
        final dac = va.distanceToSquared(vc);

        if (dab > maxEdgeLengthSquared ||
            dbc > maxEdgeLengthSquared ||
            dac > maxEdgeLengthSquared) {
          tessellating = true;

          if (dab >= dbc && dab >= dac) {
            vm.lerpVectors(va, vb, 0.5);
            if (hasNormals) nm.lerpVectors(na, nb, 0.5);
            if (hasColors) cm.lerpColors(ca, cb, 0.5);
            if (hasUVs) um.lerpVectors(ua, ub, 0.5);
            if (hasUV2s) u2m.lerpVectors(u2a, u2b, 0.5);

            addTriangle(0, 3, 2);
            addTriangle(3, 1, 2);
          } else if (dbc >= dab && dbc >= dac) {
            vm.lerpVectors(vb, vc, 0.5);
            if (hasNormals) nm.lerpVectors(nb, nc, 0.5);
            if (hasColors) cm.lerpColors(cb, cc, 0.5);
            if (hasUVs) um.lerpVectors(ub, uc, 0.5);
            if (hasUV2s) u2m.lerpVectors(u2b, u2c, 0.5);

            addTriangle(0, 1, 3);
            addTriangle(3, 2, 0);
          } else {
            vm.lerpVectors(va, vc, 0.5);
            if (hasNormals) nm.lerpVectors(na, nc, 0.5);
            if (hasColors) cm.lerpColors(ca, cc, 0.5);
            if (hasUVs) um.lerpVectors(ua, uc, 0.5);
            if (hasUV2s) u2m.lerpVectors(u2a, u2c, 0.5);

            addTriangle(0, 1, 3);
            addTriangle(3, 1, 2);
          }
        } else {
          addTriangle(0, 1, 2);
        }
      }
    }

    final geometry2 = BufferGeometry();

    geometry2.setAttribute(
        'position', Float32BufferAttribute(Float32Array.from(positions2), 3, false));

    if (hasNormals) {
      geometry2.setAttribute(
          'normal', Float32BufferAttribute(Float32Array.from(normals2), 3, false));
    }

    if (hasColors) {
      geometry2.setAttribute(
          'color', Float32BufferAttribute(Float32Array.from(colors2), 3, false));
    }

    if (hasUVs) {
      geometry2.setAttribute('uv', Float32BufferAttribute(Float32Array.from(uvs2), 2, false));
    }

    if (hasUV2s) {
      geometry2.setAttribute(
          'uv2', Float32BufferAttribute(Float32Array.from(uv2s2), 2, false));
    }

    return geometry2;
  }

  // Applies the "modify" pattern
  // modify( geometry ) {

  //   final isBufferGeometry = geometry.isBufferGeometry;

  //   if ( isBufferGeometry ) {

  //     geometry = Geometry().fromBufferGeometry( geometry );

  //   } else {

  //     geometry = geometry.clone();

  //   }

  //   geometry.mergeVertices( precisionPoints: 6 );

  //   final finalized = false;
  //   final iteration = 0;
  //   final maxEdgeLengthSquared = this.maxEdgeLength * this.maxEdgeLength;

  //   final edge;

  //   while ( ! finalized && iteration < this.maxIterations && geometry.faces.length < this.maxFaces ) {

  //     List<Face3> faces = [];
  //     List<List<List<Vector2>>> faceVertexUvs = [];

  //     finalized = true;
  //     iteration ++;

  //     for ( final i = 0, il = geometry.faceVertexUvs.length; i < il; i ++ ) {
  //       faceVertexUvs.add([]);
  //     }

  //     for ( final i = 0, il = geometry.faces.length; i < il; i ++ ) {

  //       final face = geometry.faces[ i ];

  //       if ( face is Face3 ) {

  //         final a = face.a;
  //         final b = face.b;
  //         final c = face.c;

  //         final va = geometry.vertices[ a ];
  //         final vb = geometry.vertices[ b ];
  //         final vc = geometry.vertices[ c ];

  //         final dab = va.distanceToSquared( vb );
  //         final dbc = vb.distanceToSquared( vc );
  //         final dac = va.distanceToSquared( vc );

  //         final limitReached = ( faces.length + il - i ) >= this.maxFaces;

  //         final vm;

  //         if ( ! limitReached && ( dab > maxEdgeLengthSquared || dbc > maxEdgeLengthSquared || dac > maxEdgeLengthSquared ) ) {

  //           finalized = false;

  //           final m = geometry.vertices.length;

  //           final triA = face.clone();
  //           final triB = face.clone();

  //           if ( dab >= dbc && dab >= dac ) {

  //             vm = va.clone();
  //             vm.lerp( vb, 0.5 );

  //             triA.a = a;
  //             triA.b = m;
  //             triA.c = c;

  //             triB.a = m;
  //             triB.b = b;
  //             triB.c = c;

  //             if ( face.vertexNormals.length == 3 ) {

  //               final vnm = face.vertexNormals[ 0 ].clone();
  //               vnm.lerp( face.vertexNormals[ 1 ], 0.5 );

  //               triA.vertexNormals[ 1 ].copy( vnm );
  //               triB.vertexNormals[ 0 ].copy( vnm );

  //             }

  //             if ( face.vertexColors.length == 3 ) {

  //               final vcm = face.vertexColors[ 0 ].clone();
  //               vcm.lerp( face.vertexColors[ 1 ], 0.5 );

  //               triA.vertexColors[ 1 ].copy( vcm );
  //               triB.vertexColors[ 0 ].copy( vcm );

  //             }

  //             edge = 0;

  //           } else if ( dbc >= dab && dbc >= dac ) {

  //             vm = vb.clone();
  //             vm.lerp( vc, 0.5 );

  //             triA.a = a;
  //             triA.b = b;
  //             triA.c = m;

  //             triB.a = m;
  //             triB.b = c;
  //             triB.c = a;

  //             if ( face.vertexNormals.length == 3 ) {

  //               final vnm = face.vertexNormals[ 1 ].clone();
  //               vnm.lerp( face.vertexNormals[ 2 ], 0.5 );

  //               triA.vertexNormals[ 2 ].copy( vnm );

  //               triB.vertexNormals[ 0 ].copy( vnm );
  //               triB.vertexNormals[ 1 ].copy( face.vertexNormals[ 2 ] );
  //               triB.vertexNormals[ 2 ].copy( face.vertexNormals[ 0 ] );

  //             }

  //             if ( face.vertexColors.length == 3 ) {

  //               final vcm = face.vertexColors[ 1 ].clone();
  //               vcm.lerp( face.vertexColors[ 2 ], 0.5 );

  //               triA.vertexColors[ 2 ].copy( vcm );

  //               triB.vertexColors[ 0 ].copy( vcm );
  //               triB.vertexColors[ 1 ].copy( face.vertexColors[ 2 ] );
  //               triB.vertexColors[ 2 ].copy( face.vertexColors[ 0 ] );

  //             }

  //             edge = 1;

  //           } else {

  //             vm = va.clone();
  //             vm.lerp( vc, 0.5 );

  //             triA.a = a;
  //             triA.b = b;
  //             triA.c = m;

  //             triB.a = m;
  //             triB.b = b;
  //             triB.c = c;

  //             if ( face.vertexNormals.length == 3 ) {

  //               final vnm = face.vertexNormals[ 0 ].clone();
  //               vnm.lerp( face.vertexNormals[ 2 ], 0.5 );

  //               triA.vertexNormals[ 2 ].copy( vnm );
  //               triB.vertexNormals[ 0 ].copy( vnm );

  //             }

  //             if ( face.vertexColors.length == 3 ) {

  //               final vcm = face.vertexColors[ 0 ].clone();
  //               vcm.lerp( face.vertexColors[ 2 ], 0.5 );

  //               triA.vertexColors[ 2 ].copy( vcm );
  //               triB.vertexColors[ 0 ].copy( vcm );

  //             }

  //             edge = 2;

  //           }

  //           faces.addAll( [triA, triB] );
  //           geometry.vertices.add( vm );

  //           for ( final j = 0, jl = geometry.faceVertexUvs.length; j < jl; j ++ ) {

  //             if ( geometry.faceVertexUvs[ j ].length > 0 ) {

  //               final uvs = geometry.faceVertexUvs[ j ][ i ];

  //               final uvA = uvs[ 0 ];
  //               final uvB = uvs[ 1 ];
  //               final uvC = uvs[ 2 ];

  //               List<Vector2> uvsTriA;
  //               List<Vector2> uvsTriB;

  //               // AB

  //               if ( edge == 0 ) {

  //                 final uvM = uvA.clone();
  //                 uvM.lerp( uvB, 0.5 );

  //                 uvsTriA = [ uvA.clone(), uvM.clone(), uvC.clone() ];
  //                 uvsTriB = [ uvM.clone(), uvB.clone(), uvC.clone() ];

  //                 // BC

  //               } else if ( edge == 1 ) {

  //                 final uvM = uvB.clone();
  //                 uvM.lerp( uvC, 0.5 );

  //                 uvsTriA = [ uvA.clone(), uvB.clone(), uvM.clone() ];
  //                 uvsTriB = [ uvM.clone(), uvC.clone(), uvA.clone() ];

  //                 // AC

  //               } else {

  //                 final uvM = uvA.clone();
  //                 uvM.lerp( uvC, 0.5 );

  //                 uvsTriA = [ uvA.clone(), uvB.clone(), uvM.clone() ];
  //                 uvsTriB = [ uvM.clone(), uvB.clone(), uvC.clone() ];

  //               }

  //               faceVertexUvs[ j ].addAll( [uvsTriA, uvsTriB] );

  //             }

  //           }

  //         } else {

  //           faces.add( face );

  //           for ( final j = 0, jl = geometry.faceVertexUvs.length; j < jl; j ++ ) {

  //             faceVertexUvs[ j ].add( geometry.faceVertexUvs[ j ][ i ] );

  //           }

  //         }

  //       }

  //     }

  //     geometry.faces = faces;
  //     geometry.faceVertexUvs = faceVertexUvs;

  //   }

  //   if ( isBufferGeometry ) {

  //     return BufferGeometry().fromGeometry( geometry );

  //   } else {

  //     return geometry;

  //   }

  // }

}
