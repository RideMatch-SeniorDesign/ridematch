import "dart:async";

import "package:flutter/material.dart";

import "api_client.dart";

void main() {
  runApp(const RiderMobileApp());
}

class RiderMobileApp extends StatelessWidget {
  const RiderMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RideMatch Rider",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A4)),
        useMaterial3: true,
      ),
      home: const AppBootstrapGate(),
    );
  }
}

class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  final ApiClient _api = ApiClient();
  late final Future<Map<String, dynamic>?> _restoredUserFuture;

  @override
  void initState() {
    super.initState();
    _restoredUserFuture = _api.readSessionUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
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
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
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
  }
}

class RiderShellPage extends StatefulWidget {
  const RiderShellPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<RiderShellPage> createState() => _RiderShellPageState();
}

class _RiderShellPageState extends State<RiderShellPage> {
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
        ],
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && !_submitting) {
        _loadActiveTrip(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
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
    }
  }

  Future<void> _requestRide() async {
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
      }
    }
  }

  Future<void> _cancelRide() async {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

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

  @override
  void initState() {
    super.initState();
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
    );
  }
}

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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
  final Widget child;

  @override
  Widget build(BuildContext context) {
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