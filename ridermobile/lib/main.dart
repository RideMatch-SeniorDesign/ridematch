import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "package:socket_io_client/socket_io_client.dart" as io;

import "api_client.dart";

void main() => runApp(const RiderMobileApp());

const _kRiderApiHost = String.fromEnvironment(
  "API_HOST",
  defaultValue: "10.0.2.2",
);

class RiderMobileApp extends StatelessWidget {
  const RiderMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RideMatch Rider",
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
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0D2137),
          indicatorColor: Colors.white.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? Colors.white : Colors.white54,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
      home: const AppBootstrapGate(),
    );
  }
}

class _SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _key = "rider_user_session_json";

  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> save(Map<String, dynamic> user) async {
    await _storage.write(key: _key, value: jsonEncode(user));
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}

class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  final _session = _SessionStore();
  late final Future<Map<String, dynamic>?> _future = _session.read();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        return user == null ? const RideMatchWelcomePage() : RiderShellPage(user: user);
      },
    );
  }
}

/// Matches driver app: solid deep blue auth shell.
const Color _kAuthDeepBlue = Color(0xFF0A1929);

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

/// Shown on the dashboard: one pill per saved preference (read-only).
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
                      "RIDER",
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
                        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
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
                        MaterialPageRoute<void>(builder: (_) => const RiderSignupPage()),
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _api = ApiClient();
  final _session = _SessionStore();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String _message = "";

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = "";
    });
    try {
      final result = await _api.login(username: _username.text.trim(), password: _password.text);
      if (!mounted) {
        return;
      }
      if (result["success"] == true) {
        final user = Map<String, dynamic>.from((result["user"] as Map?) ?? {});
        await _session.save(user);
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => RiderShellPage(user: user)),
          (route) => false,
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Request failed.";
        });
      }
    } catch (_) {
      setState(() {
        _message = "Could not sign in. Try again.";
      });
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
                      "RIDER",
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
                    controller: _username,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Username"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Password"),
                  ),
                  const SizedBox(height: 20),
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
                      _busy ? "Working..." : "Log in",
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

class RiderSignupPage extends StatefulWidget {
  const RiderSignupPage({super.key});

  @override
  State<RiderSignupPage> createState() => _RiderSignupPageState();
}

class _RiderSignupPageState extends State<RiderSignupPage> {
  final _api = ApiClient();
  final _session = _SessionStore();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _confirm = TextEditingController();
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

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = "";
    });
    try {
      final result = await _api.signup(
        payload: {
          "first_name": _first.text.trim(),
          "last_name": _last.text.trim(),
          "username": _username.text.trim(),
          "email": _email.text.trim(),
          "phone": _phone.text.trim(),
          "password": _password.text,
          "confirm_password": _confirm.text,
          "preferences": _prefs.toList(),
        },
      );
      if (!mounted) {
        return;
      }
      if (result["success"] == true) {
        final user = Map<String, dynamic>.from((result["user"] as Map?) ?? {});
        await _session.save(user);
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => RiderShellPage(user: user)),
          (route) => false,
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Request failed.";
        });
      }
    } catch (_) {
      setState(() {
        _message = "Could not create account. Try again.";
      });
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
                "RIDER",
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
                    "Create your rider profile. You can start using the app as soon as you sign up.",
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
                    controller: _username,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _authFieldDecoration("Username"),
                  ),
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
                      _busy ? "Working..." : "Create account",
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

class RiderShellPage extends StatefulWidget {
  const RiderShellPage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<RiderShellPage> createState() => _RiderShellPageState();
}

class _RiderShellPageState extends State<RiderShellPage> {
  int _index = 0;
  late Map<String, dynamic> _user = Map<String, dynamic>.from(widget.user);
  final _session = _SessionStore();

