#include "memory_module.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>

struct MemoryModule::Db {
    QSqlDatabase db;
    bool ok = false;
};

void MemoryModule::initDb() {
    if (m_db) return;

    m_db = new Db;
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
    path += "/agent_memory.db";

    m_db->db = QSqlDatabase::addDatabase("QSQLITE", "agent_memory");
    m_db->db.setDatabaseName(path);
    m_db->ok = m_db->db.open();

    if (m_db->ok) {
        QSqlQuery q(m_db->db);
        q.exec("CREATE TABLE IF NOT EXISTS facts ("
               "key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)");
    }
}

MemoryModule::MemoryModule(QObject *parent) : QObject(parent) {
    initDb();
    refreshLongTerm();
}

MemoryModule::~MemoryModule() {
    if (m_db) {
        m_db->db.close();
        // 必须先释放 QSqlDatabase 对连接句柄的引用，否则 removeDatabase 会报警
        m_db->db = QSqlDatabase();
        QSqlDatabase::removeDatabase("agent_memory");
        delete m_db;
    }
}

void MemoryModule::appendShortTerm(const QVariantMap &msg) {
    m_shortTerm.append(msg);
    trimShortTerm();
    emit shortTermMessagesChanged();
}

void MemoryModule::clearShortTerm() {
    m_shortTerm.clear();
    emit shortTermMessagesChanged();
}

void MemoryModule::trimShortTerm() {
    while (m_shortTerm.size() > m_windowSize) {
        m_shortTerm.removeFirst();
    }
}

void MemoryModule::addFact(const QString &key, const QString &value) {
    initDb();
    if (!m_db->ok) return;

    QSqlQuery q(m_db->db);
    q.prepare("INSERT OR REPLACE INTO facts (key, value, updated_at) VALUES (?, ?, ?)");
    q.addBindValue(key.trimmed());
    q.addBindValue(value);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.exec();

    refreshLongTerm();
}

void MemoryModule::removeFact(const QString &key) {
    initDb();
    if (!m_db->ok) return;

    QSqlQuery q(m_db->db);
    q.prepare("DELETE FROM facts WHERE key = ?");
    q.addBindValue(key);
    q.exec();

    refreshLongTerm();
}

void MemoryModule::clearLongTerm() {
    initDb();
    if (!m_db->ok) return;

    QSqlQuery q(m_db->db);
    q.exec("DELETE FROM facts");
    refreshLongTerm();
}

QString MemoryModule::getFact(const QString &key) const {
    if (!m_db || !m_db->ok) return QString();

    QSqlQuery q(m_db->db);
    q.prepare("SELECT value FROM facts WHERE key = ?");
    q.addBindValue(key);
    if (q.exec() && q.next()) {
        return q.value(0).toString();
    }
    return QString();
}

void MemoryModule::refreshLongTerm() {
    initDb();
    m_longTerm.clear();
    if (!m_db->ok) {
        emit longTermFactsChanged();
        return;
    }

    QSqlQuery q(m_db->db);
    q.exec("SELECT key, value FROM facts ORDER BY updated_at DESC");
    while (q.next()) {
        QVariantMap m;
        m["key"] = q.value(0).toString();
        m["value"] = q.value(1).toString();
        m_longTerm.append(m);
    }
    emit longTermFactsChanged();
}

QString MemoryModule::buildContextForPrompt() const {
    if (m_longTerm.isEmpty()) return QString();

    QStringList lines;
    lines << "\n[长期记忆 - 用户偏好与事实]";
    for (const QVariant &v : m_longTerm) {
        QVariantMap m = v.toMap();
        lines << QString("- %1: %2").arg(m["key"].toString(), m["value"].toString());
    }
    lines << "";
    return lines.join("\n");
}
