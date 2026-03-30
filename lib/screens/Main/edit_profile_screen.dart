// lib/screens/Main/EditProfileScreen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants.dart';
import '../../models/user.dart';

// Defined custom colors for consistency
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  File? _pickedImage;
  String _currentProfilePicUrl = 'https://placehold.co/100x100/CCCCCC/000000?text=User';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // Helper method to build proper profile picture URL
  String _buildProfilePicUrl(String? profilePicPath) {
    if (profilePicPath == null || profilePicPath.isEmpty) {
      return 'https://placehold.co/100x100/CCCCCC/000000?text=User';
    }
    
    // If it's already a full URL, return as is
    if (profilePicPath.startsWith('http://') || profilePicPath.startsWith('https://')) {
      return profilePicPath;
    }
    
    // If it starts with /, append to baseUrl
    if (profilePicPath.startsWith('/')) {
      return '$baseUrl$profilePicPath';
    }
    
    // Otherwise, assume it's relative to baseUrl/uploads/
    return '$baseUrl/uploads/$profilePicPath';
  }

  Future<void> _fetchCurrentUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final User user = User.fromJson(responseData);

        _firstNameController.text = user.firstName;
        _lastNameController.text = user.lastName;
        _emailController.text = user.email;
        _phoneNumberController.text = user.phoneNumber;

        setState(() {
          final String? fetchedProfilePicPath = responseData['profilePicUrl']; 
          _currentProfilePicUrl = _buildProfilePicUrl(fetchedProfilePicPath);
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to fetch profile data.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e. Check network or backend.';
      });
      debugPrint('Error fetching user profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in.';
        _isLoading = false;
      });
      return;
    }

    try {
      String? base64Image;
      if (_pickedImage != null) {
        List<int> imageBytes = await _pickedImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      final updateData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'profilePicBase64': ?base64Image,
      };

      final Uri url = Uri.parse('$baseUrl/api/auth/profile');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic>? updatedUser = responseData['user'];
        final String? newProfilePicPath = updatedUser?['profilePicUrl'];
        
        if (newProfilePicPath != null && newProfilePicPath.isNotEmpty) {
          setState(() {
            // Use the helper method to build the URL
            _currentProfilePicUrl = _buildProfilePicUrl(newProfilePicPath);
            
            // Add cache busting parameter for immediate refresh
            if (!_currentProfilePicUrl.contains('?')) {
              _currentProfilePicUrl = '$_currentProfilePicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
            }
            
            _pickedImage = null; // clear local selection since backend has it
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Profile updated successfully!')),
        );

        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to update profile.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e. Check network or backend.';
        });
      }
      debugPrint('Error saving profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: greenYellow)),
        backgroundColor: deepNavyBlue,
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: _isLoading && _errorMessage == null
          ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: deepNavyBlue.withValues(alpha: 0.2),
                            child: ClipOval(
                              child: SizedBox.expand(
                                child: _pickedImage != null
                                    ? Image.file(
                                        _pickedImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: _currentProfilePicUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(color: deepNavyBlue),
                                        ),
                                        errorWidget: (context, url, error) {
                                          return const Center(
                                              child: Icon(Icons.person, size: 60, color: Colors.grey));
                                        },
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              backgroundColor: deepNavyBlue,
                              radius: 20,
                              child: const Icon(Icons.camera_alt, color: greenYellow, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _inputDecoration('First Name'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your first name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: _inputDecoration('Last Name'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your last name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Phone Number'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
                          : ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: deepNavyBlue,
                                foregroundColor: greenYellow,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Update Profile', style: TextStyle(fontSize: 18)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: deepNavyBlue.withValues(alpha: 0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: deepNavyBlue.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: deepNavyBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: deepNavyBlue.withValues(alpha: 0.3)),
      ),
      filled: true,
      fillColor: whiteBackground,
    );
  }
}
