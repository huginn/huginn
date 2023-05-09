$(function () {
  const $agentNavigate = $("#agent-navigate");

  // initialize typeahead listener
  $agentNavigate.bind("typeahead:selected", function (event, object, name) {
    const item = object["value"];
    $agentNavigate.typeahead("val", "");
    if (window.agentPaths[item]) {
      $(".spinner").show();
      const navigationData = window.agentPaths[item];
      if (
        !(navigationData instanceof Object) ||
        !navigationData.method ||
        navigationData.method === "GET"
      ) {
        return (window.location = navigationData.url || navigationData);
      } else {
        return $.rails.handleMethod.apply(
          $(
            `<a href='${navigationData.url}' data-method='${navigationData.method}'></a>`
          )
            .appendTo($("body"))
            .get(0)
        );
      }
    }
  });

  // substring matcher for typeahead
  const substringMatcher = function (strings) {
    let findMatches;
    return (findMatches = function (query, callback) {
      const matches = [];
      const substrRegex = new RegExp(query, "i");
      $.each(strings, function (i, str) {
        if (substrRegex.test(str)) {
          return matches.push({ value: str });
        }
      });
      return callback(matches.slice(0, 6));
    });
  };

  return $agentNavigate.typeahead(
    {
      minLength: 1,
      highlight: true,
    },
    { source: substringMatcher(window.agentNames) }
  );
});
