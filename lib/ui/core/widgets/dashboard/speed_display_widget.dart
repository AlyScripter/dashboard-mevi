import 'package:flutter/material.dart';
import 'package:dashboardmevi/services/ros_service.dart';
import 'package:dashboardmevi/core/theme/dimensions.dart';

class SpeedDisplayWidget extends StatelessWidget {
  const SpeedDisplayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: RosService().speedometerRosStream,
      builder: (context, snapshot) {
        final speed = (snapshot.data ?? 20).toInt();
        return Column(
          children: [
            Text(
              '$speed',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                height: 1,
              ),
            ),
            SizedBox(height: AppDimensions.spacingXS),
            const Text(
              'Km/h',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        );
      },
    );
  }
}
