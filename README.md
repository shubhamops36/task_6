# VisionFlow

VisionFlow is a Flutter camera-interface prototype for exploring a real-time computer-vision workflow across mobile and web.

## Demo

Expected web demo URL after the first successful GitHub Actions deployment: <https://shubhamops36.github.io/task_6/>.

Allow camera access when prompted. Camera access requires a supported device and a secure browser context (HTTPS or localhost).

## What works

- Opens a live camera preview when a camera is available.
- Shows a sample detection overlay that can be toggled on and off.
- Displays camera frame rate and a sample latency value in the interface.
- Provides a responsive Flutter UI for web, Android, and iOS.

The detection boxes, object labels, and latency are illustrative demo data. This prototype does not run a YOLO model or perform object detection; the camera frame rate is measured from the incoming camera stream.

## Run locally

Requires the Flutter SDK and a browser or camera-enabled device.

```sh
flutter pub get
flutter run -d chrome
```

To build the web app for the GitHub Pages project path:

```sh
flutter build web --release --base-href /task_6/
```

## Deployment

Pushing to `main` runs the workflow in `.github/workflows/deploy.yml`, builds the web app, and publishes it to GitHub Pages. The first deployment may take a few minutes to become available.
