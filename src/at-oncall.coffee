# Description
#   Bring attention to the current PagerDuty on-call whenever @oncall is mentioned.
#
# Dependencies:
#   "githubot": "2.16.x"
#   "hubot-slack-api": "2.2.x"
#
# Configuration:
#   HUBOT_SLACK_TOKEN
#   HUBOT_PAGERDUTY_API_KEY
#   HUBOT_PAGERDUTY_SUBDOMAIN
#
# Commands:
#   @oncall - Mention the current on-call so they see what was just said.
#   @on-call - Mention the current on-call so they see what was just said.
#   hubot clear oncall cache - Remove the current cache of email to slack username.
#
# Notes:
#   This script is intended to work with Slack, since Slack has really good notification
#   support whenever a user is mentioned by their Slack username. Without hubot-slack-api,
#   or if we can't find the Slack username associated with the current on-call's email
#   address, it will post the email associated with the current PagerDuty on-call.
#
#   This script only works if PagerDuty has one escalation policy. If there's more than
#   that, then it's not clear which escalation policy should be used to look up the current
#   on-call.
#
#   HUBOT_SLACK_TOKEN is implicitly used by hubot-slack-api.
#
# Author:
#   Chris Downie <cdownie@gmail.com>

# Configuration
pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1"

# Emails assumed to be @usermind.com
emailToSlackId = null

module.exports = (robot) ->
  getSlackIdFromEmail = (email, cb) ->
    if emailToSlackId == null && robot.slack?
      robot.slack.users.list {}, (err, json) ->
        if err
          console.log "Calling slack API errored: #{err}"
          return null
        unless json.ok
          console.log "Calling slack API gave a not-OK response: #{json.error}"
          return null

        userMap = {}
        userMap[member.profile.email] = member.name for member in json.members

        # cache it
        emailToSlackId = userMap

        slackId = emailToSlackId[email]
        unless slackId
          slackId = null
        cb slackId
    else
      slackId = emailToSlackId[email]
      unless slackId
        slackId = null
      cb slackId

  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  pagerDutyGet = (msg, url, query, cb) ->
    if missingEnvironmentForApi(msg)
      return

    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .query(query)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            console.log res.statusCode
            console.log body
            json_body = null
        cb json_body

  # Responses
  robot.hear /@on-?call/i, (msg) ->
    pagerDutyGet msg, "/escalation_policies/on_call", {}, (json) ->
      unless json
        msg.send "Can't determine who's on call right now. 😞"
      unless json.escalation_policies.length == 1
        manyOrFew = json.escalation_policies == 0 ? "few" : "many"
        msg.send "Too #{manyOrFew} escalation policies. This script needs to be updated 🔜"

      for person in json.escalation_policies[0].on_call
        if person.level == 1
          primaryOnCall = person

      slackName = getSlackIdFromEmail primaryOnCall.user.email, (slackName) ->
        if slackName
          msg.send "@#{slackName} ^^^^"
        else
          msg.send "#{primaryOnCall.user.name} ^^^^"

  robot.respond /clear on-?call cache/, (msg) ->
    emailToSlackId = null
    msg.send "Cleared. I'll refetch on the next request."
