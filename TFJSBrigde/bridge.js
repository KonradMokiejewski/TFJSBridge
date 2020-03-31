
function postMessage(message, callBack) {
        message.callBack = callBack.toString();
        window.webkit.messageHandlers.TFJSBridge.postMessage(message);
}


