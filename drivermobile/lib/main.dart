import "dart:convert";
import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:image_picker/image_picker.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "package:socket_io_client/socket_io_client.dart" as io;
import "package:url_launcher/url_launcher.dart";

import "api_client.dart";

/// Deep blue shell (matches rider app auth + in-app chrome).
const Color _kAuthDeepBlue = Color(0xFF0A1929);

void main() {
  runApp(const DriverMobileApp());
}

class DriverMobileApp extends StatelessWidget {
  const DriverMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RideMatch Driver",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7EB3FF),
          brightness: Brightness.dark,
        ).copyWith(
          surface: _kAuthDeepBlue,
          primary: const Color(0xFF7EB3FF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: _kAuthDeepBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: _kAuthDeepBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _kAuthDeepBlue,
          ),
        ),
      ),
      home: const AppBootstrapGate(),
    );
  }
}

class _SessionStore {
  static const _SessionStore instance = _SessionStore._();
  const _SessionStore._();

  static const _sessionKey = "driver_user_session_json";
  static const _storage = FlutterSecureStorage();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}

class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  late final Future<Widget> _gateFuture;

  @override
  void initState() {
    super.initState();
    _gateFuture = _resolveInitialWidget();
  }

  Future<Widget> _resolveInitialWidget() async {
    final user = await _SessionStore.instance.readUser();
    if (user != null && user.isNotEmpty) {
      if (!_driverIsApproved(user)) {
        await _SessionStore.instance.clear();
        return const RideMatchWelcomePage();
      }
      return DriverShellPage(user: user);
    }
    return const RideMatchWelcomePage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _gateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _kAuthDeepBlue,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))),
          );
        }
        return snapshot.data ?? const RideMatchWelcomePage();
      },
    );
  }
}

bool _driverIsApproved(Map<String, dynamic> user) {
  final s = (user["status"] ?? "").toString().trim().toLowerCase();
  return s == "approved";
}

IconData _preferenceIcon(String label) {
  switch (label) {
    case "quiet ride":
      return Icons.volume_off_rounded;
    case "music okay":
      return Icons.music_note_rounded;
    case "music low":
      return Icons.graphic_eq_rounded;
    case "conversation okay":
      return Icons.forum_rounded;
    case "no conversation":
      return Icons.do_not_disturb_on_outlined;
    case "pet friendly":
      return Icons.pets_rounded;
    case "temperature cool":
      return Icons.ac_unit_rounded;
    case "temperature warm":
      return Icons.wb_sunny_rounded;
    case "no highway":
      return Icons.alt_route_rounded;
    default:
      return Icons.tune_rounded;
  }
}

Widget _signupPreferenceChip({
  required String item,
  required bool selected,
  required bool disabled,
  required ValueChanged<bool> onSelected,
}) {
  final iconColor = selected ? _kAuthDeepBlue : Colors.white.withValues(alpha: 0.95);
  final textColor = selected ? _kAuthDeepBlue : Colors.white;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: disabled
          ? null
          : () {
              onSelected(!selected);
            },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_preferenceIcon(item), size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              item,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _authFieldDecoration(String label) {
  const inputFill = Color(0x22FFFFFF);
  const accent = Color(0xFF7EB3FF);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
    floatingLabelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
    filled: true,
    fillColor: inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.65)),
    ),
  );
}

/// In-app panels (matches rider shell cards).
class _ShellCard extends StatelessWidget {
  const _ShellCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

InputDecoration _shellInputDecoration({String? label}) {
  const accent = Color(0xFF7EB3FF);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
    floatingLabelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.75), width: 1.2),
    ),
  );
}

class RideMatchWelcomePage extends StatelessWidget {
  const RideMatchWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Ride Match",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "DRIVER",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _kAuthDeepBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("Log in", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const DriverSignupPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Sign up", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverPendingApprovalPage extends StatelessWidget {
  const DriverPendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 64, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(height: 20),
                  const Text(
                    "Waiting for approval",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your driver account is being reviewed by an administrator. "
                    "We will notify you when it is approved. After that, you can log in here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const RideMatchWelcomePage(),
                          ),
                          (route) => false,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kAuthDeepBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Back to Ride Match", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DriverSignupPage extends StatefulWidget {
  const DriverSignupPage({super.key});

  @override
  State<DriverSignupPage> createState() => _DriverSignupPageState();
}

class _DriverSignupPageState extends State<DriverSignupPage> {
  final _api = ApiClient();
  final ImagePicker _picker = ImagePicker();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _licenseExpires = TextEditingController();
  final _dob = TextEditingController();
  final _insuranceProvider = TextEditingController();
  final _insurancePolicy = TextEditingController();
  String? _licenseState;
  String? _profilePhotoPath;
  bool _busy = false;
  String _message = "";
  final Set<String> _prefs = <String>{};

  static const _prefOptions = [
    "quiet ride",
    "music okay",
    "music low",
    "conversation okay",
    "no conversation",
    "pet friendly",
    "temperature cool",
    "temperature warm",
    "no highway",
  ];

