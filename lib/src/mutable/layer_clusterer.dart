import 'package:rbush/rbush.dart';
import 'package:supercluster/src/mutable/boundary_extensions.dart';

import '../cluster_data_base.dart';
import '../map_reduce_cluster_data.dart';
import '../util.dart' as util;
import 'mutable_layer.dart';
import 'mutable_layer_element.dart';

class LayerClusterer<T> {
  final int minPoints;
  final int radius;
  final int extent;
  final ClusterDataBase Function(T point)? extractClusterData;
  final Map<String, dynamic> Function(T point)? mapPointToProperties;
  final void Function(Map<String, dynamic> accumulated, Map<String, dynamic> pointProperties)? reduceProperties;
  final String Function() generateUuid;

  LayerClusterer({
    required this.minPoints,
    required this.radius,
    required this.extent,
    required this.generateUuid,
    this.extractClusterData,
    this.mapPointToProperties,
    this.reduceProperties,
  });

  List<RBushElement<MutableLayerElement<T>>> newClusterElements(
    RBushElement<MutableLayerElement<T>> layerPoint,
    MutableLayer<T> layer,
    MutableLayer<T> childLayer,
  ) {
    final r2 = layer.r2;
    final potentialClusterElements = childLayer
        .search(layerPoint.expandBy(layer.r))
        .where((element) =>
            _closeEnoughToCluster(layerPoint.data, element.data, r2))
        .toList();

    if (potentialClusterElements.fold(
            0, (acc, el) => acc + el.data.numPoints) >=
        minPoints) {
      return potentialClusterElements;
    }
    return [];
  }

  List<RBushElement<MutableLayerElement<T>>> cluster(
    Iterable<RBushElement<MutableLayerElement<T>>> points,
    int zoom,
    MutableLayer<T> layer,
    MutableLayer<T> previousLayer,
  ) {
    final clusters = <RBushElement<MutableLayerElement<T>>>[];

    for (final point in points) {
      final data = point.data;
      // If we've already visited the point at this zoom level, skip it.
      if (data.visitedAtZoom <= zoom) continue;
      data.visitedAtZoom = zoom;

      final neighbors = previousLayer.search(data.paddedBoundary(layer.r));

      final clusterableNeighbors = <MutableLayerElement<T>>[];

      var numPoints = data.numPoints;
      var wx = data.x * data.numPoints;
      var wy = data.y * data.numPoints;

      for (final neighbor in neighbors) {
        var b = neighbor.data;
        // Filter out neighbors that are too far or already processed
        if (zoom < b.visitedAtZoom &&
            _closeEnoughToCluster(data, b, layer.r2)) {
          clusterableNeighbors.add(b);
          numPoints += b.numPoints;
        }
      }

      if (numPoints == data.numPoints || numPoints < minPoints) {
        // No neighbors, add a single point as cluster
        data.lowestZoom = zoom;
        data.parentUuid = null;
        clusters.add(point);
      } else {
        final clusterId = generateUuid();
        ClusterDataBase? clusterData;

        // Handle map-reduce functionality
        Map<String, dynamic>? aggregatedProperties;
        if (mapPointToProperties != null && reduceProperties != null) {
          aggregatedProperties = _getElementProperties(data);
        }

        for (final clusterableNeighbor in clusterableNeighbors) {
          clusterableNeighbor.parentUuid = clusterId;
          clusterableNeighbor.visitedAtZoom =
              zoom; // save the zoom (so it doesn't get processed twice)
          wx += clusterableNeighbor.x * clusterableNeighbor.numPoints;
          wy += clusterableNeighbor.y * clusterableNeighbor.numPoints;

          // Handle legacy cluster data extraction
          if (extractClusterData != null) {
            clusterData ??= _extractClusterData(data);
            clusterData =
                clusterData.combine(_extractClusterData(clusterableNeighbor));
          }

          // Handle map-reduce aggregation
          if (aggregatedProperties != null && reduceProperties != null) {
            final neighborProperties = _getElementProperties(clusterableNeighbor);
            reduceProperties!(aggregatedProperties, neighborProperties);
          }
        }

        // Combine map-reduce data with legacy cluster data if needed
        if (aggregatedProperties != null) {
          final mapReduceData = MapReduceClusterData(aggregatedProperties, reduceProperties);
          clusterData = clusterData?.combine(mapReduceData) ?? mapReduceData;
        }

        // form a cluster with neighbors
        data.parentUuid = clusterId;
        final cluster = MutableLayerElement.initializeCluster<T>(
          uuid: clusterId,
          x: wx / numPoints,
          y: wy / numPoints,
          originX: data.x,
          originY: data.y,
          childPointCount: numPoints,
          zoom: zoom,
          clusterData: clusterData,
        );

        clusters.add(cluster.indexRBushPoint());
      }
    }

    return clusters;
  }

  ClusterDataBase _extractClusterData(MutableLayerElement<T> clusterOrPoint) =>
      switch (clusterOrPoint) {
        MutableLayerCluster<T> cluster => cluster.clusterData!,
        MutableLayerPoint<T> mapPoint =>
          extractClusterData!(mapPoint.originalPoint),
        MutableLayerElement<T>() => throw UnimplementedError(),
      };

  /// Helper method to get properties from a point or cluster element for map-reduce functionality
  Map<String, dynamic> _getElementProperties(MutableLayerElement<T> element) {
    if (mapPointToProperties == null) return <String, dynamic>{};
    
    switch (element) {
      case MutableLayerPoint<T> point:
        return mapPointToProperties!(point.originalPoint);
      case MutableLayerCluster<T> cluster:
        // For clusters, try to get properties from existing MapReduceClusterData
        if (cluster.clusterData is MapReduceClusterData) {
          // Return a COPY of the properties to avoid mutation of the original cluster data
          return Map<String, dynamic>.from((cluster.clusterData as MapReduceClusterData).properties);
        }
        // Fallback to empty properties if no map-reduce data exists
        return <String, dynamic>{};
      default:
        return <String, dynamic>{};
    }
  }

  bool _closeEnoughToCluster(
    MutableLayerElement<T> a,
    MutableLayerElement<T> b,
    double r2,
  ) =>
      util.distSq(a, b) <= r2;
}
