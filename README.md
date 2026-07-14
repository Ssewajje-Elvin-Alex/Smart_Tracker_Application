##  Technologies Used

### Frontend (Mobile Application)
- Flutter
- Dart
- Google Maps Flutter Plugin
- REST API Integration

### Backend
- Django
- Django REST Framework
- SQLite/PostgreSQL Database
- JWT Authentication (if enabled)

### APIs & Services
- Google Maps Platform
- Google Maps JavaScript API
- Location Services

## Features

### Location Tracking
- Displays the tracker position on Google Maps
- Retrieves GPS coordinates from the backend
- Updates the marker position dynamically

### Emergency System
- Emergency button interface
- Emergency status indication
- Guardian notification workflow

### Device Monitoring
- Battery level tracking
- Current device status
## ⚙️ Setup Instructions

### Clone Repository

git clone https://github.com/Ssewajje-Elvin-Alex/Smart_Tracker_Application

Navigate to the Flutter application: cd smart_tracker_app

Install dependencies: flutter pub get

Run application: flutter run


Backend Setup

Navigate to backend: cd tracker_backend

Install dependencies: pip install -r requirements.txt

Run migrations: python manage.py migrate

Start server: python manage.py runserver 0.0.0.0:8000

🔑 Google Maps Configuration

The application uses Google Maps services.

Add your API key:

Android

android/app/src/main/AndroidManifest.xml
add this;
<meta-data
android:name="com.google.android.geo.API_KEY"
android:value="YOUR_API_KEY"/>

Web
web/index.html
add this inside <head> <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY"></script> 

- 
- 
