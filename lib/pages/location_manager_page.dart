import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:untitled1/map/location_picker.dart';
import 'package:untitled1/services/location_context_service.dart';

class LocationManagerPage extends StatefulWidget {
  const LocationManagerPage({super.key});

  @override
  State<LocationManagerPage> createState() => _LocationManagerPageState();
}

class _LocationManagerPageState extends State<LocationManagerPage> {
  bool _isLoading = true;
  String _activeId = AppLocation.currentId;
  List<AppLocation> _saved = [];
  AppLocation? _currentDeviceLocation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final activeId = await LocationContextService.getActiveLocationId();
    final saved = await LocationContextService.getSavedLocations();
    final currentDeviceLocation =
        await LocationContextService.getCurrentDeviceLocation();

    if (!mounted) return;
    setState(() {
      _activeId = activeId;
      _saved = saved;
      _currentDeviceLocation = currentDeviceLocation;
      _isLoading = false;
    });
  }

  Future<void> _select(String id) async {
    await LocationContextService.setActiveLocationId(id);
    if (!mounted) return;
    setState(() => _activeId = id);
    Navigator.pop(context, true);
  }

  Future<void> _delete(AppLocation location) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Remove "${location.label}" from saved locations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await LocationContextService.deleteLocation(location.id);
      await _load();
    }
  }

  Future<void> _openEditDialog(AppLocation location) async {
    final nameController = TextEditingController(text: location.label);
    LatLng? selectedPoint = LatLng(location.latitude, location.longitude);
    String selectedSource =
        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    bool isSaving = false;
    bool showValidation = false;

    Future<void> fillFromCurrent(StateSetter setDialogState) async {
      final current = await LocationContextService.getCurrentDeviceLocation();
      if (current == null) return;
      setDialogState(() {
        selectedPoint = LatLng(current.latitude, current.longitude);
        selectedSource =
            'Current: ${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)}';
      });
    }

    Future<void> pickFromMap(StateSetter setDialogState) async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPicker(initialCenter: selectedPoint),
        ),
      );
      if (result is LatLng) {
        setDialogState(() {
          selectedPoint = result;
          selectedSource =
              'Map: ${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
        });
      }
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasName = nameController.text.trim().isNotEmpty;
            final hasPoint = selectedPoint != null;
            final canSave = hasName && hasPoint && !isSaving;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.edit_location_alt_outlined,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(width: 8),
                  Text('Edit Location'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Home, Work, Parents...',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose coordinates',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => fillFromCurrent(setDialogState),
                            icon: const Icon(Icons.my_location),
                            label: const Text('Current'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickFromMap(setDialogState),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Choose from Map'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedSource,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (showValidation && !canSave) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Please enter a name and choose coordinates.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSave
                      ? () async {
                          setDialogState(() {
                            isSaving = true;
                            showValidation = false;
                          });
                          await LocationContextService.saveLocation(
                            id: location.id,
                            label: nameController.text.trim(),
                            latitude: selectedPoint!.latitude,
                            longitude: selectedPoint!.longitude,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, true);
                        }
                      : () {
                          setDialogState(() {
                            showValidation = true;
                          });
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      await _load();
    }
  }

  Future<void> _openAddDialog() async {
    final nameController = TextEditingController();
    LatLng? selectedPoint;
    String selectedSource = 'No coordinates selected yet';
    bool isSaving = false;
    bool showValidation = false;

    Future<void> fillFromCurrent(StateSetter setDialogState) async {
      final current = await LocationContextService.getCurrentDeviceLocation();
      if (current == null) return;
      setDialogState(() {
        selectedPoint = LatLng(current.latitude, current.longitude);
        selectedSource =
            'Current: ${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)}';
      });
    }

    Future<void> pickFromMap(StateSetter setDialogState) async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPicker(initialCenter: selectedPoint),
        ),
      );
      if (result is LatLng) {
        setDialogState(() {
          selectedPoint = result;
          selectedSource =
              'Map: ${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
        });
      }
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasName = nameController.text.trim().isNotEmpty;
            final hasPoint = selectedPoint != null;
            final canSave = hasName && hasPoint && !isSaving;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.add_location_alt_outlined,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(width: 8),
                  Text('Add New Location'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Home, Work, Parents...',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose coordinates',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => fillFromCurrent(setDialogState),
                            icon: const Icon(Icons.my_location),
                            label: const Text('Current'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickFromMap(setDialogState),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Choose from Map'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedSource,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (showValidation && !canSave) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Please enter a name and choose coordinates.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSave
                      ? () async {
                          setDialogState(() {
                            isSaving = true;
                            showValidation = false;
                          });
                          final label = nameController.text.trim();

                          await LocationContextService.saveLocation(
                            label: label,
                            latitude: selectedPoint!.latitude,
                            longitude: selectedPoint!.longitude,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, true);
                        }
                      : () {
                          setDialogState(() {
                            showValidation = true;
                          });
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Location'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Locations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Location'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                Text(
                  'Distance Source',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLocationCard(
                  icon: Icons.my_location,
                  title: 'Current Location',
                  subtitle: _currentDeviceLocation == null
                      ? 'Unavailable'
                      : '${_currentDeviceLocation!.latitude.toStringAsFixed(5)}, ${_currentDeviceLocation!.longitude.toStringAsFixed(5)}',
                  isActive: _activeId == AppLocation.currentId,
                  onTap: () => _select(AppLocation.currentId),
                ),
                const SizedBox(height: 18),
                Text(
                  'Saved Locations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (_saved.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          color: Color(0xFF94A3B8),
                          size: 34,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No saved locations yet.\nTap Add Location to save Home, Work, etc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else
                  ..._saved.map((location) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildLocationCard(
                        icon: Icons.place_outlined,
                        title: location.label,
                        subtitle:
                            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                        isActive: _activeId == location.id,
                        onTap: () => _select(location.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: const Color(0xFF1976D2),
                              onPressed: () => _openEditDialog(location),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red.shade400,
                              onPressed: () => _delete(location),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFEEF2FF),
              child: Icon(icon, size: 18, color: const Color(0xFF1976D2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Color(0xFF0369A1),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            Radio<bool>(
              value: true,
              groupValue: isActive,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }
}
