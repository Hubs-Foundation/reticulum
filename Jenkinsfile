pipeline {
  agent any

  stages {
    stage('checkout') {
      steps {
        checkout scm
      }
    }

    stage('build') {
      steps {
        sh 'rm -rf ./results ./tmp'
        sh 'mkdir -p ./tmp'
        sh '''
          hab studio run \\"pwd \\; ls\\"
          exit \\$(cat tmp/build.exitcode)
        '''
      }
    }
  }

  post {
     always {
       archive 'tmp/*.out'
       archive 'results/**/.hart'
       deleteDir()
     }
   }
}
