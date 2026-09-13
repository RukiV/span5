import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fbs/models/asset.dart';
import 'package:fbs/models/asset_type.dart';
import 'package:fbs/models/building.dart';
import 'package:fbs/models/campus.dart';
import 'package:fbs/models/room.dart';
import 'package:fbs/models/stock.dart';
import 'package:fbs/models/user_session.dart';
import 'package:fbs/services/asset_type_service.dart';
import 'package:fbs/services/campus_service.dart';

Room sampleRoom() => Room(
      id: 101,
      name: "R101",
      type: 'klas',
      capacity: 30,
      buildingId: 1,
    );

Building sampleBuilding() => Building(
      id: 1,
      name: "Hoofgebou",
      types: const ['onderwys'],
      locationId: 1,
      rooms: [sampleRoom()],
    );

Campus sampleCampus() => Campus(
      id: 1,
      name: "Sterland",
      code: "KAMPUS",
      streetNum: "1",
      streetName: "Hoofstraat",
      suburb: "Sterpark",
      city: "Pretoria",
      province: "Gauteng",
      country: "Suid-Afrika",
      location: const LatLng(-25.85, 28.18),
      radius: 110,
      buildings: [sampleBuilding()],
    );

Asset sampleAsset() => Asset(
      id: 'ba-1',
      serialCode: 'SR123',
      name: "Projektor",
      brand: "Epson",
      category: "Projektor",
      assetTypeId: 1,
      location: '101',
      status: 'active',
    );

Stock sampleStock() => Stock(
      id: 7,
      name: "Projektorlamp",
      brand: "Epson",
      amount: 4,
      minimum: 2,
      boxTotal: 1,
      type: "Verbruiksgoed",
      description: "Reserwelamp",
      roomId: 101,
    );

void seedLocationData() {
  CampusService.campusesNotifier.value = [sampleCampus()];
  AssetTypeService.typesNotifier.value = [
    AssetType(id: 1, name: "Projektor"),
  ];
  UserSession.rights = <String>[
    'buildings.manage',
    'locations.manage',
    'rooms.manage',
    'stock.manage',
    'assets.manage',
  ];
  UserSession.userCampus = "Sterland";
}

Widget wrap(Widget child) => MaterialApp(home: child);

Future<void> pumpForm(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  seedLocationData();
  await tester.pumpWidget(wrap(child));
  await tester.pumpAndSettle();
}

bool fieldIgnoring(WidgetTester tester) {
  final pointers = tester.widgetList<IgnorePointer>(find.byType(IgnorePointer));
  for (final p in pointers) {
    if (p.child is Opacity) return p.ignoring;
  }
  fail('Geen veldomhulsel (IgnorePointer > Opacity) gevind nie');
}
