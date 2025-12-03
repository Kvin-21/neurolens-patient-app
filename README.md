# NeuroLens Patient

Patient app for daily voice recording sessions for Neurolens.

## Setup

1. Install Flutter 3.4.3+
2. Clone: `git clone https://github.com/Kvin-21/neurolens-patient.git`
3. Install deps: `flutter pub get`
4. Run: `flutter run`

## Requirements

- Android 7.0+
- Microphone permission
- ~100MB storage

## How It Works

Patients answer 5 simple questions each day. Audio is saved locally as WAV files. A notification reminds them at 10am. Audio files are sent to backend ML models for output of MMSE scores

## Privacy

All processing happens on-device. Nothing identifiable leaves the phone.
