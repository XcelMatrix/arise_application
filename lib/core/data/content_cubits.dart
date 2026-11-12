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
