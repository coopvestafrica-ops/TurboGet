import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/logger_service.dart';

/// About screen with app info, version, and support links.
/// Designed by Ayanlowo Olatunji Ayobami
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _packageInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      logger.error('AboutScreen', 'Failed to load app info', error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App header
                  _buildHeader(),
                  const Divider(height: 1),
                  
                  // Creator section
                  _buildCreatorSection(),
                  const Divider(height: 1),
                  
                  // App info section
                  _buildSection(
                    title: 'App Information',
                    children: [
                      _buildInfoTile(
                        icon: Icons.info_outline,
                        title: 'Version',
                        subtitle: _packageInfo?.version ?? 'Unknown',
                      ),
                      _buildInfoTile(
                        icon: Icons.code,
                        title: 'Build Number',
                        subtitle: _packageInfo?.buildNumber ?? 'Unknown',
                      ),
                      _buildInfoTile(
                        icon: Icons.flutter_dash,
                        title: 'Framework',
                        subtitle: 'Flutter',
                      ),
                    ],
                  ),
                  
                  // Features section
                  _buildSection(
                    title: 'Features',
                    children: [
                      _buildFeatureTile(Icons.speed, 'Turbo Speed Downloads'),
                      _buildFeatureTile(Icons.sync, 'Resume Downloads'),
                      _buildFeatureTile(Icons.schedule, 'Scheduled Downloads'),
                      _buildFeatureTile(Icons.batch_prediction, 'Batch Import'),
                      _buildFeatureTile(Icons.play_circle, 'Media Playback'),
                      _buildFeatureTile(Icons.pause_circle, 'Pause & Resume'),
                      _buildFeatureTile(Icons.folder, 'File Browser'),
                      _buildFeatureTile(Icons.history, 'Download History'),
                      _buildFeatureTile(Icons.dark_mode, 'Dark Mode'),
                      _buildFeatureTile(Icons.cloud, 'Cloud Backup'),
                    ],
                  ),
                  
                  // Support section
                  _buildSection(
                    title: 'Support',
                    children: [
                      _buildLinkTile(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        subtitle: 'FAQs and troubleshooting',
                        onTap: () => _launchUrl('https://turboget.app/help'),
                      ),
                      _buildLinkTile(
                        icon: Icons.email_outlined,
                        title: 'Contact Developer',
                        subtitle: 'ayanlowo89@gmail.com',
                        onTap: () => _launchUrl('mailto:ayanlowo89@gmail.com'),
                      ),
                      _buildLinkTile(
                        icon: Icons.phone,
                        title: 'WhatsApp',
                        subtitle: '+234 703 819 3753',
                        onTap: () => _launchUrl('https://wa.me/2347038193753'),
                      ),
                      _buildLinkTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        onTap: () => _launchUrl('https://turboget.app/privacy'),
                      ),
                      _buildLinkTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Read our terms',
                        onTap: () => _launchUrl('https://turboget.app/terms'),
                      ),
                    ],
                  ),
                  
                  // Legal section
                  _buildSection(
                    title: 'Legal',
                    children: [
                      _buildLinkTile(
                        icon: Icons.article_outlined,
                        title: 'Open Source Licenses',
                        subtitle: 'Third-party licenses',
                        onTap: () => _showLicenses(),
                      ),
                    ],
                  ),
                  
                  // Credits
                  _buildCredits(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          // App icon with glow effect
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // App name
          Text(
            'TurboGet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          
          // Tagline
          Text(
            'The Best Download Manager',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'v${_packageInfo?.version ?? '?'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Designed & Developed By',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ayanlowo Olatunji Ayobami',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildContactButton(
                  icon: Icons.email,
                  label: 'Email',
                  color: Colors.red,
                  onTap: () => _launchUrl('mailto:ayanlowo89@gmail.com'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () => _launchUrl('https://wa.me/2347038193753'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '+234 703 819 3753',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildFeatureTile(IconData icon, String text) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
      dense: true,
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildCredits() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '© 2024 TurboGet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ❤️ using Flutter',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      logger.error('AboutScreen', 'Failed to open URL: $url', error: e);
    }
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'TurboGet',
      applicationVersion: _packageInfo?.version ?? 'Unknown',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.download_rounded,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
