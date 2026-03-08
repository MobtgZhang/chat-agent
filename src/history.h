#ifndef HISTORY_H
#define HISTORY_H

#include <QObject>
#include <QVariantList>
#include <QString>
#include <QList>
#include <QDateTime>

// ── 树节点结构体 ──────────────────────────────────────────────────────────────
struct HistoryNode {
    QString  id;
    QString  type;      // "folder" | "session"
    QString  name;
    QString  parentId;  // 空字符串 = 根节点
    bool     expanded = true;
    qint64   createdAt = 0;
    qint64   updatedAt = 0;
};

// ── 历史管理器 ────────────────────────────────────────────────────────────────
class History : public QObject {
    Q_OBJECT

    // 供 QML 使用的展开后扁平树列表
    Q_PROPERTY(QVariantList flatNodes READ flatNodes NOTIFY flatNodesChanged)

public:
    explicit History(QObject *parent = nullptr);

    QVariantList flatNodes() const { return m_flatNodes; }

    // ── 节点操作 ──────────────────────────────────────────────────────────────
    Q_INVOKABLE QString createSession(const QString &name,
                                      const QString &parentId = QString());
    Q_INVOKABLE QString createFolder(const QString &name,
                                     const QString &parentId = QString());
    Q_INVOKABLE void    deleteNode(const QString &id);
    Q_INVOKABLE void    renameNode(const QString &id, const QString &name);
    Q_INVOKABLE void    toggleExpand(const QString &id);
    Q_INVOKABLE void    moveNode(const QString &id, const QString &newParentId);

    // ── 会话文件操作 ──────────────────────────────────────────────────────────
    Q_INVOKABLE QString sessionFilePath(const QString &id) const;
    Q_INVOKABLE void    touchSession(const QString &id); // 更新 updatedAt

    // ── 工具 ──────────────────────────────────────────────────────────────────
    Q_INVOKABLE QString firstSessionId() const;          // 最近的 session id

signals:
    void flatNodesChanged();

private:
    QList<HistoryNode> m_nodes;
    QVariantList       m_flatNodes;

    QString dataDir()     const;
    QString indexPath()   const;

    void loadIndex();
    void saveIndex();
    void rebuildFlat();          // 重建扁平列表

    // DFS 辅助：递归添加子节点到 flat list
    void appendChildren(const QString &parentId, int depth,
                        QVariantList &out) const;

    QString generateId() const;
    int     findIndex(const QString &id) const;  // 在 m_nodes 中查找
};

#endif // HISTORY_H

