import 'package:arise_application/core/data/rows_cubit.dart';

class GuidelinesCubit extends RowsCubit {
  GuidelinesCubit() : super('guidelines', orderBy: ['sort_order', 'title']);
}

class ContactsCubit extends RowsCubit {
  ContactsCubit()
      : super('emergency_contacts', orderBy: ['sort_order', 'name']);
}

/// Each teacher's own saved class lists.
class ClassListsCubit extends RowsCubit {
  ClassListsCubit()
      : super('class_lists', orderBy: ['name'], perUser: true);
}

/// Uploaded evacuation maps (3D models and 2D images).
class MapsCubit extends RowsCubit {
  MapsCubit() : super('evacuation_maps', orderBy: ['created_at']);
}

/// Every emergency alert ever sent (newest first), for the console.
class AlertLogCubit extends RowsCubit {
  AlertLogCubit()
      : super('emergency_alerts', orderBy: ['created_at'], ascending: false);
}

/// Buildings that have their own evacuation maps.
class BuildingsCubit extends RowsCubit {
  BuildingsCubit() : super('map_buildings', orderBy: ['sort_order', 'name']);
}

/// Exit / assembly / extinguisher ... markers placed on the maps.
class MarkersCubit extends RowsCubit {
  MarkersCubit() : super('map_markers', orderBy: ['created_at']);
}

/// The Before / During / After steps of each disaster guideline (with icons).
class GuidelineItemsCubit extends RowsCubit {
  GuidelineItemsCubit() : super('guideline_items', orderBy: ['sort_order']);

  /// the steps of one guideline, in order
  List<Map<String, dynamic>> of(String guidelineId) {
    final rows = [
      for (final r in state.rows)
        if (r['guideline_id'] == guidelineId) r
    ];
    rows.sort((a, b) => ((a['sort_order'] as num?) ?? 0)
        .compareTo((b['sort_order'] as num?) ?? 0));
    return rows;
  }

  /// Adds a step so that it ends up at [index] in its guideline.
  Future<void> insertAt(
      String guidelineId, int index, Map<String, dynamic> values) async {
    final id = await insertRow({...values, 'guideline_id': guidelineId});
    final ids = [for (final r in of(guidelineId)) r['id'] as String];
    ids.insert(index.clamp(0, ids.length), id);
    await reorder(ids);
  }
}

/// Groups of guidelines ("Emergency guides", "Disasters", ...), editable.
class GuidelineCategoriesCubit extends RowsCubit {
  GuidelineCategoriesCubit()
      : super('guideline_categories', orderBy: ['sort_order', 'name']);
}
