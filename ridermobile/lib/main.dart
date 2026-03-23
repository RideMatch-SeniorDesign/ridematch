import "dart:async";
<<<<<<< HEAD

import "package:flutter/material.dart";

import "api_client.dart";

void main() {
  runApp(const RiderMobileApp());
}
=======
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

import "api_client.dart";

void main() => runApp(const RiderMobileApp());
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f

class RiderMobileApp extends StatelessWidget {
  const RiderMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RideMatch Rider",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
<<<<<<< HEAD
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A4)),
=======
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
        useMaterial3: true,
      ),
      home: const AppBootstrapGate(),
    );
  }
}

<<<<<<< HEAD
=======
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

>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
<<<<<<< HEAD
  final ApiClient _api = ApiClient();
  late final Future<Map<String, dynamic>?> _restoredUserFuture;

  @override
  void initState() {
    super.initState();
    _restoredUserFuture = _api.readSessionUser();
  }
=======
  final _session = _SessionStore();
  late final Future<Map<String, dynamic>?> _future = _session.read();
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
<<<<<<< HEAD
      future: _restoredUserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null && user.isNotEmpty) {
          return RiderShellPage(user: user);
        }
        return const LoginPage();
=======
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        return user == null ? const LoginPage() : RiderShellPage(user: user);
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
<<<<<<< HEAD
  final ApiClient _api = ApiClient();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
      if (!mounted) return;

      if (result["success"] == true) {
        final user = Map<String, dynamic>.from(
          (result["user"] as Map?) ?? <String, dynamic>{},
        );

        if (_rememberMe) {
          await _api.saveSessionUser(user);
        } else {
          await _api.clearSessionUser();
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RiderShellPage(user: user),
          ),
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Login failed.";
        });
      }
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _message = "Request failed: $exc";
=======
  final _api = ApiClient();
  final _session = _SessionStore();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _confirm = TextEditingController();
  bool _signupMode = false;
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
      final result = _signupMode
          ? await _api.signup(
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
            )
          : await _api.login(username: _username.text.trim(), password: _password.text);
      if (!mounted) {
        return;
      }
      if (result["success"] == true) {
        final user = Map<String, dynamic>.from((result["user"] as Map?) ?? {});
        await _session.save(user);
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RiderShellPage(user: user)));
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Request failed.";
        });
      }
    } catch (exc) {
      setState(() {
        _message = "$exc";
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      });
    } finally {
      if (mounted) {
        setState(() {
<<<<<<< HEAD
          _isLoading = false;
=======
          _busy = false;
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
        });
      }
    }
  }

<<<<<<< HEAD
  void _goToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFCFECE6);
    const inputBorder = Color(0xFFBDE2DA);
    const mutedText = Color(0xFF55717D);
    const textColor = Color(0xFF0F2430);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFECFBF8), Color(0xFFF8FFFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
=======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFEAF8F6), Color(0xFFF7FCFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
<<<<<<< HEAD
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8FBF7), Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F2430),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RIDEMATCH RIDER",
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Rider Portal",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Separate login and sign-up for riders.",
                          style: TextStyle(color: mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F2430),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Rider Login",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_message.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                              color: const Color(0xFFFFF1F2),
                            ),
                            child: Text(
                              _message,
                              style: const TextStyle(color: Color(0xFF9F1239)),
                            ),
                          ),
                        const Text("Username", style: TextStyle(fontSize: 14, color: mutedText)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: inputBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: inputBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Password", style: TextStyle(fontSize: 14, color: mutedText)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: inputBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: inputBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                            ),
                            const Text("Remember me", style: TextStyle(color: mutedText)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5A4), Color(0xFF0F766E)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(_isLoading ? "Logging in..." : "Login"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _goToSignup,
                          child: const Text("Need a rider account? Sign up"),
                        ),
                      ],
                    ),
