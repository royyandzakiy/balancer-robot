#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlExtensionPlugin>

#ifdef APP_ENABLE_SPIX
#include <Spix/AnyRpcServer.h>
#include <Spix/QtQmlBot.h>
#endif

// The App QML module (qml/) is a static library; this pulls its plugin into the binary.
Q_IMPORT_QML_PLUGIN(AppPlugin)

auto main(int argc, char *argv[]) -> int {
	const QGuiApplication app(argc, argv);
	QGuiApplication::setApplicationName(APP_NAME);
	QGuiApplication::setApplicationVersion(APP_VERSION);

	QQuickStyle::setStyle("Fusion");

	QQmlApplicationEngine engine;
	QObject::connect(
		&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(-1); },
		Qt::QueuedConnection);
	engine.loadFromModule("App", "Main");

#ifdef APP_ENABLE_SPIX
	// UI automation for test/e2e/ (ENABLE_SPIX=ON test builds only). Port from SPIX_PORT, default 9000.
	const int spix_port = qEnvironmentVariableIsSet("SPIX_PORT") ? qEnvironmentVariableIntValue("SPIX_PORT") : 9000;
	spix::AnyRpcServer spix_server(spix_port);
	spix::QtQmlBot spix_bot;
	spix_bot.runTestServer(spix_server);
#endif

	return QGuiApplication::exec();
}