  Future<void> _persistUser(Map<String, dynamic> updated) async {
    _user = updated;
    setState(() {});
    await _session.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        user: _user,
        onUserUpdated: _persistUser,
        onRequestRide: () => setState(() => _index = 1),
      ),
      RideTab(user: _user),
      RatingTab(user: _user),
      ProfileTab(
        user: _user,
        onSaved: _persistUser,
        onLogout: () async {
          await _session.clear();
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
    const titles = ["Dashboard", "Ride", "Rating", "Profile"];
    return Scaffold(
      backgroundColor: _kAuthDeepBlue,
      appBar: AppBar(title: Text(titles[_index])),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: "Dashboard"),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: "Ride"),
          NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star), label: "Rating"),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onRequestRide,
  });
  final Map<String, dynamic> user;
  final Future<void> Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback onRequestRide;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _trips = [];

  static List<String> _prefsListFromUser(Map<String, dynamic> user) {
    final raw = (user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    raw.sort();
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchDashboard(riderId: _id(widget.user));
      if (!mounted) {
        return;
      }
      final ok = res["success"] == true;
      final refreshed = res["user"] is Map ? Map<String, dynamic>.from(res["user"] as Map) : null;
      setState(() {
        _summary = Map<String, dynamic>.from((res["summary"] as Map?) ?? {});
        _trips = ((res["trips"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _error = ok ? "" : (res["error"]?.toString() ?? "Could not load dashboard.");
      });
      if (ok && refreshed != null) {
        await widget.onUserUpdated(refreshed);
      }
    } catch (exc) {
      setState(() {
        _loading = false;
        _error = "$exc";
      });
    }
  }

  List<Widget> _tripDetailTipWidgets(Map<String, dynamic> trip) {
    final tip = double.tryParse((trip["tip_amount"] ?? "").toString());
    if (tip == null || tip <= 0) {
      return [];
    }
    return [
      const SizedBox(height: 8),
      Text(
        "Tip: \$${tip.toStringAsFixed(2)}",
        style: const TextStyle(color: Color(0xFF7EB3FF), fontWeight: FontWeight.w600),
      ),
    ];
  }

  void _showTripInfo(Map<String, dynamic> trip) {
    final cost = trip["final_cost"];
    final costLabel = cost == null ? "Not finalized yet" : "\$$cost";
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
              ..._tripDetailTipWidgets(trip),
              const SizedBox(height: 8),
              Text(
                "Tips are optional and go to your driver in full. Add one when you rate a completed trip.",
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
    if (trip["rider_rate"] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You already left a rating for this trip.")),
      );
      return;
    }
    await showRiderTripReviewSheet(
      context,
      api: _api,
      riderId: _id(widget.user),
      trip: trip,
      onSubmitted: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final welcomeFirst = (widget.user["first_name"] ?? "").toString().trim();
    final rideHeroTitle = welcomeFirst.isEmpty ? "Request a ride" : "Welcome, $welcomeFirst";
    final currentPrefs = _prefsListFromUser(widget.user);
    return _PageShell(
      child: RefreshIndicator(
        color: const Color(0xFF7EB3FF),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onRequestRide,
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
                              rideHeroTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Set pickup, dropoff, and track your trip on the map.",
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
            if (_error.isNotEmpty) _Notice(_error, true),
            if (_error.isNotEmpty) const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))))
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Stat("Completed trips", "${_summary["completed_count"] ?? 0}"),
                  _Stat("Your rating", _metric(_summary["avg_received_rating"])),
                ],
              ),
              const SizedBox(height: 16),
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Ride preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      "What drivers see for your rides. Edit these on your profile.",
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
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Recent rides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (_trips.isEmpty)
                      Text("No rides yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
                    else
                      ..._trips.take(8).map((trip) => _DashboardTripRow(
                            trip: trip,
                            onInfo: () => _showTripInfo(trip),
                            onReview: () => _openReviewForTrip(trip),
                          )),
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

class _DashboardTripRow extends StatelessWidget {
  const _DashboardTripRow({required this.trip, required this.onInfo, required this.onReview});
  final Map<String, dynamic> trip;
  final VoidCallback onInfo;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final route = "${trip["start_loc"] ?? "—"} → ${trip["end_loc"] ?? "—"}";
    final driver = (trip["driver_name"] ?? "Unassigned").toString();
    final status = _title(trip["status"]);
    final completed = (trip["status"] ?? "").toString().toLowerCase() == "completed";
    final needsReview = completed && trip["rider_rate"] == null;
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
            Text("$driver · $status", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline, size: 20),
                  style: IconButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.12)),
                  tooltip: "Fare & tip info",
                ),
                const SizedBox(width: 4),
                if (completed)
                  TextButton.icon(
                    onPressed: onReview,
                    icon: Icon(needsReview ? Icons.rate_review_outlined : Icons.check_circle_outline, size: 18),
                    label: Text(needsReview ? "Review trip" : "Reviewed"),
                    style: TextButton.styleFrom(foregroundColor: needsReview ? const Color(0xFF7EB3FF) : Colors.white54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RideTab extends StatefulWidget {
  const RideTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<RideTab> createState() => _RideTabState();
}

class _RideTabState extends State<RideTab> {
  final _api = ApiClient();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _notes = TextEditingController();
  Timer? _poll;
  Timer? _pickupSuggestTimer;
  Timer? _dropoffSuggestTimer;
  io.Socket? _socket;
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropoffSuggestions = [];
  bool _pickupSuggestLoading = false;
  bool _dropoffSuggestLoading = false;
  bool _suppressPickupSuggest = false;
  bool _suppressDropoffSuggest = false;
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _matchCandidates = [];
  String _message = "";
  bool _busy = false;
  bool _loadingMatches = false;
  bool _showMatchDeckOnly = false;
  String _rideType = "standard";
  LatLng? _pickupPoint;
  LatLng? _dropoffPoint;
  LatLng? _driverPoint;
  final Set<int> _autoShownReviewTripIds = <int>{};

  @override
  void initState() {
    super.initState();
    _pickup.addListener(_onPickupTextChanged);
    _dropoff.addListener(_onDropoffTextChanged);
    _load();
    _connectRealTime();
    _poll = Timer.periodic(const Duration(seconds: 7), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pickupSuggestTimer?.cancel();
    _dropoffSuggestTimer?.cancel();
    _pickup.removeListener(_onPickupTextChanged);
    _dropoff.removeListener(_onDropoffTextChanged);
    _pickup.dispose();
    _dropoff.dispose();
    _notes.dispose();
    _socket?.dispose();
    super.dispose();
  }

  void _onPickupTextChanged() {
    if (_trip == null && _matchCandidates.isNotEmpty) {
      setState(() {
        _matchCandidates = [];
        _showMatchDeckOnly = false;
      });
    }
    if (_suppressPickupSuggest) {
      return;
    }
    _pickupSuggestTimer?.cancel();
    _pickupSuggestTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted) {
        _runAddressAutocomplete(isPickup: true);
      }
    });
  }

  void _onDropoffTextChanged() {
    if (_trip == null && _matchCandidates.isNotEmpty) {
      setState(() {
        _matchCandidates = [];
        _showMatchDeckOnly = false;
      });
    }
    if (_suppressDropoffSuggest) {
      return;
    }
    _dropoffSuggestTimer?.cancel();
    _dropoffSuggestTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted) {
        _runAddressAutocomplete(isPickup: false);
      }
    });
  }

  String _autocompleteLabel(Map<String, dynamic> item) {
    final formatted = item["formatted"];
    if (formatted != null && formatted.toString().trim().isNotEmpty) {
      return formatted.toString();
    }
    final line = (item["address_line1"] ?? item["name"] ?? "").toString().trim();
    final place = (item["city"] ?? item["state"] ?? "").toString().trim();
    if (line.isNotEmpty && place.isNotEmpty) {
      return "$line, $place";
    }
    return line.isNotEmpty ? line : "Address";
  }

  Future<void> _runAddressAutocomplete({required bool isPickup}) async {
    final controller = isPickup ? _pickup : _dropoff;
    final query = controller.text.trim();
    if (query.length < 3) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (isPickup) {
          _pickupSuggestions = [];
        } else {
          _dropoffSuggestions = [];
        }
      });
      return;
    }
    setState(() {
      if (isPickup) {
        _pickupSuggestLoading = true;
      } else {
        _dropoffSuggestLoading = true;
      }
    });
    try {
      final maps = await _api.fetchMapsConfig();
      final key = (maps["geoapify_api_key"] ?? "").toString().trim();
      if (key.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          if (isPickup) {
            _pickupSuggestions = [];
            _pickupSuggestLoading = false;
          } else {
            _dropoffSuggestions = [];
            _dropoffSuggestLoading = false;
          }
        });
        return;
      }
      final res = await _api.geocodeAddress(
        apiKey: key,
        address: query,
        proximityLatitude: _pickupPoint?.latitude,
        proximityLongitude: _pickupPoint?.longitude,
      );
      final raw = (res["results"] as List?) ?? [];
      final list = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (isPickup) {
          _pickupSuggestions = list.take(5).toList();
          _pickupSuggestLoading = false;
        } else {
          _dropoffSuggestions = list.take(5).toList();
          _dropoffSuggestLoading = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (isPickup) {
          _pickupSuggestions = [];
          _pickupSuggestLoading = false;
        } else {
          _dropoffSuggestions = [];
          _dropoffSuggestLoading = false;
        }
      });
    }
  }

  void _applyAutocomplete(Map<String, dynamic> item, {required bool isPickup}) {
    final label = _autocompleteLabel(item);
    final lat = item["lat"];
    final lon = item["lon"];
    final pt = _point(lat, lon);
    _pickupSuggestTimer?.cancel();
    _dropoffSuggestTimer?.cancel();
    if (isPickup) {
      _suppressPickupSuggest = true;
      _pickup.text = label;
    } else {
      _suppressDropoffSuggest = true;
      _dropoff.text = label;
    }
    setState(() {
      if (isPickup) {
        _pickupPoint = pt;
        _pickupSuggestions = [];
        _pickupSuggestLoading = false;
      } else {
        _dropoffPoint = pt;
        _dropoffSuggestions = [];
        _dropoffSuggestLoading = false;
      }
      if (_trip == null) {
        _matchCandidates = [];
        _showMatchDeckOnly = false;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (isPickup) {
        _suppressPickupSuggest = false;
      } else {
        _suppressDropoffSuggest = false;
      }
    });
    FocusScope.of(context).unfocus();
  }

  Widget _addressSuggestions({
    required List<Map<String, dynamic>> items,
    required bool isPickup,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            itemBuilder: (context, i) {
              final item = items[i];
              final title = _autocompleteLabel(item);
              return ListTile(
                dense: true,
                leading: Icon(Icons.place_outlined, size: 20, color: Colors.white.withValues(alpha: 0.75)),
                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                onTap: () => _applyAutocomplete(item, isPickup: isPickup),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchActiveTrip(riderId: _id(widget.user));
      if (!mounted) {
        return;
      }
      final trip = res["trip"];
      final nextTrip = trip is Map ? Map<String, dynamic>.from(trip) : null;
      final hadTrip = _trip != null;
      setState(() {
        _trip = nextTrip;
        _driverPoint = _point(_trip?["driver_latitude"], _trip?["driver_longitude"]);
        if (_trip != null) {
          _matchCandidates = [];
          _showMatchDeckOnly = false;
        }
      });
      if (hadTrip && nextTrip == null) {
        await _promptPostRideReviewIfPending();
      }
    } catch (_) {}
  }

  Future<void> _promptPostRideReviewIfPending() async {
    try {
      final res = await _api.fetchPendingReviews(riderId: _id(widget.user));
      if (!mounted || res["success"] != true) {
        return;
      }
      final list = (res["pending"] as List?) ?? [];
      for (final raw in list) {
        if (raw is! Map) {
          continue;
        }
        final trip = Map<String, dynamic>.from(raw);
        final tid = _int(trip["trip_id"]);
        if (tid == null) {
          continue;
        }
        if (_autoShownReviewTripIds.contains(tid)) {
          continue;
        }
        _autoShownReviewTripIds.add(tid);
        if (!mounted) {
          return;
        }
        await showRiderTripReviewSheet(
          context,
          api: _api,
          riderId: _id(widget.user),
          trip: trip,
          onSubmitted: _load,
        );
        break;
      }
    } catch (_) {}
  }

  Future<void> _useLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied.");
      }
      final position = await Geolocator.getCurrentPosition();
      final maps = await _api.fetchMapsConfig();
      final key = (maps["geoapify_api_key"] ?? "").toString().trim();
      if (key.isEmpty) {
        throw Exception("GEOAPIFY_API_KEY is not configured yet.");
      }
      final res = await _api.reverseGeocode(apiKey: key, latitude: position.latitude, longitude: position.longitude);
      final results = (res["results"] as List?) ?? [];
      final formatted = results.isNotEmpty && results.first is Map ? ((results.first as Map)["formatted"] ?? "").toString() : "";
      setState(() {
        _pickup.text = formatted.isEmpty ? "${position.latitude}, ${position.longitude}" : formatted;
        _pickupPoint = LatLng(position.latitude, position.longitude);
        if (_trip == null) {
          _matchCandidates = [];
          _showMatchDeckOnly = false;
        }
      });
    } catch (exc) {
      setState(() => _message = "$exc");
    }
  }

  Future<void> _requestRide() async {
    setState(() {
      _busy = true;
      _loadingMatches = true;
      _message = "";
    });
    try {
      if (_pickup.text.trim().isEmpty || _dropoff.text.trim().isEmpty) {
        setState(() => _message = "Pickup and dropoff locations are required.");
        return;
      }
      final maps = await _api.fetchMapsConfig();
      final key = (maps["geoapify_api_key"] ?? "").toString().trim();
      if (key.isNotEmpty) {
        if (_pickupPoint == null && _pickup.text.trim().isNotEmpty) {
          final start = await _api.geocodeAddress(apiKey: key, address: _pickup.text.trim());
          final startResults = (start["results"] as List?) ?? [];
          if (startResults.isNotEmpty && startResults.first is Map) {
            final first = Map<String, dynamic>.from(startResults.first as Map);
            _pickupPoint = _point(first["lat"], first["lon"]);
          }
        }
        if (_dropoffPoint == null && _dropoff.text.trim().isNotEmpty) {
          final end = await _api.geocodeAddress(
            apiKey: key,
            address: _dropoff.text.trim(),
            proximityLatitude: _pickupPoint?.latitude,
            proximityLongitude: _pickupPoint?.longitude,
          );
          final results = (end["results"] as List?) ?? [];
          if (results.isNotEmpty && results.first is Map) {
            final first = Map<String, dynamic>.from(results.first as Map);
            _dropoffPoint = _point(first["lat"], first["lon"]);
          }
        }
      }
      final res = await _api.fetchMatchCandidates(
        riderId: _id(widget.user),
        startLoc: _pickup.text.trim(),
        endLoc: _dropoff.text.trim(),
        rideType: _rideType,
        notes: _notes.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final trip = res["trip"];
      final nextTrip = trip is Map ? Map<String, dynamic>.from(trip) : null;
      final rawCandidates = (res["candidates"] as List?) ?? const [];
      final nextCandidates = rawCandidates.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _trip = nextTrip;
        _driverPoint = _point(_trip?["driver_latitude"], _trip?["driver_longitude"]);
        _matchCandidates = nextTrip == null ? nextCandidates : [];
        _showMatchDeckOnly = nextTrip == null && nextCandidates.isNotEmpty;
        if (res["success"] == true) {
          if (nextTrip != null) {
            _message = "You already have an active ride.";
          } else if (nextCandidates.isEmpty) {
            _message = "No available drivers right now. Try again in a minute.";
          } else {
            _message = "Swipe right to request this driver or left to keep browsing.";
          }
        } else {
          _message = res["error"]?.toString() ?? "Could not load driver matches.";
        }
      });
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadingMatches = false;
        });
      }
    }
  }

  Future<bool> _submitSwipe(String direction) async {
    if (_matchCandidates.isEmpty) {
      return false;
    }
    final candidate = Map<String, dynamic>.from(_matchCandidates.first);
    final driverId = _int(candidate["account_id"]);
    if (driverId == null) {
      return false;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.submitMatchChoice(
        riderId: _id(widget.user),
        driverId: driverId,
        direction: direction,
        startLoc: _pickup.text.trim(),
        endLoc: _dropoff.text.trim(),
        rideType: _rideType,
        notes: _notes.text.trim(),
      );
      if (!mounted) {
        return false;
      }
      if (res["success"] != true) {
        setState(() => _message = res["error"]?.toString() ?? "Could not save your swipe.");
        return false;
      }
      if (direction == "right") {
        final trip = res["trip"];
        final nextTrip = trip is Map ? Map<String, dynamic>.from(trip) : null;
        setState(() {
          _trip = nextTrip;
          _driverPoint = _point(_trip?["driver_latitude"], _trip?["driver_longitude"]);
          _matchCandidates = [];
          _showMatchDeckOnly = false;
          _message = nextTrip != null
              ? "Ride request sent to ${(candidate["name"] ?? "your driver").toString()}."
              : "Ride request sent.";
        });
        return true;
      }
      setState(() {
        final remainingCandidates = _matchCandidates.skip(1).toList();
        final hasMoreCandidates = remainingCandidates.isNotEmpty;
        _matchCandidates = remainingCandidates;
        _showMatchDeckOnly = hasMoreCandidates;
        _message = hasMoreCandidates
            ? "Passed. Swipe on the next driver."
            : "No more drivers in this deck right now.";
      });
      return true;
    } catch (exc) {
      if (mounted) {
        setState(() => _message = "$exc");
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancelRide() async {
    final tripId = _int(_trip?["trip_id"]);
    if (tripId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.cancelRide(tripId: tripId, riderId: _id(widget.user));
      setState(() {
        _message = res["success"] == true ? "Ride canceled." : (res["error"]?.toString() ?? "Cancel failed.");
        if (res["success"] == true) {
          _trip = null;
          _driverPoint = null;
          _showMatchDeckOnly = false;
        }
      });
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = [
      if (_pickupPoint != null)
        Marker(
          point: _pickupPoint!,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Color(0xFF7EB3FF), size: 30),
        ),
      if (_dropoffPoint != null)
        Marker(
          point: _dropoffPoint!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Color(0xFF5EEAD4), size: 32),
        ),
      if (_driverPoint != null)
        Marker(
          point: _driverPoint!,
          width: 40,
          height: 40,
          child: const Icon(Icons.directions_car, color: Colors.white, size: 30),
        ),
    ];
    final welcomeFirst = (widget.user["first_name"] ?? "").toString().trim();
    final rideHeroTitle = welcomeFirst.isEmpty ? "Request a ride" : "Welcome, $welcomeFirst";
    final messageIsError = !(_message.startsWith("Ride request sent") ||
        _message == "Ride canceled." ||
        _message.startsWith("Passed.") ||
        _message.startsWith("Swipe right") ||
        _message == "You already have an active ride.");
    final isBrowsingMatches = _trip == null && _showMatchDeckOnly && _matchCandidates.isNotEmpty;
    return _PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (_message.isNotEmpty) _Notice(_message, messageIsError),
          if (_message.isNotEmpty) const SizedBox(height: 8),
          _RiderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.white.withValues(alpha: 0.9), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isBrowsingMatches ? "Browse drivers" : rideHeroTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isBrowsingMatches
                      ? "Swipe through the available drivers for this ride request."
                      : _trip == null
                      ? "Set pickup and destination, then browse available drivers with a swipe deck."
                      : "Track your matched driver on the map and manage the trip here.",
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65), height: 1.35),
                ),
                const SizedBox(height: 14),
                if (!isBrowsingMatches) ...[
                  SizedBox(
                    height: 240,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FlutterMap(
                        options: const MapOptions(initialCenter: LatLng(41.6611, -91.5302), initialZoom: 12),
                        children: [
                          TileLayer(
                            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: "com.example.ridermobile",
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_trip == null && !isBrowsingMatches) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _useLocation,
                      icon: const Icon(Icons.gps_fixed, size: 20),
                      label: const Text("Use my current location"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Start typing — matching addresses appear below. Pick one to lock the location.",
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55), height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pickup,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.next,
                    decoration: _riderShellInputDecoration(label: "Pickup").copyWith(
                      suffixIcon: _pickupSuggestLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : Icon(Icons.search, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ),
                  _addressSuggestions(items: _pickupSuggestions, isPickup: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dropoff,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.next,
                    decoration: _riderShellInputDecoration(label: "Dropoff").copyWith(
                      suffixIcon: _dropoffSuggestLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : Icon(Icons.search, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ),
                  _addressSuggestions(items: _dropoffSuggestions, isPickup: false),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _rideType, // ignore: deprecated_member_use — controlled selection
                    dropdownColor: const Color(0xFF152A42),
                    style: const TextStyle(color: Colors.white),
                    decoration: _riderShellInputDecoration(label: "Ride type"),
                    items: const [
                      DropdownMenuItem(value: "standard", child: Text("Standard")),
                      DropdownMenuItem(value: "shared", child: Text("Shared")),
                      DropdownMenuItem(value: "priority", child: Text("Priority")),
                    ],
                    onChanged: (value) => setState(() => _rideType = value ?? "standard"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: _riderShellInputDecoration(label: "Notes for driver"),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _requestRide,
                      icon: Icon(_loadingMatches ? Icons.hourglass_top_rounded : Icons.swipe_rounded),
                      label: Text(_loadingMatches ? "Loading matches..." : "Find drivers"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kAuthDeepBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_matchCandidates.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.swipe_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "${_matchCandidates.length} driver${_matchCandidates.length == 1 ? "" : "s"} ready",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Swipe left to pass, or swipe right to request this driver.",
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.62)),
                    ),
                    const SizedBox(height: 14),
                    if (_matchCandidates.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 18, right: 18, bottom: 10),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    Dismissible(
                      key: ValueKey("driver-card-${_matchCandidates.first["account_id"]}"),
                      direction: _busy ? DismissDirection.none : DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _submitSwipe("right");
                          return false;
                        }
                        if (direction == DismissDirection.endToStart) {
                          await _submitSwipe("left");
                          return false;
                        }
                        return false;
                      },
                      background: const _SwipeActionBackground(
                        alignment: Alignment.centerLeft,
                        color: Color(0xFF14B8A6),
                        icon: Icons.favorite_rounded,
                        label: "Request",
                      ),
                      secondaryBackground: const _SwipeActionBackground(
                        alignment: Alignment.centerRight,
                        color: Color(0xFFEF4444),
                        icon: Icons.close_rounded,
                        label: "Pass",
                      ),
                      child: _MatchCandidateCard(candidate: _matchCandidates.first),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _submitSwipe("left"),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text("Swipe left"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _submitSwipe("right"),
                            icon: const Icon(Icons.favorite_rounded),
                            label: const Text("Swipe right"),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _kAuthDeepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else if (isBrowsingMatches) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pickup",
                                style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.55)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _pickup.text.trim().isEmpty ? "Not set" : _pickup.text.trim(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dropoff",
                                style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.55)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _dropoff.text.trim().isEmpty ? "Not set" : _dropoff.text.trim(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _showMatchDeckOnly = false;
                              });
                            },
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: const Text("Edit ride details"),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.swipe_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "${_matchCandidates.length} driver${_matchCandidates.length == 1 ? "" : "s"} ready",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Swipe left to pass, or swipe right to request this driver.",
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.62)),
                  ),
                  const SizedBox(height: 14),
                  if (_matchCandidates.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 10),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Dismissible(
                    key: ValueKey("driver-card-${_matchCandidates.first["account_id"]}"),
                    direction: _busy ? DismissDirection.none : DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        await _submitSwipe("right");
                        return false;
                      }
                      if (direction == DismissDirection.endToStart) {
                        await _submitSwipe("left");
                        return false;
                      }
                      return false;
                    },
                    background: const _SwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      color: Color(0xFF14B8A6),
                      icon: Icons.favorite_rounded,
                      label: "Request",
                    ),
                    secondaryBackground: const _SwipeActionBackground(
                      alignment: Alignment.centerRight,
                      color: Color(0xFFEF4444),
                      icon: Icons.close_rounded,
                      label: "Pass",
                    ),
                    child: _MatchCandidateCard(candidate: _matchCandidates.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _submitSwipe("left"),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text("Swipe left"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _submitSwipe("right"),
                          icon: const Icon(Icons.favorite_rounded),
                          label: const Text("Swipe right"),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _kAuthDeepBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _RiderRow("Status", _title(_trip?["status"])),
                  _RiderRow("Driver", (_trip?["driver_name"] ?? "Pending assignment").toString()),
                  _RiderRow("Pickup", (_trip?["start_loc"] ?? "N/A").toString()),
                  _RiderRow("Dropoff", (_trip?["end_loc"] ?? "N/A").toString()),
                  _RiderRow("Driver location", (_trip?["driver_location_updated_at"] ?? "Waiting for driver location").toString()),
                  if (["requested", "accepted"].contains((_trip?["status"] ?? "").toString())) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _cancelRide,
                        icon: const Icon(Icons.close),
                        label: Text(_busy ? "Canceling..." : "Cancel ride"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isLeftAligned = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.82),
            color.withValues(alpha: 0.56),
          ],
          begin: isLeftAligned ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeftAligned ? Alignment.centerRight : Alignment.centerLeft,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeftAligned) ...[
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white, size: 28),
          if (isLeftAligned) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ],
      ),
    );
  }
}

