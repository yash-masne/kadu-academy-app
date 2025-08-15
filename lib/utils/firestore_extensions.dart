// File: lib/utils/firestore_extensions.dart

import 'package:cloud_firestore/cloud_firestore.dart';

extension QueryExtension<T> on Query<T> {
  Query<T> when(
    bool condition,
    Query<T> Function(Query<T> query) queryBuilder,
  ) {
    if (condition) {
      return queryBuilder(this);
    }
    return this;
  }
}
