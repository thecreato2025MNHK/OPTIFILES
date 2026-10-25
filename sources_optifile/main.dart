import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:storage_space/storage_space.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFileManagerApp());
}

class SmartFileManagerApp extends StatelessWidget {
  const SmartFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiFile Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const PermissionGateScreen(),
    );
  }
}

// ============================================================================
// MODÈLES DE DONNÉES & OPTIONS DE TRI
// ============================================================================

enum ItemCategory { photo, pdf, apk, installedApp }

enum SortOption {
  sizeDesc,
  sizeAsc,
  nameAsc,
  nameDesc,
  type,
}

class StorageItem {
  final String id;
  final String title;
  final String subtitle;
  final int sizeInBytes;
  final double sizeInMB;
  final ItemCategory category;
  final IconData icon;
  final Color color;
  final String? filePath;
  final String? assetId;
  final String? packageName;
  final Uint8List? thumbnailBytes;

  bool isPartOfDuplicateGroup;
  bool isDuplicateCopy;
  String? duplicateGroupKey;

  StorageItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sizeInBytes,
    required this.sizeInMB,
    required this.category,
    required this.icon,
    required this.color,
    this.filePath,
    this.assetId,
    this.packageName,
    this.thumbnailBytes,
    this.isPartOfDuplicateGroup = false,
    this.isDuplicateCopy = false,
    this.duplicateGroupKey,
  });

  bool get isBatchDeletable => category != ItemCategory.installedApp;

  String get categoryLabel {
    switch (category) {
      case ItemCategory.photo:
        return 'Photo';
      case ItemCategory.pdf:
        return 'PDF';
      case ItemCategory.apk:
        return 'APK';
      case ItemCategory.installedApp:
        return 'Application';
    }
  }

  String get formattedSize {
    if (sizeInMB <= 0.05) return 'Géré par l\'OS';
    return sizeInMB >= 1024
        ? '${(sizeInMB / 1024).toStringAsFixed(2)} Go'
        : '${sizeInMB.toStringAsFixed(1)} Mo';
  }
}

