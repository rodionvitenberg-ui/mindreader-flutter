/// ASTRAL Phase 1 — offline city catalog for natal chart birth data.
/// Standard (non-DST) timezone offsets; coordinates are city centers.
library;

/// One searchable city with chart-relevant data.
class AstroCity {
  const AstroCity({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezoneOffsetHours,
  });

  final String name;
  final String country;

  /// North positive, degrees.
  final double latitude;

  /// East positive, degrees.
  final double longitude;

  /// Standard UTC offset in hours (e.g. Bishkek = 6).
  final double timezoneOffsetHours;
}

/// 90+ major world & CIS cities.
const List<AstroCity> astroCities = [
  // Kyrgyzstan
  AstroCity(
    name: 'Bishkek',
    country: 'Kyrgyzstan',
    latitude: 42.8746,
    longitude: 74.5698,
    timezoneOffsetHours: 6,
  ),
  AstroCity(
    name: 'Karakol',
    country: 'Kyrgyzstan',
    latitude: 42.4907,
    longitude: 78.3936,
    timezoneOffsetHours: 6,
  ),
  AstroCity(
    name: 'Osh',
    country: 'Kyrgyzstan',
    latitude: 40.5140,
    longitude: 72.8161,
    timezoneOffsetHours: 6,
  ),
  AstroCity(
    name: 'Jalal-Abad',
    country: 'Kyrgyzstan',
    latitude: 40.9331,
    longitude: 72.9960,
    timezoneOffsetHours: 6,
  ),
  AstroCity(
    name: 'Naryn',
    country: 'Kyrgyzstan',
    latitude: 41.4287,
    longitude: 75.9911,
    timezoneOffsetHours: 6,
  ),
  AstroCity(
    name: 'Talas',
    country: 'Kyrgyzstan',
    latitude: 42.5228,
    longitude: 72.2426,
    timezoneOffsetHours: 6,
  ),
  // Kazakhstan
  AstroCity(
    name: 'Almaty',
    country: 'Kazakhstan',
    latitude: 43.2220,
    longitude: 76.8512,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Astana',
    country: 'Kazakhstan',
    latitude: 51.1605,
    longitude: 71.4704,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Shymkent',
    country: 'Kazakhstan',
    latitude: 42.3417,
    longitude: 69.5901,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Aktobe',
    country: 'Kazakhstan',
    latitude: 50.2839,
    longitude: 57.1670,
    timezoneOffsetHours: 5,
  ),
  // Uzbekistan
  AstroCity(
    name: 'Tashkent',
    country: 'Uzbekistan',
    latitude: 41.2995,
    longitude: 69.2401,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Samarkand',
    country: 'Uzbekistan',
    latitude: 39.6270,
    longitude: 66.9750,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Bukhara',
    country: 'Uzbekistan',
    latitude: 39.7681,
    longitude: 64.4556,
    timezoneOffsetHours: 5,
  ),
  // Tajikistan / Turkmenistan
  AstroCity(
    name: 'Dushanbe',
    country: 'Tajikistan',
    latitude: 38.5598,
    longitude: 68.7870,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Khujand',
    country: 'Tajikistan',
    latitude: 40.2826,
    longitude: 69.6222,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Ashgabat',
    country: 'Turkmenistan',
    latitude: 37.9601,
    longitude: 58.3261,
    timezoneOffsetHours: 5,
  ),
  // Russia
  AstroCity(
    name: 'Moscow',
    country: 'Russia',
    latitude: 55.7558,
    longitude: 37.6173,
    timezoneOffsetHours: 3,
  ),
  AstroCity(
    name: 'Saint Petersburg',
    country: 'Russia',
    latitude: 59.9311,
    longitude: 30.3609,
    timezoneOffsetHours: 3,
  ),
  AstroCity(
    name: 'Kazan',
    country: 'Russia',
    latitude: 55.7963,
    longitude: 49.1088,
    timezoneOffsetHours: 3,
  ),
  AstroCity(
    name: 'Sochi',
    country: 'Russia',
    latitude: 43.5855,
    longitude: 39.7231,
    timezoneOffsetHours: 3,
  ),
  AstroCity(
    name: 'Kaliningrad',
    country: 'Russia',
    latitude: 54.7104,
    longitude: 20.4522,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Yekaterinburg',
    country: 'Russia',
    latitude: 56.8389,
    longitude: 60.6057,
    timezoneOffsetHours: 5,
  ),
  AstroCity(
    name: 'Novosibirsk',
    country: 'Russia',
    latitude: 55.0084,
    longitude: 82.9357,
    timezoneOffsetHours: 7,
  ),
  AstroCity(
    name: 'Irkutsk',
    country: 'Russia',
    latitude: 52.2870,
    longitude: 104.2807,
    timezoneOffsetHours: 8,
  ),
  AstroCity(
    name: 'Vladivostok',
    country: 'Russia',
    latitude: 43.1198,
    longitude: 131.8869,
    timezoneOffsetHours: 10,
  ),
  // Ukraine / Belarus / Moldova
  AstroCity(
    name: 'Kyiv',
    country: 'Ukraine',
    latitude: 50.4501,
    longitude: 30.5234,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Odesa',
    country: 'Ukraine',
    latitude: 46.4825,
    longitude: 30.7233,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Kharkiv',
    country: 'Ukraine',
    latitude: 49.9935,
    longitude: 36.2304,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Lviv',
    country: 'Ukraine',
    latitude: 49.8397,
    longitude: 24.0297,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Minsk',
    country: 'Belarus',
    latitude: 53.9006,
    longitude: 27.5590,
    timezoneOffsetHours: 3,
  ),
  AstroCity(
    name: 'Chisinau',
    country: 'Moldova',
    latitude: 47.0105,
    longitude: 28.8638,
    timezoneOffsetHours: 2,
  ),
  // Caucasus
  AstroCity(
    name: 'Tbilisi',
    country: 'Georgia',
    latitude: 41.7151,
    longitude: 44.8271,
    timezoneOffsetHours: 4,
  ),
  AstroCity(
    name: 'Batumi',
    country: 'Georgia',
    latitude: 41.6168,
    longitude: 41.6367,
    timezoneOffsetHours: 4,
  ),
  AstroCity(
    name: 'Yerevan',
    country: 'Armenia',
    latitude: 40.1792,
    longitude: 44.4991,
    timezoneOffsetHours: 4,
  ),
  AstroCity(
    name: 'Baku',
    country: 'Azerbaijan',
    latitude: 40.4093,
    longitude: 49.8671,
    timezoneOffsetHours: 4,
  ),
  // Baltics
  AstroCity(
    name: 'Riga',
    country: 'Latvia',
    latitude: 56.9496,
    longitude: 24.1052,
    timezoneOffsetHours: 2,
  ),

  // Central & Western Europe
  AstroCity(
    name: 'Warsaw',
    country: 'Poland',
    latitude: 52.2297,
    longitude: 21.0122,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Prague',
    country: 'Czechia',
    latitude: 50.0755,
    longitude: 14.4378,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Bucharest',
    country: 'Romania',
    latitude: 44.4268,
    longitude: 26.1025,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Sofia',
    country: 'Bulgaria',
    latitude: 42.6977,
    longitude: 23.3219,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Belgrade',
    country: 'Serbia',
    latitude: 44.7866,
    longitude: 20.4489,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Athens',
    country: 'Greece',
    latitude: 37.9838,
    longitude: 23.7275,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Istanbul',
    country: 'Turkey',
    latitude: 41.0082,
    longitude: 28.9784,
    timezoneOffsetHours: 3,
  ),
  // UK & Ireland
  AstroCity(
    name: 'London',
    country: 'United Kingdom',
    latitude: 51.5074,
    longitude: -0.1278,
    timezoneOffsetHours: 0,
  ),
  AstroCity(
    name: 'Manchester',
    country: 'United Kingdom',
    latitude: 53.4808,
    longitude: -2.2426,
    timezoneOffsetHours: 0,
  ),
  AstroCity(
    name: 'Dublin',
    country: 'Ireland',
    latitude: 53.3498,
    longitude: -6.2603,
    timezoneOffsetHours: 0,
  ),
  // Western Europe
  AstroCity(
    name: 'Paris',
    country: 'France',
    latitude: 48.8566,
    longitude: 2.3522,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Berlin',
    country: 'Germany',
    latitude: 52.5200,
    longitude: 13.4050,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Munich',
    country: 'Germany',
    latitude: 48.1351,
    longitude: 11.5820,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Madrid',
    country: 'Spain',
    latitude: 40.4168,
    longitude: -3.7038,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Barcelona',
    country: 'Spain',
    latitude: 41.3874,
    longitude: 2.1686,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Lisbon',
    country: 'Portugal',
    latitude: 38.7223,
    longitude: -9.1393,
    timezoneOffsetHours: 0,
  ),
  AstroCity(
    name: 'Rome',
    country: 'Italy',
    latitude: 41.9028,
    longitude: 12.4964,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Milan',
    country: 'Italy',
    latitude: 45.4642,
    longitude: 9.1900,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Amsterdam',
    country: 'Netherlands',
    latitude: 52.3676,
    longitude: 4.9041,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Brussels',
    country: 'Belgium',
    latitude: 50.8503,
    longitude: 4.3517,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Vienna',
    country: 'Austria',
    latitude: 48.2082,
    longitude: 16.3738,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Zurich',
    country: 'Switzerland',
    latitude: 47.3769,
    longitude: 8.5417,
    timezoneOffsetHours: 1,
  ),
  // Scandinavia
  AstroCity(
    name: 'Stockholm',
    country: 'Sweden',
    latitude: 59.3293,
    longitude: 18.0686,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Oslo',
    country: 'Norway',
    latitude: 59.9139,
    longitude: 10.7522,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Copenhagen',
    country: 'Denmark',
    latitude: 55.6761,
    longitude: 12.5683,
    timezoneOffsetHours: 1,
  ),
  AstroCity(
    name: 'Helsinki',
    country: 'Finland',
    latitude: 60.1699,
    longitude: 24.9384,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Reykjavik',
    country: 'Iceland',
    latitude: 64.1466,
    longitude: -21.9426,
    timezoneOffsetHours: 0,
  ),
  // North America
  AstroCity(
    name: 'New York',
    country: 'United States',
    latitude: 40.7128,
    longitude: -74.0060,
    timezoneOffsetHours: -5,
  ),
  AstroCity(
    name: 'Los Angeles',
    country: 'United States',
    latitude: 34.0522,
    longitude: -118.2437,
    timezoneOffsetHours: -8,
  ),
  AstroCity(
    name: 'Chicago',
    country: 'United States',
    latitude: 41.8781,
    longitude: -87.6298,
    timezoneOffsetHours: -6,
  ),
  AstroCity(
    name: 'San Francisco',
    country: 'United States',
    latitude: 37.7749,
    longitude: -122.4194,
    timezoneOffsetHours: -8,
  ),
  AstroCity(
    name: 'Seattle',
    country: 'United States',
    latitude: 47.6062,
    longitude: -122.3321,
    timezoneOffsetHours: -8,
  ),
  AstroCity(
    name: 'Miami',
    country: 'United States',
    latitude: 25.7617,
    longitude: -80.1918,
    timezoneOffsetHours: -5,
  ),
  AstroCity(
    name: 'Toronto',
    country: 'Canada',
    latitude: 43.6532,
    longitude: -79.3832,
    timezoneOffsetHours: -5,
  ),
  AstroCity(
    name: 'Vancouver',
    country: 'Canada',
    latitude: 49.2827,
    longitude: -123.1207,
    timezoneOffsetHours: -8,
  ),
  AstroCity(
    name: 'Mexico City',
    country: 'Mexico',
    latitude: 19.4326,
    longitude: -99.1332,
    timezoneOffsetHours: -6,
  ),
  // South America
  AstroCity(
    name: 'Sao Paulo',
    country: 'Brazil',
    latitude: -23.5505,
    longitude: -46.6333,
    timezoneOffsetHours: -3,
  ),
  AstroCity(
    name: 'Rio de Janeiro',
    country: 'Brazil',
    latitude: -22.9068,
    longitude: -43.1729,
    timezoneOffsetHours: -3,
  ),
  AstroCity(
    name: 'Buenos Aires',
    country: 'Argentina',
    latitude: -34.6037,
    longitude: -58.3816,
    timezoneOffsetHours: -3,
  ),
  AstroCity(
    name: 'Lima',
    country: 'Peru',
    latitude: -12.0464,
    longitude: -77.0428,
    timezoneOffsetHours: -5,
  ),

  AstroCity(
    name: 'Vilnius',
    country: 'Lithuania',
    latitude: 54.6872,
    longitude: 25.2797,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Tallinn',
    country: 'Estonia',
    latitude: 59.4370,
    longitude: 24.7536,
    timezoneOffsetHours: 2,
  ),

  // East Asia
  AstroCity(
    name: 'Tokyo',
    country: 'Japan',
    latitude: 35.6762,
    longitude: 139.6503,
    timezoneOffsetHours: 9,
  ),
  AstroCity(
    name: 'Osaka',
    country: 'Japan',
    latitude: 34.6937,
    longitude: 135.5023,
    timezoneOffsetHours: 9,
  ),
  AstroCity(
    name: 'Seoul',
    country: 'South Korea',
    latitude: 37.5665,
    longitude: 126.9780,
    timezoneOffsetHours: 9,
  ),
  AstroCity(
    name: 'Beijing',
    country: 'China',
    latitude: 39.9042,
    longitude: 116.4074,
    timezoneOffsetHours: 8,
  ),
  AstroCity(
    name: 'Shanghai',
    country: 'China',
    latitude: 31.2304,
    longitude: 121.4737,
    timezoneOffsetHours: 8,
  ),
  AstroCity(
    name: 'Hong Kong',
    country: 'China',
    latitude: 22.3193,
    longitude: 114.1694,
    timezoneOffsetHours: 8,
  ),
  // South & Southeast Asia
  AstroCity(
    name: 'Singapore',
    country: 'Singapore',
    latitude: 1.3521,
    longitude: 103.8198,
    timezoneOffsetHours: 8,
  ),
  AstroCity(
    name: 'Bangkok',
    country: 'Thailand',
    latitude: 13.7563,
    longitude: 100.5018,
    timezoneOffsetHours: 7,
  ),
  AstroCity(
    name: 'Delhi',
    country: 'India',
    latitude: 28.6139,
    longitude: 77.2090,
    timezoneOffsetHours: 5.5,
  ),
  AstroCity(
    name: 'Mumbai',
    country: 'India',
    latitude: 19.0760,
    longitude: 72.8777,
    timezoneOffsetHours: 5.5,
  ),
  // Middle East & Africa
  AstroCity(
    name: 'Dubai',
    country: 'United Arab Emirates',
    latitude: 25.2048,
    longitude: 55.2708,
    timezoneOffsetHours: 4,
  ),
  AstroCity(
    name: 'Tel Aviv',
    country: 'Israel',
    latitude: 32.0853,
    longitude: 34.7818,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Cairo',
    country: 'Egypt',
    latitude: 30.0444,
    longitude: 31.2357,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Johannesburg',
    country: 'South Africa',
    latitude: -26.2041,
    longitude: 28.0473,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Cape Town',
    country: 'South Africa',
    latitude: -33.9249,
    longitude: 18.4241,
    timezoneOffsetHours: 2,
  ),
  AstroCity(
    name: 'Nairobi',
    country: 'Kenya',
    latitude: -1.2921,
    longitude: 36.8219,
    timezoneOffsetHours: 3,
  ),
  // Oceania
  AstroCity(
    name: 'Sydney',
    country: 'Australia',
    latitude: -33.8688,
    longitude: 151.2093,
    timezoneOffsetHours: 10,
  ),
  AstroCity(
    name: 'Melbourne',
    country: 'Australia',
    latitude: -37.8136,
    longitude: 144.9631,
    timezoneOffsetHours: 10,
  ),
  AstroCity(
    name: 'Auckland',
    country: 'New Zealand',
    latitude: -36.8509,
    longitude: 174.7645,
    timezoneOffsetHours: 12,
  ),
];

/// Case-insensitive city search; prefix matches first, capped at [limit].
List<AstroCity> searchAstroCities(String query, {int limit = 12}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final starts = <AstroCity>[];
  final contains = <AstroCity>[];
  for (final city in astroCities) {
    final name = city.name.toLowerCase();
    if (name.startsWith(q)) {
      starts.add(city);
    } else if (name.contains(q) || city.country.toLowerCase().contains(q)) {
      contains.add(city);
    }
  }
  final result = [...starts, ...contains];
  return result.length <= limit ? result : result.sublist(0, limit);
}
