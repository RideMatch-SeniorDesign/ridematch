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

/// Shown on the dashboard and profile: one pill per saved preference (read-only).
Widget _readOnlyPreferencePill(String item) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_preferenceIcon(item), size: 20, color: const Color(0xFF7EB3FF)),
        const SizedBox(width: 8),
        Text(
          item,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
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
  int _index = 0;
  late Map<String, dynamic> _sessionUser;

  @override
  void initState() {
    super.initState();
    _sessionUser = Map<String, dynamic>.from(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DriverDashboardTab(
        user: _sessionUser,
        onStartDriving: () => setState(() => _index = 1),
      ),
      StartDriveTab(user: _sessionUser),
      DriverRatingTab(user: _sessionUser),
      DriverIncomeTab(user: _sessionUser),
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

    const titles = ["Dashboard", "Drive", "Rating", "Income", "Profile"];

    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      appBar: AppBar(title: Text(titles[_index])),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: "Dashboard"),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: "Drive"),
          NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star), label: "Rating"),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: "Income"),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

String _driverMetric(dynamic value) {
  if (value == null) {
    return "—";
  }
  final text = value.toString().trim();
  return text.isEmpty ? "—" : text;
}

List<String> _driverPrefsListFromUser(Map<String, dynamic> user) {
  final raw = (user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  raw.sort();
  return raw;
}

int? _driverInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? "").toString().trim());
}

