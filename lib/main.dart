// ignore_for_file: unused_element

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfigLoader.load();
  runApp(GimAccessApp(config: config));
}

class GimAccessApp extends StatefulWidget {
  const GimAccessApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<GimAccessApp> createState() => _GimAccessAppState();
}

class _GimAccessAppState extends State<GimAccessApp> {
  late final ApiAuthRepository _authRepository = ApiAuthRepository(
    config: widget.config,
  );
  final LoginAuditStore _auditStore = LoginAuditStore();
  AuthSession? _session;

  Future<void> _login(String email, String password) async {
    final session = await _authRepository.authenticate(email, password);
    _auditStore.record(session.user);
    setState(() {
      _session = session;
    });
  }

  void _logout() {
    setState(() {
      _session = null;
    });
  }

  void _enterGeneralDemo() {
    final demoUser = AppUser(
      id: 'demo-gim-user',
      email: 'member@easygymlife.app',
      displayName: 'General Demo User',
      role: UserRole.gim,
      lastLogin: DateTime.now(),
    );

    _auditStore.record(demoUser);
    setState(() {
      _session = AuthSession(
        token: 'demo-general-dashboard-token',
        user: demoUser,
      );
    });
  }

  void _enterBusinessDemo() {
    final demoUser = AppUser(
      id: 'demo-business-user',
      email: 'owner@iron-temple.com',
      displayName: 'Business Demo User',
      role: UserRole.business,
      lastLogin: DateTime.now(),
    );

    _auditStore.record(demoUser);
    setState(() {
      _session = AuthSession(
        token: 'demo-business-dashboard-token',
        user: demoUser,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: widget.config.appName,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF041611),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65D190),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: _session == null
          ? LoginPage(
              config: widget.config,
              onLogin: _login,
              onEnterBusinessDemo: _enterBusinessDemo,
              onEnterGeneralDemo: _enterGeneralDemo,
            )
          : DashboardRouter(
              config: widget.config,
              currentUser: _session!.user,
              auditStore: _auditStore,
              backendToken: _session!.token,
              onLogout: _logout,
            ),
    );
  }
}

enum UserRole { business, gim }

class _EglPastels {
  static const ink = Color(0xFF10231D);
  static const mutedInk = Color(0xFF47675D);
  static const green = Color(0xFFCFEBD8);
  static const greenStrong = Color(0xFF4FBA72);
  static const blue = Color(0xFFD8EAFB);
  static const blueStrong = Color(0xFF4E92C7);
  static const white = Color(0xFFFBFDFB);
  static const shell = Color(0xFFE6ECE8);
  static const border = Color(0xFFD9E6DE);
}

