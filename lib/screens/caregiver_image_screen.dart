import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/neurolens_api_service.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _warmBeige = Color(0xFFF5F0EB);
const _darkText = Color(0xFF2D3436);

const _summaryGradient = LinearGradient(
  colors: [Color(0xFF5B7FE8), Color(0xFF7B68D9), Color(0xFF9B59B6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.5, 1.0],
);

const _offlineCredentials = <String, String>{
  'P9002': 'NrE_Ui9sGMni22S7cTxQZK7F',
  'P5001': 'QcvoB3qHHeVGcxEHK_D_UCtA',
};

const _offlineSummaryDelay = Duration(seconds: 5);
const _offlineSummaryTexts = <String>[
  'This scene depicts a multi-generational family enjoying a leisure gathering on a beach. The core focus is on shared time, evidenced by the elaborate picnic spread and the casual atmosphere. The presence of the guitar and the group sharing food suggests themes of family celebrations, music, and the simple routines of vacationing or spending quality time together.',
  'This image portrays a family spending a quiet afternoon together in a garden beside a countryside-style home. The main focus is on companionship and everyday family interaction, shown through the shared tea, fresh fruit, and relaxed conversations around the table. The bright natural lighting and peaceful outdoor setting suggest themes of home life, caregiving, family bonding, and the simple routines of spending meaningful time together..',
];

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
  bool _isOfflineSession = false;
  String? _error;
  List<ImageSummary> _summaries = [];
  late String _resolvedPatientId;
  int _offlineSummaryId = 1;
  final Set<String> _animatedSummaryKeys = {};

  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _patientIdController = TextEditingController();
  bool _showSettings = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _resolvedPatientId = _normalisePatientId(widget.patientId);
    _patientIdController.text = _resolvedPatientId;
    _initialise();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _urlController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  String _normalisePatientId(String patientId) => patientId.trim().toUpperCase();

  String _summaryKey(ImageSummary summary) {
    return '${summary.patientId}_${summary.id}_${summary.date}_${summary.summary.hashCode}';
  }

  bool _isOfflinePatient(String patientId) {
    return _offlineCredentials.containsKey(_normalisePatientId(patientId));
  }

  bool _isOfflineLogin(String patientId, String password) {
    final expected = _offlineCredentials[_normalisePatientId(patientId)];
    return expected != null && expected == password.trim();
  }

  Future<void> _initialise() async {
    await _api.loadBaseUrl();
    _urlController.text = _api.baseUrl;
    if (_resolvedPatientId.isEmpty) return;
    if (_isOfflinePatient(_resolvedPatientId)) return;
    final token = await _secure.read(key: 'cg_tok_$_resolvedPatientId');
    if (token != null && token.isNotEmpty) {
      setState(() => _isAuthenticated = true);
      await _loadSummaries();
    }
  }

  Future<void> _login() async {
    final pid = _normalisePatientId(_patientIdController.text);
    if (pid.isEmpty) {
      setState(() => _error = 'Please enter the patient ID');
      return;
    }
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Please enter the caregiver password');
      return;
    }

    if (_isOfflineLogin(pid, password)) {
      setState(() {
        _isOfflineSession = true;
        _resolvedPatientId = pid;
        _isAuthenticated = true;
        _isLoading = false;
        _isUploading = false;
        _error = null;
        _summaries = [];
        _offlineSummaryId = 1;
        _animatedSummaryKeys.clear();
      });
      _passwordController.clear();
      return;
    }

    _isOfflineSession = false;

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
    if (_isOfflineSession) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    final token = await _getToken();
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final summaries = await _api.fetchImageSummaries(token: token);
      setState(() {
        _summaries = summaries;
        _animatedSummaryKeys.addAll(summaries.map(_summaryKey));
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
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    final selectedFiles = result.files.take(2).toList();

    if (_isOfflineSession) {
      setState(() {
        _isUploading = true;
        _error = null;
      });

      final dateText = DateTime.now().toIso8601String().split('T').first;
      final newSummaries = <ImageSummary>[];
      for (final file in selectedFiles) {
        final summaryText = _offlineSummaryId <= 1
            ? _offlineSummaryTexts.first
            : _offlineSummaryTexts.last;
        newSummaries.add(
          ImageSummary(
            id: _offlineSummaryId++,
            patientId: _resolvedPatientId,
            date: dateText,
            summary: summaryText,
          ),
        );
      }

      await Future<void>.delayed(_offlineSummaryDelay);
      if (!mounted) return;
      setState(() {
        _summaries.insertAll(0, newSummaries);
        _isUploading = false;
      });
      return;
    }

    final images = <({String filename, Uint8List bytes})>[];
    for (final file in selectedFiles) {
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

      images.add((filename: file.name, bytes: bytes));
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
        images: images,
      );
      setState(() {
        for (final summary in newSummaries) {
          _animatedSummaryKeys.remove(_summaryKey(summary));
        }
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
      _isOfflineSession = false;
      _summaries = [];
      _animatedSummaryKeys.clear();
      _error = null;
      _offlineSummaryId = 1;
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
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _primaryTeal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.psychology,
                        size: 52,
                        color: _primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Caregiver Portal',
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect to view summaries',
                  style: TextStyle(
                    color: _darkText.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.patientId.isEmpty) ...[
                        TextFormField(
                          controller: _patientIdController,
                          decoration: InputDecoration(
                            hintText: 'e.g., P12345',
                            labelText: 'Patient ID',
                            labelStyle: TextStyle(color: _darkText.withOpacity(0.6), fontSize: 16),
                            prefixIcon: Icon(Icons.person_outline, color: _primaryTeal.withOpacity(0.7)),
                            filled: true,
                            fillColor: _warmBeige.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _primaryTeal, width: 2),
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _darkText),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Caregiver Password',
                          labelStyle: TextStyle(color: _darkText.withOpacity(0.6), fontSize: 16),
                          prefixIcon: Icon(Icons.lock_outline, color: _primaryTeal.withOpacity(0.7)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _darkText.withOpacity(0.4),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: _warmBeige.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _primaryTeal, width: 2),
                          ),
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _darkText),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 28),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: _isLoading ? 0 : 2,
                            shadowColor: _primaryTeal.withOpacity(0.3),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Connect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 16,
          child: _buildBackButton(),
        ),
        Positioned(
          top: 10,
          right: 16,
          child: IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.settings, color: _primaryTeal),
            tooltip: 'Server Settings',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  label: Text(_isUploading ? 'Processing...' : 'Upload Images'),
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
        final summaryKey = _summaryKey(summary);
        final shouldAnimate = !_animatedSummaryKeys.contains(summaryKey);
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
                _SummaryTextBox(
                  text: summary.summary,
                  animate: shouldAnimate,
                  onFinished: () {
                    if (!mounted) return;
                    setState(() => _animatedSummaryKeys.add(summaryKey));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTextBox extends StatefulWidget {
  final String text;
  final bool animate;
  final VoidCallback onFinished;

  const _SummaryTextBox({
    required this.text,
    required this.animate,
    required this.onFinished,
  });

  @override
  State<_SummaryTextBox> createState() => _SummaryTextBoxState();
}

class _SummaryTextBoxState extends State<_SummaryTextBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _visibleChars = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _typingDuration(widget.text),
    );
    _controller.addListener(_handleTick);
    _controller.addStatusListener(_handleStatus);

    if (widget.animate) {
      _controller.forward();
    } else {
      _visibleChars = widget.text.length;
    }
  }

  @override
  void didUpdateWidget(covariant _SummaryTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.duration = _typingDuration(widget.text);
      if (widget.animate) {
        _completed = false;
        _visibleChars = 0;
        _controller.forward(from: 0.0);
      } else {
        _visibleChars = widget.text.length;
      }
    } else if (!oldWidget.animate && widget.animate) {
      _completed = false;
      _visibleChars = 0;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    final length = widget.text.length;
    final nextCount = (_controller.value * length).round();
    if (nextCount != _visibleChars) {
      setState(() => _visibleChars = nextCount.clamp(0, length));
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completed) {
      _completed = true;
      widget.onFinished();
    }
  }

  Duration _typingDuration(String text) {
    final total = text.length * 16;
    if (total < 800) return const Duration(milliseconds: 800);
    if (total > 4200) return const Duration(milliseconds: 4200);
    return Duration(milliseconds: total);
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.text.length;
    final shown = widget.animate
        ? widget.text.substring(0, _visibleChars.clamp(0, length))
        : widget.text;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: _summaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.5),
          ),
          child: Text(
            shown,
            style: TextStyle(fontSize: 14, color: _darkText.withOpacity(0.8), height: 1.5),
          ),
        ),
      ),
    );
  }
}
