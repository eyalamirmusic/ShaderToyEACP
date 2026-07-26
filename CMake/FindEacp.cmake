include(CPM)

# The WebView module pulls in WKWebView / WebView2 and a Node toolchain for its
# schema codegen, none of which this project touches yet. It comes back on when
# the browser-hosted shader editor lands (see the plan in README.md).
CPMAddPackage(
        NAME eacp
        GITHUB_REPOSITORY eyalamirmusic/eacp
        GIT_TAG main
        OPTIONS
            "EACP_BUILD_WEBVIEW OFF")
