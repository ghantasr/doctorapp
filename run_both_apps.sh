#!/bin/bash

# Run Doctor and Patient apps simultaneously on different ports

echo "🏥 Starting Doctor App and Patient App..."
echo ""

# Kill any existing Flutter processes on these ports
lsof -ti:5001 | xargs kill -9 2>/dev/null
lsof -ti:5002 | xargs kill -9 2>/dev/null

# Start Doctor App on port 5001
echo "▶️  Starting Doctor App on http://localhost:5001"
flutter run -d chrome --web-port=5001 --dart-define=FLAVOR=doctor lib/main_doctor.dart &
DOCTOR_PID=$!

# Wait a moment
sleep 2

# Start Patient App on port 5002
echo "▶️  Starting Patient App on http://localhost:5002"
flutter run -d chrome --web-port=5002 --dart-define=FLAVOR=patient lib/main_patient.dart &
PATIENT_PID=$!

echo ""
echo "✅ Both apps are running:"
echo "   Doctor App:  http://localhost:5001"
echo "   Patient App: http://localhost:5002"
echo ""
echo "Press Ctrl+C to stop both apps"
echo ""

# Wait for both processes
wait $DOCTOR_PID $PATIENT_PID
