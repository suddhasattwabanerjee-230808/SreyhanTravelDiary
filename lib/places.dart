import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// What a place is on the passport map.
enum PlaceKind {
  /// A district of Gujarat: a stamp on the map.
  district,

  /// A famous sight, with its own fact. Stamps its district too.
  landmark,

  /// Somewhere in India outside Gujarat.
  city,
}

/// A place the diary knows about, with one fun fact Sheru tells.
class Place {
  const Place(this.id, this.name, this.lat, this.lng, this.icon, this.color, this.fact, {this.kind = PlaceKind.district, this.district});

  final String id, name;
  final double lat, lng;
  final IconData icon;
  final Color color;

  /// Short and simple: Sheru reads it aloud.
  final String fact;
  final PlaceKind kind;

  /// For a landmark, the district it's in.
  final String? district;

  /// The district this place stamps on the Gujarat map, if any.
  String? get districtId => kind == PlaceKind.district ? id : district;
}

const _l = PlaceKind.landmark;
const _c = PlaceKind.city;

/// Gujarat's districts, at their main towns.
const districts = <Place>[
  Place('ahmedabad', 'Ahmedabad', 23.0225, 72.5714, Icons.location_city_rounded, Gj.saffron,
      "Ahmedabad was India's first World Heritage City. Its old lanes are full of carved wooden houses."),
  Place('amreli', 'Amreli', 21.6032, 71.2221, Icons.pets_rounded, Gj.marigold,
      'Lions from the Gir forest sometimes walk through the fields of Amreli!'),
  Place('anand', 'Anand', 22.5645, 72.9289, Icons.local_drink_rounded, Gj.peacock,
      'Anand is the milk city of India. Amul butter comes from here!'),
  Place('aravalli', 'Aravalli', 23.4625, 73.2988, Icons.terrain_rounded, Gj.leaf,
      'The Aravalli hills here are some of the oldest mountains in the world.'),
  Place('banaskantha', 'Banaskantha', 24.1725, 72.4381, Icons.temple_hindu_rounded, Gj.kumkum,
      'Ambaji, a famous temple town on the hills, is in Banaskantha.'),
  Place('bharuch', 'Bharuch', 21.7051, 72.9959, Icons.water_rounded, Gj.teal,
      'Bharuch is one of the oldest cities in India, beside the wide Narmada river.'),
  Place('bhavnagar', 'Bhavnagar', 21.7645, 72.1519, Icons.sailing_rounded, Gj.peacock,
      'Bhavnagar is a city by the sea, with a palace on a hill.'),
  Place('botad', 'Botad', 22.1704, 71.6684, Icons.temple_hindu_rounded, Gj.saffron,
      'Salangpur, in Botad, has a big temple of Lord Hanuman.'),
  Place('chhota_udaipur', 'Chhota Udaipur', 22.3047, 74.0123, Icons.palette_rounded, Gj.lilac,
      'Artists here paint bright Pithora pictures of horses on their walls.'),
  Place('dahod', 'Dahod', 22.8340, 74.2560, Icons.forest_rounded, Gj.leaf,
      'Dahod is where Gujarat meets Madhya Pradesh and Rajasthan.'),
  Place('dang', 'Dang', 20.7570, 73.6870, Icons.forest_rounded, Gj.leaf,
      'The Dang forest is very green, and it rains a lot here.'),
  Place('devbhumi_dwarka', 'Devbhumi Dwarka', 22.2006, 69.6550, Icons.temple_hindu_rounded, Gj.kumkum,
      'Devbhumi means the land of the gods. Lord Krishna\'s city Dwarka is here.'),
  Place('gandhinagar', 'Gandhinagar', 23.2156, 72.6369, Icons.park_rounded, Gj.leaf,
      "Gandhinagar is Gujarat's capital, a city full of trees."),
  Place('gir_somnath', 'Gir Somnath', 20.9077, 70.3679, Icons.sailing_rounded, Gj.teal,
      'Veraval has a big fishing harbour full of colourful boats.'),
  Place('jamnagar', 'Jamnagar', 22.4707, 70.0577, Icons.water_rounded, Gj.teal,
      "Jamnagar has India's first sea national park, with coral and starfish."),
  Place('junagadh', 'Junagadh', 21.5222, 70.4579, Icons.landscape_rounded, Gj.maroon,
      'Girnar hill in Junagadh has nearly 10,000 steps to climb!'),
  Place('kheda', 'Kheda', 22.6916, 72.8634, Icons.person_rounded, Gj.peacock,
      'Sardar Patel, the Iron Man of India, was born in Nadiad, in Kheda.'),
  Place('kutch', 'Kutch', 23.2420, 69.6669, Icons.wb_sunny_rounded, Gj.marigold,
      'Kutch is the biggest district in India. Its people make bright mirror-work cloth.'),
  Place('mahisagar', 'Mahisagar', 23.1282, 73.6100, Icons.water_rounded, Gj.peacock,
      'The Mahi river here crosses the Tropic of Cancer two times!'),
  Place('mehsana', 'Mehsana', 23.5880, 72.3693, Icons.wb_sunny_rounded, Gj.saffron,
      'Mehsana has one of the biggest milk dairies in Asia.'),
  Place('morbi', 'Morbi', 22.8173, 70.8370, Icons.schedule_rounded, Gj.lilac,
      "Most of India's floor tiles and wall clocks are made in Morbi!"),
  Place('narmada', 'Narmada', 21.8700, 73.5028, Icons.water_rounded, Gj.teal,
      'The Narmada river flows west into the sea, not east like most big rivers in India.'),
  Place('navsari', 'Navsari', 20.9467, 72.9520, Icons.local_fire_department_rounded, Gj.saffron,
      'Navsari is home to many Parsi families and a very old fire temple.'),
  Place('panchmahal', 'Panchmahal', 22.7788, 73.6143, Icons.landscape_rounded, Gj.leaf,
      'Pavagadh hill rises high above the fields, with a temple right on top.'),
  Place('patan', 'Patan', 23.8493, 72.1266, Icons.checkroom_rounded, Gj.kumkum,
      'Patan is famous for Patola, silk saris woven with tiny dots of colour.'),
  Place('porbandar', 'Porbandar', 21.6417, 69.6293, Icons.home_rounded, Gj.peacock,
      'Mahatma Gandhi was born in Porbandar, in a house by the sea.'),
  Place('rajkot', 'Rajkot', 22.3039, 70.8022, Icons.school_rounded, Gj.marigold,
      'Gandhiji went to school in Rajkot when he was a boy.'),
  Place('sabarkantha', 'Sabarkantha', 23.5986, 72.9663, Icons.forest_rounded, Gj.leaf,
      'Polo Forest here has old stone temples hidden among the trees.'),
  Place('surat', 'Surat', 21.1702, 72.8311, Icons.diamond_rounded, Gj.lilac,
      "Surat is the diamond city: most of the world's diamonds are cut and polished here!"),
  Place('surendranagar', 'Surendranagar', 22.7277, 71.6370, Icons.pets_rounded, Gj.saffron,
      'The Little Rann here is the only home in the world of the Indian wild ass, the ghudkhar.'),
  Place('tapi', 'Tapi', 21.1106, 73.3920, Icons.water_rounded, Gj.teal,
      'The Ukai dam in Tapi holds back a giant lake.'),
  Place('vadodara', 'Vadodara', 22.3072, 73.1812, Icons.castle_rounded, Gj.maroon,
      'Laxmi Vilas Palace in Vadodara is about four times bigger than Buckingham Palace!'),
  Place('valsad', 'Valsad', 20.5992, 72.9342, Icons.eco_rounded, Gj.marigold,
      'Valsad is famous for sweet Alphonso mangoes.'),
];

