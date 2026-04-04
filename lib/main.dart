import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const GymDemoApp());
}

class GymDemoApp extends StatelessWidget {
  const GymDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EGL Gym Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A9B7B)),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    MapPage(),
    JournalPage(),
    EasyAIPage(),
    ReservePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],

          /// Global EGL logo shown on every page
          SafeArea(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 12),
                child: Image.asset(
                  'assets/egl_logo.png',
                  width: 74,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.book_outlined), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'EasyAI'),
          NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Reserve'),
        ],
      ),
    );
  }
}

/* ===========================
   DATA MODELS + TEST DATA
   =========================== */

class UsageLog {
  final String logId;
  final String sensorId;
  final String equipmentId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalMin;
  final double intensityScore;
  final String machineStatus;

  const UsageLog({
    required this.logId,
    required this.sensorId,
    required this.equipmentId,
    required this.startTime,
    required this.endTime,
    required this.totalMin,
    required this.intensityScore,
    required this.machineStatus,
  });
}

enum ZoneStatus {
  available,
  moderate,
  busy,
  maintenance,
}

Color zoneColor(ZoneStatus status) {
  switch (status) {
    case ZoneStatus.available:
      return const Color(0xFF4CAF50);
    case ZoneStatus.moderate:
      return const Color(0xFFF4C542);
    case ZoneStatus.busy:
      return const Color(0xFFE74C3C);
    case ZoneStatus.maintenance:
      return const Color(0xFF9E9E9E);
  }
}

String zoneLabel(ZoneStatus status) {
  switch (status) {
    case ZoneStatus.available:
      return 'Available';
    case ZoneStatus.moderate:
      return 'Moderate';
    case ZoneStatus.busy:
      return 'Busy';
    case ZoneStatus.maintenance:
      return 'Maintenance';
  }
}

final List<UsageLog> sampleLogs = [
  UsageLog(
    logId: '100505',
    sensorId: 'WIP1001',
    equipmentId: 'PTRM1001',
    startTime: DateTime(2026, 4, 14, 7, 15),
    endTime: DateTime(2026, 4, 14, 7, 55),
    totalMin: 40,
    intensityScore: 0.60,
    machineStatus: 'Running',
  ),
  UsageLog(
    logId: '100506',
    sensorId: 'WIP1002',
    equipmentId: 'PTRM1002',
    startTime: DateTime(2026, 4, 14, 8, 30),
    endTime: DateTime(2026, 4, 14, 9, 15),
    totalMin: 45,
    intensityScore: 0.82,
    machineStatus: 'Running',
  ),
  UsageLog(
    logId: '100507',
    sensorId: 'WIP1003',
    equipmentId: 'PTRM1003',
    startTime: DateTime(2026, 4, 14, 9, 45),
    endTime: DateTime(2026, 4, 14, 10, 30),
    totalMin: 45,
    intensityScore: 0.47,
    machineStatus: 'Running',
  ),
  UsageLog(
    logId: '100424',
    sensorId: 'WIP1004',
    equipmentId: 'PTRM1004',
    startTime: DateTime(2026, 4, 2, 11, 0),
    endTime: DateTime(2026, 4, 2, 11, 45),
    totalMin: 45,
    intensityScore: 0.0,
    machineStatus: 'Maintenance',
  ),
  UsageLog(
    logId: '100425',
    sensorId: 'WIP1005',
    equipmentId: 'PTRM1005',
    startTime: DateTime(2026, 4, 2, 12, 15),
    endTime: DateTime(2026, 4, 2, 13, 0),
    totalMin: 45,
    intensityScore: 0.0,
    machineStatus: 'Maintenance',
  ),
  UsageLog(
    logId: '100426',
    sensorId: 'WIP1006',
    equipmentId: 'PTRM1006',
    startTime: DateTime(2026, 4, 2, 13, 30),
    endTime: DateTime(2026, 4, 2, 14, 10),
    totalMin: 40,
    intensityScore: 0.68,
    machineStatus: 'Running',
  ),
  UsageLog(
    logId: '100427',
    sensorId: 'WIP1007',
    equipmentId: 'PTRM1007',
    startTime: DateTime(2026, 4, 2, 14, 45),
    endTime: DateTime(2026, 4, 2, 15, 30),
    totalMin: 45,
    intensityScore: 0.94,
    machineStatus: 'Running',
  ),
];