UserRole userRoleFromApi(String value) {
  switch (value.toLowerCase()) {
    case 'business':
      return UserRole.business;
    case 'gim':
      return UserRole.gim;
    default:
      throw AuthException('Unsupported user role received from the server.');
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.lastLogin,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime lastLogin;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class ApiAuthRepository {
  ApiAuthRepository({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  final AppConfig config;
  final http.Client _client;

  Future<AuthSession> authenticate(String email, String password) async {
    final uri = Uri.parse('${config.baseUrl}/api/auth/login');

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
    } catch (_) {
      throw AuthException(
        'Could not reach the backend at ${config.baseUrl}. Make sure the Express server is running.',
      );
    }

    final body = _decodeJson(response.body);

    if (response.statusCode != 200) {
      throw AuthException(
        body['message'] as String? ??
            'Login failed. Check the backend server and credentials.',
      );
    }

    final token = body['token'] as String?;
    final userJson = body['user'] as Map<String, dynamic>?;

    if (token == null || userJson == null) {
      throw const AuthException('The backend login response was incomplete.');
    }

    return AuthSession(
      token: token,
      user: AppUser(
        id: '${userJson['id']}',
        email: userJson['email'] as String? ?? email.trim().toLowerCase(),
        displayName: userJson['displayName'] as String? ?? 'Unknown User',
        role: userRoleFromApi(userJson['role'] as String? ?? 'gim'),
        lastLogin: DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> _decodeJson(String source) {
    if (source.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class LoginAuditStore {
  final List<AppUser> _logins = <AppUser>[];

  void record(AppUser user) {
    _logins.insert(0, user);
  }

  List<AppUser> get recentLogins => List<AppUser>.unmodifiable(_logins);
}

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.apiScheme,
    required this.apiHost,
    required this.apiPort,
    required this.dbName,
    required this.dbUser,
    required this.jwtIssuer,
    required this.businessPortalLabel,
    required this.gimPortalLabel,
  });

  final String appName;
  final String apiScheme;
  final String apiHost;
  final String apiPort;
  final String dbName;
  final String dbUser;
  final String jwtIssuer;
  final String businessPortalLabel;
  final String gimPortalLabel;

  String get baseUrl => '$apiScheme://$apiHost:$apiPort';
}

class AppConfigLoader {
  static Future<AppConfig> load() async {
    final envText = await _loadEnvFile();
    final values = _parse(envText);
    return AppConfig(
      appName: values['APP_NAME'] ?? 'Easy Gym Life (EGL)',
      apiScheme: values['API_SCHEME'] ?? 'http',
      apiHost: values['API_HOST'] ?? 'localhost',
      apiPort: values['API_PORT'] ?? '3000',
      dbName: values['DB_NAME'] ?? 'easy_gym_life',
      dbUser: values['DB_USER'] ?? 'app_user',
      jwtIssuer: values['JWT_ISSUER'] ?? 'egl-auth-service',
      businessPortalLabel:
          values['BUSINESS_PORTAL_LABEL'] ?? 'Business Dashboard',
      gimPortalLabel:
          values['GIM_PORTAL_LABEL'] ?? 'Easy Gym Life (EGL) Member Dashboard',
    );
  }

  static Future<String> _loadEnvFile() async {
    try {
      return await rootBundle.loadString('assets/config/app.env');
    } on FlutterError {
      return rootBundle.loadString('assets/config/app.env.example');
    }
  }

  static Map<String, String> _parse(String raw) {
    final result = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          !trimmed.contains('=')) {
        continue;
      }

      final separator = trimmed.indexOf('=');
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      result[key] = value;
    }
    return result;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.config,
    required this.onLogin,
    required this.onEnterBusinessDemo,
    required this.onEnterGeneralDemo,
  });

  final AppConfig config;
  final Future<void> Function(String email, String password) onLogin;
  final VoidCallback onEnterBusinessDemo;
  final VoidCallback onEnterGeneralDemo;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await widget.onLogin(_emailController.text, _passwordController.text);
    } on AuthException catch (error) {
      setState(() {
        _errorText = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _EglPastels.white,
        title: const Text('Account onboarding'),
        content: const Text(
          'Account creation will connect here when member and business onboarding are ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_EglPastels.white, _EglPastels.blue, Color(0xFFEAF5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _EglPastels.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _EglPastels.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 30,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _EglLogoMark(),
                        const SizedBox(height: 28),
                        const _FieldLabel(text: 'Email'),
                        const SizedBox(height: 8),
                        _StyledInput(
                          controller: _emailController,
                          hintText: 'member@easygymlife.app',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter an email address.';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel(text: 'Password'),
                        const SizedBox(height: 8),
                        _StyledInput(
                          controller: _passwordController,
                          hintText: 'Enter your password',
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }
                            return null;
                          },
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Color(0xFFC8504B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _EglPastels.greenStrong,
                            foregroundColor: _EglPastels.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Log In'),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: _showCreateAccountDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _EglPastels.ink,
                            side: const BorderSide(color: _EglPastels.border),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Create Account'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : widget.onEnterBusinessDemo,
                          icon: const Icon(Icons.storefront_rounded),
                          label: const Text('Enter Business Demo Dashboard'),
                          style: TextButton.styleFrom(
                            foregroundColor: _EglPastels.ink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : widget.onEnterGeneralDemo,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Enter Member Demo Dashboard'),
                          style: TextButton.styleFrom(
                            foregroundColor: _EglPastels.blueStrong,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Preview the business or member experience with demo access.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _EglPastels.mutedInk),
                        ),
                        const SizedBox(height: 24),
                        _ConfigPanel(config: widget.config),
                        const SizedBox(height: 20),
                        const _DemoAccountPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardRouter extends StatelessWidget {
  const DashboardRouter({
    super.key,
    required this.config,
    required this.currentUser,
    required this.auditStore,
    required this.backendToken,
    required this.onLogout,
  });

  final AppConfig config;
  final AppUser currentUser;
  final LoginAuditStore auditStore;
  final String backendToken;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (currentUser.role == UserRole.business) {
      return BusinessDashboard(
        config: config,
        currentUser: currentUser,
        auditStore: auditStore,
        backendToken: backendToken,
        onLogout: onLogout,
      );
    }

    return GimUserDashboard(
      config: config,
      currentUser: currentUser,
      auditStore: auditStore,
      backendToken: backendToken,
      onLogout: onLogout,
    );
  }
}

class _EglLogoMark extends StatelessWidget {
  const _EglLogoMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 360,
        child: AspectRatio(
          aspectRatio: 562 / 390,
          child: Image.asset(
            'Project Pictures/EGL Company Logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

enum _BusinessDashboardTab {
  home,
  video,
  dataFilter,
  equipmentHealth,
  insights,
  gymMap,
}

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard({
    super.key,
    required this.config,
    required this.currentUser,
    required this.auditStore,
    required this.backendToken,
    required this.onLogout,
  });

  final AppConfig config;
  final AppUser currentUser;
  final LoginAuditStore auditStore;
  final String backendToken;
  final VoidCallback onLogout;

  @override
  State<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  _BusinessDashboardTab _selectedTab = _BusinessDashboardTab.home;
  String _selectedSource = 'All Locations';

  String get _tabSubtitle {
    switch (_selectedTab) {
      case _BusinessDashboardTab.home:
        return 'Chain-level operational view for the current demo environment.';
      case _BusinessDashboardTab.video:
        return 'Preview the camera and processed-vision workspace.';
      case _BusinessDashboardTab.dataFilter:
        return 'Filter representative event data by source, zone, and event type.';
      case _BusinessDashboardTab.equipmentHealth:
        return 'Review machine readiness, maintenance risk, and service status.';
      case _BusinessDashboardTab.insights:
        return 'Surface movement analytics, heat zones, and congestion signals.';
      case _BusinessDashboardTab.gymMap:
        return 'Inspect hot zones, dead zones, and equipment state overlays.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_EglPastels.white, _EglPastels.blue, _EglPastels.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 940;
              final sidebarWidth = isCompact ? 78.0 : 220.0;
              final contentMaxWidth = constraints.maxWidth - sidebarWidth - 54;
              final headerCardWidth = isCompact
                  ? contentMaxWidth.clamp(220.0, 360.0)
                  : 420.0;
              final tbdCardWidth = isCompact
                  ? contentMaxWidth.clamp(220.0, 360.0)
                  : 320.0;
              final actionCardWidth = isCompact
                  ? contentMaxWidth.clamp(220.0, 360.0)
                  : 220.0;

              return Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: sidebarWidth,
                      child: _BusinessSidebar(
                        selectedTab: _selectedTab,
                        isCompact: isCompact,
                        onSelectTab: (tab) {
                          setState(() {
                            _selectedTab = tab;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _BusinessHeaderCard(
                                companyName: widget.config.businessPortalLabel,
                                currentUser: widget.currentUser,
                                width: headerCardWidth,
                              ),
                              _BusinessTbdCard(width: tbdCardWidth),
                              _BusinessActionCard(
                                onLogout: widget.onLogout,
                                width: actionCardWidth,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _SourceChip(
                                label: 'All Locations',
                                selected: _selectedSource == 'All Locations',
                                onTap: () {
                                  setState(() {
                                    _selectedSource = 'All Locations';
                                  });
                                },
                              ),
                              _SourceChip(
                                label: 'Downtown',
                                selected: _selectedSource == 'Downtown',
                                onTap: () {
                                  setState(() {
                                    _selectedSource = 'Downtown';
                                  });
                                },
                              ),
                              _SourceChip(
                                label: 'Iron Temple',
                                selected: _selectedSource == 'Iron Temple',
                                onTap: () {
                                  setState(() {
                                    _selectedSource = 'Iron Temple';
                                  });
                                },
                              ),
                              Text(
                                _tabSubtitle,
                                style: const TextStyle(
                                  color: _EglPastels.mutedInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _BusinessContentPanel(
                              selectedTab: _selectedTab,
                              selectedSource: _selectedSource,
                              config: widget.config,
                              auditStore: widget.auditStore,
                              backendToken: widget.backendToken,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BusinessVideoView extends StatelessWidget {
  const _BusinessVideoView();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Primary Camera View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Placeholder panel for live stream or processed camera feed.',
                  style: TextStyle(color: Color(0xFF9DB8AE)),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E2B23), Color(0xFF18362F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: const Color(0xFF315347)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            size: 56,
                            color: Color(0xFF7BE6A5),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Live video / vision feed zone',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'This is where the business-facing camera page would render.',
                            style: TextStyle(color: Color(0xFF9DB8AE)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            children: const [
              Expanded(
                child: _MetricCard(
                  title: 'Current Camera',
                  value: 'CAM-004',
                  detail: 'Cardio floor north angle',
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: _MetricCard(
                  title: 'Occupancy Snapshot',
                  value: '34',
                  detail: 'Humans detected in active zones',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessDataView extends StatelessWidget {
  const _BusinessDataView();

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['CAM-004', 'Cardio Floor', 'occupancy_snapshot', '34', '0.94'],
      ['CAM-002', 'Free Weights', 'human_activity_detected', '12', '0.91'],
      ['CAM-001', 'Studio A', 'zone_traffic_update', '19', '0.88'],
      ['CAM-005', 'Entrance', 'human_presence_detected', '8', '0.96'],
    ];

    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _StatusBadge(
                label: 'Location: Downtown',
                color: Color(0xFF8FD8FF),
              ),
              _StatusBadge(label: 'Window: Today', color: Color(0xFFF4C96B)),
              _StatusBadge(
                label: 'Source: Vision events',
                color: Color(0xFF7BE6A5),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Filterable Business Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Representative event data that business users can filter by location, zone, event type, or confidence.',
            style: TextStyle(color: Color(0xFF9DB8AE)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF163029),
                ),
                dataRowColor: WidgetStateProperty.all(const Color(0xFF10211C)),
                columns: const [
                  DataColumn(label: Text('Camera')),
                  DataColumn(label: Text('Zone')),
                  DataColumn(label: Text('Event')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Confidence')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .map((value) => DataCell(Text(value)))
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessHealthView extends StatelessWidget {
  const _BusinessHealthView();

  @override
  Widget build(BuildContext context) {
    final equipment =
        <({String name, String status, double health, Color color})>[
          (
            name: 'PTRM1001 Treadmill',
            status: 'Healthy',
            health: 0.91,
            color: const Color(0xFF7BE6A5),
          ),
          (
            name: 'PTRM1004 Treadmill',
            status: 'Watchlist',
            health: 0.66,
            color: const Color(0xFFF4C96B),
          ),
          (
            name: 'LEGP2001 Leg Press',
            status: 'Needs Service',
            health: 0.38,
            color: const Color(0xFFE98D86),
          ),
          (
            name: 'ELLP3002 Elliptical',
            status: 'Healthy',
            health: 0.88,
            color: const Color(0xFF7BE6A5),
          ),
        ];

    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Machine Equipment Health',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is the page where business owners can review equipment health, maintenance risk, and warranty timing.',
            style: TextStyle(color: Color(0xFF9DB8AE)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: equipment.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = equipment[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162A24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF29483E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusBadge(label: item.status, color: item.color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: item.health,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: const Color(0xFF25433A),
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Health score ${(item.health * 100).round()}% • next maintenance review in ${index + 3} days',
                        style: const TextStyle(color: Color(0xFF9DB8AE)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInsightsView extends StatelessWidget {
  const _BusinessInsightsView();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: const [
        _MetricCard(
          title: 'Movement Analytics',
          value: '412',
          detail: 'Detected workout-type motion events in the last 24 hours.',
        ),
        _MetricCard(
          title: 'Heat Zones',
          value: 'Free Weights',
          detail:
              'Most concentrated usage zone based on current event density.',
        ),
        _MetricCard(
          title: 'Congregation Watch',
          value: '2 zones',
          detail: 'Two areas exceeded the current congregation threshold.',
        ),
      ],
    );
  }
}

class _BusinessMapView extends StatelessWidget {
  const _BusinessMapView();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gym Map and Zone Overlay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Business users can filter hot zones, dead zones, and machine state overlays from this map view.',
                  style: TextStyle(color: Color(0xFF9DB8AE)),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF315347)),
                      color: const Color(0xFF0D1E18),
                    ),
                    child: Stack(
                      children: const [
                        Positioned(
                          left: 34,
                          top: 34,
                          child: _MapZone(
                            label: 'Cardio',
                            color: Color(0x447BE6A5),
                            width: 220,
                            height: 120,
                          ),
                        ),
                        Positioned(
                          right: 38,
                          top: 60,
                          child: _MapZone(
                            label: 'Free Weights',
                            color: Color(0x44F4C96B),
                            width: 200,
                            height: 140,
                          ),
                        ),
                        Positioned(
                          left: 90,
                          bottom: 40,
                          child: _MapZone(
                            label: 'Studios',
                            color: Color(0x448FD8FF),
                            width: 180,
                            height: 110,
                          ),
                        ),
                        Positioned(
                          right: 90,
                          bottom: 60,
                          child: _MachineMarker(
                            label: 'PTRM1001',
                            color: Color(0xFF7BE6A5),
                          ),
                        ),
                        Positioned(
                          right: 160,
                          bottom: 100,
                          child: _MachineMarker(
                            label: 'LEGP2001',
                            color: Color(0xFFF4C96B),
                          ),
                        ),
                        Positioned(
                          left: 180,
                          top: 90,
                          child: _MachineMarker(
                            label: 'ELLP3002',
                            color: Color(0xFFE98D86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Container(
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(18),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 16),
                _LegendRow(label: 'Green machine', color: Color(0xFF7BE6A5)),
                SizedBox(height: 12),
                _LegendRow(label: 'Yellow machine', color: Color(0xFFF4C96B)),
                SizedBox(height: 12),
                _LegendRow(label: 'Red machine', color: Color(0xFFE98D86)),
                SizedBox(height: 22),
                Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 12),
                _StatusBadge(label: 'Hot zones', color: Color(0xFFF4C96B)),
                SizedBox(height: 8),
                _StatusBadge(label: 'Dead zones', color: Color(0xFF8FD8FF)),
                SizedBox(height: 8),
                _StatusBadge(
                  label: 'Equipment state',
                  color: Color(0xFF7BE6A5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MapZone extends StatelessWidget {
  const _MapZone({
    required this.label,
    required this.color,
    required this.width,
    required this.height,
  });

  final String label;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.9)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MachineMarker extends StatelessWidget {
  const _MachineMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 28),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFFD1E2D9))),
        ),
      ],
    );
  }
}

class GimUserDashboard extends StatelessWidget {
  const GimUserDashboard({
    super.key,
    required this.config,
    required this.currentUser,
    required this.auditStore,
    required this.backendToken,
    required this.onLogout,
  });

  final AppConfig config;
  final AppUser currentUser;
  final LoginAuditStore auditStore;
  final String backendToken;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_EglPastels.white, _EglPastels.green, _EglPastels.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Container(
                      padding: EdgeInsets.all(isWide ? 26 : 18),
                      decoration: BoxDecoration(
                        color: _EglPastels.shell.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white54),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 24,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MemberDashboardHeader(
                            currentUser: currentUser,
                            onLogout: onLogout,
                          ),
                          const SizedBox(height: 20),
                          _MemberWelcomeStrip(currentUser: currentUser),
                          const SizedBox(height: 18),
                          if (isWide)
                            _MemberDashboardWide(currentUser: currentUser)
                          else
                            _MemberDashboardStacked(currentUser: currentUser),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberDashboardHeader extends StatelessWidget {
  const _MemberDashboardHeader({
    required this.currentUser,
    required this.onLogout,
  });

  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _EglPastels.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: _EglPastels.greenStrong,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Easy Gym Life',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _EglPastels.ink,
            side: const BorderSide(color: _EglPastels.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberWelcomeStrip extends StatelessWidget {
  const _MemberWelcomeStrip({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.white),
      child: Text(
        'Welcome back, ${currentUser.displayName.split(' ').first}.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _EglPastels.ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MemberDashboardWide extends StatelessWidget {
  const _MemberDashboardWide({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: _MemberInfoCard(currentUser: currentUser),
              ),
              const SizedBox(width: 18),
              const Expanded(flex: 2, child: _MemberCalendarCard()),
              const SizedBox(width: 18),
              const Expanded(child: _MemberPlanCard()),
            ],
          ),
        ),
        const SizedBox(height: 18),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: _MemberTodayWorkoutCard()),
              SizedBox(width: 18),
              Expanded(child: _MemberScheduleCard()),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(flex: 3, child: _MemberWorkoutLogCard()),
            SizedBox(width: 18),
            SizedBox(width: 210, child: _MemberFocusCard()),
          ],
        ),
      ],
    );
  }
}

class _MemberDashboardStacked extends StatelessWidget {
  const _MemberDashboardStacked({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MemberInfoCard(currentUser: currentUser),
        const SizedBox(height: 14),
        const _MemberCalendarCard(),
        const SizedBox(height: 14),
        const _MemberPlanCard(),
        const SizedBox(height: 14),
        const _MemberTodayWorkoutCard(),
        const SizedBox(height: 14),
        const _MemberScheduleCard(),
        const SizedBox(height: 14),
        const _MemberWorkoutLogCard(),
        const SizedBox(height: 14),
        const _MemberFocusCard(),
      ],
    );
  }
}

class _MemberInfoCard extends StatelessWidget {
  const _MemberInfoCard({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _memberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MemberPill(label: 'USER INFO'),
          const SizedBox(height: 28),
          CircleAvatar(
            radius: 28,
            backgroundColor: _EglPastels.green,
            child: Text(
              currentUser.displayName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: _EglPastels.ink,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentUser.displayName,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.email,
            style: const TextStyle(
              color: _EglPastels.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCalendarCard extends StatelessWidget {
  const _MemberCalendarCard();

  @override
  Widget build(BuildContext context) {
    const days = [
      ('S', '23', false),
      ('M', '24', true),
      ('T', '25', true),
      ('W', '26', false),
      ('T', '27', true),
      ('F', '28', false),
      ('S', '29', false),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _memberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Calendar',
                  style: TextStyle(
                    color: _EglPastels.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MemberPill(label: '3 PLANNED'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _CalendarDayTile(
                      day: day.$1,
                      date: day.$2,
                      active: day.$3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Next workout: Today at 6:30 PM',
            style: TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.day,
    required this.date,
    required this.active,
  });

  final String day;
  final String date;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: active ? _EglPastels.green : _EglPastels.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _EglPastels.greenStrong : _EglPastels.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: const TextStyle(
              color: _EglPastels.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPlanCard extends StatelessWidget {
  const _MemberPlanCard();

  @override
  Widget build(BuildContext context) {
    return const _MemberActionCard(
      label: 'PLAN AHEAD',
      title: 'My Schedule',
      body: 'Keep future workout days separate from what you log.',
      icon: Icons.event_available_rounded,
    );
  }
}

class _MemberTodayWorkoutCard extends StatelessWidget {
  const _MemberTodayWorkoutCard();

  @override
  Widget build(BuildContext context) {
    return const _MemberActionCard(
      label: "TODAY'S PLAN",
      title: 'Upper Body',
      body: 'Bench press, rows, shoulder press, and curls are queued.',
      icon: Icons.assignment_turned_in_rounded,
    );
  }
}

class _MemberScheduleCard extends StatelessWidget {
  const _MemberScheduleCard();

  @override
  Widget build(BuildContext context) {
    return const _MemberActionCard(
      label: 'PLAN AHEAD',
      title: 'My Schedule',
      body: '6:30 PM strength block with a short mobility cooldown.',
      icon: Icons.calendar_month_rounded,
    );
  }
}

class _MemberWorkoutLogCard extends StatelessWidget {
  const _MemberWorkoutLogCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: _memberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Workout Log',
                  style: TextStyle(
                    color: _EglPastels.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MemberPill(label: 'RECENT SETS'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: CustomPaint(
              painter: _WorkoutLogPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _WorkoutLogStat(label: 'Workouts', value: '11'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _WorkoutLogStat(label: 'Exercises', value: '7'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _WorkoutLogStat(label: 'Streak', value: '12d'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberFocusCard extends StatelessWidget {
  const _MemberFocusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(18),
      decoration: _memberPanelDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemberPill(label: 'FOCUS'),
          SizedBox(height: 16),
          Icon(
            Icons.local_fire_department_rounded,
            color: _EglPastels.greenStrong,
          ),
          SizedBox(height: 14),
          Text(
            'Stay steady',
            style: TextStyle(
              color: _EglPastels.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Log the workout after you finish. Notes beat perfect data.',
            style: TextStyle(
              color: _EglPastels.mutedInk,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacer(),
          Text(
            'Recovery reminder at 8:15 PM',
            style: TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberActionCard extends StatelessWidget {
  const _MemberActionCard({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(22),
      decoration: _memberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MemberPill(label: label),
              const Spacer(),
              Icon(icon, color: _EglPastels.greenStrong),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPill extends StatelessWidget {
  const _MemberPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _EglPastels.blue,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _EglPastels.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _WorkoutLogStat extends StatelessWidget {
  const _WorkoutLogStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _EglPastels.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _EglPastels.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutLogPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _EglPastels.border
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = _EglPastels.green
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = _EglPastels.greenStrong
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = _EglPastels.greenStrong;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.68),
      Offset(size.width * 0.24, size.height * 0.44),
      Offset(size.width * 0.50, size.height * 0.55),
      Offset(size.width * 0.74, size.height * 0.28),
      Offset(size.width, size.height * 0.34),
    ];

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(linePath, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration _memberPanelDecoration({
  Color backgroundColor = _EglPastels.white,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _EglPastels.border),
  );
}

class _BusinessSidebar extends StatelessWidget {
  const _BusinessSidebar({
    required this.selectedTab,
    required this.onSelectTab,
    required this.isCompact,
  });

  final _BusinessDashboardTab selectedTab;
  final ValueChanged<_BusinessDashboardTab> onSelectTab;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    const items = <(_BusinessDashboardTab, IconData, String)>[
      (_BusinessDashboardTab.home, Icons.home_rounded, 'Home'),
      (_BusinessDashboardTab.video, Icons.videocam_rounded, 'Video Feed'),
      (_BusinessDashboardTab.dataFilter, Icons.tune_rounded, 'Data Filter'),
      (
        _BusinessDashboardTab.equipmentHealth,
        Icons.fitness_center_rounded,
        'Equipment',
      ),
      (_BusinessDashboardTab.insights, Icons.insights_rounded, 'Insights'),
      (_BusinessDashboardTab.gymMap, Icons.map_rounded, 'Gym Map'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[
            _BusinessNavButton(
              icon: item.$2,
              label: item.$3,
              selected: item.$1 == selectedTab,
              isCompact: isCompact,
              onTap: () => onSelectTab(item.$1),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _BusinessNavButton extends StatelessWidget {
  const _BusinessNavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isCompact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _EglPastels.green : _EglPastels.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: isCompact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? _EglPastels.ink : _EglPastels.mutedInk,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? _EglPastels.ink : _EglPastels.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessHeaderCard extends StatelessWidget {
  const _BusinessHeaderCard({
    required this.companyName,
    required this.currentUser,
    required this.width,
  });

  final String companyName;
  final AppUser currentUser;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser.displayName,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.email,
            style: const TextStyle(color: _EglPastels.mutedInk),
          ),
        ],
      ),
    );
  }
}

class _BusinessTbdCard extends StatelessWidget {
  const _BusinessTbdCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.green),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority Metrics',
            style: TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'TBD: occupancy spikes, class utilization, machine downtime, and chain-wide exceptions can live here.',
            style: TextStyle(color: _EglPastels.mutedInk, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _BusinessActionCard extends StatelessWidget {
  const _BusinessActionCard({required this.onLogout, required this.width});

  final VoidCallback onLogout;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.blue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: _EglPastels.white,
              foregroundColor: _EglPastels.ink,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
            style: FilledButton.styleFrom(
              backgroundColor: _EglPastels.greenStrong,
              foregroundColor: _EglPastels.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _EglPastels.blue : _EglPastels.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessContentPanel extends StatelessWidget {
  const _BusinessContentPanel({
    required this.selectedTab,
    required this.selectedSource,
    required this.config,
    required this.auditStore,
    required this.backendToken,
  });

  final _BusinessDashboardTab selectedTab;
  final String selectedSource;
  final AppConfig config;
  final LoginAuditStore auditStore;
  final String backendToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.shell),
      child: _buildSelectedContent(),
    );
  }

  Widget _buildSelectedContent() {
    switch (selectedTab) {
      case _BusinessDashboardTab.home:
        return _BusinessHomeContent(
          selectedSource: selectedSource,
          logins: auditStore.recentLogins,
        );
      case _BusinessDashboardTab.video:
        return _BusinessVideoContent(selectedSource: selectedSource);
      case _BusinessDashboardTab.dataFilter:
        return _BusinessDataFilterContent(selectedSource: selectedSource);
      case _BusinessDashboardTab.equipmentHealth:
        return _BusinessEquipmentContent(selectedSource: selectedSource);
      case _BusinessDashboardTab.insights:
        return _BusinessInsightsContent(selectedSource: selectedSource);
      case _BusinessDashboardTab.gymMap:
        return _BusinessMapContent(selectedSource: selectedSource);
    }
  }
}

class _BusinessHomeContent extends StatelessWidget {
  const _BusinessHomeContent({
    required this.selectedSource,
    required this.logins,
  });

  final String selectedSource;
  final List<AppUser> logins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chain summary for $selectedSource. This is the landing view for business partners.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _BusinessStatTile(
              title: 'Total Occupancy',
              value: '184',
              detail: 'Across visible sites right now',
            ),
            _BusinessStatTile(
              title: 'Alerted Zones',
              value: '04',
              detail: 'Areas worth reviewing',
            ),
            _BusinessStatTile(
              title: 'Machines At Risk',
              value: '07',
              detail: 'Likely maintenance follow-up',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _memberPanelDecoration(
              backgroundColor: _EglPastels.white,
            ),
            child: _LoginAuditCard(logins: logins),
          ),
        ),
      ],
    );
  }
}

class _BusinessVideoContent extends StatelessWidget {
  const _BusinessVideoContent({required this.selectedSource});

  final String selectedSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Feed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Primary monitored view for $selectedSource.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _memberPanelDecoration(
              backgroundColor: _EglPastels.blue,
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 84,
                    color: _EglPastels.blueStrong,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Live or processed video feed goes here',
                    style: TextStyle(
                      color: _EglPastels.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Future: camera stream, stick-figure overlay, occupancy count, and activity markers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _EglPastels.mutedInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessDataFilterContent extends StatelessWidget {
  const _BusinessDataFilterContent({required this.selectedSource});

  final String selectedSource;

  @override
  Widget build(BuildContext context) {
    const rows = <(String, String, String, String)>[
      ('07:42', 'Occupancy spike', 'Studio A', 'High'),
      ('08:05', 'Push-up cluster', 'Functional Zone', 'Medium'),
      ('08:18', 'Treadmill idle', 'Cardio Row', 'Low'),
      ('08:31', 'Sit-up session', 'Mat Area', 'Medium'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Filter',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Filtered event snapshots for $selectedSource.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _FilterPill(label: 'Today'),
            _FilterPill(label: 'All cameras'),
            _FilterPill(label: 'Human activity'),
            _FilterPill(label: 'High confidence'),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _memberPanelDecoration(
              backgroundColor: _EglPastels.white,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: _EglPastels.border),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        row.$1,
                        style: const TextStyle(color: _EglPastels.mutedInk),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          color: _EglPastels.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        row.$3,
                        style: const TextStyle(color: _EglPastels.mutedInk),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.$4,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _EglPastels.blueStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessEquipmentContent extends StatelessWidget {
  const _BusinessEquipmentContent({required this.selectedSource});

  final String selectedSource;

  @override
  Widget build(BuildContext context) {
    const equipment = <(String, String, Color)>[
      ('Treadmill Cluster A', 'Green', Color(0xFF79E39A)),
      ('Leg Press 02', 'Yellow', Color(0xFFF1D36B)),
      ('Cable Station 07', 'Red', Color(0xFFFF7B6B)),
      ('Bike Row', 'Green', Color(0xFF79E39A)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment Health',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Machine readiness for $selectedSource.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            itemCount: equipment.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = equipment[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: _memberPanelDecoration(
                  backgroundColor: _EglPastels.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: _EglPastels.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: item.$3.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: item.$3),
                      ),
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BusinessInsightsContent extends StatelessWidget {
  const _BusinessInsightsContent({required this.selectedSource});

  final String selectedSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Movement analytics and congregation trends for $selectedSource.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _BusinessStatTile(
              title: 'Push-up Detections',
              value: '41',
              detail: 'Estimated this morning',
            ),
            _BusinessStatTile(
              title: 'Sit-up Detections',
              value: '29',
              detail: 'Estimated this morning',
            ),
            _BusinessStatTile(
              title: 'Heat Zones',
              value: '3',
              detail: 'Needs crowd balancing',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _memberPanelDecoration(
              backgroundColor: _EglPastels.white,
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight Summary',
                  style: TextStyle(
                    color: _EglPastels.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'This panel can hold charts for movement categories, congestion windows, and machine adjacency usage. For now it acts as the blueprint for the analytics area you described.',
                  style: TextStyle(color: _EglPastels.mutedInk, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessMapContent extends StatelessWidget {
  const _BusinessMapContent({required this.selectedSource});

  final String selectedSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gym Map',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _EglPastels.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hot zones, dead zones, and machine status mapping for $selectedSource.',
          style: const TextStyle(color: _EglPastels.mutedInk),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _memberPanelDecoration(
              backgroundColor: _EglPastels.white,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _EglPastels.blue,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _EglPastels.border),
                    ),
                    child: Stack(
                      children: const [
                        Positioned(
                          left: 30,
                          top: 30,
                          child: _MapZoneMarker(
                            label: 'Entry Flow',
                            color: Color(0xFFFF7B6B),
                          ),
                        ),
                        Positioned(
                          left: 180,
                          top: 160,
                          child: _MapZoneMarker(
                            label: 'Weights',
                            color: Color(0xFFF1D36B),
                          ),
                        ),
                        Positioned(
                          right: 50,
                          top: 90,
                          child: _MapZoneMarker(
                            label: 'Cardio',
                            color: Color(0xFF79E39A),
                          ),
                        ),
                        Positioned(
                          right: 90,
                          bottom: 50,
                          child: _MapZoneMarker(
                            label: 'Studio',
                            color: Color(0xFF79E39A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _LegendChip(label: 'Green: healthy / low concern'),
                    _LegendChip(label: 'Yellow: watch / monitor'),
                    _LegendChip(label: 'Red: issue / crowding'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessStatTile extends StatelessWidget {
  const _BusinessStatTile({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: _memberPanelDecoration(backgroundColor: _EglPastels.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _EglPastels.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _EglPastels.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: _EglPastels.mutedInk)),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _EglPastels.blue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _EglPastels.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _EglPastels.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapZoneMarker extends StatelessWidget {
  const _MapZoneMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _EglPastels.green,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _EglPastels.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.currentUser,
    required this.config,
    required this.backendToken,
    required this.onLogout,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final AppUser currentUser;
  final AppConfig config;
  final String backendToken;
  final VoidCallback onLogout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.14),
              const Color(0xFF041611),
              const Color(0xFF071C17),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 16,
                      spacing: 16,
                      children: [
                        SizedBox(
                          width: 620,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: const Color(0xFFB8D1C6)),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Log out'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _ProfileCard(currentUser: currentUser, accent: accent),
                        _ServerCard(config: config, backendToken: backendToken),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 900
                            ? 2
                            : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.8,
                        children: children,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF97B6A9)),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFCADED3)),
          ),
        ],
      ),
    );
  }
}

class _LoginAuditCard extends StatelessWidget {
  const _LoginAuditCard({required this.logins});

  final List<AppUser> logins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Login Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (logins.isEmpty)
            const Text('No logins recorded yet.')
          else
            Expanded(
              child: ListView.separated(
                itemCount: logins.length > 6 ? 6 : logins.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: Color(0xFF29483E)),
                itemBuilder: (context, index) {
                  final login = logins[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      login.email,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${login.role == UserRole.business ? 'Business' : 'Member'} • ${_formatTimestamp(login.lastLogin)}',
                      style: const TextStyle(color: Color(0xFF9DB8AE)),
                    ),
                    trailing: Icon(
                      login.role == UserRole.business
                          ? Icons.apartment_rounded
                          : Icons.person_rounded,
                      color: const Color(0xFF6FD694),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.currentUser, required this.accent});

  final AppUser currentUser;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final roleText = currentUser.role == UserRole.business
        ? 'Business Account'
        : 'Easy Gym Life Member';

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(borderColor: accent.withValues(alpha: 0.55)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Icon(
                  currentUser.role == UserRole.business
                      ? Icons.storefront_rounded
                      : Icons.person_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleText,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentUser.email,
            style: const TextStyle(color: Color(0xFFCAE0D7), fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text(
            'Last authenticated at ${_formatTimestamp(currentUser.lastLogin)}',
            style: const TextStyle(color: Color(0xFF97B6A9)),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.config, required this.backendToken});

  final AppConfig config;
  final String backendToken;

  @override
  Widget build(BuildContext context) {
    final tokenPreview = backendToken.length > 18
        ? '${backendToken.substring(0, 18)}...'
        : backendToken;

    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend Configuration',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _ConfigRow(label: 'Base URL', value: config.baseUrl),
          _ConfigRow(label: 'Database', value: config.dbName),
          _ConfigRow(label: 'DB User', value: config.dbUser),
          _ConfigRow(label: 'JWT Issuer', value: config.jwtIssuer),
          _ConfigRow(label: 'JWT Token', value: tokenPreview),
          const SizedBox(height: 10),
          const Text(
            'For production, keep camera data processing and analytics on the server, then let Flutter render charts, dashboards, and alerts from API responses.',
            style: TextStyle(color: Color(0xFF97B6A9), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _EglPastels.blue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EglPastels.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connection details',
            style: TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ConfigRow(label: 'Endpoint', value: config.baseUrl),
          _ConfigRow(
            label: 'Database',
            value: '${config.dbName} (${config.dbUser})',
          ),
          _ConfigRow(label: 'Issuer', value: config.jwtIssuer),
        ],
      ),
    );
  }
}

class _DemoAccountPanel extends StatelessWidget {
  const _DemoAccountPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _EglPastels.green,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EglPastels.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demo access',
            style: TextStyle(
              color: _EglPastels.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Business demo: owner@iron-temple.com / Business123!',
            style: TextStyle(color: _EglPastels.ink),
          ),
          SizedBox(height: 6),
          Text(
            'Member demo: member@easygymlife.app / EGLUser123!',
            style: TextStyle(color: _EglPastels.ink),
          ),
          SizedBox(height: 10),
          Text(
            'These are preview credentials for exploring the app experience.',
            style: TextStyle(color: _EglPastels.mutedInk),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _EglPastels.ink,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    );
  }
}

class _StyledInput extends StatelessWidget {
  const _StyledInput({
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: _EglPastels.blue,
        hintStyle: const TextStyle(color: _EglPastels.mutedInk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _EglPastels.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _EglPastels.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _EglPastels.greenStrong,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      style: const TextStyle(
        color: _EglPastels.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: _EglPastels.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _EglPastels.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration({
  Color borderColor = const Color(0xFF29483E),
  Color backgroundColor = const Color(0xFF10211C),
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: borderColor),
  );
}

String _formatTimestamp(DateTime timestamp) {
  final hour = timestamp.hour > 12
      ? timestamp.hour - 12
      : timestamp.hour == 0
      ? 12
      : timestamp.hour;
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final period = timestamp.hour >= 12 ? 'PM' : 'AM';
  return '${timestamp.month}/${timestamp.day}/${timestamp.year} $hour:$minute $period';
}
