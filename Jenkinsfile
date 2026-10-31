// Flujo:
//   feature/*  -> build + pruebas -> Sonar (Quality Gate) -> crea el PR hacia develop
//                 "Build with Parameters" con ACCION=MERGE_A_DEVELOP -> revalida y fusiona el PR
//   develop    -> versión siguiente -> build + pruebas -> Sonar -> Nexus -> tag -> réplica a GitHub
// Variables globales (JCasC): BITBUCKET_WORKSPACE, BITBUCKET_REPO, GITHUB_OWNER, GITHUB_REPO.

def revision() {
    return env.VERSION ? "-Drevision=${env.VERSION}" : ''
}

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        choice(name: 'ACCION', choices: ['VALIDAR_Y_PR', 'MERGE_A_DEVELOP'],
               description: 'Solo ramas feature/*. VALIDAR_Y_PR: valida y crea el PR. MERGE_A_DEVELOP: revalida y fusiona el PR abierto.')
        choice(name: 'INCREMENTO', choices: ['PATCH', 'MINOR', 'MAJOR'],
               description: 'Solo develop. Parte de la versión que sube respecto al último tag vX.Y.Z.')
    }

    stages {
        stage('Versión') {
            when { branch 'develop' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'bitbucket-git',
                                                  usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    sh 'bash ci/git-con-credenciales.sh fetch --tags --force origin'
                }
                script {
                    def rc = sh(script: "bash ci/siguiente-version.sh ${params.INCREMENTO} > .version", returnStatus: true)
                    if (rc == 3) {
                        env.YA_PUBLICADO = 'true'
                    } else if (rc != 0) {
                        error("No se pudo calcular la versión (rc=${rc})")
                    }
                    env.VERSION = readFile('.version').trim()
                    currentBuild.displayName = "#${env.BUILD_NUMBER} v${env.VERSION}"
                    if (env.YA_PUBLICADO == 'true') {
                        echo "Este commit ya está publicado como v${env.VERSION}: no se publica de nuevo, solo se replica."
                    }
                }
            }
        }

        stage('Build y pruebas') {
            steps {
                sh "mvn -B -ntp clean verify ${revision()}"
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Sonar') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh "mvn -B -ntp sonar:sonar ${revision()}"
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('PR a develop') {
            when {
                allOf {
                    branch 'feature/*'
                    expression { params.ACCION == 'VALIDAR_Y_PR' }
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'bitbucket-api',
                                                  usernameVariable: 'BB_API_USER', passwordVariable: 'BB_TOKEN')]) {
                    script {
                        def pr = sh(script: 'bash ci/bitbucket.sh crear-pr "$BRANCH_NAME"', returnStdout: true).trim()
                        def url = pr.tokenize(' ')[1]
                        currentBuild.description = "PR: ${url}"
                        echo "PR listo: ${url}. Para fusionar: Build with Parameters -> ACCION=MERGE_A_DEVELOP"
                    }
                }
            }
        }

        stage('Merge a develop') {
            when {
                allOf {
                    branch 'feature/*'
                    expression { params.ACCION == 'MERGE_A_DEVELOP' }
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'bitbucket-api',
                                                  usernameVariable: 'BB_API_USER', passwordVariable: 'BB_TOKEN')]) {
                    sh 'bash ci/bitbucket.sh merge-pr "$BRANCH_NAME"'
                }
            }
        }

        stage('Publicar en Nexus') {
            when {
                allOf {
                    branch 'develop'
                    expression { env.YA_PUBLICADO != 'true' }
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-deployer',
                                                  usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh "mvn -B -ntp deploy -DskipTests ${revision()} -s .mvn/ci-settings.xml"
                }
            }
        }

        stage('Tag') {
            when {
                allOf {
                    branch 'develop'
                    expression { env.YA_PUBLICADO != 'true' }
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'bitbucket-git',
                                                  usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    sh '''
                        git -c user.name=Jenkins -c user.email=jenkins@lab.local \
                            tag -a "v$VERSION" -m "Release $VERSION"
                        bash ci/git-con-credenciales.sh push origin "refs/tags/v$VERSION"
                    '''
                }
            }
        }

        stage('Replicar a GitHub') {
            when { branch 'develop' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-git',
                                                  usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    // Sin --force: si GitHub divergió, falla en lugar de reescribir historia
                    sh '''
                        bash ci/git-con-credenciales.sh push \
                            "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git" \
                            HEAD:refs/heads/develop "refs/tags/v$VERSION"
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                if (env.BRANCH_NAME == 'develop' && env.YA_PUBLICADO != 'true') {
                    echo "Publicada io.github.carlosastrea:libreria-ejemplo:${env.VERSION} en Nexus y replicada a GitHub."
                }
            }
        }
    }
}
