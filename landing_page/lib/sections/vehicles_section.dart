import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class VehiclesSection extends StatelessWidget {
  const VehiclesSection({super.key});

  static final _vehicles = [
    _Vehicle(
      icon: Icons.directions_car_rounded,
      name: 'Sedan',
      capacity: '200 kg',
      description: 'Perfect for documents, small parcels and personal items.',
      tag: 'Small loads',
      tagColor: AppColors.success,
      gradient: const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _Vehicle(
      icon: Icons.airport_shuttle_rounded,
      name: 'AUV',
      capacity: '1,000 kg',
      description: 'Versatile utility vehicle for medium cargo and reliable city deliveries.',
      tag: 'Most Popular',
      tagColor: AppColors.primary,
      gradient: AppColors.cardGradient,
    ),
    _Vehicle(
      icon: Icons.fire_truck_rounded,
      name: '4-Wheeler Closed Van',
      capacity: '2,000 kg',
      description:
          'Enclosed van ideal for retail deliveries and mid-size commercial loads.',
      tag: 'Light commercial',
      tagColor: const Color(0xFF7C3AED),
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _Vehicle(
      icon: Icons.local_shipping,
      name: '6-Wheeler Closed Van',
      capacity: '3,000 kg',
      description:
          'Mid-size enclosed delivery truck for larger commercial and industrial cargo.',
      tag: 'Heavy commercial',
      tagColor: const Color(0xFFE53935),
      gradient: AppColors.accentGradient,
    ),
    _Vehicle(
      icon: Icons.conveyor_belt,
      name: '6-Wheeler Forward Wingvan',
      capacity: '7,000 kg',
      description:
          'Large forward wingvan with side-opening doors — perfect for bulk deliveries.',
      tag: 'Bulk deliveries',
      tagColor: const Color(0xFFFF8C00),
      gradient: const LinearGradient(
        colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _Vehicle(
      icon: Icons.train_rounded,
      name: '10-Wheeler Wingvan',
      capacity: '12,000 kg',
      description:
          'Maximum capacity wingvan for warehouse-to-warehouse and long-haul cargo.',
      tag: 'Max capacity',
      tagColor: AppColors.textDark,
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _Vehicle(
      icon: Icons.rv_hookup_rounded,
      name: '20-Footer Trailer',
      capacity: '20,000 kg',
      description:
          'Heavy-duty 20-foot trailer for construction materials and large industrial equipment.',
      tag: 'Industrial',
      tagColor: const Color(0xFF0891B2),
      gradient: const LinearGradient(
        colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _Vehicle(
      icon: Icons.local_shipping_rounded,
      name: '40-Footer Trailer',
      capacity: '32,000 kg',
      description:
          'Maximum-capacity 40-foot trailer for the heaviest industrial and logistics loads.',
      tag: 'Max payload',
      tagColor: const Color(0xFF374151),
      gradient: const LinearGradient(
        colors: [Color(0xFF374151), Color(0xFF1F2937)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 24 : 60,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D1F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _DarkSectionHeader(
            tag: 'Our Fleet',
            title: 'The Right Vehicle\nfor Every Load',
            subtitle:
                'From light parcel deliveries to heavy industrial cargo — '
                'we have a truck, van, or wingvan matched to your exact needs.',
          ),
          SizedBox(height: isMobile ? 48 : 72),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 600
                  ? 1
                  : constraints.maxWidth < 900
                  ? 2
                  : constraints.maxWidth < 1300
                  ? 3
                  : 4;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: _vehicles
                    .map(
                      (v) => SizedBox(
                        width:
                            (constraints.maxWidth - (crossAxisCount - 1) * 20) /
                            crossAxisCount,
                        child: _VehicleCard(vehicle: v),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Vehicle {
  final IconData icon;
  final String name;
  final String capacity;
  final String description;
  final String tag;
  final Color tagColor;
  final Gradient gradient;

  const _Vehicle({
    required this.icon,
    required this.name,
    required this.capacity,
    required this.description,
    required this.tag,
    required this.tagColor,
    required this.gradient,
  });
}

class _VehicleCard extends StatefulWidget {
  final _Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? Colors.white.withOpacity(0.20)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -4.0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: widget.vehicle.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.vehicle.icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.vehicle.tagColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.vehicle.tagColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    widget.vehicle.tag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.vehicle.tagColor == AppColors.textDark
                          ? Colors.white70
                          : widget.vehicle.tagColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.vehicle.name,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.scale_rounded,
                  size: 14,
                  color: Colors.white38,
                ),
                const SizedBox(width: 4),
                Text(
                  'Up to ${widget.vehicle.capacity}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.vehicle.description,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white54,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkSectionHeader extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;

  const _DarkSectionHeader({
    required this.tag,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Text(
            tag,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 768 ? 26 : 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.white54,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}