/// Famous sights. Within a few kilometres, their fact wins over the district's.
const landmarks = <Place>[
  Place('statue_of_unity', 'Statue of Unity', 21.8380, 73.7191, Icons.accessibility_new_rounded, Gj.maroon,
      'The Statue of Unity is the tallest statue in the world: 182 metres high! It shows Sardar Patel.',
      kind: _l, district: 'narmada'),
  Place('rani_ki_vav', 'Rani ki Vav', 23.8589, 72.1016, Icons.stairs_rounded, Gj.kumkum,
      'Rani ki Vav is a step-well with hundreds of stone carvings. It is on the 100 rupee note!',
      kind: _l, district: 'patan'),
  Place('somnath', 'Somnath', 20.8880, 70.4012, Icons.temple_hindu_rounded, Gj.saffron,
      'Somnath temple stands by the sea. There is no land between it and the South Pole!',
      kind: _l, district: 'gir_somnath'),
  Place('dwarka', 'Dwarka', 22.2376, 68.9674, Icons.flag_rounded, Gj.kumkum,
      "Dwarka is Lord Krishna's city. The temple's flag is changed five times every day!",
      kind: _l, district: 'devbhumi_dwarka'),
  Place('gir', 'Gir Forest', 21.1240, 70.8240, Icons.pets_rounded, Gj.marigold,
      "Gir is the only place in the world where Asiatic lions live in the wild. It's my home!",
      kind: _l, district: 'junagadh'),
  Place('white_rann', 'White Rann', 23.8360, 69.6430, Icons.nights_stay_rounded, Gj.peacock,
      'The White Rann is a huge desert of salt. Under the full moon it glows white!',
      kind: _l, district: 'kutch'),
  Place('dholavira', 'Dholavira', 23.8870, 70.2130, Icons.account_balance_rounded, Gj.maroon,
      'Dholavira is a city people built about 4,500 years ago!',
      kind: _l, district: 'kutch'),
  Place('mandvi', 'Mandvi', 22.8300, 69.3550, Icons.sailing_rounded, Gj.teal,
      'At Mandvi, people still build big wooden ships by hand. There are camel rides on the beach!',
      kind: _l, district: 'kutch'),
  Place('modhera', 'Modhera Sun Temple', 23.5835, 72.1330, Icons.wb_sunny_rounded, Gj.saffron,
      'The Modhera Sun Temple has a big step-tank with 108 little shrines around it.',
      kind: _l, district: 'mehsana'),
  Place('sabarmati_ashram', 'Sabarmati Ashram', 23.0608, 72.5800, Icons.cottage_rounded, Gj.leaf,
      'Gandhiji lived at Sabarmati Ashram, and started his Salt March from here.',
      kind: _l, district: 'ahmedabad'),
  Place('adalaj', 'Adalaj step-well', 23.1667, 72.5800, Icons.stairs_rounded, Gj.lilac,
      'Adalaj step-well goes five floors down, and it stays cool even in summer.',
      kind: _l, district: 'gandhinagar'),
  Place('nal_sarovar', 'Nal Sarovar', 22.8100, 72.0400, Icons.flutter_dash_rounded, Gj.kumkum,
      'In winter, thousands of birds like pink flamingos fly to Nal Sarovar lake.',
      kind: _l, district: 'ahmedabad'),
  Place('saputara', 'Saputara', 20.5760, 73.7520, Icons.cloud_rounded, Gj.leaf,
      "Saputara is Gujarat's hill station, cool and misty on top of the hills.",
      kind: _l, district: 'dang'),
  Place('palitana', 'Palitana', 21.4825, 71.7930, Icons.temple_hindu_rounded, Gj.saffron,
      'The hill at Palitana has more than 800 temples, and thousands of steps!',
      kind: _l, district: 'bhavnagar'),
  Place('champaner', 'Champaner', 22.4850, 73.5370, Icons.mosque_rounded, Gj.maroon,
      'Champaner is a World Heritage Site, with old mosques and walls 500 years old.',
      kind: _l, district: 'panchmahal'),
  Place('dandi', 'Dandi', 21.3300, 72.6230, Icons.beach_access_rounded, Gj.teal,
      'Dandi is the beach where Gandhiji made salt at the end of the Salt March.',
      kind: _l, district: 'navsari'),
  Place('marine_park', 'Marine National Park', 22.4600, 69.7170, Icons.set_meal_rounded, Gj.peacock,
      'At low tide here you can see coral, crabs, starfish and even an octopus!',
      kind: _l, district: 'jamnagar'),
  Place('velavadar', 'Velavadar', 22.0450, 72.0300, Icons.grass_rounded, Gj.marigold,
      'Velavadar grassland is home to blackbuck deer with twisty horns.',
      kind: _l, district: 'bhavnagar'),
];

