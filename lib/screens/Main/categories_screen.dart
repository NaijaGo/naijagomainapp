import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'category_products_screen.dart';
import 'chat_screen.dart';

const Color primaryNavy = AppTheme.primaryNavy;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color accentGreen = AppTheme.accentGreen;
const Color softGrey = AppTheme.softGrey;
const Color white = AppTheme.cardWhite;
const Color borderGrey = AppTheme.borderGrey;
const Color lightGrey = AppTheme.mutedText;

class CategoriesScreen extends StatefulWidget {
  final bool showAppBar;

  const CategoriesScreen({super.key, this.showAppBar = true});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _leftPaneController = ScrollController();
  final ScrollController _rightPaneController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _sidebarKeys = {};
  final GlobalKey _rightPaneViewportKey = GlobalKey();
  String? _activeSection;

  final Map<String, List<String>> _allCategories = {
    'Home & Office': [
      'Appliances',
      'Home & Kitchen',
      'Home Interior & Exterior',
      'Office Products',
      'Furniture',
      'Lighting',
      'Home Security',
      'Cleaning Supplies',
      'Storage & Organization',
      'Garden & Outdoor',
      'Bedding & Bath',
    ],
    'Phones & Tablets': [
      'Mobile Phones',
      'Tablets',
      'Mobile Phone Accessories',
      'Wearable Technology',
      'Smartphones',
      'Feature Phones',
      'Phone Cases & Covers',
      'Screen Protectors',
      'Chargers & Cables',
      'Power Banks',
      'Bluetooth Accessories',
    ],
    'Fashion': [
      "Men's Fashion",
      "Women's Fashion",
      "Kids' Fashion",
      'Watches',
      'Luggages & Travel Gear',
      'Hair & Wigs',
      'Footwear',
      'Bags & Purses',
      'Jewelry',
      'Eyewear',
      'Belts & Accessories',
      'Traditional Attire',
      'Underwear & Lingerie',
      'Sportswear',
    ],
    'Health & Beauty': [
      'Make Up',
      'Fragrance',
      'Hair Care',
      'Oral Care',
      'Medicine',
      'Condoms',
      'Sex Toys',
      'Skin Care & Cosmetics',
      'Personal Care',
      'Shaving & Hair Removal',
      'Vitamins & Supplements',
      'First Aid',
      'Medical Equipment',
      'Feminine Care',
    ],
    'Electronics': [
      'Television & Video',
      'Camera & Photo',
      'Generator & Portable Power',
      'Audios',
      'Home Theater Systems',
      'Headphones & Earbuds',
      'Gadgets',
      'Drones',
      'Smart Home Devices',
      'Car Electronics',
      'Batteries & Power',
    ],
    'Computing': [
      'Computers',
      'Data Storage',
      'Anti Virus & Security',
      'Printers & Computer Accessories',
      'Keyboards & Mice',
    ],
    'Groceries': [
      'Beer, Wine & Spirits',
      'Food Cupboard',
      'House Hold Cleaning',
      'Fresh Produce',
      'Dairy & Eggs',
      'Seafood',
    ],
    'Automobiles': [
      'Car Care',
      'Car Exterior and Interior Accessories',
      'Tools & Equipment',
      'Oils & Fluids',
      'Car Safety',
      'Performance Parts',
    ],
    'Sporting Goods': [
      'Cardio Training',
      'Strength & Training Equipment',
      'Team Sports',
      'Outdoor & Adventures',
      'Fitness Trackers',
      'Yoga & Pilates',
      'Swimming',
      'Cycling',
      'Camping & Hiking',
      'Golf',
      'Martial Arts',
    ],
    'Gaming': [
      'Play Station',
      'Xbox',
      'Nintendo',
      'PC Gaming',
      'Gaming Consoles',
      'Video Games',
      'Gaming Accessories',
      'VR Headsets',
      'Arcade Games',
      'Board Games',
      'Card Games',
      'Puzzles',
    ],
    'Baby Products': [
      'Apparels & Accessories',
      'Diapering',
      'Feeding',
      'Baby Toddlers Toys',
      'Gears',
      'Bathing & Skin Care',
      'Potty Training',
      'Safety',
      'Nursery Furniture',
      'Strollers & Prams',
      'Car Seats',
      'Educational Toys',
    ],
    'Books & Stationery': [
      'Fiction Books',
      'Comics',
      'Technology',
      'Business',
      'Story',
      'Religious',
      'Non-Fiction',
      'Academic Textbooks',
      'Children Books',
      'Magazines',
      'Writing Instruments',
      'Office Supplies',
      'Art Supplies',
      'Calendars & Planners',
    ],
    'Animal Products': [
      'Chicken Feeds',
      'Dog Feeds',
      'Cat Feeds',
      'Fish Feeds',
      'Pig Feeds',
      'Pet Accessories',
      'Pet Health & Care',
      'Pet Toys',
      'Pet Clothing',
      'Pet Grooming',
      'Aquarium Supplies',
      'Bird Supplies',
    ],
    'Building & Construction': [
      'Building Materials',
      'Electrical',
      'Plumbing',
      'Tools & Machinery',
      'Safety Equipment',
      'Paints & Coatings',
      'Hardware',
    ],
    'Industrial & Scientific': [
      'Lab Equipment',
      'Packaging & Shipping',
      'Janitorial & Sanitation',
    ],
    'Music & Instruments': [
      'Guitars',
      'Keyboards & Pianos',
      'Wind Instruments',
      'Audio Equipment',
    ],
    'Arts & Crafts': ['Painting', 'Beading & Jewelry Making', 'Clay & Pottery'],
    'Agriculture': ['Fertilizers', 'Pesticides'],
    'Jewelry & Watches': ['Fine Jewelry', 'Fashion Jewelry', 'Wrist Watches'],
    'Toys & Games': [
      'Dolls',
      'Educational Toys',
      'Outdoor Toys',
      'Remote Control Toys',
      'Stuffed Animals',
      'Toy Vehicles',
    ],
    'Photography': [
      'Cameras',
      'Lenses',
      'Lighting Equipment',
      'Camera Bags & Cases',
      'Tripods & Supports',
    ],
    'Food & Beverage': [
      'Restaurant Equipment',
      'Catering Supplies',
      'Baking Supplies',
      'Food Processing',
      'Beverage Equipment',
      'Kitchen Utensils',
      'Food Packaging',
    ],
    'Travel & Tourism': ['Travel Accessories', 'Luggage', 'Hotel Supplies'],
    'Wedding & Events': ['Wedding Attire'],
  };

