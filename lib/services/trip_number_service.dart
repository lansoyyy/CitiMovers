import 'package:cloud_firestore/cloud_firestore.dart';

class TripNumberAllocation {
  final String dateKey;
  final int sequence;
  final String tripNumber;

  const TripNumberAllocation({
    required this.dateKey,
    required this.sequence,
    required this.tripNumber,
  });
}

class TripNumberService {
  static const String tripCountersCollection = 'trip_counters';

  String buildDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    // Format: YYYY-MMDD
    return '$year-$month$day';
  }

  List<String> buildLegacyDateKeys(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return [
      '$year-$month-$day',
      '$year-$day-$month',
    ];
  }

  String buildTripNumber(DateTime date, int sequence) {
    return '${buildDateKey(date)}-${sequence.toString().padLeft(5, '0')}';
  }

  Future<TripNumberAllocation> allocateTripNumber({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required DateTime date,
  }) async {
    final dateKey = buildDateKey(date);
    final counterCollection = firestore.collection(tripCountersCollection);
    final counterRef = counterCollection.doc(dateKey);
    final legacyRefs = buildLegacyDateKeys(date)
        .where((legacyKey) => legacyKey != dateKey)
        .toSet()
        .map(counterCollection.doc)
        .toList();
    final refs = [counterRef, ...legacyRefs];
    final snaps = await Future.wait(refs.map(transaction.get));

    var currentSequence = 0;
    var canonicalExists = false;

    for (var i = 0; i < refs.length; i++) {
      final data = snaps[i].data();
      final sequence = (data?['lastSequence'] as num?)?.toInt() ?? 0;
      if (sequence > currentSequence) {
        currentSequence = sequence;
      }
      if (refs[i].id == dateKey) {
        canonicalExists = snaps[i].exists;
      }
    }

    final nextSequence = currentSequence + 1;

    transaction.set(
        counterRef,
        {
          'dateKey': dateKey,
          'lastSequence': nextSequence,
          if (!canonicalExists) 'createdAt': date.millisecondsSinceEpoch,
          'updatedAt': date.millisecondsSinceEpoch,
        },
        SetOptions(merge: true));

    return TripNumberAllocation(
      dateKey: dateKey,
      sequence: nextSequence,
      tripNumber: buildTripNumber(date, nextSequence),
    );
  }
}
