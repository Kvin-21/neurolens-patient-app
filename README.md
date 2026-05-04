# NeuroLens Patient

Patient app that collects short daily voice recordings (5 questions), persists them locally, and securely uploads encrypted audio for remote ML processing and analysis for Neurolens

## Quick setup

1. Ensure Flutter (>= 3.0.0) is installed.
2. Clone the repo and fetch packages:

	```bash
	git clone https://github.com/Kvin-21/neurolens-patient-app.git
	cd neurolens-patient-app
	flutter pub get
	```

3. Run:

	```bash
	flutter run
	```

## Platform & requirements

- Android 7.0+
- Permissions: Microphone, and Notifications.
- ~150MB storage.

## How it works

- Patients answer 5 simple questions each day
- Each answer is recorded as a WAV file and saved locally.
- Audio is encrypted on-device using AES-GCM and the symmetric key is wrapped with the server RSA public key before files are sent to backend ML models for output of MMSE scores.
- A daily reminder is scheduled by default at 10:00

## Caregiver features

- A caregiver image upload screen allows authenticated caregivers to upload images of their paients and view summaries from the server.