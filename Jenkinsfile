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
        sh 'HAB_ORIGIN=mozillareality sudo hab-studio run /bin/bash scripts/build.sh'
      }
    }
  }

  post {
     always {
       archive 'tmp/*.out'
       sh 'HAB_ORIGIN=mozillareality sudo hab-studio rm'
       deleteDir()
     }
   }
}