  final Map<String, IconData> _categoryIcons = {
    'Home & Office': Ionicons.home_outline,
    'Phones & Tablets': Ionicons.phone_portrait_outline,
    'Fashion': Ionicons.shirt_outline,
    'Health & Beauty': Ionicons.heart_outline,
    'Electronics': Ionicons.hardware_chip_outline,
    'Computing': Ionicons.laptop_outline,
    'Groceries': Ionicons.cart_outline,
    'Automobiles': Ionicons.car_outline,
    'Sporting Goods': Ionicons.football_outline,
    'Gaming': Ionicons.game_controller_outline,
    'Baby Products': Ionicons.happy_outline,
    'Books & Stationery': Ionicons.book_outline,
    'Animal Products': Ionicons.paw_outline,
    'Building & Construction': Ionicons.build_outline,
    'Industrial & Scientific': Ionicons.construct_outline,
    'Music & Instruments': Ionicons.musical_notes_outline,
    'Arts & Crafts': Ionicons.color_palette_outline,
    'Agriculture': Ionicons.leaf_outline,
    'Jewelry & Watches': Ionicons.diamond_outline,
    'Toys & Games': Ionicons.rocket_outline,
    'Photography': Ionicons.camera_outline,
    'Food & Beverage': Ionicons.restaurant_outline,
    'Travel & Tourism': Ionicons.airplane_outline,
    'Wedding & Events': Ionicons.heart_circle_outline,
  };

