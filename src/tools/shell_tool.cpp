#include "shell_tool.h"
#include <QProcess>
#include <QJsonObject>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QDir>

ShellTool::ShellTool(QObject *parent) : BaseTool(parent) {
    // 默认白名单：常用只读/安全命令
    m_allowedPrefixes = {
        "ls", "pwd", "whoami", "date", "echo",
        "cat", "head", "tail", "wc", "grep",
        "find", "which", "env", "uname",
        "mkdir"  // 允许创建目录
    };
}

QString ShellTool::description() const {
    return QStringLiteral("执行安全的 Shell 命令（白名单限制）。适用于列出目录、查看文件、获取系统信息等。");
}

QVariantMap ShellTool::parametersSchema() const {
    return QVariantMap{
        { "type", "object" },
        { "properties", QVariantMap{
            { "command", QVariantMap{
                { "type", "string" },
                { "description", "要执行的 Shell 命令（仅白名单允许）" }
            }}
        }},
        { "required", QVariantList{"command"} }
    };
}

void ShellTool::setAllowedPrefixes(const QStringList &prefixes) {
    m_allowedPrefixes = prefixes;
}

bool ShellTool::isAllowed(const QString &cmd) const {
    QString c = cmd.trimmed();
    if (c.isEmpty()) return false;

    QString first = c.split(QChar(' '), Qt::SkipEmptyParts).value(0);
    for (const QString &p : m_allowedPrefixes) {
        if (first == p || first.startsWith(p + QChar('/')))
            return true;
    }
    return false;
}

QString ShellTool::runCommand(const QString &cmd) {
    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("sh", QStringList{"-c", cmd}, QIODevice::ReadOnly);
    if (!proc.waitForFinished(15000)) {
        proc.kill();
        return QStringLiteral("{\"error\":\"命令超时或启动失败\"}");
    }

    QString stdoutStr = QString::fromUtf8(proc.readAllStandardOutput());
    int code = proc.exitCode();

    QJsonObject o;
    o["stdout"] = stdoutStr;
    o["exitCode"] = code;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString ShellTool::execute(const QVariantMap &args) {
    QString cmd = args.value("command").toString().trimmed();
    if (cmd.isEmpty()) {
        QString r = QStringLiteral("{\"error\":\"命令为空\"}");
        emit executionFinished(name(), r);
        return r;
    }

    if (!isAllowed(cmd)) {
        QString r = QStringLiteral("{\"error\":\"命令不在白名单中，拒绝执行: %1\"}").arg(cmd);
        emit executionFinished(name(), r);
        return r;
    }

    QString result = runCommand(cmd);
    emit executionFinished(name(), result);
    return result;
}
