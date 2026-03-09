#ifndef WEBSEARCH_TOOL_H
#define WEBSEARCH_TOOL_H

#include "base_tool.h"
#include <QNetworkAccessManager>

/**
 * 网络搜索工具（基于 DuckDuckGo 即时回答 API）
 * 用于 Agent 获取实时信息
 */
class WebSearchTool : public BaseTool {
    Q_OBJECT

public:
    explicit WebSearchTool(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("web_search"); }
    QString description() const override;
    QVariantMap parametersSchema() const override;
    QString execute(const QVariantMap &args) override;

private slots:
    void onFinished();

private:
    void doSearch(const QString &query);
    QString m_pendingQuery;
    QString m_pendingResult;
    QNetworkAccessManager *m_nam;
};

#endif // WEBSEARCH_TOOL_H
