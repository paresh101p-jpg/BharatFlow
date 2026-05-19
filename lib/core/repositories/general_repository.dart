import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class GeneralRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getTableData(String table, {String? orderBy, bool ascending = false}) async {
    try {
      dynamic query = _supabase.from(table).select();
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }
      final data = await query;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Fetch $table Error: $e');
      return [];
    }
  }

  Future<bool> insertData(String table, Map<String, dynamic> data) async {
    try {
      await _supabase.from(table).insert(data);
      return true;
    } catch (e) {
      print('Insert $table Error: $e');
      return false;
    }
  }

  Future<bool> updateData(String table, String idField, dynamic idValue, Map<String, dynamic> data) async {
    try {
      await _supabase.from(table).update(data).eq(idField, idValue);
      return true;
    } catch (e) {
      print('Update $table Error: $e');
      return false;
    }
  }

  Future<bool> deleteData(String table, String idField, dynamic idValue) async {
    try {
      await _supabase.from(table).delete().eq(idField, idValue);
      return true;
    } catch (e) {
      print('Delete $table Error: $e');
      return false;
    }
  }

  Future<String?> uploadFile(String bucket, String path, File file) async {
    try {
      final String fullPath = await _supabase.storage.from(bucket).upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }
}