=======
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Hero(title: _signupMode ? "Create your rider profile" : "RideMatch Rider", subtitle: _signupMode ? "Start the mobile rider app with the same account fields as RiderWebpage." : "Sign in to request rides, track a driver, and manage rider preferences."),
                  const SizedBox(height: 14),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_signupMode ? "Rider Sign-Up" : "Rider Login", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      if (_message.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Notice(_message, true),
                      ],
                      if (_signupMode) ...[
                        const SizedBox(height: 12),
                        Row(children: [Expanded(child: _field("First Name", _first)), const SizedBox(width: 12), Expanded(child: _field("Last Name", _last))]),
                        const SizedBox(height: 12),
                        _field("Email", _email, type: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field("Phone", _phone, type: TextInputType.phone),
                      ],
                      const SizedBox(height: 12),
                      _field("Username", _username),
                      const SizedBox(height: 12),
                      _field("Password", _password, obscure: true),
                      if (_signupMode) ...[
                        const SizedBox(height: 12),
                        _field("Confirm Password", _confirm, obscure: true),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: _prefOptions.map((item) => FilterChip(label: Text(item), selected: _prefs.contains(item), onSelected: (selected) => setState(() => selected ? _prefs.add(item) : _prefs.remove(item)))).toList()),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? "Working..." : _signupMode ? "Create Account" : "Login"))),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _busy ? null : () => setState(() => _signupMode = !_signupMode), child: Text(_signupMode ? "Back to Login" : "Create Rider Account"))),
                    ]),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final ApiClient _api = ApiClient();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<String> _preferenceOptions = const [
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

  final Set<String> _selectedPreferences = <String>{};

  bool _isLoading = false;
  String _message = "";
  bool _isError = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignup() async {
    setState(() {
      _isLoading = true;
      _message = "";
      _isError = false;
    });

    try {
      final result = await _api.signup(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        preferences: _selectedPreferences.toList(),
      );

      if (!mounted) return;

      if (result["success"] == true) {
        setState(() {
          _message = result["message"]?.toString() ?? "Rider account created.";
          _isError = false;
        });
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Could not create rider account.";
          _isError = true;
        });
      }
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _message = "Signup failed: $exc";
        _isError = true;
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
    const borderColor = Color(0xFFCFECE6);

    return Scaffold(
      appBar: AppBar(title: const Text("Rider Sign-Up")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_message.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                      color: _isError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                    ),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _isError ? const Color(0xFF9F1239) : const Color(0xFF166534),
                      ),
                    ),
                  ),
                TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: "First Name")),
                const SizedBox(height: 12),
                TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: "Last Name")),
                const SizedBox(height: 12),
                TextField(controller: _usernameController, decoration: const InputDecoration(labelText: "Username")),
                const SizedBox(height: 12),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 12),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone")),
                const SizedBox(height: 16),
                const Text("Preferences", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _preferenceOptions.map((option) {
                    final selected = _selectedPreferences.contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (selected) {
                            _selectedPreferences.remove(option);
                          } else {
                            _selectedPreferences.add(option);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Confirm Password"),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submitSignup,
                    child: Text(_isLoading ? "Creating..." : "Create Rider Account"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
=======

  Widget _field(String label, TextEditingController controller, {bool obscure = false, TextInputType? type}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF365956))),
      const SizedBox(height: 6),
      TextField(controller: controller, obscureText: obscure, keyboardType: type, decoration: _inputDecoration()),
    ]);
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
  }
}

class RiderShellPage extends StatefulWidget {
  const RiderShellPage({super.key, required this.user});
<<<<<<< HEAD

=======
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
  final Map<String, dynamic> user;

  @override
  State<RiderShellPage> createState() => _RiderShellPageState();
}

class _RiderShellPageState extends State<RiderShellPage> {
<<<<<<< HEAD
  int _currentIndex = 0;
  late Map<String, dynamic> _sessionUser;

  @override
  void initState() {
    super.initState();
    _sessionUser = Map<String, dynamic>.from(widget.user);
  }

  Future<void> _logout() async {
    final api = ApiClient();
    await api.clearSessionUser();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      RiderDashboardTab(user: _sessionUser),
      RiderStartRideTab(user: _sessionUser),
      RiderReviewsTab(user: _sessionUser),
      RiderSettingsTab(
        user: _sessionUser,
        onUserUpdated: (updated) async {
          _sessionUser = Map<String, dynamic>.from(updated);
          setState(() {});
          await ApiClient().saveSessionUser(_sessionUser);
        },
        onLogout: _logout,
      ),
    ];

