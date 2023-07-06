$(function () {
  let sinceId = null;
  let previousJobs = null;

  if ($(".job-indicator").length) {
    var check = function () {
      const query = sinceId != null ? "?since_id=" + sinceId : "";
      return $.getJSON("/worker_status" + query, function (json) {
        for (var method of ["pending", "awaiting_retry", "recent_failures"]) {
          var count = json[method];
          var elem = $(`.job-indicator[role=${method}]`);
          if (count > 0) {
            var tooltipOptions = {
              title: `${count} jobs ${method.split("_").join(" ")}`,
              delay: 0,
              placement: "bottom",
              trigger: "hover",
            };
            if (elem.is(":visible")) {
              elem
                .tooltip("destroy")
                .tooltip(tooltipOptions)
                .find(".number")
                .text(count);
            } else {
              elem
                .tooltip("destroy")
                .tooltip(tooltipOptions)
                .fadeIn()
                .find(".number")
                .text(count);
            }
          } else {
            if (elem.is(":visible")) {
              elem.tooltip("destroy").fadeOut();
            }
          }
        }

        if (sinceId != null && json.event_count > 0) {
          $("#event-indicator")
            .tooltip("destroy")
            .tooltip({
              title: "Click to see the events",
              delay: 0,
              placement: "bottom",
              trigger: "hover",
            })
            .find("a")
            .attr({ href: json.events_url })
            .end()
            .fadeIn()
            .find(".number")
            .text(json.event_count);
        } else {
          $("#event-indicator").tooltip("destroy").fadeOut();
        }

        if (sinceId == null) {
          sinceId = json.max_id;
        }
        const currentJobs = [
          json.pending,
          json.awaiting_retry,
          json.recent_failures,
        ];
        if (
          document.location.pathname === "/jobs" &&
          $(".modal[aria-hidden=false]").length === 0 &&
          previousJobs != null &&
          previousJobs.join(",") !== currentJobs.join(",")
        ) {
          if (
            !document.location.search ||
            document.location.search === "?page=1"
          ) {
            $.get("/jobs", (data) => {
              return $("#main-content").html(data);
            });
          }
        }
        previousJobs = currentJobs;

        return (window.workerCheckTimeout = setTimeout(check, 2000));
      });
    };

    return check();
  }
});
