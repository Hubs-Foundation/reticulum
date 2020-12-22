import groovy.json.JsonOutput

pipeline {
  agent any

  options {
    ansiColor('xterm')
  }

  stages {
    stage('pre-build') {
      steps {
        sh 'rm -rf ./results ./tmp'
      }
    }

    stage('build') {
      steps {
        sh '''
          /usr/bin/script --return -c \\\\"sudo /usr/bin/hab-docker-studio -k mozillareality run /bin/bash scripts/build.sh\\\\" /dev/null
        '''

        sh 'sudo /usr/bin/hab-pkg-upload $(ls -t results/*.hart | head -n 1)'

        script {
          def poolHost = env.RET_DARK_POOL_HOST
          def slackURL = env.SLACK_URL
          def buildNumber = env.BUILD_NUMBER
          def jobName = env.JOB_NAME
          def onlyPromoteToStage = env.ONLY_PROMOTE_TO_STAGE
          def stageChannel = env.STAGE_CHANNEL

          // Grab IDENT file and cat it from .hart
          def s = $/eval 'ls -t results/*.hart | head -n 1'/$
          def hart = sh(returnStdout: true, script: "${s}").trim()

          s = $/eval 'tail -n +6 ${hart} | xzcat | tar tf - | grep IDENT'/$
          def identPath = sh(returnStdout: true, script: "${s}").trim()

          s = $/eval 'tail -n +6 ${hart} | xzcat | tar xf - "${identPath}" -O'/$
          def packageIdent = sh(returnStdout: true, script: "${s}").trim()
          def packageTimeVersion = packageIdent.tokenize('/')[3]
          def (major, minor, version) = packageIdent.tokenize('/')[2].tokenize('.')
          def retVersion = "${major}.${minor}.${packageTimeVersion}"

          if (onlyPromoteToStage == "") {
            def retPool = sh(returnStdout: true, script: "curl https://${poolHost}/api/v1/meta | jq -r '.pool'").trim()
            sh "sudo /usr/bin/hab-pkg-promote '${packageIdent}' '${retPool}'"
            sh "sudo /usr/bin/hab-pkg-promote '${packageIdent}' 'stable'"

            def retPoolIcon = retPool == 'earth' ? ':earth_americas:' : ':new_moon:'
            def gitMessage = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'[%an] %s'").trim()
            def gitSha = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
            def text = (
              "*<http://localhost:8080/job/${jobName}/${buildNumber}|#${buildNumber}>* *${jobName}* " +
              "<https://bldr.habitat.sh/#/pkgs/${packageIdent}|${packageIdent}>\n" +
              "<https://github.com/mozilla/reticulum/commit/$gitSha|$gitSha> " +
              "Reticulum -> ${retPoolIcon} `${retPool}`: ```${gitSha} ${gitMessage}```\n" +
              "<https://smoke-hubs.mozilla.com/0zuesf6c6mf/smoke-test?required_ret_version=${retVersion}&required_ret_pool=${retPool}|Smoke Test> - to push:\n" +
              "`/mr ret deploy ${retVersion} ${retPool}`"
            )
            sendSlackMessage(text, "#mr-builds", ":gift:", slackURL);
          }

          // Upload to ret depot after publishing to slack to minimize wait
          sh 'sudo /usr/bin/hab-ret-pkg-upload $(ls -t results/*.hart | head -n 1)'

          if (onlyPromoteToStage == "true") {
            sh "sudo /usr/bin/hab-ret-pkg-promote '${packageIdent}' '${stageChannel}'"

            def text = (
              "*<http://localhost:8080/job/${jobName}/${buildNumber}|#${buildNumber}>* *${jobName}* " +
              "<https://bldr.reticulum.io/#/pkgs/${packageIdent}|${packageIdent}>\n" +
              "<https://github.com/mozilla/reticulum/commit/$gitSha|$gitSha> " +
              "Promoted ${retVersion} to ${stageChannel}: ```${gitSha} ${gitMessage}```\n"
            )
            sendSlackMessage(text, "#mr-builds", ":gift:", slackURL);
          }
        }
      }
    }
  }

  post {
     always {
       archive 'tmp/*.log'
     }
   }
}

def sendSlackMessage(text, channel, icon, slackURL) {
  def payload = 'payload=' + JsonOutput.toJson([
    text      : text,
    channel   : channel,
    username  : "buildbot",
    icon_emoji: icon
  ])
  sh "curl -X POST --data-urlencode ${shellString(payload)} ${slackURL}"
}

// From https://issues.jenkins-ci.org/browse/JENKINS-44231

// Given arbitrary string returns a strongly escaped shell string literal.
// I.e. it will be in single quotes which turns off interpolation of $(...), etc.
// E.g.: 1'2\3\'4 5"6 (groovy string) -> '1'\''2\3\'\''4 5"6' (groovy string which can be safely pasted into shell command).
def shellString(s) {
  // Replace ' with '\'' (https://unix.stackexchange.com/a/187654/260156). Then enclose with '...'.
  // 1) Why not replace \ with \\? Because '...' does not treat backslashes in a special way.
  // 2) And why not use ANSI-C quoting? I.e. we could replace ' with \'
  // and enclose using $'...' (https://stackoverflow.com/a/8254156/4839573).
  // Because ANSI-C quoting is not yet supported by Dash (default shell in Ubuntu & Debian) (https://unix.stackexchange.com/a/371873).
  '\'' + s.replace('\'', '\'\\\'\'') + '\''
}
