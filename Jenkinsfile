pipeline {
  agent none

  options {
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  stages {
    stage('Detect Changes') {
      agent {
        kubernetes {
          defaultContainer 'git'
          yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: git
      image: alpine/git:2.47.2
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
            script: '''#!/bin/sh
set -eu

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

          env.BACKEND_CHECK_REQUIRED = changedFiles.any { path ->
            path == 'Jenkinsfile' ||
              path.startsWith('backend/')
          }.toString()

          echo "PWA check required: ${env.PWA_CHECK_REQUIRED}"
          echo "Backend check required: ${env.BACKEND_CHECK_REQUIRED}"
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

    stage('Backend Check') {
      when {
        environment name: 'BACKEND_CHECK_REQUIRED', value: 'true'
      }

      agent {
        kubernetes {
          defaultContainer 'rust'
          yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: rust
      image: ghcr.io/chahua-im/chahua-backend-builder-base:amd64-rust-1.95.0-trixie
      command:
        - cat
      tty: true
'''
        }
      }

      steps {
        dir('backend') {
          sh '''#!/usr/bin/env bash
set -euo pipefail

curl -LsSf https://get.nexte.st/latest/linux | tar zxf - -C /usr/local/cargo/bin
rustup component add rustfmt
rustup component add clippy
cargo fmt -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo check
cargo nextest run --profile ci
          '''
        }
      }

      post {
        always {
          junit allowEmptyResults: true, testResults: 'backend/rust-test-report.xml'
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

  post {
    success {
      publishChecks name: 'wetty-chat / required-checks',
        title: 'Required Checks',
        summary: 'All applicable checks passed',
        status: 'COMPLETED',
        conclusion: 'SUCCESS'
    }

    failure {
      publishChecks name: 'wetty-chat / required-checks',
        title: 'Required Checks',
        summary: 'One or more applicable checks failed',
        status: 'COMPLETED',
        conclusion: 'FAILURE'
    }

    aborted {
      publishChecks name: 'wetty-chat / required-checks',
        title: 'Required Checks',
        summary: 'Build was aborted',
        status: 'COMPLETED',
        conclusion: 'CANCELED'
    }
  }
}
