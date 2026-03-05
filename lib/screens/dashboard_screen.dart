import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  bool _hasRequiredRole(List<String> userRoles, List<String> requiredRoles) {
    return userRoles.any(
      (role) => requiredRoles.any(
        (required) => role.toLowerCase() == required.toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user ?? StorageService.getUser();
    final username = user?.name ?? 'User';
    final userRoles = user?.roleNames ?? [];
    final rolesText =
        userRoles.isNotEmpty ? userRoles.join(', ') : 'No role assigned';

    // Check role permissions
    // Administrator & KI: access all
    // KU: Budget, Attendance, Zakat Fitrah
    // Penerobos/PNB: Attendance, Member
    // Teacher: KBM only
    // Amil: Zakat Fitrah only
    final canAccessBudget = _hasRequiredRole(userRoles, [
      'Administrator',
      'KI',
      'KU',
    ]);
    final canAccessAttendance = _hasRequiredRole(userRoles, [
      'Administrator',
      'KI',
      'KU',
      'Penerobos',
      'PNB',
    ]);
    final canAccessMembers = _hasRequiredRole(userRoles, [
      'Administrator',
      'KI',
      'Penerobos',
      'PNB',
    ]);
    final canAccessKbm = _hasRequiredRole(userRoles, [
      'Administrator',
      'KI',
      'Teacher',
    ]);
    final canAccessZakatFitrah = _hasRequiredRole(userRoles, [
      'Administrator',
      'KI',
      'KU',
      'Amil',
    ]);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF16213E),
              Color(0xFF1A1A2E),
              Color(0xFF0F0F1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header with enhanced styling
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F3460).withOpacity(0.3),
                        const Color(0xFF533483).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.waving_hand,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  StorageService.getUser()?.groupName ??
                                      'MBL 1',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    rolesText,
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choose a module to get started',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section Title
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3460),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Your Modules',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Module Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (canAccessBudget)
                        _buildModuleCard(
                          context: context,
                          title: 'Budget Manager',
                          description: 'Track your income and expenses',
                          icon: Icons.account_balance_wallet,
                          gradientColors: [
                            const Color(0xFF0F3460),
                            const Color(0xFF16213E),
                          ],
                          route: '/budget',
                        ),
                      if (canAccessAttendance)
                        _buildModuleCard(
                          context: context,
                          title: 'Attendance',
                          description: 'Track attendance for events',
                          icon: Icons.event_available,
                          gradientColors: [
                            const Color(0xFF533483),
                            const Color(0xFF3D2352),
                          ],
                          route: '/attendance',
                        ),
                      if (canAccessMembers)
                        _buildModuleCard(
                          context: context,
                          title: 'Member',
                          description: 'Manage members',
                          icon: Icons.people,
                          gradientColors: [
                            const Color(0xFF2E7D32),
                            const Color(0xFF1B5E20),
                          ],
                          route: '/members',
                        ),
                      if (canAccessKbm)
                        _buildModuleCard(
                          context: context,
                          title: 'KBM',
                          description: 'Manage teaching sessions',
                          icon: Icons.school,
                          gradientColors: [
                            const Color(0xFF6A1B9A),
                            const Color(0xFF4A148C),
                          ],
                          route: '/kbm',
                        ),
                      if (canAccessZakatFitrah)
                        _buildModuleCard(
                          context: context,
                          title: 'Zakat Fitrah',
                          description:
                              'Kelola data muzakki dan zakat fitrah 1447H',
                          icon: Icons.volunteer_activism,
                          gradientColors: [
                            const Color(0xFF066046),
                            const Color(0xFF044D36),
                          ],
                          route: '/zakat-fitrah',
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

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradientColors,
    String? route,
  }) {
    final isDisabled = route == null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDisabled
              ? [Colors.grey[800]!, Colors.grey[900]!]
              : gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
        border: Border.all(
          color: isDisabled ? Colors.grey[700]! : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
                  context.go(route);
                },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDisabled ? 0.05 : 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: isDisabled ? Colors.grey[600] : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey[600] : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: isDisabled ? Colors.grey[700] : Colors.grey[300],
                      fontSize: 10,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isDisabled) ...[
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
