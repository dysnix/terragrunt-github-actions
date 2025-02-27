#!/bin/bash

function terragruntHclFmt {
  # Eliminate `-recursive` option for Terragrunt 0.11.x.

  # Gather the output of `terragrunt fmt`.
  echo "fmt: info: checking if Terragrunt files in ${tfWorkingDir} are correctly formatted"
  fmtOutput=$(${tfBinary} hclfmt --terragrunt-check ${*} 2>&1)
  fmtExitCode=${?}

  # Exit code of 0 indicates success. Print the output and exit.
  if [ ${fmtExitCode} -eq 0 ]; then
    echo "fmt: info: Terragrunt files in ${tfWorkingDir} are correctly formatted"
    echo "${fmtOutput}"
    echo
    exit ${fmtExitCode}
  fi

  # Exit code of 2 indicates a parse error. Print the output and exit.
  if [ ${fmtExitCode} -eq 2 ]; then
    echo "fmt: error: failed to parse Terragrunt files"
    echo "${fmtOutput}"
    echo
    exit ${fmtExitCode}
  fi

  # Exit code of !0 and !2 indicates failure.
  echo "fmt: error: Terragrunt files in ${tfWorkingDir} are incorrectly formatted"
  echo "${fmtOutput}"
  echo
  echo "fmt: error: the following files in ${tfWorkingDir} are incorrectly formatted"
  fmtFileList=$(${tfBinary} fmt -check=true -write=false -list ${fmtRecursive})
  echo "${fmtFileList}"
  echo

  # Comment on the pull request if necessary.
  if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tfComment}" == "1" ]; then
    fmtComment=""
    for file in ${fmtFileList}; do
      fmtFileDiff=$(${tfBinary} hclfmt --terragrunt-check "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
      fmtComment="${fmtComment}
<details><summary><code>${tfWorkingDir}/${file}</code></summary>

\`\`\`diff
${fmtFileDiff}
\`\`\`

</details>"

    done

    fmtCommentWrapper="#### \`${tfBinary} fmt\` Failed
${fmtComment}

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tfWorkingDir}\`, Workspace: \`${tfWorkspace}\`*"

    fmtCommentWrapper=$(stripColors "${fmtCommentWrapper}")
    echo "hclfmt: info: creating JSON"
    fmtPayload=$(echo "${fmtCommentWrapper}" | jq -R --slurp '{body: .}')
    fmtCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
    echo "hclfmt: info: commenting on the pull request"
    echo "${fmtPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${fmtCommentsURL}" > /dev/null
  fi

  # Write changes to branch
  echo "::set-output name=tf_actions_fmt_written::false"
  if [ "${tfFmtWrite}" == "1" ]; then
    echo "hclfmt: info: Terraform files in ${tfWorkingDir} will be formatted"
    terraform fmt -write=true ${fmtRecursive} "${*}"
    fmtExitCode=${?}
    echo "::set-output name=tf_actions_fmt_written::true"
  fi

  exit ${fmtExitCode}
}
