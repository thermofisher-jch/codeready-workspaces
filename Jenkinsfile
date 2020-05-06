#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
// nodeBig == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb||rhel7-16gb
// branchToBuildDev = refs/tags/20
// branchToBuildParent = refs/tags/7.9.3
// branchToBuildChe = refs/tags/7.9.3 or */*/7.9.x or */master
// branchToBuildCRW = */7.9.x or */master
// BUILDINFO = ${JOB_NAME}/${BUILD_NUMBER}
// MVN_EXTRA_FLAGS = extra flags, such as to disable a module -pl '!org.eclipse.che.selenium:che-selenium-test'
// SCRATCH = true (don't push to Quay) or false (do push to Quay)

def installNPM(){
	def yarnVersion="1.21.0"
	def nodeHome = tool 'nodejs-10.19.0'
	env.PATH="${nodeHome}/bin:${env.PATH}"
	sh '''#!/bin/bash -xe
rm -f ${HOME}/.npmrc ${HOME}/.yarnrc
npm install --global yarn@''' + yarnVersion + '''
npm --version; yarn --version
'''
}
def installGo(){
	def goHome = tool 'go-1.10'
	env.PATH="${env.PATH}:${goHome}/bin"
	sh "go version"
}

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def buildMaven(){
	def mvnHome = tool 'maven-3.5.4'
	env.PATH="${env.PATH}:${mvnHome}/bin"
}

def CRW_SHAs = ""

def DEV_path = "che-dev"
def VER_DEV = "VER_DEV"
def SHA_DEV = "SHA_DEV"

def PAR_path = "che-parent"
def VER_PAR = "VER_PAR"
def SHA_PAR = "SHA_PAR"

def CHE_DB_path = "che-dashboard"
def VER_CHE_DB = "VER_CHE_DB"
def SHA_CHE_DB = "SHA_CHE_DB"

def CHE_WL_path = "che-workspace-loader"
def VER_CHE_WL = "VER_CHE_WL"
def SHA_CHE_WL = "SHA_CHE_WL"

def CHE_path = "che"
def VER_CHE = "VER_CHE"
def SHA_CHE = "SHA_CHE"

def CRW_path = "codeready-workspaces"
def VER_CRW = "VER_CRW"
def SHA_CRW = "SHA_CRW"