// ============================================================================
// ÉCRAN D'APPROBATION DES PERMISSIONS (CONSIGNE 8)
// ============================================================================

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _isGranted = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final PermissionState photoState = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
    final bool hasPhotoAccess = photoState.isAuth || photoState.hasAccess;

    bool hasStorageAccess = false;
    if (Platform.isAndroid) {
      hasStorageAccess = await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
    }

    if (mounted) {
      setState(() {
        _isGranted = hasPhotoAccess || hasStorageAccess;
        _isChecking = false;
      });
    }
  }

  Future<void> _requestRealPermissions() async {
    final PermissionState photoState =
        await PhotoManager.requestPermissionExtend();
    final bool hasPhotoAccess = photoState.isAuth || photoState.hasAccess;

    bool hasStorageAccess = false;
    if (Platform.isAndroid) {
      final statusManage = await Permission.manageExternalStorage.request();
      final statusStorage = await Permission.storage.request();
      hasStorageAccess = statusManage.isGranted || statusStorage.isGranted;
    }

    if (hasPhotoAccess || hasStorageAccess) {
      if (mounted) {
        setState(() {
          _isGranted = true;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Accès refusé. Veuillez autoriser l\'accès dans les réglages.',
            ),
            action: SnackBarAction(
              label: 'Réglages',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isGranted) {
      return const MainHomeScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_special_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Autorisation d\'accès au stockage',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pour analyser l\'espace disponible, afficher le graphique de répartition et supprimer les fichiers superflus, veuillez approuver l\'accès.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _requestRealPermissions,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text(
                    'Approuver l\'accès aux fichiers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// INTERFACE PRINCIPALE COMPLÈTE
// ============================================================================

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  static const MethodChannel _appSizeChannel =
      MethodChannel('optifile/app_size');

  int _currentIndex = 2; // Accueil sur "Résumé"
  bool _isMediumPreviewMode = false;

  String _searchQuery = '';
  String _activeFilter = 'Tous';
  SortOption _currentSort = SortOption.sizeDesc;

  String _appVersion = 'v1.0.0';

  bool _isLoading = true;
  String _freeSpaceText = '...';
  String _usedSpaceText = '...';
  String _totalSpaceText = '...';
  double _storageUsageRatio = 0.0;

  final List<StorageItem> _allItems = [];

  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  int _duplicateCopiesCount = 0;
  double _duplicateWastedMB = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _runFullDeviceScan();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (_) {}
  }

  Future<void> _runFullDeviceScan() async {
    setState(() {
      _isLoading = true;
      _selectedIds.clear();
      _isSelectionMode = false;
      _allItems.clear();
    });

    await Future.wait([
      _scanStorageSpace(),
      _scanPhotosInBatches(),
      _scanDocumentsAndApksSafely(),
      _scanInstalledAppsWithRealSize(),
    ]);

    _analyzeDuplicates();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _normalizeFileName(String rawTitle) {
    final String lower = rawTitle.trim().toLowerCase();
    final int dotIndex = lower.lastIndexOf('.');
    if (dotIndex <= 0) return lower;

    String namePart = lower.substring(0, dotIndex);
    final String extPart = lower.substring(dotIndex);

    namePart = namePart.replaceAll(
      RegExp(r'(\s*\(\d+\)|\s*-\s*copie|\s*_copy|_\d+)$'),
      '',
    );

    return '${namePart.trim()}$extPart';
  }

  void _analyzeDuplicates() {
    final Map<String, List<StorageItem>> groups = {};

    for (final item in _allItems) {
      item.isPartOfDuplicateGroup = false;
      item.isDuplicateCopy = false;
      item.duplicateGroupKey = null;

      if (!item.isBatchDeletable || item.sizeInBytes <= 0) continue;

      final String normalizedName = _normalizeFileName(item.title);
      final String key = '${normalizedName}_${item.sizeInBytes}';

      item.duplicateGroupKey = key;
      groups.putIfAbsent(key, () => []).add(item);
    }

    int copiesCount = 0;
    double wastedMB = 0.0;

    for (final entry in groups.entries) {
      final List<StorageItem> group = entry.value;
      if (group.length > 1) {
        for (int i = 0; i < group.length; i++) {
          group[i].isPartOfDuplicateGroup = true;
          if (i == 0) {
            group[i].isDuplicateCopy = false;
          } else {
            group[i].isDuplicateCopy = true;
            copiesCount++;
            wastedMB += group[i].sizeInMB;
          }
        }
      }
    }

    _duplicateCopiesCount = copiesCount;
    _duplicateWastedMB = wastedMB;
  }

  void _selectAllDuplicateCopies() {
    setState(() {
      _selectedIds.clear();
      for (final item in _allItems) {
        if (item.isDuplicateCopy) {
          _selectedIds.add(item.id);
        }
      }
      _activeFilter = 'Doublons';
      _isSelectionMode = _selectedIds.isNotEmpty;
    });

    if (_selectedIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_duplicateCopiesCount copie(s) cochée(s). Les originaux sont préservés.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String get _formattedDuplicateWastedSpace {
    return _duplicateWastedMB >= 1024
        ? '${(_duplicateWastedMB / 1024).toStringAsFixed(2)} Go'
        : '${_duplicateWastedMB.toStringAsFixed(1)} Mo';
  }

  Future<void> _scanStorageSpace() async {
    try {
      final StorageSpace space = await getStorageSpace(
        lowOnSpaceThreshold: 2 * 1024 * 1024 * 1024,
        fractionDigits: 1,
      );
      if (mounted) {
        setState(() {
          _freeSpaceText = space.freeSize;
          _usedSpaceText = space.usedSize;
          _totalSpaceText = space.totalSize;
          _storageUsageRatio = space.usageValue.clamp(0.0, 1.0);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _freeSpaceText = 'N/A';
          _usedSpaceText = 'N/A';
          _totalSpaceText = 'N/A';
        });
      }
    }
  }

  Future<void> _scanPhotosInBatches() async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) return;

      final List<AssetEntity> photos =
          await albums.first.getAssetListPaged(page: 0, size: 140);

      const int batchSize = 20;
      for (int i = 0; i < photos.length; i += batchSize) {
        final int end =
            (i + batchSize < photos.length) ? i + batchSize : photos.length;
        final List<AssetEntity> batch = photos.sublist(i, end);

        final List<StorageItem?> batchResults = await Future.wait(
          batch.map((asset) async {
            try {
              final File? file = await asset.originFile;
              if (file == null) return null;

              final FileStat stat = await file.stat();
              if (stat.size <= 0) return null;

              final double sizeMB = stat.size / (1024 * 1024);
              final Uint8List? thumb = await asset.thumbnailDataWithSize(
                const ThumbnailSize.square(150),
                quality: 75,
              );

              return StorageItem(
                id: 'photo_${asset.id}',
                title: asset.title ?? file.path.split('/').last,
                subtitle: 'Photo • ${asset.width}x${asset.height}',
                sizeInBytes: stat.size,
                sizeInMB: sizeMB,
                category: ItemCategory.photo,
                icon: Icons.image_rounded,
                color: const Color(0xFF0EA5E9),
                filePath: file.path,
                assetId: asset.id,
                thumbnailBytes: thumb,
              );
            } catch (_) {
              return null;
            }
          }),
        );

        _allItems.addAll(batchResults.whereType<StorageItem>());
      }
    } catch (e) {
      debugPrint('Erreur scan photos : $e');
    }
  }

  Future<void> _scanDocumentsAndApksSafely() async {
    final List<String> targetFolders = Platform.isAndroid
        ? [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Documents',
            '/storage/emulated/0/Bluetooth',
          ]
        : [
            Directory.systemTemp.parent.path,
          ];

    for (final folderPath in targetFolders) {
      await _scanDirectoryRecursive(
        Directory(folderPath),
        folderPath.split('/').last,
      );
    }
  }

  Future<void> _scanDirectoryRecursive(Directory dir, String rootLabel) async {
    if (!await dir.exists()) return;

    try {
      await for (final FileSystemEntity entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          final String folderName = entity.path.split('/').last;
          if (!folderName.startsWith('.')) {
            await _scanDirectoryRecursive(entity, rootLabel);
          }
        } else if (entity is File) {
          final String pathLower = entity.path.toLowerCase();
          if (pathLower.endsWith('.pdf') || pathLower.endsWith('.apk')) {
            final FileStat stat = await entity.stat();
            final double sizeMB = stat.size / (1024 * 1024);
            final String fileName = entity.path.split('/').last;
            final bool isPdf = pathLower.endsWith('.pdf');

            _allItems.add(
              StorageItem(
                id: 'file_${entity.path}',
                title: fileName,
                subtitle: isPdf
                    ? 'Document PDF • $rootLabel'
                    : 'Application à installer (APK) • $rootLabel',
                sizeInBytes: stat.size,
                sizeInMB: sizeMB,
                category: isPdf ? ItemCategory.pdf : ItemCategory.apk,
                icon: isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.install_mobile_rounded,
                color: isPdf
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                filePath: entity.path,
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _scanInstalledAppsWithRealSize() async {
    if (!Platform.isAndroid) return;

    try {
      final List<AppInfo> apps =
          await InstalledApps.getInstalledApps(true, true);

      final List<StorageItem> appItems = await Future.wait(
        apps.map((app) async {
          double realAppSizeMB = 0.0;
          try {
            final double? sizeFromNative =
                await _appSizeChannel.invokeMethod<double>(
              'getAppSize',
              {'packageName': app.packageName},
            );
            if (sizeFromNative != null) {
              realAppSizeMB = sizeFromNative;
            }
          } catch (_) {}

          return StorageItem(
            id: 'app_${app.packageName}',
            title: app.name,
            subtitle: 'App installée • v${app.versionName}',
            sizeInBytes: (realAppSizeMB * 1024 * 1024).toInt(),
            sizeInMB: realAppSizeMB,
            category: ItemCategory.installedApp,
            icon: Icons.android_rounded,
            color: const Color(0xFF8B5CF6),
            packageName: app.packageName,
            thumbnailBytes: app.icon,
          );
        }),
      );

      _allItems.addAll(appItems);
    } catch (e) {
      debugPrint('Erreur scan applications : $e');
    }
  }

  void _toggleItemSelection(StorageItem item) {
    if (!item.isBatchDeletable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les applications installées se désinstallent individuellement.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(item.id);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _toggleSelectAllVisible(List<StorageItem> currentVisibleItems) {
    final List<StorageItem> targetItems = _activeFilter == 'Doublons'
        ? currentVisibleItems.where((i) => i.isDuplicateCopy).toList()
        : currentVisibleItems.where((i) => i.isBatchDeletable).toList();

    if (targetItems.isEmpty) return;

    final bool allSelected =
        targetItems.every((item) => _selectedIds.contains(item.id));

    setState(() {
      if (allSelected) {
        for (final item in targetItems) {
          _selectedIds.remove(item.id);
        }
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        for (final item in targetItems) {
          _selectedIds.add(item.id);
        }
        _isSelectionMode = true;
      }
    });
  }

  double get _totalSelectedSizeMB {
    double total = 0.0;
    for (final item in _allItems) {
      if (_selectedIds.contains(item.id)) {
        total += item.sizeInMB;
      }
    }
    return total;
  }

  String get _formattedSelectedSize {
    final double mb = _totalSelectedSizeMB;
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(2)} Go'
        : '${mb.toStringAsFixed(1)} Mo';
  }

  Future<void> _confirmAndDeleteSelectedBatch() async {
    if (_selectedIds.isEmpty) return;

    final List<StorageItem> selectedItems =
        _allItems.where((item) => _selectedIds.contains(item.id)).toList();

    final String sizeToFree = _formattedSelectedSize;
    final int count = selectedItems.length;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer $count élément(s) ?'),
        content: Text(
          'Vous allez supprimer définitivement $count fichier(s) et libérer $sizeToFree sur votre téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final Set<String> successfullyDeletedIds = {};

    try {
      final List<StorageItem> selectedPhotos = selectedItems
          .where(
              (i) => i.category == ItemCategory.photo && i.assetId != null)
          .toList();

      if (selectedPhotos.isNotEmpty) {
        final List<String> assetIdsToDelete =
            selectedPhotos.map((i) => i.assetId!).toList();
        final List<String> deletedAssetIds =
            await PhotoManager.editor.deleteWithIds(assetIdsToDelete);

        for (final photoItem in selectedPhotos) {
          if (deletedAssetIds.contains(photoItem.assetId)) {
            successfullyDeletedIds.add(photoItem.id);
          }
        }
      }

      final List<StorageItem> selectedFiles = selectedItems
          .where(
              (i) => i.category != ItemCategory.photo && i.filePath != null)
          .toList();

      await Future.wait(
        selectedFiles.map((fileItem) async {
          try {
            final file = File(fileItem.filePath!);
            if (await file.exists()) {
              await file.delete();
              successfullyDeletedIds.add(fileItem.id);
            }
          } catch (_) {}
        }),
      );

      if (mounted) {
        setState(() {
          _allItems.removeWhere(
              (element) => successfullyDeletedIds.contains(element.id));
          _selectedIds.clear();
          _isSelectionMode = false;
          _analyzeDuplicates();
          if (_activeFilter == 'Doublons' && _duplicateCopiesCount == 0) {
            _activeFilter = 'Tous';
          }
        });

        await _scanStorageSpace();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${successfullyDeletedIds.length} fichier(s) supprimé(s) ($sizeToFree libérés).',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e')),
        );
      }
    }
  }

  Future<void> _handleItemTap(StorageItem item) async {
    if (_isSelectionMode) {
      _toggleItemSelection(item);
      return;
    }

    if (item.category == ItemCategory.installedApp &&
        item.packageName != null) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.launch_rounded),
                title: Text('Ouvrir ${item.title}'),
                onTap: () {
                  Navigator.pop(context);
                  InstalledApps.startApp(item.packageName!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_applications_rounded),
                title: const Text('Voir les détails système / Vider le cache'),
                onTap: () {
                  Navigator.pop(context);
                  InstalledApps.openSettings(item.packageName!);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Désinstaller l\'application',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await InstalledApps.uninstallApp(item.packageName!);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (item.filePath != null) {
      final result = await OpenFilex.open(item.filePath!);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir le fichier : ${result.message}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteSingleItem(StorageItem item) async {
    if (item.category == ItemCategory.installedApp &&
        item.packageName != null) {
      await InstalledApps.uninstallApp(item.packageName!);
      return;
    }

    setState(() {
      _selectedIds.clear();
      _selectedIds.add(item.id);
    });
    await _confirmAndDeleteSelectedBatch();
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.sizeDesc:
        return 'Taille (Plus lourd)';
      case SortOption.sizeAsc:
        return 'Taille (Plus léger)';
      case SortOption.nameAsc:
        return 'Nom (A → Z)';
      case SortOption.nameDesc:
        return 'Nom (Z → A)';
      case SortOption.type:
        return 'Par type de fichier';
    }
  }

  int _compareBySelectedSort(StorageItem a, StorageItem b) {
    switch (_currentSort) {
      case SortOption.sizeDesc:
        return b.sizeInBytes.compareTo(a.sizeInBytes);
      case SortOption.sizeAsc:
        return a.sizeInBytes.compareTo(b.sizeInBytes);
      case SortOption.nameAsc:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SortOption.nameDesc:
        return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      case SortOption.type:
        final int typeCompare = a.category.index.compareTo(b.category.index);
        if (typeCompare != 0) return typeCompare;
        return b.sizeInBytes.compareTo(a.sizeInBytes);
    }
  }

  List<StorageItem> _getFilteredItems(List<StorageItem> sourceList) {
    final String query = _searchQuery.trim().toLowerCase();

    final List<StorageItem> filtered = sourceList.where((item) {
      final bool matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      switch (_activeFilter) {
        case 'Doublons':
          return item.isPartOfDuplicateGroup;
        case 'Photos':
          return item.category == ItemCategory.photo;
        case 'PDF':
          return item.category == ItemCategory.pdf;
        case 'APK à installer':
          return item.category == ItemCategory.apk;
        case 'Plus de 50 Mo':
          return item.sizeInMB >= 50;
        default:
          return true;
      }
    }).toList();

    if (_activeFilter == 'Doublons') {
      filtered.sort((a, b) {
        if (a.duplicateGroupKey == b.duplicateGroupKey) {
          return (a.isDuplicateCopy ? 1 : 0)
              .compareTo(b.isDuplicateCopy ? 1 : 0);
        }
        final int primaryCompare = _compareBySelectedSort(a, b);
        if (primaryCompare != 0) return primaryCompare;
        return (a.duplicateGroupKey ?? '')
            .compareTo(b.duplicateGroupKey ?? '');
      });
    } else {
      filtered.sort(_compareBySelectedSort);
    }

    return filtered;
  }

  List<StorageItem> _getCurrentTabActiveList() {
    if (_currentIndex == 0) {
      return _getFilteredItems(_allItems
          .where((item) =>
              item.category == ItemCategory.photo ||
              item.category == ItemCategory.pdf ||
              item.category == ItemCategory.apk)
          .toList());
    } else if (_currentIndex == 1) {
      return _getFilteredItems(_allItems
          .where((item) =>
              item.category == ItemCategory.installedApp ||
              item.category == ItemCategory.apk)
          .toList());
    }
    return _getFilteredItems(_allItems);
  }

  Widget _buildActiveTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildFilesTab();
      case 1:
        return _buildAppsTab();
      case 2:
      default:
        return _buildSummaryTab();
    }
  }

  Widget _buildSortPopupMenu({Widget? customChild}) {
    return PopupMenuButton<SortOption>(
      tooltip: 'Trier les fichiers',
      initialValue: _currentSort,
      onSelected: (SortOption selectedSort) {
        setState(() {
          _currentSort = selectedSort;
        });
      },
      itemBuilder: (BuildContext context) => [
        _buildSortMenuItem(
          SortOption.sizeDesc,
          'Taille : Plus lourd d\'abord',
          Icons.arrow_downward_rounded,
        ),
        _buildSortMenuItem(
          SortOption.sizeAsc,
          'Taille : Plus léger d\'abord',
          Icons.arrow_upward_rounded,
        ),
        const PopupMenuDivider(),
        _buildSortMenuItem(
          SortOption.nameAsc,
          'Ordre alphabétique (A → Z)',
          Icons.sort_by_alpha_rounded,
        ),
        _buildSortMenuItem(
          SortOption.nameDesc,
          'Ordre alphabétique (Z → A)',
          Icons.sort_by_alpha_rounded,
        ),
        const PopupMenuDivider(),
        _buildSortMenuItem(
          SortOption.type,
          'Par type (Photos, PDF, APK, Apps)',
          Icons.category_rounded,
        ),
      ],
      child: customChild ??
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.sort_rounded),
          ),
    );
  }

  PopupMenuItem<SortOption> _buildSortMenuItem(
    SortOption value,
    String text,
    IconData icon,
  ) {
    final bool isSelected = _currentSort == value;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return PopupMenuItem<SortOption>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? primaryColor : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: primaryColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<StorageItem> currentVisibleList = _getCurrentTabActiveList();

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Quitter la sélection',
                onPressed: _exitSelectionMode,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedIds.length} sélectionné(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Espace à libérer : $_formattedSelectedSize',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Tout cocher / Tout décocher',
                  onPressed: () =>
                      _toggleSelectAllVisible(currentVisibleList),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                  tooltip: 'Supprimer la sélection',
                  onPressed: _confirmAndDeleteSelectedBatch,
                ),
              ],
            )
          : AppBar(
              elevation: 0,
              title: const Text(
                'OptiFile',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              actions: [
                _buildSortPopupMenu(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Mode sélection multiple',
                ),
                IconButton(
                  onPressed: _runFullDeviceScan,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser le scan',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.view_list_rounded, size: 18),
                        tooltip: 'Liste',
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                        tooltip: 'Visualisation Moyenne',
                      ),
                    ],
                    selected: {_isMediumPreviewMode},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isMediumPreviewMode = newSelection.first;
                      });
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchAndFilterHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Analyse du stockage et des catégories...',
                            ),
                          ],
                        ),
                      )
                    : _buildActiveTabContent(),
              ),
            ],
          ),

          if (_isSelectionMode && _selectedIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 90,
              bottom: 12,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _confirmAndDeleteSelectedBatch,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(
                  'Supprimer (${_selectedIds.length}) • $_formattedSelectedSize',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          Positioned(
            right: 14,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Fichiers',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Résumé',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader() {
    final filters = [
      'Tous',
      'Doublons',
      'Photos',
      'PDF',
      'APK à installer',
      'Plus de 50 Mo',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Rechercher une photo, un PDF, un doublon...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = _activeFilter == filter;
                final String chipLabel =
                    (filter == 'Doublons' && _duplicateCopiesCount > 0)
                        ? 'Doublons ($_duplicateCopiesCount)'
                        : filter;

                return FilterChip(
                  avatar: filter == 'Doublons'
                      ? Icon(
                          Icons.copy_all_rounded,
                          size: 16,
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                              : Colors.orange,
                        )
                      : null,
                  label: Text(chipLabel),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _activeFilter = filter),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtre : $_activeFilter',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              _buildSortPopupMenu(
                customChild: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tri : ${_getSortLabel(_currentSort)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateBannerCard() {
    if (_duplicateCopiesCount <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_delete_rounded,
                color: Colors.amber.shade800,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_duplicateCopiesCount doublon(s) détecté(s) ($_formattedDuplicateWastedSpace gaspillés)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Même nom et même taille exacte. Le bouton ci-dessous coche uniquement les copies et conserve vos originaux intacts.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _selectAllDuplicateCopies,
              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
              label: Text(
                'Cocher les $_duplicateCopiesCount copie(s) à nettoyer',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // GRAPHIQUE DE RÉPARTITION COLORÉ DES CATÉGORIES
  // ==========================================================================

  Widget _buildStorageCategoryBreakdownCard() {
    double photosMB = 0;
    double pdfMB = 0;
    double apkMB = 0;
    double appsMB = 0;

    for (final item in _allItems) {
      if (item.category == ItemCategory.photo) {
        photosMB += item.sizeInMB;
      } else if (item.category == ItemCategory.pdf) {
        pdfMB += item.sizeInMB;
      } else if (item.category == ItemCategory.apk) {
        apkMB += item.sizeInMB;
      } else if (item.category == ItemCategory.installedApp) {
        appsMB += item.sizeInMB;
      }
    }

    final double totalScannedMB = photosMB + pdfMB + apkMB + appsMB;
    if (totalScannedMB <= 0) return const SizedBox.shrink();

    final double pPhotos = photosMB / totalScannedMB;
    final double pPdf = pdfMB / totalScannedMB;
    final double pApk = apkMB / totalScannedMB;
    final double pApps = appsMB / totalScannedMB;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition par catégorie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (pPhotos > 0)
                    Expanded(
                      flex: (pPhotos * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF0EA5E9)),
                    ),
                  if (pPdf > 0)
                    Expanded(
                      flex: (pPdf * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (pApk > 0)
                    Expanded(
                      flex: (pApk * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (pApps > 0)
                    Expanded(
                      flex: (pApps * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildLegendItem(
                'Photos',
                photosMB,
                const Color(0xFF0EA5E9),
                Icons.image_rounded,
              ),
              _buildLegendItem(
                'PDF',
                pdfMB,
                const Color(0xFFEF4444),
                Icons.picture_as_pdf_rounded,
              ),
              _buildLegendItem(
                'APK',
                apkMB,
                const Color(0xFF10B981),
                Icons.install_mobile_rounded,
              ),
              _buildLegendItem(
                'Applications',
                appsMB,
                const Color(0xFF8B5CF6),
                Icons.android_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      String label, double sizeMB, Color color, IconData icon) {
    final String formatted = sizeMB >= 1024
        ? '${(sizeMB / 1024).toStringAsFixed(2)} Go'
        : '${sizeMB.toStringAsFixed(1)} Mo';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label ($formatted)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ONGLET 2 : RÉSUMÉ (ACCUEIL PAR DÉFAUT)
  Widget _buildSummaryTab() {
    final sortedAll = _getFilteredItems(_allItems);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 65),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Espace de stockage',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_freeSpaceText libres',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _storageUsageRatio,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$_usedSpaceText utilisés sur $_totalSpaceText',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildStorageCategoryBreakdownCard(),

        _buildDuplicateBannerCard(),

        Text(
          _activeFilter == 'Doublons'
              ? 'Groupes de fichiers en double'
              : 'Tous les éléments (${sortedAll.length})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _activeFilter == 'Doublons'
              ? 'Chaque "Original" est suivi de ses "Copies" redondantes'
              : 'Classés selon : ${_getSortLabel(_currentSort)}',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        _buildAdaptiveCollectionView(sortedAll, shrinkWrap: true),
      ],
    );
  }

  // ONGLET 0 : FICHIERS
  Widget _buildFilesTab() {
    final filesOnly = _allItems
        .where((item) =>
            item.category == ItemCategory.photo ||
            item.category == ItemCategory.pdf ||
            item.category == ItemCategory.apk)
        .toList();

    final filteredFiles = _getFilteredItems(filesOnly);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              'Photos, PDF & Fichiers (${filteredFiles.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildAdaptiveCollectionView(filteredFiles)),
        ],
      ),
    );
  }

  // ONGLET 1 : APPLICATIONS
  Widget _buildAppsTab() {
    final appsOnly = _allItems
        .where((item) =>
            item.category == ItemCategory.installedApp ||
            item.category == ItemCategory.apk)
        .toList();

    final filteredApps = _getFilteredItems(appsOnly);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              'Applications & Installateurs (${filteredApps.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildAdaptiveCollectionView(filteredApps)),
        ],
      ),
    );
  }

  Widget _buildDuplicateStatusBadge(StorageItem item) {
    if (!item.isPartOfDuplicateGroup) return const SizedBox.shrink();

    final bool isCopy = item.isDuplicateCopy;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCopy
            ? Colors.orange.withValues(alpha: 0.18)
            : Colors.teal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCopy ? 'DOUBLON (COPIE)' : 'ORIGINAL À GARDER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isCopy ? Colors.deepOrange : Colors.teal.shade700,
        ),
      ),
    );
  }

  Widget _buildAdaptiveCollectionView(
    List<StorageItem> items, {
    bool shrinkWrap = false,
  }) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Aucun fichier trouvé pour ce filtre.'),
        ),
      );
    }

    final Color primaryColor = Theme.of(context).colorScheme.primary;

    if (_isMediumPreviewMode) {
      return GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.only(bottom: 70),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isSelected = _selectedIds.contains(item.id);

          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(color: primaryColor, width: 2.5)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _handleItemTap(item),
              onLongPress: () => _toggleItemSelection(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.thumbnailBytes != null
                            ? Image.memory(
                                item.thumbnailBytes!,
                                fit: item.category == ItemCategory.installedApp
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                              )
                            : Container(
                                color: item.color.withValues(alpha: 0.12),
                                child: Icon(
                                  item.icon,
                                  size: 48,
                                  color: item.color,
                                ),
                              ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _isSelectionMode
                              ? (item.isBatchDeletable
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          _toggleItemSelection(item),
                                    )
                                  : const SizedBox.shrink())
                              : IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _confirmAndDeleteSingleItem(item),
                                ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.categoryLabel} • ${item.formattedSize}',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        _buildDuplicateStatusBadge(item),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.only(bottom: 70),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isSelected = _selectedIds.contains(item.id);

        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.45)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: primaryColor, width: 1.5)
                : null,
          ),
          child: ListTile(
            onTap: () => _handleItemTap(item),
            onLongPress: () => _toggleItemSelection(item),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 50,
                height: 50,
                child: item.thumbnailBytes != null
                    ? Image.memory(
                        item.thumbnailBytes!,
                        fit: item.category == ItemCategory.installedApp
                            ? BoxFit.contain
                            : BoxFit.cover,
                      )
                    : Container(
                        color: item.color.withValues(alpha: 0.12),
                        child: Icon(item.icon, color: item.color, size: 28),
                      ),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.subtitle} • ${item.formattedSize}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                _buildDuplicateStatusBadge(item),
              ],
            ),
            trailing: _isSelectionMode
                ? (item.isBatchDeletable
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleItemSelection(item),
                      )
                    : const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: Colors.grey,
                      ))
                : IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Supprimer',
                    onPressed: () => _confirmAndDeleteSingleItem(item),
                  ),
          ),
        );
      },
    );
  }
}