/// Places around India, for trips outside Gujarat.
const cities = <Place>[
  Place('kolkata', 'Kolkata', 22.5726, 88.3639, Icons.location_city_rounded, Gj.saffron,
      "Kolkata's Howrah Bridge has no nuts and bolts. It is held together by rivets!", kind: _c),
  Place('delhi', 'Delhi', 28.6139, 77.2090, Icons.account_balance_rounded, Gj.maroon,
      "Delhi is India's capital. India Gate remembers brave soldiers.", kind: _c),
  Place('mumbai', 'Mumbai', 19.0760, 72.8777, Icons.location_city_rounded, Gj.peacock,
      'Mumbai was once seven islands, joined together!', kind: _c),
  Place('jaipur', 'Jaipur', 26.9124, 75.7873, Icons.castle_rounded, Gj.kumkum,
      'Jaipur is the Pink City: its old town is painted pink!', kind: _c),
  Place('udaipur', 'Udaipur', 24.5854, 73.7125, Icons.water_rounded, Gj.teal,
      'Udaipur is the City of Lakes, with a palace in the middle of a lake.', kind: _c),
  Place('mount_abu', 'Mount Abu', 24.5926, 72.7156, Icons.landscape_rounded, Gj.leaf,
      'Mount Abu is the only hill station in Rajasthan.', kind: _c),
  Place('agra', 'Agra', 27.1751, 78.0421, Icons.mosque_rounded, Gj.lilac,
      'The Taj Mahal in Agra is white marble that looks pink at sunrise.', kind: _c),
  Place('diu', 'Diu', 20.7144, 70.9874, Icons.fort_rounded, Gj.maroon,
      'Diu is a little island with a big old fort by the sea.', kind: _c),
  Place('goa', 'Goa', 15.4909, 73.8278, Icons.beach_access_rounded, Gj.marigold,
      "Goa is India's smallest state, with lots of sandy beaches.", kind: _c),
  Place('bengaluru', 'Bengaluru', 12.9716, 77.5946, Icons.park_rounded, Gj.leaf,
      'Bengaluru is called the Garden City.', kind: _c),
  Place('chennai', 'Chennai', 13.0827, 80.2707, Icons.beach_access_rounded, Gj.teal,
      'Marina Beach in Chennai is one of the longest city beaches in the world.', kind: _c),
  Place('hyderabad', 'Hyderabad', 17.3850, 78.4867, Icons.mosque_rounded, Gj.saffron,
      "Hyderabad's Charminar has four tall towers.", kind: _c),
  Place('varanasi', 'Varanasi', 25.3176, 82.9739, Icons.water_rounded, Gj.peacock,
      'Varanasi, on the Ganga river, is one of the oldest cities in the world.', kind: _c),
];

