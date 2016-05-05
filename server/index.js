/**
 * Created by amonshiz on 4/12/16.
 */

var fs = require('fs');
var Promise = require('bluebird');
Promise.promisifyAll(fs);

var Geocodio = require('geocodio');
var geocodioConfig = {
  api_key: 'YOUR_GEOCODIO_API_KEY'
};
var geocodio = new Geocodio(geocodioConfig);
Promise.promisifyAll(geocodio);

var express = require('express');
var bodyParser = require('body-parser');
var rp = require('request-promise');
var AWS = require('aws-sdk');

AWS.config.update({
  accessKeyId: 'YOUR_AWS_ACCESS_KEY_ID',
  secretAccessKey: 'YOUR_SECRET_ACCESS_KEY',
  region: 'YOUR_REGION'
});

var sns = new AWS.SNS();
Promise.promisifyAll(sns);
var app = express();

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({
  extended: true
}));

function sendSilentNotification (endpoint) {
  var payload = {
    APNS_SANDBOX: {
      aps: {}
    }
  };
  var aps = {}

  aps['content-available'] = 1;
  aps['endpoint'] = endpoint;

  payload.APNS_SANDBOX.aps = aps;
  payload.APNS_SANDBOX = JSON.stringify(payload.APNS_SANDBOX);
  payload = JSON.stringify(payload);

  // Determine what ARN or other targeting you want to use for the destination of the notification
  var targetARN = "";

  var snsInfo = {
    Message: payload,
    MessageStructure: 'json',
    TargetArn: targetARN
  };
  sns.publishAsync(snsInfo)
    .then(function (data) {
    })
    .catch(function (error) {
    });

  return true;
}

app.get('/:end', function (req, res, next) {
  var endpoint = req.params.end;
  var endpointFileName = './' + endpoint + '.txt';

  var timeoutLength = 4 * 60 + 30;
  timeoutLength -= 2; // give some padding

  fs.accessAsync(endpointFileName, fs.F_OK)
    .then(function () {
      // remove the existing file so new one can be created
      return fs.unlinkAsync(endpointFileName)
        .catch(function (error) {
          console.log('unable to delete file');
          console.log('error: '+ error);
        });
    })
    .catch(function (error) {
      console.log('error : ' + error);
    })
    .then(function () {
      // make request for location
      var wasAbleToSend = sendSilentNotification(endpoint);
      if (!wasAbleToSend) {
        throw 'Unable to send'
      }
    })
    // start the timeout to wait for the file to be created
    // lambda service will only wait up to :timeoutLength: ms for a response, so this needs to be less than that
    .timeout(timeoutLength * 1000)
    .then(function () {
      // in testing it does not seem that fs.watch is reliable, and i couldn't find a good alternative that could be
      // promisified, so just doing this the hard way. going to build a list of the same file name, and then delay
      // 1000ms between each successive attempt at reading the file
      // LOL HAX
      var currentOffset = 0;
      var fileNames = [];
      while (currentOffset < (timeoutLength * 1000)) {
        fileNames.push(endpointFileName);
        currentOffset += 1000;
      }

      var emptyValue = "";
      return Promise.reduce(fileNames, function (contents, fileName) {
        if (contents !== emptyValue) {
          return contents;
        }

        return fs.accessAsync(fileName)
          .catch(function (error) {
            console.log('error: ' + error);
            return emptyValue;
          })
          .delay(1000)
          .then(function () {
            return fs.readFileAsync(fileName, 'utf8')
              .then(function (data) {
                return data;
              })
              .catch(function (error) {
                console.log('error: ' + error);
                return emptyValue;
              });
          });
      }, emptyValue)
        .then(function (data) {
          console.log('data: ' + data);
          if (data === emptyValue) {
            res.send({'location':data});
            return;
          }

          geocodio.getAsync('reverse', {q: data})
            .then(function (data) {
              var parsedData = JSON.parse(data);
              var results = parsedData.results;
              var firstResult = results[0];
              res.send({'location': firstResult.formatted_address});
            })
            .catch(function (error) {
              console.log('geocodio error: ' + error);
              res.send('error: ' + error);
            });
        });
    })
    .catch(Promise.TimeoutError, function (error) {
      console.log('time out error');
      console.log('error: ' + error);
      res.send('error: ' + error);
    })
    .catch(function (error) {
      console.log('error: ' + error);
      res.send('error: ' + error);
    })
});

app.post('/:end', function (req, res, next) {
  var endpoint = req.params.end;
  var endpointFileName = './' + endpoint + '.txt';

  var reqBody = req.body || {};
  var location = reqBody['location'] || "";

  fs.writeFile(endpointFileName, location, function (error) {
    if (error) {
      console.log('error writing file: ' + error);
    } else {
      console.log('successfully saved file');
    }

    res.send('Success');
  });
});

app.listen(3000, function () {
  console.log('started');
});