    final titles = ["Dashboard", "Start Ride", "Reviews", "Settings"];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_currentIndex])),
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          NavigationDestination(icon: Icon(Icons.local_taxi_outlined), label: "Start Ride"),
          NavigationDestination(icon: Icon(Icons.reviews_outlined), label: "Reviews"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: "Settings"),
=======
  int _index = 0;
  late Map<String, dynamic> _user = Map<String, dynamic>.from(widget.user);
  final _session = _SessionStore();

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(user: _user),
      RideTab(user: _user),
      ReviewsTab(user: _user),
      ProfileTab(
        user: _user,
        onSaved: (updated) async {
          _user = updated;
          setState(() {});
          await _session.save(updated);
        },
        onLogout: () async {
          await _session.clear();
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        },
      ),
    ];
    const titles = ["Dashboard", "Start Ride", "Reviews", "Profile"];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: "Ride"),
          NavigationDestination(icon: Icon(Icons.star_outline), label: "Reviews"),
          NavigationDestination(icon: Icon(Icons.person_outline), label: "Profile"),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
        ],
      ),
    );
  }
}

<<<<<<< HEAD
class RiderDashboardTab extends StatefulWidget {
  const RiderDashboardTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<RiderDashboardTab> createState() => _RiderDashboardTabState();
}

class _RiderDashboardTabState extends State<RiderDashboardTab> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _message = "";
  Map<String, dynamic> _summary = <String, dynamic>{};
  List<dynamic> _trips = <dynamic>[];

  int? _extractAccountId() {
    final raw = widget.user["account_id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? "").toString().trim());
  }
=======
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _trips = [];
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final riderId = _extractAccountId();
    if (riderId == null) {
      setState(() {
        _loading = false;
        _message = "Missing rider account id.";
      });
      return;
    }

    try {
      final result = await _api.fetchDashboard(riderId: riderId);
      if (!mounted) return;

      setState(() {
        _summary = Map<String, dynamic>.from(
          (result["summary"] as Map?) ?? <String, dynamic>{},
        );
        _trips = (result["trips"] as List?) ?? <dynamic>[];
        _message = result["error"]?.toString() ?? "";
        _loading = false;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = "Could not load dashboard: $exc";
=======
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchDashboard(riderId: _id(widget.user));
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = Map<String, dynamic>.from((res["summary"] as Map?) ?? {});
        _trips = ((res["trips"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _error = res["success"] == true ? "" : (res["error"]?.toString() ?? "Could not load dashboard.");
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _error = "$exc";
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      });
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final firstName = (widget.user["first_name"] ?? "").toString().trim();
    final username = (widget.user["username"] ?? "").toString().trim();
    final greetingName = firstName.isNotEmpty ? firstName : (username.isNotEmpty ? username : "Rider");

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFECFBF8), Color(0xFFF8FFFD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCFECE6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "RIDEMATCH RIDER",
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Welcome back, $greetingName",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF0F2430),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "@$username",
                        style: const TextStyle(color: Color(0xFF55717D)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_message.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_message),
                  ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _StatCard(title: "Total Rides", value: "${_summary["trip_count"] ?? 0}"),
                    _StatCard(title: "Completed", value: "${_summary["completed_count"] ?? 0}"),
                    _StatCard(title: "Active", value: "${_summary["active_count"] ?? 0}"),
                    _StatCard(title: "Ratings Given", value: "${_summary["avg_given_rating"] ?? "N/A"}"),
                    _StatCard(title: "Ratings Received", value: "${_summary["avg_received_rating"] ?? "N/A"}"),
                    _StatCard(title: "Preferences", value: (widget.user["preferences"] ?? "None").toString()),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: "Recent Rides",
                  child: _trips.isEmpty
                      ? const Text("No rides yet.", style: TextStyle(color: Color(0xFF55717D)))
                      : Column(
                          children: _trips.map((trip) {
                            final row = Map<String, dynamic>.from(trip as Map);
                            return _TripRow(
                              id: "${row["trip_id"] ?? ""}",
                              status: (row["status"] ?? "").toString(),
                              route: "${row["start_loc"] ?? "N/A"} -> ${row["end_loc"] ?? "N/A"}",
                              rider: "Driver: ${row["driver_name"] ?? "Unknown"}",
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
=======
    final prefs = (widget.user["preferences"] ?? "").toString().trim();
    return _PageShell(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _Hero(title: "Rider overview", subtitle: "Recent rides, trip totals, ratings, and saved ride preferences."),
          const SizedBox(height: 12),
          if (_error.isNotEmpty) _Notice(_error, true),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Stat("Total Rides", "${_summary["trip_count"] ?? 0}"),
              _Stat("Completed", "${_summary["completed_count"] ?? 0}"),
              _Stat("Active", "${_summary["active_count"] ?? 0}"),
              _Stat("Ratings Given", _metric(_summary["avg_given_rating"])),
              _Stat("Ratings Received", _metric(_summary["avg_received_rating"])),
            ]),
            const SizedBox(height: 12),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Preferences", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Text(prefs.isEmpty ? "No preferences selected yet." : prefs)])),
            const SizedBox(height: 12),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Recent Rides", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 10), if (_trips.isEmpty) const Text("No rides yet.") else ..._trips.take(5).map((trip) => _Row("${trip["start_loc"] ?? "N/A"} -> ${trip["end_loc"] ?? "N/A"}", "Driver: ${trip["driver_name"] ?? "Unassigned"} | ${_title(trip["status"])}"))])),
          ],
        ]),
      ),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
    );
  }
}

<<<<<<< HEAD
class RiderStartRideTab extends StatefulWidget {
  const RiderStartRideTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<RiderStartRideTab> createState() => _RiderStartRideTabState();
}

class _RiderStartRideTabState extends State<RiderStartRideTab> {
  final ApiClient _api = ApiClient();

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _notesController = TextEditingController();

  String _rideType = "standard";
  String _timePref = "asap";
  bool _loading = true;
  bool _submitting = false;
  String _message = "";
  bool _messageIsError = false;
  Map<String, dynamic>? _activeTrip;
  Timer? _refreshTimer;

  int? _extractAccountId() {
    final raw = widget.user["account_id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? "").toString().trim());
  }
=======
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
  Map<String, dynamic>? _trip;
  String _message = "";
  bool _busy = false;
  String _rideType = "standard";
  LatLng? _pickupPoint;
  LatLng? _dropoffPoint;
  LatLng? _driverPoint;
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadActiveTrip();
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && !_submitting) {
        _loadActiveTrip(showLoader: false);
      }
    });
