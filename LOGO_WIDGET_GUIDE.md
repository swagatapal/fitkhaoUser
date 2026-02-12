# Logo Widget - Enhanced Responsive Design

## Overview
The `LogoWidget` has been enhanced with advanced responsive design features that ensure perfect display across all mobile device sizes, from the smallest iPhone SE (320px) to large devices and tablets.

## Location
`lib/shared/widgets/logo_widget.dart`

## Features

### ✅ Enhanced Responsive Design

#### 1. **Automatic Size Scaling**
The logo automatically adjusts its size based on device width:

| Device Type | Width | Logo Height |
|-------------|-------|-------------|
| Very Small | < 320px | 45px |
| Small | 320-374px | 50px |
| Medium | 375-413px | 60px |
| Large | 414px+ | 70px |

#### 2. **Adaptive Border Width**
Border width adapts for better visual appearance:
- Small devices (< 320px) or logo < 50px: **2.0px**
- Standard devices: **2.5px**
- Large devices or logo > 65px: **3.0px**

#### 3. **Dynamic Letter Spacing**
Text spacing adjusts for optimal readability:
- Small devices: **-0.3** (tighter)
- Standard devices: **-0.5** (balanced)
- Large devices (> 414px): **-0.6** (looser)

#### 4. **Icon Weight Adjustment**
Checkmark icon weight adapts:
- Small devices: **400** (lighter)
- Standard devices: **500** (bolder)

#### 5. **Proportional Scaling**
All elements scale proportionally:
- Outer circle: **70%** of logo height
- Checkmark icon: **40%** of logo height
- Text size: **45%** of logo height
- Spacing: **Responsive** (6-9px based on device)

## Usage

### Basic Usage (Responsive)
```dart
// Automatically adapts to screen size
const LogoWidget()
```

### Custom Size
```dart
// Fixed size
const LogoWidget(height: 80)
```

### In AppBar
```dart
AppBar(
  title: const LogoWidget(),
  centerTitle: true,
)
```

### As Screen Header
```dart
Center(
  child: const LogoWidget(),
)
```

### Custom Size in Hero
```dart
Hero(
  tag: 'logo',
  child: const LogoWidget(height: 120),
)
```

## Responsive Behavior

### On iPhone SE (320×568)
```
Logo Height: 45px
Border Width: 2.0px
Letter Spacing: -0.3
Icon Weight: 400
Spacing: 6.4px
```

### On iPhone 13 (390×844)
```
Logo Height: 60px
Border Width: 2.5px
Letter Spacing: -0.5
Icon Weight: 500
Spacing: 8.0px
```

### On iPhone 14 Pro Max (430×932)
```
Logo Height: 70px
Border Width: 3.0px
Letter Spacing: -0.6
Icon Weight: 500
Spacing: 8.8px
```

## Component Breakdown

### 1. Container (Background Circle)
- **Size**: Equal to logo height
- **Color**: Primary green with 10% opacity
- **Shape**: Perfect circle

### 2. Outer Circle (Plate)
- **Size**: 70% of logo height
- **Border**: Adaptive width (2.0-3.0px)
- **Color**: Primary green
- **Shape**: Perfect circle

### 3. Checkmark Icon
- **Size**: 40% of logo height
- **Color**: Primary green
- **Weight**: Adaptive (400-500)
- **Position**: Centered in circle

### 4. Text
- **Content**: "fitkhao"
- **Size**: 45% of logo height
- **Weight**: Bold
- **Color**: Text primary
- **Spacing**: Adaptive (-0.3 to -0.6)
- **Height**: 1.2 (line height)

## Code Structure

```dart
class LogoWidget extends StatelessWidget {
  final double? width;   // Reserved for future use
  final double? height;  // Optional custom height

  @override
  Widget build(BuildContext context) {
    // 1. Calculate responsive sizes
    final logoHeight = height ?? context.logoSize;
    final spacing = context.responsiveSpacing(8.0);
    final borderWidth = _getBorderWidth(context, logoHeight);

    // 2. Calculate proportional sizes
    final outerCircleSize = logoHeight * 0.7;
    final checkIconSize = logoHeight * 0.4;
    final fontSize = logoHeight * 0.45;

    // 3. Build UI
    return Row(...);
  }

  // Helper methods for adaptive values
  double _getBorderWidth(BuildContext context, double logoHeight) { ... }
  double _getLetterSpacing(BuildContext context) { ... }
}
```

## Advanced Features

### 1. Text Overflow Protection
```dart
Text(
  'fitkhao',
  maxLines: 1,
  overflow: TextOverflow.visible,
)
```
Prevents text from breaking into multiple lines.

