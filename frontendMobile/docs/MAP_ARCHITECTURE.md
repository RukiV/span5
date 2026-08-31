# Kaart Argitektuur - FBS Mobile

Hierdie dokument verduidelik hoe die kaartstelsel in die FBS (Fasiliteite Bestuurs
Stelsel) mobiele app werk - van GPS-opsporing tot kaartvertoning en backend-integrasie.

---

## 1. Tegniese Stack

| Komponent | Biblioteek | Doel |
|-----------|-----------|------|
| Kaart | `google_maps_flutter ^2.17.0` | Google Maps rendering op foon |
| GPS | `geolocator ^13.0.1` | GPS-opsporing en posisie-stroom |
| HTTP | `dio ^5.7.0` | API-aanvrae na backend |
| Env | `flutter_dotenv ^5.1.0` | Laai .env veranderlikes |
| State | `ValueNotifier` | Reaktiewe UI-opdaterings |

---

## 2. Lêerstruktuur

```
frontendMobile/lib/
├── pages/
│   ├── reporting/
│   │   ├── location_page.dart          # Hoofkaart vir foutverslag-ligging
│   │   ├── select_location_page.dart   # Eenvoudige kaart-kieser (terrein add/edit)
│   │   ├── new_report_page.dart        # Nuwe verslag (roep location_page aan)
│   │   ├── edit_report_page.dart       # Wysig verslag (kan ligging kies)
│   │   └── report_detail_page.dart     # Verslagbesonderhede (lees-only kaart)
│   └── campus/
│       ├── add_campus_page.dart        # Voeg terrein by (gebruik select_location_page)
│       └── edit_campus_page.dart       # Wysig terrein (gebruik select_location_page)
├── models/
│   └── campus.dart                     # Campus model met LatLng + radius
├── services/
│   └── campus_service.dart             # Haal kampusse vanaf backend API
└── core/
    ├── app_colors.dart                 # Kleurpalet
    └── api_client.dart                 # Dio HTTP-kliënt ( singleton )
```

---

## 3. Location Page (Hoofkaart)

**Lêer:** `lib/pages/reporting/location_page.dart`

Die hoofkaart wat oopmaak wanneer 'n gebruiker 'n foutverslag maak. Dit wys die
gebruiker se huidige GPS-ligging met die standaard Google Maps blou merkie.

### 3.1 Hoe dit begin

Wanneer `LocationPage` gelaai word, gebeur die volgende in `initState`:

```dart
@override
void initState() {
  super.initState();
  // Stel die aanvanklike koördinate (of vanaf parameter, of default Pretoria)
  if (widget.initialLocation != null) {
    _selectedLocation = widget.initialLocation!;
  }
  // Begin GPS-opsporing na die eerste frame gelaai is
  WidgetsBinding.instance.addPostFrameCallback((_) => _initGps());
}
```

### 3.2 GPS-opsporing

Die GPS word via die `geolocator` pakket bestuur. Dit volg die gebruiker
se posisie in reële tyd.

**Stap 1 - Toestemming:**

```dart
Future<void> _initGps() async {
  // 1. Kontroleer of GPS diens aan is
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    setState(() => _gpsPermissionDenied = true);
    return;
  }

  // 2. Vra toestemming
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  // 3. Begin opsporing as toestemming gegee is
  if (permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always) {
    setState(() => _gpsPermissionDenied = false);
    _startTracking();
  } else {
    setState(() => _gpsPermissionDenied = true);
  }
}
```

**Stap 2 - Posisie stroom:**

```dart
void _startTracking() async {
  // Kry huidige posisie een keer (vir vinnige eerste merkie)
  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,  // Herfs slegs as gebruiker 1m beweeg
      ),
    );
    _handleNewPosition(position, moveMap: true);
  } catch (_) {}

  // Begin reële tyd stroom
  _positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    ),
  ).listen((Position position) {
    _handleNewPosition(position, moveMap: false);
  });
}
```

