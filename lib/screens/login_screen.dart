import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import '../services/ml_interface_service.dart';
import '../services/background_upload_service.dart';
import 'recording_screen.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _warmBeige = Color(0xFFF5F0EB);
const _darkText = Color(0xFF2D3436);

const _kPasswordKey = 'patient_password';
const _kResultKeyKey = 'result_key_b64';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  final _storage = const FlutterSecureStorage();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final patientId = _idController.text.trim();
      final password = _passwordController.text;

      final ml = MLInterfaceService();
      final auth = await ml.authenticatePatient(
        patientId: patientId,
        password: password,
      );

      await BackgroundUploadService.saveAuthToken(auth.token);

      if (auth.resultKeyB64 != null && auth.resultKeyB64!.isNotEmpty) {
        await _storage.write(key: _kResultKeyKey, value: auth.resultKeyB64);
      }

      if (mounted) {
        final storageService = context.read<StorageService>();
        await storageService.savePatientId(patientId);
        await _storage.write(key: _kPasswordKey, value: password);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RecordingScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        String msg;
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          msg = 'Invalid ID or password. Please check your details.';
        } else if (statusCode != null) {
          final body = e.response?.data;
          final detail = body is Map ? body['detail']?.toString() : null;
          msg = detail != null
              ? 'Error $statusCode: $detail'
              : 'Server error $statusCode. Please try again.';
        } else {
          msg = 'Could not reach the server. Check your connection and try again.';
        }
        debugPrint('[NeuroLens] Login error (${statusCode ?? "network"}): ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
        );
      }
    } catch (e) {
      debugPrint('[NeuroLens] Login unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 24),
                      const Text(
                        'NeuroLens',
                        style: TextStyle(
                          color: _darkText,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(
                          color: _darkText.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildLoginCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
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
    );
  }

  Widget _buildLoginCard() {
    return Container(
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
          TextFormField(
            controller: _idController,
            focusNode: _focusNode,
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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your patient ID';
              }
              if (value.trim().length < 3) {
                return 'ID must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: _isSubmitting ? 0 : 2,
                shadowColor: _primaryTeal.withOpacity(0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
