#!/usr/bin/env bash
# Copyright © 2019 PixelExperience Project
#
# SPDX-License-Identifier: GPL-3.0
#
### Script to test and format our jsons

ADMINS="@Hlcpereira @baalajimaestro @Shreejoy\_Dash"
BUILD_START=$(date +"%s")
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
COMMIT_MESSAGE="$(git log -1 --pretty=%B)"
COMMIT_SMALL_HASH="$(git rev-parse --short HEAD)"
COMMIT_HASH="$(git rev-parse --verify HEAD)"


git remote rm origin
git remote add origin https://baalajimaestro:"${GH_PERSONAL_TOKEN}"@github.com/PixelExperience/official_devices.git

function sendAdmins() {
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendmessage" --data "text=${*}&chat_id=-1001463677498&disable_web_page_preview=true&parse_mode=Markdown" > /dev/null
}

function sendMaintainers() {
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendmessage" --data "text=${*}&chat_id=-1001287849567&disable_web_page_preview=true&parse_mode=Markdown" > /dev/null
}

function closePR() {
    curl -s -X POST -d '{"state": "closed"}' -H "Authorization: token $GH_PERSONAL_TOKEN" https://api.github.com/repos/PixelExperience/official_devices/pulls/$PULL_REQUEST_NUMBER >/dev/null
    curl -s -X POST -d '{"body": "This is Pixel CI Automation Service! This PR has been closed as it has a derped devices.json and/or you are PR-ing some other file. Please recheck your PR."}' -H "Authorization: token $GH_PERSONAL_TOKEN" https://api.github.com/repos/PixelExperience/official_devices/issues/$PULL_REQUEST_NUMBER/comments >/dev/null
    exit 1
}

function checkPullReq() {
    printf "\n\n***Pixel Experience CI***\n\n"

    if [ -z "$PULL_REQUEST_NUMBER" ]; then
        git checkout master >/dev/null
        git pull origin master >/dev/null
    else
        git fetch origin master >/dev/null
        export CHANGED_FILES="$(git --no-pager diff --name-only HEAD $(git merge-base HEAD origin/master))"
    fi
}

function checkLint() {

    if [[ "$COMMIT_MESSAGE" =~ "[PIXEL-CI]" ]]; then
        if [[ -n "$PULL_REQUEST_NUMBER" ]]; then
            sendMaintainers "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER has CI-Skip mechanism. It has been closed.\`"
            sendAdmins "\`Official-Devices CI%0A%0AI have closed PR $PULL_REQUEST_NUMBER for using CI-Skip mechanism. \`%0A%0A[PR Link](https://github.com/PixelExperience/official_devices/pull/$PULL_REQUEST_NUMBER)"
            curl -s -X POST -d '{"state": "closed"}' -H "Authorization: token $GH_PERSONAL_TOKEN" https://api.github.com/repos/PixelExperience/official_devices/pulls/$PULL_REQUEST_NUMBER >/dev/null
            curl -s -X POST -d '{"body": "This is Pixel CI Automation Service! You attempted to skip CI on a PR, its not permitted. Reopen PR after you fix the commit message."}' -H "Authorization: token $GH_PERSONAL_TOKEN" https://api.github.com/repos/PixelExperience/official_devices/issues/$PULL_REQUEST_NUMBER/comments >/dev/null
            exit 1
        else
            printf "\n\n***Commit Already Linted***\n\n"
            exit 0
        fi
    fi
}

function checkJsons() {
    cargo run
    RESULT=$?

    if [ -n "$PULL_REQUEST_NUMBER" ]; then
        if [[ ! "$CHANGED_FILES" =~ "devices.json" ]]; then
            sendMaintainers "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER has an improper format and has been closed.\`%0A\`Maintainer has been requested to follow the PR guidelines before PR-ing again.\`"
            sendAdmins "\`Official-Devices CI%0A%0AI have closed PR $PULL_REQUEST_NUMBER due to failing checks.\`%0A%0A[PR Link](https://github.com/PixelExperience/official_devices/pull/$PULL_REQUEST_NUMBER)"
            closePR
        elif [ "$RESULT" -ne 0 ]; then
            sendAdmins "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER is failing JSON checks. Please don't merge\`"
            sendMaintainers "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER is failing JSON checks. Maintainer is requested to check it\` %0A%0A[PR Link](https://github.com/PixelExperience/official_devices/pull/$PULL_REQUEST_NUMBER)"
            closePR
        else
           if [[ "$CHANGED_FILES" =~ "devices.json" ]]; then
            ALTERED_DEVICE="$(git --no-pager diff HEAD $(git merge-base HEAD origin/master) | grep "codename")"
            if [[ -z "$ALTERED_DEVICE" ]]; then
              echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
              sendAdmins "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER can be merged.\` %0A%0A${ADMINS} %0A%0A[PR Link](https://github.com/PixelExperience/official_devices/pull/$PULL_REQUEST_NUMBER) %0A%0A\`CI couldn't figure out which device was PR-ed\`"
              sendMaintainers "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER has passed all checks. Please wait for the merge. CI can't figure out which device was PR-ed\`"
           else
             echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
             sendAdmins "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER can be merged.\`%0A%0A${ADMINS}%0A%0A\`Device PR-ed for: ${ALTERED_DEVICE}\`%0A%0A[PR Link](https://github.com/PixelExperience/official_devices/pull/$PULL_REQUEST_NUMBER)"
             sendMaintainers "\`Official-Devices CI%0A%0APR $PULL_REQUEST_NUMBER has passed all checks. Please wait for the merge.%0A%0ADevice PR-ed for: ${ALTERED_DEVICE}\`"
            exit 0
            fi
          fi
        fi
    elif [ "$RESULT" -ne 0 ]; then
        sendAdmins "\`Official-Devices CI%0A%0ASomeone has merged a failing file. Please look in ASAP.\` %0A%0A${ADMINS}"
        echo "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds. But its an error!"
        exit 1
    else
        sendAdmins "\`Official-Devices CI\`%0A%0A**I am building master branch job.** %0A**Commit Point:** [${COMMIT_SMALL_HASH}](https://github.com/PixelExperience/official_devices/commit/${COMMIT_HASH})"
    fi

}

function pushToGit() {
    if [ -z "$PULL_REQUEST_NUMBER" ] && [ -n "$(git status -s)" ]; then
        git add .
        git commit --amend -m "[PIXEL-CI]: ${COMMIT_MESSAGE}"
        git push -f origin master
        sendAdmins "\`Official-Devices CI\`%0A%0AJSON Linted and Force Pushed!"
        echo "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
    fi


}

checkPullReq
checkLint
checkJsons
pushToGit