=======
    _load();
    _poll = Timer.periodic(const Duration(seconds: 7), (_) => _load());
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _pickupController.dispose();
    _dropoffController.dispose();
    _notesController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveTrip({bool showLoader = true}) async {
    final riderId = _extractAccountId();
    if (riderId == null) {
      setState(() {
        _loading = false;
        _message = "Missing rider account id.";
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
      final result = await _api.fetchActiveTrip(riderId: riderId);
      if (!mounted) return;

      setState(() {
        _activeTrip = result["trip"] is Map
            ? Map<String, dynamic>.from(result["trip"] as Map)
            : null;
        _loading = false;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = "Could not load active ride: $exc";
        _messageIsError = true;
      });
=======
    _poll?.cancel();
    _pickup.dispose();
    _dropoff.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchActiveTrip(riderId: _id(widget.user));
      if (!mounted) {
        return;
      }
      final trip = res["trip"];
      setState(() {
        _trip = trip is Map ? Map<String, dynamic>.from(trip) : null;
        _driverPoint = _point(_trip?["driver_latitude"], _trip?["driver_longitude"]);
      });
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
      });
    } catch (exc) {
      setState(() => _message = "$exc");
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
    }
  }

  Future<void> _requestRide() async {
<<<<<<< HEAD
    final riderId = _extractAccountId();
    if (riderId == null) return;

    setState(() {
      _submitting = true;
      _message = "";
      _messageIsError = false;
    });

    try {
      final result = await _api.requestRide(
        riderId: riderId,
        startLoc: _pickupController.text.trim(),
        endLoc: _dropoffController.text.trim(),
        rideType: _rideType,
        timePref: _timePref,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result["success"] == true) {
        setState(() {
          _message = result["message"]?.toString() ?? "Ride request created.";
          _messageIsError = false;
        });
        await _loadActiveTrip(showLoader: false);
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Could not request ride.";
          _messageIsError = true;
        });
      }
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _message = "Ride request failed: $exc";
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
=======
    setState(() {
      _busy = true;
      _message = "";
    });
    try {
      final maps = await _api.fetchMapsConfig();
      final key = (maps["geoapify_api_key"] ?? "").toString().trim();
      if (key.isNotEmpty) {
        final end = await _api.geocodeAddress(apiKey: key, address: _dropoff.text.trim(), proximityLatitude: _pickupPoint?.latitude, proximityLongitude: _pickupPoint?.longitude);
        final results = (end["results"] as List?) ?? [];
        if (results.isNotEmpty && results.first is Map) {
          final first = Map<String, dynamic>.from(results.first as Map);
          _dropoffPoint = _point(first["lat"], first["lon"]);
        }
      }
      final res = await _api.requestRide(riderId: _id(widget.user), startLoc: _pickup.text.trim(), endLoc: _dropoff.text.trim(), rideType: _rideType, notes: _notes.text.trim());
      setState(() {
        _message = res["success"] == true ? "Ride request sent." : (res["error"]?.toString() ?? "Request failed.");
      });
      await _load();
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() => _busy = false);
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      }
    }
  }

  Future<void> _cancelRide() async {
<<<<<<< HEAD
    final tripId = int.tryParse((_activeTrip?["trip_id"] ?? "").toString());
    if (tripId == null) return;

    setState(() {
      _submitting = true;
    });

    try {
      final result = await _api.cancelRide(tripId: tripId);
      if (!mounted) return;

      setState(() {
        _message = result["message"]?.toString() ?? "Ride canceled.";
        _messageIsError = result["success"] != true;
      });
      await _loadActiveTrip(showLoader: false);
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _message = "Cancel failed: $exc";
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
=======
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
        }
      });
    } catch (exc) {
      setState(() => _message = "$exc");
    } finally {
      if (mounted) {
        setState(() => _busy = false);
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      }
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final trip = _activeTrip;
    final status = (trip?["status"] ?? "").toString();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFECFBF8), Color(0xFFF8FFFD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: "Start Ride",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_message.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _messageIsError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                      border: Border.all(
                        color: _messageIsError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_message),
                  ),
                TextField(
                  controller: _pickupController,
                  decoration: const InputDecoration(labelText: "Pickup location"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dropoffController,
                  decoration: const InputDecoration(labelText: "Dropoff location"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _rideType,
                  items: const [
                    DropdownMenuItem(value: "standard", child: Text("Standard")),
                    DropdownMenuItem(value: "shared", child: Text("Shared")),
                    DropdownMenuItem(value: "priority", child: Text("Priority")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _rideType = value ?? "standard";
                    });
                  },
                  decoration: const InputDecoration(labelText: "Ride type"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _timePref,
                  items: const [
                    DropdownMenuItem(value: "asap", child: Text("ASAP")),
                    DropdownMenuItem(value: "scheduled", child: Text("Scheduled")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _timePref = value ?? "asap";
                    });
                  },
                  decoration: const InputDecoration(labelText: "Time preference"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Notes"),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _requestRide,
                    icon: const Icon(Icons.local_taxi_outlined),
                    label: Text(_submitting ? "Submitting..." : "Request Ride"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: "Active Ride",
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                : trip == null
                    ? const Text("No active ride right now.")
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow(label: "Status", value: status.replaceAll("_", " ")),
                          _DetailRow(label: "Driver", value: (trip["driver_name"] ?? "Pending assignment").toString()),
                          _DetailRow(label: "Pickup", value: (trip["start_loc"] ?? "").toString()),
                          _DetailRow(label: "Dropoff", value: (trip["end_loc"] ?? "").toString()),
                          const SizedBox(height: 12),
                          if (status == "requested" || status == "accepted")
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _submitting ? null : _cancelRide,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text("Cancel Ride"),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
=======
    final markers = [
      if (_pickupPoint != null) Marker(point: _pickupPoint!, width: 40, height: 40, child: const Icon(Icons.my_location, color: Color(0xFF0F766E), size: 30)),
      if (_dropoffPoint != null) Marker(point: _dropoffPoint!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Color(0xFF115E59), size: 32)),
      if (_driverPoint != null) Marker(point: _driverPoint!, width: 40, height: 40, child: const Icon(Icons.directions_car, color: Color(0xFF1D4ED8), size: 30)),
    ];
    return _PageShell(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _Hero(title: "Start ride", subtitle: "Use your current location for pickup, request a driver, and keep an eye on live ride status."),
        const SizedBox(height: 12),
        if (_message.isNotEmpty) _Notice(_message, _message != "Ride request sent." && _message != "Ride canceled."),
        const SizedBox(height: 12),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Ride Map", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: const MapOptions(initialCenter: LatLng(41.6611, -91.5302), initialZoom: 12),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.example.ridermobile"),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_trip == null) ...[
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _useLocation, icon: const Icon(Icons.gps_fixed), label: const Text("Use My Current Location"))),
            const SizedBox(height: 12),
            TextField(controller: _pickup, decoration: _inputDecoration(label: "Pickup Location")),
            const SizedBox(height: 12),
            TextField(controller: _dropoff, decoration: _inputDecoration(label: "Dropoff Location")),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _rideType, decoration: _inputDecoration(label: "Ride Type"), items: const [DropdownMenuItem(value: "standard", child: Text("Standard")), DropdownMenuItem(value: "shared", child: Text("Shared")), DropdownMenuItem(value: "priority", child: Text("Priority"))], onChanged: (value) => setState(() => _rideType = value ?? "standard")),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 3, decoration: _inputDecoration(label: "Ride Notes")),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _requestRide, icon: const Icon(Icons.send_outlined), label: Text(_busy ? "Requesting..." : "Request Ride"))),
          ] else ...[
            _Row("Status", _title(_trip?["status"])),
            _Row("Driver", (_trip?["driver_name"] ?? "Pending assignment").toString()),
            _Row("Pickup", (_trip?["start_loc"] ?? "N/A").toString()),
            _Row("Dropoff", (_trip?["end_loc"] ?? "N/A").toString()),
            _Row("Driver Location Updated", (_trip?["driver_location_updated_at"] ?? "Waiting for driver location").toString()),
            if (["requested", "accepted"].contains((_trip?["status"] ?? "").toString())) SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _cancelRide, icon: const Icon(Icons.close), label: Text(_busy ? "Canceling..." : "Cancel Ride"))),
          ],
        ])),
      ]),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
    );
  }
}

