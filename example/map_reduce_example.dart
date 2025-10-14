import 'package:supercluster/supercluster.dart';

/// Example point class with properties for aggregation
class ExamplePoint {
  final double lat;
  final double lng;
  final int value;  // A numeric property to aggregate
  final String category;  // A categorical property
  final Map<String, dynamic> metadata;  // Additional metadata

  ExamplePoint({
    required this.lat,
    required this.lng,
    required this.value,
    required this.category,
    this.metadata = const {},
  });

  @override
  String toString() => 'ExamplePoint(lat: $lat, lng: $lng, value: $value, category: $category)';
}

/// Example demonstrating map-reduce functionality similar to JavaScript supercluster
void main() {
  print('=== Supercluster Dart Map-Reduce Example ===\n');

  // Create sample points with properties to aggregate
  final points = [
    ExamplePoint(lat: 37.7749, lng: -122.4194, value: 100, category: 'retail', metadata: {'store_type': 'electronics'}),
    ExamplePoint(lat: 37.7849, lng: -122.4094, value: 150, category: 'retail', metadata: {'store_type': 'clothing'}),
    ExamplePoint(lat: 37.7649, lng: -122.4294, value: 200, category: 'restaurant', metadata: {'cuisine': 'italian'}),
    ExamplePoint(lat: 37.7549, lng: -122.4394, value: 75, category: 'restaurant', metadata: {'cuisine': 'asian'}),
    ExamplePoint(lat: 37.7449, lng: -122.4494, value: 125, category: 'retail', metadata: {'store_type': 'books'}),
    ExamplePoint(lat: 40.7128, lng: -74.0060, value: 300, category: 'retail', metadata: {'store_type': 'electronics'}),
    ExamplePoint(lat: 40.7228, lng: -73.9960, value: 250, category: 'restaurant', metadata: {'cuisine': 'american'}),
  ];

  print('Input points:');
  for (final point in points) {
    print('  $point');
  }
  print();

  // Example 1: Simple aggregation - sum values by category
  print('=== Example 1: Simple Value Aggregation ===');
  final supercluster1 = SuperclusterImmutable<ExamplePoint>(
    getX: (point) => point.lng,
    getY: (point) => point.lat,
    radius: 100,
    minPoints: 2,
    maxZoom: 16,
    // Map function: extract properties from individual points
    mapPointToProperties: (point) => {
      'sum': point.value,
      'count': 1,
      'categories': {point.category: 1},
      'max_value': point.value,
      'min_value': point.value,
    },
    // Reduce function: aggregate properties when clustering
    reduceProperties: (accumulated, pointProperties) {
      accumulated['sum'] = (accumulated['sum'] ?? 0) + (pointProperties['sum'] ?? 0);
      accumulated['count'] = (accumulated['count'] ?? 0) + (pointProperties['count'] ?? 0);
      accumulated['max_value'] = [accumulated['max_value'] ?? 0, pointProperties['max_value'] ?? 0].reduce((a, b) => a > b ? a : b);
      accumulated['min_value'] = [accumulated['min_value'] ?? double.infinity, pointProperties['min_value'] ?? double.infinity].reduce((a, b) => a < b ? a : b);
      
      // Aggregate categories
      final categories = accumulated['categories'] as Map<String, int>? ?? <String, int>{};
      final pointCategories = pointProperties['categories'] as Map<String, int>? ?? <String, int>{};
      
      for (final entry in pointCategories.entries) {
        categories[entry.key] = (categories[entry.key] ?? 0) + entry.value;
      }
      accumulated['categories'] = categories;
    },
  );

  supercluster1.load(points);

  // Search for clusters in San Francisco area (contains multiple points that should cluster)
  final sfClusters = supercluster1.search(-122.5, 37.7, -122.3, 37.8, 10);
  
  print('Clusters in San Francisco area (zoom 10):');
  for (final cluster in sfClusters) {
    if (cluster is ImmutableLayerCluster<ExamplePoint>) {
      final clusterData = cluster.clusterData;
      if (clusterData is MapReduceClusterData) {
        print('  Cluster at (${cluster.x.toStringAsFixed(4)}, ${cluster.y.toStringAsFixed(4)}):');
        print('    Points: ${cluster.numPoints}');
        print('    Total Value: ${clusterData.properties['sum']}');
        print('    Count: ${clusterData.properties['count']}');
        print('    Average Value: ${(clusterData.properties['sum'] / clusterData.properties['count']).toStringAsFixed(2)}');
        print('    Max Value: ${clusterData.properties['max_value']}');
        print('    Min Value: ${clusterData.properties['min_value']}');
        print('    Categories: ${clusterData.properties['categories']}');
      }
    } else if (cluster is ImmutableLayerPoint<ExamplePoint>) {
      print('  Individual Point: ${cluster.originalPoint}');
    }
    print();
  }

  // Example 2: Using SuperclusterMutable with map-reduce
  print('=== Example 2: Mutable Supercluster with Map-Reduce ===');
  final supercluster2 = SuperclusterMutable<ExamplePoint>(
    getX: (point) => point.lng,
    getY: (point) => point.lat,
    radius: 80,
    minPoints: 2,
    maxZoom: 16,
    // Map function: extract different properties
    mapPointToProperties: (point) => {
      'total_value': point.value,
      'point_count': 1,
      'avg_value': point.value.toDouble(),
      point.category: 1,  // Count by category as separate properties
    },
    // Reduce function: custom aggregation logic
    reduceProperties: (accumulated, pointProperties) {
      final oldCount = accumulated['point_count'] as int? ?? 0;
      final newCount = oldCount + (pointProperties['point_count'] as int? ?? 0);
      
      // Update totals
      accumulated['total_value'] = (accumulated['total_value'] ?? 0) + (pointProperties['total_value'] ?? 0);
      accumulated['point_count'] = newCount;
      
      // Calculate running average
      if (newCount > 0) {
        accumulated['avg_value'] = (accumulated['total_value'] as num) / newCount;
      }
      
      // Aggregate category counts
      for (final key in pointProperties.keys) {
        if (key != 'total_value' && key != 'point_count' && key != 'avg_value') {
          accumulated[key] = (accumulated[key] ?? 0) + (pointProperties[key] ?? 0);
        }
      }
    },
  );

  supercluster2.load(points);

  // Add a new point dynamically
  final newPoint = ExamplePoint(lat: 37.7650, lng: -122.4190, value: 180, category: 'retail', metadata: {'store_type': 'grocery'});
  print('Adding new point: $newPoint');
  supercluster2.add(newPoint);

  // Search again to see updated clusters
  final updatedClusters = supercluster2.search(-122.5, 37.7, -122.3, 37.8, 10);
  
  print('\\nUpdated clusters after adding new point:');
  for (final cluster in updatedClusters) {
    if (cluster is MutableLayerCluster<ExamplePoint>) {
      final clusterData = cluster.clusterData;
      if (clusterData is MapReduceClusterData) {
        print('  Cluster at (${cluster.x.toStringAsFixed(4)}, ${cluster.y.toStringAsFixed(4)}):');
        print('    Points: ${cluster.numPoints}');
        print('    Total Value: ${clusterData.properties['total_value']}');
        print('    Average Value: ${(clusterData.properties['avg_value'] as double).toStringAsFixed(2)}');
        
        // Show category counts
        final categoryKeys = clusterData.properties.keys.where((key) => 
          key != 'total_value' && key != 'point_count' && key != 'avg_value').toList();
        
        if (categoryKeys.isNotEmpty) {
          print('    Category breakdown:');
          for (final category in categoryKeys) {
            print('      $category: ${clusterData.properties[category]}');
          }
        }
      }
    } else if (cluster is MutableLayerPoint<ExamplePoint>) {
      print('  Individual Point: ${cluster.originalPoint}');
    }
    print();
  }

  // Example 3: Advanced usage - metadata aggregation
  print('=== Example 3: Metadata Aggregation ===');
  final supercluster3 = SuperclusterImmutable<ExamplePoint>(
    getX: (point) => point.lng,
    getY: (point) => point.lat,
    radius: 120,
    minPoints: 2,
    maxZoom: 16,
    mapPointToProperties: (point) => {
      'count': 1,
      'metadata_keys': point.metadata.keys.toList(),
      'metadata_values': point.metadata,
    },
    reduceProperties: (accumulated, pointProperties) {
      accumulated['count'] = (accumulated['count'] ?? 0) + (pointProperties['count'] ?? 0);
      
      // Merge metadata keys
      final existingKeys = accumulated['metadata_keys'] as List<dynamic>? ?? <dynamic>[];
      final newKeys = pointProperties['metadata_keys'] as List<dynamic>? ?? <dynamic>[];
      final allKeys = {...existingKeys, ...newKeys}.toList();
      accumulated['metadata_keys'] = allKeys;
      
      // Merge metadata values
      final existingMetadata = accumulated['metadata_values'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final newMetadata = pointProperties['metadata_values'] as Map<String, dynamic>? ?? <String, dynamic>{};
      
      // Create a combined metadata map with counts for each value
      for (final entry in newMetadata.entries) {
        final key = '${entry.key}_${entry.value}';
        existingMetadata[key] = (existingMetadata[key] ?? 0) + 1;
      }
      accumulated['metadata_values'] = existingMetadata;
    },
  );

  supercluster3.load(points);
  final metadataClusters = supercluster3.search(-122.5, 37.7, -122.3, 37.8, 10);
  
  print('Clusters with metadata aggregation:');
  for (final cluster in metadataClusters) {
    if (cluster is ImmutableLayerCluster<ExamplePoint>) {
      final clusterData = cluster.clusterData;
      if (clusterData is MapReduceClusterData) {
        print('  Cluster with ${cluster.numPoints} points:');
        print('    Metadata distribution: ${clusterData.properties['metadata_values']}');
      }
    }
    print();
  }

  print('=== Map-Reduce Example Complete ===');
}
