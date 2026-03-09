#include "websearch_tool.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QEventLoop>

WebSearchTool::WebSearchTool(QObject *parent) : BaseTool(parent) {
    m_nam = new QNetworkAccessManager(this);
}

QString WebSearchTool::description() const {
    return QStringLiteral("在网络上搜索信息。输入搜索关键词，返回相关摘要和链接。");
}

QVariantMap WebSearchTool::parametersSchema() const {
    return QVariantMap{
        { "type", "object" },
        { "properties", QVariantMap{
            { "query", QVariantMap{
                { "type", "string" },
                { "description", "搜索关键词" }
            }}
        }},
        { "required", QVariantList{"query"} }
    };
}

void WebSearchTool::doSearch(const QString &query) {
    QUrl url("https://api.duckduckgo.com/");
    QUrlQuery q;
    q.addQueryItem("q", query);
    q.addQueryItem("format", "json");
    url.setQuery(q);

    QNetworkRequest req(url);

    QEventLoop loop;
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    QJsonObject result;
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QString abstract = root["Abstract"].toString();
        QString abstractUrl = root["AbstractURL"].toString();
        QJsonArray related = root["RelatedTopics"].toArray();

        result["abstract"] = abstract.isEmpty() ? "(无摘要)" : abstract;
        result["url"] = abstractUrl;
        QJsonArray snippets;
        for (int i = 0; i < qMin(3, related.size()); ++i) {
            QJsonObject r = related[i].toObject();
            if (r.contains("Text"))
                snippets.append(r["Text"].toString());
        }
        result["related"] = snippets;
        result["success"] = true;
    } else {
        result["error"] = reply->errorString();
        result["success"] = false;
    }
    reply->deleteLater();

    m_pendingResult = QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
}

void WebSearchTool::onFinished() {
    // 用于异步回调（当前实现为同步）
}

QString WebSearchTool::execute(const QVariantMap &args) {
    QString query = args.value("query").toString().trimmed();
    if (query.isEmpty()) {
        QString r = QStringLiteral("{\"error\":\"搜索关键词为空\",\"success\":false}");
        emit executionFinished(name(), r);
        return r;
    }

    m_pendingQuery = query;
    doSearch(query);

    emit executionFinished(name(), m_pendingResult);
    return m_pendingResult;
}
