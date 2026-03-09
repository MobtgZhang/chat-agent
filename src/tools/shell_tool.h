#ifndef SHELL_TOOL_H
#define SHELL_TOOL_H

#include "base_tool.h"

/**
 * Shell 命令执行工具（安全沙箱）
 * 默认仅允许白名单命令，可配置
 */
class ShellTool : public BaseTool {
    Q_OBJECT

public:
    explicit ShellTool(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("shell"); }
    QString description() const override;
    QVariantMap parametersSchema() const override;
    QString execute(const QVariantMap &args) override;

    // 白名单：允许的命令前缀
    void setAllowedPrefixes(const QStringList &prefixes);
    QStringList allowedPrefixes() const { return m_allowedPrefixes; }

private:
    bool isAllowed(const QString &cmd) const;
    QString runCommand(const QString &cmd);

    QStringList m_allowedPrefixes;
};

#endif // SHELL_TOOL_H
