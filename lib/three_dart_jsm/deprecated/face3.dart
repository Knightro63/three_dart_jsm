import 'package:three_dart/three3d/three.dart';

class Face3 {
  late int a;
  late int b;
  late int c;
  late Vector3 normal;
  late List<Vector3> vertexNormals;
  late Color color;
  late List<Color> vertexColors;
  late int materialIndex;

  Face3(this.a, this.b, this.c, [List<Vector3>? normals, List<Color>? colors, int materialIndex = 0]) {
    this.normal = (normals != null && normals.runtimeType == Vector3)
        ? normals[0]
        : Vector3();
    this.vertexNormals = normals ?? [];

    this.color = (colors != null && colors.runtimeType == Color)
        ? colors[0]
        : Color(0, 0, 0);
    this.vertexColors = colors ?? [];

    this.materialIndex = materialIndex;
  }

  Face3 clone() {
    return Face3(0, 0, 0, null, null).copy(this);
  }

  Face3 copy(Face3 source) {
    this.a = source.a;
    this.b = source.b;
    this.c = source.c;

    this.normal.copy(source.normal);
    this.color.copy(source.color);

    this.materialIndex = source.materialIndex;

    this.vertexNormals = List<Vector3>.filled(source.vertexNormals.length, Vector3());
    for (int i = 0, il = source.vertexNormals.length; i < il; i++) {
      this.vertexNormals[i] = source.vertexNormals[i].clone();
    }

    this.vertexColors = List<Color>.filled(source.vertexColors.length, Color(0, 0, 0));
    for (int i = 0, il = source.vertexColors.length; i < il; i++) {
      this.vertexColors[i] = source.vertexColors[i].clone();
    }

    return this;
  }
}