**Stap 3 - Verwerk nuwe posisie:**

```dart
void _handleNewPosition(Position position, {bool moveMap = false}) {
  final userPoint = LatLng(position.latitude, position.longitude);

  setState(() {
    _userLocation = userPoint;
    _selectedLocation = userPoint;
  });

  // Beweeg die kaart slegs na die eerste GPS-fix
  if (moveMap) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userPoint, 18.0));
  }
}
```

### 3.3 Die GoogleMap Widget

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 15),
  onMapCreated: (c) => _mapController = c,
  myLocationEnabled: !_gpsPermissionDenied,  // Die blou merkie
  myLocationButtonEnabled: false,            // Ons gebruik ons eie FAB
  zoomControlsEnabled: false,
  mapType: MapType.normal,                   // Plain straatkaart
  markers: {},                               // Geen custom markers nie
  circles: {},                               // Geen overlays nie
),
```

Belangrikste eienskappe:
- **`myLocationEnabled: true`** - Google Maps se ingeboude blou merkie wys die
  gebruiker se huidige ligging
- **`mapType: MapType.normal`** - Plain straatkaart (nie satelliet nie)
- **`markers: {}`** - Leë stel, geen custom merkers nodig nie

### 3.4 Bevestiging

Wanneer die gebruiker die regmerkie druk:

```dart
Future<void> _confirmLocation() async {
  setState(() => _isSnapping = true);

  try {
    // Neem 'n skermkappie van die kaart (vir die verslag foto)
    final Uint8List? imageBytes = await _mapController?.takeSnapshot();

    if (mounted) {
      // Stuur koördinate + skermkappie terug na die bladsy wat dit geroep het
      Navigator.pop(context, {
        'coords': "${_selectedLocation.latitude.toStringAsFixed(6)}, "
            "${_selectedLocation.longitude.toStringAsFixed(6)}",
        'screenshot': imageBytes,
      });
    }
  } catch (e) {
    if (mounted) Navigator.pop(context, null);
  } finally {
    if (mounted) setState(() => _isSnapping = false);
  }
}
```

### 3.5 FAB - "Gebruik my ligging"

Die swembal-bewegende-knoppie onder regs:

```dart
FloatingActionButton(
  mini: true,
  backgroundColor: Colors.white,
  tooltip: "Gebruik my ligging",
  onPressed: () {
    if (_userLocation != null) {
      // Beweeg kaart terug na gebruiker se ligging
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 18.0));
    } else {
      // Probeer GPS weer
      _initGps();
    }
  },
  child: const Icon(Icons.my_location, color: AppColors.navy),
),
```

---

## 4. Select Location Page (Terrein Kies)

**Lêer:** `lib/pages/reporting/select_location_page.dart`

'N Eenvoudige kaart waarop die gebruiker kan tik om 'n ligging te kies. Word
gebruik wanneer terreine bygevoeg of gewysig word.

### 4.1 Hoe dit werk

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(target: _currentLocation, zoom: 15),
  // Tik enige plek op die kaart om 'n nuwe ligging te kies
  onTap: (pos) {
    setState(() {
      _currentLocation = pos;
    });
  },
  markers: {
    Marker(
      markerId: const MarkerId("selected"),
      position: _currentLocation,
    ),
  },
),
```

Die bladsy返l die gekose `LatLng` terug na die roeper sodra die regmerkie gedruk word:

```dart
onPressed: () => Navigator.pop(context, _currentLocation),
```

---

## 5. Back Integration

### 5.1 Backend Location Model

**Lêer:** `backend/app/models/location.py`

Die backend stoor terrein-data (kampusse) in die `location` tabel:

