# Development

### Sprint

- v1
    - create gui design draft
    - add samples git submodule:
        - https://github.com/royyandzakiy/qt-logsfilter-gui
    - implement base qml-gui project
    - add functioning keypad buttons
    - add logs area (still with dummy logs)
        - logs can be added dynamically (+ multithreaded)
- v2
    - implement ble uart
        - add winrt via vcpkg
    - implement ble funcs: scan, connect, notify, send, show rssi
- v3
    - connect keypad input with ble send
    - connect notify with logs
- v4
    - add unit tests using gtest & pytest
    - consider refactor using [QML Modules](https://www.youtube.com/watch?v=gzoWIJQDA1c&list=PLJFB6-PFBLVMO0-f3H5KyLbFJ2i1Nkn3a&index=7&t=23456s) dan [QML Views & QAbstract](https://www.youtube.com/watch?v=gzoWIJQDA1c&list=PLJFB6-PFBLVMO0-f3H5KyLbFJ2i1Nkn3a&index=7&t=23456s)

---

### Project Structure

source: https://chat.deepseek.com/a/chat/s/b8bdbb47-ad21-4048-abbd-07476c56b902

```
wheel-balancer-app/
├── .vscode/                     # VSCode-specific configs
│   ├── launch.json
│   ├── tasks.json
│   └── settings.json
├── cmake/                       # CMake modules
│   └── FindQMLModules.cmake
├── src/
│   ├── main.cpp                 # Application entry point
│   ├── main.qml                 # Root QML file
│   ├── qml/                     # QML components
│   │   ├── components/          # Reusable UI components
│   │   │   ├── Button/
│   │   │   │   ├── PrimaryButton.qml
│   │   │   │   └── SecondaryButton.qml
│   │   │   ├── LogViewer.qml
│   │   │   └── RobotStatus.qml
│   │   ├── screens/             # Application screens/views
│   │   │   ├── Dashboard.qml
│   │   │   ├── LogsScreen.qml
│   │   │   └── ControlScreen.qml
│   │   ├── dialogs/             # Modal dialogs
│   │   │   ├── ConnectDialog.qml
│   │   │   └── SettingsDialog.qml
│   │   └── themes/              # Style/Theming
│   │       ├── Colors.qml
│   │       ├── Fonts.qml
│   │       └── Metrics.qml
│   ├── core/                    # C++ business logic
│   │   ├── CMakeLists.txt
│   │   ├── ble/
│   │   │   ├── BLEClient.h
│   │   │   ├── BLEClient.cpp
│   │   │   └── BLEManager.h
│   │   ├── robot/
│   │   │   ├── RobotController.h
│   │   │   ├── RobotController.cpp
│   │   │   └── commands/
│   │   ├── logging/
│   │   │   ├── LogManager.h
│   │   │   └── LogManager.cpp
│   │   └── models/              # QAbstractListModel derivatives
│   │       ├── LogModel.h
│   │       └── LogModel.cpp
│   └── utils/                   # Utilities
│       ├── Settings.h
│       ├── Validator.h
│       └── Formatters.h
├── resources/                   # Static resources
│   ├── images/
│   ├── fonts/
│   └── translations/            # i18n files
├── tests/                       # Unit/integration tests
│   ├── unit/
│   └── integration/
├── docs/                        # Documentation
│   ├── architecture.md
│   └── api/
├── thirdparty/                  # External dependencies
├── scripts/                     # Build/deployment scripts
├── CMakeLists.txt              # Root CMake
├── README.md
├── LICENSE
└── .gitignore
```