#include "settings.h"

#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QDebug>

// ── 构造函数 ──────────────────────────────────────────────────────────────────
Settings::Settings(QObject *parent) : QObject(parent) {
    m_nam = new QNetworkAccessManager(this);
    load();
    refreshModels();   // ← 新增：启动时自动拉取最新模型列表
}


// ── 文件路径 ──────────────────────────────────────────────────────────────────
QString Settings::settingsFilePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/settings.json";
}

// ── Setters ───────────────────────────────────────────────────────────────────
void Settings::setApiKey(const QString &v)      { if (m_apiKey      != v) { m_apiKey      = v; emit apiKeyChanged(); } }
void Settings::setApiUrl(const QString &v)      { if (m_apiUrl      != v) { m_apiUrl      = v; emit apiUrlChanged(); } }
void Settings::setModelName(const QString &v)   { if (m_modelName   != v) { m_modelName   = v; emit modelNameChanged(); } }
void Settings::setTemperature(double v)         { if (m_temperature != v) { m_temperature = v; emit temperatureChanged(); } }
void Settings::setTopP(double v)                { if (m_topP        != v) { m_topP        = v; emit topPChanged(); } }
void Settings::setTopK(int v)                   { if (m_topK        != v) { m_topK        = v; emit topKChanged(); } }
void Settings::setMaxTokens(int v)              { if (m_maxTokens   != v) { m_maxTokens   = v; emit maxTokensChanged(); } }
void Settings::setSystemPrompt(const QString &v){ if (m_systemPrompt!= v) { m_systemPrompt= v; emit systemPromptChanged(); } }

// ── 模型列表管理 ──────────────────────────────────────────────────────────────
void Settings::addModel(const QString &model) {
    if (!model.trimmed().isEmpty() && !m_modelList.contains(model)) {
        m_modelList.append(model.trimmed());
        emit modelListChanged();
        save();
    }
}

void Settings::removeModel(const QString &model) {
    if (m_modelList.removeOne(model)) {
        if (m_modelName == model && !m_modelList.isEmpty())
            setModelName(m_modelList.first());
        emit modelListChanged();
        save();
    }
}

// ── 通过 API /models 自动刷新模型列表 ───────────────────────────────────────────
void Settings::refreshModels() {
    if (!m_nam) m_nam = new QNetworkAccessManager(this);

    // 从当前 apiUrl 推导出 /v1/models 地址（兼容 https://api.openai.com 或带 /v1 的端点）
    QUrl base(m_apiUrl);
    QString path = base.path();

    // 1) 如果没有 /v1，就先补 /v1
    const QString v1Segment = QStringLiteral("/v1");
    if (!path.contains(v1Segment)) {
        if (!path.endsWith(QLatin1Char('/')))
            path.append(QLatin1Char('/'));
        path.append(QStringLiteral("v1"));
    }

    // 2) 去掉可能已经带上的 /chat/completions
    const QString chatComp = QStringLiteral("/chat/completions");
    int idx = path.indexOf(chatComp);
    if (idx >= 0) {
        path = path.left(idx);
    }

    // 3) 补上 /models
    if (!path.endsWith(QLatin1Char('/')))
        path.append(QLatin1Char('/'));
    path.append(QStringLiteral("models"));

    base.setPath(path);

    QNetworkRequest req(base);
    if (!m_apiKey.isEmpty())
        req.setRawHeader("Authorization",
                         QByteArray("Bearer ") + m_apiKey.toUtf8());

    QNetworkReply *reply = m_nam->get(req);
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "refreshModels error:" << reply->errorString();
            return;
        }

        const QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject root = doc.object();

        // 尝试按 OpenAI 风格解析：{ "data": [ { "id": "xxx" }, ... ] }
        QStringList models;
        QJsonArray arr = root.value(QStringLiteral("data")).toArray();
        for (const QJsonValue &v : arr) {
            QJsonObject o = v.toObject();
            const QString id = o.value(QStringLiteral("id")).toString();
            if (!id.isEmpty())
                models.append(id);
        }

        if (models.isEmpty()) {
            qWarning() << "refreshModels: no models found in response";
            return;
        }

        m_modelList = models;
        // 当前模型不在列表中时，自动切到第一个
        if (!m_modelList.contains(m_modelName) && !m_modelList.isEmpty())
            setModelName(m_modelList.first());

        emit modelListChanged();
        save();
    });
}

// ── 持久化：保存 ──────────────────────────────────────────────────────────────
void Settings::save() {
    QJsonObject root;
    root["apiKey"]       = m_apiKey;
    root["apiUrl"]       = m_apiUrl;
    root["modelName"]    = m_modelName;
    root["temperature"]  = m_temperature;
    root["topP"]         = m_topP;
    root["topK"]         = m_topK;
    root["maxTokens"]    = m_maxTokens;
    root["systemPrompt"] = m_systemPrompt;

    QJsonArray models;
    for (const QString &m : m_modelList) models.append(m);
    root["modelList"] = models;

    QFile f(settingsFilePath());
    if (f.open(QIODevice::WriteOnly))
        f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

// ── 持久化：加载 ──────────────────────────────────────────────────────────────
void Settings::load() {
    QFile f(settingsFilePath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    if (root.isEmpty()) return;

    if (root.contains("apiKey"))       m_apiKey       = root["apiKey"].toString();
    if (root.contains("apiUrl"))       m_apiUrl       = root["apiUrl"].toString();
    if (root.contains("modelName"))    m_modelName    = root["modelName"].toString();
    if (root.contains("temperature"))  m_temperature  = root["temperature"].toDouble(0.7);
    if (root.contains("topP"))         m_topP         = root["topP"].toDouble(0.9);
    if (root.contains("topK"))         m_topK         = root["topK"].toInt(50);
    if (root.contains("maxTokens"))    m_maxTokens    = root["maxTokens"].toInt(4096);
    if (root.contains("systemPrompt")) m_systemPrompt = root["systemPrompt"].toString();

    if (root.contains("modelList")) {
        m_modelList.clear();
        for (const QJsonValue &v : root["modelList"].toArray())
            m_modelList.append(v.toString());
    }
}

