import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/hospital_service.dart';
import '../theme/app_theme.dart';

class ScannerOverlay extends StatelessWidget {
  final bool isScanning;
  final bool isPalmDetected;
  final String statusText;
  final VoidCallback? onSnapPressed;
  final bool isCameraReady;

  const ScannerOverlay({
    super.key,
    required this.isScanning,
    required this.isPalmDetected,
    required this.statusText,
    required this.isCameraReady,
    this.onSnapPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double reticleWidth = screenSize.width - 36;
    final double reticleHeight = (screenSize.height * 0.52).clamp(320.0, 520.0);

    final Color activeColor = isScanning
        ? AppTheme.accentBlue
        : (isPalmDetected ? AppTheme.primaryEmerald : AppTheme.secondaryCyan);

    return Stack(
      children: [
        // 1. Full-Screen Semi-Transparent Vignette with large scan opening
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.40),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: reticleWidth,
                  height: reticleHeight,
                  decoration: BoxDecoration(
                    color: Colors.red, // Mask hole
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. High-Precision Full-Screen Palm Target Reticle
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: reticleWidth,
            height: reticleHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: activeColor,
                width: isPalmDetected ? 3.5 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: isPalmDetected ? 0.55 : 0.25),
                  blurRadius: isPalmDetected ? 20 : 12,
                  spreadRadius: isPalmDetected ? 3 : 1,
                )
              ],
            ),
            child: Stack(
              children: [
                // Corner Reticles
                TopLeftCorner(color: activeColor),
                TopRightCorner(color: activeColor),
                BottomLeftCorner(color: activeColor),
                BottomRightCorner(color: activeColor),

                // Palm Contour Guide Icon with Dynamic Detection Glow
                Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: isPalmDetected ? 1.08 : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.front_hand_rounded,
                          size: 150,
                          color: activeColor.withValues(alpha: isPalmDetected ? 0.40 : 0.20),
                        ),
                        if (isPalmDetected && !isScanning)
                          Positioned(
                            top: 24,
                            right: 24,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryEmerald,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Animated Scan Line when actively extracting vector
                if (isScanning)
                  Animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                    effects: [
                      SlideEffect(
                        begin: const Offset(0, -0.45),
                        end: const Offset(0, 0.45),
                        duration: 1200.ms,
                        curve: Curves.easeInOut,
                      )
                    ],
                    child: Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryEmerald.withValues(alpha: 0.1),
                            AppTheme.secondaryCyan,
                            AppTheme.primaryEmerald.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.secondaryCyan,
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. Status Bar Prompt & Real-time Detection Status Badge
        Positioned(
          top: 36,
          left: 16,
          right: 16,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isPalmDetected
                      ? AppTheme.primaryEmerald
                      : AppTheme.lightCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPalmDetected ? AppTheme.primaryEmerald : AppTheme.borderLight,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPalmDetected ? Icons.check_circle_rounded : Icons.shield_rounded,
                      color: isPalmDetected ? Colors.white : AppTheme.primaryEmerald,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPalmDetected ? "PALM DETECTED & ALIGNED" : "100% Offline Vector Engine",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPalmDetected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (HospitalService().hasSelectedHospital) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightCard.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryEmerald, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "${HospitalService().selectedHospital!.name} (${HospitalService().selectedHospital!.datimCode})",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.lightCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeColor,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Floating Scan Capture Trigger Button
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: isScanning || !isCameraReady ? null : onSnapPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isPalmDetected
                        ? [AppTheme.primaryEmerald, const Color(0xFF047857)]
                        : [AppTheme.primaryEmerald, AppTheme.secondaryCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isPalmDetected ? AppTheme.primaryEmerald : AppTheme.secondaryCyan).withValues(alpha: 0.4),
                      blurRadius: isPalmDetected ? 20 : 14,
                      spreadRadius: isPalmDetected ? 4 : 2,
                    )
                  ],
                ),
                child: Center(
                  child: isScanning
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 34, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TopLeftCorner extends StatelessWidget {
  final Color color;
  const TopLeftCorner({super.key, this.color = AppTheme.primaryEmerald});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color, width: 4),
            left: BorderSide(color: color, width: 4),
          ),
        ),
      ),
    );
  }
}

class TopRightCorner extends StatelessWidget {
  final Color color;
  const TopRightCorner({super.key, this.color = AppTheme.primaryEmerald});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color, width: 4),
            right: BorderSide(color: color, width: 4),
          ),
        ),
      ),
    );
  }
}

class BottomLeftCorner extends StatelessWidget {
  final Color color;
  const BottomLeftCorner({super.key, this.color = AppTheme.primaryEmerald});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color, width: 4),
            left: BorderSide(color: color, width: 4),
          ),
        ),
      ),
    );
  }
}

class BottomRightCorner extends StatelessWidget {
  final Color color;
  const BottomRightCorner({super.key, this.color = AppTheme.primaryEmerald});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color, width: 4),
            right: BorderSide(color: color, width: 4),
          ),
        ),
      ),
    );
  }
}
