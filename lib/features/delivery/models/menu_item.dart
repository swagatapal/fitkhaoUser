/// Model representing a menu food item
class MenuItem {
  final String id;
  final String name;
  final String imageUrl;
  final int calories;
  final double price;
  final double marketPrice;
  final double? discountPrice;
  final String category;
  final String categoryId;
  final String categoryName;
  final bool isVeg;
  final String description;
  final String protein;
  final String carbs;
  final String fats;
  final String fiber;
  final String menuType;
  final String mealType;
  final List<String> applicableMealTypes;
  final List<String> goalCategory;
  final bool isAvailable;
  final List<String> tags;
  final List<String> allergens;
  final double rating;
  final int ratingCount;
  final List<String> ingredients;
  final Map<String, dynamic> suitability;

  const MenuItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.calories,
    required this.price,
    this.marketPrice = 0,
    this.discountPrice,
    required this.category,
    this.categoryId = '',
    this.categoryName = '',
    required this.isVeg,
    this.description = '',
    this.protein = '0g',
    this.carbs = '0g',
    this.fats = '0g',
    this.fiber = '0g',
    this.menuType = 'veg',
    this.mealType = 'lunch',
    this.applicableMealTypes = const [],
    this.goalCategory = const [],
    this.isAvailable = true,
    this.tags = const [],
    this.allergens = const [],
    this.rating = 0.0,
    this.ratingCount = 0,
    this.ingredients = const [],
    this.suitability = const {},
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // ID: new API uses '_id', legacy uses 'id'
    final id = json['_id'] as String? ?? json['id'] as String? ?? '';

    // Category: new API uses object {_id, name}, legacy uses plain string
    final categoryRaw = json['category'];
    String catId = '';
    String catName = '';
    String legacyCatStr = '';
    if (categoryRaw is Map<String, dynamic>) {
      catId = categoryRaw['_id'] as String? ?? '';
      catName = categoryRaw['name'] as String? ?? '';
    } else if (categoryRaw is String) {
      legacyCatStr = categoryRaw;
    }

    // Name: new API uses 'dishName'
    final name = json['dishName'] as String? ?? json['name'] as String? ?? '';

    // Nutrition: new API uses 'nutritionalValue', legacy uses 'nutrition'
    final nutritionalValue = json['nutritionalValue'] as Map<String, dynamic>?;
    final legacyNutrition = json['nutrition'] as Map<String, dynamic>?;

    double kcal = 0, protein = 0, fat = 0, carbs = 0, fiber = 0;
    if (nutritionalValue != null) {
      kcal = (nutritionalValue['kcal'] as num?)?.toDouble() ?? 0;
      protein = (nutritionalValue['protein'] as num?)?.toDouble() ?? 0;
      fat = (nutritionalValue['fat'] as num?)?.toDouble() ?? 0;
      carbs = (nutritionalValue['carbs'] as num?)?.toDouble() ?? 0;
      fiber = (nutritionalValue['fiber'] as num?)?.toDouble() ?? 0;
    } else if (legacyNutrition != null) {
      kcal = (legacyNutrition['energyKcal'] as num?)?.toDouble() ?? 0;
      protein = (legacyNutrition['proteinGm'] as num?)?.toDouble() ?? 0;
      fat = (legacyNutrition['fatGm'] as num?)?.toDouble() ?? 0;
      carbs = (legacyNutrition['carbGm'] as num?)?.toDouble() ?? 0;
      fiber = (legacyNutrition['fiber'] as num?)?.toDouble() ?? 0;
    }

    // Dish type: new API uses 'dishType' array [{_id, dishType: "Veg"/"Non-Veg"}]
    bool isVeg = true;
    String menuType = 'veg';
    final dishTypeList = json['dishType'] as List<dynamic>?;
    if (dishTypeList != null && dishTypeList.isNotEmpty) {
      final firstType = dishTypeList[0] as Map<String, dynamic>?;
      final typeStr = firstType?['dishType'] as String? ?? 'Veg';
      isVeg = typeStr.toLowerCase() == 'veg';
      menuType = typeStr.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
    } else {
      final foodType = json['foodType'] as String? ?? 'veg';
      isVeg = foodType.toLowerCase() == 'veg';
      menuType = foodType;
    }

    // Image: new API sends `imageUrl` as a top-level string;
    // legacy API nested it inside `image.url`.
    const defaultImageUrl =
        'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg';
    final rawImageUrl = json['imageUrl'] as String? ??
        (json['image'] as Map<String, dynamic>?)?['url'] as String? ??
        '';
    final finalImageUrl = rawImageUrl.isEmpty ? defaultImageUrl : rawImageUrl;

