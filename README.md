# Supercluster

A very fast point clustering library for Dart, ported and adapted from [MapBox's JavaScript supercluster library](https://github.com/mapbox/supercluster). 

This package contains two very fast point clustering algorithms with support for map-reduce aggregation:

- `SuperclusterImmutable`: A direct port of the original MapBox supercluster library for blazingly fast marker clustering. Points cannot be added/removed after initial load, but clustering is extremely fast.
- `SuperclusterMutable`: An adaptation of the same supercluster library modified to use a mutable underlying index, allowing points to be added/removed dynamically.

Both implementations now support **map-reduce functionality** similar to the JavaScript version, allowing you to aggregate custom properties during clustering (e.g., sum values, count categories, calculate averages).

## Credits

This library is based on the excellent work from:
- **[MapBox Supercluster](https://github.com/mapbox/supercluster)** - The original JavaScript implementation
- **[Vladimir Agafonkin](https://github.com/mourner)** - Creator of the original supercluster algorithm

The Dart port maintains the same high performance characteristics while adding type safety and Dart-specific optimizations.

## Usage

Note: For the sake of these examples the following class is used to represent points on the map:

```dart
class MapPoint {
  String name;
  final double lat;
  final double lon;

  MapPoint({
    required this.name,
    required this.lat,
    required this.lon,
  });

  @override
  String toString() => '"$name" ($lat, $lon)';
}
```

### Supercluster example

```dart
void main() {
  final points = [
    MapPoint(name: 'first', lat: 46, lon: 1.5),
    MapPoint(name: 'second', lat: 46.4, lon: 0.9),
    MapPoint(name: 'third', lat: 45, lon: 19),
  ];
  final supercluster = SuperclusterImmutable<MapPoint>(
    getX: (p) => p.lon,
    getY: (p) => p.lat,
  )
    ..load(points);

  final clustersAndPoints = supercluster.search(0, 40, 20, 50, 5).map(
        (e) =>
        e.map(
          cluster: (cluster) => 'cluster (${cluster.numPoints} points)',
          point: (point) => 'point ${point.originalPoint}',
        ),
  );

  print(clustersAndPoints.join(', '));
  // prints: cluster (2 points), point "third" (45.0, 19.0)
}
```

### SuperclusterMutable example

```dart
void main() {
  final points = [
    MapPoint(name: 'first', lat: 46, lon: 1.5),
    MapPoint(name: 'second', lat: 46.4, lon: 0.9),
    MapPoint(name: 'third', lat: 45, lon: 19),
  ];
  final supercluster = SuperclusterMutable<MapPoint>(
    getX: (p) => p.lon,
    getY: (p) => p.lat,
    extractClusterData: (customMapPoint) =>
        ClusterNameData([customMapPoint.name]),
  )
    ..load(points);

  var clustersAndPoints = supercluster.search(0.0, 40, 20, 50, 5).map(
        (e) =>
        e.map(
          cluster: (cluster) => 'cluster (${cluster.numPoints} points)',
          point: (point) => 'point ${point.originalPoint}',
        ),
  );

  print(clustersAndPoints.join(', '));
  // prints: cluster (2 points), point "third" (45.0, 19.0)

  supercluster.add(MapPoint(name: 'fourth', lat: 45.1, lon: 18));
  supercluster.remove(points[1]);

  clustersAndPoints = supercluster.search(0.0, 40, 20, 50, 5).map(
        (e) =>
        e.map(
            cluster: (cluster) => 'cluster (${cluster.numPoints} points)',
            point: (point) => 'point ${point.originalPoint}'),
  );

  print(clustersAndPoints.join(', '));
  // prints: point "third" (45.0, 19.0), point "fourth" (45.1, 18.0), point "first" (46.0, 1.5)
}
```

### Map-Reduce Aggregation

Both `SuperclusterImmutable` and `SuperclusterMutable` support map-reduce functionality for aggregating custom properties during clustering, similar to the JavaScript version:

```dart
class BusinessPoint {
  final String name;
  final double lat;
  final double lon;
  final int revenue;
  final String category;

  BusinessPoint({
    required this.name,
    required this.lat, 
    required this.lon,
    required this.revenue,
    required this.category,
  });
}

void main() {
  final points = [
    BusinessPoint(name: 'Store A', lat: 46.0, lon: 1.5, revenue: 1000, category: 'retail'),
    BusinessPoint(name: 'Store B', lat: 46.1, lon: 1.4, revenue: 1500, category: 'retail'),
    BusinessPoint(name: 'Restaurant C', lat: 45.9, lon: 1.6, revenue: 800, category: 'food'),
  ];

  final supercluster = SuperclusterImmutable<BusinessPoint>(
    getX: (p) => p.lon,
    getY: (p) => p.lat,
    radius: 50,
    minPoints: 2,
    
    // Map function: extract properties from individual points
    mapPointToProperties: (point) => {
      'total_revenue': point.revenue,
      'count': 1,
      'categories': {point.category: 1},
    },
    
    // Reduce function: aggregate properties when points are clustered
    reduceProperties: (accumulated, pointProperties) {
      accumulated['total_revenue'] = (accumulated['total_revenue'] ?? 0) + 
                                   (pointProperties['total_revenue'] ?? 0);
      accumulated['count'] = (accumulated['count'] ?? 0) + 
                           (pointProperties['count'] ?? 0);
      
      // Merge category counts
      final categories = accumulated['categories'] as Map<String, int>? ?? <String, int>{};
      final pointCategories = pointProperties['categories'] as Map<String, int>? ?? <String, int>{};
      
      for (final entry in pointCategories.entries) {
        categories[entry.key] = (categories[entry.key] ?? 0) + entry.value;
      }
      accumulated['categories'] = categories;
    },
  )..load(points);

  final clusters = supercluster.search(0, 40, 20, 50, 5);
  
  for (final cluster in clusters) {
    cluster.map(
      cluster: (c) {
        if (c.clusterData is MapReduceClusterData) {
          final data = c.clusterData as MapReduceClusterData;
          final avgRevenue = data.properties['total_revenue'] / data.properties['count'];
          print('Cluster: ${c.numPoints} points, avg revenue: \$${avgRevenue.toStringAsFixed(0)}');
          print('Categories: ${data.properties['categories']}');
        }
      },
      point: (p) => print('Individual point: ${p.originalPoint.name}'),
    );
  }
}
```

### Key Features

- **High Performance**: Maintains the same performance characteristics as the original JavaScript library
- **Type Safety**: Full Dart type safety with generic point types
- **Map-Reduce**: Aggregate custom properties during clustering (sum, count, average, etc.)
- **Mutable Operations**: Add/remove points dynamically with `SuperclusterMutable`
- **Flexible Clustering**: Configurable radius, zoom levels, and minimum points per cluster
- **Memory Efficient**: Optimized data structures for minimal memory usage
