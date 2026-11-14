import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Utility class for converting between Quill Delta, HTML, and Document objects.
///
/// Handles four input formats for reading:
/// - Quill Delta JSON array: `[{"insert":"Hello\n"}]`
/// - Quill Delta JSON object: `{"ops":[{"insert":"Hello\n"}]}`
/// - HTML (Ionic app format): `<p>Hello</p>`
/// - Plain text fallback for legacy data
///
/// Always writes as HTML for backward compatibility with the Ionic app.
class QuillUtils {
  QuillUtils._();

  static final _htmlTagRegExp = RegExp(r'<[^>]+>');

  /// Strips HTML tags and decodes common entities to plain text.
  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>|</h[1-6]>'), '\n')
        .replaceAll(_htmlTagRegExp, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Returns true if the string looks like HTML content.
  static bool _isHtml(String text) {
    return text.trimLeft().startsWith('<') && _htmlTagRegExp.hasMatch(text);
  }

  /// Creates a [Document] from a notes string stored in the database.
  ///
  /// Supports:
  /// - `null` or empty → empty Document
  /// - JSON array `[{"insert":"..."}]` → Quill Delta
  /// - JSON object `{"ops":[...]}` → Quill Delta
  /// - HTML → converted to Quill Delta (preserving formatting)
  /// - Plain text → Document with text content
  ///
  /// [separateParagraphs] (OEFF-12): `HtmlToDelta` joins consecutive `<p>`
  /// elements into one line ("…de</p><p>Quelle…" → "…deQuelle…"); with
  /// `true` every `<p>` ends its own line, like a browser renders it.
  static Document documentFromNotesString(String? notes,
      {bool separateParagraphs = false}) {
    if (notes == null || notes.trim().isEmpty) {
      return Document();
    }

    try {
      final trimmed = notes.trim();
      final decoded = jsonDecode(trimmed);

      if (decoded is List) {
        // Array form: [{"insert":"Hello\n"}]
        return Document.fromJson(decoded.cast<Map<String, dynamic>>());
      } else if (decoded is Map) {
        // Object form: {"ops":[{"insert":"Hello\n"}]}
        final ops = decoded['ops'];
        if (ops is List) {
          return Document.fromJson(ops.cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {
      // Not valid JSON — check for HTML or treat as plain text
    }

    // HTML → Quill Delta (preserves formatting like bold, lists, headers)
    if (_isHtml(notes)) {
      try {
        final delta = HtmlToDelta(
          shouldInsertANewLine:
              separateParagraphs ? (name) => name == 'p' : null,
        ).convert(notes);
        return Document.fromDelta(delta);
      } catch (_) {
        // Fallback: strip HTML to plain text
        final plainText = stripHtml(notes);
        if (plainText.isEmpty) return Document();
        return Document()..insert(0, plainText);
      }
    }

    // Plain text fallback
    return Document()..insert(0, notes);
  }

  /// Serializes a [Document] to HTML for database storage.
  ///
  /// Returns HTML string compatible with the Ionic app,
  /// or `null` if the document is empty.
  static String? notesHtmlFromDocument(Document doc) {
    if (isDocumentEmpty(doc)) return null;
    final deltaJson = doc.toDelta().toJson();
    final ops = deltaJson.cast<Map<String, dynamic>>();
    final converter = QuillDeltaToHtmlConverter(ops);
    return converter.convert();
  }

  /// Serializes a [Document] back to a JSON string for database storage.
  ///
  /// Returns the ops array as a JSON string (compatible with quill.js),
  /// or `null` if the document is empty.
  @Deprecated('Use notesHtmlFromDocument for backward compatibility with Ionic')
  static String? notesStringFromDocument(Document doc) {
    if (isDocumentEmpty(doc)) return null;
    return jsonEncode(doc.toDelta().toJson());
  }

  /// Checks whether a [Document] is effectively empty (only contains a newline).
  static bool isDocumentEmpty(Document doc) {
    final delta = doc.toDelta();
    if (delta.isEmpty) return true;
    // A "blank" Quill document has exactly one insert op with just "\n"
    if (delta.length == 1) {
      final op = delta.first;
      if (op.isInsert && op.data == '\n') return true;
    }
    return false;
  }
}
