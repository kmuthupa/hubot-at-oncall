# Description
#   Bring attention to the current PagerDuty primary whenever @<team>-primary is mentioned.
#   Bring attention to the current PagerDuty secondary whenever @<team>-secondary is mentioned.
#
# Dependencies:
#   "githubot": "2.16.x"
#   "hubot-slack-api": "2.2.x" (Optional)
#
# Configuration:
#   HUBOT_PAGERDUTY_API_KEY
#   HUBOT_PAGERDUTY_API (Optional)
#   HUBOT_SLACK_TOKEN (Optional)
#
# Commands:
#   @<team>-primary - Mention the current on-call primary for the team so they see what was just said.
#   @<team>-secondary - Mention the current on-call secondary for the team so they see what was just said.
#   teams: dd
#   oddjob clear oncall cache - Remove the current cache of email to username.
#
#
# Author:
#   Karthik Muthupalaniappan

# Configuration
pagerDutyApiKey             = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutyBaseUrl            = process.env.HUBOT_PAGERDUTY_API || "https://api.pagerduty.com"

emailToUsername = null

escalationPolicies = {
  "dd" : "Data Distribution Escalation"
}

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

  # Respond to @<team-name>-primary with the on call's username (or name if username is unavailable)
  robot.hear /@(.+)-primary/i, (msg) ->
    policy = msg.match[1]
    pagerDutyGet msg, "/oncalls?include[]=users&include[]=escalation_policies", {}, (json) ->
      unless json
        msg.send "Can't determine who's primary right now. 😞"

      console.log(escalationPolicies)
      console.log(escalationPolicies[policy])
      primaries = json.oncalls
        .filter (oncall) ->
          oncall.escalation_level <= 1
        .filter (oncall) ->
          oncall.escalation_policy.name == escalationPolicies[policy]
        .map (oncall) -> oncall.user

      # Message each primary.
      console.log(primaries)
      primaries.forEach (primary) ->
        getUserNameFromEmail primary.email, (userName) ->
          if userName
            msg.send "@#{userName} ^^^^"
          else
            msg.send "#{primary.name} ^^^^"

  # Respond to @<team-name>-secondary with the on call's username (or name if username is unavailable)
   robot.hear /@(.+)-secondary/i, (msg) ->
    policy = msg.match[1]
    pagerDutyGet msg, "/oncalls?include[]=users&include[]=escalation_policies", {}, (json) ->
      unless json
        msg.send "Can't determine who's secondary right now. 😞"

      secondaries = json.oncalls
        .filter (oncall) ->
          oncall.escalation_level <= 1
        .filter (oncall) ->
          oncall.escalation_policy.name == escalationPolicies[policy]
        .map (oncall) -> oncall.user

      # Message each secondary.
      console.log(secondaries)
      secondaries.forEach (secondary) ->
        getUserNameFromEmail secondary.email, (userName) ->
          if userName
            msg.send "@#{userName} ^^^^"
          else
            msg.send "#{secondary.name} ^^^^"


  # Manually clear the cache of email to username
  robot.respond /clear on-?call cache/, (msg) ->
    emailToUsername = null
    msg.send "Cleared. I'll refetch on the next request."
