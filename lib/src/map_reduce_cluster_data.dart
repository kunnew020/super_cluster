import 'cluster_data_base.dart';

/// A cluster data implementation that supports map-reduce functionality
/// similar to the JavaScript supercluster library.
/// 
/// This class stores aggregated properties that result from applying
/// a reduce function to mapped point properties during clustering.
/// 
/// In the JavaScript supercluster:
/// - `map` extracts properties from individual points
/// - `reduce` merges properties when clustering points together
/// 
/// Example from JavaScript:
/// ```javascript
/// const index = new Supercluster({
///     map: (props) => ({sum: props.myValue}),
///     reduce: (accumulated, props) => { accumulated.sum += props.sum; }
/// });
/// ```
/// 
/// Dart equivalent:
/// ```dart
/// final supercluster = SuperclusterImmutable(
///   mapPointToProperties: (point) => {'sum': point.myValue},
///   reduceProperties: (accumulated, props) {
///     accumulated['sum'] = (accumulated['sum'] ?? 0) + (props['sum'] ?? 0);
///   },
/// );
/// ```
class MapReduceClusterData extends ClusterDataBase {
  /// The aggregated properties data as a dynamic map.
  /// This is mutable to allow the reduce function to modify it directly,
  /// matching the JavaScript implementation behavior.
  final Map<String, dynamic> properties;

  /// Optional reduce function to use when combining cluster data.
  /// This should be the same function passed to the Supercluster constructor.
  final void Function(Map<String, dynamic> accumulated, Map<String, dynamic> props)? _reduceFunction;

  MapReduceClusterData(this.properties, [this._reduceFunction]);

  /// Creates an empty MapReduceClusterData
  MapReduceClusterData.empty([void Function(Map<String, dynamic>, Map<String, dynamic>)? reduceFunction]) 
    : properties = <String, dynamic>{},
      _reduceFunction = reduceFunction;

  /// Creates a MapReduceClusterData from initial point properties.
  /// The properties are cloned to avoid mutation of the original.
  factory MapReduceClusterData.fromPointProperties(
    Map<String, dynamic> pointProperties,
    [void Function(Map<String, dynamic>, Map<String, dynamic>)? reduceFunction]
  ) {
    return MapReduceClusterData(Map<String, dynamic>.from(pointProperties), reduceFunction);
  }

  @override
  MapReduceClusterData combine(covariant MapReduceClusterData other) {
    // Create a new accumulated properties map (clone to avoid mutation)
    final accumulated = Map<String, dynamic>.from(properties);
    
    // If a reduce function is provided, use it to merge properties
    // This matches the JavaScript behavior where reduce mutates the accumulated object
    if (_reduceFunction != null) {
      _reduceFunction!(accumulated, other.properties);
    } else {
      // Fallback: simple merge if no reduce function is provided
      // This is for backward compatibility, but ideally reduce should always be provided
      other.properties.forEach((key, value) {
        accumulated[key] = value;
      });
    }
    
    return MapReduceClusterData(accumulated, _reduceFunction);
  }

  /// Creates a copy of this cluster data with updated properties
  MapReduceClusterData copyWith(Map<String, dynamic> newProperties) {
    return MapReduceClusterData(
      Map<String, dynamic>.from(properties)..addAll(newProperties),
      _reduceFunction,
    );
  }

  /// Gets a property value by key
  T? getProperty<T>(String key) {
    return properties[key] as T?;
  }

  /// Sets a property value
  void setProperty(String key, dynamic value) {
    properties[key] = value;
  }

  /// Returns true if this cluster data has no properties
  bool get isEmpty => properties.isEmpty;

  @override
  String toString() => 'MapReduceClusterData($properties)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapReduceClusterData &&
          runtimeType == other.runtimeType &&
          _mapEquals(properties, other.properties) &&
          _reduceFunction == other._reduceFunction;

  @override
  int get hashCode => Object.hash(properties.hashCode, _reduceFunction.hashCode);

  /// Helper method to compare two maps for equality
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
