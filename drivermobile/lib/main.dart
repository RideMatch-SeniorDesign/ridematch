import "dart:convert";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "api_client.dart";


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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD)),
        useMaterial3: true,
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
  late final Future<Map<String, dynamic>?> _restoredUserFuture;

  @override
  void initState() {
    super.initState();
    _restoredUserFuture = _SessionStore.instance.readUser();
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
          return DriverShellPage(user: user);
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
        if (_rememberMe) {
          await _SessionStore.instance.saveUser(user);
        } else {
          await _SessionStore.instance.clear();
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DriverShellPage(user: user),
          ),
        );
      } else {
        setState(() {
          _message = result["error"]?.toString() ?? "Login failed.";
        });
      }
    } catch (exc) {
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFD7E4FB);
    const inputBorder = Color(0xFFC8DAF7);
    const mutedText = Color(0xFF5B6B8C);
    const textColor = Color(0xFF0C1A3A);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF4FF), Color(0xFFF7FBFF)],
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
                        colors: [Color(0xFFF3F8FF), Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14102C5E),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RIDEMATCH DRIVER",
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38527E),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Driver Portal",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Separate login and sign-up for drivers.",
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
                          color: Color(0x14102C5E),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Driver Login",
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
                              borderSide: const BorderSide(color: Color(0xFF1367FF), width: 1.3),
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
                              borderSide: const BorderSide(color: Color(0xFF1367FF), width: 1.3),
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
                                colors: [Color(0xFF1367FF), Color(0xFF0F4EC2)],
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
      const StartDriveTab(),
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          );
        },
      ),
    ];

    final titles = ["Dashboard", "Start Drive", "Profile"];

    return Scaffold(
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
    const activeColor = Color(0xFF0D6EFD);
    const inactiveColor = Color(0xFF6B7280);

    return SizedBox(
      height: 86,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 14,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withAlpha(currentIndex == 1 ? 120 : 70),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
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

    const recentTrips = <Map<String, String>>[
      {
        "id": "2187",
        "status": "Completed",
        "route": "Iowa City -> Coralville",
        "rider": "Sofia Ramirez",
      },
      {
        "id": "2186",
        "status": "Completed",
        "route": "North Liberty -> Iowa City",
        "rider": "Liam Carter",
      },
      {
        "id": "2185",
        "status": "In Progress",
        "route": "Coralville -> Tiffin",
        "rider": "Noah Bennett",
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF7FBFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7E4FB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14102C5E),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "RIDEMATCH DRIVER",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38527E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Welcome back, $greetingName",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0C1A3A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "@$username · ${status[0].toUpperCase()}${status.substring(1)}",
                  style: const TextStyle(color: Color(0xFF5B6B8C)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Dashboard Stats",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1A3A),
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
            children: const [
              _StatCard(title: "Total Trips", value: "124"),
              _StatCard(title: "Completed", value: "120"),
              _StatCard(title: "Active", value: "1"),
              _StatCard(title: "Given Rating", value: "4.7"),
              _StatCard(title: "Received Rating", value: "4.8"),
              _StatCard(title: "Preferences", value: "Quiet ride"),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: "Recent Trips",
            child: Column(
              children: recentTrips
                  .map(
                    (trip) => _TripRow(
                      id: trip["id"]!,
                      status: trip["status"]!,
                      route: trip["route"]!,
                      rider: trip["rider"]!,
                    ),
                  )
                  .toList(),
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5B6B8C),
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
              color: Color(0xFF0C1A3A),
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
        border: Border.all(color: const Color(0xFFD7E4FB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1A3A),
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
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7F0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "#$id · $status",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1A3A),
            ),
          ),
          const SizedBox(height: 3),
          Text(route, style: const TextStyle(color: Color(0xFF334155))),
          const SizedBox(height: 2),
          Text("Rider: $rider", style: const TextStyle(color: Color(0xFF5B6B8C))),
        ],
      ),
    );
  }
}

class StartDriveTab extends StatelessWidget {
  const StartDriveTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE0ECFF), Color(0xFFF0F7FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Start a New Drive", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text("This center tab is highlighted so it stays quick to access while driving."),
                const SizedBox(height: 16),
                const TextField(decoration: InputDecoration(labelText: "Start location", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                const TextField(decoration: InputDecoration(labelText: "End location", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.directions_car_filled_outlined),
                    label: const Text("Start Drive"),
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
    final photoUrl = accountId == null ? null : "http://10.0.2.2:8002/api/driver/photo/$accountId?v=$_photoVersion";

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF7FBFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7E4FB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14102C5E),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1367FF), Color(0xFF0F4EC2)],
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
                              color: const Color(0xFFEAF1FF),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                          color: Color(0xFF0C1A3A),
                        ),
                      ),
                      Text(
                        "@${username.isEmpty ? 'driver' : username}",
                        style: const TextStyle(color: Color(0xFF5B6B8C)),
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
                ? const Text(
                    "No preferences selected yet.",
                    style: TextStyle(color: Color(0xFF5B6B8C)),
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
                              color: const Color(0xFFEAF1FF),
                              border: Border.all(color: const Color(0xFFB8CDF6)),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Color(0xFF16376F),
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
                const Text(
                  "Upload a new photo for review. Replacing it deletes your current photo.",
                  style: TextStyle(color: Color(0xFF5B6B8C)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _uploadingPhoto ? null : _changeProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_uploadingPhoto ? "Uploading..." : "Change Profile Photo"),
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
                  color: _photoNoticeIsError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                ),
                color: _photoNoticeIsError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
              ),
              child: Text(
                _photoNotice,
                style: TextStyle(
                  color: _photoNoticeIsError ? const Color(0xFF9F1239) : const Color(0xFF166534),
                ),
              ),
            ),
          if (_photoNotice.isNotEmpty) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
              color: const Color(0xFFFFF1F2),
            ),
            child: const Text(
              "Uploading a new profile photo will put your driver account under review again.",
              style: TextStyle(color: Color(0xFF9F1239)),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await widget.onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text("Log out"),
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
        border: Border.all(color: const Color(0xFFE7F0FF)),
        color: const Color(0xFFFBFDFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5B6B8C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0C1A3A),
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
        border: Border.all(color: const Color(0xFFB8E2DE)),
        color: const Color(0xFFEFFBF8),
      ),
      child: Text(
        "${label[0].toUpperCase()}${label.substring(1)}",
        style: const TextStyle(
          color: Color(0xFF1F6E69),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}