```python
class LocationBase(SQLModel):
    location_name: str = Field(max_length=100)
    location_type: str = Field(max_length=50)
    location_streetnum: str = Field(max_length=20)
    location_streetname: str = Field(max_length=100)
    location_suburb: str = Field(default="", max_length=100)
    location_city: str = Field(default="", max_length=100)
    location_province: str = Field(default="", max_length=100)
    location_country: str = Field(default="", max_length=100)
    location_latitude: Optional[float] = None   # GPS breedtegraad
    location_longitude: Optional[float] = None  # GPS lengtegraad
    location_radius: Optional[float] = Field(default=110)  # Radius in meters
```

### 5.2 Flutter Campus Model

**Lêer:** `lib/models/campus.dart`

Die Flutter-kant se weergawe van die backend se location:

```dart
class Campus {
  final int id;
  final String name;
  final String code;
  final String streetNum;
  final String streetName;
  final String suburb;
  final String city;
  final String province;
  final String country;
  final LatLng location;    // Google Maps se LatLng
  final double radius;

  // JSON serialisasie vir die API
  Map<String, dynamic> toJson() => {
    'location_name': name,
    'location_latitude': location.latitude,
    'location_longitude': location.longitude,
    'location_radius': radius,
    // ... ander velde
  };

  // Maak Campus uit API-antwoord
  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      id: json['location_id'] ?? 0,
      name: json['location_name'] ?? '',
      location: LatLng(
        (json['location_latitude'] as num?)?.toDouble() ?? -25.8480,
        (json['location_longitude'] as num?)?.toDouble() ?? 28.2366,
      ),
      radius: (json['location_radius'] as num?)?.toDouble() ?? 110.0,
      // ... ander velde
    );
  }
}
```

### 5.3 Campus Service (API-oproep)

**Lêer:** `lib/services/campus_service.dart`

Haal alle kampusse, geboue en kamers vanaf die backend:

```dart
class CampusService {
  static final ValueNotifier<List<Campus>> campusesNotifier = ValueNotifier([]);

  static Future<void> fetchCampuses() async {
    try {
      final locResponse = await ApiClient().client.get('/location');
      final buildingResponse = await ApiClient().client.get('/building');
      final roomResponse = await ApiClient().client.get('/rooms');

      if (locResponse.statusCode == 200) {
        final List<dynamic> locData = locResponse.data;

        _campuses.clear();
        for (var locJson in locData) {
          // Koppel geboue en kamers aan elke kampus
          _campuses.add(Campus.fromJson(locJson));
        }
        campusesNotifier.value = List.from(_campuses);
      }
    } catch (e) {
      debugPrint("Error loading locations: $e");
    }
  }
}
```

### 5.4 Mappoint Model (Vir Foutkaartjies)

**Lêer:** `backend/app/models/mappoint.py`

Wanneer 'n foutverslag 'n GPS-punt het, word dit in die `mappoint` tabel gestoor:

```python
class MappointBase(SQLModel):
    latitude: float
    longitude: float
```

Foutverslae en werkskaarte verwys na `mappoint_id` om hul GPS-ligging te stoor.

---

## 6. API Endpoints

| Metode | Pad | Beskrywing |
|--------|-----|------------|
| `GET` | `/location` | Kry alle terreine/kampusse |
| `POST` | `/location` | Voeg nuwe terrein by |
| `PATCH` | `/location/{id}` | Wysig terrein |
| `DELETE` | `/location/{id}` | Verwyder terrein |
| `GET` | `/building` | Kry alle geboue |
| `POST` | `/building` | Voeg gebou by |
| `GET` | `/rooms` | Kry alle kamers |
| `POST` | `/mappoint` | Stoor GPS-punt vir verslag |

---

## 7. Google Maps API Key Opstel

### Android

Die Android-sleutel word in `android/app/build.gradle.kts` gelaai:

```kotlin
// Lees uit keystore.properties (nie in git nie) of GOOGLE_MAPS_API_KEY env var
manifestPlaceholders["googleMapsApiKey"] =
    keystoreProperties["googleMapsApiKey"] as String?
        ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
```

