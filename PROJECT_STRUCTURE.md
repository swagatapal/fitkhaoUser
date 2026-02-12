# FitKhao User App - Project Structure

## Overview
This is a production-ready Flutter application with clean architecture, Riverpod state management, and a scalable folder structure.

## Folder Structure

```
lib/
├── core/                          # Core functionality
│   ├── constants/                 # App-wide constants
│   │   ├── app_colors.dart       # Color palette
│   │   ├── app_sizes.dart        # Sizing constants
│   │   └── app_strings.dart      # String constants
│   └── theme/                     # Theme configuration
│       └── app_theme.dart        # Material theme setup
│
├── features/                      # Feature modules
│   └── auth/                      # Authentication feature
│       ├── models/                # Data models
│       │   └── auth_state.dart   # Authentication state model
│       ├── providers/             # Riverpod providers
│       │   └── auth_provider.dart # Auth state management
│       └── screens/               # UI screens
│           └── phone_auth_screen.dart
│
├── shared/                        # Shared/Reusable components
│   └── widgets/                   # Reusable widgets
│       ├── custom_text_field.dart # Custom input field
│       ├── logo_widget.dart       # App logo
│       └── primary_button.dart    # Primary button
│
└── main.dart                      # App entry point
```

## Key Features

### 1. State Management
- **Riverpod**: Used for efficient and scalable state management
- **AuthProvider**: Manages authentication state
- **Reactive UI**: Automatic UI updates on state changes

### 2. Clean Architecture
- **Separation of Concerns**: Features, Core, and Shared modules
- **Scalability**: Easy to add new features
- **Maintainability**: Clear structure and organization

### 3. Reusable Components
- **Custom Widgets**: Button, TextField, Logo
- **Theme System**: Centralized theme configuration
- **Constants**: Centralized colors, sizes, strings

### 4. Production-Ready Features
- **Form Validation**: Phone number validation
- **Error Handling**: User-friendly error messages
- **Loading States**: Loading indicators
- **Responsive Design**: Adapts to different screen sizes

## Current Implementation

### Phone Authentication Screen
- Phone number input with country code picker
- 10-digit validation
- Terms and conditions checkbox
- Auto-fetch phone number (placeholder)
- Error handling with SnackBar
- Loading states

## Next Steps

### To Complete the Authentication Flow:
1. Create OTP verification screen
2. Integrate with backend API
3. Implement token storage
4. Add navigation with GoRouter

### API Integration Points:
- `auth_provider.dart` - Line 60: Send OTP API call
- `phone_auth_screen.dart` - Line 36: Auto-fetch phone number

## Dependencies

```yaml
# State Management
flutter_riverpod: ^2.6.1

# Routing
go_router: ^14.6.2

# UI/UX
google_fonts: ^6.2.1
country_code_picker: ^3.0.0

# HTTP & API
dio: ^5.7.0

# Utils
shared_preferences: ^2.3.5
```

## Running the App

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Design Principles

1. **Single Responsibility**: Each file has a single, well-defined purpose
2. **DRY (Don't Repeat Yourself)**: Reusable widgets and utilities
3. **SOLID Principles**: Applied throughout the codebase
4. **Performance**: Optimized with Riverpod for minimal rebuilds
5. **Accessibility**: Semantic widgets and proper labeling

## Color Scheme

- **Primary Green**: #6B9F6E
- **Light Green**: #9CCC9D
- **Dark Green**: #4A7C4D

## Notes

- All screens are ready for API integration
- Form validation is implemented
- Error handling is in place
- Loading states are managed
- TODO comments mark API integration points
