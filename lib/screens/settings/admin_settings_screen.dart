import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../core/namkeen_theme.dart';
import '../../models/company_settings_model.dart';
import '../../services/database_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _companyNameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _gstRateCtrl;
  
  bool _useThermal80mm = true;
  bool _preferA4 = false;
  bool _showLogo = true;
  String? _logoBase64;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
       final bytes = await image.readAsBytes();
       final String base64String = base64Encode(bytes);
       setState(() {
         _logoBase64 = base64String;
       });
    }
  }
  
  // Existing data
  CompanySettingsModel? _currentSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _companyNameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _gstCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _termsCtrl = TextEditingController();
    _gstRateCtrl = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    // Since getCompanySettings is a stream, we can listen or just get once via standard stream builder pattern.
    // But since this is an edit form, pre-filling is easier with a single fetch if we had a get method.
    // We'll use the stream.first pattern for initial fill.
    final settings = await db.getCompanySettings().first;
    
    setState(() {
      _currentSettings = settings;
      _companyNameCtrl.text = settings.companyName;
      _addressCtrl.text = settings.address;
      _phoneCtrl.text = settings.phone;
      _gstCtrl.text = settings.gstNumber;
      _footerCtrl.text = settings.footerMessage;
      _termsCtrl.text = settings.termsAndConditions;
      _gstRateCtrl.text = settings.gstRate.toString();
      _useThermal80mm = settings.useThermal80mm;
      _preferA4 = settings.preferA4;
      _showLogo = settings.showLogo; // Initialized from settings
      _logoBase64 = settings.logoBase64; // Initialized from settings
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Bill / Receipt Header'),
              _buildTextField('Company / Factory Name', _companyNameCtrl),
              _buildTextField('Address', _addressCtrl, maxLines: 3),
              _buildTextField('Phone Number', _phoneCtrl, keyboardType: TextInputType.phone),
              _buildTextField('GST Number', _gstCtrl),
              _buildTextField('GST Rate (%)', _gstRateCtrl, keyboardType: TextInputType.number, hint: 'e.g. 12.0'),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Bill Footer & Terms'),
              _buildTextField('Footer Message', _footerCtrl, hint: 'e.g. Thank you for your business'),
              _buildTextField('Terms & Conditions', _termsCtrl, maxLines: 2),

              const SizedBox(height: 24),
              _buildSectionHeader('Print Format Preferences'),
              SwitchListTile(
                title: const Text('Prioritize A4 Prints?'),
                subtitle: const Text('If enabled, default print action will use PDF A4 format.'),
                value: _preferA4,
                onChanged: (val) => setState(() => _preferA4 = val),
              ),
              SwitchListTile(
                title: const Text('Use 80mm Thermal Width?'),
                subtitle: Text(_useThermal80mm ? 'Yes (80mm)' : 'No (58mm)'),
                value: _useThermal80mm,
                onChanged: (val) => setState(() => _useThermal80mm = val),
              ),
              
  // ... 

              const SizedBox(height: 24),
              _buildSectionHeader('Support & Branding'),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                       const Text('Need Help? Contact Support:', style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 4),
                       SelectableText('Manav Nagpal: +91 9896817707\nEmail: manav.nagpal2005@gmail.com', textAlign: TextAlign.center),
                       const SizedBox(height: 8),
                       const Text('Powered by FLIP CLIP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                       
                       const Divider(),
                       SwitchListTile(
                         title: const Text('Show Logo on Invoice'),
                         value: _showLogo,
                         onChanged: (v) => setState(() => _showLogo = v),
                       ),
                       if (_showLogo) ...[
                         const SizedBox(height: 8),
                         Center(
                           child: _logoBase64 != null 
                             ? Image.memory(base64Decode(_logoBase64!), height: 80)
                             : Image.asset('assets/images/logo.png', height: 80, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, size: 50)),
                         ),
                         const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload),
                                label: const Text('Upload Logo'),
                                onPressed: _pickImage,
                              ),
                              if (_logoBase64 != null) ...[
                                const SizedBox(width: 8),
                                 TextButton(
                                   onPressed: () => setState(() => _logoBase64 = null),
                                   child: const Text('Reset to Default'),
                                 )
                              ]
                           ]
                         ),
                       ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('To change the Invoice Logo, please replace the file "assets/images/logo.png" in the application folder.', style: TextStyle(color: Colors.grey, fontSize: 12)),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final newSettings = _currentSettings!.copyWith(
      companyName: _companyNameCtrl.text,
      address: _addressCtrl.text,
      phone: _phoneCtrl.text,
      gstNumber: _gstCtrl.text,
      footerMessage: _footerCtrl.text,
      termsAndConditions: _termsCtrl.text,
      useThermal80mm: _useThermal80mm,
      preferA4: _preferA4,
      gstRate: double.tryParse(_gstRateCtrl.text) ?? 12.0,
      showLogo: _showLogo, // Added
      logoBase64: _logoBase64, // Added
    );

    try {
      await db.saveCompanySettings(newSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved & Updated Properly!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
