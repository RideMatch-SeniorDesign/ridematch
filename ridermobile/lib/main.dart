import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

import "api_client.dart";

void main() => runApp(const RiderMobileApp());

class RiderMobileApp extends StatelessWidget {
  const RiderMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RideMatch Rider",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
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
        return user == null ? const LoginPage() : RiderShellPage(user: user);
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFEAF8F6), Color(0xFFF7FCFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool obscure = false, TextInputType? type}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF365956))),
      const SizedBox(height: 6),
      TextField(controller: controller, obscureText: obscure, keyboardType: type, decoration: _inputDecoration()),
    ]);
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
        ],
      ),
    );
  }
}

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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
  Map<String, dynamic>? _trip;
  String _message = "";
  bool _busy = false;
  String _rideType = "standard";
  LatLng? _pickupPoint;
  LatLng? _dropoffPoint;
  LatLng? _driverPoint;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 7), (_) => _load());
  }

  @override
  void dispose() {
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
    }
  }

  Future<void> _requestRide() async {
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
    );
  }
}

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

  @override
  void initState() {
    super.initState();
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
  late final Set<String> _prefs = ((widget.user["preferences"] ?? "").toString().split(",").map((e) => e.trim()).where((e) => e.isNotEmpty)).toSet();
  String _message = "";
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
