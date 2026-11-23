/// One thing to check after a drill.
class AssessmentItem {
  const AssessmentItem(this.key, this.label);
  final String key;
  final String label; // English; translated on screen
}

/// The checklist teachers and admins fill in after a drill.
const assessmentItems = <AssessmentItem>[
  AssessmentItem('alarm', 'The alarm was heard clearly'),
  AssessmentItem('response', 'Students stopped and followed their teacher'),
  AssessmentItem('route', 'Students used the correct route and exits'),
  AssessmentItem('orderly', 'The evacuation was calm and orderly'),
  AssessmentItem('assembly', 'Everyone reached the assembly area'),
  AssessmentItem('headcount', 'The headcount was quick and correct'),
  AssessmentItem('reports', 'Every class sent its attendance report'),
  AssessmentItem('assist', 'Students who needed help were assisted'),
  AssessmentItem('time', 'The evacuation finished within the target time'),
];

/// 2 = yes, 1 = partly, 0 = no
class DrillAssessment {
  DrillAssessment(this.drillId, this.answers, this.notes, this.assessedAt);

  final String drillId;
  final Map<String, int> answers;
  final String notes;
  final DateTime? assessedAt;

  factory DrillAssessment.fromRow(Map<String, dynamic> r) {
    final raw = r['answers'];
    return DrillAssessment(
      r['drill_id'] as String,
      {
        if (raw is Map)
          for (final e in raw.entries)
            '${e.key}': (e.value is num) ? (e.value as num).toInt() : 0,
      },
      '${r['notes'] ?? ''}',
      DateTime.tryParse('${r['assessed_at']}')?.toLocal(),
    );
  }

  /// 0 - 100, over the items that were answered
  int get score {
    final given = [
      for (final i in assessmentItems)
        if (answers.containsKey(i.key)) answers[i.key]!.clamp(0, 2),
    ];
    if (given.isEmpty) return 0;
    return (given.fold<int>(0, (a, b) => a + b) * 100 / (given.length * 2))
        .round();
  }

  String get rating => ratingFor(score);

  static String ratingFor(int score) => score >= 90
      ? 'Excellent'
      : score >= 75
          ? 'Good'
          : score >= 60
              ? 'Satisfactory'
              : 'Needs improvement';
}
