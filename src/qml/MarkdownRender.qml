// qml/MarkdownRender.qml
import QtQuick 2.15
import QtWebEngine 1.15

Item {
    id: root
    property string markdownText: ""
    property color  textColor:    "#DBDEE1"
    property int    fontSize:     14

    height: 40   // JS 轮询后动态更新

    // ── 防抖：流式 token 高频时合并渲染 ─────────────────────────────────────
    Timer {
        id: debounce
        interval: 60
        repeat: false
        onTriggered: root._render()
    }

    // ── 高度轮询：等待 KaTeX 排版完成 ───────────────────────────────────────
    Timer {
        id: heightPoller
        interval: 250
        repeat: false
        onTriggered: {
            webView.runJavaScript("getHeight()", function(h) {
                if (h && h > 0) root.height = h + 6
            })
        }
    }

    onMarkdownTextChanged: { if (webView.ready) debounce.restart() }

    function _render() {
        webView.runJavaScript("setContent(" + JSON.stringify(markdownText) + ")")
        heightPoller.restart()
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        backgroundColor: "transparent"
        property bool ready: false

        Component.onCompleted: loadHtml(_buildHtml())

        onLoadingChanged: function(req) {
            if (req.status === WebEngineView.LoadSucceededStatus) {
                ready = true
                root._render()
            }
        }

        function _buildHtml() {
            return `<!DOCTYPE html>
<html> <head> <meta charset="utf-8"> <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"> <script src="https://cdn.jsdelivr.net/npm/marked@9.1.6/marked.min.js"></script> <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script> <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script> <style> *,*::before,*::after{box-sizing:border-box} html,body{ margin:0;padding:0;background:transparent; color:${root.textColor};font-size:${root.fontSize}px; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Noto Sans SC","Microsoft YaHei",sans-serif; line-height:1.65;overflow:hidden;word-break:break-word; } p{margin:0 0 .55em}p:last-child{margin-bottom:0} h1,h2,h3,h4,h5,h6{margin:.5em 0 .2em;line-height:1.3;font-weight:600} h1{font-size:1.4em}h2{font-size:1.2em}h3{font-size:1.05em} ul,ol{margin:.2em 0;padding-left:1.6em}li{margin:.12em 0} pre{background:#141517;border:1px solid #2E3035;padding:10px 14px; border-radius:6px;overflow-x:auto;margin:.4em 0} code{font-family:"Cascadia Code",Consolas,"Courier New",monospace;font-size:.87em; background:rgba(0,0,0,.35);padding:2px 5px;border-radius:3px} pre code{background:transparent;padding:0} blockquote{border-left:3px solid #4A4D55;margin:.3em 0;padding:2px 12px;color:#949BA4} table{border-collapse:collapse;width:100%;margin:.35em 0} th,td{border:1px solid #3F4147;padding:5px 10px;text-align:left} th{background:#2B2D31} hr{border:none;border-top:1px solid #3F4147;margin:.4em 0} a{color:#7289DA;text-decoration:none}a:hover{text-decoration:underline} .katex-display{overflow-x:auto;overflow-y:hidden;padding:4px 0;margin:.3em 0} .katex{font-size:1.06em} </style> </head> <body> <div id="md"></div> <script> var _pending=null,_timer=null; function setContent(text){ _pending=text; if(_timer)clearTimeout(_timer); _timer=setTimeout(_flush,25); } function _flush(){ _timer=null;if(_pending===null)return; var el=document.getElementById("md"); var text=_pending;_pending=null; if(typeof marked!=="undefined"){ marked.setOptions({breaks:true,gfm:true}); el.innerHTML=marked.parse(text); }else{ el.textContent=text; } _tryKaTeX(el,0); } function _tryKaTeX(el,waited){ if(typeof renderMathInElement==="undefined"){ if(waited<6000)setTimeout(function(){_tryKaTeX(el,waited+200);},200); return; } try{ renderMathInElement(el,{ delimiters:[ {left:"$$", right:"$$", display:true}, {left:"\\\\[",right:"\\\\]",display:true}, {left:"\\\\(",right:"\\\\)",display:false}, {left:"$", right:"$", display:false} ], throwOnError:false,errorColor:"#FF7B72" }); }catch(e){console.warn("KaTeX:",e)} } function getHeight(){ return Math.max( document.documentElement.scrollHeight, document.body.scrollHeight, (document.getElementById("md")||{}).scrollHeight||0 ); } </script> </body> </html>` 
        }
    }
}