#include "agent_core.h"
#include "llm_backend.h"
#include "tool_registry.h"
#include "memory_module.h"

AgentCore::AgentCore(QObject *parent) : QObject(parent) {}

AgentCore::~AgentCore() {}

void AgentCore::setLLM(LLMBackend *llm) { m_llm = llm; }
void AgentCore::setTools(ToolRegistry *registry) { m_registry = registry; }
void AgentCore::setMemory(MemoryModule *memory) { m_memory = memory; }

void AgentCore::setMode(const QString &mode) {
    if (m_mode == mode) return;
    m_mode = mode;
    emit modeChanged();
}

void AgentCore::setSystemPromptBase(const QString &base) {
    m_systemPromptBase = base;
}

void AgentCore::setMaxToolRounds(int n) {
    n = qBound(5, n, 40);
    if (m_maxToolRounds == n) return;
    m_maxToolRounds = n;
    emit maxToolRoundsChanged();
}

static QString defaultAgentSystemPrompt() {
    return QStringLiteral(
        "# Role: 物理级全能执行者\n"
        "你拥有文件读写、网页搜索、终端命令、剪贴板等物理操作权限。禁止推诿「无法操作」——不空想，用工具探测。\n"
        "## 行动原则\n"
        "调用工具前在 <thinking> 内推演：当前阶段、上步结果是否符合预期、下步策略。\n"
        "- **探测优先**：失败时先充分获取信息（日志/状态/上下文），关键信息存入记忆，再决定重试或换方案。不可逆操作先询问用户。\n"
        "- **失败升级**：1次→读错误理解原因，2次→探测环境状态，3次→深度分析后换方案或问用户。禁止无新信息的重复操作。\n"
        "- **立即执行**：需要执行动作时，必须实际调用工具，切勿仅描述计划而不调用。用用户语言回复。"
    );
}

QString AgentCore::buildSystemPrompt() const {
    QString base = m_systemPromptBase.trimmed().isEmpty()
        ? defaultAgentSystemPrompt()
        : m_systemPromptBase;

    if (m_memory) {
        QString ctx = m_memory->buildContextForPrompt();
        if (!ctx.isEmpty())
            base += "\n\n" + ctx;
    }

    if (m_mode == "planning") {
        base += "\n\n[Mode: Planning] Break complex tasks into steps. Plan first, then execute tools in order.";
    }

    return base;
}

void AgentCore::run(const QVariantList &messages, const QString &userInput) {
    m_currentToolRound = 0;
    m_pendingMessages = messages;

    // 添加用户消息
    QVariantMap userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = userInput;
    m_pendingMessages.append(userMsg);

    if (!m_llm) {
        emit errorOccurred("LLM backend not set");
        return;
    }

    m_llm->setTools(m_registry ? m_registry->toolsSchema() : QVariantList{});
    QString sysPrompt = buildSystemPrompt();

    disconnect(m_llm, nullptr, this, nullptr);
    connect(m_llm, &LLMBackend::chunkReceived, this, &AgentCore::onChunk);
    connect(m_llm, &LLMBackend::finished, this, &AgentCore::onLLMFinished);
    connect(m_llm, &LLMBackend::toolCallRequested, this, &AgentCore::onToolRequested);
    connect(m_llm, &LLMBackend::errorOccurred, this, &AgentCore::onLLMError);

    m_llm->chatStream(m_pendingMessages, sysPrompt);
}

void AgentCore::stop() {
    if (m_llm)
        m_llm->abort();
}

void AgentCore::onChunk(const QString &content, const QString &reasoning, bool isThinking) {
    emit chunkReceived(content, reasoning, isThinking);
}

void AgentCore::onLLMFinished(const QString &fullContent) {
    Q_UNUSED(fullContent);
    emit finished();
}

void AgentCore::onToolRequested(const QString &toolName, const QVariantMap &args) {
    if (!m_registry) return;

    QString result = m_registry->execute(toolName, args);
    emit toolExecuted(toolName, result);

    // 将 assistant 消息（含 tool_calls）和 tool 结果加入历史，继续 ReAct
    m_currentToolRound++;
    if (m_currentToolRound > m_maxToolRounds) {
        emit errorOccurred("工具调用轮次超限");
        emit finished();
        return;
    }

    // 需要将本轮 assistant 的完整回复 + tool 结果追加到 m_pendingMessages
    // 由于流式 API 的 tool_calls 可能是增量送达，这里简化处理：
    // 将 tool 结果作为 user 消息发送，让 LLM 继续
    QVariantMap toolMsg;
    toolMsg["role"] = "user";
    toolMsg["content"] = QString("[Tool %1 结果]\n%2").arg(toolName, result);
    m_pendingMessages.append(toolMsg);

    m_llm->chatStream(m_pendingMessages, buildSystemPrompt());
}

void AgentCore::onLLMError(const QString &msg) {
    emit errorOccurred(msg);
    emit finished();
}
