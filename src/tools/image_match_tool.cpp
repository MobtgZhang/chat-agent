#include "image_match_tool.h"
#include <QProcess>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QTemporaryFile>

ImageMatchTool::ImageMatchTool(QObject *parent) : BaseTool(parent) {}

QString ImageMatchTool::description() const {
    return QStringLiteral("在场景图中查找模板图像的位置，返回中心坐标。需安装 Python3 和 opencv-python：pip install opencv-python");
}

QVariantMap ImageMatchTool::parametersSchema() const {
    return QVariantMap{
        { "type", "object" },
        { "properties", QVariantMap{
            { "scene_path", QVariantMap{
                { "type", "string" },
                { "description", "大图/场景图路径（如截图）" }
            }},
            { "template_path", QVariantMap{
                { "type", "string" },
                { "description", "要查找的模板小图路径" }
            }},
            { "threshold", QVariantMap{
                { "type", "number" },
                { "description", "匹配阈值 0-1，越高越严格" },
                { "default", 0.8 }
            }}
        }},
        { "required", QVariantList{"scene_path", "template_path"} }
    };
}

QString ImageMatchTool::runMatch(const QString &scenePath, const QString &templatePath, double threshold) {
    QFileInfo fiScene(scenePath), fiTpl(templatePath);
    if (!fiScene.exists()) return QStringLiteral("{\"error\":\"场景图不存在\"}");
    if (!fiTpl.exists()) return QStringLiteral("{\"error\":\"模板图不存在\"}");

    const QString sceneAbs = fiScene.absoluteFilePath();
    const QString tplAbs = fiTpl.absoluteFilePath();

    QString pyScript =
        "import cv2, sys, json\n"
        "scene_path, tpl_path, th = sys.argv[1], sys.argv[2], float(sys.argv[3])\n"
        "scene = cv2.imread(scene_path)\n"
        "tpl = cv2.imread(tpl_path)\n"
        "if scene is None or tpl is None:\n"
        "    print(json.dumps({'error': '无法加载图片'}))\n"
        "    sys.exit(1)\n"
        "res = cv2.matchTemplate(scene, tpl, cv2.TM_CCOEFF_NORMED)\n"
        "min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(res)\n"
        "if max_val < th:\n"
        "    print(json.dumps({'found': False, 'confidence': float(max_val)}))\n"
        "else:\n"
        "    h, w = tpl.shape[:2]\n"
        "    cx = max_loc[0] + w // 2\n"
        "    cy = max_loc[1] + h // 2\n"
        "    print(json.dumps({'found': True, 'x': cx, 'y': cy, 'confidence': float(max_val)}))\n";

    QTemporaryFile tmp;
    if (!tmp.open() || tmp.write(pyScript.toUtf8()) < 0) {
        return QStringLiteral("{\"error\":\"无法创建临时脚本\"}");
    }
    tmp.close();

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start("python3", QStringList{tmp.fileName(), sceneAbs, tplAbs, QString::number(threshold)});
    if (!proc.waitForFinished(10000)) {
        return QStringLiteral("{\"error\":\"Python/OpenCV 执行超时或未安装。请安装: pip install opencv-python\"}");
    }
    QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    if (proc.exitCode() != 0) {
        return QString("{\"error\":\"%1\"}").arg(QString::fromUtf8(proc.readAllStandardError()));
    }
    return out.isEmpty() ? QStringLiteral("{\"error\":\"无输出\"}") : out;
}

QString ImageMatchTool::execute(const QVariantMap &args) {
    QString scenePath = args.value("scene_path").toString();
    QString templatePath = args.value("template_path").toString();
    double threshold = args.value("threshold", 0.8).toDouble();
    if (threshold <= 0 || threshold > 1) threshold = 0.8;

    QString result = runMatch(scenePath, templatePath, threshold);
    emit executionFinished(name(), result);
    return result;
}