<<<<<<< HEAD
class RiderReviewsTab extends StatefulWidget {
  const RiderReviewsTab({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<RiderReviewsTab> createState() => _RiderReviewsTabState();
}

class _RiderReviewsTabState extends State<RiderReviewsTab> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _message = "";
  List<dynamic> _received = <dynamic>[];
  List<dynamic> _given = <dynamic>[];

  int? _extractAccountId() {
    final raw = widget.user["account_id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? "").toString().trim());
  }
=======
class ReviewsTab extends StatefulWidget {
  const ReviewsTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  final _api = ApiClient();
  bool _loading = true;
  String _error = "";
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _given = [];
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final riderId = _extractAccountId();
    if (riderId == null) {
      setState(() {
        _loading = false;
        _message = "Missing rider account id.";
      });
      return;
    }

    try {
      final result = await _api.fetchReviews(riderId: riderId);
      if (!mounted) return;

      final reviewData = Map<String, dynamic>.from(
        (result["review_data"] as Map?) ?? <String, dynamic>{},
      );

      setState(() {
        _received = (reviewData["received"] as List?) ?? <dynamic>[];
        _given = (reviewData["given"] as List?) ?? <dynamic>[];
        _message = result["error"]?.toString() ?? "";
        _loading = false;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = "Could not load reviews: $exc";
=======
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchReviews(riderId: _id(widget.user));
      final data = Map<String, dynamic>.from((res["review_data"] as Map?) ?? {});
      setState(() {
        _received = ((data["received"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _given = ((data["given"] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _error = res["success"] == true ? "" : (res["error"]?.toString() ?? "Could not load reviews.");
      });
    } catch (exc) {
      setState(() {
        _loading = false;
        _error = "$exc";
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      });
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFECFBF8), Color(0xFFF8FFFD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_message.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_message),
            ),
          _SectionCard(
            title: "Reviews You Received",
            child: _received.isEmpty
                ? const Text("No received ratings yet.")
                : Column(
                    children: _received.map((row) {
                      final item = Map<String, dynamic>.from(row as Map);
                      return _TripRow(
                        id: "${item["review_id"] ?? ""}",
                        status: "${item["rating"] ?? ""}/5 from ${item["counterpart_name"] ?? ""}",
                        route: (item["trip_status"] ?? "").toString(),
                        rider: "Trip/Review #${item["review_id"] ?? ""}",
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Reviews You Gave",
            child: _given.isEmpty
                ? const Text("No ratings given yet.")
                : Column(
                    children: _given.map((row) {
                      final item = Map<String, dynamic>.from(row as Map);
                      return _TripRow(
                        id: "${item["review_id"] ?? ""}",
                        status: "${item["rating"] ?? ""}/5 to ${item["counterpart_name"] ?? ""}",
                        route: (item["comment"] ?? item["trip_status"] ?? "No comment").toString(),
                        rider: (item["review_date"] ?? "#${item["review_id"] ?? ""}").toString(),
                      );
                    }).toList(),
                  ),
          ),
        ],
=======
    return _PageShell(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_error.isNotEmpty) _Notice(_error, true),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else ...[
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Reviews You Received", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 10), if (_received.isEmpty) const Text("No received ratings yet.") else ..._received.map((row) => _Row("${row["rating"] ?? "?"}/5 from ${row["counterpart_name"] ?? "Driver"}", (row["trip_status"] ?? row["comment"] ?? "").toString()))])),
            const SizedBox(height: 12),
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Reviews You Gave", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 10), if (_given.isEmpty) const Text("No ratings given yet.") else ..._given.map((row) => _Row("${row["rating"] ?? "?"}/5 to ${row["counterpart_name"] ?? "Driver"}", (row["comment"] ?? row["trip_status"] ?? "").toString()))])),
          ],
        ]),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      ),
    );
  }
}

<<<<<<< HEAD
class RiderSettingsTab extends StatefulWidget {
  const RiderSettingsTab({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  final Map<String, dynamic> user;
  final Future<void> Function(Map<String, dynamic> updatedUser) onUserUpdated;
  final Future<void> Function() onLogout;

  @override
  State<RiderSettingsTab> createState() => _RiderSettingsTabState();
}

class _RiderSettingsTabState extends State<RiderSettingsTab> {
  final ApiClient _api = ApiClient();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  final List<String> _preferenceOptions = const [
=======
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
  late final Set<String> _prefs = ((widget.user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty)).toSet();
  String _message = "";
  bool _busy = false;

  static const _options = [
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
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

<<<<<<< HEAD
  final Set<String> _selectedPreferences = <String>{};

  bool _saving = false;
  String _message = "";
  bool _messageIsError = false;

  int? _extractAccountId() {
    final raw = widget.user["account_id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? "").toString().trim());
  }

  @override
  void initState() {
    super.initState();

    _firstNameController = TextEditingController(text: (widget.user["first_name"] ?? "").toString());
    _lastNameController = TextEditingController(text: (widget.user["last_name"] ?? "").toString());
    _emailController = TextEditingController(text: (widget.user["email"] ?? "").toString());
    _phoneController = TextEditingController(text: (widget.user["phone"] ?? "").toString());

    final prefs = (widget.user["preferences"] ?? "").toString();
    if (prefs.trim().isNotEmpty) {
      _selectedPreferences.addAll(
        prefs.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final riderId = _extractAccountId();
    if (riderId == null) return;

    setState(() {
      _saving = true;
      _message = "";
      _messageIsError = false;
    });

    try {
      final result = await _api.saveSettings(
        riderId: riderId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        preferences: _selectedPreferences.toList(),
      );

      if (!mounted) return;

      if (result["success"] == true) {
        final updatedUser = Map<String, dynamic>.from(widget.user)
          ..["first_name"] = _firstNameController.text.trim()
          ..["last_name"] = _lastNameController.text.trim()
          ..["email"] = _emailController.text.trim()
          ..["phone"] = _phoneController.text.trim()
          ..["preferences"] = _selectedPreferences.join(", ");

        await widget.onUserUpdated(updatedUser);

        setState(() {
          _message = result["message"]?.toString() ?? "Settings saved.";
          _messageIsError = false;
        });
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Could not save settings.";
          _messageIsError = true;
        });
      }
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _message = "Save failed: $exc";
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
=======
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
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
      }
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFECFBF8), Color(0xFFF8FFFD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: "Settings",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_message.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _messageIsError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                      border: Border.all(
                        color: _messageIsError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_message),
                  ),
                TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: "First Name")),
                const SizedBox(height: 12),
                TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: "Last Name")),
                const SizedBox(height: 12),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 12),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone")),
                const SizedBox(height: 16),
                const Text("Preferences", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _preferenceOptions.map((option) {
                    final selected = _selectedPreferences.contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (selected) {
                            _selectedPreferences.remove(option);
                          } else {
                            _selectedPreferences.add(option);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? "Saving..." : "Save Settings"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onLogout,
                    child: const Text("Log Out"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
=======
    final displayName = "${widget.user["first_name"] ?? ""} ${widget.user["last_name"] ?? ""}".trim();
    return _PageShell(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _Card(child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF115E59)])), child: const Icon(Icons.person, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName.isEmpty ? "Rider" : displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), Text("@${widget.user["username"] ?? "rider"}")]))])),
        const SizedBox(height: 12),
        if (_message.isNotEmpty) _Notice(_message, _message != "Rider settings updated."),
        const SizedBox(height: 12),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Account Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _first, decoration: _inputDecoration(label: "First Name")),
          const SizedBox(height: 12),
          TextField(controller: _last, decoration: _inputDecoration(label: "Last Name")),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: _inputDecoration(label: "Email")),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: _inputDecoration(label: "Phone")),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _options.map((item) => FilterChip(label: Text(item), selected: _prefs.contains(item), onSelected: (selected) => setState(() => selected ? _prefs.add(item) : _prefs.remove(item)))).toList()),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_busy ? "Saving..." : "Save Settings"))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async => widget.onLogout(), icon: const Icon(Icons.logout), label: const Text("Log out"))),
        ])),
      ]),
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
    );
  }
}

