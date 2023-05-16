import 'package:flutter/foundation.dart';
import 'package:osm_api/osm_api.dart';

import '/models/element_variants/base_element.dart';

/// This class is used to created [ProcessedElement]s from an [OSMElementBundle].
///
/// It adds any cross references to the elements and calculates their geometries.
///
/// Elements whose geometry could not be calculated will **not be included**.

class OSMElementProcessor {
  /// Nodes mapped to id for faster look up
  final _nodesLookUp = <int, ProcessedNode>{};
  /// Ways mapped to id for faster look up
  final _waysLookUp = <int, ProcessedWay>{};
  /// Relations mapped to id for faster look up
  final _relationsLookUp = <int, ProcessedRelation>{};

  OSMElementProcessor([ OSMElementBundle? elements ]) {
    if(elements != null) add(elements);
  }

  /// Returns all processed elements.

  Iterable<ProcessedElement> get elements sync* {
    yield* _nodesLookUp.values;
    yield* _waysLookUp.values;
    yield* _relationsLookUp.values;
  }

  /// Add and process elements.
  /// Already existing element will be discarded.
  ///
  /// Elements whose geometry could not be calculated will **not be included**.
  ///
  /// Returns all newly added elements.

  Iterable<ProcessedElement> add(OSMElementBundle elements) sync* {
    // convert to list so lazy iterable is evaluated
    final newNodes = _addNodes(elements.nodes)
      .toList(growable: false);
    final newWays = _addWays(elements.ways)
      .toList(growable: false);
    final newRelations = _addRelations(elements.relations)
      .toList(growable: false);
    // resolve references AFTER all elements have been added
    _resolveWays(newWays);
    _resolveRelations(newRelations);
    // geometry calculation depends on parent/children assignment
    // due to inner dependencies first process nodes, then ways and then relations
    // also remove any elements where geometry calculation failed
    _calcGeometries(newNodes)
      .forEach((e) => _nodesLookUp.remove(e.id));
    _calcGeometries(newWays)
      .forEach((e) => _waysLookUp.remove(e.id));
    _calcGeometries(newRelations)
      .forEach((e) => _relationsLookUp.remove(e.id));

    yield* newNodes; yield* newWays; yield* newRelations;
  }

  /// Fast way to get an element by it's type and id.

  ProcessedElement? find(OSMElementType type, int id) {
    switch (type) {
      case OSMElementType.node:
        return _nodesLookUp[id];
      case OSMElementType.way:
        return _waysLookUp[id];
      case OSMElementType.relation:
        return _relationsLookUp[id];
    }
  }

  /// Convert and add nodes **lazily** if not already existing.
  ///
  /// Returns all newly added nodes.

  Iterable<ProcessedNode> _addNodes(Iterable<OSMNode> nodes) sync* {
    for (final node in nodes) {
      var isNew = false;
      final pNode = _nodesLookUp.putIfAbsent(node.id, () {
        isNew = true;
        return ProcessedNode(node);
      });
      if (isNew) yield pNode;
    }
  }

  /// Convert and add ways **lazily** if not already existing.
  ///
  /// Returns all newly added ways.

  Iterable<ProcessedWay> _addWays(Iterable<OSMWay> ways) sync* {
    for (final way in ways) {
      var isNew = false;
      final pWay = _waysLookUp.putIfAbsent(way.id, () {
        isNew = true;
        return ProcessedWay(way);
      });
      if (isNew) yield pWay;
    }
  }

  /// Convert and add relations **lazily** if not already existing.
  ///
  /// Returns all newly added relations.

  Iterable<ProcessedRelation> _addRelations(Iterable<OSMRelation> relations) sync* {
    for (final relation in relations) {
      var isNew = false;
      final pRelation = _relationsLookUp.putIfAbsent(relation.id, () {
        isNew = true;
        return ProcessedRelation(relation);
      });
      if (isNew) yield pRelation;
    }
  }

  /// Assigns all available children per way.

  void _resolveWays(Iterable<ProcessedWay> ways) {
    for (final pWay in ways) {
      for (final nodeId in pWay.nodeIds) {
        final pNode = _nodesLookUp[nodeId]!;
        pWay.addChild(pNode);
      }
    }
  }

  /// Assigns all available children per relation.

  void _resolveRelations(Iterable<ProcessedRelation> relations) {
    for (final pRelation in relations) {
      for (final member in pRelation.members) {
        final child = find(member.type, member.ref);
        // relations my reference objects that are not present in the bundle
        if (child != null) pRelation.addChild(child as ChildElement);
      }
    }
  }

  /// Lazily calculates the geometry for every element.
  ///
  /// Return all elements whose geometry calculation failed.

  Iterable<T> _calcGeometries<T extends ProcessedElement>(Iterable<T> elements) sync* {
    for (final element in elements) {
      try {
        element.calcGeometry();
      }
      // catch geometry calculation errors
      catch(e) {
        debugPrint(e.toString());
        yield element;
      }
    }
  }
}
