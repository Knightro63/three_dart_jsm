import 'geometry.dart';

class DodecahedronGeometry extends Geometry {
  String type = "DodecahedronGeometry";

  DodecahedronGeometry({num radius = 0, int detail = 0}) : super() {
    this.parameters = {"radius": radius, "detail": detail};

    this.fromBufferGeometry(DodecahedronGeometry(radius:radius, detail:detail));
    this.mergeVertices();
  }
}
