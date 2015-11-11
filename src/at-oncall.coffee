# Description
#   Bring attention to the current PagerDuty on-call whenever @oncall is mentioned.
#
# Dependencies:
#   "githubot": "2.16.x"
#   "hubot-slack-api": "2.2.x" (Optional)
#
# Configuration:
#   HUBOT_PAGERDUTY_API_KEY
#   HUBOT_PAGERDUTY_SUBDOMAIN
#   HUBOT_SLACK_TOKEN (Optional)
#
# Commands:
#   @oncall - Mention the current on-call so they see what was just said.
#   @on-call - Mention the current on-call so they see what was just said.
#   hubot clear oncall cache - Remove the current cache of email to username.
#
# Notes:
#   @oncall will respond with the current on-call's name as they've registered it with PagerDuty.
#
#   If you use slack, adding `hubot-slack-api` and a HUBOT_SLACK_TOKEN will change the @oncall response.
#   Instead of responding with the name, it will respond with the Slack username. HUBOT_SLACK_TOKEN is
#   implicitly used by hubot-slack-api.
#
#   This script only works if PagerDuty has one escalation policy. If there's more than
#   that, then it's not clear which escalation policy should be used to look up the current
#   on-call. If you've got a use case for this & an idea of how to choose which escalation policy
#   to pull the on-call data from, please file an issue and let's discuss.
#
#
# Author:
#   Chris Downie <cdownie@gmail.com>
#

# Configuration
pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1"

# Emails assumed to be @usermind.com
emailToUsername = null

module.exports = (robot) ->
  #
  # Helper functions
  #

  # Map an email to a username in the appropriate chat interface
  getUserNameFromEmail = (email, cb) ->
    if emailToUsername == null
      # Look up the usernames in Slack, if supported.
      if robot.slack?
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
          emailToUsername = userMap

          slackId = emailToUsername[email]
          unless slackId
            slackId = null
          cb slackId
      else
        cb null
    else
      userName = emailToUsername[email]
      unless userName
        userName = null
      cb userName

  # Warn about any misconfigured environment variables.
  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  # Make GET requests to the pagerDuty API
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


  #
  # Supported commands
  #

  # Respond to @oncall with the on call's username (or name if username is unavailable)
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

      getUserNameFromEmail primaryOnCall.user.email, (userName) ->
        if userName
          msg.send "@#{userName} ^^^^"
        else
          msg.send "#{primaryOnCall.user.name} ^^^^"

  # Manually clear the cache of email to username
  robot.respond /clear on-?call cache/, (msg) ->
    emailToUsername = null
    msg.send "Cleared. I'll refetch on the next request."