class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key, required this.user, required this.onStartDriving});

  final Map<String, dynamic> user;
  final VoidCallback onStartDriving;

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _driverInt(widget.user["account_id"]);
    if (id == null || id == 0) {
      setState(() {
        _loading = false;
        _error = "Missing account id.";
      });
      return;
    }
    try {
      final res = await _api.fetchDashboard(driverId: id);
      if (!mounted) {
        return;
      }
      if (res["success"] != true) {
        setState(() {
          _loading = false;
          _error = (res["error"] ?? "Could not load dashboard.").toString();
        });
        return;
      }
      final trips = (res["trips"] as List?) ?? [];
      setState(() {
        _summary = Map<String, dynamic>.from((res["summary"] as Map?) ?? {});
        _trips = trips.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _error = "";
      });
    } catch (exc) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "$exc";
        });
      }
    }
  }

  List<Widget> _driverTripTipWidgets(Map<String, dynamic> trip) {
    final tip = double.tryParse((trip["tip_amount"] ?? "").toString());
    if (tip == null || tip <= 0) {
      return [];
    }
    return [
      const SizedBox(height: 8),
      Text(
        "Rider tip: \$${tip.toStringAsFixed(2)}",
        style: const TextStyle(color: Color(0xFF7EB3FF), fontWeight: FontWeight.w600),
      ),
    ];
  }

  void _showTripInfo(Map<String, dynamic> trip) {
    final cost = trip["final_cost"];
    final estimated = trip["estimated_cost"];
    final hasFinal = cost != null && cost.toString().trim().isNotEmpty && cost.toString() != "0.0";
    final costLabel = hasFinal ? "\$$cost" : "Estimated \$${estimated ?? "0.00"}";
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152A42),
        title: const Text("Trip details", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${trip["start_loc"] ?? "—"} → ${trip["end_loc"] ?? "—"}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text("Fare: $costLabel", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ..._driverTripTipWidgets(trip),
              const SizedBox(height: 8),
              Text(
                "Rider tips show here and in Income after they submit a rating.",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _openReviewForTrip(Map<String, dynamic> trip) async {
    final status = (trip["status"] ?? "").toString().toLowerCase();
    if (status != "completed") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can review a trip after it is completed.")),
      );
      return;
    }
    if (trip["driver_rate"] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You already left a rating for this trip.")),
      );
      return;
    }
    final id = _driverInt(widget.user["account_id"]);
    if (id == null || id == 0) {
      return;
    }
    await showDriverTripReviewSheet(
      context,
      api: _api,
      driverId: id,
      trip: trip,
      onSubmitted: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.user["first_name"] ?? "").toString().trim();
    final startHeroTitle = firstName.isEmpty ? "Start driving" : "Welcome, $firstName";
    final currentPrefs = _driverPrefsListFromUser(widget.user);

    return ColoredBox(
      color: _kAuthDeepBlue,
      child: RefreshIndicator(
        color: const Color(0xFF7EB3FF),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onStartDriving,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        const Color(0xFF7EB3FF).withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.near_me_rounded, color: Color(0xFF7EB3FF), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              startHeroTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Go online, accept trips, and navigate to riders.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.65), size: 28),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error, style: TextStyle(color: Colors.red.shade200)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))),
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DriverDashStat("Completed trips", "${_summary["completed_count"] ?? 0}"),
                  _DriverDashStat("Your rating", _driverMetric(_summary["avg_received_rating"])),
                ],
              ),
              const SizedBox(height: 14),
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ride preferences",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "What riders see when you are matched. Edit these on your profile.",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (currentPrefs.isEmpty)
                      Text(
                        "No preferences selected yet.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentPrefs.map(_readOnlyPreferencePill).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: "Recent trips",
                child: _trips.isEmpty
                    ? Text(
                        "No trips yet.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.35),
                      )
                    : Column(
                        children: _trips
                            .take(8)
                            .map(
                              (trip) => _DriverDashboardTripRow(
                                trip: trip,
                                onInfo: () => _showTripInfo(trip),
                                onReview: () => _openReviewForTrip(trip),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _titleCaseStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) {
    return "—";
  }
  return s.replaceAll("_", " ");
}

class _DriverDashboardTripRow extends StatelessWidget {
  const _DriverDashboardTripRow({
    required this.trip,
    required this.onInfo,
    required this.onReview,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onInfo;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final route = "${trip["start_loc"] ?? "—"} → ${trip["end_loc"] ?? "—"}";
    final rider = (trip["rider_name"] ?? "Rider").toString();
    final status = _titleCaseStatus((trip["status"] ?? "").toString());
    final completed = (trip["status"] ?? "").toString().toLowerCase() == "completed";
    final needsReview = completed && trip["driver_rate"] == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(route, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
            const SizedBox(height: 4),
            Text("$rider · $status", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  tooltip: "Fare & trip info",
                ),
                const SizedBox(width: 4),
                if (completed)
                  TextButton.icon(
                    onPressed: onReview,
                    icon: Icon(needsReview ? Icons.rate_review_outlined : Icons.check_circle_outline, size: 18),
                    label: Text(needsReview ? "Review trip" : "Reviewed"),
                    style: TextButton.styleFrom(
                      foregroundColor: needsReview ? const Color(0xFF7EB3FF) : Colors.white54,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDashStat extends StatelessWidget {
  const _DriverDashStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class DriverRatingTab extends StatefulWidget {
  const DriverRatingTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DriverRatingTab> createState() => _DriverRatingTabState();
}

class _DriverRatingTabState extends State<DriverRatingTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _given = [];
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _recentCompleted = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _driverInt(widget.user["account_id"]);
    if (id == null || id == 0) {
      setState(() {
        _loading = false;
        _error = "Missing account id.";
      });
      return;
    }
    try {
      final dash = await _api.fetchDashboard(driverId: id);
      final rev = await _api.fetchReviews(driverId: id);
      final pend = await _api.fetchPendingReviews(driverId: id);
      final tripsRes = await _api.fetchTrips(driverId: id);
      if (!mounted) {
        return;
      }
      final data = Map<String, dynamic>.from((rev["review_data"] as Map?) ?? {});
      final rawTrips = (tripsRes["trips"] as List?) ?? [];
      final recentCompleted = rawTrips
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((trip) => (trip["status"] ?? "").toString().toLowerCase() == "completed")
          .take(10)
          .toList();
      setState(() {
        _summary = Map<String, dynamic>.from((dash["summary"] as Map?) ?? {});
        _received = ((data["received"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _given = ((data["given"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _pending = ((pend["pending"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _recentCompleted = recentCompleted;
        _loading = false;
        _error = rev["success"] == true && pend["success"] == true && tripsRes["success"] == true
            ? ""
            : (rev["error"]?.toString() ?? pend["error"]?.toString() ?? tripsRes["error"]?.toString() ?? "Could not load.");
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _error = "$exc";
      });
    }
  }

  double get _avgReceivedStars {
    final v = _summary["avg_received_rating"];
    if (v == null) {
      return 0.0;
    }
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kAuthDeepBlue,
      child: RefreshIndicator(
        color: const Color(0xFF7EB3FF),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error, style: TextStyle(color: Colors.red.shade200)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))),
              )
            else ...[
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Your driver rating", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "Average from riders after completed trips.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _DriverStarRow(rating: _avgReceivedStars, starSize: 32),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            "${_avgReceivedStars.toStringAsFixed(1)} / 5",
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_pending.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ShellCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pending_actions, color: Colors.amber.shade200, size: 22),
                          const SizedBox(width: 8),
                          const Text("Finish your reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Rate your riders after completed trips.",
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                      ),
                      const SizedBox(height: 12),
                      ..._pending.map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => showDriverTripReviewSheet(
                                context,
                                api: _api,
                                driverId: _driverInt(widget.user["account_id"]) ?? 0,
                                trip: trip,
                                onSubmitted: _load,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${trip["start_loc"] ?? "—"} → ${trip["end_loc"] ?? "—"}",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Rider: ${trip["rider_name"] ?? "—"}",
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.white54),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Last 10 riders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      "Review riders from your 10 most recent completed trips whenever you're ready.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 12),
                    if (_recentCompleted.isEmpty)
                      Text("No completed trips yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
                    else
                      ..._recentCompleted.map(
                        (trip) {
                          final alreadyReviewed = trip["driver_rate"] != null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Rider: ${trip["rider_name"] ?? "Unknown rider"}",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${trip["start_loc"] ?? "-"} -> ${trip["end_loc"] ?? "-"}",
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (alreadyReviewed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: Colors.white.withValues(alpha: 0.08),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                                      ),
                                      child: Text(
                                        "Reviewed ${trip["driver_rate"]}/5",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: () => showDriverTripReviewSheet(
                                        context,
                                        api: _api,
                                        driverId: _driverInt(widget.user["account_id"]) ?? 0,
                                        trip: trip,
                                        onSubmitted: _load,
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _kAuthDeepBlue,
                                      ),
                                      child: const Text("Review now"),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Feedback from riders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (_received.isEmpty)
                      Text("No ratings yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
                    else
                      ..._received.take(12).map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _DriverStarRow(rating: double.tryParse((row["rating"] ?? "").toString()) ?? 0.0, starSize: 18),
                                    if ((row["comment"] ?? "").toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        (row["comment"] ?? "").toString(),
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Ratings you gave riders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (_given.isEmpty)
                      Text("You have not submitted ratings yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
                    else
                      ..._given.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                _DriverStarRow(rating: double.tryParse((row["rating"] ?? "").toString()) ?? 0.0, starSize: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "To ${row["counterpart_name"] ?? "rider"}",
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DriverIncomeTab extends StatefulWidget {
  const DriverIncomeTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DriverIncomeTab> createState() => _DriverIncomeTabState();
}

class _DriverIncomeTabState extends State<DriverIncomeTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  Map<String, dynamic> _allTime = {};
  Map<String, dynamic> _payPeriod = {};
  Map<String, dynamic> _payout = {};
  List<Map<String, dynamic>> _recentTips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _driverInt(widget.user["account_id"]);
    if (id == null || id == 0) {
      setState(() {
        _loading = false;
        _error = "Missing account id.";
      });
      return;
    }
    try {
      final res = await _api.fetchIncome(driverId: id);
      if (!mounted) {
        return;
      }
      if (res["success"] != true) {
        setState(() {
          _loading = false;
          _error = (res["error"] ?? "Could not load income.").toString();
        });
        return;
      }
      final stats = Map<String, dynamic>.from((res["stats"] as Map?) ?? {});
      final tipsRaw = (stats["recent_tips"] as List?) ?? [];
      final tipsList = tipsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _allTime = Map<String, dynamic>.from((stats["all_time"] as Map?) ?? {});
        _payPeriod = Map<String, dynamic>.from((stats["pay_period"] as Map?) ?? {});
        _payout = Map<String, dynamic>.from((stats["payout"] as Map?) ?? {});
        _recentTips = tipsList;
        _loading = false;
        _error = "";
      });
    } catch (exc) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "$exc";
        });
      }
    }
  }

  String _money(dynamic v) {
    final n = double.tryParse((v ?? "").toString());
    if (n == null) {
      return "—";
    }
    return "\$${n.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kAuthDeepBlue,
      child: RefreshIndicator(
        color: const Color(0xFF7EB3FF),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error, style: TextStyle(color: Colors.red.shade200)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))),
              )
            else ...[
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("All-time earnings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "Trip fare amounts shown are your share after the admin cut (${_payout["driver_fare_share_pct"] ?? "—"}%). Tips are yours in full.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 14),
                    _incomeRow("Trips", "${_allTime["trip_count"] ?? 0}"),
                    _incomeRow("Your share of fares", _money(_allTime["fare_earnings"])),
                    _incomeRow("Tips", _money(_allTime["total_tips"])),
                    const Divider(height: 24, color: Colors.white24),
                    _incomeRow("Estimated payout", _money(_allTime["estimated_payout"]), bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current pay period", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "${_payout["schedule_label"] ?? "Pay period"} · ${_payout["period_range_label"] ?? ""}",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Matches the payout schedule set in the admin settings. Only trips completed in this window are counted.",
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    _incomeRow("Trips", "${_payPeriod["trip_count"] ?? 0}"),
                    _incomeRow("Your share of fares", _money(_payPeriod["fare_earnings"])),
                    _incomeRow("Tips", _money(_payPeriod["total_tips"])),
                    const Divider(height: 24, color: Colors.white24),
                    _incomeRow("Estimated payout", _money(_payPeriod["estimated_payout"]), bold: true),
                  ],
                ),
              ),
              if (_recentTips.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ShellCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tips from riders",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Individual tips riders added after completed trips. Totals above include all tips.",
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 12),
                      ..._recentTips.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${row["start_loc"] ?? "—"} → ${row["end_loc"] ?? "—"}",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Trip #${row["trip_id"] ?? "—"}",
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _money(row["tip_amount"]),
                                  style: const TextStyle(
                                    color: Color(0xFF7EB3FF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _incomeRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: bold ? 17 : 15,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStarRow extends StatelessWidget {
  const _DriverStarRow({required this.rating, this.starSize = 24});

  final double rating;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        final IconData icon;
        if (r >= idx) {
          icon = Icons.star_rounded;
        } else if (r >= idx - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, color: const Color(0xFFFFD54F), size: starSize);
      }),
    );
  }
}

Future<void> showDriverTripReviewSheet(
  BuildContext context, {
  required ApiClient api,
  required int driverId,
  required Map<String, dynamic> trip,
  required VoidCallback onSubmitted,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF152A42),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) {
      return _DriverTripReviewSheetBody(
        api: api,
        driverId: driverId,
        trip: trip,
        onSubmitted: () {
          Navigator.pop(ctx);
          onSubmitted();
        },
      );
    },
  );
}

class _DriverTripReviewSheetBody extends StatefulWidget {
  const _DriverTripReviewSheetBody({
    required this.api,
    required this.driverId,
    required this.trip,
    required this.onSubmitted,
  });

  final ApiClient api;
  final int driverId;
  final Map<String, dynamic> trip;
  final VoidCallback onSubmitted;

  @override
  State<_DriverTripReviewSheetBody> createState() => _DriverTripReviewSheetBodyState();
}

class _DriverTripReviewSheetBodyState extends State<_DriverTripReviewSheetBody> {
  int _stars = 5;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final tid = _driverInt(widget.trip["trip_id"]);
      if (tid == null) {
        return;
      }
      final res = await widget.api.submitTripReview(
        tripId: tid,
        driverId: widget.driverId,
        rating: _stars,
        comment: _comment.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (res["success"] == true) {
        widget.onSubmitted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((res["error"] ?? "Could not submit.").toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Rate your rider", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            "${widget.trip["start_loc"] ?? "—"} → ${widget.trip["end_loc"] ?? "—"}",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              return IconButton(
                onPressed: _busy ? null : () => setState(() => _stars = n),
                icon: Icon(
                  n <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD54F),
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: _shellInputDecoration(label: "Comment (optional)"),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Submitting..." : "Submit rating"),
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
      if (response["success"] == false) {
        setState(() {
          _loading = false;
          _message = (response["error"] ?? "Could not load dispatch.").toString();
          _messageIsError = true;
        });
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
    socket.on("ride_request_received", (data) {
      if (!mounted) return;

      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final title = (map["title"] ?? "New ride request").toString();
      final message = (map["message"] ?? "A rider sent you a request.").toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title\n$message")),
      );

      _loadDispatch(showLoader: false);
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
        response = await _api.completeTrip(
          tripId: tripId,
          driverId: accountId,
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
        final completedTrip = updatedTrip is Map<String, dynamic> ? Map<String, dynamic>.from(updatedTrip) : null;
        await _loadDispatch();
        if (completedTrip != null && mounted) {
          await showDriverTripReviewSheet(
            context,
            api: _api,
            driverId: accountId,
            trip: completedTrip,
            onSubmitted: _loadDispatch,
          );
        }
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
    final results = response["results"];
    Map<String, dynamic>? firstMap;
    if (features is List && features.isNotEmpty && features.first is Map) {
      firstMap = Map<String, dynamic>.from(features.first as Map);
    } else if (results is List && results.isNotEmpty && results.first is Map) {
      firstMap = Map<String, dynamic>.from(results.first as Map);
    }
    if (firstMap == null) {
      return null;
    }
    double? latitude;
    double? longitude;
    final properties = firstMap["properties"];
    if (properties is Map) {
      final props = Map<String, dynamic>.from(properties);
      latitude = _asDouble(props["lat"]);
      longitude = _asDouble(props["lon"]);
    }
    latitude ??= _asDouble(firstMap["lat"]);
    longitude ??= _asDouble(firstMap["lon"]);
    final geometry = firstMap["geometry"];
    if ((latitude == null || longitude == null) && geometry is Map) {
      final coords = geometry["coordinates"];
      if (coords is List && coords.length >= 2) {
        longitude = _asDouble(coords[0]);
        latitude = _asDouble(coords[1]);
      }
    }
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

    if (targetAddress.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _targetLatLng = null;
        _routePoints = const [];
        _routeDistance = "";
        _routeEta = "";
        _routeError = "";
      });
      return;
    }

    if (driverLatLng == null) {
      await _ensureMapsConfig();
      if (!mounted) {
        return;
      }
      if (_geoapifyApiKey.isEmpty) {
        setState(() {
          _targetLatLng = null;
          _routePoints = const [];
          _routeDistance = "";
          _routeEta = "";
          _routeError = "Map configuration is missing.";
        });
        return;
      }
      final requestToken = ++_routeRefreshToken;
      try {
        final previewTarget = await _resolveAddressLatLng(targetAddress, null);
        if (!mounted || requestToken != _routeRefreshToken) {
          return;
        }
        if (previewTarget == null) {
          setState(() {
            _targetLatLng = null;
            _routePoints = const [];
            _routeDistance = "";
            _routeEta = "";
            _routeError = "Could not find that address on the map.";
          });
          return;
        }
        setState(() {
          _targetLatLng = previewTarget;
          _routePoints = const [];
          _routeDistance = "";
          _routeEta = "";
          _routeError = "Waiting for your live location to draw directions.";
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
    final fallbackCenter = driverLatLng ?? targetLatLng ?? const LatLng(41.6611, -91.5302);
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
                      _DispatchDetailRow(
                        label: status == "requested" ? "Estimated fare" : "Fare",
                        value: "\$${trip["estimated_cost"] ?? trip["final_cost"] ?? "0.00"}",
                      ),
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
                                    cameraConstraint: const CameraConstraint.unconstrained(),
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
                        Text(
                          "Estimated fare: \$${trip["estimated_cost"] ?? trip["final_cost"] ?? "0.00"}",
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Text(
                            "Ride is in progress. The rider will complete the ride and submit payment from their app.",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.78), height: 1.35),
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

  late final TextEditingController _first = TextEditingController(text: (widget.user["first_name"] ?? "").toString());
  late final TextEditingController _last = TextEditingController(text: (widget.user["last_name"] ?? "").toString());
  late final TextEditingController _email = TextEditingController(text: (widget.user["email"] ?? "").toString());
  late final TextEditingController _phone = TextEditingController(text: (widget.user["phone"] ?? "").toString());
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  late Set<String> _prefs = _prefsFromUserString(widget.user);

  String _settingsMessage = "";
  bool _settingsMessageIsError = false;
  bool _busy = false;
  bool _pwBusy = false;

  static const _profilePrefOptions = [
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

  static Set<String> _prefsFromUserString(Map<String, dynamic> user) {
    return (user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  void _applyUserToFields(Map<String, dynamic> user) {
    _first.text = (user["first_name"] ?? "").toString();
    _last.text = (user["last_name"] ?? "").toString();
    _email.text = (user["email"] ?? "").toString();
    _phone.text = (user["phone"] ?? "").toString();
    _prefs = _prefsFromUserString(user);
  }

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadLatestProfile();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
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
          _applyUserToFields(latestUser);
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

  Future<void> _saveProfile() async {
    final accountId = _extractAccountId(_user) ?? _extractAccountId(widget.user);
    if (accountId == null) {
      setState(() {
        _settingsMessage = "Cannot save: account id is missing.";
        _settingsMessageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _settingsMessage = "";
    });
    try {
      final res = await _api.updateDriverProfile(
        driverId: accountId,
        payload: <String, dynamic>{
          "first_name": _first.text.trim(),
          "last_name": _last.text.trim(),
          "email": _email.text.trim(),
          "phone": _phone.text.trim(),
          "preferences": _prefs.toList(),
        },
      );
      if (!mounted) {
        return;
      }
      if (res["success"] == true && res["user"] is Map) {
        final updated = Map<String, dynamic>.from(res["user"] as Map);
        setState(() {
          _user = updated;
          _applyUserToFields(updated);
          _settingsMessage = (res["message"] ?? "Settings updated.").toString();
          _settingsMessageIsError = false;
        });
        await widget.onUserUpdated(updated);
      } else {
        setState(() {
          _settingsMessage = (res["error"] ?? "Could not save settings.").toString();
          _settingsMessageIsError = true;
        });
      }
    } catch (exc) {
      if (mounted) {
        setState(() {
          _settingsMessage = "$exc";
          _settingsMessageIsError = true;
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

  Future<void> _changePassword() async {
    final cur = _currentPassword.text;
    final nw = _newPassword.text;
    final cf = _confirmPassword.text;
    if (cur.isEmpty || nw.isEmpty) {
      setState(() {
        _settingsMessage = "Enter current and new password.";
        _settingsMessageIsError = true;
      });
      return;
    }
    if (nw.length < 6) {
      setState(() {
        _settingsMessage = "New password must be at least 6 characters.";
        _settingsMessageIsError = true;
      });
      return;
    }
    if (nw != cf) {
      setState(() {
        _settingsMessage = "New passwords do not match.";
        _settingsMessageIsError = true;
      });
      return;
    }
    final accountId = _extractAccountId(_user) ?? _extractAccountId(widget.user);
    if (accountId == null) {
      setState(() {
        _settingsMessage = "Cannot save: account id is missing.";
        _settingsMessageIsError = true;
      });
      return;
    }
    setState(() {
      _pwBusy = true;
      _settingsMessage = "";
    });
    try {
      final res = await _api.changeDriverPassword(
        driverId: accountId,
        currentPassword: cur,
        newPassword: nw,
      );
      if (!mounted) {
        return;
      }
      if (res["success"] == true) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        setState(() {
          _settingsMessage = (res["message"] ?? "Password updated.").toString();
          _settingsMessageIsError = false;
        });
      } else {
        setState(() {
          _settingsMessage = (res["error"] ?? "Could not change password.").toString();
          _settingsMessageIsError = true;
        });
      }
    } catch (exc) {
      if (mounted) {
        setState(() {
          _settingsMessage = "$exc";
          _settingsMessageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pwBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_user["first_name"] ?? "").toString().trim();
    final lastName = (_user["last_name"] ?? "").toString().trim();
    final username = (_user["username"] ?? "").toString().trim();
    final statusRaw = (_user["status"] ?? "").toString().trim();
    final status = statusRaw.isEmpty ? "pending" : statusRaw;
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
          if (_settingsMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _settingsMessage,
                style: TextStyle(
                  color: _settingsMessageIsError ? Colors.red.shade200 : const Color(0xFFD1FAE5),
                ),
              ),
            ),
          _SectionCard(
            title: "Account & preferences",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _first,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "First name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _last,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "Last name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "Email"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "Phone"),
                ),
                const SizedBox(height: 12),
                Text("Preferences", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _profilePrefOptions
                      .map(
                        (item) => _signupPreferenceChip(
                          item: item,
                          selected: _prefs.contains(item),
                          disabled: _busy,
                          onSelected: (selected) => setState(() => selected ? _prefs.add(item) : _prefs.remove(item)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_busy ? "Saving..." : "Save"),
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
          _SectionCard(
            title: "Change password",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _currentPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "Current password"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "New password"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _shellInputDecoration(label: "Confirm new password"),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _pwBusy ? null : _changePassword,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_pwBusy ? "Updating..." : "Update password"),
                  ),
                ),
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



