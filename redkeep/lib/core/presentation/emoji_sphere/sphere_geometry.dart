import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A point or direction in the sphere's space: x right, y up, z toward
/// the viewer.
@immutable
final class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const front = Vec3(0, 0, 1);

  final double x, y, z;

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  Vec3 operator *(double factor) => Vec3(x * factor, y * factor, z * factor);
  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  Vec3 normalized() {
    final size = length;
    return size == 0 ? this : this * (1 / size);
  }

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// A turn of the whole sphere, as a unit quaternion. Turns compose freely,
/// so the sphere has no fixed axis.
@immutable
final class SphereRotation {
  const SphereRotation(this.w, this.x, this.y, this.z);

  static const identity = SphereRotation(1, 0, 0, 0);

  factory SphereRotation.axisAngle(Vec3 axis, double angle) {
    final unit = axis.normalized();
    final half = angle / 2;
    final s = math.sin(half);
    return SphereRotation(math.cos(half), unit.x * s, unit.y * s, unit.z * s);
  }

  /// The shortest turn that carries [from] onto [to] (both unit length).
  factory SphereRotation.between(Vec3 from, Vec3 to) {
    final cos = from.dot(to).clamp(-1.0, 1.0);
    if (cos > 1 - 1e-9) return identity;
    var axis = from.cross(to);
    if (axis.length < 1e-9) {
      // Opposite points: any axis at right angles will do.
      axis = from.cross(const Vec3(0, 1, 0));
      if (axis.length < 1e-9) axis = from.cross(const Vec3(1, 0, 0));
    }
    return SphereRotation.axisAngle(axis, math.acos(cos));
  }

  final double w, x, y, z;

  /// This turn applied after [other].
  SphereRotation operator *(SphereRotation o) => SphereRotation(
    w * o.w - x * o.x - y * o.y - z * o.z,
    w * o.x + x * o.w + y * o.z - z * o.y,
    w * o.y - x * o.z + y * o.w + z * o.x,
    w * o.z + x * o.y - y * o.x + z * o.w,
  );

  SphereRotation get inverse => SphereRotation(w, -x, -y, -z);

  SphereRotation normalized() {
    final size = math.sqrt(w * w + x * x + y * y + z * z);
    return SphereRotation(w / size, x / size, y / size, z / size);
  }

  Vec3 rotate(Vec3 v) {
    // v + 2w(q × v) + 2q × (q × v)
    final q = Vec3(x, y, z);
    final t = q.cross(v) * 2;
    return v + t * w + q.cross(t);
  }

  /// The turn that brings [cell] to the front with its north pointing up,
  /// so the emoji there reads upright.
  factory SphereRotation.facing(SphereCell cell) {
    // Rows of the rotation matrix: the cell's east, north and normal.
    final SphereCell(east: e, north: n, normal: f) = cell;
    final trace = e.x + n.y + f.z;
    if (trace > 0) {
      final s = .5 / math.sqrt(trace + 1);
      return SphereRotation(
        .25 / s,
        (f.y - n.z) * s,
        (e.z - f.x) * s,
        (n.x - e.y) * s,
      ).normalized();
    }
    if (e.x > n.y && e.x > f.z) {
      final s = 2 * math.sqrt(1 + e.x - n.y - f.z);
      return SphereRotation(
        (f.y - n.z) / s,
        .25 * s,
        (e.y + n.x) / s,
        (e.z + f.x) / s,
      ).normalized();
    }
    if (n.y > f.z) {
      final s = 2 * math.sqrt(1 + n.y - e.x - f.z);
      return SphereRotation(
        (e.z - f.x) / s,
        (e.y + n.x) / s,
        .25 * s,
        (n.z + f.y) / s,
      ).normalized();
    }
    final s = 2 * math.sqrt(1 + f.z - e.x - n.y);
    return SphereRotation(
      (n.x - e.y) / s,
      (e.z + f.x) / s,
      (n.z + f.y) / s,
      .25 * s,
    ).normalized();
  }

  /// Spherical interpolation from [a] to [b].
  static SphereRotation slerp(SphereRotation a, SphereRotation b, double t) {
    var cos = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;
    var end = b;
    if (cos < 0) {
      cos = -cos;
      end = SphereRotation(-b.w, -b.x, -b.y, -b.z);
    }
    double from, to;
    if (cos > .9995) {
      from = 1 - t;
      to = t;
    } else {
      final angle = math.acos(cos);
      final sin = math.sin(angle);
      from = math.sin((1 - t) * angle) / sin;
      to = math.sin(t * angle) / sin;
    }
    return SphereRotation(
      a.w * from + end.w * to,
      a.x * from + end.x * to,
      a.y * from + end.y * to,
      a.z * from + end.z * to,
    ).normalized();
  }
}

/// A place on the unit sphere: its outward [normal], and the [east] and
/// [north] directions an emoji there is laid along.
@immutable
final class SphereCell {
  const SphereCell({
    required this.normal,
    required this.east,
    required this.north,
    required this.latitude,
    required this.longitude,
  });

  factory SphereCell.at(double latitude, double longitude) {
    final cosLat = math.cos(latitude), sinLat = math.sin(latitude);
    final cosLon = math.cos(longitude), sinLon = math.sin(longitude);
    return SphereCell(
      normal: Vec3(cosLat * sinLon, sinLat, cosLat * cosLon),
      east: Vec3(cosLon, 0, -sinLon),
      north: Vec3(-sinLat * sinLon, cosLat, -sinLat * cosLon),
      latitude: latitude,
      longitude: longitude,
    );
  }

  final Vec3 normal, east, north;
  final double latitude, longitude;
}

/// About [count] cells in rings of latitude, like a globe's grid: each ring
/// holds as many as its circumference fits, alternate rings offset half a
/// step so neighbours sit in a brick pattern.
List<SphereCell> latitudeRings(int count) {
  final rings = math.max(2, (math.sqrt(count * math.pi / 4)).round());
  final step = math.pi / rings;
  return [
    for (var ring = 0; ring < rings; ring++)
      ...() {
        final latitude = math.pi / 2 - step * (ring + .5);
        final slots = math.max(
          1,
          (2 * math.pi * math.cos(latitude) / step).round(),
        );
        final offset = ring.isOdd ? .5 : 0.0;
        return [
          for (var slot = 0; slot < slots; slot++)
            SphereCell.at(latitude, 2 * math.pi * (slot + offset) / slots),
        ];
      }(),
  ];
}

/// The east and north directions for an emoji at [normal] (already turned
/// into view) that keep it upright on screen however the sphere is rolled:
/// north is the surface direction that points straight up the screen, so
/// the emoji still bends with the sphere but never tips over.
(Vec3 east, Vec3 north) uprightFrame(Vec3 normal) {
  // In the surface, at right angles to the screen's x axis.
  var north = Vec3(0, normal.z, -normal.y);
  if (north.length < 1e-6) {
    // Exactly at the left or right rim, edge-on and unseen.
    north = const Vec3(0, 1, 0);
  }
  north = north.normalized();
  return (north.cross(normal), north);
}
