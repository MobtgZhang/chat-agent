#ifndef OCR_TOOL_H
#define OCR_TOOL_H

#include "base_tool.h"

/**
 * OCR 文字识别工具
 * 对截图/图片进行 OCR，识别其中的文字及位置
 * 依赖 tesseract 命令行
 */
class OcrTool : public BaseTool {
    Q_OBJECT

public:
    explicit OcrTool(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("ocr"); }
    QString description() const override;
    QVariantMap parametersSchema() const override;
    QString execute(const QVariantMap &args) override;

private:
    QString runOcr(const QString &imagePath, bool withBoxes, const QString &lang);
};

#endif // OCR_TOOL_H
