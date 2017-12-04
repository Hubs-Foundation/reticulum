import groovy.json.JsonOutput

pipeline {
  agent any

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
            // Grab IDENT file and cat it from .hart
            def s = $/eval 'ls -rt results/*.hart | head -n 1'/$
            def hart = sh(returnStdout: true, script: "${s}").trim()
            s = $/eval 'tail -n +6 ${hart} | xzcat | tar tf - | grep IDENT'/$
            def identPath = sh(returnStdout: true, script: "${s}").trim()
            s = $/eval 'tail -n +6 ${hart} | xzcat | tar xf - "${identPath}" -O'/$
            def packageIdent = sh(returnStdout: true, script: "${s}").trim()

            def gitMessage = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h [%an] %s'").trim()
            def slackURL = 'https://hooks.slack.com/services/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'
            def text = "*<http://localhost:8080/job/${env.JOB_NAME}/${env.BUILD_NUMBER}|#${env.BUILD_NUMBER}>* *${env.JOB_NAME}* <https://bldr.habitat.sh/#/pkgs/${packageIdent}|${packageIdent}>\n`${gitMessage}`\nTo push:\n`/mr-ops hab promote ${packageIdent}`"
            def payload = JsonOutput.toJson([text      : text, channel   : "#mr-builds", username  : "buildbot", icon_emoji: ":gift:"])
            sh "curl -X POST --data-urlencode \'payload=${payload}\' ${slackURL}"
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
