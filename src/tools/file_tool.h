#ifndef FILE_TOOL_H
#define FILE_TOOL_H

#include "base_tool.h"

/**
 * 文件操作工具：读、写、列目录
 * 支持相对路径和绝对路径，工作目录为应用数据目录的子目录
 */
class FileTool : public BaseTool {
    Q_OBJECT

public:
    explicit FileTool(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("file"); }
    QString description() const override;
    QVariantMap parametersSchema() const override;
    QString execute(const QVariantMap &args) override;

private:
    QString readFile(const QString &path);
    QString writeFile(const QString &path, const QString &content);
    QString listDir(const QString &path);
    QString createDir(const QString &path);
    QString safePath(const QString &path);
};

#endif // FILE_TOOL_H
