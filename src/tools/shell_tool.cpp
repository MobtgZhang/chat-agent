#include "shell_tool.h"
#include <QProcess>
#include <QJsonObject>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QDir>

ShellTool::ShellTool(QObject *parent) : BaseTool(parent) {
    // 默认白名单：常用只读/安全命令
    // Windows / Linux 兼容：命令名尽量选择两端都存在的子集
    m_allowedPrefixes = {
        QStringLiteral("ls"), QStringLiteral("dir"),
        QStringLiteral("pwd"),
        QStringLiteral("whoami"), QStringLiteral("date"), QStringLiteral("echo"),
        QStringLiteral("cat"), QStringLiteral("type"),
        QStringLiteral("head"), QStringLiteral("tail"),
        QStringLiteral("wc"), QStringLiteral("grep"),
        QStringLiteral("find"),
        QStringLiteral("which"), QStringLiteral("where"),
        QStringLiteral("env"),
        QStringLiteral("uname"),
        QStringLiteral("mkdir")  // 允许创建目录
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

#if defined(Q_OS_WIN)
    // Windows：使用 cmd.exe /C 执行命令
    QString shell = QStringLiteral("cmd.exe");
    QStringList args{QStringLiteral("/C"), cmd};
#else
    // Linux / macOS：使用 sh -c 执行命令
    QString shell = QStringLiteral("sh");
    QStringList args{QStringLiteral("-c"), cmd};
#endif

    proc.start(shell, args, QIODevice::ReadOnly);
    if (!proc.waitForFinished(15000)) {
        proc.kill();
        QJsonObject o;
        o["error"] = QStringLiteral("命令超时或启动失败");
        return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
    }

    const QString stdoutStr = QString::fromUtf8(proc.readAllStandardOutput());
    const int code = proc.exitCode();

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
