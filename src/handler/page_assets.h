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

// NPM /subapi 反代时可通过 X-Forwarded-Prefix 显式指定；否则 HTML 内脚本按 pathname 推断。
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
  html = replaceAllDistinct(std::move(html), "href=\"" + localPath + "\"",
                            "href=\"" + base + "\"");
  return html;
}

constexpr const char *BASE_TAG_SCRIPT = R"html(<script>
(function () {
    var path = window.location.pathname.replace(/\/+$/, "");
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
