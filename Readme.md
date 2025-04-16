# Geo Bangladesh App

A Flutter application that interacts with a REST API to manage and display geographic entities in Bangladesh.

## Features

- Display a map centered on Bangladesh with markers for geographic entities
- Create new entities with title, location, and image
- View a list of all entities
- Edit existing entities
- Offline caching for working without internet connection
- Optional user authentication

## Project Structure

```
geo_bangladesh_app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── entity.dart
│   ├── screens/
│   │   ├── map_screen.dart
│   │   ├── entity_form_screen.dart
│   │   ├── entity_list_screen.dart
│   │   └── auth_screen.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── location_service.dart
│   │   ├── db_helper.dart
│   │   ├── mongodb_helper.dart
│   │   └── auth_service.dart
│   ├── utils/
│   │   └── image_utils.dart
│   └── widgets/
│       ├── app_drawer.dart
│       └── entity_card.dart
```

## Setup Instructions

1. Clone the repository
2. Make sure you have Flutter installed (version 2.17.0 or higher)
3. Run `flutter pub get` to install dependencies
4. Add your Google Maps API key:
    - The API key is already included in the AndroidManifest.xml file
    - For iOS, add it to the AppDelegate file
5. Run the app:
   ```
   flutter run
   ```

## Dependencies

- **google_maps_flutter**: For displaying maps and markers
- **http**: For API requests
- **dio**: For multipart form data uploads
- **image_picker**: For selecting/capturing images
- **flutter_image_compress**: For image resizing
- **location**: For accessing device location
- **cached_network_image**: For efficient image loading and caching
- **sqflite**: For local database storage (offline mode)
- **flutter_secure_storage**: For secure token storage (authentication)
- **mongo_dart**: For MongoDB integration (bonus feature)

## API Integration

The app interacts with a REST API at `https://labs.anontech.info/cse489/t3/api.php` with the following endpoints:

- **GET /api.php**: Fetch all entities
- **POST /api.php**: Create a new entity
- **PUT /api.php**: Update an existing entity

## Bonus Features

1. **Offline Caching**: The app stores entities in a local SQLite database for offline access.
2. **User Authentication**: Optional login/register functionality for secure API access.
3. **MongoDB Integration**: Entities can be synced with a MongoDB database.

## Development Notes

- The app uses the Drawer pattern for navigation between screens
- Images are resized to 800x600 before upload as per requirements
- The app handles both online and offline modes gracefully
- Error handling is implemented throughout the app