  final Map<String, String> _subCategoryImages = {
    'Appliances':
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=150&h=150&fit=crop',
    'Home & Kitchen':
        'https://images.unsplash.com/photo-1556228453-efd6c1ff04f6?w=150&h=150&fit=crop',
    'Home Interior & Exterior':
        'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=150&h=150&fit=crop',
    'Office Products':
        'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=150&h=150&fit=crop',
    'Furniture':
        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=150&h=150&fit=crop',
    'Lighting':
        'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=150&h=150&fit=crop',
    'Home Security': 'assets/categories/security.jpg',
    'Cleaning Supplies': 'assets/categories/cleaning supplier.jpg',
    'Storage & Organization':
        'https://images.unsplash.com/photo-1556228453-efd6c1ff04f6?w=150&h=150&fit=crop',
    'Garden & Outdoor':
        'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=150&h=150&fit=crop',
    'Bedding & Bath':
        'https://images.unsplash.com/photo-1560185893-a55cbc8c57e8?w=150&h=150&fit=crop',
    'Mobile Phones': 'assets/categories/mobile phones.jpg',
    'Tablets': 'assets/categories/tablets.jpg',
    'Mobile Phone Accessories':
        'assets/categories/mobile phone accessories.jpg',
    'Wearable Technology':
        'https://images.unsplash.com/photo-1576243345690-4e4b79b63288?w=150&h=150&fit=crop',
    'Smartphones':
        'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=150&h=150&fit=crop',
    'Feature Phones':
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=150&h=150&fit=crop',
    'Phone Cases & Covers': 'assets/categories/phones casese and cover.jpg',
    'Screen Protectors': 'assets/categories/screen protector.jpg',
    'Chargers & Cables': 'assets/categories/charger_and_cables.jpg',
    'Power Banks': 'assets/categories/power bank.jpg',
    'Bluetooth Accessories': 'assets/categories/bluetooth accessories.jpg',
    "Men's Fashion":
        'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=150&h=150&fit=crop',
    "Women's Fashion":
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=150&h=150&fit=crop',
    "Kids' Fashion": 'assets/categories/kids fashion.jpg',
    'Watches':
        'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=150&h=150&fit=crop',
    'Luggages & Travel Gear':
        'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=150&h=150&fit=crop',
    'Hair & Wigs': 'assets/categories/hair and wigs.jpg',
    'Footwear':
        'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=150&h=150&fit=crop',
    'Bags & Purses': 'assets/categories/bags and purses.jpg',
    'Jewelry': 'assets/categories/jewelry.jpg',
    'Eyewear':
        'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=150&h=150&fit=crop',
    'Belts & Accessories':
        'https://images.unsplash.com/photo-1520013573795-38516d2661e4?w=150&h=150&fit=crop',
    'Traditional Attire': 'assets/categories/traditional attire.jpg',
    'Underwear & Lingerie': 'assets/categories/underwear and lingerie.jpg',
    'Sportswear': 'assets/categories/sportswears.jpg',
    'Make Up':
        'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=150&h=150&fit=crop',
    'Fragrance': 'assets/categories/frangrance.jpg',
    'Hair Care': 'assets/categories/hair care.jpg',
    'Oral Care': 'assets/categories/oral care.jpg',
    'Medicine': 'assets/categories/medicines.jpg',
    'Condoms': 'assets/categories/condoms.jpg',
    'Sex Toys': 'assets/categories/sex toys.jpg',
    'Skin Care & Cosmetics': 'assets/categories/skin cares and cosmestic.jpg',
    'Personal Care': 'assets/categories/personal care.jpg',
    'Shaving & Hair Removal': 'assets/categories/hair removal.jpg',
    'Vitamins & Supplements': 'assets/categories/vitamins and supplement.jpg',
    'First Aid': 'assets/categories/first aid.jpg',
    'Medical Equipment': 'assets/categories/medical equipment.jpg',
    'Feminine Care': 'assets/categories/feminine  care.jpg',
    'Television & Video': 'assets/categories/television and video.jpg',
    'Camera & Photo':
        'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=150&h=150&fit=crop',
    'Generator & Portable Power':
        'assets/categories/generator and portable power.jpg',
    'Audios': 'assets/categories/audio.jpg',
    'Home Theater Systems':
        'assets/categories/home theatre and sound system.jpg',
    'Headphones & Earbuds': 'assets/categories/headphones and earbuds.jpg',
    'Gadgets': 'assets/categories/gadget.jpg',
    'Drones': 'assets/categories/drones.png',
    'Smart Home Devices': 'assets/categories/smart homes devices.jpg',
    'Car Electronics': 'assets/categories/car electronic.jpg',
    'Batteries & Power': 'assets/categories/batteries and power.jpg',
    'Computers': 'assets/categories/computer.jpg',
    'Data Storage': 'assets/categories/data storage.jpg',
    'Anti Virus & Security': 'assets/categories/antivirus and security.jpg',
    'Printers & Computer Accessories':
        'assets/categories/printer and computer.jpg',
    'Keyboards & Mice': 'assets/categories/keyboard.jpg',
    'Beer, Wine & Spirits': 'assets/categories/wine, beer and spirit.jpg',
    'Food Cupboard': 'assets/categories/food cupboard.jpg',
    'House Hold Cleaning': 'assets/categories/house hold cleaning.jpg',
    'Fresh Produce': 'assets/categories/fresh produce.jpg',
    'Dairy & Eggs': 'assets/categories/diary and eggs.jpg',
    'Seafood': 'assets/categories/seafood.jpg',
    'Car Care': 'assets/categories/car cares.jpg',
    'Car Exterior and Interior Accessories':
        'assets/categories/car exterior and interrior.jpg',
    'Tools & Equipment': 'assets/categories/tools and equipment.jpg',
    'Oils & Fluids': 'assets/categories/oils and fluids.jpg',
    'Car Safety': 'assets/categories/car safety.jpg',
    'Performance Parts': 'assets/categories/peformance part.jpg',
    'Cardio Training': 'assets/categories/Cardio traning.jpg',
    'Strength & Training Equipment':
        'assets/categories/strength and traning.jpg',
    'Team Sports': 'assets/categories/teams sport.jpg',
    'Outdoor & Adventures':
        'assets/categories/outdoor and adventures images.jpg',
    'Fitness Trackers': 'assets/categories/fitness trackers.jpg',
    'Yoga & Pilates': 'assets/categories/yoga and pilates.jpg',
    'Swimming': 'assets/categories/swimming.jpg',
    'Cycling': 'assets/categories/cycling.jpg',
    'Camping & Hiking': 'assets/categories/camping and hiking.jpg',
    'Golf': 'assets/categories/Golf.jpg',
    'Martial Arts': 'assets/categories/martial arts.jpg',
    'Play Station': 'assets/categories/play station.jpg',
    'Xbox': 'assets/categories/xbox.jpg',
    'Nintendo': 'assets/categories/nintendo.jpg',
    'PC Gaming': 'assets/categories/pc gaming.jpg',
    'Gaming Consoles': 'assets/categories/gaming console.jpg',
    'Video Games': 'assets/categories/video gaming.jpg',
    'Gaming Accessories': 'assets/categories/gaming accessories.jpg',
    'VR Headsets': 'assets/categories/VR gaming.jpg',
    'Arcade Games': 'assets/categories/arcade game.jpg',
    'Board Games': 'assets/categories/board game.jpg',
    'Card Games': 'assets/categories/card game.jpg',
    'Puzzles': 'assets/categories/puzzle.jpg',
    'Apparels & Accessories': 'assets/categories/apparel and accessories.jpg',
    'Diapering': 'assets/categories/diapering.jpg',
    'Feeding': 'assets/categories/feeding.jpg',
    'Baby Toddlers Toys': 'assets/categories/baby toddler and toys.jpg',
    'Gears': 'assets/categories/baby gear.jpg',
    'Bathing & Skin Care': 'assets/categories/baby bathing and skin cares.jpg',
    'Potty Training': 'assets/categories/potty tranning.jpg',
    'Safety': 'assets/categories/baby safety.jpg',
    'Nursery Furniture': 'assets/categories/nursery furniture.jpg',
    'Strollers & Prams': 'assets/categories/stroller and prams.jpg',
    'Car Seats': 'assets/categories/baby car sit.jpg',
    'Fiction Books': 'assets/categories/fiction_books.jpg',
    'Comics': 'assets/categories/comic_books.jpg',
    'Technology': 'assets/categories/AI BOOK.jpg',
    'Business': 'assets/categories/business_books.jpg',
    'Story': 'assets/categories/story_books.jpg',
    'Religious': 'assets/categories/religious_book.jpg',
    'Non-Fiction': 'assets/categories/non-fiction.jpg',
    'Academic Textbooks': 'assets/categories/academic_text_book.jpg',
    'Children Books': 'assets/categories/children_books.jpg',
    'Magazines': 'assets/categories/magazines.jpg',
    'Writing Instruments': 'assets/categories/Writing_instruments.jpg',
    'Office Supplies': 'assets/categories/Office_Supplies.jpg',
    'Art Supplies': 'assets/categories/art_supplies.jpg',
    'Calendars & Planners': 'assets/categories/calenders_planners.jpg',
    'Chicken Feeds': 'assets/categories/Chicken_feeds.jpg',
    'Dog Feeds': 'assets/categories/dog_feeds.jpg',
    'Cat Feeds': 'assets/categories/cat_feed.jpg',
    'Fish Feeds': 'assets/categories/fish_feeds.jpg',
    'Pig Feeds': 'assets/categories/pig_feeds.jpg',
    'Pet Accessories': 'assets/categories/pet_accessories.jpg',
    'Pet Health & Care': 'assets/categories/pet_health_care.jpg',
    'Pet Toys': 'assets/categories/pet_toys.jpg',
    'Pet Clothing': 'assets/categories/pet_clothing.jpg',
    'Pet Grooming': 'assets/categories/Pet grooming.jpg',
    'Aquarium Supplies': 'assets/categories/aquarium_supplies.jpg',
    'Bird Supplies': 'assets/categories/Bird_supplies.jpg',
    'Building Materials': 'assets/categories/building_materials.jpg',
    'Electrical': 'assets/categories/Electrical.jpg',
    'Plumbing': 'assets/categories/plumbing.jpg',
    'Tools & Machinery': 'assets/categories/tools_machinery.jpg',
    'Safety Equipment': 'assets/categories/safety_equipment.jpg',
    'Paints & Coatings': 'assets/categories/painting_coating.jpg',
    'Hardware': 'assets/categories/hardware.jpg',
    'Lab Equipment': 'assets/categories/lab_equipment.jpg',
    'Packaging & Shipping': 'assets/categories/packaging_shipping.jpg',
    'Janitorial & Sanitation': 'assets/categories/janitor_Sanitation.jpg',
    'Guitars': 'assets/categories/guitars.jpg',
    'Keyboards & Pianos': 'assets/categories/keybaord_pianos.jpg',
    'Wind Instruments': 'assets/categories/wind_instruments.jpg',
    'Audio Equipment': 'assets/categories/audio_equipment.jpg',
    'Painting': 'assets/categories/painting_images.jpg',
    'Beading & Jewelry Making': 'assets/categories/bead_making_tools.jpg',
    'Clay & Pottery': 'assets/categories/clay and pottery.jpg',
    'Fertilizers': 'assets/categories/fertilizer.jpg',
    'Pesticides': 'assets/categories/Pesticides.jpg',
    'Fine Jewelry': 'assets/categories/fine_jewelry.jpg',
    'Fashion Jewelry': 'assets/categories/fashion_jewelry.jpg',
    'Wrist Watches': 'assets/categories/watches.jpg',
    'Dolls': 'assets/categories/dolls.jpg',
    'Educational Toys': 'assets/categories/educational_toys.jpg',
    'Outdoor Toys': 'assets/categories/outdoor_toys.jpg',
    'Remote Control Toys': 'assets/categories/remote_control_cars.jpg',
    'Stuffed Animals': 'assets/categories/stuffed_animals.jpg',
    'Toy Vehicles': 'assets/categories/toy_vehicle.jpg',
    'Cameras': 'assets/categories/cameras.jpg',
    'Lenses': 'assets/categories/lenses.jpg',
    'Lighting Equipment': 'assets/categories/lightning.jpg',
    'Camera Bags & Cases': 'assets/categories/camera_bags.jpg',
    'Tripods & Supports': 'assets/categories/tripod_supports.jpg',
    'Restaurant Equipment': 'assets/categories/restuarant_equipment.jpg',
    'Catering Supplies': 'assets/categories/catering_supplies.jpg',
    'Baking Supplies': 'assets/categories/baking_supplies.jpg',
    'Food Processing': 'assets/categories/food_processor.jpg',
    'Beverage Equipment': 'assets/categories/beverage_equipment.jpg',
    'Kitchen Utensils': 'assets/categories/kitchen_utensils.jpg',
    'Food Packaging': 'assets/categories/food_packaging.jpg',
    'Travel Accessories': 'assets/categories/travel_accessories.jpg',
    'Luggage': 'assets/categories/luggage.jpg',
    'Hotel Supplies': 'assets/categories/hotel_supplies.jpg',
    'Wedding Attire': 'assets/categories/wedding_attire.jpg',
  };

