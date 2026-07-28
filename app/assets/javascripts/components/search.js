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

  const substringMatcher = function (items) {
    return function (query, callback) {
      const term = query.trim().toUpperCase();
      const matches = [];
      $.each(items, function (index, item) {
        const namePosition = item.value.toUpperCase().indexOf(term);
        if (namePosition >= 0) {
          matches.push({
            ...item,
            sortKey: [1, namePosition, index],
          });
          return;
        }

        const typePosition = (item.agentType || "")
          .toUpperCase()
          .indexOf(term);
        if (typePosition >= 0) {
          matches.push({
            ...item,
            sortKey: [2, typePosition, index],
          });
        }
      });

      matches.sort(function (left, right) {
        for (let index = 0; index < left.sortKey.length; index += 1) {
          const difference = left.sortKey[index] - right.sortKey[index];
          if (difference !== 0) return difference;
        }
        return 0;
      });

      return callback(matches.slice(0, 6));
    };
  };

  const suggestionTemplate = function (item) {
    const suggestion = document.createElement("p");
    const name = document.createElement("span");
    name.className = "agent-search-name";
    name.appendChild(document.createTextNode(item.value));
    suggestion.appendChild(name);

    if (item.agentType) {
      const type = document.createElement("small");
      type.className = "agent-search-type";
      type.appendChild(document.createTextNode(item.agentType));
      suggestion.appendChild(type);
    }

    return suggestion;
  };

  return $agentNavigate.typeahead(
    {
      minLength: 1,
      highlight: true,
    },
    {
      displayKey: "value",
      source: substringMatcher(window.agentSearchItems),
      templates: { suggestion: suggestionTemplate },
    }
  );
});
