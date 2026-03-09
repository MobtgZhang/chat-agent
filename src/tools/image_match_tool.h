#ifndef IMAGE_MATCH_TOOL_H
#define IMAGE_MATCH_TOOL_H

#include "base_tool.h"

/**
 * 图像/模板匹配工具
 * 在大图中查找模板图像的位置，用于精确定位按钮、图标等
 * 通过 Python + OpenCV 子进程实现（若可用）
 */
class ImageMatchTool : public BaseTool {
    Q_OBJECT

public:
    explicit ImageMatchTool(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("image_match"); }
    QString description() const override;
    QVariantMap parametersSchema() const override;
    QString execute(const QVariantMap &args) override;

private:
    QString runMatch(const QString &scenePath, const QString &templatePath, double threshold);
};

#endif // IMAGE_MATCH_TOOL_H
