import 'package:flutter/material.dart';

const _ink = Color(0xFF17243A);
const _muted = Color(0xFF778399);
const _blue = Color(0xFF4169E1);
const _page = Color(0xFFF5F7FB);

void main() {
  runApp(const VistaCiApp());
}

class VistaCiApp extends StatelessWidget {
  const VistaCiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vista CI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _page,
        colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        appBarTheme: const AppBarTheme(
          backgroundColor: _page,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const PipelineOverviewPage(),
    );
  }
}

class PipelineOverviewPage extends StatelessWidget {
  const PipelineOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            _BrandMark(),
            SizedBox(width: 10),
            Text('Vista CI', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: null,
            tooltip: 'Notifications will be available after setup',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: const [
          Text(
            'PROJECT OVERVIEW',
            style: TextStyle(
              color: _blue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pipeline status',
            style: TextStyle(
              color: _ink,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'A clear view of your builds and deployments.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          SizedBox(height: 20),
          _FirebaseNotice(),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Workflows',
                  icon: Icons.account_tree_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Succeeded',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Failed',
                  icon: Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          _RecentRunsCard(),
          SizedBox(height: 22),
          Text(
            'GETTING STARTED',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 12),
          _SetupStep(
            number: '01',
            title: 'Connect Firebase',
            subtitle: 'Create the project and add your app.',
          ),
          SizedBox(height: 10),
          _SetupStep(
            number: '02',
            title: 'Connect a repository',
            subtitle: 'Choose which workflows Vista should follow.',
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text(
        'V',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FirebaseNotice extends StatelessWidget {
  const _FirebaseNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_outlined, color: _blue),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase not connected',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Connect your Firebase project to start showing live pipeline data.',
                  style: TextStyle(color: _muted, height: 1.4, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 19, color: _blue),
          const Text(
            '—',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RecentRunsCard extends StatelessWidget {
  const _RecentRunsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent runs',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 28, color: Color(0xFF9AA6B8)),
                SizedBox(height: 8),
                Text(
                  'No pipeline runs yet',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Your latest activity will appear here.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }
}
