import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CommodityUtils {
  static String getImageUrl(String commodity) {
    final lower = commodity.toLowerCase().trim();
    
    // 1. Check if we have a custom image uploaded in Supabase (cached in Hive)
    try {
      final box = Hive.box('supabase_commodity_images');
      if (box.isOpen && box.containsKey(lower)) {
        final customUrl = box.get(lower) as String?;
        if (customUrl != null && customUrl.isNotEmpty) {
          return customUrl;
        }
      }
    } catch (_) {}
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
    } else if (lower.contains('banana - green') || lower.contains('green banana') || lower.contains('kachcha kela') || lower.contains('raw banana')) {
      return 'https://images.unsplash.com/photo-1566393028639-d108a42c46a7?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('banana') || lower.contains('kela')) {
      return 'https://images.unsplash.com/photo-1571771894821-ad99024177c6?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('lemon') || lower.contains('nimbu')) {
      return 'https://images.unsplash.com/photo-1587411768538-ef461ec7d18c?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('mango') || lower.contains('aam')) {
      return 'https://images.unsplash.com/photo-1553279768-865429fa0078?q=80&w=500&auto=format&fit=crop';
    } else if (lower.contains('radish') || lower.contains('raddish') || lower.contains('mooli')) {
      return 'https://images.unsplash.com/photo-1590779033100-9f60a05a013d?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('mint') || lower.contains('pudina')) {
      return 'https://images.unsplash.com/photo-1558961313-90d24e5264b0?q=80&w=800&auto=format&fit=crop';
    } else if (lower.contains('thondekal') || lower.contains('thondekai') || lower.contains('kundru') || lower.contains('gourd')) {
      return 'https://images.unsplash.com/photo-1592417817098-8f3d6eb19675?q=80&w=800&auto=format&fit=crop';
    }
    return '';
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

  /// Batch synchronize custom product images uploaded to Supabase 'commodity_images' table
  static Future<void> syncCustomImagesFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. If table is empty, auto-populate all 340+ unique product names to make it easy for the user!
      try {
        final List existing = await supabase.from('commodity_images').select('commodity_name').limit(1);
        if (existing.isEmpty) {
          debugPrint('🌱 Seeding 340+ commodity names to Supabase commodity_images table...');
          final List<String> defaultCrops = [
            'Agar', 'Agathi', 'Ajwain(Bishops Weed)', 'Alasande Gram', 'Alasande', 'Almond(Badam)', 'Alsande', 'Amaranthus', 'Ambada Seed', 'Ambarkhani', 
            'Amla(Nelli Kai)', 'Amphophallus', 'Antawala', 'Anterwala', 'Apple', 'Apricot(Jardalu)', 'Arecanut(Betelnut/Supari)', 'Arhar (Tur/Red Gram)', 'Arhar Dal(Tur Dal)', 'Ashgourd', 
            'Asparagus', 'Astera', 'Avacado(Fruit)', 'Baby Corn', 'Bajra(Pearl Millet/Cumbu)', 'Balekai', 'Bamboo', 'Banana', 'Banana - Green', 'Barley (Jau)', 
            'Basil', 'Bay leaf (Tejpatta)', 'Beans', 'Beetroot', 'Bengal Gram(Gram)', 'Bengal Gram Dal(Chana Dal)', 'Ber(Zizyphus/Borehana)', 'Betel Leaves', 'Bhindi(Ladies Finger)', 'Big Gram', 
            'Binoula', 'Bitter Gourd', 'Black Gram (Urd Beans)', 'Black Gram Dal (Urd Dal)', 'Black Pepper', 'Bobbili', 'Bottle Gourd', 'Brinjal', 'Broccoli', 'Bull', 
            'Bunched Vegetables', 'Butter', 'Cabbage', 'Capsicum', 'Cardamom', 'Carnation', 'Carrot', 'Cashewnuts', 'Castor Oil', 'Castor Seed', 
            'Cauliflower', 'Chana Dal', 'Chandramukhi', 'Chayote', 'Cherry', 'Chicory(Roots)', 'Chili Red', 'Chilies Green', 'Chikoos(Sapota)', 'Chilly Powder', 
            'Chrysanthemum(Loose)', 'Cinnamon(Dalchini)', 'Citron', 'Cluster beans', 'Coca', 'Coconut', 'Coconut Oil', 'Coffee', 'Colocasia', 'Copra', 
            'Coriander(Leaves)', 'Coriander(Seed)', 'Cotton', 'Cotton Seed', 'Cowpea(Veg)', 'Cowpea (Lobia/Karamani)', 'Cucumber(Kheera)', 'Cumin Seed(Jeera)', 'Custard Apple (Sharifa)', 'Dahlia', 
            'Dal', 'Dhaincha', 'Drumstick', 'Dry Chillies', 'Dry Fodder', 'Egg', 'Elephant Yam (Suran)', 'Fennel(Saunf)', 'Fenugreek Seeds', 'Fenugreek(Leaves)', 
            'Fig(Anjura/Anjeer)', 'Firewood', 'Fish', 'Flower', 'French Beans (Frasbin)', 'Garlic', 'Ghee', 'Ginger(Green)', 'Ginger(Dry)', 'Gladiolus Cut Flower', 
            'Goat', 'Gram Raw(Chana)', 'Gramflour', 'Grapes', 'Green Chilli', 'Green Fodder', 'Green Gram (Moong Beans)', 'Green Gram Dal (Moong Dal)', 'Green Peas', 'Groundnut', 
            'Groundnut (Split)', 'Groundnut pods (Whole)', 'Groundnut Oil', 'Guava', 'Gur(Jaggery)', 'Gwar', 'Gwar Seed', 'He-Buffalo', 'Hen', 'Hi-Buffalo', 
            'Honey', 'Horse Gram(Kulthi)', 'Isabgul (Psyllium)', 'Jack Fruit', 'Jaggery', 'Jamun(Fruit)', 'Jasmine', 'Jowar(Sorghum)', 'Jute', 'Jute Seed', 
            'Kabuli Chana(White Gram)', 'Kachalu', 'Kakada', 'Kalonji', 'Kapas', 'Karade', 'Karutha Columban', 'Kasturi Cotton', 'Knool Khol', 'Kokum', 
            'Kulthi(Horse Gram)', 'Kusum', 'Ladies Finger', 'Lak(Teora)', 'Lamb', 'Lentil (Masur)', 'Lemon', 'Lily', 'Linseed', 'Lint', 
            'Litchi', 'Little Gourd (Tinda)', 'Lobia', 'Long Pepper', 'Lotus', 'Lotus Sticks', 'Lukati', 'Mace', 'Mackarel', 'Mahua', 
            'Mahua Seed(Hippe seed)', 'Maize', 'Mango', 'Mango (Raw)', 'Mangosteen', 'Marigold(Calcutta)', 'Marigold(Loose)', 'Mashrooms', 'Mataki', 'Menthi', 
            'Methi(Leaves)', 'Millets', 'Milk', 'Mint(Pudina)', 'Moong(Whole)', 'Moong Dal', 'Moth', 'Mousambi(Sweet Lime)', 'Mustard', 'Mustard Oil', 
            'Myrobalan(Harad)', 'Neem Seed', 'Niger Seed (Ramtil)', 'Nutmeg', 'Onion', 'Onion Green', 'Orange', 'Orchid', 'Ox', 'Paddy(Dhan)', 
            'Papaya', 'Papaya (Raw)', 'Pathani', 'Peach', 'Pear(Maraseel)', 'Peas (Dry)', 'Peas Wet', 'Pepper Garbled', 'Pepper Ungarbled', 'Persimon', 
            'Pigeon Pea (Arhar)', 'Pineapple', 'Plum', 'Pomegranate', 'Potato', 'Pumpkin', 'Punga Oil', 'Radish', 'Ragi (Finger Millet)', 'Rajgir', 
            'Rajma', 'Ram', 'Ramtilla', 'Rat Tail Puru', 'Red Gram', 'Red Cabbage', 'Ridgegourd(Turi)', 'Rose(Local)', 'Rose(Loose)', 'Safflower', 
            'Saffron', 'Sago', 'Sal Seed', 'Sapota(Chikoo)', 'Sarsone', 'Seasamum(Sesame,Til)', 'Sheep', 'Silk', 'Skin And Hide', 'Snakegourd', 
            'Soapnut(Antawala/Ritha)', 'Soyabean', 'Spinach', 'Sponge Gourd', 'Squash(Pumpkins)', 'Strawberry', 'Sugar', 'Sugarcane', 'Sunflower', 'Sunflower Seed', 
            'Suva (Anethum)', 'Sweet Corn', 'Sweet Lime', 'Sweet Potato', 'Tamarind', 'Tamarind Seed', 'Tapioca', 'Tea', 'Tender Coconut', 'Thondekai', 
            'Tobacco', 'Tomato', 'Toria', 'Tur Dal', 'Turmeric', 'Turnip', 'Urd Dal', 'Water Melon', 'Walnut', 'Wheat', 
            'White Pumpkin', 'Wood', 'Wool', 'Yam', 'Yam (Ratalu)', 'Alasande Dal', 'Moth Dal', 'Kabuli Chana Dal', 'Singhoda', 'Foxnut(Makhana)',
            'Thinai', 'Kuthiravali', 'Samai', 'Varagu', 'Parsley', 'Celery', 'Leek', 'Lettuce', 'Kale', 'Bok Choy',
            'Blueberry', 'Blackberry', 'Raspberry', 'Cranberry', 'Passion Fruit', 'Rambutan', 'Durian', 'Longan', 'Anthurium',
            'Lilium', 'Gerbera', 'Tulip', 'Orchid Flower', 'Asafoetida', 'Dry Mango Powder', 'Nigella seeds', 'Star Anise', 'Mace(Javitri)',
            'Poppy seeds', 'Aloo', 'Pyaz', 'Tamatar', 'Gajar', 'Mooli', 'Adrak', 'Lahsun', 'Hari Mirch', 'Lal Mirch',
            'Dhaniya', 'Jeera', 'Haldi', 'Methi', 'Saunf', 'Ajwain(Carom)', 'Sarson', 'Til', 'Moongfali', 'Soyabean Oil',
            'Kapas(Cotton Seed)', 'Dhan', 'Chawal', 'Gehun', 'Makka', 'Bajra', 'Jowar', 'Chana', 'Tur', 'Moong',
            'Urad', 'Masur Dal', 'Matar', 'Kela', 'Seb', 'Aam', 'Angur', 'Santra', 'Papita', 'Anar',
            'Nimbu', 'Amrud', 'Cheeku', 'Kharbuja', 'Tarboj', 'Sitafal', 'Lichi', 'Anjir', 'Khajur', 'Kaju',
            'Badam', 'Akhrot', 'Pista', 'Kishmish', 'Supari', 'Nariyal', 'Gud', 'Shakar', 'Chai', 'Paneer',
            'Dahi', 'Malai', 'Makhan', 'Beef', 'Pork', 'Poultry', 'Dry Fruits', 'Makhana', 'Rava', 'Maida'
          ];
          
          final List<Map<String, dynamic>> batch = defaultCrops.map((c) => {
            'commodity_name': c,
            'image_url': ''
          }).toList();
          
          await supabase.from('commodity_images').upsert(batch, onConflict: 'commodity_name');
          debugPrint('✨ Successfully seeded ${batch.length} commodity names to Supabase!');
        }
      } catch (se) {
        debugPrint('⚠️ Error auto-seeding commodity names: $se');
      }

      // 2. Fetch all custom image links
      final List response = await supabase
          .from('commodity_images')
          .select('commodity_name, image_url');
      
      final box = await Hive.openBox('supabase_commodity_images');
      await box.clear(); // Flush old cache to sync fresh
      
      for (final row in response) {
        final name = (row['commodity_name'] as String).toLowerCase().trim();
        final url = row['image_url'] as String;
        await box.put(name, url);
      }
      debugPrint('✅ Synced ${response.length} custom commodity images from Supabase!');
    } catch (e) {
      debugPrint('⚠️ Failed to sync custom commodity images: $e');
    }
  }
}