class _MatchCandidateCard extends StatelessWidget {
  const _MatchCandidateCard({required this.candidate});

  final Map<String, dynamic> candidate;

  @override
  Widget build(BuildContext context) {
    final name = (candidate["name"] ?? "Driver").toString();
    final rating = double.tryParse("${candidate["rating"] ?? ""}") ?? 0;
    final rides = int.tryParse("${candidate["rides"] ?? ""}") ?? 0;
    final rideType = (candidate["ride_type"] ?? "standard").toString();
    final photoUrl = _resolveRiderApiUrl((candidate["photo_url"] ?? "").toString().trim());
    final preferences = _splitListString(candidate["preferences"]);
    final matchingPreferences = ((candidate["matching_preferences"] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF132B47), Color(0xFF0E2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 196,
              width: double.infinity,
              child: photoUrl.isEmpty
                  ? _MatchPhotoFallback(name: name)
                  : _MatchPhoto(url: photoUrl, name: name),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_title(rideType)} ride match",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MatchStatPill(icon: Icons.star_rounded, label: rating <= 0 ? "New driver" : "${rating.toStringAsFixed(1)} rating"),
              _MatchStatPill(icon: Icons.route_rounded, label: "$rides rides"),
              _MatchStatPill(
                icon: Icons.favorite_border_rounded,
                label: "${candidate["compatibility_score"] ?? 0} shared prefs",
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Shared vibe",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (matchingPreferences.isEmpty)
            Text(
              "No saved preference overlap yet, but this driver is available now.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13, height: 1.35),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matchingPreferences
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7EB3FF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF7EB3FF).withValues(alpha: 0.28)),
                      ),
                      child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          if (preferences.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Driver preferences",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              preferences.join(", "),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MatchRouteLine(label: "Pickup", value: (candidate["pickup_preview"] ?? "").toString()),
                const SizedBox(height: 8),
                _MatchRouteLine(label: "Dropoff", value: (candidate["dropoff_preview"] ?? "").toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPhotoFallback extends StatelessWidget {
  const _MatchPhotoFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? "D" : name.trim()[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF183A5A), Color(0xFF0D2137)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -12,
            top: -10,
            child: Icon(
              Icons.local_taxi_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPhoto extends StatefulWidget {
  const _MatchPhoto({required this.url, required this.name});

  final String url;
  final String name;

  @override
  State<_MatchPhoto> createState() => _MatchPhotoState();
}

class _MatchPhotoState extends State<_MatchPhoto> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MatchPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) {
        return;
      }
      final data = response.data;
      if (data == null || data.isEmpty) {
        setState(() {
          _bytes = null;
          _loading = false;
        });
        return;
      }
      setState(() {
        _bytes = Uint8List.fromList(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = null;
        _loading = false;
      });
    }
  }

  void _connectRealtime() {
    final socket = io.io(
      "http://10.0.2.2:8002",
      <String, dynamic>{
        "transports": ["websocket"],
        "autoConnect": false,
      },
    );

    socket.on("connect", (_) {
      socket.emit("subscribe", {
        "role": "rider",
        "account_id": _id(widget.user).toString(),
      });
    });

    socket.on("trip_updated", (_) async {
      if (!mounted) return;
      await _load();
    });

    socket.on("driver_location_updated", (data) async {
      if (!mounted) return;
      // update map / driver marker here
      await _load();
    });

    socket.on("ride_request_accepted", (data) {
      if (!mounted) return;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final title = (map["title"] ?? "Ride accepted").toString();
      final message = (map["message"] ?? "Your driver accepted the ride.").toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title\n$message")),
      );
    });

    socket.on("driver_arrived", (data) {
      if (!mounted) return;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final title = (map["title"] ?? "Driver arrived").toString();
      final message = (map["message"] ?? "Your driver is at pickup.").toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title\n$message")),
      );
    });

    socket.connect();
    _socket = socket;
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    if (_loading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _MatchPhotoFallback(name: widget.name),
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    return _MatchPhotoFallback(name: widget.name);
  }
}

class _MatchStatPill extends StatelessWidget {
  const _MatchStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7EB3FF), size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _MatchRouteLine extends StatelessWidget {
  const _MatchRouteLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontSize: 11.5)),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? "Not set" : value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class RatingTab extends StatefulWidget {
  const RatingTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<RatingTab> createState() => _RatingTabState();
}

class _RatingTabState extends State<RatingTab> {
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
    try {
      final dash = await _api.fetchDashboard(riderId: _id(widget.user));
      final rev = await _api.fetchReviews(riderId: _id(widget.user));
      final pend = await _api.fetchPendingReviews(riderId: _id(widget.user));
      final tripsRes = await _api.fetchTrips(riderId: _id(widget.user));
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

  double? get _avgReceived {
    final v = _summary["avg_received_rating"];
    if (v == null) {
      return null;
    }
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: RefreshIndicator(
        color: const Color(0xFF7EB3FF),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error.isNotEmpty) _Notice(_error, true),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7EB3FF))),
              )
            else ...[
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Your rider rating", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "Average from drivers after completed trips.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StarRow(rating: _avgReceived, starSize: 32),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _avgReceived == null ? "Not enough data" : "${_avgReceived!.toStringAsFixed(1)} / 5",
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
                _RiderCard(
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
                        "Rate your recent drivers to help the community.",
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
                              onTap: () => showRiderTripReviewSheet(
                                context,
                                api: _api,
                                riderId: _id(widget.user),
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
                                            "Driver: ${trip["driver_name"] ?? "—"}",
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
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Last 10 drivers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      "Review drivers from your 10 most recent completed trips whenever you want.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 12),
                    if (_recentCompleted.isEmpty)
                      Text("No completed trips yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
                    else
                      ..._recentCompleted.map(
                        (trip) {
                          final alreadyReviewed = trip["rider_rate"] != null;
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
                                          "Driver: ${trip["driver_name"] ?? "Unknown driver"}",
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
                                        "Reviewed ${trip["rider_rate"]}/5",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: () => showRiderTripReviewSheet(
                                        context,
                                        api: _api,
                                        riderId: _id(widget.user),
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
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Anonymous feedback you received", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      "Drivers rate you after trips; names stay private.",
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 12),
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
                                    _StarRow(
                                      rating: double.tryParse((row["rating"] ?? "").toString()),
                                      starSize: 18,
                                    ),
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
              _RiderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reviews you gave drivers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (_given.isEmpty)
                      Text("You have not submitted reviews yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.65)))
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _StarRow(
                                      rating: double.tryParse((row["rating"] ?? "").toString()),
                                      starSize: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "To ${row["counterpart_name"] ?? "driver"}",
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((row["comment"] ?? "").toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    (row["comment"] ?? "").toString(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.user, required this.onSaved, required this.onLogout});
  final Map<String, dynamic> user;
  final Future<void> Function(Map<String, dynamic>) onSaved;
  final Future<void> Function() onLogout;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _api = ApiClient();
  late final TextEditingController _first = TextEditingController(text: (widget.user["first_name"] ?? "").toString());
  late final TextEditingController _last = TextEditingController(text: (widget.user["last_name"] ?? "").toString());
  late final TextEditingController _email = TextEditingController(text: (widget.user["email"] ?? "").toString());
  late final TextEditingController _phone = TextEditingController(text: (widget.user["phone"] ?? "").toString());
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final Set<String> _prefs = ((widget.user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty)).toSet();
  String _message = "";
  bool _busy = false;
  bool _pwBusy = false;

  static const _options = [
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

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final res = await _api.updateProfile(riderId: _id(widget.user), payload: {
        "first_name": _first.text.trim(),
        "last_name": _last.text.trim(),
        "email": _email.text.trim(),
        "phone": _phone.text.trim(),
        "preferences": _prefs.toList(),
      });
      if (res["success"] == true && res["user"] is Map) {
        final updated = Map<String, dynamic>.from(res["user"] as Map);
        await widget.onSaved(updated);
        setState(() => _message = res["message"]?.toString() ?? "Rider settings updated.");
      } else {
        setState(() => _message = res["error"]?.toString() ?? "Could not save settings.");
      }
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final cur = _currentPassword.text;
    final nw = _newPassword.text;
    final cf = _confirmPassword.text;
    if (cur.isEmpty || nw.isEmpty) {
      setState(() => _message = "Enter current and new password.");
      return;
    }
    if (nw.length < 6) {
      setState(() => _message = "New password must be at least 6 characters.");
      return;
    }
    if (nw != cf) {
      setState(() => _message = "New passwords do not match.");
      return;
    }
    setState(() {
      _pwBusy = true;
      _message = "";
    });
    try {
      final res = await _api.changePassword(
        riderId: _id(widget.user),
        currentPassword: cur,
        newPassword: nw,
      );
      if (res["success"] == true) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        setState(() => _message = res["message"]?.toString() ?? "Password updated.");
      } else {
        setState(() => _message = res["error"]?.toString() ?? "Could not change password.");
      }
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() => _pwBusy = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final displayName = "${widget.user["first_name"] ?? ""} ${widget.user["last_name"] ?? ""}".trim();
    return _PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _RiderCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1E3A5F), Colors.white.withValues(alpha: 0.25)],
                    ),
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? "Rider" : displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        "@${widget.user["username"] ?? "rider"}",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_message.isNotEmpty) _Notice(_message, _message != "Rider settings updated." && _message != "Password updated."),
          if (_message.isNotEmpty) const SizedBox(height: 12),
          _RiderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                TextField(
                  controller: _first,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "First name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _last,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "Last name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "Email"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "Phone"),
                ),
                const SizedBox(height: 12),
                Text("Preferences", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options
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
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_busy ? "Saving..." : "Save profile"),
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
          const SizedBox(height: 14),
          _RiderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Change password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "Current password"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "New password"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _riderShellInputDecoration(label: "Confirm new password"),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async => widget.onLogout(),
              icon: const Icon(Icons.logout),
              label: const Text("Log out"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _kAuthDeepBlue, child: child);
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, this.error);
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: error ? const Color(0x33FF6B6B) : const Color(0x3322C55E),
        border: Border.all(color: error ? const Color(0x55FF6B6B) : const Color(0x5522C55E)),
      ),
      child: Text(
        message,
        style: TextStyle(color: error ? Colors.red.shade100 : const Color(0xFFD1FAE5)),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
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

class _RiderRow extends StatelessWidget {
  const _RiderRow(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
          ),
          Expanded(child: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.starSize = 24});
  final double? rating;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final r = rating == null ? 0.0 : rating!.clamp(0.0, 5.0);
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

InputDecoration _riderShellInputDecoration({String? label}) {
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

Future<void> showRiderTripReviewSheet(
  BuildContext context, {
  required ApiClient api,
  required int riderId,
  required Map<String, dynamic> trip,
  required VoidCallback onSubmitted,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: const Color(0xFF152A42),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _TripReviewSheetBody(
          api: api,
          riderId: riderId,
          trip: trip,
          onSubmitted: () {
            Navigator.pop(ctx);
            onSubmitted();
          },
        ),
      );
    },
  );
}

class _TripReviewSheetBody extends StatefulWidget {
  const _TripReviewSheetBody({
    required this.api,
    required this.riderId,
    required this.trip,
    required this.onSubmitted,
  });
  final ApiClient api;
  final int riderId;
  final Map<String, dynamic> trip;
  final VoidCallback onSubmitted;

  @override
  State<_TripReviewSheetBody> createState() => _TripReviewSheetBodyState();
}

class _TripReviewSheetBodyState extends State<_TripReviewSheetBody> {
  int _stars = 5;
  final _comment = TextEditingController();
  final _tipCustom = TextEditingController();
  double _tipPreset = 0;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    _tipCustom.dispose();
    super.dispose();
  }

  void _selectTipPreset(double dollars) {
    setState(() {
      _tipPreset = dollars;
      _tipCustom.clear();
    });
  }

  double _effectiveTipDollars() {
    final custom = _tipCustom.text.trim();
    if (custom.isNotEmpty) {
      final v = double.tryParse(custom);
      if (v != null) {
        return v < 0 ? 0 : v;
      }
    }
    return _tipPreset < 0 ? 0 : _tipPreset;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final tid = _int(widget.trip["trip_id"]);
      if (tid == null) {
        return;
      }
      final tip = _effectiveTipDollars();
      final res = await widget.api.submitTripReview(
        tripId: tid,
        riderId: widget.riderId,
        rating: _stars,
        comment: _comment.text.trim(),
        tipAmount: tip,
      );
      if (!mounted) {
        return;
      }
      if (res["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res["message"]?.toString() ?? "Thanks for your feedback.")),
        );
        widget.onSubmitted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res["error"]?.toString() ?? "Could not submit.")),
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
    final presets = <double>[0, 2, 5, 10];
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 40),
                const Expanded(
                  child: Text(
                    "Rate & tip",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: "Close",
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
              decoration: _riderShellInputDecoration(label: "Comment (optional)"),
            ),
            const SizedBox(height: 16),
            Text("Tip (optional)", style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((v) {
                final selected = _tipCustom.text.isEmpty && _tipPreset == v;
                return ChoiceChip(
                  showCheckmark: false,
                  selected: selected,
                  label: Text(v == 0 ? r"$0" : "\$$v"),
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? _kAuthDeepBlue : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: _busy ? null : (_) => _selectTipPreset(v),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tipCustom,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              onChanged: (_) => setState(() {}),
              decoration: _riderShellInputDecoration(label: "Custom tip (\$)"),
            ),
            const SizedBox(height: 8),
            Text(
              "You can close and finish later from Reviews or your trip list. Tips go to your driver in full.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _kAuthDeepBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_busy ? "Submitting..." : "Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _id(Map<String, dynamic> user) => _int(user["account_id"]) ?? 0;
int? _int(dynamic value) => value is int ? value : int.tryParse((value ?? "").toString().split(".").first.trim());
LatLng? _point(dynamic lat, dynamic lng) => double.tryParse((lat ?? "").toString()) != null && double.tryParse((lng ?? "").toString()) != null ? LatLng(double.parse(lat.toString()), double.parse(lng.toString())) : null;
String _metric(dynamic value) => value == null ? "N/A" : value.toString();
String _resolveRiderApiUrl(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return "";
  }
  if (text.startsWith("http://") || text.startsWith("https://")) {
    return text;
  }
  if (text.startsWith("/")) {
    return "http://$_kRiderApiHost:8003$text";
  }
  return "http://$_kRiderApiHost:8003/$text";
}
List<String> _splitListString(dynamic value) => (value ?? "")
    .toString()
    .split(",")
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
String _title(dynamic value) => (value ?? "unknown").toString().replaceAll("_", " ");
