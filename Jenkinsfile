import groovy.json.JsonOutput

pipeline {
  agent any

  options {
    ansiColor('xterm')
  }

  stages {
    stage('pre-build') {
      steps {
        checkout scm: [$class: 'GitSCM', clean: false, clearWorkspace: false]

        sh 'rm -rf ./results ./tmp'
      }
    }

    stage('build') {
      steps {
        sh '''
          /usr/bin/script --return -c \\\\"sudo /usr/bin/hab-docker-studio -k mozillareality run /bin/bash scripts/build.sh\\\\" /dev/null
        '''

        sh 'sudo /usr/bin/hab-pkg-upload $(ls -rt results/*.hart | head -n 1)'

        script {

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

            // Grab IDENT file and cat it from .hart
            def s = $/eval 'ls -rt results/*.hart | head -n 1'/$
            def hart = sh(returnStdout: true, script: "${s}").trim()
            s = $/eval 'tail -n +6 ${hart} | xzcat | tar tf - | grep IDENT'/$
            def identPath = sh(returnStdout: true, script: "${s}").trim()
            s = $/eval 'tail -n +6 ${hart} | xzcat | tar xf - "${identPath}" -O'/$
            def packageIdent = sh(returnStdout: true, script: "${s}").trim()

            def gitMessage = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'[%an] %s'").trim()
            def gitSha = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
            def gitMessageClient = sh(
              returnStdout: true,
              script: (
                "curl --silent 'https://api.github.com/repos/mozilla/mr-social-client/commits?per_page=1' | " +
                "jq -r '.[0] | (\"[\" + .commit.author.name + \"] \" + .commit.message)'"
              )
            ).trim()
            def gitClientSha = sh(
              returnStdout: true,
              script: (
                "curl --silent 'https://api.github.com/repos/mozilla/mr-social-client/commits?per_page=1' | " +
                "jq -r '.[0] | .sha[0:7]'"
              )
            ).trim()
            def slackURL = env.SLACK_URL
            def text = (
              "*<http://localhost:8080/job/${env.JOB_NAME}/${env.BUILD_NUMBER}|#${env.BUILD_NUMBER}>* *${env.JOB_NAME}* " +
              "<https://bldr.habitat.sh/#/pkgs/${packageIdent}|${packageIdent}>\n" +
              "<https://github.com/mozilla/mr-social-client/commit/${gitClientSha}|${gitClientSha}> " + 
              "Client:```${gitClientSha} ${gitMessageClient}```\n" +
              "<https://github.com/mozilla/reticulum/commit/$gitSha|$gitSha> " +
              "Reticulum: ```${gitSha} ${gitMessage}```\n" +
              "<https://smoke-dev.reticulum.io/client/smoke-room.html?room=1|Smoke Test> - to push:\n" +
              "`/mr hab promote ${packageIdent}`"
            )
            def payload = 'payload=' + JsonOutput.toJson([
              text      : text,
              channel   : "#mr-builds",
              username  : "buildbot",
              icon_emoji: ":gift:"
            ])
            sh "curl -X POST --data-urlencode ${shellString(payload)} ${slackURL}"
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
