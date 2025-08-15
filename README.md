<<<<<<< HEAD
# student_livestream_app_new

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
# Kadu Academy Mobile App

## Project Overview

The Kadu Academy Mobile App is a cross-platform application developed using **Flutter** for iOS and Android. This app serves as the student-facing counterpart to the Kadu Academy web platform, providing a seamless and engaging experience for online test-taking and result tracking.

The app's primary purpose is to allow students to access tests created by administrators on the web platform. It includes features for test-taking, real-time feedback, and secure access based on an admin-approved system.

## Key Features

  * **Cross-Platform Compatibility:** Developed with **Flutter**, the app runs natively on both iOS and Android from a single codebase.
  * **Secure User Authentication:** Students can securely log in to access their personalized test dashboard.
  * **Integrated Web-to-App Workflow:**
      * The app dynamically pulls test data from the **Firebase** backend.
      * Students can appear for tests created by administrators on the web platform.
      * Access to paid tests is controlled by an admin-approved system.
  * **Test-Taking Interface:** A clean, responsive UI for taking multiple-choice tests, with support for images and mathematical expressions.
  * **Results & Analytics:** Students can view their test results instantly. The app shows detailed feedback on correct and incorrect answers.
  * **User Management:** The app communicates with the Firebase backend to handle student access permissions, which are set by the web platform's admin.

## Technologies Used

  * **Frontend (Mobile App):**
      * **Flutter:** The UI toolkit used for building a single, beautiful codebase for both mobile platforms.
  * **Backend & Database:**
      * **Firebase:** The core backend for the entire ecosystem.
          * **Authentication:** Manages student and admin login sessions.
          * **Firestore:** The real-time database that syncs test data, results, and user permissions between the web platform and the app.
          * **Storage:** Hosts all test-related images for the app.

## How It Works

The app works in a synchronized ecosystem with the web platform.

1.  An administrator uses the web platform to create a test, including questions, options, images, and other details.
2.  The app pulls this new test data from the Firebase Firestore database.
3.  A student uses the app to take the test.
4.  Once submitted, the student's results are saved back to the Firestore database.
5.  The administrator can then log in to the web platform to view the results, approve/deny student access, or export the data.

This integrated workflow demonstrates a comprehensive, end-to-end solution for online test management.

## Setup and Installation

Follow these steps to set up the project locally.

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/yash-masne/kadu-academy-app.git
    ```

2.  **Navigate to the project directory:**

    ```bash
    cd kadu-academy-app
    ```

3.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

4.  **Configure Firebase:**

      * Ensure your Flutter project is connected to the same Firebase project as the web app.
      * Follow the official Firebase for Flutter documentation to set up the configuration files for your specific platform (e.g., `google-services.json` for Android, `GoogleService-Info.plist` for iOS).

5.  **Run the application:**

    ```bash
    flutter run
    ```

    (Ensure a device or emulator is connected) 
>>>>>>> 54111528c54ac2ec8fb800487ea77a40775c4cfa
