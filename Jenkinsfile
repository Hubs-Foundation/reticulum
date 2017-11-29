pipeline {
  agent any

  stages {
    stage('pre-build') {
      steps {
        checkout scm
        sh 'rm -rf ./results ./tmp'
      }
    }

    stage('build') {
      steps {
        sh '''
          /usr/bin/script --return -c \\\\"sudo /usr/bin/hab-docker-studio run /bin/bash scripts/build.sh\\\\" /dev/null
	'''
      }
    }
  }

  post {
     always {
       archive 'tmp/*.log'
       deleteDir()
     }
   }
}
