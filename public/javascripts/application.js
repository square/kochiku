Kochiku = {};
Kochiku.graphBuildTimes = function(projectName) {
  var url = '/projects/' + projectName + '/build-time-history.json';
  $.getJSON(url, function(data) {
    var max = data.max;
    var min = data.min;
    var logmax = max + 10;
    var difference = max - min;

    $.plot($('#plot'), [
      {color: '#00802D', data: data.cucumber},
      {color: '#2D80C5', data: data.spec},
    ], {
      lines: {
        show: true,
        fill: true
      },
      xaxis: {
        transform: function (v) { return Math.log(difference) - Math.log(logmax - v); },
        inverseTransform: function (v) { return difference * Math.exp(-v) * ( (logmax/difference) - Math.exp(v) - 1); },
      },
      yaxis: {
        min: 0,
        max: 50
      },
    });

  });
};
