# DesiHITTE25 🇮🇳🔥

**OTF-Style HIIT Workouts with Bollywood Music & Sole E25 Bluetooth Integration**

DesiHITTE25 is an iOS app that brings the Orangetheory Fitness experience home — powered by Bollywood beats and a bilingual Hindi/English voice coach. Connect your Sole E25 elliptical via Bluetooth for real-time heart rate zone tracking, automatic resistance suggestions, and Splat Point scoring.

## ✨ Features

### 🏋️ OTF-Style Heart Rate Zone Training
- **5 Heart Rate Zones**: Grey, Blue, Green, Orange, Red
- **Splat Points**: Earn points for every minute in Orange or Red zones
- **Auto-resistance suggestions**: The app tells you when to increase/decrease resistance based on your target zone

### 🎵 Bollywood Music Integration
- Curated playlists for each workout phase (high energy, moderate, cool down)
- YouTube-powered playback with auto-switching based on workout intensity
- Separate volume controls for music and voice coach

### 🗣️ Bilingual Voice Coach
- Motivational coaching in English + Hindi
- Audio ducking — music volume automatically lowers when coach speaks
- 20+ motivational phrases: "Chalo! Let's go!", "Bahut acche!", "Shandar!"
- Interval change announcements, countdowns, and zone transition alerts

### 📡 Bluetooth Integration
- Connects to **Sole E25** via FTMS (Fitness Machine Service)
- Reads: Heart rate, speed, cadence, power
- Writes: Resistance level control
- Auto-reconnection logic
- Simulator mock data for development

### 📊 Workout Templates
- **Endurance** 🏃‍♂️ — Long green/orange pushes with short recoveries
- **Power** ⚡ — Short all-out bursts with recovery periods
- **ESP** 🔥 — Endurance, Strength, Power mix

### 📱 Additional Features
- Workout history with SwiftData persistence
- Detailed post-workout summaries with zone breakdown
- Onboarding flow with BLE pairing walkthrough
- Shareable workout results
- Customizable settings (age, max HR, coach preferences)

## 📸 Screenshots

*Screenshots coming soon*

## 🛠️ Setup Instructions

### Prerequisites
- **Xcode 15+** (Swift 5.9+)
- **iOS 17.0+** deployment target
- macOS Sonoma or later

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/kirankaja/DesiHITTE25.git
   cd DesiHITTE25
   ```

2. **Create Xcode Project**
   - Open Xcode → File → New → Project
   - Choose **iOS → App**
   - Product Name: `DesiHITTE25`
   - Interface: **SwiftUI**
   - Storage: **SwiftData**
   - Bundle Identifier: `com.yourname.DesiHITTE25`

3. **Add Source Files**
   - Drag all `.swift` files from the `DesiHITTE25/` folder into the Xcode project
   - Ensure "Copy items if needed" is checked
   - Replace the generated `Info.plist` with the provided one

4. **Configure Signing**
   - Select the project in Xcode
   - Go to Signing & Capabilities
   - Select your development team
   - Enable **Background Modes** capability:
     - ✅ Uses Bluetooth LE accessories
     - ✅ Audio, AirPlay, and Picture in Picture

5. **Build & Run**
   - Select your iPhone or Simulator
   - Press `Cmd + R` to build and run
   - In Simulator, mock BLE data is automatically used

## 🏗️ Architecture

```
DesiHITTE25/
├── DesiHITTE25App.swift          # App entry point, SwiftData setup
├── Info.plist                     # BLE & audio permissions
├── Models/
│   ├── WorkoutZone.swift          # 5 HR zones with colors & ranges
│   ├── WorkoutTemplate.swift      # Workout templates (Endurance/Power/ESP)
│   ├── WorkoutSession.swift       # SwiftData model for history
│   └── BollywoodPlaylist.swift    # YouTube video ID playlists
├── Services/
│   ├── BluetoothManager.swift     # CoreBluetooth FTMS integration
│   ├── WorkoutEngine.swift        # Workout state machine & zone logic
│   ├── VoiceCoach.swift           # AVSpeechSynthesizer with ducking
│   └── YouTubePlayerManager.swift # WKWebView YouTube IFrame API
└── Views/
    ├── ContentView.swift          # Main TabView (Workout/History/Settings)
    ├── WorkoutView.swift          # Live workout screen
    ├── ZoneBarView.swift          # Animated 5-zone indicator bar
    ├── YouTubePlayerView.swift    # UIViewRepresentable WKWebView wrapper
    ├── WorkoutSummaryView.swift   # Post-workout stats & sharing
    ├── SettingsView.swift         # User preferences & device management
    ├── OnboardingView.swift       # First-launch setup wizard
    └── DevicePairingView.swift    # BLE device discovery & pairing
```

### Key Design Patterns
- **ObservableObject Services**: `BluetoothManager`, `WorkoutEngine`, `VoiceCoach`, `YouTubePlayerManager` are all `ObservableObject` classes with `@Published` properties
- **Combine**: Reactive data flow between services (HR updates → zone changes → music switches)
- **SwiftData**: Persistent storage for workout history and user profile
- **MVVM-ish**: Views observe service objects directly; no separate view models needed for this app size

### Bluetooth Protocol
- **Service**: FTMS (Fitness Machine Service, UUID: 0x1826)
- **Heart Rate**: UUID 0x2A37 (standard HR measurement)
- **Indoor Bike Data**: UUID 0x2AD2 (speed, cadence, power, resistance)
- **Machine Control Point**: UUID 0x2AD9 (write resistance level)

## 📝 Notes

- The `.xcodeproj` file is not included — create a new Xcode project and add these source files
- YouTube playback requires an internet connection
- BLE features require a physical device (simulator uses mock data via `#if targetEnvironment(simulator)`)
- Bollywood song video IDs reference popular YouTube videos; availability may vary by region

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

**Made with ❤️ and Bollywood beats** 🇮🇳🎵
