import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'mera_khet_home.dart';
import 'mera_khet_dashboard.dart';

class MeraKhetWrapper extends StatefulWidget {
  const MeraKhetWrapper({Key? key}) : super(key: key);

  @override
  State<MeraKhetWrapper> createState() => _MeraKhetWrapperState();
}

class _MeraKhetWrapperState extends State<MeraKhetWrapper> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    final hasSavedFarm = box.get('has_saved_farm', defaultValue: false) as bool;

    if (hasSavedFarm) {
      return const MeraKhetDashboard(farmId: 'farm_1');
    } else {
      return MeraKhetHome(cropName: '', sowingDate: DateTime.now());
    }
  }
}
