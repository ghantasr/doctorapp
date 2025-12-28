#!/bin/bash

# Run Doctor and Patient apps simultaneously on two iPhone simulators

echo "🏥 Starting Doctor App and Patient App on iPhones..."
echo ""

# Get the two booted iPhone simulators
IPHONE_1=$(xcrun simctl list devices | grep "iPhone.*Booted" | head -1 | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}')
IPHONE_2=$(xcrun simctl list devices | grep "iPhone.*Booted" | tail -1 | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}')

# Check if we have two different simulators
if [ -z "$IPHONE_1" ] || [ -z "$IPHONE_2" ]; then
    echo "❌ Error: Need two booted iPhone simulators"
    echo ""
    echo "Please boot two iPhone simulators:"
    echo "1. Open Xcode → Window → Devices and Simulators"
    echo "2. Or run: open -a Simulator"
    echo "3. Then File → New Simulator Window (to open second simulator)"
    exit 1
fi

if [ "$IPHONE_1" == "$IPHONE_2" ]; then
    echo "❌ Error: Only one iPhone simulator is booted"
    echo "Please boot a second iPhone simulator"
    exit 1
fi

echo "📱 Using iPhone simulators:"
echo "   iPhone 1: $IPHONE_1"
echo "   iPhone 2: $IPHONE_2"
echo ""

# Start Doctor App on first iPhone
echo "▶️  Starting Doctor App on first iPhone..."
flutter run -d $IPHONE_1 --dart-define=FLAVOR=doctor lib/main_doctor.dart &
DOCTOR_PID=$!

# Wait a moment
sleep 3

# Start Patient App on second iPhone
echo "▶️  Starting Patient App on second iPhone..."
flutter run -d $IPHONE_2 --dart-define=FLAVOR=patient lib/main_patient.dart &
PATIENT_PID=$!

echo ""
echo "✅ Both apps are running on iPhones"
echo ""
echo "Press Ctrl+C to stop both apps"
echo ""

# Wait for both processes
wait $DOCTOR_PID $PATIENT_PID
