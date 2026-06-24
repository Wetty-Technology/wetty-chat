pipeline {
  agent none

  options {
    buildDiscarder(logRotator(numToKeepStr: '30'))
    disableConcurrentBuilds(abortPrevious: true)
    withChecks('wetty-chat / required-checks')
  }

  stages {
    stage('Detect Changes') {
      agent {
        kubernetes {
          defaultContainer 'node'
          yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: node
      image: node:22-bookworm
      command:
        - cat
      tty: true
'''
        }
      }

      steps {
        script {
          def changedFiles = sh(
            returnStdout: true,
            script: '''#!/usr/bin/env bash
set -euo pipefail

git config --global --add safe.directory "$PWD"

if git rev-parse HEAD^ >/dev/null 2>&1; then
  git diff --name-only HEAD^ HEAD
else
  git show --format= --name-only HEAD
fi
'''
          ).trim().split('\\n').findAll { it }

          env.PWA_CHECK_REQUIRED = changedFiles.any { path ->
            path == 'Jenkinsfile' ||
              path.startsWith('wetty-chat-mobile/')
          }.toString()

          echo "PWA check required: ${env.PWA_CHECK_REQUIRED}"
        }
      }
    }

    stage('PWA Check') {
      when {
        environment name: 'PWA_CHECK_REQUIRED', value: 'true'
      }

      agent {
        kubernetes {
          defaultContainer 'node'
          yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: node
      image: node:22-bookworm
      command:
        - cat
      tty: true
'''
        }
      }

      stages {
        stage('Install Dependencies') {
          steps {
            dir('wetty-chat-mobile') {
              sh '''#!/usr/bin/env bash
set -euo pipefail

npm ci
              '''
            }
          }
        }

        stage('Run PWA Checks') {
          parallel {
            stage('Format') {
              steps {
                dir('wetty-chat-mobile') {
                  sh '''#!/usr/bin/env bash
set -euo pipefail

npm run format:ci
                  '''
                }
              }
            }

            stage('Typecheck') {
              steps {
                dir('wetty-chat-mobile') {
                  sh '''#!/usr/bin/env bash
set -euo pipefail

npm run typecheck
                  '''
                }
              }
            }

            stage('Lint') {
              steps {
                dir('wetty-chat-mobile') {
                  sh '''#!/usr/bin/env bash
set -euo pipefail

npm run lint
                  '''
                }
              }
            }

            stage('Lingui') {
              steps {
                dir('wetty-chat-mobile') {
                  sh '''#!/usr/bin/env bash
set -euo pipefail

npm run lingui:extract
npm run lingui:compile
                  '''
                }
              }
            }

            stage('Test') {
              steps {
                dir('wetty-chat-mobile') {
                  sh '''#!/usr/bin/env bash
set -euo pipefail

npm run test:run
                  '''
                }
              }
            }
          }
        }
      }

      post {
        always {
          junit allowEmptyResults: true, testResults: 'wetty-chat-mobile/test_output/report.xml'
        }
      }
    }

    stage('Required Checks') {
      agent none

      steps {
        echo 'All applicable checks passed'
      }
    }
  }
}