final _byId = {for (final p in [...districts, ...landmarks, ...cities]) p.id: p};

Place? placeById(String? id) => id == null ? null : _byId[id];

/// Gujarat's outline as (lat, lng), drawn on the passport map and used to
/// tell whether a photo was taken in Gujarat. Rough, like a cartoon map.
const gujaratOutline = <(double, double)>[
  (23.70, 68.42), (24.05, 68.75), (24.30, 68.85), (24.30, 69.30), (24.25, 69.80), (24.30, 70.20),
  (24.45, 70.60), (24.40, 71.00), (24.60, 71.10), (24.60, 71.60), (24.50, 72.10), (24.62, 72.40),
  (24.45, 72.75), (24.30, 73.05), (24.00, 73.25), (23.75, 73.45), (23.50, 73.70), (23.20, 74.00),
  (23.05, 74.30), (22.85, 74.45), (22.50, 74.35), (22.20, 74.15), (21.95, 74.05), (21.60, 73.90),
  (21.30, 74.05), (21.05, 73.90), (20.80, 73.95), (20.55, 73.80), (20.35, 73.45), (20.15, 73.10),
  (20.15, 72.75), (20.45, 72.85), (20.95, 72.80), (21.10, 72.62), (21.45, 72.55), (21.70, 72.55),
  (22.00, 72.62), (22.30, 72.70), (22.25, 72.35), (21.95, 72.25), (21.70, 72.25), (21.40, 72.15),
  (21.15, 71.90), (21.05, 71.55), (20.85, 71.30), (20.75, 70.90), (20.80, 70.40), (21.10, 70.10),
  (21.40, 69.85), (21.65, 69.55), (21.95, 69.25), (22.25, 68.95), (22.45, 69.05), (22.40, 69.45),
  (22.50, 69.80), (22.55, 70.10), (22.80, 70.35), (23.00, 70.50), (23.00, 70.20), (22.85, 69.75),
  (22.80, 69.35), (22.95, 69.00), (23.20, 68.65), (23.45, 68.45),
];

/// The salt deserts of Kutch, drawn white on the map.
const greatRann = <(double, double)>[
  (24.22, 69.00), (24.22, 70.90), (23.95, 71.10), (23.72, 70.60), (23.82, 69.60), (23.95, 69.10),
];
const littleRann = <(double, double)>[
  (23.55, 70.65), (23.60, 71.40), (23.22, 71.60), (23.02, 71.10), (23.10, 70.62),
];

bool _inside(List<(double, double)> poly, double lat, double lng) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (yi, xi) = poly[i];
    final (yj, xj) = poly[j];
    if ((yi > lat) != (yj > lat) && lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

bool inGujarat(double lat, double lng) => _inside(gujaratOutline, lat, lng);

/// Kilometres between two points.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a));
}

Place _nearest(List<Place> places, double lat, double lng) =>
    places.reduce((a, b) => distanceKm(lat, lng, a.lat, a.lng) <= distanceKm(lat, lng, b.lat, b.lng) ? a : b);

/// The place a photo was taken: a famous sight if it's close by, else the
/// nearest Gujarat district, else a city elsewhere in India; null if it's far
/// from anywhere the diary knows.
Place? placeAt(double lat, double lng) {
  final sight = _nearest(landmarks, lat, lng);
  if (distanceKm(lat, lng, sight.lat, sight.lng) <= 6) return sight;
  // Near the border, a city just over it (Mount Abu, Diu) beats a district.
  final city = _nearest(cities, lat, lng);
  final cityKm = distanceKm(lat, lng, city.lat, city.lng);
  if (cityKm <= 15) return city;
  if (inGujarat(lat, lng)) return _nearest(districts, lat, lng);
  return cityKm <= 60 ? city : null;
}

/// Every stamp in the passport from the places photos were taken: the places
/// themselves, plus the districts their sights are in.
Set<String> passportStamps(Iterable<String> placeIds) => {
  for (final id in placeIds) ...{id, ?placeById(id)?.districtId},
};
