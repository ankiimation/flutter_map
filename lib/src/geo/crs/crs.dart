import 'dart:math' as math;

import 'package:flutter_map/src/core/bounds.dart';
import 'package:flutter_map/src/core/point.dart';
import 'package:latlong/latlong.dart';
import 'package:tuple/tuple.dart';

abstract class Crs {
  String get code;

  Projection get projection;

  Transformation get transformation;

  const Crs();

  CustomPoint latLngToPoint(LatLng latlng, double zoom) {
    try {
      var projectedPoint = projection.project(latlng);
      var scale = this.scale(zoom);
      return transformation.transform(projectedPoint, scale.toDouble());
    } catch (e) {
      return CustomPoint(0.0, 0.0);
    }
  }

  LatLng pointToLatLng(CustomPoint point, double zoom) {
    var scale = this.scale(zoom);
    var untransformedPoint =
        transformation.untransform(point, scale.toDouble());
    try {
      return projection.unproject(untransformedPoint);
    } catch (e) {
      return null;
    }
  }

  num scale(double zoom) {
    return 256 * math.pow(2, zoom);
  }

  num zoom(double scale) {
    return math.log(scale / 256) / math.ln2;
  }

  Bounds getProjectedBounds(double zoom) {
    if (infinite) return null;

    var b = projection.bounds;
    var s = scale(zoom);
    var min = transformation.transform(b.min, s.toDouble());
    var max = transformation.transform(b.max, s.toDouble());
    return Bounds(min, max);
  }

  bool get infinite;

  Tuple2<double, double> get wrapLng;

  Tuple2<double, double> get wrapLat;
}

abstract class Earth extends Crs {
  @override
  bool get infinite => false;

  @override
  final Tuple2<double, double> wrapLng = const Tuple2(-180.0, 180.0);

  @override
  final Tuple2<double, double> wrapLat = null;

  const Earth() : super();
}

class Epsg3857 extends Earth {
  @override
  final String code = 'EPSG:3857';

  @override
  final Projection projection;

  @override
  final Transformation transformation;

  static const num _scale = 0.5 / (math.pi * SphericalMercator.r);

  const Epsg3857()
      : projection = const SphericalMercator(),
        transformation = const Transformation(_scale, 0.5, -_scale, 0.5),
        super();
}

abstract class Projection {
  const Projection();

  Bounds<double> get bounds;

  CustomPoint project(LatLng latlng);

  LatLng unproject(CustomPoint point);
}

class SphericalMercator extends Projection {
  static const int r = 6378137;
  static const double maxLatitude = 85.0511287798;
  static const double _boundsD = r * math.pi;
  static final Bounds<double> _bounds = Bounds<double>(
    CustomPoint<double>(-_boundsD, -_boundsD),
    CustomPoint<double>(_boundsD, _boundsD),
  );

  const SphericalMercator() : super();

  @override
  Bounds<double> get bounds => _bounds;

  @override
  CustomPoint project(LatLng latlng) {
    var d = math.pi / 180;
    var max = maxLatitude;
    var lat = math.max(math.min(max, latlng.latitude), -max);
    var sin = math.sin(lat * d);

    return CustomPoint(
        r * latlng.longitude * d, r * math.log((1 + sin) / (1 - sin)) / 2);
  }

  @override
  LatLng unproject(CustomPoint point) {
    var d = 180 / math.pi;
    return LatLng((2 * math.atan(math.exp(point.y / r)) - (math.pi / 2)) * d,
        point.x * d / r);
  }
}

class Transformation {
  final num a;
  final num b;
  final num c;
  final num d;

  const Transformation(this.a, this.b, this.c, this.d);

  CustomPoint transform(CustomPoint<num> point, double scale) {
    scale ??= 1.0;
    var x = scale * (a * point.x + b);
    var y = scale * (c * point.y + d);
    return CustomPoint(x, y);
  }

  CustomPoint untransform(CustomPoint point, double scale) {
    scale ??= 1.0;
    var x = (point.x / scale - b) / a;
    var y = (point.y / scale - d) / c;
    return CustomPoint(x, y);
  }
}
