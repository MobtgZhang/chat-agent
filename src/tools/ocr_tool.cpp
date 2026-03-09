#include "ocr_tool.h"
#include <QProcess>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>

OcrTool::OcrTool(QObject *parent) : BaseTool(parent) {}

QString OcrTool::description() const {
    return QStringLiteral("对图片进行 OCR 文字识别，可选返回文字及其边界框坐标。需安装 tesseract。");
}

QVariantMap OcrTool::parametersSchema() const {
    return QVariantMap{
        { "type", "object" },
        { "properties", QVariantMap{
            { "image_path", QVariantMap{
                { "type", "string" },
                { "description", "图片文件路径（PNG/JPG 等）" }
            }},
            { "with_boxes", QVariantMap{
                { "type", "boolean" },
                { "description", "是否返回每个文字的位置边界框" },
                { "default", false }
            }},
            { "lang", QVariantMap{
                { "type", "string" },
                { "description", "识别语言，如 eng chi_sim" },
                { "default", "eng+chi_sim" }
            }}
        }},
        { "required", QVariantList{"image_path"} }
    };
}

QString OcrTool::runOcr(const QString &imagePath, bool withBoxes, const QString &lang) {
    QFileInfo fi(imagePath);
    if (!fi.exists()) {
        return QStringLiteral("{\"error\":\"图片文件不存在\"}");
    }

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    QStringList args{imagePath, "stdout", "-l", lang};
    if (withBoxes) args << "hocr";
    proc.start("tesseract", args);
    if (!proc.waitForFinished(30000)) {
        return QStringLiteral("{\"error\":\"tesseract 执行失败或未安装，请安装: sudo apt install tesseract-ocr tesseract-ocr-chi-sim\"}");
    }
    if (proc.exitCode() != 0) {
        return QString("{\"error\":\"tesseract: %1\"}").arg(QString::fromUtf8(proc.readAllStandardError()));
    }

    QString output = QString::fromUtf8(proc.readAllStandardOutput());
    QJsonObject o;
    o["text"] = output.trimmed();
    o["success"] = true;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString OcrTool::execute(const QVariantMap &args) {
    QString imagePath = args.value("image_path").toString();
    bool withBoxes = args.value("with_boxes", false).toBool();
    QString lang = args.value("lang").toString();
    if (lang.isEmpty()) lang = "eng+chi_sim";

    QString result = runOcr(imagePath, withBoxes, lang);
    emit executionFinished(name(), result);
    return result;
}
