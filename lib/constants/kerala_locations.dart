/// Kerala districts and major cities/pincodes for heat map and location selection.
class KeralaLocations {
  KeralaLocations._();

  /// All 14 districts of Kerala with their major cities
  static const Map<String, List<String>> districtCities = {
    'Thiruvananthapuram': [
      'Thiruvananthapuram', 'Neyyattinkara', 'Attingal', 'Nedumangad',
      'Varkala', 'Kattakada', 'Kazhakkoottam', 'Pothencode',
    ],
    'Kollam': [
      'Kollam', 'Punalur', 'Karunagappally', 'Kottarakkara',
      'Paravur', 'Chavara', 'Anchal',
    ],
    'Pathanamthitta': [
      'Pathanamthitta', 'Adoor', 'Thiruvalla', 'Pandalam',
      'Ranni', 'Kozhencherry',
    ],
    'Alappuzha': [
      'Alappuzha', 'Cherthala', 'Kayamkulam', 'Mavelikkara',
      'Ambalapuzha', 'Haripad', 'Chengannur',
    ],
    'Kottayam': [
      'Kottayam', 'Changanassery', 'Pala', 'Ettumanoor',
      'Vaikom', 'Erattupetta', 'Kanjirapally',
    ],
    'Idukki': [
      'Painavu', 'Thodupuzha', 'Munnar', 'Adimali',
      'Kattappana', 'Nedumkandam', 'Devikulam',
    ],
    'Ernakulam': [
      'Kochi', 'Ernakulam', 'Aluva', 'Perumbavoor',
      'Angamaly', 'Muvattupuzha', 'Kothamangalam',
      'North Paravur', 'Thrippunithura', 'Kalamassery',
    ],
    'Thrissur': [
      'Thrissur', 'Chalakudy', 'Irinjalakuda', 'Kodungallur',
      'Guruvayur', 'Kunnamkulam', 'Chavakkad', 'Wadakkanchery',
    ],
    'Palakkad': [
      'Palakkad', 'Ottapalam', 'Shoranur', 'Chittur',
      'Mannarkkad', 'Alathur', 'Pattambi', 'Nenmara',
    ],
    'Malappuram': [
      'Malappuram', 'Manjeri', 'Perinthalmanna', 'Tirur',
      'Ponnani', 'Tanur', 'Kondotty', 'Nilambur',
    ],
    'Kozhikode': [
      'Kozhikode', 'Vadakara', 'Koyilandy', 'Ramanattukara',
      'Feroke', 'Mukkom', 'Balussery', 'Thamarassery',
    ],
    'Wayanad': [
      'Kalpetta', 'Mananthavady', 'Sulthan Bathery',
      'Meenangadi', 'Vythiri',
    ],
    'Kannur': [
      'Kannur', 'Thalassery', 'Payyanur', 'Taliparamba',
      'Iritty', 'Mattannur', 'Anthoor', 'Kuthuparamba',
    ],
    'Kasaragod': [
      'Kasaragod', 'Kanhangad', 'Nileshwar', 'Manjeshwar',
      'Uppala', 'Bekal',
    ],
  };

  /// District center coordinates for heat map (lat, lng)
  static const Map<String, List<double>> districtCenters = {
    'Thiruvananthapuram': [8.5241, 76.9366],
    'Kollam': [8.8932, 76.6141],
    'Pathanamthitta': [9.2648, 76.7870],
    'Alappuzha': [9.4981, 76.3388],
    'Kottayam': [9.5916, 76.5222],
    'Idukki': [9.9189, 76.9290],
    'Ernakulam': [9.9816, 76.2999],
    'Thrissur': [10.5276, 76.2144],
    'Palakkad': [10.7867, 76.6548],
    'Malappuram': [11.0510, 76.0711],
    'Kozhikode': [11.2588, 75.7804],
    'Wayanad': [11.6854, 76.1320],
    'Kannur': [11.8745, 75.3704],
    'Kasaragod': [12.4996, 74.9869],
  };

  /// Kerala state bounds for map camera
  static const double keralaNorthLat = 12.8000;
  static const double keralaSouthLat = 8.2900;
  static const double keralaEastLng = 77.4200;
  static const double keralaWestLng = 74.8500;
  static const double keralaCenterLat = 10.5276;
  static const double keralaCenterLng = 76.2144;

  /// Get all cities as a flat list
  static List<String> get allCities {
    return districtCities.values.expand((cities) => cities).toList();
  }

  /// Get district for a given city
  static String? getDistrictForCity(String city) {
    for (final entry in districtCities.entries) {
      if (entry.value.contains(city)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get all district names
  static List<String> get districts => districtCities.keys.toList();
}
