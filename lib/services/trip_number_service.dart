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
    // Format: YYYY-DD-MM (year-day-month)
    return '$year-$day-$month';
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
    final counterRef =
        firestore.collection(tripCountersCollection).doc(dateKey);
    final counterSnap = await transaction.get(counterRef);
    final counterData = counterSnap.data();
    final currentSequence =
        (counterData?['lastSequence'] as num?)?.toInt() ?? 0;
    final nextSequence = currentSequence + 1;

    transaction.set(
        counterRef,
        {
          'dateKey': dateKey,
          'lastSequence': nextSequence,
          if (!counterSnap.exists) 'createdAt': date.millisecondsSinceEpoch,
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