**Stappe:**
1. Skep `android/keystore.properties` (nie in git):
   ```
   googleMapsApiKey=JOU_SLEUTEL_HIER
   ```
   OF stel die `GOOGLE_MAPS_API_KEY` omgewingsveranderlike.

2. Die sleutel word outomaties in `AndroidManifest.xml` ingevoeg:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="${googleMapsApiKey}"/>
   ```

### iOS

**Stappe:**
1. Voeg die sleutel by in `ios/Runner/Info.plist`:
   ```xml
   <key>GMSApiKey</key>
   <string>JOU_SLEUTEL_HIER</string>
   ```

2. Voeg by in `ios/Runner/AppDelegate.swift`:
   ```swift
   import GoogleMaps

   @main
   @objc class AppDelegate: FlutterAppDelegate {
     override func application(
       _ application: UIApplication,
       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
     ) -> Bool {
       GMSServices.provideAPIKey("JOU_SLEUTEL_HIER")
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     }
   }
   ```

**Google Cloud Console opsies:**
- Maak die "Maps SDK for Android" en "Maps SDK for iOS" aan
- Beperk die sleutel tot slegs jou app se pakketnaam (Android) / bundle ID (iOS)

---

## 8. Data Vloei Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     FBS MOBILE APP                       │
│                                                          │
│  ┌──────────────┐      ┌──────────────────────────────┐ │
│  │  LocationPage │      │  SelectLocationPage           │ │
│  │  (Verslag)    │      │  (Terrein Add/Edit)           │ │
│  │               │      │                               │ │
│  │  • GPS-out    │      │  • Tik op kaart               │ │
│  │  • Blou merkie│      │  • Kies ligging               │ │
│  │  • Bevestig   │      │  • Bevestig                   │ │
│  └──────┬───────┘      └──────────┬────────────────────┘ │
│         │                         │                      │
│         │ Koördinate + foto        │ LatLng               │
│         ▼                         ▼                      │
│  ┌──────────────────────────────────────────────┐        │
│  │              new_report_page / add_campus      │        │
│  │              (Stoor by backend)                │        │
│  └──────────────────────┬───────────────────────┘        │
│                          │                               │
└──────────────────────────┼───────────────────────────────┘
                           │
                           │ HTTP POST / PATCH
                           ▼
┌──────────────────────────────────────────────────────────┐
│                   FASTAPI BACKEND                         │
│                                                           │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────────┐  │
│  │  /location   │  │  /mappoint  │  │  /fault           │  │
│  │  (Terrein)   │  │  (GPS punt) │  │  (Foutverslag)    │  │
│  │              │  │             │  │                   │  │
│  │  latitude    │  │  latitude   │  │  mappoint_id FK   │  │
│  │  longitude   │  │  longitude  │  │                   │  │
│  │  radius      │  │             │  │                   │  │
│  └─────────────┘  └────────────┘  └──────────────────┘  │
│                                                           │
│                    PostgreSQL Database                    │
└──────────────────────────────────────────────────────────┘
```

---

## 9. Belangrike Keuses

### Waarom `myLocationEnabled` eerder as custom marker?

Google Maps se ingeboude `myLocationEnabled` wys outomaties:
- Die blou posisiedraaiertjie
- 'n Skaduwee onder die merkie
- Outomatiese beweging saam met GPS

Dit is betroubaarder as 'n custom `Marker` omdat:
- Google Maps hanteer die animasie en posisie-opdaterings
- Geen ekstra berekeninge nodig nie
- Die merkie beweeg vlot saam met die GPS-stroom

### Waarom `MapType.normal`?

Plain straatkaart is:
- Skoner en makliker om te lees
- Minder data-verbruik as satelliet
- Betere kontras vir die blou merkie

### Waarom `distanceFilter: 1`?

'N 1-meter filter beteken die GPS stuur slegs 'n opdatering wanneer die
gebruiker ten minste 1 meter beweeg het. Dit voorkom:
- Oormatige batteryverbruik
- Onnodige herhaalde opdaterings wanneer die foon stilstaan
