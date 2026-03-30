import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants.dart';
import '../../widgets/vendor_ui.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockQuantityController = TextEditingController();

  // SEARCH CONTROLLER
  final TextEditingController _searchController = TextEditingController();

  // FULL CATEGORIES MAP
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
    'Arts & Crafts': [
      'Painting',
      'Beading & Jewelry Making',
      'Clay & Pottery',
    ],
    'Agriculture': [
      'Fertilizers',
      'Pesticides',
    ],
    'Jewelry & Watches': [
      'Fine Jewelry',
      'Fashion Jewelry',
      'Wrist Watches',
    ],
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
    'Travel & Tourism': [
      'Travel Accessories',
      'Luggage',
      'Hotel Supplies',
    ],
    'Wedding & Events': [
      'Wedding Attire',
    ],
  };

  // NEW: Categories that REQUIRE size selection
  final Set<String> _sizeRequiredCategories = {
    "Men's Fashion",
    "Women's Fashion",
    "Kids' Fashion",
    'Footwear',
    'Sportswear',
    'Underwear & Lingerie',
    'Belts & Accessories',
    'Traditional Attire',
    'Watches',
    'Pet Clothing',
    'Wedding Attire',
    'Apparels & Accessories', // Baby Products
  };

  // NEW: Categories that OPTIONALLY can have size
  final Set<String> _sizeOptionalCategories = {
    'Furniture',
    'Bedding & Bath',
    'Luggages & Travel Gear',
    'Bags & Purses',
    'Mattresses',
    'TVs & Monitors',
    'Strollers & Prams',
    'Car Seats',
    'Luggage',
  };

  // NEW: Size state variables - CHANGED TO MULTIPLE SELECTION
  String? _selectedCategory;
  String? _selectedSizeType;
  Set<String> _selectedSizes = {}; // CHANGED: Now a Set for multiple selection
  final Map<String, dynamic> _customSize = {
    'length': '',
    'width': '',
    'height': '',
    'unit': 'cm',
  };
  bool _showSizeSection = false;
  bool _isSizeRequired = false;
  bool _showCustomSizeFields = false;

  // NEW: For multiple custom sizes
  final List<Map<String, dynamic>> _customSizes = [];

  // Standard size options
  final Map<String, List<String>> _standardSizes = {
    'clothing': ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'],
    'shoes': List.generate(20, (index) => (index + 30).toString()), // 30-49
    'watches': ['38mm', '40mm', '42mm', '44mm', '46mm'],
    'baby': ['Newborn', '0-3M', '3-6M', '6-9M', '9-12M', '12-18M', '18-24M'],
    'pet': ['XS', 'S', 'M', 'L', 'XL'],
  };

  File? _mainImage;
  final List<File> _extraImages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFlashSale = false;
  static const int _maxExtraImages = 10;

  // For search functionality
  String _searchQuery = '';
  List<MapEntry<String, List<String>>> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _filteredCategories = _allCategories.entries.toList();
    _searchController.addListener(_onSearchChanged);
    // Initialize with one custom size
    _customSizes.add(_customSize);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQuantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // NEW: Check if selected category needs size
  void _checkSizeRequirements(String? category) {
    if (category == null) {
      setState(() {
        _showSizeSection = false;
        _isSizeRequired = false;
        _selectedSizeType = null;
        _selectedSizes.clear();
        _showCustomSizeFields = false;
      });
      return;
    }

    // Extract subcategory from "Main Category > Subcategory" format
    final subcategory = category.split(' > ').last;
    
    final requiresSize = _sizeRequiredCategories.contains(subcategory);
    final optionalSize = _sizeOptionalCategories.contains(subcategory);
    
    setState(() {
      _showSizeSection = requiresSize || optionalSize;
      _isSizeRequired = requiresSize;
      _selectedSizeType = null;
      _selectedSizes.clear();
      _showCustomSizeFields = false;
      
      // Auto-select size type based on category
      if (requiresSize || optionalSize) {
        if (subcategory == 'Footwear') {
          _selectedSizeType = 'shoes';
        } else if (subcategory == 'Watches') {
          _selectedSizeType = 'watches';
        } else if (subcategory.contains('Apparel') || 
                   subcategory.contains('Fashion') || 
                   subcategory == 'Sportswear' ||
                   subcategory == 'Wedding Attire') {
          _selectedSizeType = 'clothing';
        } else if (subcategory == 'Pet Clothing') {
          _selectedSizeType = 'pet';
        } else if (subcategory == 'Apparels & Accessories') {
          _selectedSizeType = 'baby';
        }
      }
    });
  }

  // NEW: Get appropriate size options based on type
  List<String> _getSizeOptions(String? type) {
    return _standardSizes[type] ?? [];
  }

  // NEW: Toggle size selection (multiple)
  void _toggleSizeSelection(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        _selectedSizes.remove(size);
      } else {
        _selectedSizes.add(size);
      }
    });
  }

  // NEW: Add a new custom size field
  void _addCustomSize() {
    setState(() {
      _customSizes.add({
        'length': '',
        'width': '',
        'height': '',
        'unit': 'cm',
      });
    });
  }

  // NEW: Remove a custom size field
  void _removeCustomSize(int index) {
    setState(() {
      if (_customSizes.length > 1) {
        _customSizes.removeAt(index);
      }
    });
  }

  // NEW: Update custom size field
  void _updateCustomSize(int index, String key, String value) {
    setState(() {
      _customSizes[index][key] = value;
    });
  }

  // NEW: Build size selection widget with MULTIPLE selection
  Widget _buildSizeSelection() {
    if (!_showSizeSection) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with counter
          Row(
            children: [
              Icon(
                Icons.straighten,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Available Sizes ${_isSizeRequired ? '(Required)' : '(Optional)'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Show count of selected sizes
              if (_selectedSizes.isNotEmpty || _showCustomSizeFields)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _showCustomSizeFields
                        ? '${_customSizes.length} custom'
                        : '${_selectedSizes.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Help text
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Text(
              'Select all sizes available for this product. Buyers will choose from these options.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          
          // Size Type Selection
          DropdownButtonFormField<String>(
            initialValue: _selectedSizeType,
            decoration: InputDecoration(
              labelText: 'Size Type',
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: [
              if (_selectedCategory?.contains('Footwear') ?? false)
                _buildSizeTypeItem('shoes', '👟 Shoes'),
              if (_selectedCategory?.contains('Watches') ?? false)
                _buildSizeTypeItem('watches', '⌚ Watches'),
              if (_selectedCategory?.contains('Apparels & Accessories') ?? false)
                _buildSizeTypeItem('baby', '👶 Baby Clothing'),
              if (_selectedCategory?.contains('Pet Clothing') ?? false)
                _buildSizeTypeItem('pet', '🐾 Pet Clothing'),
              _buildSizeTypeItem('clothing', '👕 Clothing (XS-XXXL)'),
              _buildSizeTypeItem('custom', '📏 Custom Dimensions'),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSizeType = value;
                _selectedSizes.clear();
                _showCustomSizeFields = value == 'custom';
              });
            },
            validator: _isSizeRequired ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a size type';
              }
              return null;
            } : null,
          ),
          
          const SizedBox(height: 20),
          
          // Standard Size Selection - MULTIPLE SELECTION
          if (_selectedSizeType != null && 
              _selectedSizeType != 'custom' && 
              !_showCustomSizeFields)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Select Available Sizes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    // Select All / Clear All buttons
                    if (_getSizeOptions(_selectedSizeType).isNotEmpty)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedSizes.length == _getSizeOptions(_selectedSizeType).length) {
                                  _selectedSizes.clear();
                                } else {
                                  _selectedSizes = Set.from(_getSizeOptions(_selectedSizeType));
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              _selectedSizes.length == _getSizeOptions(_selectedSizeType).length
                                  ? 'Clear All'
                                  : 'Select All',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Size selection grid with checkboxes
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _getSizeOptions(_selectedSizeType).map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return GestureDetector(
                        onTap: () => _toggleSizeSelection(size),
                        child: Container(
                          width: 70,
                          height: 45,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Selected sizes preview
                if (_selectedSizes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected sizes (${_selectedSizes.length}):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedSizes.map((size) {
                            return Chip(
                              label: Text(size),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => _toggleSizeSelection(size),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                
                if (_isSizeRequired && _selectedSizes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '⚠️ Please select at least one size for this product',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          
          // Custom Size Fields - MULTIPLE
          if (_showCustomSizeFields)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Custom Dimensions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    // Add more custom sizes button
                    ElevatedButton.icon(
                      onPressed: _addCustomSize,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Another'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                
                // Multiple custom size fields
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _customSizes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final size = _customSizes[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_customSizes.length > 1)
                            Row(
                              children: [
                                Text(
                                  'Custom Size #${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const Spacer(),
                                if (_customSizes.length > 1)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeCustomSize(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Length',
                                    hintText: 'e.g., 120',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) =>
                                      _updateCustomSize(index, 'length', value),
                                  validator: _isSizeRequired ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  } : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Width',
                                    hintText: 'e.g., 80',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) =>
                                      _updateCustomSize(index, 'width', value),
                                  validator: _isSizeRequired ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  } : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Height',
                                    hintText: 'e.g., 60',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) =>
                                      _updateCustomSize(index, 'height', value),
                                  validator: _isSizeRequired ? (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  } : null,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 10),
                          
                          DropdownButtonFormField<String>(
                            initialValue: size['unit'],
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: ['cm', 'inch', 'mm', 'm']
                                .map((unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit.toUpperCase()),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                _updateCustomSize(index, 'unit', value ?? 'cm'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Custom sizes summary
                if (_customSizes.length > 1)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_customSizes.length} custom size variations added. Each will be available for buyers.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          
          // Size Help Text
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_checkout,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How buyers will see this:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getBuyerExperienceText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Helper methods
  DropdownMenuItem<String> _buildSizeTypeItem(String value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Text(label),
        ],
      ),
    );
  }

  String _getBuyerExperienceText() {
    if (_selectedSizeType == 'shoes') {
      return 'Buyers will see: "Available Sizes: [Selected sizes]" and choose their size.';
    } else if (_selectedSizeType == 'clothing') {
      return 'Buyers can select from: ${_selectedSizes.join(", ")}';
    } else if (_showCustomSizeFields) {
      return 'Buyers will see ${_customSizes.length} dimension options.';
    }
    return 'Buyers will choose from your selected sizes at checkout.';
  }

  // NEW: Prepare size data for API submission (now supports multiple)
  Map<String, dynamic>? _getSizeData() {
    if (!_showSizeSection || 
        (_selectedSizeType == null && !_showCustomSizeFields) ||
        (_selectedSizes.isEmpty && _customSizes.isEmpty)) {
      return null;
    }

    if (_showCustomSizeFields) {
      return {
        'type': 'custom',
        'sizes': _customSizes,
        'multiple': _customSizes.length > 1,
      };
    }

    return {
      'type': _selectedSizeType,
      'sizes': _selectedSizes.toList(),
      'multiple': true,
      'unit': _getUnitForType(_selectedSizeType),
    };
  }

  String _getUnitForType(String? type) {
    switch (type) {
      case 'shoes':
        return 'EU';
      case 'watches':
        return 'mm';
      case 'clothing':
      case 'baby':
      case 'pet':
        return 'size';
      default:
        return 'unit';
    }
  }

  // Search filter function
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      
      if (_searchQuery.isEmpty) {
        _filteredCategories = _allCategories.entries.toList();
      } else {
        _filteredCategories = _allCategories.entries
            .where((entry) {
              bool mainCategoryMatches = entry.key.toLowerCase().contains(_searchQuery);
              bool subCategoryMatches = entry.value.any(
                (subcat) => subcat.toLowerCase().contains(_searchQuery)
              );
              bool combinedMatches = entry.value.any(
                (subcat) => "${entry.key} > $subcat".toLowerCase().contains(_searchQuery)
              );
              
              return mainCategoryMatches || subCategoryMatches || combinedMatches;
            })
            .toList();
      }
    });
  }

  // Clear search
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredCategories = _allCategories.entries.toList();
    });
  }

  // Enhanced category dropdown items
  List<DropdownMenuItem<String>> _buildCategoryItems() {
    List<DropdownMenuItem<String>> items = [];

    items.add(
      DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                        onPressed: _clearSearch,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Found ${_filteredCategories.length} main categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    items.add(
      const DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: Divider(),
      ),
    );

    if (_filteredCategories.isEmpty) {
      items.add(
        DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No categories found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      for (var entry in _filteredCategories) {
        final section = entry.key;
        final subcategories = entry.value;

        items.add(
          DropdownMenuItem<String>(
            value: null,
            enabled: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${subcategories.length} subcategories',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        for (var sub in subcategories) {
          items.add(
            DropdownMenuItem<String>(
              value: "$section > $sub",
              child: Padding(
                padding: const EdgeInsets.only(left: 36.0, top: 6, bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.arrow_right_alt,
                        color: Theme.of(context).colorScheme.secondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if ("$section > $sub" == _selectedCategory)
                      Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary, size: 16),
                    // NEW: Show size icon if category needs size
                    if (_sizeRequiredCategories.contains(sub))
                      Icon(Icons.straighten,
                          color: Colors.orange, size: 14),
                  ],
                ),
              ),
            ),
          );
        }

        if (entry != _filteredCategories.last) {
          items.add(
            const DropdownMenuItem<String>(
              value: null,
              enabled: false,
              child: SizedBox(height: 12),
            ),
          );
        }
      }
    }

    return items;
  }

  // Show selected category in a chip
  Widget _buildSelectedCategoryChip() {
    if (_selectedCategory == null) return const SizedBox.shrink();

    final parts = _selectedCategory!.split(' > ');
    if (parts.length != 2) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Selected Category:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
              if (_sizeRequiredCategories.contains(parts[1]))
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.straighten, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Size Required',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  parts[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.primary, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts[1],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages({bool isMain = true}) async {
    final ImagePicker picker = ImagePicker();
    
    setState(() {
      _errorMessage = null;
    });

    if (isMain) {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _mainImage = File(image.path);
        });
      } else {
        setState(() {
          _errorMessage = 'Main image selection cancelled.';
        });
      }
    } else {
      final List<XFile> images = await picker.pickMultiImage();
      if (!mounted) return;
      
      if (images.isNotEmpty) {
        final remainingSlots = _maxExtraImages - _extraImages.length;
        final filesToAdd = images.take(remainingSlots).map((xfile) => File(xfile.path)).toList();
        
        setState(() {
          _extraImages.addAll(filesToAdd);
        });

        if (images.length > remainingSlots) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Only the first $remainingSlots images were added (Max is $_maxExtraImages).')),
          );
        }
      }
    }
  }

  void _removeExtraImage(int index) {
    setState(() {
      _extraImages.removeAt(index);
    });
  }
  
  Future<void> _addProduct() async {
    // NEW: Validate multiple sizes if required
    if (_isSizeRequired) {
      if (_selectedSizeType == null) {
        setState(() {
          _errorMessage = 'Please select a size type for this product.';
        });
        return;
      }
      
      if (_selectedSizeType != 'custom' && _selectedSizes.isEmpty) {
        setState(() {
          _errorMessage = 'Please select at least one size for this product.';
        });
        return;
      }
      
      if (_selectedSizeType == 'custom') {
        for (var customSize in _customSizes) {
          if (customSize['length'].isEmpty || 
              customSize['width'].isEmpty || 
              customSize['height'].isEmpty) {
            setState(() {
              _errorMessage = 'Please fill all custom dimension fields.';
            });
            return;
          }
        }
      }
    }

    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Please complete all required form fields.';
      });
      return;
    }

    if (_mainImage == null) {
      setState(() {
        _errorMessage = 'Please select a main product image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    final double price = double.parse(_priceController.text);
    final int stockQuantity = int.parse(_stockQuantityController.text);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('$baseUrl/api/products');
    var request = http.MultipartRequest('POST', url);

    // Add text fields
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();
    request.fields['category'] = _selectedCategory!;
    request.fields['stockQuantity'] = stockQuantity.toString();
    request.fields['is_flashsale'] = _isFlashSale.toString();

    // NEW: Add multiple size data if available
    final sizeData = _getSizeData();
    if (sizeData != null) {
      request.fields['size_data'] = jsonEncode(sizeData);
    }

    // 1. Add Main Image
    request.files.add(await http.MultipartFile.fromPath(
      'mainImage',
      _mainImage!.path,
      filename: _mainImage!.path.split('/').last,
    ));
    
    // 2. Add Extra Images (if any)
    for (var file in _extraImages) {
      request.files.add(await http.MultipartFile.fromPath(
        'extraImages',
        file.path,
        filename: file.path.split('/').last,
      ));
    }

    request.headers['Authorization'] = 'Bearer $token';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Product added successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Show success message with size info
        if (sizeData != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Product with ${_selectedSizes.length} sizes added!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to add product (Status: ${response.statusCode}).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'A network or processing error occurred: $e';
        });
      }
      debugPrint('Add product network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, ColorScheme color) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: VendorUi.textMuted,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: VendorUi.whiteBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VendorUi.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VendorUi.deepNavyBlue, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VendorUi.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VendorUi.danger, width: 1.3),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VendorUi.theme,
      child: Builder(
        builder: (context) {
          final color = Theme.of(context).colorScheme;

          return Scaffold(
            backgroundColor: VendorUi.surface,
            appBar: AppBar(
              title: const Text('Add Product'),
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VendorPageHero(
                          badge: 'Catalogue publishing',
                          title: 'Add a new product',
                          subtitle:
                              'Bring a new item live with clean visuals, accurate pricing, stock-ready details, and the right category setup.',
                          icon: Icons.add_box_outlined,
                          stats: [
                            VendorHeroStat(
                              label: 'Main image',
                              value: _mainImage == null ? 'Required' : 'Ready',
                            ),
                            VendorHeroStat(
                              label: 'Extra images',
                              value: '${_extraImages.length}/$_maxExtraImages',
                            ),
                            VendorHeroStat(
                              label: 'Flash sale',
                              value: _isFlashSale ? 'On' : 'Off',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        VendorPanel(
                          title: 'Product details',
                          subtitle:
                              'Upload visuals, set pricing, choose the right category, and prepare the product for buyers.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Primary listing information',
                                style: TextStyle(
                                  color: color.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // 1. MAIN IMAGE PICKER (REQUIRED)
                Text('Main Product Image (Required)', style: TextStyle(fontWeight: FontWeight.bold, color: color.primary)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickImages(isMain: true),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: VendorUi.whiteBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _mainImage == null ? VendorUi.danger : VendorUi.border,
                        width: 1,
                      ),
                    ),
                    child: _mainImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Image.file(
                              _mainImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library, size: 50, color: color.primary),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to select Main Image',
                                style: TextStyle(color: color.onSurface, fontSize: 16),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 2. EXTRA IMAGES GALLERY (OPTIONAL)
                Text('Extra Images (Optional, max 10)', style: TextStyle(fontWeight: FontWeight.bold, color: color.primary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: VendorUi.whiteBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: VendorUi.border),
                  ),
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: [
                      ..._extraImages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final file = entry.value;
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.file(
                                file,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: -5,
                              top: -5,
                              child: IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.red[700], size: 20),
                                onPressed: () => _removeExtraImage(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        );
                      }),
                      
                      // Add button
                      if (_extraImages.length < _maxExtraImages)
                        GestureDetector(
                          onTap: () => _pickImages(isMain: false),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: VendorUi.surface,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: VendorUi.border, width: 1.0),
                            ),
                            child: Icon(Icons.add, size: 30, color: color.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Product Name
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Product Name', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Product Description', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Price
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Price', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product price';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Show selected category chip
                _buildSelectedCategoryChip(),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _inputDecoration('Select Category', color),
                  style: TextStyle(color: color.primary, fontSize: 16),
                  icon: Icon(Icons.arrow_drop_down, color: color.primary),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                      // NEW: Check size requirements when category changes
                      _checkSizeRequirements(newValue);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  menuMaxHeight: 500,
                  items: _buildCategoryItems(),
                ),
                const SizedBox(height: 15),

                // NEW: Size Selection Section (Conditional) - NOW MULTIPLE SELECTION
                _buildSizeSelection(),

                // Stock Quantity
                TextFormField(
                  controller: _stockQuantityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: color.primary),
                  decoration: _inputDecoration('Stock Quantity', color),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Please enter a valid non-negative quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Flash Sale Checkbox
                Container(
                  decoration: BoxDecoration(
                    color: VendorUi.whiteBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: VendorUi.border, width: 1.0),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Mark as Flash Sale 🔥',
                      style: TextStyle(color: color.primary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    value: _isFlashSale,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _isFlashSale = newValue ?? false;
                      });
                    },
                    activeColor: color.secondary,
                    checkColor: color.onSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),

                const SizedBox(height: 30),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      '❌ $_errorMessage',
                      style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),

                _isLoading
                    ? Center(child: CircularProgressIndicator(color: color.primary))
                    : ElevatedButton(
                        onPressed: _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VendorUi.deepNavyBlue,
                          foregroundColor: VendorUi.whiteBackground,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Add Product',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
