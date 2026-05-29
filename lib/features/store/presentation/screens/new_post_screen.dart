import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mandi/presentation/providers/mandi_providers.dart';
import '../../../../core/providers/general_providers.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/services/notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';

class NewPostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? editData;
  const NewPostScreen({super.key, this.editData});

  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _commodityController;
  late final TextEditingController _quantityController;
  late final TextEditingController _targetPriceController;
  late final TextEditingController _stateController;
  late final TextEditingController _districtController;
  late final TextEditingController _commentsController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;

  // Form State
  String _buySell = 'SELL';
  String _commodity = '';
  String _unit = 'Quintal';
  String _selectedState = '';
  String _selectedDistrict = '';
  String _quality = 'Good';
  String _language = 'English';
  DateTime _listingDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  bool _isOrganic = false;
  bool _isProcessed = false;
  bool _isGraded = false;
  bool _isPackedInBags = false;
  bool _isStoredInAC = false;
  bool _agreeToTerms = true;
  bool _isSubmitting = false;

  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final data = widget.editData;

    _commodityController =
        TextEditingController(text: data?['commodity'] ?? '');
    _quantityController = TextEditingController(text: data?['quantity'] ?? '');
    _targetPriceController =
        TextEditingController(text: data?['price']?.toString() ?? '');
    _stateController = TextEditingController(text: data?['state'] ?? '');
    _districtController = TextEditingController(text: data?['district'] ?? '');
    _commentsController = TextEditingController(
        text: data?['comments'] ??
            (data?['type'] == 'BUY'
                ? 'I want to buy good quality commodity.'
                : 'I want to sell my product.'));
    _nameController = TextEditingController(text: data?['contact_name'] ?? '');
    _emailController =
        TextEditingController(text: data?['contact_email'] ?? '');
    _mobileController = TextEditingController();

    if (data != null) {
      _buySell = data['type'] ?? 'SELL';
      _commodity = data['commodity'] ?? '';
      _unit = data['unit'] ?? 'Quintal';
      _selectedState = data['state'] ?? '';
      _selectedDistrict = data['district'] ?? '';
      _quality = data['quality'] ?? 'Good';
      _language = data['language'] ?? 'English';
      _listingDate = DateTime.parse(
          data['listing_date'] ?? DateTime.now().toIso8601String());
      _endDate = DateTime.parse(data['end_date'] ??
          DateTime.now().add(const Duration(days: 30)).toIso8601String());
      _isOrganic = data['is_organic'] ?? false;
      _isProcessed = data['is_processed'] ?? false;
      _isGraded = data['is_graded'] ?? false;
      _isPackedInBags = data['is_packed'] ?? false;
      _isStoredInAC = data['is_ac_stored'] ?? false;
      _existingImageUrl = data['image_url'];
    }
  }

  @override
  void dispose() {
    _commodityController.dispose();
    _quantityController.dispose();
    _targetPriceController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _commentsController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
        content: const SingleChildScrollView(
          child: Text(
            'Users must buy or sell at their own responsibility. Thoroughly verify the details before making transactions with any individual. Finalize the deal keeping your safety and risk in mind. Bharat Flow will not be responsible for the behavior of any buyer or seller, payments, or the quality of goods. We only provide a platform; transaction responsibility is entirely yours.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please agree to terms and conditions')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final googleUser = googleSignInInstance.currentUser;
      final profile = ref.read(profileProvider).value;
      final box = Hive.box('settings');

      final String? userId = supabaseUser?.id ?? googleUser?.id ?? (box.get('isLoggedIn') == true ? 'reviewer_id' : null);
      final String? userName = profile?.fullName ?? 
          googleUser?.displayName ?? 
          supabaseUser?.userMetadata?['full_name'] ?? 
          supabaseUser?.userMetadata?['name'] ?? 
          box.get('userName') ?? 
          'Kisan User';

      if (userId == null) throw 'User not logged in';

      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await ref
            .read(generalRepositoryProvider)
            .uploadFile('store-images', fileName, _selectedImage!);
      }

      String finalComments = _commentsController.text;
      if (_mobileController.text.isNotEmpty) {
        finalComments += '\nContact No: ${_mobileController.text}';
      }

      final postData = {
        'type': _buySell,
        'commodity': _commodity,
        'quantity': _quantityController.text,
        'price': double.tryParse(_targetPriceController.text) ?? 0.0,
        'unit': _unit,
        'state': _selectedState,
        'district': _selectedDistrict,
        'quality': _quality,
        'listing_date': _listingDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'language': _language,
        'comments': finalComments,
        'is_organic': _isOrganic,
        'is_processed': _isProcessed,
        'is_graded': _isGraded,
        'is_packed': _isPackedInBags,
        'is_ac_stored': _isStoredInAC,
        'image_url': imageUrl,
        'contact_name': _nameController.text,
        'contact_email': _emailController.text,
        'user_id': userId,
        'user_name': userName,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'rejection_reason': null,
      };

      final repo = ref.read(generalRepositoryProvider);
      bool success;
      if (widget.editData != null) {
        success = await repo.updateData(
            'store_products', 'id', widget.editData!['id'], postData);
      } else {
        success = await repo.insertData('store_products', postData);
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.editData != null
                  ? 'Post updated and submitted for approval!'
                  : 'Post submitted for review! It will go live after approval.'),
              backgroundColor: const Color(0xFF00897B),
              duration: const Duration(seconds: 4),
            ),
          );
          ref.invalidate(
              tableDataProvider('store_products')); // Refresh the list

          if (widget.editData == null) {
            try {
              final oppositeType = _buySell == 'BUY' ? 'SELL' : 'BUY';
              final matchingPostResponse = await Supabase.instance.client
                  .from('store_products')
                  .select()
                  .eq('type', oppositeType)
                  .eq('commodity', _commodity)
                  .eq('district', _selectedDistrict)
                  .neq('user_id', userId)
                  .limit(1);

              if (matchingPostResponse.isNotEmpty) {
                final matchingPost = matchingPostResponse.first;
                String title;
                String body;

                if (_buySell == 'BUY') {
                  title = '🎉 Seller Found in Your City!';
                  body =
                      'A seller for $_commodity is available in $_selectedDistrict. Tap to view and contact them now!';
                } else {
                  title = '🎉 Buyer Found in Your City!';
                  body =
                      'A buyer for $_commodity is looking in $_selectedDistrict. Tap to view and contact them now!';
                }

                NotificationService.showNotification(title, body,
                    payload: json.encode(
                        {'type': 'store_match', 'product': matchingPost}));
              }
            } catch (e) {
              debugPrint('Match-making error: $e');
            }
          }

          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Failed to save post. Please try again.')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Comprehensive Indian States and Districts Data
  static const Map<String, List<String>> _stateDistricts = {
    'Andhra Pradesh': [
      'Anantapur',
      'Chittoor',
      'East Godavari',
      'Guntur',
      'Krishna',
      'Kurnool',
      'Prakasam',
      'Srikakulam',
      'Visakhapatnam',
      'Vizianagaram',
      'West Godavari',
      'YSR Kadapa'
    ],
    'Arunachal Pradesh': [
      'Anjaw',
      'Changlang',
      'Dibang Valley',
      'East Kameng',
      'East Siang',
      'Kurung Kumey',
      'Lohit',
      'Lower Dibang Valley',
      'Lower Subansiri',
      'Papum Pare',
      'Tawang',
      'Tirap',
      'Upper Siang',
      'Upper Subansiri',
      'West Kameng',
      'West Siang'
    ],
    'Assam': [
      'Baksa',
      'Barpeta',
      'Biswanath',
      'Bongaigaon',
      'Cachar',
      'Charaideo',
      'Chirang',
      'Darrang',
      'Dhemaji',
      'Dhubri',
      'Dibrugarh',
      'Goalpara',
      'Golaghat',
      'Hailakandi',
      'Hojai',
      'Jorhat',
      'Kamrup',
      'Kamrup Metropolitan',
      'Karbi Anglong',
      'Karimganj',
      'Kokrajhar',
      'Lakhimpur',
      'Majuli',
      'Morigaon',
      'Nagaon',
      'Nalbari',
      'Sivasagar',
      'Sonitpur',
      'South Salmara-Mankachar',
      'Tinsukia',
      'Udalguri',
      'West Karbi Anglong'
    ],
    'Bihar': [
      'Araria',
      'Arwal',
      'Aurangabad',
      'Banka',
      'Begusarai',
      'Bhagalpur',
      'Bhojpur',
      'Buxar',
      'Darbhanga',
      'East Champaran',
      'Gaya',
      'Gopalganj',
      'Jamui',
      'Jehanabad',
      'Kaimur',
      'Katihar',
      'Khagaria',
      'Kishanganj',
      'Lakhisarai',
      'Madhepura',
      'Madhubani',
      'Munger',
      'Muzaffarpur',
      'Nalanda',
      'Nawada',
      'Patna',
      'Purnia',
      'Rohtas',
      'Saharsa',
      'Samastipur',
      'Saran',
      'Sheikhpura',
      'Sheohar',
      'Sitamarhi',
      'Siwan',
      'Supaul',
      'Vaishali',
      'West Champaran'
    ],
    'Chhattisgarh': [
      'Balod',
      'Baloda Bazar',
      'Balrampur',
      'Bastar',
      'Bemetara',
      'Bijapur',
      'Bilaspur',
      'Dantewada',
      'Dhamtari',
      'Durg',
      'Gariaband',
      'Janjgir-Champa',
      'Jashpur',
      'Kabirdham',
      'Kanker',
      'Kondagaon',
      'Korba',
      'Koriya',
      'Mahasamund',
      'Mungeli',
      'Narayanpur',
      'Raigarh',
      'Raipur',
      'Rajnandgaon',
      'Sukma',
      'Surajpur',
      'Surguja'
    ],
    'Goa': ['North Goa', 'South Goa'],
    'Gujarat': [
      'Ahmedabad',
      'Amreli',
      'Anand',
      'Aravalli',
      'Banaskantha',
      'Bharuch',
      'Bhavnagar',
      'Botad',
      'Chhota Udepur',
      'Dahod',
      'Dang',
      'Devbhoomi Dwarka',
      'Gandhinagar',
      'Gir Somnath',
      'Jamnagar',
      'Junagadh',
      'Kheda',
      'Kutch',
      'Mahisagar',
      'Mehsana',
      'Morbi',
      'Narmada',
      'Navsari',
      'Panchmahal',
      'Patan',
      'Porbandar',
      'Rajkot',
      'Sabarkantha',
      'Surat',
      'Surendranagar',
      'Tapi',
      'Vadodara',
      'Valsad'
    ],
    'Haryana': [
      'Ambala',
      'Bhiwani',
      'Charkhi Dadri',
      'Faridabad',
      'Fatehabad',
      'Gurugram',
      'Hisar',
      'Jhajjar',
      'Jind',
      'Kaithal',
      'Karnal',
      'Kurukshetra',
      'Mahendragarh',
      'Nuh',
      'Palwal',
      'Panchkula',
      'Panipat',
      'Rewari',
      'Rohtak',
      'Sirsa',
      'Sonipat',
      'Yamunanagar'
    ],
    'Himachal Pradesh': [
      'Bilaspur',
      'Chamba',
      'Hamirpur',
      'Kangra',
      'Kinnaur',
      'Kullu',
      'Lahaul and Spiti',
      'Mandi',
      'Shimla',
      'Sirmaur',
      'Solan',
      'Una'
    ],
    'Jammu and Kashmir': [
      'Anantnag',
      'Bandipora',
      'Baramulla',
      'Budgam',
      'Doda',
      'Ganderbal',
      'Jammu',
      'Kathua',
      'Kishtwar',
      'Kulgam',
      'Kupwara',
      'Poonch',
      'Pulwama',
      'Rajouri',
      'Ramban',
      'Reasi',
      'Samba',
      'Shopian',
      'Srinagar',
      'Udhampur'
    ],
    'Jharkhand': [
      'Bokaro',
      'Chatra',
      'Deoghar',
      'Dhanbad',
      'Dumka',
      'East Singhbhum',
      'Garhwa',
      'Giridih',
      'Godda',
      'Gumla',
      'Hazaribagh',
      'Jamtara',
      'Khunti',
      'Koderma',
      'Latehar',
      'Lohardaga',
      'Pakur',
      'Palamu',
      'Ramgarh',
      'Ranchi',
      'Sahibganj',
      'Seraikela-Kharsawan',
      'Simdega',
      'West Singhbhum'
    ],
    'Karnataka': [
      'Bagalkot',
      'Ballari',
      'Belagavi',
      'Bengaluru Rural',
      'Bengaluru Urban',
      'Bidar',
      'Chamarajanagar',
      'Chikkaballapur',
      'Chikkamagaluru',
      'Chitradurga',
      'Dakshina Kannada',
      'Davanagere',
      'Dharwad',
      'Gadag',
      'Hassan',
      'Haveri',
      'Kalaburagi',
      'Kodagu',
      'Kolar',
      'Koppal',
      'Mandya',
      'Mysuru',
      'Raichur',
      'Ramanagara',
      'Shivamogga',
      'Tumakuru',
      'Udupi',
      'Uttara Kannada',
      'Vijayapura',
      'Yadgir'
    ],
    'Kerala': [
      'Alappuzha',
      'Ernakulam',
      'Idukki',
      'Kannur',
      'Kasaragod',
      'Kollam',
      'Kottayam',
      'Kozhikode',
      'Malappuram',
      'Palakkad',
      'Pathanamthitta',
      'Thiruvananthapuram',
      'Thrissur',
      'Wayanad'
    ],
    'Madhya Pradesh': [
      'Agar Malwa',
      'Alirajpur',
      'Anuppur',
      'Ashoknagar',
      'Balaghat',
      'Barwani',
      'Betul',
      'Bhind',
      'Bhopal',
      'Burhanpur',
      'Chhatarpur',
      'Chhindwara',
      'Damoh',
      'Datia',
      'Dewas',
      'Dhar',
      'Dindori',
      'Guna',
      'Gwalior',
      'Harda',
      'Hoshangabad',
      'Indore',
      'Jabalpur',
      'Jhabua',
      'Katni',
      'Khandwa',
      'Khargone',
      'Mandla',
      'Mandsaur',
      'Morena',
      'Narsinghpur',
      'Neemuch',
      'Panna',
      'Raisen',
      'Rajgarh',
      'Ratlam',
      'Rewa',
      'Sagar',
      'Satna',
      'Sehore',
      'Seoni',
      'Shahdol',
      'Shajapur',
      'Sheopur',
      'Shivpuri',
      'Sidhi',
      'Singrauli',
      'Tikamgarh',
      'Ujjain',
      'Umaria',
      'Vidisha'
    ],
    'Maharashtra': [
      'Ahmednagar',
      'Akola',
      'Amravati',
      'Aurangabad',
      'Beed',
      'Bhandara',
      'Buldhana',
      'Chandrapur',
      'Dhule',
      'Gadchiroli',
      'Gondia',
      'Hingoli',
      'Jalgaon',
      'Jalna',
      'Kolhapur',
      'Latur',
      'Mumbai City',
      'Mumbai Suburban',
      'Nagpur',
      'Nanded',
      'Nandurbar',
      'Nashik',
      'Osmanabad',
      'Palghar',
      'Parbhani',
      'Pune',
      'Raigad',
      'Ratnagiri',
      'Sangli',
      'Satara',
      'Sindhudurg',
      'Solapur',
      'Thane',
      'Wardha',
      'Washim',
      'Yavatmal'
    ],
    'Manipur': [
      'Bishnupur',
      'Chandel',
      'Churachandpur',
      'Imphal East',
      'Imphal West',
      'Jiribam',
      'Kakching',
      'Kamjong',
      'Kangpokpi',
      'Noney',
      'Pherzawl',
      'Senapati',
      'Tamenglong',
      'Tengnoupal',
      'Thoubal',
      'Ukhrul'
    ],
    'Meghalaya': [
      'East Garo Hills',
      'East Jaintia Hills',
      'East Khasi Hills',
      'North Garo Hills',
      'Ri Bhoi',
      'South Garo Hills',
      'South West Garo Hills',
      'South West Khasi Hills',
      'West Garo Hills',
      'West Jaintia Hills',
      'West Khasi Hills'
    ],
    'Mizoram': [
      'Aizawl',
      'Champhai',
      'Kolasib',
      'Lawngtlai',
      'Lunglei',
      'Mamit',
      'Saiha',
      'Serchhip'
    ],
    'Nagaland': [
      'Dimapur',
      'Kiphire',
      'Kohima',
      'Longleng',
      'Mokokchung',
      'Mon',
      'Peren',
      'Phek',
      'Tuensang',
      'Wokha',
      'Zunheboto'
    ],
    'Odisha': [
      'Angul',
      'Balangir',
      'Balasore',
      'Bargarh',
      'Bhadrak',
      'Baudh',
      'Cuttack',
      'Deogarh',
      'Dhenkanal',
      'Gajapati',
      'Ganjam',
      'Jagatsinghpur',
      'Jajpur',
      'Jharsuguda',
      'Kalahandi',
      'Kandhamal',
      'Kendrapara',
      'Kendujhar',
      'Khordha',
      'Koraput',
      'Malkangiri',
      'Mayurbhanj',
      'Nabarangpur',
      'Nayagarh',
      'Nuapada',
      'Puri',
      'Rayagada',
      'Sambalpur',
      'Sonepur',
      'Sundargarh'
    ],
    'Punjab': [
      'Amritsar',
      'Barnala',
      'Bathinda',
      'Faridkot',
      'Fatehgarh Sahib',
      'Fazilka',
      'Ferozepur',
      'Gurdaspur',
      'Hoshiarpur',
      'Jalandhar',
      'Kapurthala',
      'Ludhiana',
      'Mansa',
      'Moga',
      'Muktsar',
      'Pathankot',
      'Patiala',
      'Rupnagar',
      'Sahibzada Ajit Singh Nagar',
      'Sangrur',
      'Shahid Bhagat Singh Nagar',
      'Sri Muktsar Sahib',
      'Tarn Taran'
    ],
    'Rajasthan': [
      'Ajmer',
      'Alwar',
      'Banswara',
      'Baran',
      'Barmer',
      'Bharatpur',
      'Bhilwara',
      'Bikaner',
      'Bundi',
      'Chittorgarh',
      'Churu',
      'Dausa',
      'Dholpur',
      'Dungarpur',
      'Hanumangarh',
      'Jaipur',
      'Jaisalmer',
      'Jalore',
      'Jhalawar',
      'Jhunjhunu',
      'Jodhpur',
      'Karauli',
      'Kota',
      'Nagaur',
      'Pali',
      'Pratapgarh',
      'Rajsamand',
      'Sawai Madhopur',
      'Sikar',
      'Sirohi',
      'Sri Ganganagar',
      'Tonk',
      'Udaipur'
    ],
    'Sikkim': ['East Sikkim', 'North Sikkim', 'South Sikkim', 'West Sikkim'],
    'Tamil Nadu': [
      'Ariyalur',
      'Chennai',
      'Coimbatore',
      'Cuddalore',
      'Dharmapuri',
      'Dindigul',
      'Erode',
      'Kanchipuram',
      'Kanyakumari',
      'Karur',
      'Krishnagiri',
      'Madurai',
      'Nagapattinam',
      'Namakal',
      'Nilgiris',
      'Perambalur',
      'Pudukkottai',
      'Ramanathapuram',
      'Salem',
      'Sivaganga',
      'Thanjavur',
      'Theni',
      'Thoothukudi',
      'Tiruchirappalli',
      'Tirunelveli',
      'Tiruppur',
      'Tiruvallur',
      'Tiruvannamalai',
      'Tiruvarur',
      'Vellore',
      'Viluppuram',
      'Virudhunagar'
    ],
    'Telangana': [
      'Adilabad',
      'Bhadradri Kothagudem',
      'Hyderabad',
      'Jagtial',
      'Jangaon',
      'Jayashankar Bhupalpally',
      'Jogulamba Gadwal',
      'Kamareddy',
      'Karimnagar',
      'Khammam',
      'Komaram Bheem Asifabad',
      'Mahabubabad',
      'Mahabubnagar',
      'Mancherial',
      'Medak',
      'Medchal',
      'Nagarkurnool',
      'Nalgonda',
      'Nirmal',
      'Nizamabad',
      'Peddapalli',
      'Rajanna Sircilla',
      'Rangareddy',
      'Sangareddy',
      'Siddipet',
      'Suryapet',
      'Vikarabad',
      'Wanaparthy',
      'Warangal Rural',
      'Warangal Urban',
      'Yadadri Bhuvanagiri'
    ],
    'Tripura': [
      'Dhalai',
      'Gomati',
      'Khowai',
      'North Tripura',
      'Sepahijala',
      'South Tripura',
      'Unakoti',
      'West Tripura'
    ],
    'Uttar Pradesh': [
      'Agra',
      'Aligarh',
      'Allahabad',
      'Ambedkar Nagar',
      'Amethi',
      'Amroha',
      'Auraiya',
      'Azamgarh',
      'Baghpat',
      'Bahraich',
      'Ballia',
      'Balrampur',
      'Banda',
      'Barabanki',
      'Bareilly',
      'Basti',
      'Bhadohi',
      'Bijnor',
      'Budaun',
      'Bulandshahr',
      'Chandauli',
      'Chitrakoot',
      'Deoria',
      'Etah',
      'Etawah',
      'Faizabad',
      'Farrukhabad',
      'Fatehpur',
      'Firozabad',
      'Gautam Buddha Nagar',
      'Ghaziabad',
      'Ghazipur',
      'Gonda',
      'Gorakhpur',
      'Hamirpur',
      'Hapur',
      'Hardoi',
      'Hathras',
      'Jalaun',
      'Jaunpur',
      'Jhansi',
      'Kannauj',
      'Kanpur Dehat',
      'Kanpur Nagar',
      'Kasganj',
      'Kaushambi',
      'Kheri',
      'Kushinagar',
      'Lalitpur',
      'Lucknow',
      'Maharajganj',
      'Mahoba',
      'Mainpuri',
      'Mathura',
      'Mau',
      'Meerut',
      'Mirzapur',
      'Moradabad',
      'Muzaffarnagar',
      'Pilibhit',
      'Pratapgarh',
      'Raebareli',
      'Rampur',
      'Saharanpur',
      'Sambhal',
      'Sant Kabir Nagar',
      'Shahjahanpur',
      'Shamli',
      'Shravasti',
      'Siddharthnagar',
      'Sitapur',
      'Sonbhadra',
      'Sultanpur',
      'Unnao',
      'Varanasi'
    ],
    'Uttarakhand': [
      'Almora',
      'Bageshwar',
      'Chamoli',
      'Champawat',
      'Dehradun',
      'Haridwar',
      'Nainital',
      'Pauri Garhwal',
      'Pithoragarh',
      'Rudraprayag',
      'Tehri Garhwal',
      'Udham Singh Nagar',
      'Uttarkashi'
    ],
    'West Bengal': [
      'Alipurduar',
      'Bankura',
      'Birbhum',
      'Cooch Behar',
      'Dakshin Dinajpur',
      'Darjeeling',
      'Hooghly',
      'Howrah',
      'Jalpaiguri',
      'Jhargram',
      'Kalimpong',
      'Kolkata',
      'Malda',
      'Murshidabad',
      'Nadia',
      'North 24 Parganas',
      'Paschim Bardhaman',
      'Paschim Medinipur',
      'Purba Bardhaman',
      'Purba Medinipur',
      'Purulia',
      'South 24 Parganas',
      'Uttar Dinajpur'
    ],
    'Delhi': [
      'Central Delhi',
      'East Delhi',
      'New Delhi',
      'North Delhi',
      'North East Delhi',
      'North West Delhi',
      'Shahdara',
      'South Delhi',
      'South East Delhi',
      'South West Delhi',
      'West Delhi'
    ],
    'Puducherry': ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'],
    'Chandigarh': ['Chandigarh'],
    'Ladakh': ['Kargil', 'Leh'],
  };

  @override
  Widget build(BuildContext context) {
    final productList = ref.watch(productListProvider).items;
    final List<String> commodityNames = productList
        .map((e) => e['commodity_name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    commodityNames.sort();

    final List<String> allStates = _stateDistricts.keys.toList();
    allStates.sort();

    final List<String> currentDistricts = _selectedState.isNotEmpty
        ? List<String>.from(_stateDistricts[_selectedState] ?? [])
        : [];
    currentDistricts.sort();

    final activeThemeColor =
        _buySell == 'SELL' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final screenBgColor =
        _buySell == 'SELL' ? const Color(0xFFD0ECD5) : const Color(0xFFFBE9D0);
    final appBarColor = activeThemeColor;

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        title: Text(widget.editData != null ? 'Edit Post' : 'New Post',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _buySell == 'BUY'
                        ? 'List Your Requirement To Buy'
                        : 'List Your Product For Sale',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238)),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel(
                    'Do you want to Buy / Sell',
                    isRequired: true,
                    helpText:
                        'Choose whether you want to Buy commodities or Sell agricultural products.',
                  ),
                  _buildDropdown(
                    value: _buySell,
                    items: const ['BUY', 'SELL'],
                    onChanged: (val) {
                      setState(() {
                        _buySell = val!;
                        if (_commentsController.text ==
                                'I want to sell my product.' &&
                            _buySell == 'BUY') {
                          _commentsController.text =
                              'I want to buy good quality commodity.';
                        } else if (_commentsController.text ==
                                'I want to buy good quality commodity.' &&
                            _buySell == 'SELL') {
                          _commentsController.text =
                              'I want to sell my product.';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Commodity',
                    isRequired: true,
                    helpText:
                        'Select the name of the agricultural crop (e.g. Onion, Potato, Tomato) that you want to list.',
                  ),
                  _buildSearchableCommodity(commodityNames),
                  const SizedBox(height: 16),

                  _buildLabel(
                    _buySell == 'BUY'
                        ? 'Required Quantity'
                        : 'Available Quantity',
                    isRequired: true,
                    helpText: _buySell == 'BUY'
                        ? 'Enter the total crop quantity you want to buy, along with the appropriate unit.'
                        : 'Enter the total crop quantity you have available for sale, along with the appropriate unit.',
                  ),
                  Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: _buildTextField(
                              controller: _quantityController,
                              hint: '100, 50, 10 ..',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          value: _unit,
                          items: ['Quintal', 'KG', 'Ton', 'Box'],
                          onChanged: (val) => setState(() => _unit = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Target Price (₹)',
                    isRequired: true,
                    helpText:
                        'Specify the target or expected price you expect per unit (e.g., per Quintal).',
                  ),
                  _buildTextField(
                      controller: _targetPriceController,
                      hint: 'Ex: 2500',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                  const SizedBox(height: 16),

                  // State Searchable
                  _buildLabel(
                    'State',
                    isRequired: true,
                    helpText:
                        'Select the Indian state where the crop is located or required.',
                  ),
                  _buildSearchableLocation(
                    hint: 'Select Your State',
                    options: allStates,
                    controller: _stateController,
                    onSelected: (val) {
                      setState(() {
                        _selectedState = val;
                        _stateController.text = val;
                        _selectedDistrict = '';
                        _districtController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // District Searchable
                  _buildLabel(
                    'District',
                    isRequired: true,
                    helpText:
                        'Select the specific district within the chosen state.',
                  ),
                  _buildSearchableLocation(
                    hint: 'Select Your District',
                    options: currentDistricts,
                    controller: _districtController,
                    onSelected: (val) {
                      setState(() {
                        _selectedDistrict = val;
                        _districtController.text = val;
                      });
                    },
                    isEnabled: _selectedState.isNotEmpty,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Quality',
                    isRequired: true,
                    helpText:
                        'Select the quality grade of your crop (Average, Good, or Premium).',
                  ),
                  _buildDropdown(
                    value: _quality,
                    items: ['Good', 'Average', 'Premium'],
                    onChanged: (val) => setState(() => _quality = val!),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Listing Date',
                    isRequired: true,
                    helpText:
                        'The starting date when this deal/requirement goes live.',
                  ),
                  _buildDatePicker(
                    currentDate: _listingDate,
                    onDateSelected: (date) =>
                        setState(() => _listingDate = date),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'End Date',
                    isRequired: true,
                    helpText:
                        'The expiry date for this listing. It will automatically close after this date.',
                  ),
                  _buildDatePicker(
                    currentDate: _endDate,
                    onDateSelected: (date) => setState(() => _endDate = date),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Language Preference',
                    isRequired: true,
                    helpText:
                        'Select the language you prefer for communication with buyers/sellers.',
                  ),
                  _buildDropdown(
                    value: _language,
                    items: [
                      'English',
                      'Hindi (हिंदी)',
                      'Bengali (বাংলা)',
                      'Marathi (मराठी)',
                      'Telugu (తెలుగు)',
                      'Tamil (தமிழ்)',
                      'Gujarati (ગુજરાતી)',
                      'Urdu (اردو)',
                      'Kannada (कನ್ನಡ)',
                      'Odia (ଓଡ଼िଆ)',
                      'Malayalam (മലയാളम)'
                    ],
                    onChanged: (val) => setState(() => _language = val!),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Comments',
                    isRequired: true,
                    helpText:
                        'Add extra details like delivery terms, crop specifications, or packaging info.',
                  ),
                  _buildTextField(
                      controller: _commentsController,
                      hint: _buySell == 'BUY'
                          ? 'I want to buy good quality commodity.'
                          : 'I want to sell my product.',
                      maxLines: 3),
                  const SizedBox(height: 24),

                  _buildSwitch(
                      _buySell == 'BUY'
                          ? 'Do You Want Organic Product ?'
                          : 'Is It Organic Product ?',
                      _isOrganic,
                      (val) => setState(() => _isOrganic = val)),
                  _buildSwitch(
                      _buySell == 'BUY'
                          ? 'Do You Want Product Processed ?'
                          : 'Is Product Processed ?',
                      _isProcessed,
                      (val) => setState(() => _isProcessed = val)),
                  _buildSwitch(
                      _buySell == 'BUY'
                          ? 'Do You Want Product Graded ?'
                          : 'Is Product Graded ?',
                      _isGraded,
                      (val) => setState(() => _isGraded = val)),
                  _buildSwitch(
                      _buySell == 'BUY'
                          ? 'Do You Want Product Packed In Bags ?'
                          : 'Is Product Packed In Bags ?',
                      _isPackedInBags,
                      (val) => setState(() => _isPackedInBags = val)),
                  _buildSwitch(
                      _buySell == 'BUY'
                          ? 'Do You Want Product Stored in AC ?'
                          : 'Is Product Stored in AC ?',
                      _isStoredInAC,
                      (val) => setState(() => _isStoredInAC = val)),

                  const SizedBox(height: 24),
                  _buildLabel(
                    'Images',
                    isRequired: true,
                    helpText:
                        'Attach clear photos of the crop to attract more genuine deals.',
                  ),
                  const Text('(max file size allowed 1mb)',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildFilePicker(),

                  const SizedBox(height: 32),
                  const Text(
                    'Your Contact Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238)),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel(
                    'Contact Name',
                    isRequired: true,
                    helpText:
                        'Enter your full name so other traders know who they are speaking to.',
                  ),
                  _buildTextField(
                      controller: _nameController,
                      hint: 'Please Enter Your name'),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Email Address',
                    isRequired: false,
                    helpText:
                        'Enter your email address (Optional) for notifications and deal copy.',
                  ),
                  _buildTextField(
                      controller: _emailController,
                      hint: 'Please Enter Your Email Address',
                      keyboardType: TextInputType.emailAddress,
                      isRequired: false),
                  const SizedBox(height: 16),

                  _buildLabel(
                    'Mobile No.',
                    isRequired: false,
                    helpText:
                        'Provide your phone number so interested traders can directly call you.',
                  ),
                  _buildTextField(
                      controller: _mobileController,
                      hint: 'Please Enter Your Mobile No.',
                      keyboardType: TextInputType.phone,
                      isRequired: false),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (val) =>
                            setState(() => _agreeToTerms = val!),
                        activeColor: activeThemeColor,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showTermsDialog(),
                          child: Text(
                            'I am agree with Terms And Conditions',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: activeThemeColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: activeThemeColor,
                        side: BorderSide(color: activeThemeColor, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: activeThemeColor))
                          : Text(
                              widget.editData != null
                                  ? 'Update Post'
                                  : 'Submit',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showHelpDialog(String fieldName, String helpText) {
    final activeColor =
        _buySell == 'SELL' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: activeColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
                child: Text(fieldName,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content:
            Text(helpText, style: const TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: activeColor),
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text,
      {required bool isRequired, String? helpText}) {
    final activeThemeColor =
        _buySell == 'SELL' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238)),
          ),
          if (isRequired)
            const Text(' *',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (helpText != null) {
                _showHelpDialog(text, helpText);
              }
            },
            child: Icon(Icons.help_outlined, size: 16, color: activeThemeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String hint,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters,
      bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: isRequired
          ? ((val) => val == null || val.trim().isEmpty ? 'Required' : null)
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildSearchableCommodity(List<String> commodityNames) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _commodity),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') return const Iterable<String>.empty();
        final query = textEditingValue.text.toLowerCase();
        return commodityNames.where((String option) {
          final optLower = option.toLowerCase();
          if (optLower.startsWith(query)) return true;
          final words = optLower.split(RegExp(r'[\s\(\)/\-]+'));
          return words.any((word) => word.startsWith(query));
        });
      },
      onSelected: (String selection) => setState(() => _commodity = selection),
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\(\)/\-]'))],
          validator: (val) =>
              val == null || val.isEmpty ? 'Please select a commodity' : null,
          decoration: InputDecoration(
            hintText: 'Ex: Tomato, Potato, Onions',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                      title: Text(option, style: const TextStyle(fontSize: 14)),
                      onTap: () => onSelected(option));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchableLocation({
    required String hint,
    required List<String> options,
    required TextEditingController controller,
    required Function(String) onSelected,
    bool isEnabled = true,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (!isEnabled || textEditingValue.text == '')
          return const Iterable<String>.empty();
        return options.where((String option) =>
            option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        if (controller.text != fieldController.text &&
            controller.text.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => fieldController.clear());
        } else if (controller.text.isNotEmpty && fieldController.text.isEmpty) {
          fieldController.text = controller.text;
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          enabled: isEnabled,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey.shade100,
            suffixIcon: const Icon(Icons.keyboard_arrow_down,
                size: 20, color: Colors.grey),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                      title: Text(option, style: const TextStyle(fontSize: 14)),
                      onTap: () => onSelected(option));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
      {required String value,
      required List<String> items,
      required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      {required DateTime currentDate,
      required Function(DateTime) onDateSelected}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 1000)),
        );
        if (date != null) onDateSelected(date);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300)),
        child: Text(
            "${currentDate.month.toString().padLeft(2, '0')}/${currentDate.day.toString().padLeft(2, '0')}/${currentDate.year}",
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238))),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    final activeThemeColor =
        _buySell == 'SELL' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Transform.scale(
              scale: 0.8,
              child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: activeThemeColor)),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238))),
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: Colors.grey.shade400))),
              child: const Text('Choose Files',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedImage != null
                    ? _selectedImage!.path.split('/').last
                    : (_existingImageUrl != null
                        ? 'Existing Image Attached'
                        : 'No file chosen'),
                style: TextStyle(
                    color: _buySell == 'SELL'
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_selectedImage != null || _existingImageUrl != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedImage != null
                        ? (kIsWeb
                            ? Image.network(_selectedImage!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    const Icon(Icons.broken_image))
                            : Image.file(_selectedImage!,
                                key: ValueKey(_selectedImage!.path),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    const Icon(Icons.broken_image)))
                        : Image.network(_existingImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                const Icon(Icons.broken_image)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedImage = null;
                      _existingImageUrl = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
