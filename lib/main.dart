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

enum UserRole {
  business,
  gim,
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
  const AuthSession({
    required this.token,
    required this.user,
  });

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
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
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
      throw const AuthException(
        'The backend login response was incomplete.',
      );
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
      appName: values['APP_NAME'] ?? 'GIM Access',
      apiScheme: values['API_SCHEME'] ?? 'http',
      apiHost: values['API_HOST'] ?? 'localhost',
      apiPort: values['API_PORT'] ?? '3000',
      dbName: values['DB_NAME'] ?? 'gim_access',
      dbUser: values['DB_USER'] ?? 'app_user',
      jwtIssuer: values['JWT_ISSUER'] ?? 'gim-backend',
      businessPortalLabel:
          values['BUSINESS_PORTAL_LABEL'] ?? 'Business Dashboard',
      gimPortalLabel: values['GIM_PORTAL_LABEL'] ?? 'GIM User Dashboard',
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
      if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
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
  });

  final AppConfig config;
  final Future<void> Function(String email, String password) onLogin;

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
      await widget.onLogin(
        _emailController.text,
        _passwordController.text,
      );
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
        backgroundColor: const Color(0xFF102A22),
        title: const Text('Account onboarding'),
        content: const Text(
          'The next production step would be a backend signup or business onboarding flow handled by the Express API.',
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
            colors: [
              Color(0xFF03120F),
              Color(0xFF08231C),
              Color(0xFF041611),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                    color: const Color(0xFF2D3835).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF5D7369)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
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
                        const SizedBox(height: 8),
                        Text(
                          widget.config.appName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFFC9FFD8),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Flutter handles the interface. Express handles login, JWTs, and data.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF72DD98),
                              ),
                        ),
                        const SizedBox(height: 28),
                        const _FieldLabel(text: 'Email'),
                        const SizedBox(height: 8),
                        _StyledInput(
                          controller: _emailController,
                          hintText: 'member@gimlife.app',
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
                              color: Color(0xFFFFA9A9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5BC47F),
                            foregroundColor: const Color(0xFF052013),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Log In'),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: _showCreateAccountDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC9FFD8),
                            side: const BorderSide(color: Color(0xFFC9FFD8)),
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

enum BusinessWorkspaceTab {
  home,
  video,
  data,
  health,
  insights,
  map,
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
  BusinessWorkspaceTab _selectedTab = BusinessWorkspaceTab.home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabViews = <BusinessWorkspaceTab, Widget>{
      BusinessWorkspaceTab.home: _BusinessHomeView(
        auditStore: widget.auditStore,
      ),
      BusinessWorkspaceTab.video: const _BusinessVideoView(),
      BusinessWorkspaceTab.data: const _BusinessDataView(),
      BusinessWorkspaceTab.health: const _BusinessHealthView(),
      BusinessWorkspaceTab.insights: const _BusinessInsightsView(),
      BusinessWorkspaceTab.map: const _BusinessMapView(),
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF061A14),
              Color(0xFF08211A),
              Color(0xFF041611),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _BusinessSidebar(
                  selectedTab: _selectedTab,
                  currentUser: widget.currentUser,
                  onSelectTab: (tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _panelDecoration(
                          borderColor: const Color(0xFF3A6153),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.config.businessPortalLabel,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _businessTabSubtitle(_selectedTab),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFFB8D1C6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            _StatusBadge(
                              label: 'Backend ${widget.config.baseUrl}',
                              color: const Color(0xFF7BE6A5),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: widget.onLogout,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Log out'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey<BusinessWorkspaceTab>(_selectedTab),
                            child: tabViews[_selectedTab]!,
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
    );
  }
}

String _businessTabSubtitle(BusinessWorkspaceTab tab) {
  switch (tab) {
    case BusinessWorkspaceTab.home:
      return 'High-level operational snapshot for business partners.';
    case BusinessWorkspaceTab.video:
      return 'Live or recorded camera/vision feed workspace.';
    case BusinessWorkspaceTab.data:
      return 'Filterable event and equipment data reference.';
    case BusinessWorkspaceTab.health:
      return 'Machine status, maintenance flags, and warranty visibility.';
    case BusinessWorkspaceTab.insights:
      return 'Movement analytics, heat zones, and congregation insights.';
    case BusinessWorkspaceTab.map:
      return 'Gym map with hot zones, dead zones, and machine status markers.';
  }
}

class _BusinessSidebar extends StatelessWidget {
  const _BusinessSidebar({
    required this.selectedTab,
    required this.currentUser,
    required this.onSelectTab,
  });

  final BusinessWorkspaceTab selectedTab;
  final AppUser currentUser;
  final ValueChanged<BusinessWorkspaceTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final items = <(BusinessWorkspaceTab, IconData, String)>[
      (BusinessWorkspaceTab.home, Icons.home_rounded, 'Home'),
      (BusinessWorkspaceTab.video, Icons.videocam_rounded, 'Video'),
      (BusinessWorkspaceTab.data, Icons.table_chart_rounded, 'Data Filter'),
      (BusinessWorkspaceTab.health, Icons.fitness_center_rounded, 'Equipment Health'),
      (BusinessWorkspaceTab.insights, Icons.analytics_rounded, 'Insights'),
      (BusinessWorkspaceTab.map, Icons.map_rounded, 'Gym Map'),
    ];

    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(
        borderColor: const Color(0xFF315347),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF7BE6A5).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF7BE6A5),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Workspace',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Partner-only dashboard',
                      style: TextStyle(
                        color: Color(0xFF9DB8AE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            currentUser.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.email,
            style: const TextStyle(
              color: Color(0xFF9DB8AE),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          for (final item in items) ...[
            _BusinessSidebarItem(
              icon: item.$2,
              label: item.$3,
              selected: selectedTab == item.$1,
              onTap: () => onSelectTab(item.$1),
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF162A24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF29483E)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo note',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This workspace is reserved for authenticated business partners. The layout is ready to receive live backend metrics later.',
                  style: TextStyle(
                    color: Color(0xFF9DB8AE),
                    height: 1.4,
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

class _BusinessSidebarItem extends StatelessWidget {
  const _BusinessSidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7BE6A5).withValues(alpha: 0.16)
              : const Color(0xFF10211C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF7BE6A5)
                : const Color(0xFF29483E),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF7BE6A5) : const Color(0xFF9DB8AE),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFD1E2D9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessHomeView extends StatelessWidget {
  const _BusinessHomeView({
    required this.auditStore,
  });

  final LoginAuditStore auditStore;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.65,
      children: [
        const _MetricCard(
          title: 'Active Locations',
          value: '12',
          detail: 'Three locations are currently feeding occupancy and health data.',
        ),
        const _MetricCard(
          title: 'Live Cameras',
          value: '08',
          detail: 'Six online, one degraded, one awaiting calibration.',
        ),
        const _MetricCard(
          title: 'Machine Alerts',
          value: '03',
          detail: 'Two maintenance flags and one warranty warning are active.',
        ),
        _LoginAuditCard(logins: auditStore.recentLogins),
      ],
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
                  style: TextStyle(
                    color: Color(0xFF9DB8AE),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0E2B23),
                          Color(0xFF18362F),
                        ],
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
                            style: TextStyle(
                              color: Color(0xFF9DB8AE),
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
              _StatusBadge(label: 'Location: Downtown', color: Color(0xFF8FD8FF)),
              _StatusBadge(label: 'Window: Today', color: Color(0xFFF4C96B)),
              _StatusBadge(label: 'Source: Vision events', color: Color(0xFF7BE6A5)),
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
                dataRowColor: WidgetStateProperty.all(
                  const Color(0xFF10211C),
                ),
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
                        cells: row.map((value) => DataCell(Text(value))).toList(),
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
    final equipment = <({String name, String status, double health, Color color})>[
      (name: 'PTRM1001 Treadmill', status: 'Healthy', health: 0.91, color: const Color(0xFF7BE6A5)),
      (name: 'PTRM1004 Treadmill', status: 'Watchlist', health: 0.66, color: const Color(0xFFF4C96B)),
      (name: 'LEGP2001 Leg Press', status: 'Needs Service', health: 0.38, color: const Color(0xFFE98D86)),
      (name: 'ELLP3002 Elliptical', status: 'Healthy', health: 0.88, color: const Color(0xFF7BE6A5)),
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
          detail: 'Most concentrated usage zone based on current event density.',
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
                          child: _MapZone(label: 'Cardio', color: Color(0x447BE6A5), width: 220, height: 120),
                        ),
                        Positioned(
                          right: 38,
                          top: 60,
                          child: _MapZone(label: 'Free Weights', color: Color(0x44F4C96B), width: 200, height: 140),
                        ),
                        Positioned(
                          left: 90,
                          bottom: 40,
                          child: _MapZone(label: 'Studios', color: Color(0x448FD8FF), width: 180, height: 110),
                        ),
                        Positioned(
                          right: 90,
                          bottom: 60,
                          child: _MachineMarker(label: 'PTRM1001', color: Color(0xFF7BE6A5)),
                        ),
                        Positioned(
                          right: 160,
                          bottom: 100,
                          child: _MachineMarker(label: 'LEGP2001', color: Color(0xFFF4C96B)),
                        ),
                        Positioned(
                          left: 180,
                          top: 90,
                          child: _MachineMarker(label: 'ELLP3002', color: Color(0xFFE98D86)),
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
                _StatusBadge(label: 'Equipment state', color: Color(0xFF7BE6A5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
  const _MachineMarker({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.location_on_rounded,
          color: color,
          size: 28,
        ),
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
  const _LegendRow({
    required this.label,
    required this.color,
  });

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
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD1E2D9),
            ),
          ),
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
    return _DashboardFrame(
      title: config.gimPortalLabel,
      subtitle: 'General GIM users are routed here after authentication.',
      accent: const Color(0xFF8FD8FF),
      currentUser: currentUser,
      config: config,
      backendToken: backendToken,
      onLogout: onLogout,
      children: [
        const _MetricCard(
          title: 'Today\'s Plan',
          value: 'Strength',
          detail: 'A future workout service can feed this from the backend.',
        ),
        const _MetricCard(
          title: 'Check-In Status',
          value: 'Ready',
          detail: 'QR or access state should be delivered by the API.',
        ),
        const _MetricCard(
          title: 'Graphics Feed',
          value: 'Live',
          detail: 'Flutter can render charts from data collected and stored by Node.',
        ),
        _LoginAuditCard(logins: auditStore.recentLogins),
      ],
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
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
                        _ProfileCard(
                          currentUser: currentUser,
                          accent: accent,
                        ),
                        _ServerCard(
                          config: config,
                          backendToken: backendToken,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 900 ? 2 : 1,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF97B6A9),
                ),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFCADED3),
                ),
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
                      '${login.role == UserRole.business ? 'Business' : 'GIM user'} • ${_formatTimestamp(login.lastLogin)}',
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
  const _ProfileCard({
    required this.currentUser,
    required this.accent,
  });

  final AppUser currentUser;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final roleText = currentUser.role == UserRole.business
        ? 'Business Account'
        : 'GIM Member';

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
            style: const TextStyle(
              color: Color(0xFFCAE0D7),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Last authenticated at ${_formatTimestamp(currentUser.lastLogin)}',
            style: const TextStyle(
              color: Color(0xFF97B6A9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.config,
    required this.backendToken,
  });

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
            style: TextStyle(
              color: Color(0xFF97B6A9),
              height: 1.4,
            ),
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
        color: const Color(0xFF24302C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42564E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configured server',
            style: TextStyle(
              color: Color(0xFFC9FFD8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ConfigRow(label: 'Endpoint', value: config.baseUrl),
          _ConfigRow(label: 'Database', value: '${config.dbName} (${config.dbUser})'),
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
        color: const Color(0xFF1B2623),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF355048)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Public demo accounts',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Business demo: owner@iron-temple.com / Business123!',
            style: TextStyle(color: Color(0xFFCAE0D7)),
          ),
          SizedBox(height: 6),
          Text(
            'General demo: member@gimlife.app / GimUser123!',
            style: TextStyle(color: Color(0xFFCAE0D7)),
          ),
          SizedBox(height: 10),
          Text(
            'These are public demo-only app credentials. Do not reuse them in real environments.',
            style: TextStyle(color: Color(0xFF97B6A9)),
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
        color: Color(0xFFC9FFD8),
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
        fillColor: const Color(0xFFDDE7F4),
        hintStyle: const TextStyle(color: Color(0xFF5C6878)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(fontWeight: FontWeight.w600),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      style: const TextStyle(
        color: Color(0xFF13202E),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
  });

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
                color: Color(0xFF97B6A9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration({Color borderColor = const Color(0xFF29483E)}) {
  return BoxDecoration(
    color: const Color(0xFF10211C),
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
