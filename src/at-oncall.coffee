# Description
#   Bring attention to the current PagerDuty on-call whenever @oncall is mentioned.
#
# Dependencies:
#   "githubot": "2.16.x"
#   "hubot-slack-api": "2.2.x" (Optional)
#
# Configuration:
#   HUBOT_PAGERDUTY_API_KEY
#   HUBOT_PAGERDUTY_ESCALATION_POLICIES (Optional)
#   HUBOT_SLACK_TOKEN (Optional)
#
# Commands:
#   @oncall - Mention the current on-call so they see what was just said.
#   @on-call - Mention the current on-call so they see what was just said.
#   hubot clear oncall cache - Remove the current cache of email to username.
#
# Notes:
#   @oncall will respond with the current on-call's name as they've registered
#   it with PagerDuty.
#
#   If you use slack, adding `hubot-slack-api` and a HUBOT_SLACK_TOKEN will
#   change the @oncall response. Instead of responding with the name, it will
#   respond with the Slack username. HUBOT_SLACK_TOKEN is implicitly used by
#   hubot-slack-api.
#
#   This script will use the PagerDuty escalation policy named Default. To
#   customize that, provide the `HUBOT_PAGERDUTY_ESCALATION_POLICIES`
#   environment variable. It should be a comma-separated list of ids of
#   escalation policies to follow.
#
#
# Author:
#   Chris Downie <cdownie@gmail.com>
#

# Configuration
pagerDutyApiKey             = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutyEscalationPolicies = (process.env.HUBOT_PAGERDUTY_ESCALATION_POLICIES or "Default").split(",")
pagerDutyBaseUrl            = "https://api.pagerduty.com"

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
      .headers(Authorization: auth, Accept: 'application/vnd.pagerduty+json;version=2')
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
    pagerDutyGet msg, "/oncalls?include[]=users&include[]=escalation_policies", {}, (json) ->
      unless json
        msg.send "Can't determine who's on call right now. 😞"

      primaries = json.oncalls
        # Filter out policies that are higher than level 1.
        .filter (oncall) ->
          oncall.escalation_level <= 1
        # Filter out policies that don't match the predefined set.
        .filter (oncall) ->
          oncall.escalation_policy.id in pagerDutyEscalationPolicies or
            oncall.escalation_policy.name in pagerDutyEscalationPolicies
        # Get just the active oncall user.
        .map (oncall) -> oncall.user

      # Message each primary.
      primaries.forEach (primary) ->
        getUserNameFromEmail primary.email, (userName) ->
          if userName
            msg.send "@#{userName} ^^^^"
          else
            msg.send "#{primary.name} ^^^^"

  # Manually clear the cache of email to username
  robot.respond /clear on-?call cache/, (msg) ->
    emailToUsername = null
    msg.send "Cleared. I'll refetch on the next request."
