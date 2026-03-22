import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Asia region Realtime Database URL (required; default US URL causes "Database lives in a different region").
const String _kDatabaseURL = 'https://spotit-62cab-default-rtdb.asia-southeast1.firebasedatabase.app';

/// Realtime Database instance that always uses the Asia URL.
/// Use this instead of [FirebaseDatabase.instance] to avoid region errors.
FirebaseDatabase get firebaseDatabase =>
    FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _kDatabaseURL);

/// Reference to a path in the Asia Realtime Database.
DatabaseReference dbRef(String path) => firebaseDatabase.ref(path);
