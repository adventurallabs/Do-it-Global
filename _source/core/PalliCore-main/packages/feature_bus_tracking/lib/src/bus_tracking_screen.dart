import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';

import 'bus_bloc.dart';

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final MapController _mapController = MapController();
  String? _focusedBusId;
  static const _school = LatLng(10.7905, 78.7047);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          BusBloc(RepositoryProvider.of<BusRepository>(context))
            ..add(LoadBuses())
            ..add(SubscribeToLocations()),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Bus Tracking'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/admin'),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded),
                onPressed: () => _showAddBusDialog(context),
              ),
            ],
          ),
          body: SafeArea(
            child: BlocBuilder<BusBloc, BusState>(
            builder: (context, state) {
              if (state is BusLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is BusLoaded) {
                if (state.buses.isEmpty) {
                  return EmptyState(
                    icon: Icons.directions_bus_rounded,
                    title: 'No Buses Added',
                    subtitle: 'Add a bus to start tracking',
                    actionLabel: 'Add Bus',
                    onAction: () => _showAddBusDialog(context),
                  );
                }
                return Column(
                  children: [
                    // Map
                    Expanded(
                      flex: 3,
                      child: SoftSurface(
                        depth: SoftDepth.one,
                        margin: const EdgeInsets.all(12),
                        borderRadius: BorderRadius.circular(22),
                        padding: EdgeInsets.zero,
                        fill: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: const MapOptions(
                              initialCenter: _school,
                              initialZoom: 12.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.pallicore.app',
                              ),
                              PolylineLayer(
                                polylines: _focusedPolylines(state.buses),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _school,
                                    width: 44,
                                    height: 44,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  ...state.buses
                                      .where(
                                        (b) =>
                                            b.latitude != null &&
                                            b.longitude != null,
                                      )
                                      .map(
                                        (b) => Marker(
                                          point: LatLng(
                                            b.latitude!,
                                            b.longitude!,
                                          ),
                                          width: 48,
                                          height: 48,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.busCard,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.directions_bus_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bus list
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: state.buses.length,
                        itemBuilder: (context, index) {
                          final bus = state.buses[index];
                          return AnimatedListItem(
                            index: index,
                            child: _BusCard(
                              bus: bus,
                              onTap: () {
                                setState(() => _focusedBusId = bus.id);
                                if (bus.latitude != null &&
                                    bus.longitude != null) {
                                  _mapController.move(
                                    LatLng(bus.latitude!, bus.longitude!),
                                    15.0,
                                  );
                                }
                              },
                              onEdit: () =>
                                  _showAddBusDialog(context, bus: bus),
                              onDelete: () => _confirmDelete(context, bus),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              if (state is BusError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Bus data could not be loaded\n${state.message}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            ),
          ),
        ),
      ),
    );
  }

  List<Polyline> _focusedPolylines(List<Bus> buses) {
    Bus? bus;
    for (final item in buses) {
      if (item.id == _focusedBusId) bus = item;
    }
    if (bus?.latitude == null || bus?.longitude == null) return const [];
    return [
      Polyline(
        points: [_school, LatLng(bus!.latitude!, bus.longitude!)],
        color: AppColors.busCard,
        strokeWidth: 3,
      ),
    ];
  }

  void _showAddBusDialog(BuildContext context, {Bus? bus}) {
    showDialog(
      context: context,
      builder: (dialogContext) => BusEditDialog(
        bus: bus,
        onSave: (next) {
          if (bus == null) {
            context.read<BusBloc>().add(AddBus(next));
          } else {
            context.read<BusBloc>().add(UpdateBus(next));
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Bus bus) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Delete Bus',
        content:
            'This will permanently remove bus "${bus.busNumber}" and stop tracking.',
        onConfirm: () {
          context.read<BusBloc>().add(DeleteBus(bus.id));
        },
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final Bus bus;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BusCard({
    required this.bus,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.busCard.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: AppColors.busCard,
            size: 22,
          ),
        ),
        title: Text(
          bus.busNumber,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${bus.driverName} · ${bus.driverContact}',
          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bus.latitude != null)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_rounded,
                color: AppColors.error,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class BusEditDialog extends StatefulWidget {
  final Function(Bus) onSave;
  final Bus? bus;
  const BusEditDialog({super.key, required this.onSave, this.bus});

  @override
  State<BusEditDialog> createState() => _BusEditDialogState();
}

class _BusEditDialogState extends State<BusEditDialog> {
  late final TextEditingController _busNumberController;
  late final TextEditingController _driverNameController;
  late final TextEditingController _driverContactController;

  @override
  void initState() {
    super.initState();
    _busNumberController = TextEditingController(
      text: widget.bus?.busNumber ?? '',
    );
    _driverNameController = TextEditingController(
      text: widget.bus?.driverName ?? '',
    );
    _driverContactController = TextEditingController(
      text: widget.bus?.driverContact ?? '',
    );
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bus == null ? 'Add Bus' : 'Edit Bus'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _busNumberController,
            decoration: const InputDecoration(
              labelText: 'Bus Number',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _driverNameController,
            decoration: const InputDecoration(
              labelText: 'Driver Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _driverContactController,
            decoration: const InputDecoration(
              labelText: 'Driver Contact',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_busNumberController.text.isEmpty) return;
            widget.onSave(
              Bus(
                id:
                    widget.bus?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                busNumber: _busNumberController.text,
                driverName: _driverNameController.text,
                driverContact: _driverContactController.text,
                latitude: widget.bus?.latitude,
                longitude: widget.bus?.longitude,
                lastUpdate: widget.bus?.lastUpdate,
              ),
            );
            Navigator.pop(context);
          },
          child: Text(widget.bus == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
