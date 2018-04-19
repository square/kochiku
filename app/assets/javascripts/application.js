//= require jquery
//= require jquery_ujs
//= require jquery.tipTip
//= require jquery.tablesorter
//= require jquery.timeago
//= require jquery.flot
//= require jquery.flot.errorbars
//= require jquery.flot.categories
//= require moment

//= require_self

moment.lang('en', {
  calendar: {
    sameDay: 'h:mma',
    lastDay: 'ddd ha',
    lastWeek: 'ddd',
    sameElse: 'M/D'
  }
});

Kochiku = {};

StartTimes = {};

Kochiku.delayedRefresh = function(updateInfo) {
  var now = new Date();
  $(updateInfo.table).find('tr:has(.running)').each( function() {
      var startTime = new Date(Date.parse(StartTimes[$(this).data('id')]));
      $(this).find('.elapsed').text(
        Math.floor((now-startTime)/60000) + ":" + ("00" + (Math.round((now-startTime)/1000)%60)).slice(-2));
  });
  setTimeout(function() {
    if($('input#refresh').is(':checked')) {
      $.getJSON(document.URL + '/modified_time', function( data ) {
        var buildTime = Date.parse(data);
        var renderTime = updateInfo.renderTime;
        if(buildTime > renderTime) {
          Kochiku.buildInfo.renderTime = buildTime;
          Kochiku.updateBuildParts(renderTime);
        }
      });
      Kochiku.delayedRefresh(Kochiku.buildInfo);
    }
  }, 5000);
};

jQuery(document).ready(function() {
  jQuery("abbr.timeago").timeago();
});

Kochiku.updateBuildParts = function(renderTime) {
  $.getJSON(document.URL + '/refresh_build_part_info', { modified_time: renderTime }, function( data ) {
    $.each(data,function(index, el) {
      if (el.build_complete) {
        window.location.reload();

      }
      var row;
      row = $(".build-summary [data-id='" + el.id + "']");
      if (row) {
        row.replaceWith(el.content);
      }
    });
    $("table.tablesorter").trigger("update", [true]);
  });
}

Kochiku.graphBuildTimes = function(repositoryPath, branchName) {
  var url = '/' + repositoryPath + '/' + branchName + '/build-time-history',
    colors = {
      cucumber:     'hsl(87,  63%, 47%)',
      spec:         'hsl(187, 63%, 47%)',
      jasmine:      'hsl(27,  63%, 47%)',
      maven:        'hsl(207, 63%, 47%)',
      unit:         'hsl(187, 63%, 47%)',
      integration:  'hsl(87,  63%, 47%)',
      acceptance:   'hsl(207, 63%, 47%)'
    };

  $.getJSON(url, function(data) {
    var plot = $('#plot'),
      series = [];
    for (var label in data) {
      var points = data[label].slice(-20),
        lastTime = null;
      for (var i = 0; i < points.length; i++) {
        var ref = $('<a>')
              .attr('href', '/' + repositoryPath + '/builds/' + points[i][4])
              .attr('class', 'build-status ' + points[i][5])
              .text(points[i][0]).wrap('<div>'),
                time = moment(points[i][6]).calendar().replace(/m$/,'');
        if (time != lastTime) {
          ref.after($('<time>').text(time));
          lastTime = time;
        }
        points[i][0] = ref.parent().html();
      }
      series.push({
        label: label,
        data: points,
        color: colors[label]
      });
    }

    $.plot(plot, series, {
      xaxis: {
        mode: 'categories',
        color: 'transparent'
      },
      yaxis: {
        color: '#f3f3f3'
      },
      points: {
        show: true,
        lineWidth: 1.5,
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
        borderWidth: 0,
        clickable: true,
        labelMargin: 20,
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
    is:     function(s) { return statuses.indexOf(s) !== -1; },
    format: function(s) { return statuses.indexOf(s.replace(/^\s+|\s+$/g, '')); }
  });
})();

function timeToSeconds(time) {
  var timeArr = time.split(':')
  if (timeArr.length === 2) {
    return Number(timeArr[0])*60 + Number(timeArr[1])
  } else {
    return Number(timeArr[0])*3600 + Number(timeArr[1])*60 + Number(timeArr[2])
  }
}

(function() {
  $.tablesorter.addParser({
    id:     'elapsedTime',
    type:   'numeric',
    is:     function(s) { return /^([0-9]*:(?=[0-9]{2}:))?([0-5]?[0-9])(:[0-5][0-9])$/.test(s); },
    format: function(s) { return timeToSeconds(s); }
  });
})();
