import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildLogo(colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'MaS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Container(
        color: colorScheme.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive values
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 600;
            final isMediumScreen = screenWidth >= 600 && screenWidth < 1200;
            
            // Responsive padding
            final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
            final verticalPadding = isSmallScreen ? 16.0 : 24.0;
            
            // Responsive text sizes
            final titleSize = isSmallScreen ? 24.0 : 28.0;
            final subtitleSize = isSmallScreen ? 14.0 : 16.0;
            
            // Responsive grid columns
            final crossAxisCount = isSmallScreen ? 1 : (isMediumScreen ? 2 : 3);
            
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildLogo(colorScheme.primary, size: isSmallScreen ? 40 : 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to MaS',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose a feature to get started',
                              style: TextStyle(
                                fontSize: subtitleSize,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: isSmallScreen ? 16 : 24,
                      crossAxisSpacing: isSmallScreen ? 16 : 24,
                      childAspectRatio: isSmallScreen ? 1.5 : 1.2,
                      children: [
                        _buildFeatureCard(
                          context,
                          'Template Management',
                          Icons.description,
                          'Upload and manage templates, generate files from datasets',
                          () {
                            Navigator.pushNamed(context, '/templates');
                          },
                          isSmallScreen,
                        ),
                        _buildFeatureCard(
                          context,
                          'Send Emails',
                          Icons.email,
                          'Send emails with attachments to recipients',
                          () {
                            Navigator.pushNamed(context, '/emails');
                          },
                          isSmallScreen,
                        ),
                        _buildFeatureCard(
                          context,
                          'Recent Templates',
                          Icons.history,
                          'View and access your recent templates',
                          () {
                            Navigator.pushNamed(context, '/templates');
                          },
                          isSmallScreen,
                        ),
                        _buildFeatureCard(
                          context,
                          'Settings',
                          Icons.settings,
                          'Configure application settings and preferences',
                          () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          isSmallScreen,
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
    );
  }

  Widget _buildLogo(Color color, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          // Letter M
          Text(
            'M',
            style: TextStyle(
              color: color,
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Small 'a' and 'S'
          Positioned(
            right: size * 0.15,
            bottom: size * 0.15,
            child: Text(
              'aS',
              style: TextStyle(
                color: color,
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
    bool isSmallScreen,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 24 : 32,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 