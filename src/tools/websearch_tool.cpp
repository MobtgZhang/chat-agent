#include "websearch_tool.h"
#include "settings.h"
#include "web_search_service.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

WebSearchTool::WebSearchTool(Settings *settings, QObject *parent) : BaseTool(parent), m_settings(settings) {
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
                { "description", "简短的搜索关键词（1-10个词，不要包含对话背景或冗长描述，如：\"Python 安装教程\"）" }
            }}
        }},
        { "required", QVariantList{"query"} }
    };
}

QString WebSearchTool::execute(const QVariantMap &args) {
    QString query = args.value("query").toString().trimmed();
    if (query.isEmpty()) {
        QString r = QStringLiteral("{\"error\":\"搜索关键词为空\",\"success\":false}");
        emit executionFinished(name(), r);
        return r;
    }

    QVector<QPair<QString, QString>> results = WebSearchService::search(query, m_settings, m_nam);

    QJsonObject result;
    QString engine = m_settings ? m_settings->searchEngine().trimmed().toLower() : QStringLiteral("duckduckgo");
    if (engine == QLatin1String("duckduckgo")) {
        result["searchUrl"] = QStringLiteral("https://html.duckduckgo.com/html/?q=%1").arg(QString::fromUtf8(QUrl::toPercentEncoding(query)));
    } else if (engine == QLatin1String("google")) {
        result["searchUrl"] = QStringLiteral("https://www.google.com/search?q=%1").arg(QString::fromUtf8(QUrl::toPercentEncoding(query)));
    } else if (engine == QLatin1String("bing")) {
        result["searchUrl"] = QStringLiteral("https://www.bing.com/search?q=%1").arg(QString::fromUtf8(QUrl::toPercentEncoding(query)));
    }
    result["success"] = true;

    QJsonArray snippets;
    QStringList summary;
    for (const auto &p : results) {
        QJsonObject item;
        item["title"] = p.first;
        item["url"] = p.second;
        snippets.append(item);
        summary.append(p.first);
    }
    result["related"] = snippets;
    if (results.isEmpty()) {
        result["abstract"] = result.contains("searchUrl")
            ? QStringLiteral("未解析到结果，请访问上方 searchUrl 手动搜索。")
            : QStringLiteral("未获取到搜索结果。");
    } else {
        result["abstract"] = summary.join(" | ");
    }

    m_pendingResult = QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
    emit executionFinished(name(), m_pendingResult);
    return m_pendingResult;
}
