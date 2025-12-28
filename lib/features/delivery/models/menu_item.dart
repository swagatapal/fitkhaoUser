/// Model representing a menu food item
class MenuItem {
  final String id;
  final String name;
  final String imageUrl;
  final int calories;
  final double price;
  final String category; // 'bmiMaintainance', 'fatLoss', 'leanMassGain', etc.
  final bool isVeg;
  final String description;
  final String protein; // e.g., "12g"
  final String carbs; // e.g., "40g"
  final String fats; // e.g., "8g"
  final String fiber; // e.g., "6g"
  final String menuType; // veg, nonVeg, eggetarian, vegan
  final String mealType; // breakfast, lunch, dinner
  final List<String> goalCategory;
  final bool isAvailable;
  final List<String> tags;
  final List<String> allergens;
  final double rating; // Rating out of 5
  final List<String> ingredients;
  final Map<String, dynamic> suitability;

  const MenuItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.calories,
    required this.price,
    required this.category,
    required this.isVeg,
    this.description = '',
    this.protein = '0g',
    this.carbs = '0g',
    this.fats = '0g',
    this.fiber = '0g',
    this.menuType = 'veg',
    this.mealType = 'lunch',
    this.goalCategory = const [],
    this.isAvailable = true,
    this.tags = const [],
    this.allergens = const [],
    this.rating = 0.0,
    this.ingredients = const [],
    this.suitability = const {},
  });

  /// Create MenuItem from API response
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Parse nutrition information
    final nutrition = json['nutrition'] as Map<String, dynamic>? ?? {};
    final energyKcal = (nutrition['energyKcal'] as num?)?.toDouble() ?? 0.0;
    final proteinGm = (nutrition['proteinGm'] as num?)?.toDouble() ?? 0.0;
    final fatGm = (nutrition['fatGm'] as num?)?.toDouble() ?? 0.0;
    final carbGm = (nutrition['carbGm'] as num?)?.toDouble() ?? 0.0;

    // Parse food type (veg, nonVeg)
    final foodType = (json['foodType'] as String?) ?? 'veg';
    final isVeg = foodType.toLowerCase() == 'veg';

    // Parse image
    final imageObj = json['image'] as Map<String, dynamic>?;
    final imageUrl = imageObj?['url'] as String? ?? '';

    // Use default image if URL is empty or null
    const defaultImageUrl = 'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg';
    final finalImageUrl = imageUrl.isEmpty ? defaultImageUrl : imageUrl;

    // Parse category (bmiMaintainance, fatLoss, leanMassGain, etc.)
    final category = (json['category'] as String?) ?? 'bmiMaintainance';

    // Map category to display name
    String displayCategory = 'BMI Maintenance';
    switch (category.toLowerCase()) {
      case 'bmimaintainance':
      case 'bmi-maintenance':
        displayCategory = 'BMI Maintenance';
        break;
      case 'fatloss':
      case 'fat-loss':
        displayCategory = 'Fat Loss';
        break;
      case 'leanmassgain':
      case 'lean-mass-gain':
        displayCategory = 'Lean Mass Gain';
        break;
      case 'musclegain':
      case 'muscle-gain':
        displayCategory = 'Muscle Gain';
        break;
      default:
        displayCategory = category;
    }

    // Parse ingredients
    final ingredients = (json['ingredients'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];

    // Parse suitability
    final suitability = json['suitability'] as Map<String, dynamic>? ?? {};

    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['dishName'] as String? ?? '',
      imageUrl: finalImageUrl,
      calories: energyKcal.toInt(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: displayCategory,
      isVeg: isVeg,
      description: json['description'] as String? ?? '',
      protein: '${proteinGm.toStringAsFixed(1)}g',
      carbs: '${carbGm.toStringAsFixed(1)}g',
      fats: '${fatGm.toStringAsFixed(1)}g',
      fiber: '0g', // API doesn't provide fiber
      menuType: foodType,
      mealType: (json['mealType'] as String?) ?? 'breakfast',
      goalCategory: [category], // Store original category
      isAvailable: json['isActive'] as bool? ?? true,
      tags: const [], // No tags in current API response
      allergens: const [], // No allergens in current API response
      rating: 0.0, // No rating in current API response
      ingredients: ingredients,
      suitability: suitability,
    );
  }

  // Mock data for demonstration
  static List<MenuItem> getMockMenuItems() {
    return [
      const MenuItem(
        id: '1',
        name: 'Protein Power Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 450,
        price: 99,
        category: 'Lean Mass Gain',
        isVeg: true,
        description: 'A wholesome blend of oats, fresh fruits, and honey for a nutritious start to your day.',
        protein: '12g',
        carbs: '40g',
        fats: '8g',
        fiber: '6g',
      ),
      const MenuItem(
        id: '2',
        name: 'Grilled Chicken Salad',
        imageUrl:
            'https://www.shutterstock.com/image-photo/fried-salmon-steak-cooked-green-600nw-2489026949.jpg',
        calories: 320,
        price: 99,
        category: 'Fat Loss',
        isVeg: false,
        description: 'Lean grilled chicken with fresh vegetables for a healthy meal.',
        protein: '25g',
        carbs: '15g',
        fats: '12g',
        fiber: '4g',
      ),
      const MenuItem(
        id: '3',
        name: 'Mediterranean Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 380,
        price: 99,
        category: 'Diet Maintain',
        isVeg: true,
        description: 'Balanced meal with hummus, falafel, and vegetables.',
        protein: '14g',
        carbs: '45g',
        fats: '10g',
        fiber: '8g',
      ),
      const MenuItem(
        id: '4',
        name: 'Paneer Tikka Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 480,
        price: 99,
        category: 'Lean Mass Gain',
        isVeg: true,
        description: 'Indian style paneer with spices and vegetables.',
        protein: '18g',
        carbs: '35g',
        fats: '20g',
        fiber: '5g',
      ),
      const MenuItem(
        id: '5',
        name: 'Tuna Salad',
        imageUrl:
            'https://www.shutterstock.com/image-photo/fried-salmon-steak-cooked-green-600nw-2489026949.jpg',
        calories: 280,
        price: 99,
        category: 'Fat Loss',
        isVeg: false,
        description: 'Fresh tuna with mixed greens.',
        protein: '30g',
        carbs: '10g',
        fats: '8g',
        fiber: '3g',
      ),
      const MenuItem(
        id: '6',
        name: 'Quinoa Buddha Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 360,
        price: 99,
        category: 'Diet Maintain',
        isVeg: true,
        description: 'Wholesome quinoa bowl with seasonal vegetables.',
        protein: '10g',
        carbs: '50g',
        fats: '9g',
        fiber: '7g',
      ),
    ];
  }
}