final Map<String, String> equipmentToZone = {
  'PTRM1001': 'Treadmills A',
  'PTRM1002': 'Treadmills B',
  'PTRM1003': 'Ellipticals',
  'PTRM1004': 'Leg Press',
  'PTRM1005': 'Chest Press',
  'PTRM1006': 'Free Weights',
  'PTRM1007': 'Benches',
};

ZoneStatus statusFromLog(UsageLog log) {
  if (log.machineStatus.toLowerCase() == 'maintenance') {
    return ZoneStatus.maintenance;
  }
  if (log.intensityScore >= 0.75) {
    return ZoneStatus.busy;
  }
  if (log.intensityScore >= 0.50) {
    return ZoneStatus.moderate;
  }
  return ZoneStatus.available;
}

/* ===========================
   SHARED HEADER
   =========================== */

class TopLeftHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData trailingIcon;

  const TopLeftHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(104, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 24,
              child: Icon(trailingIcon, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

/* ===========================
   MAP PAGE
   =========================== */

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final zoneEntries = sampleLogs.map((log) {
      return MapEntry(equipmentToZone[log.equipmentId] ?? log.equipmentId, log);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: const Color(0xFFF6F6F4)),
          ),
          const TopLeftHeader(
            title: 'Crunch Fitness',
            subtitle: 'Tempe, AZ · 1.2 mi',
            trailingIcon: Icons.access_time,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Text(
                            'Temporary Gym Layout Demo',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _ZoneBox(
                          left: 10,
                          top: 45,
                          width: 120,
                          height: 85,
                          label: 'Free Weights',
                          status: ZoneStatus.moderate,
                        ),
                        _ZoneBox(
                          left: 155,
                          top: 45,
                          width: 130,
                          height: 85,
                          label: 'Selector Machines',
                          status: ZoneStatus.available,
                        ),
                        _ZoneBox(
                          left: 25,
                          top: 165,
                          width: 120,
                          height: 95,
                          label: 'Benches',
                          status: ZoneStatus.busy,
                        ),
                        _ZoneBox(
                          left: 170,
                          top: 170,
                          width: 135,
                          height: 80,
                          label: 'Treadmills A',
                          status: statusFromLog(sampleLogs[0]),
                        ),
                        _ZoneBox(
                          left: 170,
                          top: 270,
                          width: 135,
                          height: 80,
                          label: 'Treadmills B',
                          status: statusFromLog(sampleLogs[1]),
                        ),
                        _ZoneBox(
                          left: 20,
                          top: 285,
                          width: 125,
                          height: 70,
                          label: 'Ellipticals',
                          status: statusFromLog(sampleLogs[2]),
                        ),
                        _ZoneBox(
                          left: 320,
                          top: 175,
                          width: 95,
                          height: 72,
                          label: 'Leg Press',
                          status: statusFromLog(sampleLogs[3]),
                        ),
                        _ZoneBox(
                          left: 320,
                          top: 270,
                          width: 95,
                          height: 72,
                          label: 'Chest Press',
                          status: statusFromLog(sampleLogs[4]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Color(0xFF4CAF50)),
                          SizedBox(width: 6),
                          Text('Available'),
                          SizedBox(width: 16),
                          Icon(Icons.location_on, color: Color(0xFFF4C542)),
                          SizedBox(width: 6),
                          Text('Moderate'),
                          SizedBox(width: 16),
                          Icon(Icons.location_on, color: Color(0xFFE74C3C)),
                          SizedBox(width: 6),
                          Text('Busy'),
                          SizedBox(width: 16),
                          Icon(Icons.location_on, color: Color(0xFF9E9E9E)),
                          SizedBox(width: 6),
                          Text('Maintenance'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (_) => _DataPreviewSheet(entries: zoneEntries),
                                );
                              },
                              child: const Text('View Live Demo Data'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _ZoneBox extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final String label;
  final ZoneStatus status;

  const _ZoneBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        children: [
          Icon(Icons.location_on, color: zoneColor(status), size: 34),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPreviewSheet extends StatelessWidget {
  final List<MapEntry<String, UsageLog>> entries;

  const _DataPreviewSheet({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Embedded Test Data Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Using sample rows from your teammate’s Sheet 2 usage logs.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          ...entries.take(7).map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: zoneColor(statusFromLog(entry.value))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${entry.key} • ${entry.value.machineStatus} • intensity ${entry.value.intensityScore.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
   JOURNAL PAGE
   =========================== */

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  int selectedDay = 1;

  final List<Map<String, dynamic>> days = [
    {'day': 'Mon', 'type': 'Push'},
    {'day': 'Tue', 'type': 'Pull'},
    {'day': 'Wed', 'type': 'Legs'},
    {'day': 'Thu', 'type': 'Arms'},
    {'day': 'Fri', 'type': 'Upper'},
    {'day': 'Sat', 'type': 'Lower'},
    {'day': 'Sun', 'type': 'Rest'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      body: Stack(
        children: [
          const TopLeftHeader(
            title: 'Workout Journal',
            subtitle: 'Track your training plan',
            trailingIcon: Icons.calendar_month,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            child: Column(
              children: [
                GlassCard(
                  child: SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final isSelected = selectedDay == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDay = index;
                            });
                          },
                          child: Container(
                            width: 88,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7A9B7B) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  days[index]['day'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  days[index]['type'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${days[selectedDay]['type']} Day',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        const _WorkoutRow(name: 'Bench Press', sets: '4', reps: '8'),
                        const _WorkoutRow(name: 'Incline Dumbbell Press', sets: '3', reps: '10'),
                        const _WorkoutRow(name: 'Cable Fly', sets: '3', reps: '12'),
                        const _WorkoutRow(name: 'Tricep Pushdown', sets: '3', reps: '12'),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.add),
                                label: const Text('Add Workout'),
                              ),
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
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final String name;
  final String sets;
  final String reps;

  const _WorkoutRow({
    required this.name,
    required this.sets,
    required this.reps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text('$sets sets • $reps reps'),
        ],
      ),
    );
  }
}

/* ===========================
   EASY AI PAGE
   =========================== */

class EasyAIPage extends StatelessWidget {
  const EasyAIPage({super.key});

  void _showResponse(BuildContext context, String prompt) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prompt,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Demo AI Response:\n\n'
              'Based on current test usage, Treadmills B and Benches are seeing heavy usage.\n'
              'Ellipticals look more open right now.\n'
              'Machines in maintenance are temporarily unavailable.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'What is open right now?',
      'What should I do while I wait?',
      'What is the best workout for me today?',
      'What machine should I avoid right now?',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      body: Stack(
        children: [
          const TopLeftHeader(
            title: 'EasyAI',
            subtitle: 'Ask fast questions about the gym',
            trailingIcon: Icons.smart_toy,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            child: ListView.separated(
              itemCount: prompts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      prompts[index],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showResponse(context, prompts[index]),
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

/* ===========================
   RESERVE PAGE
   =========================== */

class ReservePage extends StatefulWidget {
  const ReservePage({super.key});

  @override
  State<ReservePage> createState() => _ReservePageState();
}

class _ReservePageState extends State<ReservePage> {
  Timer? timer;
  int reservedSeconds = 0;
  String reservedMachine = '';

  final List<Map<String, String>> machines = [
    {'name': 'Bench Press #2', 'zone': 'Benches'},
    {'name': 'Treadmill #4', 'zone': 'Treadmills B'},
    {'name': 'Elliptical #1', 'zone': 'Ellipticals'},
    {'name': 'Cable Station', 'zone': 'Selector Machines'},
  ];

  void reserveMachine(String machine) {
    setState(() {
      reservedMachine = machine;
      reservedSeconds = 180;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (reservedSeconds <= 1) {
        t.cancel();
        setState(() {
          reservedSeconds = 0;
          reservedMachine = '';
        });
      } else {
        setState(() {
          reservedSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      body: Stack(
        children: [
          const TopLeftHeader(
            title: 'Reserve',
            subtitle: 'Hold a machine for a short time',
            trailingIcon: Icons.lock_clock,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            child: Column(
              children: [
                GlassCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reservedSeconds > 0
                              ? 'You reserved $reservedMachine • $reservedSeconds seconds left'
                              : 'Reserve concept demo: tap a machine and simulate a 3-minute hold.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: machines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final machine = machines[index];
                      final isReserved =
                          reservedMachine == machine['name'] &&
                          reservedSeconds > 0;

                      return GlassCard(
                        child: Row(
                          children: [
                            const Icon(Icons.fitness_center),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    machine['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    machine['zone']!,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: isReserved
                                  ? null
                                  : () => reserveMachine(machine['name']!),
                              child: Text(isReserved ? 'Held' : 'Reserve'),
                            ),
                          ],
                        ),
                      );
                    },
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