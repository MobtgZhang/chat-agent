#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "about.h"
#include "locale_bridge.h"
#include "settings.h"
#include "history.h"
#include "memory_module.h"
#include "mainview.h"
#include "clipboard_bridge.h"

int main(int argc, char *argv[]) {
    // 输入法设置（必须在创建 QGuiApplication 之前），同时兼容 X11 与 Wayland
    // 不在此处设置 QT_PLUGIN_PATH：若仅添加系统路径，会覆盖自定义 Qt 的插件搜索顺序，
    // 导致错误加载系统 Qt 的 sqldrivers/ssl，引发 QSQLITE、TLS 失败和 Segmentation fault。
    // 请通过 run.sh 或启动器正确设置（自定义 Qt plugins 路径需放最前）。
    // 2. Qt 6.7+ 支持 QT_IM_MODULES 多级 fallback；fcitx5 对应 libfcitx5platforminputcontextplugin.so
    qputenv("QT_IM_MODULES", "fcitx5;fcitx;wayland;ibus");
    qputenv("QT_IM_MODULE", "fcitx5");
    qputenv("XMODIFIERS", "@im=fcitx");  // X11/XWayland 需要

    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    app.setOrganizationName("ChatAgent");
    app.setApplicationName("ChatAgent");
    app.setApplicationVersion("1.3.0");

    // ── 后端对象 ──────────────────────────────────────────────────────────────
    About        about;
    Settings     settings;
    LocaleBridge locale(&settings);
    settings.setLocaleBridge(&locale);
    settings.refreshModels();
    History      history(&settings);
    MainView     mainView(&settings, &history);

    // ── QML 引擎 ──────────────────────────────────────────────────────────────
    QQmlApplicationEngine engine;
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("about",       &about);
    ctx->setContextProperty("locale",      &locale);
    ctx->setContextProperty("localeBridge", &locale);  // 独立名称，避免 Qt 6 内置 locale 覆盖
    ctx->setContextProperty("settings",    &settings);
    ctx->setContextProperty("history",     &history);
    ctx->setContextProperty("mainView",    &mainView);
    ClipboardBridge clipboardBridge;
    ctx->setContextProperty("clipboardBridge", &clipboardBridge);
    ctx->setContextProperty("agentMemory", static_cast<QObject*>(mainView.agentMemory()));

    const QUrl url(QStringLiteral("qrc:/src/qml/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
    );
    engine.load(url);

    return app.exec();
}

