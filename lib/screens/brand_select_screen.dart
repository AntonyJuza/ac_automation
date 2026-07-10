import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/cloud_ir_service.dart';
import 'package:go_router/go_router.dart';

/// AC brand data with icon mapping.
class _ACBrand {
  final String name;
  final IconData icon;

  const _ACBrand(this.name, this.icon);
}

/// Pre-defined popular AC brands.
const List<_ACBrand> _popularBrands = [
  _ACBrand('Daikin', Icons.ac_unit),
  _ACBrand('Voltas', Icons.ac_unit),
  _ACBrand('LG', Icons.ac_unit),
  _ACBrand('Samsung', Icons.ac_unit),
  _ACBrand('Blue Star', Icons.ac_unit),
  _ACBrand('Lloyd', Icons.ac_unit),
  _ACBrand('Carrier', Icons.ac_unit),
  _ACBrand('Hitachi', Icons.ac_unit),
  _ACBrand('Panasonic', Icons.ac_unit),
  _ACBrand('Godrej', Icons.ac_unit),
  _ACBrand('Whirlpool', Icons.ac_unit),
  _ACBrand('Haier', Icons.ac_unit),
  _ACBrand('O General', Icons.ac_unit),
  _ACBrand('Mitsubishi', Icons.ac_unit),
  _ACBrand('Toshiba', Icons.ac_unit),
  _ACBrand('IFB', Icons.ac_unit),
];

class BrandSelectScreen extends StatefulWidget {
  const BrandSelectScreen({super.key});

  @override
  State<BrandSelectScreen> createState() => _BrandSelectScreenState();
}

class _BrandSelectScreenState extends State<BrandSelectScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<String> _cloudBrands = [];
  bool _isLoading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadCloudBrands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudBrands() async {
    final brands = await CloudIRService.fetchBrands();
    if (mounted) {
      setState(() {
        _cloudBrands = brands;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  List<_ACBrand> get _filteredBrands {
    if (_searchQuery.isEmpty) return _popularBrands;
    return _popularBrands
        .where(
          (b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  bool _hasCloudProfiles(String brandName) {
    return _cloudBrands.any(
      (b) => b.toLowerCase() == brandName.toLowerCase(),
    );
  }

  void _onBrandSelected(String brand) {
    final hasCloud = _hasCloudProfiles(brand);

    showDialog(
      context: context,
      builder: (dialogCtx) => _MethodChoiceDialog(
        brand: brand,
        hasCloudProfiles: hasCloud,
        onRecordOwn: () {
          Navigator.pop(dialogCtx);
          context.push(
            '/learn',
            extra: {'name': '', 'brand': brand, 'model': null},
          );
        },
        onUseCloud: () {
          Navigator.pop(dialogCtx);
          context.push(
            '/cloud-test',
            extra: {'brand': brand},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBrands;

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: const Text('Select AC Brand'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.primaryBackground,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search brand...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Cloud profiles badge
          if (!_isLoading && _cloudBrands.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.statusGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_cloudBrands.length} brands with cloud presets',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Brand Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBrand,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color:
                                  AppColors.textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No brands match "$_searchQuery"',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeController,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final brand = filtered[index];
                            final hasCloud = _hasCloudProfiles(brand.name);
                            return _BrandTile(
                              brand: brand,
                              hasCloudProfiles: hasCloud,
                              onTap: () => _onBrandSelected(brand.name),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Individual brand tile in the grid.
class _BrandTile extends StatelessWidget {
  final _ACBrand brand;
  final bool hasCloudProfiles;
  final VoidCallback onTap;

  const _BrandTile({
    required this.brand,
    required this.hasCloudProfiles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: hasCloudProfiles
              ? Border.all(
                  color: AppColors.primaryBrand.withValues(alpha: 0.15),
                  width: 1.5,
                )
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hasCloudProfiles
                          ? AppColors.primaryBrand.withValues(alpha: 0.08)
                          : AppColors.secondaryBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      brand.icon,
                      size: 26,
                      color: hasCloudProfiles
                          ? AppColors.primaryBrand
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    brand.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasCloudProfiles
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Cloud badge
            if (hasCloudProfiles)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_rounded,
                    size: 12,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to choose between cloud presets and manual recording.
class _MethodChoiceDialog extends StatelessWidget {
  final String brand;
  final bool hasCloudProfiles;
  final VoidCallback onRecordOwn;
  final VoidCallback onUseCloud;

  const _MethodChoiceDialog({
    required this.brand,
    required this.hasCloudProfiles,
    required this.onRecordOwn,
    required this.onUseCloud,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brand icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ac_unit,
                size: 36,
                color: AppColors.primaryBrand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              brand,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'How would you like to set up\nyour remote?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Cloud presets option
            _MethodOption(
              icon: Icons.cloud_download_rounded,
              title: 'Try Cloud Presets',
              subtitle: hasCloudProfiles
                  ? 'Test pre-recorded IR patterns'
                  : 'No presets available for this brand',
              enabled: hasCloudProfiles,
              isPrimary: true,
              onTap: hasCloudProfiles ? onUseCloud : null,
            ),
            const SizedBox(height: 12),

            // Record own option
            _MethodOption(
              icon: Icons.settings_remote_rounded,
              title: 'Record Your Own',
              subtitle: 'Use your AC remote to teach',
              enabled: true,
              isPrimary: false,
              onTap: onRecordOwn,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _MethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.isPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary && enabled
              ? AppColors.primaryBrand
              : enabled
                  ? AppColors.secondaryBackground
                  : AppColors.secondaryBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: !isPrimary && enabled
              ? Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary && enabled
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primaryBrand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isPrimary && enabled
                    ? Colors.white
                    : enabled
                        ? AppColors.primaryBrand
                        : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isPrimary && enabled
                          ? Colors.white
                          : enabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPrimary && enabled
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isPrimary && enabled
                  ? Colors.white.withValues(alpha: 0.6)
                  : enabled
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
