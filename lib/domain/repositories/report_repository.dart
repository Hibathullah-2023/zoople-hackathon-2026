import 'dart:io';
import '../../models/report_model.dart';

/// Agnostic Heat Map point structure.
class HeatMapPoint {
  final double latitude;
  final double longitude;
  final double weight;

  const HeatMapPoint({
    required this.latitude,
    required this.longitude,
    this.weight = 1.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatMapPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          weight == other.weight;

  @override
  int get hashCode => Object.hash(latitude, longitude, weight);
}

/// Interface defining Incident Report operations and Heat Map queries.
abstract class ReportRepository {
  /// Saves a report to Firestore and synchronizes to Realtime Database.
  /// If [imageFile] is provided, it is compressed and uploaded to Storage first.
  Future<void> saveReportSync({required ReportModel report, File? imageFile});

  /// Deletes a report from Firestore, removes from Realtime Database, and deletes Storage media.
  Future<void> deleteReportSync(String reportId);

  /// Retrieves a month's aggregated Heat Map coordinates.
  Future<List<HeatMapPoint>> getMonthlyHeatMapData({
    required int year,
    required int month,
  });
}
