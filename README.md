# Apartment Management System (Aura Residence) 

## Overview

The Apartment Management System (Aura Residence) is a modern, premium mobile application developed using Flutter and Firebase. It provides a comprehensive and seamless solution for managing various aspects of apartment living. From managing multiple units and handling daily utilities to interacting with an AI-powered Support Center, this app is designed to deliver a luxury digital experience for both tenants and landlords.

## Features

### Property & Unit Management
- **Multi-Unit Switching:** Seamlessly switch between multiple managed units with a smooth UI.
- **Link Unit:** Submit requests to link newly purchased or rented units to your account.
- **Property Cataloging:** Owners can set custom pricing (monthly/yearly) and publish units for rent or sale directly to the public catalog.
- **Contract Management:** Track rental application statuses (Pending, Occupied, Awaiting Payment) and request contract terminations or extensions.

### Daily Utilities & Requests
- **Maintenance:** Submit and track maintenance requests.
- **Complaints:** Report and manage complaints within the apartment complex efficiently.
- **Parking:** Reserve and manage parking spaces.
- **Club House Requests:** Allow users to request the use of the club house for private events like birthday parties or gatherings.

### Administration & Finances
- **Member Management:** Maintain a secure database of apartment residents and manage their information.
- **Financial Tracking:** Keep track of income, expenses, outstanding balances, and overall financial management securely.

### AI Support & Communication
- **Smart Chatbot:** Integrated with Google Gemini AI to provide instant, intelligent support and answer resident queries 24/7.
- **Inbox & Notifications:** Real-time push notifications with unread badge indicators.
- **Important Broadcasts:** Global pop-up announcements from the management team.

### Modern UI/UX
- **Smooth Navigation:** Custom-built bottom navigation bar with intelligent scroll-to-top functionality.
- **Dynamic Greetings:** Time-based typewriter animation greetings on the home dashboard.
- **Premium Layouts:** Clean, elegant design mimicking 5-star hospitality applications.

## Technologies Used

- **Flutter:** A UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
- **Firebase:** A comprehensive app development platform providing Authentication, Cloud Firestore (Real-time Database), and Cloud Storage.
- **Google Gemini API:** Powering the intelligent Chatbot Support Center.
- **flutter_dotenv:** For secure environment variable management (API Keys).

---

## Getting Started

If you are cloning this repository, please note that **API Keys and Firebase Configuration files are hidden** in `.gitignore` for security reasons. Follow the steps below to run the app on your local machine.

### Prerequisites

- Ensure you have Flutter installed. If not, follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install).
- Set up a Firebase project and configure it according to the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup).
- Get a free API key for the Gemini Chatbot from [Google AI Studio](https://aistudio.google.com/).

### Installation & Configuration

**1. Clone the repository**
```bash
git clone [https://github.com/yourusername/Aura-Residence.git](https://github.com/yourusername/Aura-Residence.git)
cd Aura-Residence
```

**2. Install Dependencies**
```bash
flutter pub get
```

**3. Configure Firebase (Crucial Step)**
Because `lib/firebase_options.dart` and `google-services.json` are hidden, you **must** connect this app to your own Firebase project. Run the following command in your terminal and follow the prompts:
```bash
flutterfire configure
```
*This will automatically generate the required `firebase_options.dart` file for your machine.*

**4. Set Up Environment Variables (API Keys)**
This app uses a `.env` file to securely store the Google Gemini API key.
- Create a new file named `.env` in the root directory of the project (same level as `pubspec.yaml`).
- Add your Gemini API Key inside the file like this:
```env
GEMINI_API_KEY=your_gemini_api_key_here
``` 

**5. Run the Application**
Ensure you have an emulator running or a physical device connected.
```bash
flutter run
```