  List<MapEntry<String, List<String>>> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _filteredCategories = _allCategories.entries.toList();
    _activeSection = _filteredCategories.isNotEmpty
        ? _filteredCategories.first.key
        : null;
    _searchController.addListener(_onSearchChanged);
    _rightPaneController.addListener(_syncActiveSectionFromScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _leftPaneController.dispose();
    _rightPaneController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredCategories = _allCategories.entries.toList();
      } else {
        _filteredCategories = _allCategories.entries.where((entry) {
          final mainCategoryMatches = entry.key.toLowerCase().contains(
            _searchQuery,
          );
          final subCategoryMatches = entry.value.any(
            (subcat) => subcat.toLowerCase().contains(_searchQuery),
          );
          final combinedMatches = entry.value.any(
            (subcat) =>
                "${entry.key} > $subcat".toLowerCase().contains(_searchQuery),
          );
          return mainCategoryMatches || subCategoryMatches || combinedMatches;
        }).toList();
      }

      _activeSection = _filteredCategories.isNotEmpty
          ? _filteredCategories.first.key
          : null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredCategories = _allCategories.entries.toList();
      _activeSection = _filteredCategories.isNotEmpty
          ? _filteredCategories.first.key
          : null;
    });
  }

  void _handleSidebarTap(BuildContext context, String categoryName) {
    setState(() => _activeSection = categoryName);
    _handleCategoryTap(context, categoryName, null);
  }

  void _showPharmacyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: borderGrey,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Pharmacy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: secondaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to continue.',
                style: TextStyle(fontSize: 13.5, color: lightGrey),
              ),
              const SizedBox(height: 18),
              _buildBottomSheetAction(
                icon: Icons.chat_outlined,
                iconColor: primaryNavy,
                title: 'Consult Pharmacist',
                subtitle: 'Chat for guidance before placing an order.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildBottomSheetAction(
                icon: Icons.storefront_outlined,
                iconColor: accentGreen,
                title: 'Pharmacy Store',
                subtitle: 'Browse medicine and health products.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryProductsScreen(
                        category: 'Health & Beauty > Medicine',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetAction({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: secondaryBlack,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: lightGrey,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: lightGrey),
          ],
        ),
      ),
    );
  }

  void _handleCategoryTap(
    BuildContext context,
    String mainCategory,
    String? subCategory,
  ) {
    if (subCategory == 'Medicine') {
      _showPharmacyOptions(context);
      return;
    }

    final categoryString = subCategory != null
        ? '$mainCategory > $subCategory'
        : mainCategory;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(category: categoryString),
      ),
    );
  }

  String _getImageForSubCategory(String subCategoryName) {
    return _subCategoryImages[subCategoryName] ??
        'https://via.placeholder.com/48';
  }

  bool _isAssetImage(String imagePath) {
    return imagePath.startsWith('assets/');
  }

  Widget _buildImageWidget(
    String imagePath, {
    double width = 48,
    double height = 48,
    BoxFit fit = BoxFit.cover,
  }) {
    if (_isAssetImage(imagePath)) {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
        },
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF3F4F6),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryNavy),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.error_outline, color: Colors.grey),
        ),
      );
    }
  }

  void _syncActiveSectionFromScroll() {
    if (!mounted || _searchQuery.isNotEmpty || _filteredCategories.isEmpty) {
      return;
    }

    final viewportContext = _rightPaneViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    const activationOffset = 28.0;

    String? candidate;
    double closestPastSection = double.infinity;
    String? fallback;
    double closestFutureSection = double.infinity;

    for (final entry in _filteredCategories) {
      final sectionContext = _sectionKeys[entry.key]?.currentContext;
      final sectionBox = sectionContext?.findRenderObject() as RenderBox?;
      if (sectionBox == null || !sectionBox.hasSize) continue;

      final sectionTop = sectionBox.localToGlobal(Offset.zero).dy - viewportTop;

      if (sectionTop <= activationOffset) {
        final distance = activationOffset - sectionTop;
        if (distance < closestPastSection) {
          closestPastSection = distance;
          candidate = entry.key;
        }
      } else if (sectionTop < closestFutureSection) {
        closestFutureSection = sectionTop;
        fallback = entry.key;
      }
    }

    final nextActiveSection = candidate ?? fallback;
    if (nextActiveSection == null || nextActiveSection == _activeSection) {
      return;
    }

    setState(() {
      _activeSection = nextActiveSection;
    });
    _bringSidebarItemIntoView(nextActiveSection);
  }

  void _bringSidebarItemIntoView(String categoryName) {
    final key = _sidebarKeys[categoryName];
    final context = key?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.25,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderGrey.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: lightGrey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search categories or products...',
                hintStyle: TextStyle(color: lightGrey, fontSize: 14),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: secondaryBlack),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: lightGrey, size: 20),
              onPressed: _clearSearch,
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactLayout = screenWidth < 390;
    final sidebarWidth = screenWidth < 360
        ? 106.0
        : screenWidth < 430
        ? 118.0
        : 128.0;
    final sidebarHeaderPadding = EdgeInsets.fromLTRB(
      isCompactLayout ? 10 : 14,
      isCompactLayout ? 8 : 10,
      isCompactLayout ? 8 : 12,
      isCompactLayout ? 6 : 8,
    );
    final sidebarItemPadding = EdgeInsets.symmetric(
      horizontal: isCompactLayout ? 4 : 6,
      vertical: 1,
    );
    final sidebarTilePadding = EdgeInsets.fromLTRB(
      isCompactLayout ? 10 : 12,
      isCompactLayout ? 10 : 12,
      isCompactLayout ? 8 : 10,
      isCompactLayout ? 10 : 12,
    );

    return Scaffold(
      backgroundColor: white,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: white,
              foregroundColor: secondaryBlack,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 18,
              title: const Text(
                'Categories',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: secondaryBlack,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: borderGrey.withValues(alpha: 0.7),
                ),
              ),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _buildSearchBar(),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: sidebarWidth,
                    decoration: BoxDecoration(
                      color: white,
                      border: Border(
                        right: BorderSide(
                          color: borderGrey.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: sidebarHeaderPadding,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                color: secondaryBlack,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: _leftPaneController,
                            padding: const EdgeInsets.only(bottom: 16),
                            children: [
                              ..._filteredCategories.map((entry) {
                                final categoryName = entry.key;
                                final isActive = _activeSection == categoryName;
                                final sidebarKey = _sidebarKeys.putIfAbsent(
                                  categoryName,
                                  () => GlobalKey(),
                                );

                                return Padding(
                                  key: sidebarKey,
                                  padding: sidebarItemPadding,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _handleSidebarTap(
                                      context,
                                      categoryName,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      constraints: BoxConstraints(
                                        minHeight: isCompactLayout ? 44 : 48,
                                      ),
                                      padding: sidebarTilePadding,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? primaryNavy.withValues(
                                                alpha: 0.04,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border(
                                          left: BorderSide(
                                            color: isActive
                                                ? accentGreen
                                                : Colors.transparent,
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        categoryName,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: isCompactLayout
                                              ? 11.8
                                              : 12.6,
                                          height: isCompactLayout ? 1.24 : 1.3,
                                          color: isActive
                                              ? secondaryBlack
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: softGrey,
                      key: _rightPaneViewportKey,
                      child: _searchQuery.isNotEmpty
                          ? _buildSearchResults()
                          : _buildCategorySections(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 14),
                Text(
                  'No categories found for "$_searchQuery"',
                  style: const TextStyle(
                    color: secondaryBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try another keyword or browse from the category list.',
                  style: TextStyle(
                    color: lightGrey,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final entry = _filteredCategories[index];
        final section = entry.key;
        final subcategories = entry.value;

        final mainCategoryMatches = section.toLowerCase().contains(
          _searchQuery,
        );
        final matchingSubcategories = subcategories
            .where((subcat) => subcat.toLowerCase().contains(_searchQuery))
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryNavy.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcons[section] ?? Ionicons.grid_outline,
                color: primaryNavy,
              ),
            ),
            title: Text(
              section,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: secondaryBlack,
              ),
            ),
            subtitle: matchingSubcategories.isNotEmpty && !mainCategoryMatches
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Matches: ${matchingSubcategories.take(2).join(", ")}${matchingSubcategories.length > 2 ? "..." : ""}',
                      style: const TextStyle(color: lightGrey, fontSize: 12.5),
                    ),
                  )
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            children: subcategories.map((subcat) {
              final isExactMatch = subcat.toLowerCase().contains(_searchQuery);
              final imagePath = _getImageForSubCategory(subcat);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageWidget(imagePath, width: 34, height: 34),
                  ),
                ),
                title: Text(
                  subcat,
                  style: TextStyle(
                    fontWeight: isExactMatch
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isExactMatch ? primaryNavy : Colors.black87,
                    fontSize: 13.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: lightGrey,
                ),
                onTap: () => _handleCategoryTap(context, section, subcat),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCategorySections() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactLayout = screenWidth < 390;

    return ListView.separated(
      controller: _rightPaneController,
      padding: EdgeInsets.fromLTRB(
        isCompactLayout ? 12 : 16,
        isCompactLayout ? 12 : 14,
        isCompactLayout ? 12 : 16,
        isCompactLayout ? 24 : 32,
      ),
      itemCount: _filteredCategories.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: isCompactLayout ? 22 : 28),
      itemBuilder: (context, index) {
        final entry = _filteredCategories[index];
        final sectionName = entry.key;
        final items = entry.value;

        final sectionKey = _sectionKeys.putIfAbsent(
          sectionName,
          () => GlobalKey(),
        );

        return Column(
          key: sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: isCompactLayout ? 12 : 14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primaryNavy,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _handleCategoryTap(context, sectionName, null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          sectionName,
                          style: TextStyle(
                            fontSize: isCompactLayout ? 16.5 : 18,
                            fontWeight: FontWeight.w800,
                            color: secondaryBlack,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _handleCategoryTap(context, sectionName, null),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryNavy,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactLayout ? 8 : 10,
                        vertical: isCompactLayout ? 6 : 8,
                      ),
                    ),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isCompactLayout ? 12.2 : 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final useThreeColumns = constraints.maxWidth >= 430;
                final useTwoColumnMobileGrid = !useThreeColumns;
                final crossAxisCount = useThreeColumns ? 3 : 2;
                final tileHeight = useThreeColumns
                    ? 156.0
                    : isCompactLayout
                    ? 152.0
                    : 160.0;
                final tileImageSize = useThreeColumns
                    ? 62.0
                    : isCompactLayout
                    ? 50.0
                    : 56.0;
                final gridSpacing = isCompactLayout ? 10.0 : 14.0;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: tileHeight,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final subcat = items[i];
                    final imagePath = _getImageForSubCategory(subcat);

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () =>
                            _handleCategoryTap(context, sectionName, subcat),
                        child: Container(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(
                              isCompactLayout ? 16 : 18,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: useTwoColumnMobileGrid ? 8 : 8,
                              vertical: useTwoColumnMobileGrid ? 10 : 10,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: tileImageSize,
                                  width: tileImageSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: const Color(0xFFF4F7FB),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildImageWidget(
                                      imagePath,
                                      width: tileImageSize,
                                      height: tileImageSize,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: useTwoColumnMobileGrid ? 2 : 4,
                                  ),
                                  child: Text(
                                    subcat,
                                    textAlign: TextAlign.center,
                                    maxLines: useTwoColumnMobileGrid ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: useTwoColumnMobileGrid
                                          ? 11.8
                                          : isCompactLayout
                                          ? 11.8
                                          : 12.2,
                                      height: useTwoColumnMobileGrid
                                          ? 1.24
                                          : 1.3,
                                      fontWeight: FontWeight.w600,
                                      color: secondaryBlack,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
