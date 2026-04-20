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
      appName: values['APP_NAME'] ?? 'Easy Gym Life',
      apiScheme: values['API_SCHEME'] ?? 'http',
      apiHost: values['API_HOST'] ?? 'localhost',
      apiPort: values['API_PORT'] ?? '3000',
      dbName: values['DB_NAME'] ?? 'easy_gym_life',
      dbUser: values['DB_USER'] ?? 'app_user',
      jwtIssuer: values['JWT_ISSUER'] ?? 'gim-backend',
      businessPortalLabel:
          values['BUSINESS_PORTAL_LABEL'] ?? 'Business Dashboard',
      gimPortalLabel: values['GIM_PORTAL_LABEL'] ?? 'Easy Gym Life Member Dashboard',
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
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed:
                              _isLoading ? null : widget.onEnterBusinessDemo,
                          icon: const Icon(Icons.storefront_rounded),
                          label: const Text('Enter Business Demo Dashboard'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8BF0B4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed:
                              _isLoading ? null : widget.onEnterGeneralDemo,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Enter Member Demo Dashboard'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9EE4FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use the demo dashboard buttons when backend authentication is still being set up and you need to preview the business or member experience.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF9FB7AE),
                                  ),
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
  String _selectedSource = 'All Sources';

  static const List<String> _sources = <String>[
    'All Sources',
    'Iron Temple - Tempe',
    'Iron Temple - Mesa',
    'Iron Temple - Downtown',
  ];

  void _selectTab(_BusinessDashboardTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _selectSource(String source) {
    setState(() {
      _selectedSource = source;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF7BE6A5);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.12),
              const Color(0xFF041611),
              const Color(0xFF071C17),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 980;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: isWide ? 220 : 92,
                      child: _BusinessSidebar(
                        selectedTab: _selectedTab,
                        onSelectTab: _selectTab,
                        isCompact: !isWide,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _BusinessHeaderCard(
                                companyName: widget.config.businessPortalLabel,
                                currentUser: widget.currentUser,
                                width: isWide ? 320 : constraints.maxWidth - 160,
                              ),
                              _BusinessTbdCard(
                                width: isWide ? 360 : constraints.maxWidth - 160,
                              ),
                              _BusinessActionCard(
                                onLogout: widget.onLogout,
                                width: isWide ? 220 : constraints.maxWidth - 160,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 54,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _sources.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final source = _sources[index];
                                final isSelected = source == _selectedSource;
                                return _SourceChip(
                                  label: source,
                                  selected: isSelected,
                                  onTap: () => _selectSource(source),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
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
                );
              },
            ),
          ),
        ),
      ),
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
      subtitle: 'Easy Gym Life members are routed here for planning, scheduling, workouts, and day-to-day gym tools.',
      accent: const Color(0xFF8FD8FF),
      currentUser: currentUser,
      config: config,
      backendToken: backendToken,
      onLogout: onLogout,
      children: [
        const _MetricCard(
          title: 'Workout Plan',
          value: 'Upper Body',
          detail: 'This space can surface the current training plan for the member.',
        ),
        const _MetricCard(
          title: 'Schedule',
          value: '6:30 PM',
          detail: 'Class bookings, coaching sessions, or reminders can appear here.',
        ),
        const _MetricCard(
          title: 'Calendar',
          value: '4 Sessions',
          detail: 'A lighter member dashboard can focus on consistency, workouts, and upcoming activity.',
        ),
        const _MetricCard(
          title: 'Consistency',
          value: '12 Days',
          detail: 'This can later track a continuous attendance streak or weekly consistency goal.',
        ),
      ],
    );
  }
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
      decoration: _panelDecoration(
        borderColor: const Color(0xFF335A4A),
      ),
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
      color: selected ? const Color(0xFF1A5BFF) : const Color(0xFF16231F),
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
            mainAxisAlignment:
                isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Colors.white,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
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
      decoration: _panelDecoration(
        backgroundColor: const Color(0xFF173226),
        borderColor: const Color(0xFF3F775B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser.displayName,
            style: const TextStyle(
              color: Color(0xFFBAF7D2),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.email,
            style: const TextStyle(
              color: Color(0xFFCAE0D7),
            ),
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
      decoration: _panelDecoration(
        backgroundColor: const Color(0xFF173226),
        borderColor: const Color(0xFF3F775B),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority Metrics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'TBD: occupancy spikes, class utilization, machine downtime, and chain-wide exceptions can live here.',
            style: TextStyle(
              color: Color(0xFFCAE0D7),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessActionCard extends StatelessWidget {
  const _BusinessActionCard({
    required this.onLogout,
    required this.width,
  });

  final VoidCallback onLogout;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(
        backgroundColor: const Color(0xFF173226),
        borderColor: const Color(0xFF3F775B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Settings'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
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
      color: selected ? const Color(0xFF9F342B) : const Color(0xFF40231F),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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
      decoration: _panelDecoration(
        backgroundColor: const Color(0xFF1547D8),
        borderColor: const Color(0xFF6FA2FF),
      ),
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chain summary for $selectedSource. This is the landing view for business partners.',
          style: const TextStyle(
            color: Color(0xFFD9E6FF),
          ),
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
            decoration: _panelDecoration(
              backgroundColor: const Color(0xFF10317D),
              borderColor: const Color(0xFF5F96FF),
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Primary monitored view for $selectedSource.',
          style: const TextStyle(color: Color(0xFFD9E6FF)),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _panelDecoration(
              backgroundColor: const Color(0xFF0A1F5F),
              borderColor: const Color(0xFF5F96FF),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 84,
                    color: Color(0xFFA6C7FF),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Live or processed video feed goes here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Future: camera stream, stick-figure overlay, occupancy count, and activity markers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD9E6FF),
                    ),
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Filtered event snapshots for $selectedSource.',
          style: const TextStyle(color: Color(0xFFD9E6FF)),
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
            decoration: _panelDecoration(
              backgroundColor: const Color(0xFF0F2C73),
              borderColor: const Color(0xFF5F96FF),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Color(0xFF4F78D3)),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        row.$1,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        row.$3,
                        style: const TextStyle(color: Color(0xFFD9E6FF)),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.$4,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFFAEE6FF),
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Machine readiness for $selectedSource.',
          style: const TextStyle(color: Color(0xFFD9E6FF)),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            itemCount: equipment.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = equipment[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: _panelDecoration(
                  backgroundColor: const Color(0xFF0F2C73),
                  borderColor: const Color(0xFF5F96FF),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: Colors.white,
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Movement analytics and congregation trends for $selectedSource.',
          style: const TextStyle(color: Color(0xFFD9E6FF)),
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
            decoration: _panelDecoration(
              backgroundColor: const Color(0xFF0F2C73),
              borderColor: const Color(0xFF5F96FF),
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'This panel can hold charts for movement categories, congestion windows, and machine adjacency usage. For now it acts as the blueprint for the analytics area you described.',
                  style: TextStyle(
                    color: Color(0xFFD9E6FF),
                    height: 1.5,
                  ),
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hot zones, dead zones, and machine status mapping for $selectedSource.',
          style: const TextStyle(color: Color(0xFFD9E6FF)),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: _panelDecoration(
              backgroundColor: const Color(0xFF0F2C73),
              borderColor: const Color(0xFF5F96FF),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF12396F),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF5F96FF)),
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
      decoration: _panelDecoration(
        backgroundColor: const Color(0xFF0F2C73),
        borderColor: const Color(0xFF5F96FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD9E6FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: Color(0xFFAFC9FF),
            ),
          ),
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
        color: const Color(0xFF244D9B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7EA9FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapZoneMarker extends StatelessWidget {
  const _MapZoneMarker({
    required this.label,
    required this.color,
  });

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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
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
        color: const Color(0xFF23498F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD9E6FF),
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
                separatorBuilder: (_, __) =>
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
            'Member demo: member@easygymlife.app / GimUser123!',
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
