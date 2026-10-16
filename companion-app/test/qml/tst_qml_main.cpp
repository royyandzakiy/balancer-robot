#include <QtQml/QQmlExtensionPlugin>
#include <QtQuickTest>

// Runs every test/qml/tst_*.qml. The static App module is linked in, so tests `import App` and get
// the real components and C++ viewmodels.
Q_IMPORT_QML_PLUGIN(AppPlugin)

QUICK_TEST_MAIN(qml_tests)