### 2. Center Alignment
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [...],
)
```
Ensures logo is centered when placed in flexible layouts.

### 3. Context-Aware Sizing
```dart
final logoHeight = height ?? context.logoSize;
```
Uses custom height if provided, otherwise uses responsive sizing.

## Testing on Different Devices

### Small Devices (iPhone SE - 320px)
```dart
// Logo appears smaller but still clear
// Tighter spacing for compact display
// Lighter icon weight for better clarity
```

### Medium Devices (iPhone 13 - 390px)
```dart
// Balanced size, standard appearance
// Default spacing and weights
// Optimal for most users
```

### Large Devices (iPhone 14 Pro Max - 430px)
```dart
// Larger, more prominent display
// Wider spacing for premium look
// Bolder elements for impact
```

## Performance Considerations

### ✅ Optimized
- All calculations done once per build
- No unnecessary rebuilds
- Efficient responsive queries
- Const constructor for widget reuse

### Best Practices
```dart
// ✅ Good - Widget caching
static const logoWidget = LogoWidget();

// ✅ Good - Conditional rendering
if (showLogo) const LogoWidget()

// ❌ Avoid - Creating in loops
ListView.builder(
  itemBuilder: (context, index) => const LogoWidget(), // OK if const
)
```

## Customization Examples

### Example 1: Different Size for Splash Screen
```dart
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Larger logo for splash
            const LogoWidget(height: 100),
            const SizedBox(height: 24),
            const Text('Welcome to FitKhao'),
          ],
        ),
      ),
    );
  }
}
```

### Example 2: AppBar Logo
```dart
AppBar(
  title: const LogoWidget(),
  centerTitle: true,
  backgroundColor: Colors.white,
  elevation: 0,
)
```

### Example 3: Animated Logo
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  child: LogoWidget(
    height: isExpanded ? 100 : 60,
  ),
)
```

## Accessibility

### Features
- ✅ Proper contrast ratios
- ✅ Scalable for all device sizes
- ✅ Clear visual hierarchy
- ✅ Readable text on all screens

### Semantic Label (Future Enhancement)
```dart
Semantics(
  label: 'FitKhao Logo',
  child: const LogoWidget(),
)
```

## Color Customization

While the logo uses theme colors, you can customize if needed:

```dart
// Current colors from AppColors
- Primary Green: #6B9F6E (logo icon)
- Primary Green 10%: Background circle
- Text Primary: #1A1A1A (logo text)

// To customize, edit:
// lib/core/constants/app_colors.dart
```

## Troubleshooting

### Issue 1: Logo appears too small on large devices
**Solution**: Already handled - logo scales up to 70px on devices > 414px

### Issue 2: Logo text overlaps on very small devices
**Solution**: Letter spacing automatically tightens to -0.3 on small devices

### Issue 3: Border too thick on small devices
**Solution**: Border width reduces to 2.0px on small devices

### Issue 4: Logo not centered
**Solution**: Wrap with `Center` widget or use in a `Row` with `MainAxisAlignment.center`

## Comparison: Before vs After Enhancement

### Before
```dart
// Basic responsive
- Fixed spacing
- Single border width
- Basic size scaling
- No letter spacing adjustment
```

### After (Enhanced)
```dart
✅ Adaptive border width (2.0-3.0px)
✅ Dynamic letter spacing (-0.3 to -0.6)
✅ Icon weight adjustment (400-500)
✅ Better small device handling
✅ Comprehensive documentation
✅ Helper methods for calculations
✅ Text overflow protection
✅ Line height control
```

## Integration Examples

### 1. Auth Screen
```dart
class PhoneAuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 40),
          Center(child: const LogoWidget()), // Auto-responsive
          SizedBox(height: 48),
          Text('Let\'s get you started!'),
          // ... rest of the screen
        ],
      ),
    );
  }
}
```

### 2. Loading Screen
```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const LogoWidget(height: 80),
      const SizedBox(height: 24),
      const CircularProgressIndicator(),
    ],
  ),
)
```

### 3. Profile Header
```dart
Row(
  children: [
    const LogoWidget(height: 40), // Smaller for header
    const SizedBox(width: 16),
    Text('FitKhao Premium'),
  ],
)
```

## Summary

The enhanced `LogoWidget` provides:

✅ **Fully Responsive** - Adapts to all device sizes automatically
✅ **Smart Scaling** - Proportional sizing of all elements
✅ **Adaptive Details** - Border width, spacing, and icon weight adjust
✅ **Performance** - Optimized calculations and const constructor
✅ **Flexibility** - Accepts custom size or uses automatic sizing
✅ **Production Ready** - Tested, documented, and maintainable

Use it anywhere in your app with confidence that it will look perfect on every device!
