#ifndef MEMORY_MODULE_H
#define MEMORY_MODULE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * Agent 记忆模块
 * 短期：滚动窗口对话历史（内存）
 * 长期：SQLite 存储用户偏好/事实
 */
class MemoryModule : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList shortTermMessages READ shortTermMessages NOTIFY shortTermMessagesChanged)
    Q_PROPERTY(QVariantList longTermFacts READ longTermFacts NOTIFY longTermFactsChanged)

public:
    explicit MemoryModule(QObject *parent = nullptr);
    ~MemoryModule();

    // 短期记忆（最近 N 轮对话）
    QVariantList shortTermMessages() const { return m_shortTerm; }
    void appendShortTerm(const QVariantMap &msg);
    void clearShortTerm();
    void setShortTermWindow(int count) { m_windowSize = qMax(1, count); }

    // 长期记忆
    QVariantList longTermFacts() const { return m_longTerm; }
    Q_INVOKABLE void addFact(const QString &key, const QString &value);
    Q_INVOKABLE void removeFact(const QString &key);
    Q_INVOKABLE void clearLongTerm();
    Q_INVOKABLE QString getFact(const QString &key) const;

    // 刷新长期记忆（从 DB 加载）
    Q_INVOKABLE void refreshLongTerm();

    // 构建注入到 prompt 的上下文
    QString buildContextForPrompt() const;

signals:
    void shortTermMessagesChanged();
    void longTermFactsChanged();

private:
    void trimShortTerm();
    void initDb();

    QVariantList m_shortTerm;
    QVariantList m_longTerm;
    int m_windowSize = 20;

    struct Db;
    Db *m_db = nullptr;
};

#endif // MEMORY_MODULE_H
