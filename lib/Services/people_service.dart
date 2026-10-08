import 'package:cloud_firestore/cloud_firestore.dart';

class PeopleService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _peopleCol =>
      _db.collection("people");

  Stream<QuerySnapshot<Map<String, dynamic>>> peopleStream() {
    return _peopleCol.orderBy("name").snapshots();
  }

  Future<void> addPerson({
    required String name,
    required double initialValue,
  }) async {
    await _peopleCol.add({
      "name": name,
      "value": initialValue,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePerson(String personId) async {
    final personRef = _peopleCol.doc(personId);
    final movementsSnap = await personRef.collection("movements").get();

    final batch = _db.batch();
    for (final doc in movementsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(personRef);

    await batch.commit();
  }

  Future<void> updatePersonValue({
    required String personId,
    required double newValue,
  }) async {
    await _peopleCol.doc(personId).update({"value": newValue});
  }
}