// lib/utils/text_formatter.dart

import 'package:flutter/material.dart';

List<TextSpan> formatTextWithBold(String? text) {
  if (text == null || text.isEmpty) {
    return [const TextSpan(text: '')];
  }

  final parts = text.split('**');

  // If there's an even number of parts, it means there's an unmatched '**'.
  // We return the original text without formatting.
  if (parts.length % 2 == 0) {
    return [TextSpan(text: text)];
  }

  List<TextSpan> spans = [];
  for (int i = 0; i < parts.length; i++) {
    if (i % 2 != 0) {
      spans.add(
        TextSpan(
          text: parts[i],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      spans.add(TextSpan(text: parts[i]));
    }
  }
  return spans;
}
