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
        sh '''
          echo $(pwd)
          rm -rf ./results ./tmp
          mkdir -p ./tmp
          hab studio run \\"bash scripts/build.sh \\; echo \\\\\\\$! \\> tmp/build.exitcode\\"
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
