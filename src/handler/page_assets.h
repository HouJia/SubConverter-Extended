#ifndef PAGE_ASSETS_H_INCLUDED
#define PAGE_ASSETS_H_INCLUDED

#include <string>

#include "server/webserver.h"
#include "utils/string.h"

namespace page_assets {

inline std::string headerValue(const Request &request, const std::string &name) {
  for (const auto &entry : request.headers) {
    if (strcasecmp(entry.first.c_str(), name.c_str()) == 0)
      return entry.second;
  }
  return {};
}

// Favicon HTTP 路由仅在 /version/favicon-*.svg；各 HTML 页引用方式见 docs/功能与访问入口.md §4
inline constexpr const char *FAVICON_REL_VERSION = "favicon-light.svg";
inline constexpr const char *FAVICON_REL_FROM_SIBLING_PAGE = "../version/favicon-light.svg";
inline std::string resolvePublicBase(const Request &request,
                                     const std::string &localPath) {
  std::string prefix = headerValue(request, "X-Forwarded-Prefix");
  while (!prefix.empty() && prefix.back() == '/')
    prefix.pop_back();
  if (!prefix.empty())
    return prefix + localPath;
  return localPath;
}

inline std::string rewriteLocalAssetPaths(std::string html,
                                          const Request &request,
                                          const std::string &localPath) {
  const std::string base = resolvePublicBase(request, localPath);
  if (base == localPath)
    return html;
  html = replaceAllDistinct(std::move(html), localPath + "/favicon",
                            base + "/favicon");
  html = replaceAllDistinct(std::move(html),
                            "srcset=\"" + localPath + "/",
                            "srcset=\"" + base + "/");
  html = replaceAllDistinct(std::move(html), "src=\"" + localPath + "/",
                            "src=\"" + base + "/");
  html = replaceAllDistinct(std::move(html), "href=\"" + localPath + "/",
                            "href=\"" + base + "/");
  html = replaceAllDistinct(std::move(html), "href=\"" + localPath + "\"",
                            "href=\"" + base + "\"");
  return html;
}

constexpr const char *BASE_TAG_SCRIPT = R"html(<script>
(function () {
    var path = window.location.pathname.replace(/\/+$/, "");
    // NPM: /subapi 反代到后端 /version，浏览器 pathname 仍是 /subapi
    if (path === "/subapi" || path.endsWith("/subapi")) {
        document.write('<base href="' + path + '/version/">');
        return;
    }
    var routes = ["/version", "/dashboard", "/inspect"];
    for (var i = 0; i < routes.length; i++) {
        var route = routes[i];
        if (path === route || path.endsWith(route)) {
            document.write('<base href="' + path + '/">');
            break;
        }
    }
})();
</script>
)html";

} // namespace page_assets

#endif // PAGE_ASSETS_H_INCLUDED