<<<<<<< HEAD
class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FFFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9F2ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF55717D))),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2430),
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
=======
class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
  final Widget child;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFECE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2430),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.id,
    required this.status,
    required this.route,
    required this.rider,
  });

  final String id;
  final String status;
  final String route;
  final String rider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFFFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDFF3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "#$id · $status",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2430),
            ),
          ),
          const SizedBox(height: 3),
          Text(route, style: const TextStyle(color: Color(0xFF334155))),
          const SizedBox(height: 2),
          Text(rider, style: const TextStyle(color: Color(0xFF55717D))),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

=======
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFEEF8F7), Color(0xFFF8FCFC)], begin: Alignment.topCenter, end: Alignment.bottomCenter)), child: child);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("RIDEMATCH RIDER", style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF2E6A64))), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Color(0xFF57716E)))]));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD7ECE8)), boxShadow: const [BoxShadow(color: Color(0x11255B58), blurRadius: 16, offset: Offset(0, 8))]), child: child);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, this.error);
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: error ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4), border: Border.all(color: error ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0))), child: Text(message, style: TextStyle(color: error ? const Color(0xFF9F1239) : const Color(0xFF166534))));
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFECE6)),
        color: const Color(0xFFF6FFFD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF55717D))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F2430))),
        ],
      ),
    );
  }
}
=======
    return Container(width: 152, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD7ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF57716E))), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))]));
  }
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFFAFDFC), border: Border.all(color: const Color(0xFFD7ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF57716E))), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600))]));
  }
}

InputDecoration _inputDecoration({String? label}) => InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0E7E3))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.4)));

int _id(Map<String, dynamic> user) => _int(user["account_id"]) ?? 0;
int? _int(dynamic value) => value is int ? value : int.tryParse((value ?? "").toString().split(".").first.trim());
LatLng? _point(dynamic lat, dynamic lng) => double.tryParse((lat ?? "").toString()) != null && double.tryParse((lng ?? "").toString()) != null ? LatLng(double.parse(lat.toString()), double.parse(lng.toString())) : null;
String _metric(dynamic value) => value == null ? "N/A" : value.toString();
String _title(dynamic value) => (value ?? "unknown").toString().replaceAll("_", " ");
>>>>>>> d02ff88393509a9726ca22f89b2e82446b991c6f
