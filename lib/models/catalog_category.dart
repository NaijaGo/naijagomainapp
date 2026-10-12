import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Version 1 preserves the existing labels and IDs. Unsupported or corrupt
/// responses are rejected instead of silently replacing the client's taxonomy.
class CatalogHierarchy {
  final Map<String, dynamic> _data;
  final bool referencesReady;
  final String checksum;
  CatalogHierarchy._(this._data, this.referencesReady, this.checksum);

  factory CatalogHierarchy.fromJson(Map<String, dynamic> data) {
    final manifest = <String, dynamic>{
      'version': data['version'],
      'parentAliases': data['parentAliases'],
      'childAliases': data['childAliases'],
      'categories': data['categories'],
    };
    final checksum = sha256
        .convert(utf8.encode(jsonEncode(manifest)))
        .toString();
    if (data['version'] != 1 ||
        data['checksum'] != checksum ||
        data['parentAliases'] is! List ||
        data['childAliases'] is! Map ||
        data['categories'] is! List ||
        (data['categories'] as List).length != 23) {
      throw const FormatException('Invalid category hierarchy');
    }
    final ids = <String>{}, keys = <String>{}, labels = <String>{};
    var children = 0;
    void validate(dynamic node, int index, String? parentId) {
      if (node is! Map ||
          node['id'] is! String ||
          !RegExp(r'^[a-f0-9]{24}$').hasMatch(node['id'] as String) ||
          !ids.add(node['id'] as String) ||
          node['key'] is! String ||
          !keys.add(node['key'] as String) ||
          node['label'] is! String ||
          (node['label'] as String).trim().isEmpty ||
          node['sortOrder'] != index ||
          (parentId != null && node['parentId'] != parentId)) {
        throw const FormatException('Invalid category identity');
      }
    }

    final parents = data['categories'] as List;
    for (var i = 0; i < parents.length; i++) {
      final parent = parents[i];
      validate(parent, i, null);
      if (!labels.add(parent['label'] as String) ||
          parent['children'] is! List) {
        throw const FormatException('Invalid category labels');
      }
      final childLabels = <String>{};
      final entries = parent['children'] as List;
      for (var j = 0; j < entries.length; j++) {
        validate(entries[j], j, parent['id'] as String);
        if (!childLabels.add(entries[j]['label'] as String)) {
          throw const FormatException('Duplicate subcategory');
        }
        children++;
      }
    }
    if (children != 186) {
      throw const FormatException('Incomplete category hierarchy');
    }
    return CatalogHierarchy._(
      manifest,
      data['referencesReady'] == true,
      checksum,
    );
  }

  CatalogHierarchy withoutReferenceWrites() =>
      CatalogHierarchy._(_data, false, checksum);
  Map<String, dynamic> toJson() => {
    ..._data,
    'checksum': checksum,
    'referencesReady': referencesReady,
  };

  Map<String, List<String>> categoryMap({bool includeRestaurant = true}) => {
    for (final parent in _data['categories'] as List)
      if (includeRestaurant || parent['label'] != 'Restaurant')
        parent['label'] as String: [
          for (final child in parent['children'] as List)
            child['label'] as String,
        ],
  };

  Map<String, String> referencesFor(
    String category, [
    String subcategory = '',
  ]) {
    if (!referencesReady) return {};
    String normalize(dynamic value) => value.toString().trim().toLowerCase();
    final parts = category.split('>').map((value) => value.trim()).toList();
    if (parts.length > 2) {
      return {};
    }
    Map? parent;
    for (final node in _data['categories'] as List) {
      final aliases = (_data['parentAliases'] as List).where(
        (group) => normalize(group[0]) == normalize(node['label']),
      );
      if (normalize(node['label']) == normalize(parts[0]) ||
          aliases.any(
            (group) => (group as List).any(
              (label) => normalize(label) == normalize(parts[0]),
            ),
          )) {
        parent = node as Map;
        break;
      }
    }
    if (parent == null) return {};
    final childLabel = subcategory.isNotEmpty
        ? subcategory
        : (parts.length == 2 ? parts[1] : '');
    final result = {'categoryId': parent['id'] as String};
    if (childLabel.isEmpty) return result;
    final aliases =
        (_data['childAliases'] as Map)[normalize(parent['label'])] as List? ??
        [];
    for (final child in parent['children'] as List) {
      if (normalize(child['label']) == normalize(childLabel) ||
          aliases.any(
            (group) =>
                normalize(group[0]) == normalize(child['label']) &&
                (group as List).any(
                  (label) => normalize(label) == normalize(childLabel),
                ),
          )) {
        if (parts.length == 2 && subcategory.isNotEmpty) {
          final combined = referencesFor(parts[0], parts[1]);
          if (combined['subcategoryId'] != child['id']) return {};
        }
        return {...result, 'subcategoryId': child['id'] as String};
      }
    }
    return {};
  }
}
