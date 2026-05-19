import 'package:flutter/material.dart';

class CommodityUtils {
  static String getImageUrl(String commodity) {
    final lower = commodity.toLowerCase();
    if (lower.contains('wheat') || lower.contains('gehun') || lower.contains('ghav')) {
      return 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('onion') || lower.contains('dungali') || lower.contains('pyaaz')) {
      return 'https://images.unsplash.com/photo-1508747703725-719777637510?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('tomato') || lower.contains('tameta') || lower.contains('tamatar')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('potato') || lower.contains('aloo') || lower.contains('batata')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('cotton') || lower.contains('kapas')) {
      return 'https://images.unsplash.com/photo-1594904351111-a072f80b1a71?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('mustard') || lower.contains('sarson') || lower.contains('rai')) {
      return 'https://images.unsplash.com/photo-1530537021313-0579e0a07e15?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('soyabean')) {
      return 'https://images.unsplash.com/photo-1591871937573-74dbba515c4c?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('rice') || lower.contains('chokha') || lower.contains('chawal')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('maize') || lower.contains('makai')) {
      return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('garlic') || lower.contains('lasun')) {
      return 'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('ginger') || lower.contains('adrak')) {
      return 'https://images.unsplash.com/photo-1615485500704-a1a90f484c60?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('chili') || lower.contains('mirch')) {
      return 'https://images.unsplash.com/photo-1588253584673-c7012000ff9f?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('apple') || lower.contains('seb')) {
      return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6bccb?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('banana') || lower.contains('kela')) {
      return 'https://images.unsplash.com/photo-1571771894821-ad99024177c6?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('lemon') || lower.contains('nimbu')) {
      return 'https://images.unsplash.com/photo-1587411768538-ef461ec7d18c?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('mango') || lower.contains('aam')) {
      return 'https://images.unsplash.com/photo-1553279768-865429fa0078?q=80&w=500&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?q=80&w=500&auto=format&fit=crop';
  }

  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'up':
      case 'bullish':
        return Colors.green;
      case 'down':
      case 'bearish':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Universal date parser — supports ISO, YYYY-MM-DD, and DD/MM/YYYY
  static DateTime? _parseAnyDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    try {
      // ISO Format (Full timestamp)
      if (dateStr.contains('T')) return DateTime.parse(dateStr);

      // YYYY-MM-DD format (Supabase)
      if (dateStr.length >= 10 && dateStr[4] == '-') {
        return DateTime.parse(dateStr.substring(0, 10));
      }
      
      // DD/MM/YYYY or DD-MM-YYYY format
      final parts = dateStr.contains('/') ? dateStr.split('/') : dateStr.split('-');
      if (parts.length == 3) {
        int day = int.tryParse(parts[0]) ?? 0;
        int month = int.tryParse(parts[1]) ?? 0;
        int year = int.tryParse(parts[2]) ?? 0;
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  static String getFormattedDateTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'No Date';
    final date = _parseAnyDate(timestamp);
    if (date == null) return 'Recently';
    final months = ['May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr']; // Simple month list
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  static String getFullDateTime(String? timestamp, [String? syncTimestamp]) {
    if (timestamp == null || timestamp.isEmpty) return 'Recently';
    var date = _parseAnyDate(timestamp);
    if (date == null) return 'Recently';

    // If time is missing (00:00) and we have a sync timestamp, use the time from sync_at
    if (date.hour == 0 && date.minute == 0 && syncTimestamp != null && syncTimestamp.isNotEmpty) {
      final sDate = _parseAnyDate(syncTimestamp);
      if (sDate != null) {
        date = DateTime(date.year, date.month, date.day, sDate.hour, sDate.minute);
      }
    }
    
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = date.day;
    final month = monthNames[date.month - 1];
    final year = date.year;
    
    // If time is STILL exactly 00:00, only show date
    if (date.hour == 0 && date.minute == 0) {
      return '$day $month $year';
    }
    
    final hourNum = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    
    return '$day $month $year • $hourNum:$minute $period';
  }

  static String getRelativeTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recently';
    final date = _parseAnyDate(timestamp);
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  static String formatToDMY(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static DateTime parseDateForSort(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    final date = _parseAnyDate(dateStr);
    return date ?? DateTime(2000);
  }
}