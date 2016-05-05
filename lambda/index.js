/**
 * Created by amonshiz on 4/25/16.
 */

"use strict";

var rp = require('request-promise');
var _ = require('lodash');

var timeoutVar;

exports.handler = function (event, context) {
  var timeoutLength = 15000;
  if (event.request.type === 'IntentRequest') {
    timeoutVar = setTimeout(function () {
      context.fail('Timeout after ' + timeoutLength);
      return;
    }, timeoutLength);
    intentRequestHandler(event.request, event.session, context);
  } else {
    context.fail('Only intent is supported');
  }
};

function intentRequestHandler(intentRequest, session, context) {
  var intentName = intentRequest.intent.name;

  if (intentName === 'FindLocation') {
    var userSlot = intentRequest.intent.slots['User'] || {};
    var userName = userSlot['value'];

    if (userName === undefined || userName.length < 1) {
      context.fail("Invalid user name");
      clearTimeout(timeoutVar);
      return;
    }

    var options = {
      method: 'GET',
      url: 'YOUR_SERVER_URL_OR_IPADDRESS' + userName,
      json: true
    };

    rp(options)
      .then(function (locData) {
        var theLocation = locData['location'] || '';

        if (theLocation.length === 0) {
          context.succeed({
            version: "0.1",
            sessionAttributes: null,
            response: {
              outputSpeech: {
                type: "PlainText",
                text: "No location could be found"
              },
              shouldEndSession: true
            }
          });
        } else {
          context.succeed({
            version: "0.1",
            sessionAttributes: null,
            response: {
              outputSpeech: {
                type: "PlainText",
                text: "" + userName + " is at " + theLocation
              },
              shouldEndSession: true
            }
          });
        }

        clearTimeout(timeoutVar);
      })
      .catch(function (error) {
        console.log("error: " + error.message);
        context.fail("Error getting info: " + error.message);
        clearTimeout(timeoutVar);
      });
  }
}