    // Price: new API uses marketPrice / discountPrice
    final discountPrice = (json['discountPrice'] as num?)?.toDouble();
    final marketPrice = (json['marketPrice'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0.0;
    final price = discountPrice ?? marketPrice;

    // Applicable meal types derived from applicableDishCategory
    final applicableDishCategory =
        json['applicableDishCategory'] as Map<String, dynamic>?;
    final applicableMealTypes = <String>[];
    if (applicableDishCategory != null) {
      if (applicableDishCategory['breakfast'] == true) {
        applicableMealTypes.add('breakfast');
      }
      if (applicableDishCategory['lunch'] == true) {
        applicableMealTypes.add('lunch');
      }
      if (applicableDishCategory['dinner'] == true) {
        applicableMealTypes.add('dinner');
      }
      if (applicableDishCategory['snacks'] == true) {
        applicableMealTypes.add('snacks');
      }
    }
    final mealType = applicableMealTypes.isNotEmpty
        ? applicableMealTypes.first
        : (json['mealType'] as String? ?? 'breakfast');

    // Goal categories from applicableGoalType
    final applicableGoalType =
        json['applicableGoalType'] as Map<String, dynamic>?;
    final goalCategories = <String>[];
    if (applicableGoalType != null) {
      if (applicableGoalType['general'] == true) goalCategories.add('general');
      if (applicableGoalType['leanMass'] == true) goalCategories.add('leanMass');
      if (applicableGoalType['fatLoss'] == true) goalCategories.add('fatLoss');
    }

    // Display category label (goal-based)
    String displayCategory;
    if (goalCategories.contains('fatLoss')) {
      displayCategory = 'Fat Loss';
    } else if (goalCategories.contains('leanMass')) {
      displayCategory = 'Lean Mass Gain';
    } else if (goalCategories.contains('general')) {
      displayCategory = 'BMI Maintenance';
    } else {
      switch (legacyCatStr.toLowerCase()) {
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
        default:
          displayCategory = legacyCatStr.isNotEmpty ? legacyCatStr : 'General';
      }
    }

    if (goalCategories.isEmpty && legacyCatStr.isNotEmpty) {
      goalCategories.add(legacyCatStr);
    }

    return MenuItem(
      id: id,
      name: name,
      imageUrl: finalImageUrl,
      calories: kcal.toInt(),
      price: price,
      marketPrice: marketPrice,
      discountPrice: discountPrice,
      category: displayCategory,
      categoryId: catId,
      categoryName: catName.isNotEmpty ? catName : legacyCatStr,
      isVeg: isVeg,
      description:
          json['remarks'] as String? ?? json['description'] as String? ?? '',
      protein: '${protein.toStringAsFixed(1)}g',
      carbs: '${carbs.toStringAsFixed(1)}g',
      fats: '${fat.toStringAsFixed(1)}g',
      fiber: '${fiber.toStringAsFixed(1)}g',
      menuType: menuType,
      mealType: mealType,
      applicableMealTypes: applicableMealTypes,
      goalCategory: goalCategories.isNotEmpty ? goalCategories : [],
      isAvailable: json['isActive'] as bool? ?? true,
      tags: const [],
      allergens: const [],
      rating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      suitability: json['applicablePhysiologicalCategory'] as Map<String, dynamic>? ?? {},
    );
  }

  static List<MenuItem> getMockMenuItems() {
    return [
      const MenuItem(
        id: '1',
        name: 'Protein Power Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 450,
        price: 99,
        marketPrice: 120,
        discountPrice: 99,
        category: 'Lean Mass Gain',
        isVeg: true,
        description:
            'A wholesome blend of oats, fresh fruits, and honey for a nutritious start to your day.',
        protein: '12g',
        carbs: '40g',
        fats: '8g',
        fiber: '6g',
        applicableMealTypes: ['breakfast'],
      ),
      const MenuItem(
        id: '2',
        name: 'Grilled Chicken Salad',
        imageUrl:
            'https://www.shutterstock.com/image-photo/fried-salmon-steak-cooked-green-600nw-2489026949.jpg',
        calories: 320,
        price: 99,
        marketPrice: 130,
        discountPrice: 99,
        category: 'Fat Loss',
        isVeg: false,
        description: 'Lean grilled chicken with fresh vegetables for a healthy meal.',
        protein: '25g',
        carbs: '15g',
        fats: '12g',
        fiber: '4g',
        applicableMealTypes: ['lunch'],
      ),
      const MenuItem(
        id: '3',
        name: 'Mediterranean Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 380,
        price: 99,
        marketPrice: 110,
        category: 'Diet Maintain',
        isVeg: true,
        description: 'Balanced meal with hummus, falafel, and vegetables.',
        protein: '14g',
        carbs: '45g',
        fats: '10g',
        fiber: '8g',
        applicableMealTypes: ['lunch', 'dinner'],
      ),
      const MenuItem(
        id: '4',
        name: 'Paneer Tikka Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 480,
        price: 99,
        marketPrice: 140,
        discountPrice: 99,
        category: 'Lean Mass Gain',
        isVeg: true,
        description: 'Indian style paneer with spices and vegetables.',
        protein: '18g',
        carbs: '35g',
        fats: '20g',
        fiber: '5g',
        applicableMealTypes: ['dinner'],
      ),
      const MenuItem(
        id: '5',
        name: 'Tuna Salad',
        imageUrl:
            'https://www.shutterstock.com/image-photo/fried-salmon-steak-cooked-green-600nw-2489026949.jpg',
        calories: 280,
        price: 99,
        marketPrice: 100,
        category: 'Fat Loss',
        isVeg: false,
        description: 'Fresh tuna with mixed greens.',
        protein: '30g',
        carbs: '10g',
        fats: '8g',
        fiber: '3g',
        applicableMealTypes: ['lunch'],
      ),
      const MenuItem(
        id: '6',
        name: 'Quinoa Buddha Bowl',
        imageUrl:
            'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
        calories: 360,
        price: 99,
        marketPrice: 115,
        category: 'Diet Maintain',
        isVeg: true,
        description: 'Wholesome quinoa bowl with seasonal vegetables.',
        protein: '10g',
        carbs: '50g',
        fats: '9g',
        fiber: '7g',
        applicableMealTypes: ['breakfast', 'lunch'],
      ),
    ];
  }
}