  static const _usStates = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
  ];

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _licenseNumber.dispose();
    _licenseExpires.dispose();
    _dob.dispose();
    _insuranceProvider.dispose();
    _insurancePolicy.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _profilePhotoPath = picked.path;
    });
  }

  Future<void> _submit() async {
    if (_profilePhotoPath == null || _profilePhotoPath!.trim().isEmpty) {
      setState(() {
        _message = "Please choose a profile photo.";
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = "";
    });
    try {
      final result = await _api.signup(
        fields: {
          "first_name": _first.text.trim(),
          "last_name": _last.text.trim(),
          "username": _username.text.trim(),
          "email": _email.text.trim(),
          "phone": _phone.text.trim(),
          "password": _password.text,
          "confirm_password": _confirm.text,
          "license_state": (_licenseState ?? "").trim(),
          "license_number": _licenseNumber.text.trim(),
          "license_expires": _licenseExpires.text.trim(),
          "date_of_birth": _dob.text.trim(),
          "insurance_provider": _insuranceProvider.text.trim(),
          "insurance_policy": _insurancePolicy.text.trim(),
        },
        preferences: _prefs.toList(),
        profilePhotoPath: _profilePhotoPath!,
      );
      if (!mounted) {
        return;
      }
      if (result["success"] == true) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => const DriverPendingApprovalPage(),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Sign up failed.";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = "Could not submit. Check your connection and try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtle = TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.35);

    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withValues(alpha: 0.85)),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    "Sign up",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                "Driver",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                children: [
                  Text(
                    "Create your profile for admin review. Fields marked with your license and insurance must match verification.",
                    style: subtle,
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message,
                      style: TextStyle(color: Colors.red.shade200, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _first,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          decoration: _authFieldDecoration("First name"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _last,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          decoration: _authFieldDecoration("Last name"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Username"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Email"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Phone"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dob,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Date of birth (YYYY-MM-DD)"),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "License state",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text("Select state", style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
                        value: _licenseState,
                        dropdownColor: const Color(0xFF152A3D),
                        iconEnabledColor: Colors.white70,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: _usStates
                            .map(
                              (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) {
                                setState(() {
                                  _licenseState = value;
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _licenseNumber,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("License number"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _licenseExpires,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("License expires (YYYY-MM-DD)"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _insuranceProvider,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Insurance provider"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _insurancePolicy,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Insurance policy"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Profile photo",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Required — JPG, PNG, or WebP (max 5 MB).",
                    style: subtle,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_profilePhotoPath == null ? "Choose profile photo" : "Change photo"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_profilePhotoPath != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: Image.file(
                          File(_profilePhotoPath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Password"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Confirm password"),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Preferences",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _prefOptions
                        .map(
                          (item) {
                            final selected = _prefs.contains(item);
                            return _signupPreferenceChip(
                              item: item,
                              selected: selected,
                              disabled: _busy,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _prefs.add(item);
                                  } else {
                                    _prefs.remove(item);
                                  }
                                });
                              },
                            );
                          },
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _kAuthDeepBlue,
                      disabledBackgroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _busy ? "Submitting..." : "Create account",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _api = ApiClient();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;
  String _message = "";

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = "Please enter both username and password.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final result = await _api.login(username: username, password: password);
      if (!mounted) {
        return;
      }

      if (result["success"] == true) {
        final user = Map<String, dynamic>.from(
          (result["user"] as Map?) ?? <String, dynamic>{},
        );
        if (!_driverIsApproved(user)) {
          await _SessionStore.instance.clear();
          if (!mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil<void>(
            MaterialPageRoute<void>(
              builder: (_) => const DriverPendingApprovalPage(),
            ),
            (route) => false,
          );
          return;
        }
        if (_rememberMe) {
          await _SessionStore.instance.saveUser(user);
        } else {
          await _SessionStore.instance.clear();
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => DriverShellPage(user: user),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Login failed.";
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = "Could not sign in. Try again.";
      });
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
      backgroundColor: _kAuthDeepBlue,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withValues(alpha: 0.85)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Ride Match",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "DRIVER",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade200, fontSize: 14),
                      ),
                    ),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Username"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Password"),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: Colors.white,
                        checkColor: _kAuthDeepBlue,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                      ),
                      Text(
                        "Remember me",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _kAuthDeepBlue,
                      disabledBackgroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _isLoading ? "Logging in..." : "Log in",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
}

class DriverShellPage extends StatefulWidget {
  const DriverShellPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DriverShellPage> createState() => _DriverShellPageState();
}

class _DriverShellPageState extends State<DriverShellPage> {
  int _currentIndex = 0;
  late Map<String, dynamic> _sessionUser;

  @override
  void initState() {
    super.initState();
    _sessionUser = Map<String, dynamic>.from(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DriverDashboardTab(user: _sessionUser),
      StartDriveTab(user: _sessionUser),
      DriverProfileTab(
        user: _sessionUser,
        onUserUpdated: (updatedUser) async {
          _sessionUser = Map<String, dynamic>.from(updatedUser);
          if (mounted) {
            setState(() {});
          }
          await _SessionStore.instance.saveUser(_sessionUser);
        },
        onLogout: () async {
          await _SessionStore.instance.clear();
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil<void>(
            MaterialPageRoute<void>(builder: (_) => const RideMatchWelcomePage()),
            (route) => false,
          );
        },
      ),
    ];

    final titles = ["Dashboard", "Start Drive", "Profile"];

    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      appBar: AppBar(title: Text(titles[_currentIndex])),
      body: tabs[_currentIndex],
      bottomNavigationBar: _BottomTabBar(
        currentIndex: _currentIndex,
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF7EB3FF);
    const inactiveColor = Color(0xFF9CA3AF);

    return SizedBox(
      height: 86,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 14,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D2137),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      label: "Dashboard",
                      icon: Icons.dashboard_outlined,
                      selected: currentIndex == 0,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onTabSelected(0),
                    ),
                  ),
                  const SizedBox(width: 90),
                  Expanded(
                    child: _NavItem(
                      label: "Profile",
                      icon: Icons.person_outline,
                      selected: currentIndex == 2,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onTabSelected(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onTabSelected(1),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: currentIndex == 1 ? 0.95 : 0.85),
                    const Color(0xFF7EB3FF).withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7EB3FF).withAlpha(currentIndex == 1 ? 100 : 55),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 3),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: _kAuthDeepBlue.withValues(alpha: 0.95),
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class DriverDashboardTab extends StatelessWidget {
  const DriverDashboardTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final firstName = (user["first_name"] ?? "").toString().trim();
    final username = (user["username"] ?? "").toString().trim();
    final statusRaw = (user["status"] ?? "").toString().trim();
    final status = statusRaw.isEmpty ? "Pending" : statusRaw.replaceAll("_", " ");
    final greetingName = firstName.isNotEmpty ? firstName : (username.isNotEmpty ? username : "Driver");
    final prefsRaw = (user["preferences"] ?? "").toString().trim();
    final prefsLabel = prefsRaw.isEmpty ? "—" : prefsRaw;

    return ColoredBox(
      color: _kAuthDeepBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RIDEMATCH DRIVER",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Welcome back, $greetingName",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "@$username · ${status[0].toUpperCase()}${status.substring(1)}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Dashboard Stats",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              const _StatCard(title: "Total Trips", value: "0"),
              const _StatCard(title: "Completed", value: "0"),
              const _StatCard(title: "Active", value: "0"),
              const _StatCard(title: "Given Rating", value: "—"),
              const _StatCard(title: "Received Rating", value: "—"),
              _StatCard(title: "Preferences", value: prefsLabel),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: "Recent Trips",
            child: Text(
              "No trips yet.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class StartDriveTab extends StatefulWidget {
  const StartDriveTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<StartDriveTab> createState() => _StartDriveTabState();
}

class _StartDriveTabState extends State<StartDriveTab> {
  final ApiClient _api = ApiClient();
  final TextEditingController _fareController = TextEditingController(text: "18.50");
  final MapController _mapController = MapController();
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _submitting = false;
  bool _isAvailable = false;
  String _message = "";
  bool _messageIsError = false;
  Timer? _refreshTimer;
  Timer? _locationTimer;
  io.Socket? _socket;
  String _geoapifyApiKey = "";
  LatLng? _driverLatLng;
  LatLng? _targetLatLng;
  List<LatLng> _routePoints = const [];
  String _routeLabel = "Driver to pickup";
  String _routeDistance = "";
  String _routeEta = "";
  String _routeError = "";
  final Map<String, LatLng> _geocodeCache = <String, LatLng>{};
  int _routeRefreshToken = 0;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadDispatch();
    _connectRealtime();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_submitting) {
        _loadDispatch(showLoader: false);
      }
    });
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_submitting) {
        _syncDriverLocation();
      }
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _refreshTimer?.cancel();
    _locationTimer?.cancel();
    _fareController.dispose();
    super.dispose();
  }

  void _recenterMapToRoute() {
    if (!_mapReady) {
      return;
    }
    final driverLatLng = _currentDriverLatLng();
    final points = <LatLng>[
      ?driverLatLng,
      ?_targetLatLng,
      ..._routePoints,
    ];
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  int? _extractAccountId() {
    final raw = widget.user["account_id"];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final text = (raw ?? "").toString().trim();
    return int.tryParse(text);
  }

  Future<void> _loadDispatch({bool showLoader = true}) async {
    final accountId = _extractAccountId();
    if (accountId == null) {
      setState(() {
        _loading = false;
        _message = "Driver account id is missing.";
        _messageIsError = true;
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final response = await _api.fetchDriverDispatch(accountId: accountId);
      if (!mounted) {
        return;
      }
      setState(() {
        _trip = response["trip"] is Map
            ? Map<String, dynamic>.from(response["trip"] as Map)
            : null;
        _isAvailable = response["is_available"] == true;
        _loading = false;
      });
      await _refreshNavigationPreview();
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMapToRoute());
    } catch (exc) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _message = "Could not load dispatch: $exc";
        _messageIsError = true;
      });
    }
  }

  Future<void> _setAvailability(bool value) async {
    final accountId = _extractAccountId();
    if (accountId == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _message = "";
      _messageIsError = false;
    });

    try {
      final response = await _api.setDriverAvailability(
        driverId: accountId,
        isAvailable: value,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isAvailable = response["is_available"] == true;
        _message = _isAvailable
            ? "You are now online for ride matching."
            : "You are now offline and will not receive new rides.";
        _messageIsError = false;
      });
      if (_isAvailable) {
        await _syncDriverLocation(showErrors: true);
      }
      await _loadDispatch(showLoader: false);
    } catch (exc) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = "Availability update failed: $exc";
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _syncDriverLocation({bool showErrors = false}) async {
    final accountId = _extractAccountId();
    if (accountId == null) {
      return;
    }
    final shouldShare = _isAvailable || _trip != null;
    if (!shouldShare) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showErrors && mounted) {
          setState(() {
            _message = "Turn on location services to share driver location.";
            _messageIsError = true;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (showErrors && mounted) {
          setState(() {
            _message = "Location permission is required to show your driver location.";
            _messageIsError = true;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _driverLatLng = LatLng(position.latitude, position.longitude);
      await _api.updateDriverLocation(
        driverId: accountId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _refreshNavigationPreview();
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMapToRoute());
    } catch (exc) {
      if (showErrors && mounted) {
        setState(() {
          _message = "Could not share driver location: $exc";
          _messageIsError = true;
        });
      }
    }
  }

  void _connectRealtime() {
    final accountId = _extractAccountId();
    if (accountId == null) {
      return;
    }

    final socket = io.io(
      _api.realtimeBaseUrl,
      io.OptionBuilder()
          .setTransports(["websocket", "polling"])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    socket.onConnect((_) {
      socket.emit("subscribe", {
        "role": "driver",
        "account_id": accountId,
      });
    });
    socket.on("trip_updated", (_) {
      if (mounted && !_submitting) {
        _loadDispatch(showLoader: false);
      }
    });
    socket.connect();
    _socket = socket;
  }

  Future<void> _runTripAction(String action) async {
    final accountId = _extractAccountId();
    final trip = _trip;
    if (accountId == null || trip == null) {
      return;
    }

    final tripId = int.tryParse((trip["trip_id"] ?? "").toString());
    if (tripId == null) {
      setState(() {
        _message = "Trip id is invalid.";
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = "";
      _messageIsError = false;
    });

    try {
      late Map<String, dynamic> response;
      if (action == "accept") {
        response = await _api.acceptTrip(tripId: tripId, driverId: accountId);
      } else if (action == "start") {
        response = await _api.startTrip(tripId: tripId, driverId: accountId);
      } else {
        final fare = double.tryParse(_fareController.text.trim());
        if (fare == null) {
          throw const FormatException("Enter a valid fare amount.");
        }
        response = await _api.completeTrip(
          tripId: tripId,
          driverId: accountId,
          finalCost: fare,
        );
      }

      if (!mounted) {
        return;
      }
      final updatedTrip = response["trip"];
      setState(() {
        _trip = updatedTrip is Map ? Map<String, dynamic>.from(updatedTrip) : null;
        _message = action == "accept"
            ? "Ride accepted."
            : action == "start"
                ? "Rider picked up. Opening destination in Google Maps."
                : "Trip completed.";
        _messageIsError = false;
      });
      await _refreshNavigationPreview();
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMapToRoute());
      if (action == "accept" && _trip != null) {
        await _openGoogleMapsDirections(
          destinationAddress: (_trip!["start_loc"] ?? "").toString(),
          destinationLatLng: _targetLatLng,
          emptyDestinationMessage: "Ride accepted, but the rider pickup location is missing.",
          launchFailureMessage: "Ride accepted, but Google Maps could not open directions to the rider.",
        );
      } else if (action == "start" && _trip != null) {
        await _openGoogleMapsDirections(
          destinationAddress: (_trip!["end_loc"] ?? "").toString(),
          destinationLatLng: _targetLatLng,
          emptyDestinationMessage: "Trip started, but the dropoff destination is missing.",
          launchFailureMessage: "Trip started, but Google Maps could not open directions to the destination.",
        );
      }
      if (action == "complete") {
        await _loadDispatch();
      }
    } catch (exc) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = "Action failed: $exc";
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    final text = (value ?? "").toString().trim();
    return double.tryParse(text);
  }

  LatLng? _tripDriverLatLng() {
    final trip = _trip;
    if (trip == null) {
      return null;
    }
    final latitude = _asDouble(trip["driver_latitude"]);
    final longitude = _asDouble(trip["driver_longitude"]);
    if (latitude == null || longitude == null) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  LatLng? _currentDriverLatLng() => _driverLatLng ?? _tripDriverLatLng();

  Future<void> _ensureMapsConfig() async {
    if (_geoapifyApiKey.isNotEmpty) {
      return;
    }
    try {
      final response = await _api.fetchMapsConfig();
      final apiKey = (response["geoapify_api_key"] ?? "").toString().trim();
      if (!mounted || apiKey.isEmpty) {
        return;
      }
      setState(() {
        _geoapifyApiKey = apiKey;
      });
    } catch (_) {
      // Keep the rest of the dispatch experience working even if maps config fails.
    }
  }

  String _routeTargetAddress(Map<String, dynamic>? trip) {
    final status = (trip?["status"] ?? "").toString().trim().toLowerCase();
    final rawAddress = status == "in_progress"
        ? (trip?["end_loc"] ?? "").toString().trim()
        : (trip?["start_loc"] ?? "").toString().trim();
    return _sanitizeRouteAddress(rawAddress);
  }

  String _sanitizeRouteAddress(String address) {
    final sanitized = address.replaceFirst(
      RegExp(r"\s+\((standard|shared|priority)\s*:\s*.*\)$", caseSensitive: false),
      "",
    ).trim();
    return sanitized;
  }

  String _routeTargetLabel(Map<String, dynamic>? trip) {
    final status = (trip?["status"] ?? "").toString().trim().toLowerCase();
    if (status == "in_progress") {
      return "Driver to dropoff";
    }
    return "Driver to pickup";
  }

  Future<void> _openGoogleMapsDirections({
    required String destinationAddress,
    LatLng? destinationLatLng,
    required String emptyDestinationMessage,
    required String launchFailureMessage,
  }) async {
    final normalizedAddress = _sanitizeRouteAddress(destinationAddress);
    if (normalizedAddress.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = emptyDestinationMessage;
        _messageIsError = true;
      });
      return;
    }

    Uri? appUri;
    if (destinationLatLng != null) {
      appUri = Uri.parse(
        "google.navigation:q=${destinationLatLng.latitude},${destinationLatLng.longitude}&mode=d",
      );
    }

    final webUri = Uri.https("www.google.com", "/maps/dir/", <String, String>{
      "api": "1",
      "destination": normalizedAddress,
      "travelmode": "driving",
    });

    final launchedApp = appUri != null &&
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
    if (launchedApp) {
      return;
    }

    final launchedWeb = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launchedWeb && mounted) {
      setState(() {
        _message = launchFailureMessage;
        _messageIsError = true;
      });
    }
  }

  Future<void> _resumeActiveNavigation() async {
    final trip = _trip;
    if (trip == null) {
      return;
    }
    final status = (trip["status"] ?? "").toString().trim().toLowerCase();
    if (status == "in_progress") {
      await _openGoogleMapsDirections(
        destinationAddress: (trip["end_loc"] ?? "").toString(),
        destinationLatLng: _targetLatLng,
        emptyDestinationMessage: "Trip is active, but the dropoff destination is missing.",
        launchFailureMessage: "Could not reopen Google Maps for the destination.",
      );
      return;
    }
    await _openGoogleMapsDirections(
      destinationAddress: (trip["start_loc"] ?? "").toString(),
      destinationLatLng: _targetLatLng,
      emptyDestinationMessage: "Trip is active, but the rider pickup location is missing.",
      launchFailureMessage: "Could not reopen Google Maps for the rider pickup.",
    );
  }

  Future<LatLng?> _resolveAddressLatLng(String address, LatLng? bias) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final cached = _geocodeCache[normalized];
    if (cached != null) {
      return cached;
    }
    final response = await _api.geocodeAddress(
      apiKey: _geoapifyApiKey,
      address: address,
      proximityLatitude: bias?.latitude,
      proximityLongitude: bias?.longitude,
    );
    final features = response["features"];
    if (features is! List || features.isEmpty) {
      return null;
    }
    final first = features.first;
    if (first is! Map) {
      return null;
    }
    final properties = first["properties"];
    if (properties is! Map) {
      return null;
    }
    final latitude = _asDouble(properties["lat"]);
    final longitude = _asDouble(properties["lon"]);
    if (latitude == null || longitude == null) {
      return null;
    }
    final latLng = LatLng(latitude, longitude);
    _geocodeCache[normalized] = latLng;
    return latLng;
  }

  String _formatDistance(dynamic meters) {
    final value = _asDouble(meters);
    if (value == null) {
      return "";
    }
    final miles = value / 1609.344;
    if (miles >= 10) {
      return "${miles.toStringAsFixed(0)} mi";
    }
    return "${miles.toStringAsFixed(1)} mi";
  }

  String _formatDuration(dynamic seconds) {
    final value = _asDouble(seconds);
    if (value == null) {
      return "";
    }
    final totalMinutes = (value / 60).round();
    if (totalMinutes < 60) {
      return "$totalMinutes min";
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return "$hours hr";
    }
    return "$hours hr $minutes min";
  }

  Future<void> _refreshNavigationPreview() async {
    final trip = _trip;
    if (trip == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _targetLatLng = null;
        _routePoints = const [];
        _routeDistance = "";
        _routeEta = "";
        _routeError = "";
        _routeLabel = "Driver to pickup";
      });
      return;
    }

    final driverLatLng = _currentDriverLatLng();
    final targetAddress = _routeTargetAddress(trip);
    final routeLabel = _routeTargetLabel(trip);

    if (mounted) {
      setState(() {
        _routeLabel = routeLabel;
      });
    }

    if (driverLatLng == null || targetAddress.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _targetLatLng = null;
        _routePoints = const [];
        _routeDistance = "";
        _routeEta = "";
        _routeError = driverLatLng == null
            ? "Waiting for your live location to draw directions."
            : "";
      });
      return;
    }

    await _ensureMapsConfig();
    if (_geoapifyApiKey.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeError = "Map configuration is missing.";
        _targetLatLng = null;
        _routePoints = const [];
        _routeDistance = "";
        _routeEta = "";
      });
      return;
    }

    final requestToken = ++_routeRefreshToken;

    try {
      final targetLatLng = await _resolveAddressLatLng(targetAddress, driverLatLng);
      if (!mounted || requestToken != _routeRefreshToken) {
        return;
      }
      if (targetLatLng == null) {
        setState(() {
          _targetLatLng = null;
          _routePoints = const [];
          _routeDistance = "";
          _routeEta = "";
          _routeError = "Could not find that route endpoint on the map.";
        });
        return;
      }

      final routeResponse = await _api.fetchRoute(
        apiKey: _geoapifyApiKey,
        startLatitude: driverLatLng.latitude,
        startLongitude: driverLatLng.longitude,
        endLatitude: targetLatLng.latitude,
        endLongitude: targetLatLng.longitude,
      );
      if (!mounted || requestToken != _routeRefreshToken) {
        return;
      }

      final features = routeResponse["features"];
      if (features is! List || features.isEmpty) {
        setState(() {
          _targetLatLng = targetLatLng;
          _routePoints = const [];
          _routeDistance = "";
          _routeEta = "";
          _routeError = "Route unavailable right now.";
        });
        return;
      }

      final feature = features.first;
      if (feature is! Map) {
        return;
      }
      final geometry = feature["geometry"];
      final properties = feature["properties"];
      final routePoints = <LatLng>[];
      if (geometry is Map && geometry["coordinates"] is List) {
        final coordinates = geometry["coordinates"] as List;
        for (final coordinate in coordinates) {
          if (coordinate is List && coordinate.length >= 2) {
            final longitude = _asDouble(coordinate[0]);
            final latitude = _asDouble(coordinate[1]);
            if (latitude != null && longitude != null) {
              routePoints.add(LatLng(latitude, longitude));
            }
          }
        }
      }

      String distance = "";
      String eta = "";
      if (properties is Map) {
        distance = _formatDistance(properties["distance"]);
        eta = _formatDuration(properties["time"]);
      }

      setState(() {
        _targetLatLng = targetLatLng;
        _routePoints = routePoints;
        _routeDistance = distance;
        _routeEta = eta;
        _routeError = "";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMapToRoute());
    } catch (_) {
      if (!mounted || requestToken != _routeRefreshToken) {
        return;
      }
      setState(() {
        _targetLatLng = null;
        _routePoints = const [];
        _routeDistance = "";
        _routeEta = "";
        _routeError = "Could not load directions right now.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final status = (trip?["status"] ?? "").toString();
    final driverLatLng = _currentDriverLatLng();
    final targetLatLng = _targetLatLng;
    final mapPoints = <LatLng>[
      ?driverLatLng,
      ?targetLatLng,
      ..._routePoints,
    ];
    final fallbackCenter = driverLatLng ?? targetLatLng ?? const LatLng(32.7767, -96.7970);
    final routeSummary = [
      if (_routeDistance.isNotEmpty) _routeDistance,
      if (_routeEta.isNotEmpty) _routeEta,
    ].join(" • ");

    return ColoredBox(
      color: _kAuthDeepBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dispatch Center",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  "This tab shows the ride assigned to this driver from the rider request flow.",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.35),
                ),
                const SizedBox(height: 16),
                if (_message.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _messageIsError ? const Color(0x33FF6B6B) : const Color(0x3322C55E),
                      border: Border.all(
                        color: _messageIsError ? const Color(0x55FF6B6B) : const Color(0x5522C55E),
                      ),
                    ),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _messageIsError ? Colors.red.shade100 : const Color(0xFFD1FAE5),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _loading ? "Loading driver dispatch..." : "Current assignment",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : _loadDispatch,
                      icon: const Icon(Icons.refresh),
                      color: Colors.white70,
                      tooltip: "Refresh",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isAvailable,
                  onChanged: _submitting ? null : _setAvailability,
                  contentPadding: EdgeInsets.zero,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF7EB3FF)
                        : Colors.white54,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF7EB3FF).withValues(alpha: 0.35)
                        : Colors.white24,
                  ),
                  title: const Text(
                    "Available for ride requests",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isAvailable
                        ? "You are online and eligible for new matches."
                        : "You are offline and hidden from rider matching.",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFF7EB3FF)),
                    ),
                  )
                else if (trip == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Text(
                      "No active ride is assigned right now. Go online here, then submit a ride from the rider portal to test matching.",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.35),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DispatchDetailRow(label: "Trip #", value: "${trip["trip_id"]}"),
                      _DispatchDetailRow(label: "Status", value: status.replaceAll("_", " ")),
                      _DispatchDetailRow(label: "Rider", value: (trip["rider_name"] ?? "Unknown").toString()),
                      _DispatchDetailRow(label: "Pickup", value: (trip["start_loc"] ?? "").toString()),
                      _DispatchDetailRow(label: "Dropoff", value: (trip["end_loc"] ?? "").toString()),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _routeLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (routeSummary.isNotEmpty)
                              Text(
                                routeSummary,
                                style: const TextStyle(color: Color(0xFF7EB3FF)),
                              )
                            else
                              Text(
                                "Directions will appear once the route is ready.",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                              ),
                            if (_routeError.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _routeError,
                                style: TextStyle(color: Colors.amber.shade200),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 220,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: fallbackCenter,
                                    initialZoom: 12.5,
                                    onMapReady: () {
                                      _mapReady = true;
                                      _refreshNavigationPreview();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) => _recenterMapToRoute());
                                    },
                                    cameraConstraint: mapPoints.length >= 2
                                        ? CameraConstraint.contain(
                                            bounds: LatLngBounds.fromPoints(mapPoints),
                                          )
                                        : const CameraConstraint.unconstrained(),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: _geoapifyApiKey.isEmpty
                                          ? "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
                                          : "https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=$_geoapifyApiKey",
                                      userAgentPackageName: "com.ridematch.drivermobile",
                                    ),
                                    if (_routePoints.isNotEmpty)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: _routePoints,
                                            strokeWidth: 5,
                                            color: const Color(0xFF7EB3FF),
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        if (driverLatLng != null)
                                          Marker(
                                            point: driverLatLng,
                                            width: 56,
                                            height: 56,
                                            child: const Icon(
                                              Icons.local_taxi_rounded,
                                              size: 32,
                                              color: Color(0xFF7EB3FF),
                                            ),
                                          ),
                                        if (targetLatLng != null)
                                          Marker(
                                            point: targetLatLng,
                                            width: 56,
                                            height: 56,
                                            child: Icon(
                                              status == "in_progress"
                                                  ? Icons.flag_rounded
                                                  : Icons.place_rounded,
                                              size: 34,
                                              color: Color(0xFF5EEAD4),
                                            ),
                                          ),
                                      ],
                                    ),
                                    RichAttributionWidget(
                                      attributions: [
                                        TextSourceAttribution(
                                          "OpenStreetMap contributors",
                                          onTap: null,
                                        ),
                                        if (_geoapifyApiKey.isNotEmpty)
                                          TextSourceAttribution(
                                            "Geoapify",
                                            onTap: null,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (status == "accepted" || status == "in_progress") ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _resumeActiveNavigation,
                            icon: const Icon(Icons.map_outlined),
                            label: Text(
                              status == "in_progress"
                                  ? "Go Back to Maps"
                                  : "Open Rider in Maps",
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (status == "requested")
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : () => _runTripAction("accept"),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text("Accept Ride and Navigate to Rider"),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _kAuthDeepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      if (status == "accepted") ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : () => _runTripAction("start"),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text("Rider Picked Up"),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _kAuthDeepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                      if (status == "in_progress") ...[
                        TextField(
                          controller: _fareController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          decoration: _shellInputDecoration(label: "Final fare").copyWith(
                            prefixText: "\$ ",
                            prefixStyle: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : () => _runTripAction("complete"),
                            icon: const Icon(Icons.flag_circle_outlined),
                            label: const Text("Complete Trip"),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _kAuthDeepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchDetailRow extends StatelessWidget {
  const _DispatchDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class DriverProfileTab extends StatefulWidget {
  const DriverProfileTab({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  final Map<String, dynamic> user;
  final Future<void> Function(Map<String, dynamic> updatedUser) onUserUpdated;
  final Future<void> Function() onLogout;

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();
  late Map<String, dynamic> _user;
  bool _uploadingPhoto = false;
  String _photoNotice = "";
  bool _photoNoticeIsError = false;
  int _photoVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadLatestProfile();
  }

  int? _extractAccountId(Map<String, dynamic> source) {
    final raw = source["account_id"];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final text = (raw ?? "").toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final direct = int.tryParse(text);
    if (direct != null) {
      return direct;
    }
    final normalized = text.contains(".") ? text.split(".").first.trim() : text;
    return int.tryParse(normalized);
  }

  Future<void> _loadLatestProfile() async {
    final accountId = _extractAccountId(_user) ?? _extractAccountId(widget.user);
    if (accountId == null) {
      if (mounted) {
        setState(() {
          _photoNotice = "Profile missing account id; cannot load photo.";
          _photoNoticeIsError = true;
        });
      }
      return;
    }

    try {
      final response = await _api.fetchDriverProfile(accountId: accountId);
      if (!mounted) {
        return;
      }
      if (response["success"] == true && response["user"] is Map) {
        final latestUser = Map<String, dynamic>.from(response["user"] as Map);
        setState(() {
          _user = latestUser;
          _photoVersion = DateTime.now().millisecondsSinceEpoch;
        });
        await widget.onUserUpdated(Map<String, dynamic>.from(_user));
      }
    } catch (_) {
      // Keep existing user data if live refresh fails.
    }
  }

  Future<void> _changeProfilePhoto() async {
    final accountId = _extractAccountId(_user) ?? _extractAccountId(widget.user);
    if (accountId == null) {
      setState(() {
        _photoNotice = "Cannot update photo because account_id is missing.";
        _photoNoticeIsError = true;
      });
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (picked == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoNotice = "No photo selected.";
        _photoNoticeIsError = true;
      });
      return;
    }

    setState(() {
      _uploadingPhoto = true;
      _photoNotice = "";
      _photoNoticeIsError = false;
    });

    try {
      final response = await _api.uploadDriverProfilePhoto(
        accountId: accountId,
        filePath: picked.path,
      );
      if (!mounted) {
        return;
      }
      final success = response["success"] == true;
      if (success) {
        final refreshed = await _api.fetchDriverProfile(accountId: accountId);
        if (!mounted) {
          return;
        }
        if (refreshed["success"] == true && refreshed["user"] is Map) {
          _user = Map<String, dynamic>.from(refreshed["user"] as Map);
        } else {
          final updatedUser = response["user"];
          if (updatedUser is Map) {
            _user.addAll(Map<String, dynamic>.from(updatedUser));
          }
          final photoUrl = (response["photo_url"] ?? "").toString().trim();
          if (photoUrl.isNotEmpty) {
            _user["photo_url"] = photoUrl;
          }
        }
        _user["status"] = "under_review";
        _photoVersion = DateTime.now().millisecondsSinceEpoch;
        await widget.onUserUpdated(Map<String, dynamic>.from(_user));
        setState(() {
          _photoNotice = (response["message"] ?? "Profile photo updated.").toString();
          _photoNoticeIsError = false;
        });
      } else {
        setState(() {
          _photoNotice = (response["error"] ?? "Could not update profile photo.").toString();
          _photoNoticeIsError = true;
        });
      }
    } catch (exc) {
      if (!mounted) {
        return;
      }
      setState(() {
        _photoNotice = "Upload failed: $exc";
        _photoNoticeIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_user["first_name"] ?? "").toString().trim();
    final lastName = (_user["last_name"] ?? "").toString().trim();
    final username = (_user["username"] ?? "").toString().trim();
    final email = (_user["email"] ?? "").toString().trim();
    final phone = (_user["phone"] ?? "").toString().trim();
    final statusRaw = (_user["status"] ?? "").toString().trim();
    final status = statusRaw.isEmpty ? "pending" : statusRaw;
    final preferences = (_user["preferences"] ?? "").toString().trim();
    final licenseState = (_user["license_state"] ?? "").toString().trim();
    final licenseNumber = (_user["license_number"] ?? "").toString().trim();
    final licenseExpires = (_user["license_expires"] ?? "").toString().trim();
    final insuranceProvider = (_user["insurance_provider"] ?? "").toString().trim();
    final insurancePolicy = (_user["insurance_policy"] ?? "").toString().trim();
    final displayName = "$firstName $lastName".trim().isEmpty ? "Driver" : "$firstName $lastName".trim();
    final statusTitle = status.replaceAll("_", " ");
    final accountId = _extractAccountId(_user) ?? _extractAccountId(widget.user);
    final photoUrl = accountId == null ? null : "${_api.realtimeBaseUrl}/api/driver/photo/$accountId?v=$_photoVersion";

    return ColoredBox(
      color: _kAuthDeepBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ShellCard(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3A5F),
                        Colors.white.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: photoUrl == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return Container(
                              color: Colors.white.withValues(alpha: 0.08),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7EB3FF)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, color: Colors.white);
                          },
                        ),
                ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "@${username.isEmpty ? 'driver' : username}",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: statusTitle),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: "Account Details",
            child: Column(
              children: [
                _ProfileFieldRow(label: "First Name", value: firstName),
                _ProfileFieldRow(label: "Last Name", value: lastName),
                _ProfileFieldRow(label: "Email", value: email),
                _ProfileFieldRow(label: "Phone", value: phone),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Driver Verification",
            child: Column(
              children: [
                _ProfileFieldRow(label: "License State", value: licenseState),
                _ProfileFieldRow(label: "License Number", value: licenseNumber),
                _ProfileFieldRow(label: "License Expires", value: licenseExpires),
                _ProfileFieldRow(label: "Insurance Provider", value: insuranceProvider),
                _ProfileFieldRow(label: "Insurance Policy", value: insurancePolicy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Preferences",
            child: preferences.isEmpty
                ? Text(
                    "No preferences selected yet.",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: preferences
                        .split(",")
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: "Change Profile Photo",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Upload a new photo for review. Replacing it deletes your current photo.",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _uploadingPhoto ? null : _changeProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_uploadingPhoto ? "Uploading..." : "Change Profile Photo"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _kAuthDeepBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_photoNotice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _photoNoticeIsError ? const Color(0x55FF6B6B) : const Color(0x5522C55E),
                ),
                color: _photoNoticeIsError ? const Color(0x33FF6B6B) : const Color(0x3322C55E),
              ),
              child: Text(
                _photoNotice,
                style: TextStyle(
                  color: _photoNoticeIsError ? Colors.red.shade100 : const Color(0xFFD1FAE5),
                ),
              ),
            ),
          if (_photoNotice.isNotEmpty) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x55FF6B6B)),
              color: const Color(0x33FF6B6B),
            ),
            child: Text(
              "Uploading a new profile photo will put your driver account under review again.",
              style: TextStyle(color: Colors.red.shade100),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await widget.onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text("Log out"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFieldRow extends StatelessWidget {
  const _ProfileFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? "N/A" : value;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7EB3FF).withValues(alpha: 0.5)),
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Text(
        "${label[0].toUpperCase()}${label.substring(1)}",
        style: const TextStyle(
          color: Color(0xFF7EB3FF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}



