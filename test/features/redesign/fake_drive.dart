import 'dart:convert';

import 'package:attendix/features/redesign/data/import/rd_import_drive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A folder tree in Google Drive as the `werke-import` function answers.
class FakeDrive {
  FakeDrive(this.tree, {this.names = const {}, this.dates = const {}});

  /// Children by folder id.
  final Map<String, List<Map<String, dynamic>>> tree;

  /// Folder names (action `folder`).
  final Map<String, String> names;

  /// File id → PDF content returned by `head`.
  final Map<String, String> dates;
  final calls = <Map<String, dynamic>>[];

  Future<dynamic> call(Map<String, dynamic> body) async {
    calls.add(body);
    final tenantId = body['tenantId'];
    switch (body['action']) {
      case 'folder':
        final id = (body['folder'] as Map)['id'] as String;
        final name = names[id];
        if (name == null) throw const FunctionException(status: 404, details: {'error': 'not_found'});
        return {'id': id, 'name': name};
      case 'list':
        final folders = (body['folders'] as List).cast<Map<String, dynamic>>();
        expect(folders.length, lessThanOrEqualTo(RdDriveApi.maxFolders));
        return {
          'children': {for (final f in folders) f['id']: tree[f['id']] ?? const []},
        };
      case 'head':
        final id = (body['file'] as Map)['id'] as String;
        return {'data': base64Encode(latin1.encode(dates[id] ?? '%PDF')), 'size': 10};
      case 'copy':
        return {'path': 'songs/$tenantId/${body['songId']}/${body['storageName']}'};
    }
    throw StateError('unknown action');
  }
}

Map<String, dynamic> folder(String id, String name) =>
    {'id': id, 'name': name, 'mimeType': 'application/vnd.google-apps.folder'};

Map<String, dynamic> file(String id, String name, {int size = 100, String? md5, String? modified}) => {
      'id': id,
      'name': name,
      'mimeType': name.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream',
      'size': size,
      if (md5 != null) 'md5': md5,
      if (modified != null) 'modifiedTime': modified,
    };

