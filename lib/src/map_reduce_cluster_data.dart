import 'cluster_data_base.dart';

/// A cluster data implementation that supports map-reduce functionality
/// similar to the JavaScript supercluster library.
/// 
/// This class stores aggregated properties that result from applying
/// a reduce function to mapped point properties during clustering.
class MapReduceClusterData extends ClusterDataBase {
  /// The aggregated properties data as a dynamic map
  final Map<String, dynamic> properties;

  MapReduceClusterData(this.properties);

  /// Creates an empty MapReduceClusterData
  MapReduceClusterData.empty() : properties = <String, dynamic>{};

  /// Creates a MapReduceClusterData from initial point properties
  factory MapReduceClusterData.fromPointProperties(Map<String, dynamic> pointProperties) {
    return MapReduceClusterData(Map<String, dynamic>.from(pointProperties));
  }

  @override
  MapReduceClusterData combine(covariant MapReduceClusterData other) {
    // Create a new combined properties map
    final combinedProperties = Map<String, dynamic>.from(properties);
    
    // Merge with other properties - this is a simple merge
    // The actual aggregation should be done by the reduce function
    other.properties.forEach((key, value) {
      if (combinedProperties.containsKey(key)) {
        // If both have the same key, we need to combine them
        // For now, we'll use simple addition for numbers, otherwise take the other value
        if (combinedProperties[key] is num && value is num) {
          combinedProperties[key] = (combinedProperties[key] as num) + (value as num);
        } else {
          combinedProperties[key] = value;
        }
      } else {
        combinedProperties[key] = value;
      }
    });
    
    return MapReduceClusterData(combinedProperties);
  }

  /// Creates a copy of this cluster data with updated properties
  MapReduceClusterData copyWith(Map<String, dynamic> newProperties) {
    return MapReduceClusterData(Map<String, dynamic>.from(properties)..addAll(newProperties));
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
          _mapEquals(properties, other.properties);

  @override
  int get hashCode => properties.hashCode;

  /// Helper method to compare two maps for equality
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
