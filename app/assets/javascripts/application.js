//= require jquery
//= require jquery_ujs
//= require jquery.tipTip
//= require jquery.tablesorter
//= require jquery.flot
//= require jquery.flot.errorbars
//= require jquery.flot.categories

//= require_self

Kochiku = {};

Kochiku.delayedRefresh = function() {
  setTimeout(function() {
    if ($('input#refresh').is(':checked'))
      window.location.reload();
    else
      Kochiku.delayedRefresh();
  }, 10000);
};

Kochiku.graphBuildTimes = function(projectName) {
  var url = '/projects/' + projectName + '/build-time-history.json'
    , colors = {
      cucumber: 'hsl(87,63%,47%)',
      spec: 'hsl(187, 63%,47%)',
      jasmine: 'hsl(27, 63%,47%)',

      maven: 'hsl(207,63%,47%)',

      unit: 'hsl(187, 63%,47%)',
      integration: 'hsl(87,63%,47%)',
      acceptance: 'hsl(207,63%,47%)'
    };

  $.getJSON(url, function(data) {
    var plot = $('#plot')
      , series = [];
    for (var label in data)
      series.push({
        label: label,
        data: data[label].slice(-28),
        color: colors[label]
      });

    $.plot(plot, series, {
      xaxis: {
        mode: 'categories'
      },
      points: {
        show: true,
        lineWidth: 2,
        radius: 3,
        shadowSize: 0,
        errorbars: 'y',
        yerr: {
          show: true,
          asymmetric: true,
          lineWidth: 1,
          lowerCap: '-'
        }
      },
      grid: {
        borderWidth: 1,
        margin: {
          left: 20
        }
      },
      legend: {
        show: true,
        position: 'nw',
        noColumns: series.length
      }
    });

    $('<div class="axis-label y">')
      .text('Minutes (Min to Max)')
      .appendTo(plot);
  });
};

(function() {
  var statuses = [
    'Errored', 'Aborted', 'Failed', 'Running', 'Runnable', 'Passed'
  ];

  $.tablesorter.addParser({
    id:     'state',
    type:   'numeric',
    is:     function(s) { return statuses.indexOf(s) !== -1 },
    format: function(s) { return statuses.indexOf(s.replace(/^\s+|\s+$/g, '')); }
  });
})();