timeout(240) {
	node("${node}"){ stage "Build ${DEV_path}, ${PAR_path}, ${CHE_DB_path}, ${CHE_WL_path}, and ${CRW_path}"
		cleanWs()
		buildMaven()
		installNPM()
		installGo()

		echo "===== Build che-dev =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildDev}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${DEV_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${DEV_path}.git"]]])
		sh "mvn clean install ${MVN_FLAGS} -f ${DEV_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashDev', includes: findFiles(glob: '.repository/**').join(", ")

		VER_DEV = sh(returnStdout:true,script:"egrep \"<version>\" ${DEV_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_DEV = sh(returnStdout:true,script:"cd ${DEV_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Build che-dev ====="

		echo "===== Build che-parent =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildParent}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${PAR_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${PAR_path}.git"]]])
		sh "mvn clean install ${MVN_FLAGS} -f ${PAR_path}/pom.xml ${MVN_EXTRA_FLAGS}"

		VER_PAR = sh(returnStdout:true,script:"egrep \"<version>\" ${PAR_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_PAR = sh(returnStdout:true,script:"cd ${PAR_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Build che-parent ====="

		echo "===== Get CRW version =====>"
		if (env.ghprbPullId && env.ghprbPullId?.trim()) {
			checkout([$class: 'GitSCM', 
				branches: [[name: "FETCH_HEAD"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [
					[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"],
					[$class: 'LocalBranch'],
					[$class: 'PathRestriction', excludedRegions: 'dependencies/**'],
					[$class: 'DisableRemotePoll']
				],
				submoduleCfg: [], 
				userRemoteConfigs: [[refspec: "+refs/pull/${env.ghprbPullId}/head:refs/remotes/origin/PR-${env.ghprbPullId}", url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		} else {
			checkout([$class: 'GitSCM', 
				branches: [[name: "${branchToBuildCRW}"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [
					[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"],
					[$class: 'PathRestriction', excludedRegions: 'dependencies/**'],
				],
				submoduleCfg: [], 
				userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		}
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Get CRW version ====="

		echo "===== Build che-dashboard =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_DB_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_DB_path}.git"]]])

		VER_CHE_DB = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_DB_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE_DB = sh(returnStdout:true,script:"cd ${CHE_DB_path}/ && git rev-parse --short=4 HEAD").trim()

		// set correct version of CRW Dashboard
		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "CRW_SHAs (for dashboard) = ${CRW_SHAs}"

		// insert a longer version string which includes both CRW and Che, plus build and SHA info
		// not sure if this does anything. See also assembly/codeready-workspaces-assembly-dashboard-war/pom.xml line 109
		sh "egrep 'productVersion = ' ${CHE_DB_path}/src/components/api/che-service.factory.ts"
		sh "sed -i -e \"s#\\(.\\+productVersion = \\).\\+#\\1'${CRW_SHAs}';#g\" ${CHE_DB_path}/src/components/api/che-service.factory.ts;"
		sh "egrep 'productVersion = ' ${CHE_DB_path}/src/components/api/che-service.factory.ts"
		// apply CRW CSS
		sh '''#!/bin/bash -xe
			rawBranch=${branchToBuildCRW##*/}
			curl -S -L --create-dirs -o ''' + CHE_DB_path + '''/src/assets/branding/branding.css \
				https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${rawBranch}/assembly/codeready-workspaces-assembly-dashboard-war/src/main/webapp/assets/branding/branding-crw.css
			cat ''' + CHE_DB_path + '''/src/assets/branding/branding.css
		'''

		sh "mvn clean install ${MVN_FLAGS} -P native -f ${CHE_DB_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		echo "<===== Build che-dashboard ====="

		echo "===== Build che-workspace-loader =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_WL_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_WL_path}.git"]]])

		VER_CHE_WL = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_WL_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE_WL = sh(returnStdout:true,script:"cd ${CHE_WL_path}/ && git rev-parse --short=4 HEAD").trim()
		sh "mvn clean install ${MVN_FLAGS} -P native -f ${CHE_WL_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		echo "<===== Build che-workspace-loader ====="

		echo "===== Build che server assembly =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_path}.git"]]])

		VER_CHE = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE = sh(returnStdout:true,script:"cd ${CHE_path}/ && git rev-parse --short=4 HEAD").trim()
		sh "mvn clean install ${MVN_FLAGS} -P native -f ${CHE_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		echo "<==== Build che server assembly ====="

		echo "===== Build CRW server assembly =====>"
		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${CHE_DB_path} @ ${SHA_CHE_DB} (${VER_CHE_DB}) \
:: ${CHE_WL_path} @ ${SHA_CHE_WL} (${VER_CHE_WL}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "CRW_SHAs (overall) = ${CRW_SHAs}"

		// TODO does crw.dashboard.version still work here? Or should we do this higher up? 
		// NOTE: VER_CHE could be 7.12.2-SNAPSHOT if we're using a .x branch instead of a tag. So this overrides what's in the crw root pom.xml
		sh "mvn clean install ${MVN_FLAGS} -f ${CRW_path}/pom.xml -Dparent.version=\"${VER_CHE}\" -Dche.version=\"${VER_CHE}\" -Dcrw.dashboard.version=\"${CRW_SHAs}\" ${MVN_EXTRA_FLAGS}"
		archiveArtifacts fingerprint: true, artifacts:"**/*.log, **/assembly/*xml, **/assembly/**/*xml, ${CRW_path}/assembly/${CRW_path}-assembly-main/target/*.tar.*"

		echo "<===== Build CRW server assembly ====="

		def brewwebQuery = \
			"https://brewweb.engineering.redhat.com/brew/tasks?method=buildContainer&owner=crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com&state=all&view=flat&order=-id"
		def descriptString=(
			env.ghprbPullId && env.ghprbPullId?.trim()?\
				"<a href=https://github.com/redhat-developer/${CRW_path}/pull/${env.ghprbPullId}>PR-${env.ghprbPullId}</a> ":\
				("${SCRATCH}"=="true"?\
					"<a href=${brewwebQuery}>Scratch</a> ":\
					"<a href=https://quay.io/repository/crw/server-rhel8?tab=tags>Quay</a> "\
				)\
			)\
			+ "Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) <br/>\
 :: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) <br/>\
 :: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) <br/>\
 :: ${CHE_DB_path} @ ${SHA_CHE_DB} (${VER_CHE_DB}) <br/>\
 :: ${CHE_WL_path} @ ${SHA_CHE_WL} (${VER_CHE_WL}) <br/>\
 :: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) <br/>\
 :: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
	}
}

timeout(120) {
	node("${node}"){ stage "Run get-sources-rhpkg-container-build"
		def QUAY_REPO_PATHs=(env.ghprbPullId && env.ghprbPullId?.trim()?"":("${SCRATCH}"=="true"?"":"server-rhel8"))

		def matcher = ( "${JOB_NAME}" =~ /.*_(stable-branch|master).*/ )
		def JOB_BRANCH = (matcher.matches() ? matcher[0][1] : "master")

		def matcher2 = ( "${JOB_NAME}" =~ /.*(_PR).*/ )
		def PR_SUFFIX = (matcher2.matches() ? matcher2[0][1] : "")

		echo "[INFO] Trigger get-sources-rhpkg-container-build " + (env.ghprbPullId && env.ghprbPullId?.trim()?"for PR-${ghprbPullId} ":"") + \
		"with SCRATCH = ${SCRATCH}, QUAY_REPO_PATHs = ${QUAY_REPO_PATHs}, JOB_BRANCH = ${JOB_BRANCH}${PR_SUFFIX}"

		// trigger OSBS build
		build(
		  job: 'get-sources-rhpkg-container-build',
		  wait: false,
		  propagate: false,
		  parameters: [
			[
			  $class: 'StringParameterValue',
			  name: 'GIT_PATHs',
			  value: "containers/codeready-workspaces",
			],
			[
			  $class: 'StringParameterValue',
			  name: 'GIT_BRANCH',
			  value: "crw-2.2-rhel-8",
			],
			[
			  $class: 'StringParameterValue',
			  name: 'QUAY_REPO_PATHs',
			  value: "${QUAY_REPO_PATHs}",
			],
			[
			  $class: 'StringParameterValue',
			  name: 'SCRATCH',
			  value: "${SCRATCH}",
			],
			[
			  $class: 'StringParameterValue',
			  name: 'JOB_BRANCH',
			  value: "${JOB_BRANCH}${PR_SUFFIX}",
			]
		  ]
		)
	}
}
