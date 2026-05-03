import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/neurolens_api_service.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _warmBeige = Color(0xFFF5F0EB);
const _darkText = Color(0xFF2D3436);

class CaregiverImageScreen extends StatefulWidget {
  final String patientId;

  const CaregiverImageScreen({super.key, required this.patientId});

  @override
  State<CaregiverImageScreen> createState() => _CaregiverImageScreenState();
}

class _CaregiverImageScreenState extends State<CaregiverImageScreen> {
  final NeurolensApiService _api = NeurolensApiService();
  static const _secure = FlutterSecureStorage();

  bool _isLoading = false;
  bool _isUploading = false;
  bool _isAuthenticated = false;
  String? _error;
  List<ImageSummary> _summaries = [];
  late String _resolvedPatientId;

  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _patientIdController = TextEditingController();
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _resolvedPatientId = widget.patientId;
    _patientIdController.text = widget.patientId;
    _initialise();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _urlController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _initialise() async {
    await _api.loadBaseUrl();
    _urlController.text = _api.baseUrl;
    if (_resolvedPatientId.isEmpty) return;
    final token = await _secure.read(key: 'cg_tok_$_resolvedPatientId');
    if (token != null && token.isNotEmpty) {
      setState(() => _isAuthenticated = true);
      await _loadSummaries();
    }
  }

  Future<void> _login() async {
    final pid = _patientIdController.text.trim();
    if (pid.isEmpty) {
      setState(() => _error = 'Please enter the patient ID');
      return;
    }
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Please enter the caregiver password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.login(
        patientId: pid,
        password: password,
        role: 'caregiver',
      );
      _resolvedPatientId = pid;
      await _secure.write(key: 'cg_tok_$_resolvedPatientId', value: result.accessToken);
      await _secure.write(key: 'cg_rt_$_resolvedPatientId', value: result.refreshToken);
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
      _passwordController.clear();
      await _loadSummaries();
    } catch (e) {
      setState(() {
        _error = 'Login failed. Check the server URL and credentials.';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getToken() async {
    return _secure.read(key: 'cg_tok_$_resolvedPatientId');
  }

  Future<void> _loadSummaries() async {
    final token = await _getToken();
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final summaries = await _api.fetchImageSummaries(token: token);
      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load summaries';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    Uint8List? bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null) {
      setState(() => _error = 'Could not read selected file');
      return;
    }

    final token = await _getToken();
    if (token == null) {
      setState(() {
        _isAuthenticated = false;
        _error = 'Session expired. Please log in again.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final newSummaries = await _api.uploadImages(
        token: token,
        images: [(filename: file.name, bytes: bytes)],
      );
      setState(() {
        _summaries.insertAll(0, newSummaries);
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Upload failed. Check the server connection.';
        _isUploading = false;
      });
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _api.setBaseUrl(url);
    setState(() => _showSettings = false);
  }

  Future<void> _logout() async {
    await _secure.delete(key: 'cg_tok_$_resolvedPatientId');
    await _secure.delete(key: 'cg_rt_$_resolvedPatientId');
    setState(() {
      _isAuthenticated = false;
      _summaries = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_warmBeige, Color(0xFFE8E0D8)],
          ),
        ),
        child: SafeArea(
          child: _isAuthenticated ? _buildMainContent() : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildBackButton(),
              const Spacer(),
              IconButton(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.settings, color: _primaryTeal),
                tooltip: 'Server Settings',
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image_search, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Connect to Neurolens AI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (widget.patientId.isEmpty) ...[
                      TextField(
                        controller: _patientIdController,
                        decoration: InputDecoration(
                          labelText: 'Patient ID',
                          hintText: 'e.g., P12345',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Caregiver Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Connect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Server Settings', style: TextStyle(color: _darkText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Server URL (ngrok)',
                  hintText: 'https://xxxx.ngrok-free.app',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: _darkText)),
            ),
            TextButton(
              onPressed: () {
                _saveUrl();
                Navigator.of(context).pop();
              },
              child: const Text('Save', style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.bold)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade500,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Patient Login',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryTeal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_search, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Patient: $_resolvedPatientId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showSettings = !_showSettings),
                icon: Icon(Icons.settings, color: _darkText.withOpacity(0.6)),
                tooltip: 'Settings',
              ),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Logout',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSettings)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'ngrok URL',
                        filled: true,
                        fillColor: _warmBeige.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saveUrl,
                    child: const Text('Save', style: TextStyle(color: _primaryTeal)),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                    onPressed: () => setState(() => _error = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadImage,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(_isUploading ? 'Processing...' : 'Upload Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadSummaries,
                icon: Icon(Icons.refresh, color: _darkText.withOpacity(0.6)),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primaryTeal))
              : _summaries.isEmpty
                  ? _buildEmptyState()
                  : _buildSummariesList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 72, color: _darkText.withOpacity(0.25)),
          const SizedBox(height: 20),
          Text(
            'No Image Summaries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _darkText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload an image to generate an AI summary',
            style: TextStyle(fontSize: 14, color: _darkText.withOpacity(0.45)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummariesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _summaries.length,
      itemBuilder: (context, index) {
        final summary = _summaries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, size: 18, color: _primaryTeal),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Image #${summary.id}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      summary.date,
                      style: TextStyle(fontSize: 12, color: _darkText.withOpacity(0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary.summary,
                  style: TextStyle(fontSize: 14, color: _darkText.withOpacity(0.8), height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
